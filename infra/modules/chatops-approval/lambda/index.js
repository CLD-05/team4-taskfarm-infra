const crypto = require("crypto");
const https = require("https");
const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const lambda = new LambdaClient({});
const secrets = new SecretsManagerClient({});
const secretCache = new Map();

exports.handler = async (event) => {
  if (event && event.mode === "approve_pending_deployment_worker") {
    return await handleAutoApproveWorker(event);
  }

  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body || "", "base64").toString("utf8")
    : event.body || "";

  try {
    await verifySlackRequest(event.headers || {}, rawBody);

    const path = event.rawPath || "";
    if (path.endsWith("/slack/commands")) {
      return handleCommand(rawBody);
    }
    if (path.endsWith("/slack/actions")) {
      return await handleAction(rawBody);
    }

    return jsonResponse(404, { text: "Unknown ChatOps route." });
  } catch (error) {
    console.error(error);
    return jsonResponse(error.statusCode || 500, {
      text: error.publicMessage || "ChatOps approval failed."
    });
  }
};

async function handleCommand(rawBody) {
  const form = parseForm(rawBody);
  const userId = form.user_id;
  assertAllowedUser(userId);

  return jsonResponse(200, {
    response_type: "in_channel",
    text: "prod deploy approval requested",
    blocks: approvalBlocks(userId)
  });
}

async function handleAction(rawBody) {
  const form = parseForm(rawBody);
  const payload = JSON.parse(form.payload || "{}");
  const action = payload.actions && payload.actions[0];

  if (!action) {
    throw publicError(400, "Slack action payload is missing.");
  }

  const userId = payload.user && payload.user.id;
  assertAllowedUser(userId);

  if (action.action_id === "reject_prod_deploy") {
    await respondToSlack(payload.response_url, {
      replace_original: true,
      response_type: "in_channel",
      text: `<@${userId}> rejected prod deployment.`
    });
    return emptyResponse();
  }

  if (action.action_id !== "approve_prod_deploy") {
    throw publicError(400, "Unsupported Slack action.");
  }

  const dispatchedAt = new Date();
  const dispatch = await dispatchGithubWorkflow();
  await invokeAutoApproveWorker({
    dispatchedAt: dispatchedAt.toISOString(),
    responseUrl: payload.response_url,
    slackUserId: userId
  });

  await respondToSlack(payload.response_url, {
    replace_original: true,
    response_type: "in_channel",
    text: `<@${userId}> approved prod deployment. GitHub Actions workflow dispatch status: ${dispatch.statusCode}. Automatically approving \`${process.env.GITHUB_ENVIRONMENT_NAME}\` next.`
  });

  return emptyResponse();
}

async function handleAutoApproveWorker(event) {
  try {
    const run = await findDispatchedWorkflowRun(new Date(event.dispatchedAt));
    if (!run) {
      await respondToSlack(event.responseUrl, {
        replace_original: true,
        response_type: "in_channel",
        text: `<@${event.slackUserId}> approved prod deployment, but the GitHub Actions run was not visible yet. Check GitHub Actions for the pending production review.`
      });
      return { ok: false, reason: "run_not_found" };
    }

    const result = await reviewPendingDeployment(run.id, "approved", event.slackUserId);
    await respondToSlack(event.responseUrl, {
      replace_original: true,
      response_type: "in_channel",
      text: `<@${event.slackUserId}> approved prod deployment and automatically approved \`${process.env.GITHUB_ENVIRONMENT_NAME}\` for GitHub Actions run <${run.html_url}|#${run.run_number}>. Review status: ${result.statusCode}.`
    });
    return { ok: true, run_id: run.id };
  } catch (error) {
    console.error(error);
    await respondToSlack(event.responseUrl, {
      replace_original: true,
      response_type: "in_channel",
      text: `<@${event.slackUserId}> approved prod deployment, but automatic \`${process.env.GITHUB_ENVIRONMENT_NAME}\` approval failed: ${error.publicMessage || error.message}`
    });
    return { ok: false, error: error.publicMessage || error.message };
  }
}

function approvalBlocks(requesterId) {
  return [
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `*prod deployment approval requested*\nRequester: <@${requesterId}>\nRepository: \`${process.env.GITHUB_OWNER}/${process.env.GITHUB_REPO}\`\nWorkflow: \`${process.env.GITHUB_WORKFLOW_ID}\`\nRef: \`${process.env.GITHUB_REF}\``
      }
    },
    {
      type: "actions",
      elements: [
        {
          type: "button",
          text: { type: "plain_text", text: "Approve" },
          style: "primary",
          action_id: "approve_prod_deploy",
          value: "approve"
        },
        {
          type: "button",
          text: { type: "plain_text", text: "Reject" },
          style: "danger",
          action_id: "reject_prod_deploy",
          value: "reject"
        }
      ]
    }
  ];
}

async function invokeAutoApproveWorker(payload) {
  await lambda.send(new InvokeCommand({
    FunctionName: process.env.SELF_FUNCTION_NAME,
    InvocationType: "Event",
    Payload: Buffer.from(JSON.stringify({
      mode: "approve_pending_deployment_worker",
      ...payload
    }))
  }));
}

async function dispatchGithubWorkflow() {
  const owner = encodeURIComponent(process.env.GITHUB_OWNER);
  const repo = encodeURIComponent(process.env.GITHUB_REPO);
  const workflowId = encodeURIComponent(process.env.GITHUB_WORKFLOW_ID);
  const prodInputName = process.env.WORKFLOW_PROD_INPUT_NAME || "prod";

  return githubRequest({
    hostname: "api.github.com",
    path: `/repos/${owner}/${repo}/actions/workflows/${workflowId}/dispatches`,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ref: process.env.GITHUB_REF || "main",
      inputs: {
        [prodInputName]: "true"
      }
    }),
    successStatuses: [200, 201, 204]
  });
}

async function findDispatchedWorkflowRun(dispatchedAt) {
  const owner = encodeURIComponent(process.env.GITHUB_OWNER);
  const repo = encodeURIComponent(process.env.GITHUB_REPO);
  const workflowId = encodeURIComponent(process.env.GITHUB_WORKFLOW_ID);
  const ref = encodeURIComponent(process.env.GITHUB_REF || "main");
  const minCreatedAt = dispatchedAt.getTime() - 5000;

  for (let attempt = 0; attempt < 4; attempt += 1) {
    const response = await githubRequest({
      hostname: "api.github.com",
      path: `/repos/${owner}/${repo}/actions/workflows/${workflowId}/runs?event=workflow_dispatch&branch=${ref}&per_page=5`,
      method: "GET",
      successStatuses: [200]
    });
    const body = JSON.parse(response.body || "{}");
    const run = (body.workflow_runs || []).find((candidate) => {
      return new Date(candidate.created_at).getTime() >= minCreatedAt;
    });

    if (run) {
      return run;
    }

    await delay(500);
  }

  return null;
}

async function reviewPendingDeployment(runId, state, slackUserId) {
  if (!runId) {
    throw publicError(400, "GitHub Actions run ID is missing.");
  }

  const owner = encodeURIComponent(process.env.GITHUB_OWNER);
  const repo = encodeURIComponent(process.env.GITHUB_REPO);
  const environmentName = process.env.GITHUB_ENVIRONMENT_NAME || "production";
  const environment = await findPendingDeployment(owner, repo, runId, environmentName);

  if (!environment) {
    throw publicError(409, `No pending ${environmentName} deployment found for run #${runId}.`);
  }

  return githubRequest({
    hostname: "api.github.com",
    path: `/repos/${owner}/${repo}/actions/runs/${encodeURIComponent(runId)}/pending_deployments`,
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      environment_ids: [environment.environment.id],
      state,
      comment: `${state} from Slack ChatOps by ${slackUserId}`
    }),
    successStatuses: [200, 201, 204]
  });
}

async function findPendingDeployment(owner, repo, runId, environmentName) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const pending = await githubRequest({
      hostname: "api.github.com",
      path: `/repos/${owner}/${repo}/actions/runs/${encodeURIComponent(runId)}/pending_deployments`,
      method: "GET",
      successStatuses: [200]
    });
    const deployments = JSON.parse(pending.body || "[]");
    const environment = deployments.find((deployment) => {
      return deployment.environment && deployment.environment.name === environmentName;
    });

    if (environment) {
      return environment;
    }

    await delay(1500);
  }

  return null;
}

async function githubRequest(options) {
  const token = await getSecret(process.env.GITHUB_TOKEN_SECRET_ID, ["token", "github_token", "GITHUB_TOKEN"]);

  return requestJson({
    ...options,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "User-Agent": "taskfarm-chatops-approval",
      "X-GitHub-Api-Version": "2026-03-10",
      ...(options.headers || {})
    }
  });
}

async function verifySlackRequest(headers, rawBody) {
  const normalizedHeaders = {};
  for (const [key, value] of Object.entries(headers)) {
    normalizedHeaders[key.toLowerCase()] = value;
  }

  const timestamp = normalizedHeaders["x-slack-request-timestamp"];
  const slackSignature = normalizedHeaders["x-slack-signature"];
  if (!timestamp || !slackSignature) {
    throw publicError(401, "Slack signature headers are missing.");
  }

  const ageSeconds = Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp));
  if (!Number.isFinite(ageSeconds) || ageSeconds > 300) {
    throw publicError(401, "Slack request timestamp is too old.");
  }

  const signingSecret = await getSecret(process.env.SLACK_SIGNING_SECRET_ID, [
    "signing_secret",
    "slack_signing_secret",
    "SLACK_SIGNING_SECRET"
  ]);
  const baseString = `v0:${timestamp}:${rawBody}`;
  const computed = `v0=${crypto.createHmac("sha256", signingSecret).update(baseString).digest("hex")}`;

  const computedBuffer = Buffer.from(computed);
  const slackBuffer = Buffer.from(slackSignature);
  if (computedBuffer.length !== slackBuffer.length || !crypto.timingSafeEqual(computedBuffer, slackBuffer)) {
    throw publicError(401, "Slack signature verification failed.");
  }
}

function assertAllowedUser(userId) {
  const allowed = (process.env.ALLOWED_SLACK_USER_IDS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (!userId || allowed.length === 0 || !allowed.includes(userId)) {
    throw publicError(403, "This Slack user is not allowed to approve prod deployment.");
  }
}

async function getSecret(secretId, jsonKeys) {
  if (secretCache.has(secretId)) {
    return secretCache.get(secretId);
  }

  const result = await secrets.send(new GetSecretValueCommand({ SecretId: secretId }));
  const raw = result.SecretString || Buffer.from(result.SecretBinary || "", "base64").toString("utf8");
  let value = raw;

  try {
    const parsed = JSON.parse(raw);
    for (const key of jsonKeys) {
      if (parsed[key]) {
        value = parsed[key];
        break;
      }
    }
  } catch (_error) {
    value = raw;
  }

  if (!value) {
    throw publicError(500, `Secret ${secretId} is empty.`);
  }

  secretCache.set(secretId, value);
  return value;
}

function parseForm(rawBody) {
  return Object.fromEntries(new URLSearchParams(rawBody));
}

async function respondToSlack(responseUrl, body) {
  if (!responseUrl) {
    return;
  }

  const url = new URL(responseUrl);
  await requestJson({
    hostname: url.hostname,
    path: `${url.pathname}${url.search}`,
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body),
    successStatuses: [200]
  });
}

function requestJson(options) {
  const body = options.body || "";

  return new Promise((resolve, reject) => {
    const request = https.request({
      hostname: options.hostname,
      path: options.path,
      method: options.method,
      headers: {
        ...options.headers,
        "Content-Length": Buffer.byteLength(body)
      }
    }, (response) => {
      let responseBody = "";
      response.on("data", (chunk) => {
        responseBody += chunk;
      });
      response.on("end", () => {
        if (!options.successStatuses.includes(response.statusCode)) {
          reject(publicError(response.statusCode || 500, responseBody || "External API request failed."));
          return;
        }
        resolve({ statusCode: response.statusCode, body: responseBody });
      });
    });

    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function publicError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.publicMessage = message;
  return error;
}

function jsonResponse(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  };
}

function emptyResponse() {
  return { statusCode: 200, body: "" };
}

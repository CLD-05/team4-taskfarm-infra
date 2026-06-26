# ChatOps prod approval

This module creates an HTTPS API for Slack ChatOps prod deployment approval.

## Slack URLs

After applying `infra/envs/prod/infra`, use these Terraform outputs:

- `chatops_slack_command_request_url`: Slack slash command Request URL
- `chatops_slack_interactivity_request_url`: Slack Interactivity Request URL

Recommended Slack command:

```text
/deploy-prod
```

## Required secret values

Terraform creates the empty Secrets Manager secrets below. Fill their values after apply:

- `team4/taskfarm/prod/chatops-github-token`
- `team4/taskfarm/prod/chatops-slack-signing-secret`

The GitHub token must be able to dispatch workflows and approve pending deployments in `CLD-05/team4-taskfarm-app`.
Use a fine-grained token or GitHub App token with Actions write permission and deployment review permission, or a classic token with the required repository access.

Each secret can be a plain string or JSON:

```json
{ "token": "github_pat_..." }
```

```json
{ "signing_secret": "..." }
```

## Required Terraform input

Set `chatops_allowed_slack_user_ids` in the prod infra tfvars or through the CLI:

```hcl
chatops_allowed_slack_user_ids = ["U0123456789"]
```

The Lambda rejects all requests when this list is empty.

## Dispatched workflow

The Slack approval dispatches:

- repository: `CLD-05/team4-taskfarm-app`
- workflow: `cd.yml`
- ref: `main`
- input: `deploy_prod=true`
- environment review: `production`

After dispatching the app workflow, the Lambda automatically approves the pending `production` deployment.
The GitHub token owner must be allowed to approve the `production` environment.

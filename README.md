# 🌱 taskfarm — Infra (Terraform)

> 게이미피케이션 투두앱 **taskfarm** 의 인프라 레포지토리
> dev / prod 환경 완전 분리 · EKS 기반 · GitOps 배포

![Terraform](https://img.shields.io/badge/Terraform-1.10%2B-7B42BC)
![AWS](https://img.shields.io/badge/AWS-EKS%201.35-FF9900)
![Region](https://img.shields.io/badge/Region-ap--northeast--2-232F3E)

---

## 📌 이 레포의 역할

taskfarm의 **모든 AWS 인프라를 Terraform 코드로** 관리합니다.
앱 코드는 [team4-taskfarm-app](#), 배포 매니페스트는 [team4-taskfarm-config](#) 를 참고하세요.

```
team4-taskfarm-app      → Spring Boot 소스, Dockerfile, CI
team4-taskfarm-config   → k8s 매니페스트, ArgoCD (CD)
team4-taskfarm-infra    → Terraform (현재 레포)
```

---

## 🗂 디렉터리 구조

```
team4-taskfarm-infra/
├── scripts/                 야간 비용절감 스크립트 (teardown / startup)
└── infra/
    ├── bootstrap/           state 저장소(S3)를 만드는 곳. 처음 한 번만 실행
    ├── chaos/               AWS FIS 카오스 실험 (AZ 장애·노드 종료)
    │
    ├── modules/             인프라 부품의 설계도. 직접 실행하지 않는다
    │   ├── vpc/  eks/  rds/  elasticache/  ecr/  iam/
    │   ├── secrets/  s3/  route53/  acm/  cloudfront/  bastion/
    │   ├── chatops-approval/     Slack 승인 게이트
    │   └── platform-addons/      애드온·Helm 설치 모듈
    │
    └── envs/                실제로 인프라를 만드는 곳. 여기서 apply 한다
        ├── dev/
        │   ├── infra/            레이어 1: vpc·eks·rds 등 (AWS provider)
        │   └── platform-addons/  레이어 2: 애드온·Helm (Kubernetes·Helm provider)
        └── prod/
            ├── infra/
            └── platform-addons/
```

> **modules** 는 부품, **envs/** 가 tfvars로 값을 채워 조립합니다.
> 같은 모듈을 dev/prod가 **다른 값으로 호출** → 환경 차이는 tfvars가 만듭니다.

---

## ▶️ 배포 실행 순서 (반드시 순서대로)

> ⚠️ infra와 platform-addons를 **분리해서 2단계**로 apply 합니다.
> 한 번에 하면 helm/kubernetes provider가 아직 없는 EKS에 붙으려다 실패합니다.

```bash
# 0단계: state 백엔드 (최초 1회만)
cd infra/bootstrap
terraform init && terraform apply

# 1단계: dev 인프라 (레이어 1 — VPC·EKS·RDS·ECR·IAM…)
cd ../envs/dev/infra
terraform init
terraform apply
# → kubeconfig 갱신 후 EKS 접속 확인
aws eks update-kubeconfig --name team4-dev-eks --region ap-northeast-2
kubectl get nodes   # Fargate라 노드 대신 fargate-* 확인

# 2단계: dev 애드온 (레이어 2 — ALB Controller·ESO·ArgoCD·KEDA·Prometheus…)
cd ../platform-addons
terraform init
terraform apply

# prod 도 동일 순서 (envs/prod/infra → envs/prod/platform-addons)
```

> dev만 테스트하려면 `envs/dev` 만 apply. **prod 디렉터리는 호출 전까지 비용 0.**
> 애플리케이션 배포는 여기서 하지 않습니다 → **ArgoCD(config 레포)** 가 담당.

---

## 🔐 state 관리

- **S3 + 네이티브 락(`use_lockfile`)** — **DynamoDB 미사용** (Terraform 1.10+ 내장 락)
- state 경로: `team4/{env}/{layer}/terraform.tfstate`
  ```
  team4/dev/infra/terraform.tfstate
  team4/dev/platform-addons/terraform.tfstate
  team4/prod/infra/terraform.tfstate
  team4/prod/platform-addons/terraform.tfstate
  ```
- `.terraform.lock.hcl` 은 **커밋** (재현성)

---

## 🌐 환경 차이 (dev / prod)  ※ 실제 배포 기준

| 항목 | dev | prod |
|------|-----|------|
| VPC | 10.4.0.0/17 | 10.4.128.0/17 |
| AZ | a, c | a, c |
| **EKS 컴퓨트** | **Fargate (서버리스)** | **노드그룹 m6i.large (desired 2 / max 5)** |
| EKS endpoint | public + private | private |
| **NAT** | **NAT 인스턴스 (t4g.nano) 1개** | **NAT Gateway (AZ별 다중)** |
| RDS class | db.t4g.micro | db.m6i.large |
| RDS Multi-AZ | false (단일 AZ) | **true** (Primary a + Standby c) |
| Read Replica | 0 | **1** |
| Redis | cache.t4g.micro 단일 | cache.m7g.large 2노드 (a·c) |
| Pod 권한 | **IRSA만** (Fargate 조건상 Pod Identity 미적용) | IRSA + Pod Identity(구현·미사용, S3 확장대비) |
| CloudFront | 비활성 | 활성 |
| Bastion | 없음 | AZ-a Private · SSM 전용 |
| KEDA max | 2 | 5 |
| 관측성 | CloudWatch | CloudWatch + Prometheus + Grafana |
| deletion_protection | false | true |

> **왜 dev는 Fargate?** 노드 관리 부담·비용 최소화(검증용).
> **왜 prod는 노드그룹?** 성능·KEDA 오토스케일·비용 예측.
> **ECR 접근** = 노드/파드 → **NAT → ECR** (VPC 엔드포인트 없음). 현 규모엔 NAT로 충분, 확장 시 VPC 엔드포인트가 로드맵.

---

## 🌙 야간 비용 절감 스크립트

부트캠프 특성상 밤에는 모듈들를 내렸다가 아침에 올립니다. `scripts/` 참고.

```bash
# 저녁 — 내리기 (앱 scale0 → RDS replica destroy → RDS stop
#                → 노드그룹 destroy → NAT GW destroy → bastion/NAT인스턴스 stop)
./scripts/teardown.sh

# 아침 — 올리기 (teardown 역순, RDS primary available 대기 후 replica apply)
./scripts/startup.sh
```

> - **모든 ID를 동적 조회** → 하드코딩 없음, **git에 올려도 안전.**
> - `startup.sh`에 **EBS CSI 애드온 복구 단계** 포함 (노드 destroy/apply 시 CSI가 증발하는 문제 대응 — v3).
> - dev는 bastion·노드그룹이 없어(Fargate) down/up 대상 아님.

---

## ⚠️ 운영 주의사항 (사고 방지)

- **AWS 작업은 09:00~18:00만.** 18시 이후 terraform/kubectl 차단.
  apply/destroy(EKS+RDS 15~20분)는 **17:30 전 시작.**
- 모든 리소스에 **소문자 `team = team4` 태그** + 이름 prefix `team4-`. (대문자/누락 시 권한 차단)
- 리전은 **ap-northeast-2 고정.** 다른 리전 생성 금지.
- 권한 에러 시 체크: ①서울 리전? ②소문자 team 태그? ③다른 팀 것 아닌가? ④18시 이후 아닌가?

### destroy 순서 (막힘 방지)
```bash
# 1. ALB 먼저 정리 (LBC가 만든 실물 — 안 지우면 VPC destroy 막힘)
kubectl delete ingress,svc --all -A
# 2. platform-addons → infra 역순 destroy
cd envs/dev/platform-addons && terraform destroy
cd ../infra && terraform destroy
# 3. 안 지워지면: ECR force_delete, 노드 드레이닝 대기, team 태그 확인
```

### 비용 차단 우선순위 (종료/18시 임박 시)
NAT Gateway 삭제 → 노드 desired_size=0 → RDS 중지

---

## 🚫 절대 커밋 금지

```gitignore
*.tfstate
*.tfstate.backup
*.tfvars
.terraform/
```
> 민감값(Gemini 키·DB 비번)은 **Secrets Manager에만.** Terraform은 ARN만 참조.
> 레포 생성 직후 **`.gitignore` 부터** 푸시할 것. (지난 프로젝트 state 백업 json 노출 사고 → 재발 방지)
> ⚠️ **현재 `terraform.tfvars`에 `rds_master_password` 평문이 있다면 즉시 제거 + 히스토리 정리 필요.**

---

## 📐 코드 컨벤션

핵심:
- 파일 역할별 고정: `main` / `variables` / `outputs` / `versions` / `backend`
- 대표 리소스는 `this`, 전부 snake_case
- 모든 변수에 `description` + `type`
- 주석은 "왜"만, 태그는 default_tags 한 곳
- 커밋 전 `terraform fmt -recursive`
- 보안 스캔: **Trivy**(IaC), 커밋 훅 **Gitleaks**

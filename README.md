# 🌱 taskfarm — Infra (Terraform)

> 게이미피케이션 투두앱 **taskfarm** 의 인프라 레포지토리
> dev / prod 환경 완전 분리 · EKS 기반 · GitOps 배포

![Terraform](https://img.shields.io/badge/Terraform-1.14.x-7B42BC)
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
infra/
├── bootstrap-backend/        # state용 S3 (가장 먼저 1회만)
├── modules/                  # 환경 무관 재사용 부품
│   ├── network/              # VPC, subnet, NAT, AZ(a/c)
│   ├── bastion/              # SSM 허브 (SSH 차단)
│   ├── eks/                  # 클러스터 1.35, Pod Identity
│   ├── database/             # RDS MySQL 8.4 (Multi-AZ 변수화)
│   ├── elasticache/          # Redis (Gemini 캐싱)
│   ├── ecr/                  # 앱 이미지 (+lifecycle)
│   ├── github_oidc/          # GitHub Actions OIDC role
│   ├── route53/              # 도메인
│   ├── s3/                   # 스토리지
│   └── secrets/              # Secrets Manager (Gemini 키)
└── envs/                     # 실행 root (환경별 분리)
    ├── dev/
    │   ├── infra/            # VPC, EKS, RDS, IAM
    │   └── platform-addons/  # ArgoCD, ESO, Prometheus 등
    └── prod/
        ├── infra/
        └── platform-addons/
```

> **modules** 는 부품, **envs/** 가 tfvars로 값을 채워 조립합니다.
> 같은 모듈을 dev/prod가 다른 값으로 호출 → 환경 차이는 tfvars가 만듭니다.

---

## ▶️ 실행 순서 (반드시 순서대로)

> ⚠️ infra와 platform-addons를 **분리해서 2단계**로 apply 합니다.
> 한 번에 하면 helm/kubernetes provider가 아직 없는 EKS에 붙으려다 실패합니다.

```bash
# 1단계: state 백엔드 (최초 1회)
cd bootstrap-backend
terraform init
terraform apply

# 2단계: dev 인프라
cd ../envs/dev/infra
cp backend.tf.example backend.tf
terraform init
terraform apply
# → EKS 접속 확인 후 다음 단계

# 3단계: dev 애드온
cd ../platform-addons
cp backend.tf.example backend.tf
terraform init
terraform apply

# prod 도 동일 순서 (envs/prod/infra → envs/prod/platform-addons)
```

> dev만 테스트하려면 envs/dev 만 apply. prod 디렉터리는 호출 전까지 비용 0.

---

## 🔐 state 관리

- **S3 + 네이티브 락(use_lockfile)** — DynamoDB 미사용 (Terraform 1.10+)
- state 경로: `team4/{env}/{layer}/terraform.tfstate`
  ```
  team4/dev/infra/terraform.tfstate
  team4/dev/platform-addons/terraform.tfstate
  team4/prod/infra/terraform.tfstate
  team4/prod/platform-addons/terraform.tfstate
  ```
- `.terraform.lock.hcl` 은 **커밋** (재현성)

---

## 🌐 환경 차이 (dev / prod)

| 항목 | dev | prod |
|------|-----|------|
| VPC | 10.4.0.0/17 | 10.4.128.0/17 |
| AZ | a, c | a, c |
| NAT | 1개 | AZ별 다중 |
| EKS 노드 | t3.medium 1~2 | m6i.large 3~8 |
| EKS endpoint | public+private | private |
| RDS class | db.t4g.micro | db.m6i.large |
| RDS Multi-AZ | false | true |
| Read Replica | 0 | 1 |
| deletion_protection | false | true |
| CloudFront | 비활성 | 활성 |

---

## ⚠️ 운영 주의사항 (사고 방지)

- **AWS 작업은 09:00~18:00만.** 18시 이후 terraform/kubectl 차단.
  apply/destroy(EKS+RDS 15~20분)는 **17:30 전 시작.**
- 모든 리소스에 **소문자 `team = team4` 태그** + 이름 prefix `team4-`. (대문자/누락 시 권한 차단)
- 리전은 **ap-northeast-2 고정.** 다른 리전 생성 금지.
- 권한 에러 시 체크: ①서울 리전? ②소문자 team 태그? ③다른 팀 것 아닌가? ④18시 이후 아닌가?

### destroy 순서 (막힘 방지)
```bash
# 1. ALB 먼저 정리 (LBC가 만든 실물)
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
> 레포 생성 직후 **`.gitignore` 부터** 푸시할 것.

---

## 📐 코드 컨벤션

[team4-terraform-convention.md](#) 참조. 핵심:
- 파일 역할별 고정: `main` / `variables` / `outputs` / `versions`
- 대표 리소스는 `this`, 전부 snake_case
- 모든 변수에 `description` + `type`
- 주석은 "왜"만, 태그는 default_tags 한 곳
- 커밋 전 `terraform fmt -recursive`

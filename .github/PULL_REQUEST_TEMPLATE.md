## 📌 유형
<!-- 해당하는 것에 x 표시 (예: [x]) -->
- [ ] feat: 인프라/리소스 추가 (VPC, EKS, RDS, ECR 등)
- [ ] fix: 설정/리소스 버그 수정
- [ ] refactor: 모듈 구조 개선 (동작 변화 없음)
- [ ] chore: CICD/배포 설정 (GitHub Actions, ArgoCD, Kustomize)
- [ ] docs: 문서 (README, 비용 산정표, 아키텍처)

## 🔍 무엇을 했나요?
<!-- 한두 줄로 적어주세요. 예: EKS 노드그룹 모듈 추가, ArgoCD prod 오버레이 구성 -->

## 📋 변경 리소스
<!-- 어떤 AWS 리소스/매니페스트가 생기거나 바뀌나요? -->
- 

## ✅ 확인
- [ ] `terraform fmt` / `terraform validate` 통과
- [ ] `terraform plan` 결과 확인 (아래 참고란에 요약 또는 캡처 첨부)
- [ ] 리전이 **ap-northeast-2(서울)** 인지 확인
- [ ] 모든 리소스에 `team4-` 이름 + **소문자 team 태그** 적용 확인
- [ ] (K8s) `kubectl apply --dry-run` 또는 `kustomize build` 통과
- [ ] (CICD) 워크플로우 문법/OIDC 권한 확인

## 🔒 보안 체크 (필수)
- [ ] **tfstate / state 백업 json / tfvars / 시크릿** 커밋 안 됨 (.gitignore 확인)
- [ ] 하드코딩된 AWS 키·비밀번호·토큰 없음

## ⚠️ 참고 (선택)
<!-- plan 요약, 비용 영향(NAT/EKS/RDS 과금 주의), 리뷰어가 알아야 할 점. 없으면 비워두세요 -->

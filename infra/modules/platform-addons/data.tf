# modules/platform-addons/data.tf
# remote_state는 환경 디렉토리에서 읽어 변수로 주입받음.
# 모듈 내부에선 계정ID/리전만 data로 조회.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

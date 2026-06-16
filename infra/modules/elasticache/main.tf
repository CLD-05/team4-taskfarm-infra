# ----------------------------------------------------------------------
# ElastiCache Redis 보안 그룹 => EKS 노드 보안 그룹에서 Redis 포트(6379) 접근만 허용
# ----------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name   = "${var.name_prefix}-redis-sg"
  vpc_id = var.vpc_id

  # Redis 접근 허용 규칙 => source를 CIDR이 아니라 EKS 노드 보안 그룹으로 지정한다.
  ingress {
    from_port = var.redis_port
    to_port   = var.redis_port
    protocol  = "tcp"

    # 애플리케이션 컴퓨트 계층 보안 그룹에서 들어오는 트래픽만 허용
    security_groups = [var.app_security_group_id]
  }

  # ElastiCache에서 외부로 나가는 트래픽 허용 => 일반적으로 보안 그룹 egress는 전체 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-sg"
  })
}

# ----------------------------------------------------------------------
# ElastiCache 서브넷 그룹 => ElastiCache가 어떤 서브넷에 생성될지 private subnet group 지정
# ----------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  name = "${var.name_prefix}-redis-subnet-group"

  # VPC 모듈에서 output으로 받은 private db subnet 사용
  subnet_ids = var.db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-subnet-group"
  })
}

# ----------------------------------------------------------------------
# Redis 파라미터 그룹 => Redis 엔진 설정을 관리하는 리소스
# ----------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.name_prefix}-redis-params"
  family = var.redis_parameter_group_family

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-params"
  })
}

# ----------------------------------------------------------------------
# ElastiCache Redis 복제 그룹
# ----------------------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  # redis 복제 그룹 ID
  replication_group_id = "${var.name_prefix}-redis"

  description = "redis for cache"

  # Redis 엔진 사용
  engine = "redis"

  # Redis 버전 
  engine_version = var.redis_engine_version

  # 노드 타입 => dev : cache.t4g.micro, prod : cache.m7g.large
  node_type = var.redis_node_type

  # redis 기본 포트
  port = var.redis_port

  # 위에서 만든 파라미터 그룹 연결
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  # subnet group 연결
  subnet_group_name = aws_elasticache_subnet_group.redis.name

  # EKS 노드에서만 접근 가능
  security_group_ids = [aws_security_group.redis.id]

  # redis 노드 개수 => dev : 1, prod : 2개 이상
  num_cache_clusters = var.num_cache_clusters

  # 자동 장애 조치 => dev : false, prod : true
  automatic_failover_enabled = var.automatic_failover_enabled

  # Multi-AZ 여부 => dev ; false, prod : true
  multi_az_enabled = var.multi_az_enabled

  # 저장 데이터 암호화 - redis에 저장되는 데이터 암호화
  at_rest_encryption_enabled = var.at_rest_encryption_enabled

  # 전송 중 암호화 => true면 애플리케이션 redis 클라이언트 TLS 접속을 지원하도록 설정해야 함
  transit_encryption_enabled = var.transit_encryption_enabled

  # redis 스냅샷 보관 기간
  # snapshot_retention_limit = var.snapshot_retention_limit

  # 스냅샷 생성 시간대
  # snapshot_window = var.snapshot_window

  # 정기 점검 시간 => true 면 변경 사항 즉시 적용(재시작 가능성이 있기 때문에 운영 환경에서는 false)
  # maintenance_window = var.maintenance_window
  # apply_immediately  = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis"
  })
}

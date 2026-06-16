locals {
  resource_prefix = lower(replace(var.name_prefix, "_", "-"))
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket        = "${local.resource_prefix}-${each.value.suffix}"
  force_destroy = var.env == "dev" ? true : each.value.force_destroy

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-${each.value.suffix}"
  })
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  versioning_configuration {
    status = var.buckets[each.key].versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    bucket_key_enabled = var.kms_key_arn == null ? false : true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = {
    for key, bucket in var.buckets :
    key => bucket
    if bucket.lifecycle_enabled
  }

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = each.value.expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = each.value.noncurrent_version_expiration_days
    }
  }
}
resource "aws_s3_bucket" "source" {
  bucket = "dandi-s3-experiment-bucket"
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "prevent_deletion_of_object_versions" {
  bucket = aws_s3_bucket.source.id
  policy = data.aws_iam_policy_document.prevent_deletion_of_object_versions.json
}

data "aws_iam_policy_document" "prevent_deletion_of_object_versions" {
  statement {
    effect = "Deny"

    actions = [
      "s3:DeleteObjectVersion",
    ]

    resources = [
      "${aws_s3_bucket.source.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

# S3 lifecycle policy that permanently deletes objects with delete markers
# after 1 day.
resource "aws_s3_bucket_lifecycle_configuration" "expire_deleted_objects" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.source]

  bucket = aws_s3_bucket.source.id

  # Based on https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html#lifecycle-config-conceptual-ex7
  rule {
    id = "ExpireOldDeleteMarkers"
    filter {}

    # Expire objects with delete markers after 1 day
    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    # Also delete any delete markers associated with the expired object
    expiration {
      expired_object_delete_marker = true
    }

    status = "Enabled"
  }
}

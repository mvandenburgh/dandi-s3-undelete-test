resource "aws_s3_bucket" "source" {
  bucket = "dandi-s3-experiment-bucket"
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload all files in test_files/ directory to bucket
resource "aws_s3_object" "file" {
  for_each = fileset("test_files/", "*.txt")
  bucket   = aws_s3_bucket.source.id
  key      = each.key
  source   = "test_files/${each.key}"
  etag     = filemd5("test_files/${each.key}")
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
      aws_s3_bucket.source.arn,
      "${aws_s3_bucket.source.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

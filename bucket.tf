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

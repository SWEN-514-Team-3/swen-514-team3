# S3 bucket that holds the website files
resource "aws_s3_bucket" "site" {
  bucket        = "meeting-momentum-frontend-calvinwin7"
  force_destroy = true # lets Teardown delete the bucket even if it still has files in it
}

# Turn on static website hosting for the bucket
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

# Allow the bucket to be public (S3 blocks this by default)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Let anyone read the files so the website loads in a browser
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
    }]
  })

  # The public access block has to be turned off before AWS accepts a public policy
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# Upload index.html from the repo root
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.root}/../index.html"
  etag         = filemd5("${path.root}/../index.html") # re-upload when the file changes
  content_type = "text/html"
}

resource "random_id" "vb_upload" {
  byte_length = 2
}

resource "aws_s3_bucket" "vb_upload" {
  bucket        = "svs-deep-upload-${random_id.vb_upload.dec}"
  acl           = "private"
  force_destroy = true

  tags = {
    Name        = "Video bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "vb_trans" {
  bucket        = "svs-deep-transcoded-${random_id.vb_upload.dec}"
  acl           = "private"
  force_destroy = true

  tags = {
    Name        = "Video bucket transcoded"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "vb_trans" {
  bucket = aws_s3_bucket.vb_trans.id

  policy = <<POLICY
{
"Version": "2012-10-17",
"Statement": [
    {
        "Sid": "AddPerm",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "${aws_s3_bucket.vb_trans.arn}/*"
    }
]
}
POLICY
}


resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-et-jobsubmitter"
  role = aws_iam_role.lambda_role.id

  policy = file("iam/lambda-policy.json")
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-et"

  assume_role_policy = file("iam/lambda-assume-policy.json")
}


resource "aws_elastictranscoder_pipeline" "lambda_et" {
  input_bucket = aws_s3_bucket.vb_upload.bucket
  name         = "tf_aws_elastictranscoder_pipeline_lambda"
  role         = aws_iam_role.lambda_role.arn

  content_config {
    bucket        = aws_s3_bucket.vb_trans.bucket
    storage_class = "Standard"
  }

  thumbnail_config {
    bucket        = aws_s3_bucket.vb_trans.bucket
    storage_class = "Standard"
  }
}


resource "aws_lambda_function" "lambda_et" {
  filename          = "src/Lambda-Deployment.zip"
  function_name     = "transcode_video"
  role              = aws_iam_role.lambda_role.arn
  handler           = "index.handler"
  source_code_hash  = filebase64sha256("src/Lambda-Deployment.zip")
  runtime           = "nodejs10.x"
  timeout           = 30
}
resource "random_id" "vb" {
  byte_length = 2
}

resource "aws_s3_bucket" "vb_upload" {
  bucket        = "svs-deep-upload-${random_id.vb.dec}"
  force_destroy = true

  tags = {
    Name        = "Video bucket"
    Environment = "Dev"
  }
}

resource "aws_sns_topic" "transcoder" {
  name = "user-updates-topic"
}

resource "aws_sns_topic_subscription" "transcoder_subscription" {
  topic_arn = aws_sns_topic.transcoder.arn
  protocol  = "sms"
  endpoint  = "+17162398438"
}


resource "aws_s3_bucket" "vb_trans" {
  bucket        = "svs-deep-transcoded-${random_id.vb.dec}"
  force_destroy = true

  tags = {
    Name        = "Video bucket transcoded"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.vb_trans.id

  block_public_policy = false
}


resource "aws_s3_bucket_policy" "vb_trans" {
  bucket = aws_s3_bucket.vb_trans.id
  policy = <<-POLICY
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


resource "aws_iam_role" "lambda_role" {
  name = "lambda-et"

  assume_role_policy = file("iam/lambda-assume-policy.json")
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-et-jobsubmitter"
  role = aws_iam_role.lambda_role.id

  policy = file("iam/lambda-policy.json")
}

# resource "aws_iam_role_policy" "et_s3_policy" {
#   name = "tf_et_s3_access"
#   role = aws_iam_role.s3_role.id

#   policy = <<-POLICY
#   {
#       "Version": "2012-10-17",
#       "Statement": [
#         {
#           "Action": "sts:AssumeRole",
#           "Principal": {
#             "Service": "elastictranscoder.amazonaws.com"
#           },
#           "Effect": "Allow",
#           "Sid": ""
#         }
#       ]
#     }
#   POLICY
# }

# resource "aws_iam_role" "s3_role" {
#   name = "tf_s3_role"
#   assume_role_policy = file("iam/s3-policy.json")
# }


resource "aws_elastictranscoder_pipeline" "lambda_et" {
  input_bucket = aws_s3_bucket.vb_upload.bucket
  name         = "tf_aws_elastictranscoder_pipeline_lambda"
  # role         = aws_iam_role.lambda_role.arn
  role         = aws_iam_role.lambda_role.arn
  # content_config {
  #   bucket        = aws_s3_bucket.vb_trans.bucket
  #   storage_class = "Standard"
  # }
  output_bucket = aws_s3_bucket.vb_trans.bucket
  
  # thumbnail_config {
  #   bucket        = aws_s3_bucket.vb_trans.bucket
  #   storage_class = "Standard"
  # }
}


resource "aws_lambda_function" "lambda_et" {
  filename          = "src/Lambda-Deployment.zip"
  function_name     = "transcode_video"
  role              = aws_iam_role.lambda_role.arn
  handler           = "index.handler"
  source_code_hash  = filebase64sha256("src/Lambda-Deployment.zip")
  runtime           = "nodejs10.x"
  timeout           = 30

  environment {
    variables = {
      ELASTIC_TRANSCODER_REGION = var.aws_region
      ELASTIC_TRANSCODER_PIPELINE_ID = element(split("/", aws_elastictranscoder_pipeline.lambda_et.arn),1)
    }
  }
}


resource "aws_lambda_permission" "allow_vb_upload_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_et.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.vb_upload.arn
}


resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.vb_upload.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_et.arn
    events              = ["s3:ObjectCreated:*"]
    # filter_prefix       = "<_prefix_if_any_dir_in_s3>/"
    # filter_suffix       = "<_suffix_of_file_put_in_s3>"
  }
}
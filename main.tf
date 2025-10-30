terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket
resource "aws_s3_bucket" "uploads" {
  bucket        = var.bucket_name
  force_destroy = true
  tags = {
    Project = var.project_name
    Purpose = "AWS Rekognition Image Label Generator"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table
resource "aws_dynamodb_table" "labels" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_key"

  attribute {
    name = "image_key"
    type = "S"
  }
}

# Lambda packaging
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# IAM role for Lambda
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
  statement {
    sid       = "S3Read"
    actions   = ["s3:GetObject", "s3:GetObjectAttributes"]
    resources = ["${aws_s3_bucket.uploads.arn}/*"]
  }
  statement {
    sid       = "RekognitionDetect"
    actions   = ["rekognition:DetectLabels"]
    resources = ["*"]
  }
  statement {
    sid       = "DDBWrite"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.labels.arn]
  }
}

resource "aws_iam_policy" "lambda_inline" {
  name   = "${var.project_name}-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_inline.arn
}

# Lambda function
resource "aws_lambda_function" "labeler" {
  function_name    = "${var.project_name}-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.main"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.labels.name
    }
  }
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.labeler.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

# S3 event -> Lambda trigger
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.labeler.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

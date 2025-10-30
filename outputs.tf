output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.labels.name
}

output "lambda_name" {
  value = aws_lambda_function.labeler.function_name
}

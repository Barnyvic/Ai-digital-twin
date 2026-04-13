output "api_gateway_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "s3_frontend_bucket" {
  value = aws_s3_bucket.frontend.id
}

output "s3_memory_bucket" {
  value = aws_s3_bucket.memory.id
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

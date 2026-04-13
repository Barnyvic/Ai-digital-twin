variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model ID"
  type        = string
  default     = "global.amazon.nova-2-lite-v1:0"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway rate limit"
  type        = number
  default     = 5
}

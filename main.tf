terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = var.region
  shared_credentials_files = ["./credentials"]
  profile                  = "default"
}

variable "region" {
  description = "The AWS region"
  default     = "eu-central-1"
}

variable "retention" {
  description = "retention of cloudwatch logs in days"
  default     = 7
}

resource "aws_lambda_function" "example_lambda" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "aws_go_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "main"
  runtime          = "go1.x"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256

  environment {
    variables = {
      environment = "development"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "aws_go_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/aws_go_lambda"
  retention_in_days = var.retention
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "./bin"
  output_path = "main.zip"
}

resource "aws_apigatewayv2_api" "example_api" {
  name          = "example-api-gateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.example_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.example_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "example_route" {
  api_id    = aws_apigatewayv2_api.example_api.id
  route_key = "GET /lambda"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.example_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }

  default_route_settings {
    logging_level = "INFO"
    # Total requests at spike
    throttling_burst_limit = 5000
    # Requests per second
    throttling_rate_limit = 10000
  }
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_stage.default_stage.execution_arn}/*/*"
}

resource "aws_iam_role" "apigateway_role" {
  name = "apigateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch_logs_policy" {
  role       = aws_iam_role.apigateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.example_api.name}"
  retention_in_days = var.retention
}

# resource "aws_iam_role_policy" "apigateway_cloudwatch_logs_policy" {
#   name = "apigateway-cloudwatch-logs-policy"
#   role = aws_iam_role.apigateway_cloudwatch_logs_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams",
#         "logs:PutLogEvents",
#         "logs:GetLogEvents",
#         "logs:FilterLogEvents"
#       ],
#       Effect   = "Allow",
#       Resource = "*"
#     }]
#   })
# }

output "api_gateway_invoke_url" {
  value       = "https://${aws_apigatewayv2_api.example_api.id}.execute-api.${var.region}.amazonaws.com/"
  description = "The URL to invoke the API Gateway"
}

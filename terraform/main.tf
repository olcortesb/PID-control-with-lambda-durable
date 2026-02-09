# Data sources for Lambda packaging
data "archive_file" "pid_controller" {
  type        = "zip"
  source_dir  = "${path.module}/.build/pid_controller"
  output_path = "${path.module}/.terraform/pid_controller.zip"
}

data "archive_file" "reactor_simulator" {
  type        = "zip"
  source_dir  = "${path.module}/.build/reactor_simulator"
  output_path = "${path.module}/.terraform/reactor_simulator.zip"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "pid_controller" {
  name              = "/aws/lambda/${var.project_name}-pid-controller"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "reactor_simulator" {
  name              = "/aws/lambda/${var.project_name}-reactor-simulator"
  retention_in_days = var.log_retention_days
}

# IAM Role for PID Controller
resource "aws_iam_role" "pid_controller" {
  name = "${var.project_name}-pid-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pid_controller_durable" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicDurableExecutionRolePolicy"
  role       = aws_iam_role.pid_controller.name
}

resource "aws_iam_role_policy" "pid_controller" {
  name = "${var.project_name}-pid-controller-policy"
  role = aws_iam_role.pid_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.pid_controller.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.reactor_simulator.arn,
          "${aws_lambda_function.reactor_simulator.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Reactor Simulator
resource "aws_iam_role" "reactor_simulator" {
  name = "${var.project_name}-reactor-simulator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reactor_simulator_durable" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicDurableExecutionRolePolicy"
  role       = aws_iam_role.reactor_simulator.name
}

resource "aws_iam_role_policy" "reactor_simulator" {
  name = "${var.project_name}-reactor-simulator-policy"
  role = aws_iam_role.reactor_simulator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.reactor_simulator.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function - PID Controller (Durable)
resource "aws_lambda_function" "pid_controller" {
  filename         = data.archive_file.pid_controller.output_path
  function_name    = "${var.project_name}-pid-controller"
  role             = aws_iam_role.pid_controller.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  source_code_hash = data.archive_file.pid_controller.output_base64sha256
  publish          = true

  durable_config {
    execution_timeout = var.durable_execution_timeout
    retention_period  = var.log_retention_days
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.pid_controller.name
  }

  environment {
    variables = {
      REACTOR_FUNCTION_NAME = "${aws_lambda_function.reactor_simulator.function_name}:prod"
      KP                    = var.kp
      KI                    = var.ki
      KD                    = var.kd
      SAMPLE_TIME           = var.sample_time
      MAX_ITERATIONS        = var.max_iterations
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.pid_controller,
    aws_iam_role_policy_attachment.pid_controller_durable
  ]
}

resource "aws_lambda_alias" "pid_controller_prod" {
  name             = "prod"
  function_name    = aws_lambda_function.pid_controller.function_name
  function_version = aws_lambda_function.pid_controller.version
}

# Lambda Function - Reactor Simulator (Durable)
resource "aws_lambda_function" "reactor_simulator" {
  filename         = data.archive_file.reactor_simulator.output_path
  function_name    = "${var.project_name}-reactor-simulator"
  role             = aws_iam_role.reactor_simulator.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  source_code_hash = data.archive_file.reactor_simulator.output_base64sha256
  publish          = true

  durable_config {
    execution_timeout = var.lambda_timeout
    retention_period  = var.log_retention_days
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.reactor_simulator.name
  }

  environment {
    variables = {
      AMBIENT_TEMP        = var.ambient_temp
      COOLING_RATE        = var.cooling_rate
      HEATING_EFFICIENCY  = "1.0"
      THERMAL_INERTIA     = "0.18"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.reactor_simulator,
    aws_iam_role_policy_attachment.reactor_simulator_durable
  ]
}

resource "aws_lambda_alias" "reactor_simulator_prod" {
  name             = "prod"
  function_name    = aws_lambda_function.reactor_simulator.function_name
  function_version = aws_lambda_function.reactor_simulator.version
}

# API Gateway
resource "aws_apigatewayv2_api" "pid_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.pid_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "pid_controller" {
  api_id           = aws_apigatewayv2_api.pid_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_alias.pid_controller_prod.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "setpoint" {
  api_id    = aws_apigatewayv2_api.pid_api.id
  route_key = "POST /setpoint"
  target    = "integrations/${aws_apigatewayv2_integration.pid_controller.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pid_controller.function_name
  qualifier     = aws_lambda_alias.pid_controller_prod.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pid_api.execution_arn}/*/*"
}

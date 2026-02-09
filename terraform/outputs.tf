output "api_endpoint" {
  description = "API Gateway endpoint URL for setpoint"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/setpoint"
}

output "pid_controller_function_name" {
  description = "PID Controller Lambda function name"
  value       = aws_lambda_function.pid_controller.function_name
}

output "reactor_simulator_function_name" {
  description = "Reactor Simulator Lambda function name"
  value       = aws_lambda_function.reactor_simulator.function_name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.pid_control.dashboard_name}"
}

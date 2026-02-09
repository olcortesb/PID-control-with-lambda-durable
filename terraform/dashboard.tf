# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "pid_control" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["PIDControl-v2", "SetpointTemperature", { stat = "Average", label = "Setpoint (SP)", color = "#FF0000" }],
            [".", "ActualTemperature", { stat = "Average", label = "Process Variable (PV)", color = "#0000FF" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "PID Control - Temperature"
          period  = 60
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["PIDControl-v2", "TemperatureError", { stat = "Average", label = "Error", color = "#FF9900" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "PID Control - Error"
          period  = 60
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      }
    ]
  })
}

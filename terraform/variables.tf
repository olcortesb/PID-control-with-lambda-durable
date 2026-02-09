variable "ambient_temp" {
  description = "Ambient temperature"
  type        = string
  default     = "20.0"
}

variable "aws_profile" {
  description = "AWS Profile"
  type        = string
  default     = "olcb-terraform"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "cooling_rate" {
  description = "Cooling rate"
  type        = string
  default     = "0.05"
}

variable "kd" {
  description = "PID Derivative gain"
  type        = string
  default     = "0.20"
}

variable "ki" {
  description = "PID Integral gain"
  type        = string
  default     = "0.0004"
}

variable "kp" {
  description = "PID Proportional gain"
  type        = string
  default     = "0.50"
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 900
}

variable "durable_execution_timeout" {
  description = "Durable execution timeout in seconds"
  type        = number
  default     = 3600
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "max_iterations" {
  description = "Maximum number of PID control iterations"
  type        = string
  default     = "40"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "pid-control"
}

variable "sample_time" {
  description = "Sample time in seconds"
  type        = string
  default     = "30"
}

# PID Control with AWS Lambda Durable Functions

Proof of concept implementing a PID controller and reactor simulator using AWS Lambda Durable Functions with persistent state management.

## Overview

This project demonstrates:
- PID control loop with state persistence using Lambda Durable Functions
- Reactor simulation with thermal dynamics
- Zero-cost waiting between iterations using `context.wait()`
- Automatic checkpointing and recovery
- Local simulation for parameter tuning

## Architecture

```
API Gateway → PID Controller Lambda (Durable)
                ├─ calculate_pid (step)
                ├─ invoke_reactor (step) → Reactor Lambda (Durable)
                ├─ publish_metrics (step)
                └─ context.wait() [NO COST]
```

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── src/
│   │   ├── pid_controller/    # PID Lambda with durable execution
│   │   └── reactor_simulator/ # Reactor Lambda with durable execution
│   ├── main.tf               # Lambda functions, API Gateway, IAM
│   ├── variables.tf          # Configurable parameters
│   └── build_lambdas.sh      # Build script
│
└── simulation/            # Local PID simulator
    ├── simulate_pid.py       # Python simulator (same equations as Lambda)
    ├── .env.example          # Configuration template
    └── outputs/              # Generated graphs
```

## Quick Start

### 1. Local Simulation

Test PID parameters before deploying:

```bash
cd simulation
cp .env.example .env
# Edit .env with desired parameters
./run_simulation.sh
```

Generates graph: `outputs/pid_kp{KP}_ki{KI}_kd{KD}_*.png`

### 2. Deploy to AWS

```bash
cd terraform

# Build Lambda packages
./build_lambdas.sh

# Deploy infrastructure
terraform init
terraform plan
terraform apply

# Get API endpoint
terraform output api_endpoint
```

### 3. Test PID Control

```bash
curl -X POST https://{api-endpoint}/prod/setpoint \
  -H "Content-Type: application/json" \
  -d '{"setpoint": 75.0}'
```

Response:
```json
{
  "message": "PID control completed - 40 iterations",
  "final_temperature": 74.82,
  "setpoint": 75.0,
  "iterations": 40
}
```

## Configuration

### PID Parameters (terraform/variables.tf)

```hcl
kp = "0.50"      # Proportional gain
ki = "0.0004"    # Integral gain
kd = "0.20"      # Derivative gain
sample_time = "60"        # Seconds between iterations
max_iterations = "40"     # Control loop iterations
```

### Reactor Parameters

```hcl
ambient_temp = "20.0"     # Ambient temperature (°C)
cooling_rate = "0.05"     # Cooling rate coefficient
thermal_inertia = "0.18"  # Thermal inertia (0-1)
```

## Lambda Durable Functions

### Key Features

- **context.wait()**: Suspends execution without compute charges
- **context.step()**: Automatic checkpointing for each step
- **State persistence**: No need for DynamoDB/SQS
- **Automatic recovery**: Resumes from last checkpoint on failure

### Configuration

```hcl
durable_config {
  execution_timeout = 3600  # 1 hour max
  retention_period  = 7     # 7 days state retention
}
```

### IAM Policy Required

```hcl
policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicDurableExecutionRolePolicy"
```

## Monitoring

### CloudWatch Metrics

Namespace: `PIDControl-v2`

- `SetpointTemperature`: Target temperature
- `ActualTemperature`: Current reactor temperature
- `TemperatureError`: Absolute error

### CloudWatch Logs

- `/aws/lambda/{project}-pid-controller`
- `/aws/lambda/{project}-reactor-simulator`

## Cost Optimization

**Without Durable Functions:**
- 40 iterations × 60s = 40 minutes continuous execution

**With Durable Functions:**
- ~5 seconds actual compute time
- `context.wait()` = $0 during 40 minutes of waiting

## Cleanup

```bash
cd terraform
terraform destroy
```

## Technical Details

### PID Algorithm (Discrete Parallel Form)

```python
error = setpoint - current_temp
integral += error * SAMPLE_TIME
derivative = (error - last_error) / SAMPLE_TIME
cv = Kp * error + Ki * integral + Kd * derivative
cv = max(0, min(100, cv))
```

### Reactor Physics

```python
cooling = (temp - AMBIENT_TEMP) * COOLING_RATE
heating = control_value * HEATING_EFFICIENCY
temp_change = heating - cooling
new_temp = temp + temp_change * (1 - THERMAL_INERTIA)
```

## Requirements

- **AWS Account** with Lambda Durable Functions enabled
- **Terraform** >= 1.0
- **Python** 3.13
- **Docker** (for local simulation)

## Limitations

- Max execution timeout: 3600 seconds (1 hour)
- Max payload size: 256 KB per step
- Max retention period: 90 days
- Not suitable for real-time control (< 1 second latency)

## References

- [AWS Lambda Durable Functions](https://docs.aws.amazon.com/lambda/latest/dg/durable-getting-started.html)
- [SDK Python](https://pypi.org/project/aws-durable-execution-sdk-python/)
- Article: [Link to be published]

## License

MIT

## Author

Oscar Cortés

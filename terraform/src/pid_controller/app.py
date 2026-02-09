import json
import os
import boto3
from aws_lambda_powertools import Logger
from aws_durable_execution_sdk_python import (
    DurableContext,
    durable_execution,
    durable_step,
)
from aws_durable_execution_sdk_python.config import Duration

logger = Logger()
lambda_client = boto3.client('lambda')
cloudwatch = boto3.client('cloudwatch')

REACTOR_FUNCTION_NAME = os.environ['REACTOR_FUNCTION_NAME']
KP = float(os.environ.get('KP', '2.0'))
KI = float(os.environ.get('KI', '0.5'))
KD = float(os.environ.get('KD', '1.0'))
SAMPLE_TIME = float(os.environ.get('SAMPLE_TIME', '60.0'))
MAX_ITERATIONS = int(os.environ.get('MAX_ITERATIONS', '40'))

@durable_step
def calculate_pid(step_context, setpoint, current_temp, integral, last_error):
    error = setpoint - current_temp
    integral += error * SAMPLE_TIME
    derivative = (error - last_error) / SAMPLE_TIME
    
    cv = KP * error + KI * integral + KD * derivative
    cv = max(0, min(100, cv))
    
    return {'cv': cv, 'integral': integral, 'error': error}

@durable_step
def invoke_reactor(step_context, cv, setpoint, current_temp):
    response = lambda_client.invoke(
        FunctionName=REACTOR_FUNCTION_NAME,
        InvocationType='RequestResponse',
        Payload=json.dumps({
            'control_value': cv,
            'setpoint': setpoint,
            'current_temp': current_temp
        })
    )
    return json.loads(response['Payload'].read())

@durable_step
def publish_metrics(step_context, setpoint, actual_temp, iteration):
    import time
    timestamp = int(time.time())
    
    cloudwatch.put_metric_data(
        Namespace='PIDControl-v2',
        MetricData=[
            {
                'MetricName': 'SetpointTemperature',
                'Value': setpoint,
                'Unit': 'None',
                'Timestamp': timestamp
            },
            {
                'MetricName': 'ActualTemperature',
                'Value': actual_temp,
                'Unit': 'None',
                'Timestamp': timestamp
            },
            {
                'MetricName': 'TemperatureError',
                'Value': abs(setpoint - actual_temp),
                'Unit': 'None',
                'Timestamp': timestamp
            }
        ]
    )
    return True

@durable_execution
def lambda_handler(event, context: DurableContext):
    setpoint = event.get('setpoint', 50.0)
    
    logger.info(f"Starting PID control loop with setpoint={setpoint}")
    
    integral = 0.0
    last_error = 0.0
    current_temp = 20.0
    
    for iteration in range(MAX_ITERATIONS):
        pid_result = context.step(calculate_pid(setpoint, current_temp, integral, last_error))
        cv = pid_result['cv']
        integral = pid_result['integral']
        last_error = pid_result['error']
        
        logger.info(f"Iteration {iteration}: Setpoint={setpoint:.2f}, Temp={current_temp:.2f}, CV={cv:.2f}")
        
        reactor_data = context.step(invoke_reactor(cv, setpoint, current_temp))
        current_temp = reactor_data['temperature']
        
        context.step(publish_metrics(setpoint, current_temp, iteration))
        
        if iteration < MAX_ITERATIONS - 1:
            context.wait(Duration.from_seconds(SAMPLE_TIME))
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'PID control completed - {MAX_ITERATIONS} iterations',
            'final_temperature': current_temp,
            'setpoint': setpoint,
            'iterations': MAX_ITERATIONS
        })
    }

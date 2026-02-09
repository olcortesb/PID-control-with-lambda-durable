import json
import os
from aws_lambda_powertools import Logger
from aws_durable_execution_sdk_python import (
    DurableContext,
    durable_execution,
    durable_step,
)

logger = Logger()

AMBIENT_TEMP = float(os.environ.get('AMBIENT_TEMP', '20.0'))
COOLING_RATE = float(os.environ.get('COOLING_RATE', '0.05'))
HEATING_EFFICIENCY = float(os.environ.get('HEATING_EFFICIENCY', '1.0'))
THERMAL_INERTIA = float(os.environ.get('THERMAL_INERTIA', '0.18'))

@durable_step
def simulate_reactor_step(step_context, current_temp, control_value, dt):
    # Enfriamiento natural hacia temperatura ambiente (Newton's law of cooling)
    cooling = (current_temp - AMBIENT_TEMP) * COOLING_RATE
    
    # Calentamiento por control value (0-100) - potencia de calentamiento
    heating = control_value * HEATING_EFFICIENCY
    
    # Cambio de temperatura por segundo
    temp_change = heating - cooling
    
    # Aplicar inercia térmica (el reactor no cambia instantáneamente)
    new_temp = current_temp + temp_change * (1 - THERMAL_INERTIA)
    
    return max(AMBIENT_TEMP, new_temp)

@durable_execution
def lambda_handler(event, context: DurableContext):
    control_value = event.get('control_value', 0)
    current_temp = event.get('current_temp', AMBIENT_TEMP)
    dt = 60.0  # 1 minuto
    
    new_temp = context.step(simulate_reactor_step(current_temp, control_value, dt))
    
    logger.info(f"Reactor: CV={control_value:.2f}, Temp={new_temp:.2f}, Ambient={AMBIENT_TEMP}")
    
    return {
        'statusCode': 200,
        'temperature': new_temp
    }

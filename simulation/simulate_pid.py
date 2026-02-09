#!/usr/bin/env python3
"""
Simulador de Control PID con Reactor
Genera gráficas de respuesta del sistema basado en parámetros configurables
"""

import matplotlib.pyplot as plt
import os
from pathlib import Path

# Cargar .env si existe
env_file = Path(__file__).parent / '.env'
if env_file.exists():
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                key, value = line.split('=', 1)
                os.environ.setdefault(key, value)

# ============================================================================
# PARÁMETROS CONFIGURABLES (desde variables de entorno)
# ============================================================================

# Parámetros PID
KP = float(os.getenv('KP', '0.50'))
KI = float(os.getenv('KI', '0.0004'))
KD = float(os.getenv('KD', '0.20'))

# Parámetros del Reactor
AMBIENT_TEMP = float(os.getenv('AMBIENT_TEMP', '20.0'))
COOLING_RATE = float(os.getenv('COOLING_RATE', '0.05'))
HEATING_EFFICIENCY = float(os.getenv('HEATING_EFFICIENCY', '1.0'))
THERMAL_INERTIA = float(os.getenv('THERMAL_INERTIA', '0.18'))

# Parámetros de Simulación
SETPOINT = float(os.getenv('SETPOINT', '75.0'))
INITIAL_TEMP = float(os.getenv('INITIAL_TEMP', '20.0'))
SAMPLE_TIME = int(os.getenv('SAMPLE_TIME', '30'))
MAX_ITERATIONS = int(os.getenv('MAX_ITERATIONS', '40'))
OUTPUT_FILE = os.getenv('OUTPUT_FILE', 'pid_simulation.png')

# ============================================================================
# SIMULACIÓN
# ============================================================================

def simulate_reactor(current_temp, control_value):
    """Simula el comportamiento del reactor"""
    cooling = (current_temp - AMBIENT_TEMP) * COOLING_RATE
    heating = control_value * HEATING_EFFICIENCY
    temp_change = heating - cooling
    new_temp = current_temp + temp_change * (1 - THERMAL_INERTIA)
    return max(AMBIENT_TEMP, new_temp)

def calculate_pid(error, integral, last_error):
    """Calcula la salida del controlador PID"""
    integral += error * SAMPLE_TIME
    derivative = (error - last_error) / SAMPLE_TIME
    cv = KP * error + KI * integral + KD * derivative
    cv = max(0, min(100, cv))
    return cv, integral, error

# Inicialización
temps = [INITIAL_TEMP]
errors = []
cvs = []
setpoints = []

integral = 0.0
last_error = 0.0
current_temp = INITIAL_TEMP

# Simulación
for i in range(MAX_ITERATIONS):
    error = SETPOINT - current_temp
    cv, integral, last_error = calculate_pid(error, integral, last_error)
    
    current_temp = simulate_reactor(current_temp, cv)
    
    temps.append(current_temp)
    errors.append(abs(error))
    cvs.append(cv)
    setpoints.append(SETPOINT)

# ============================================================================
# GRÁFICAS
# ============================================================================

iterations = list(range(MAX_ITERATIONS + 1))
time_minutes = [i * SAMPLE_TIME / 60 for i in iterations]

fig, ax = plt.subplots(figsize=(14, 8))

# Gráfica: Temperatura (PV vs SP)
ax.plot(time_minutes, temps, 'b-', linewidth=2.5, label='Process Variable (PV)', marker='o', markersize=4)
ax.plot(time_minutes[:-1], setpoints, 'r--', linewidth=2, label='Setpoint (SP)')
ax.axhline(y=SETPOINT, color='r', linestyle=':', alpha=0.3)
ax.set_xlabel('Tiempo (minutos)', fontsize=12)
ax.set_ylabel('Temperatura (°C)', fontsize=12, color='b')
ax.set_title(f'Sistema de Control PID - Kp={KP}, Ki={KI}, Kd={KD}, TI={THERMAL_INERTIA}', fontsize=14, fontweight='bold')
ax.grid(True, alpha=0.3)
ax.tick_params(axis='y', labelcolor='b')

# Segundo eje Y para Error
ax2 = ax.twinx()
ax2.plot(time_minutes[:-1], errors, 'orange', linewidth=2, label='Error Absoluto', marker='s', markersize=3, alpha=0.7)
ax2.set_ylabel('Error Absoluto (°C)', fontsize=12, color='orange')
ax2.tick_params(axis='y', labelcolor='orange')

# Tercer eje Y para CV
ax3 = ax.twinx()
ax3.spines['right'].set_position(('outward', 60))
ax3.plot(time_minutes[:-1], cvs, 'green', linewidth=2, label='Control Value', marker='^', markersize=3, alpha=0.7)
ax3.set_ylabel('Control Value (%)', fontsize=12, color='green')
ax3.tick_params(axis='y', labelcolor='green')

# Leyendas combinadas
lines1, labels1 = ax.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
lines3, labels3 = ax3.get_legend_handles_labels()
ax.legend(lines1 + lines2 + lines3, labels1 + labels2 + labels3, loc='upper right', fontsize=10)

plt.tight_layout()
plt.savefig(OUTPUT_FILE, dpi=300, bbox_inches='tight')
print(f"✅ Gráfica guardada: {OUTPUT_FILE}")

print(f"\n📊 Estadísticas de la Simulación:")
print(f"   Setpoint: {SETPOINT}°C")
print(f"   Temperatura inicial: {INITIAL_TEMP}°C")
print(f"   Temperatura final: {temps[-1]:.2f}°C")
print(f"   Error final: {abs(SETPOINT - temps[-1]):.2f}°C")
print(f"   Overshoot máximo: {max(temps) - SETPOINT:.2f}°C")
print(f"   Tiempo total: {MAX_ITERATIONS * SAMPLE_TIME / 60:.1f} minutos")
print(f"\n🎯 Parámetros PID: Kp={KP}, Ki={KI}, Kd={KD}")
print(f"⚙️  Reactor: Inercia={THERMAL_INERTIA}, Enfriamiento={COOLING_RATE}")

plt.show()

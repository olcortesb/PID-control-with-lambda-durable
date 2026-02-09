# Simulador PID - Análisis y Visualización

Herramienta de simulación para analizar el comportamiento del sistema de control PID antes del despliegue en AWS Lambda.

## Ecuaciones Implementadas

### Control PID (Forma Paralela Discreta)

```
error = Setpoint - PV(t)

P = Kp × error
I = Ki × Σ(error × SAMPLE_TIME)
D = Kd × (error - last_error) / SAMPLE_TIME

CV = P + I + D
CV = max(0, min(100, CV))
```

### Física del Reactor

```
cooling = (temp - AMBIENT_TEMP) × COOLING_RATE
heating = CV × HEATING_EFFICIENCY
temp_change = heating - cooling
new_temp = temp + temp_change × (1 - THERMAL_INERTIA)
```

## Estructura

```
simulation/
├── .env                      # Parámetros de simulación
├── .env.example             # Plantilla de configuración
├── simulate_pid.py          # Script principal de simulación
├── Dockerfile               # Contenedor Python 3.13
├── requirements.txt         # matplotlib, numpy
├── run_simulation.sh        # Ejecuta simulación con Docker
├── generate_responses.sh    # Genera 3 tipos de respuesta
└── outputs/                 # Gráficas generadas
```

## Configuración (.env)

```bash
# Parámetros PID
KP=0.50                    # Ganancia proporcional
KI=0.0004                  # Ganancia integral
KD=0.20                    # Ganancia derivativa

# Parámetros del Reactor
AMBIENT_TEMP=20.0          # Temperatura ambiente (°C)
COOLING_RATE=0.05          # Tasa de enfriamiento
HEATING_EFFICIENCY=1.0     # Eficiencia de calentamiento
THERMAL_INERTIA=0.18       # Inercia térmica (0-1)

# Parámetros de Simulación
SETPOINT=75.0              # Temperatura objetivo (°C)
INITIAL_TEMP=20.0          # Temperatura inicial (°C)
SAMPLE_TIME=30             # Tiempo de muestreo (segundos)
MAX_ITERATIONS=40          # Número de iteraciones
```

## Uso

### Simulación Individual

```bash
# Editar parámetros
vim .env

# Ejecutar simulación
./run_simulation.sh
```

**Salida:** `outputs/pid_kp{KP}_ki{KI}_kd{KD}_ti{TI}_st{ST}_iter{ITER}_sp{SP}.png`

### Tres Tipos de Respuesta

```bash
./generate_responses.sh
```

Genera automáticamente tres simulaciones que demuestran los diferentes comportamientos de amortiguamiento del sistema PID:

#### 1. Subamortiguada (Underdamped)

**Parámetros:**
```bash
KP=1.2
KI=0.002
KD=0.1
THERMAL_INERTIA=0.18
```

**Comportamiento:**
- Sistema con alta ganancia proporcional (Kp) y baja derivativa (Kd)
- Respuesta rápida pero con oscilaciones pronunciadas
- Overshoot significativo antes de estabilizarse
- Múltiples cruces del setpoint

**Objetivo:** Mostrar cómo un PID agresivo puede causar inestabilidad y oscilaciones no deseadas en el sistema.

![Respuesta Subamortiguada](outputs/underdamped.png)

---

#### 2. Críticamente Amortiguada (Critically Damped)

**Parámetros:**
```bash
KP=0.50
KI=0.0004
KD=0.20
THERMAL_INERTIA=0.18
```

**Comportamiento:**
- Balance óptimo entre velocidad de respuesta y estabilidad
- Converge rápidamente al setpoint sin oscilaciones significativas
- Overshoot mínimo (~2°C)
- Tiempo de establecimiento: ~10 iteraciones (5 minutos)

**Objetivo:** Demostrar la configuración óptima del PID que alcanza el setpoint de manera eficiente sin comportamiento oscilatorio. Esta es la configuración desplegada en las Lambdas de producción.

![Respuesta Críticamente Amortiguada](outputs/critically_damped.png)

---

#### 3. Sobreamortiguada (Overdamped)

**Parámetros:**
```bash
KP=0.20
KI=0.0001
KD=0.30
THERMAL_INERTIA=0.18
```

**Comportamiento:**
- Ganancias conservadoras con alta derivativa (Kd)
- Respuesta muy lenta y suave
- Sin overshoot ni oscilaciones
- Tarda mucho más en alcanzar el setpoint

**Objetivo:** Ilustrar cómo un PID demasiado conservador sacrifica velocidad de respuesta por estabilidad, resultando en un sistema lento que puede no ser adecuado para aplicaciones que requieren respuesta rápida.

![Respuesta Sobreamortiguada](outputs/overdamped.png)

---

**Salidas:**
- `outputs/underdamped.png`
- `outputs/critically_damped.png`
- `outputs/overdamped.png`

### Comparación de Comportamientos

| Tipo | Velocidad | Overshoot | Oscilaciones | Uso Recomendado |
|------|-----------|-----------|--------------|------------------|
| Subamortiguada | Rápida | Alto | Sí | Sistemas que toleran oscilaciones |
| Críticamente Amortiguada | Óptima | Mínimo | No | Aplicaciones de producción (recomendado) |
| Sobreamortiguada | Lenta | Ninguno | No | Sistemas críticos que no toleran overshoot |

## Gráfica Generada

La visualización combina tres métricas en una sola gráfica:

- **Eje Y izquierdo (azul):** Temperatura PV vs SP
- **Eje Y derecho (naranja):** Error absoluto
- **Eje Y derecho externo (verde):** Control Value (CV)

Todas comparten el eje X (tiempo en minutos).

## Validación de Ecuaciones

Las ecuaciones implementadas fueron validadas contra:

1. **Forma Paralela Estándar del PID Discreto**
   - Fuente: Literatura académica de control
   - Método: Euler discretization

2. **MathWorks PID Controller**
   - Forma paralela: `u(t) = Kp×e(t) + Ki×∫e(τ)dτ + Kd×de/dt`
   - Discretización: Suma de Riemann para integral, diferencia finita para derivada

3. **Física del Reactor**
   - Ley de enfriamiento de Newton
   - Balance energético: calentamiento - enfriamiento
   - Inercia térmica: resistencia al cambio de temperatura

## Equivalencia con Lambda

Este simulador usa **exactamente las mismas ecuaciones** que las Lambdas desplegadas:

| Componente | Simulación | Lambda |
|------------|-----------|--------|
| PID | `simulate_pid.py` | `terraform/src/pid_controller/app.py` |
| Reactor | `simulate_pid.py` | `terraform/src/reactor_simulator/app.py` |
| Parámetros | `.env` | `terraform/variables.tf` |

**Diferencias:**
- Simulación: Ejecución local, gráficas matplotlib
- Lambda: AWS Durable Functions, métricas CloudWatch

## Análisis de Convergencia

### Equilibrio del Sistema

Para temperatura objetivo de 75°C:

```
En equilibrio: heating = cooling
CV × HEATING_EFFICIENCY = (75 - 20) × COOLING_RATE
CV × 1.0 = 55 × 0.05
CV = 2.75%
```

El PID debe converger a CV ≈ 2.75% para mantener 75°C.

### Tiempo de Establecimiento

Con parámetros críticamente amortiguados:
- **10 iteraciones** (~5 minutos con SAMPLE_TIME=30s)
- **Overshoot:** ~2°C
- **Error final:** <0.5°C

## Requisitos

- Docker
- Bash

## Referencias

- [Control PID - Wikipedia](https://en.wikipedia.org/wiki/PID_controller)
- [MathWorks PID Controller](https://www.mathworks.com/help/control/ref/pid.html)
- [Discrete-Time PID](https://en.wikipedia.org/wiki/PID_controller#Discrete_implementation)

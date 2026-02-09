#!/bin/bash

# Cargar .env para generar nombre de archivo
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Nombre de imagen y archivo de salida
IMAGE_NAME="pid-sim"
OUTPUT_DIR="./outputs"
OUTPUT_FILE="pid_kp${KP}_ki${KI}_kd${KD}_ti${THERMAL_INERTIA}_st${SAMPLE_TIME}_iter${MAX_ITERATIONS}_sp${SETPOINT}.png"

mkdir -p "$OUTPUT_DIR"

echo "🔨 Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

echo "🚀 Running simulation..."
docker run --rm \
  -v "$(pwd)/$OUTPUT_DIR:/app/outputs" \
  -e OUTPUT_FILE="/app/outputs/$OUTPUT_FILE" \
  "$IMAGE_NAME"

echo "✅ Done! Output: $OUTPUT_DIR/$OUTPUT_FILE"

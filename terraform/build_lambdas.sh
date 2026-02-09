#!/bin/bash
set -e

echo "Building Lambda packages with Docker (Python 3.13)..."

# Build PID Controller
echo "Building PID Controller..."
rm -rf .build/pid_controller
mkdir -p .build/pid_controller

docker run --rm \
  -v "$(pwd)/src/pid_controller:/src" \
  -v "$(pwd)/.build/pid_controller:/build" \
  python:3.13-slim \
  bash -c "pip install -r /src/requirements.txt -t /build --quiet && cp /src/app.py /build/"

# Build Reactor Simulator
echo "Building Reactor Simulator..."
rm -rf .build/reactor_simulator
mkdir -p .build/reactor_simulator

docker run --rm \
  -v "$(pwd)/src/reactor_simulator:/src" \
  -v "$(pwd)/.build/reactor_simulator:/build" \
  python:3.13-slim \
  bash -c "pip install -r /src/requirements.txt -t /build --quiet && cp /src/app.py /build/"

echo "Lambda packages built successfully!"

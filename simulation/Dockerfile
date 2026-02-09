FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY .env* ./
COPY simulate_pid.py .

CMD ["python", "simulate_pid.py"]

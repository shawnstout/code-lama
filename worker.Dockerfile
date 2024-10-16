FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "worker.py"]
FROM python:3.9-slim

WORKDIR /app

# Copy requirements file
COPY worker-ai-requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r worker-ai-requirements.txt

# Copy the CodeLlama model files (adjust the source path as needed)
COPY ./models/codellama /models/codellama

# Copy the worker script
COPY worker-ai-script.py .

CMD ["python", "worker-ai-script.py"]

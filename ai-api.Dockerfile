# This Dockerfile sets up an environment for a CodeLlama API service
FROM python:3.9-slim

WORKDIR /app

COPY ai-api-requirements.txt .
RUN pip install --no-cache-dir -r ai-api-requirements.txt

COPY . .

# The api.py file should implement the CodeLlama API
CMD ["python", "api.py"]

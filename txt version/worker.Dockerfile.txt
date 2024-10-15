FROM nvidia/cuda:12.6.0-base-ubuntu22.04

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl https://ollama.ai/install.sh | sh

COPY worker-ai-script.py .

RUN pip3 install --no-cache-dir pika requests torch transformers numpy pandas

CMD ["python3", "worker-ai-script.py"]








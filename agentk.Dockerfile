FROM python:3.9-slim

WORKDIR /app

COPY agentk-requirements.txt .
RUN pip install --no-cache-dir -r agentk-requirements.txt

COPY . .

CMD ["python", "agentk-app.py"]

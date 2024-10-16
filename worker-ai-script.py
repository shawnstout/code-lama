import pika
import json
import os
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

# Load CodeLlama model and tokenizer
model_path = "/models/codellama"  # Adjust this path as needed
tokenizer = AutoTokenizer.from_pretrained(model_path)
model = AutoModelForCausalLM.from_pretrained(model_path)

# RabbitMQ connection
rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
connection = pika.BlockingConnection(pika.ConnectionParameters(host=rabbitmq_host))
channel = connection.channel()
channel.queue_declare(queue='task_queue', durable=True)

def process_task(task):
    prompt = task.get('prompt', '')
    
    input_ids = tokenizer.encode(prompt, return_tensors='pt')
    with torch.no_grad():
        output = model.generate(input_ids, max_length=100, num_return_sequences=1)
    
    generated_code = tokenizer.decode(output[0], skip_special_tokens=True)
    return generated_code

def callback(ch, method, properties, body):
    task = json.loads(body)
    print(f" [x] Received task: {task}")
    
    result = process_task(task)
    
    print(f" [x] Task processed. Result: {result}")
    
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_qos(prefetch_count=1)
channel.basic_consume(queue='task_queue', on_message_callback=callback)

print(' [*] Waiting for tasks. To exit press CTRL+C')
channel.start_consuming()

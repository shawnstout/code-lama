import pika
import json
import requests
import os
import time

# RabbitMQ connection
rabbitmq_host = os.environ.get('RABBITMQ_HOST', 'localhost')
max_retries = 5
retry_delay = 5  # seconds

def connect_to_rabbitmq():
    for attempt in range(max_retries):
        try:
            connection = pika.BlockingConnection(pika.ConnectionParameters(host=rabbitmq_host))
            channel = connection.channel()
            channel.queue_declare(queue='ai_tasks')
            return connection, channel
        except pika.exceptions.AMQPConnectionError:
            if attempt < max_retries - 1:
                print(f"Failed to connect to RabbitMQ. Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
            else:
                raise

connection, channel = connect_to_rabbitmq()

# Ollama API
ollama_api_base_url = os.environ.get('OLLAMA_API_BASE_URL', 'http://localhost:11434')

def process_task(ch, method, properties, body):
    task = json.loads(body)
    input_text = task['input']
    topic = task['topic']

    # Process with Ollama
    response = requests.post(f"{ollama_api_base_url}/api/generate", 
                             json={"model": "codellama", "prompt": input_text})
    
    result = response.json()['response']

    # Update task status in Supabase (you'd need to implement this part)
    # update_task_status(task_id, 'completed', result)

    print(f"Processed task: {input_text}")
    print(f"Result: {result}")

channel.basic_consume(queue='ai_tasks', on_message_callback=process_task, auto_ack=True)

print('Worker AI waiting for tasks. To exit press CTRL+C')
channel.start_consuming()import pika
import json
import time

def connect_to_rabbitmq():
    """Establish a connection to RabbitMQ."""
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='task_queue', durable=True)
    channel.queue_declare(queue='result_queue', durable=True)
    return connection, channel

def process_task(ch, method, properties, body):
    """Process the task received from the queue."""
    task = json.loads(body)
    print(f" [x] Received task: {task}")
    
    # Simulate AI processing
    time.sleep(5)
    
    result = {
        'input': task['input'],
        'output': f"Processed: {task['input']}",
        'timestamp': time.time()
    }
    
    ch.basic_publish(
        exchange='',
        routing_key='result_queue',
        body=json.dumps(result),
        properties=pika.BasicProperties(
            delivery_mode=2,  # make message persistent
        ))
    
    print(f" [x] Sent result: {result}")
    ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    connection, channel = connect_to_rabbitmq()
    
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='task_queue', on_message_callback=process_task)
    
    print(' [*] Waiting for tasks. To exit press CTRL+C')
    channel.start_consuming()

if __name__ == "__main__":
    main()

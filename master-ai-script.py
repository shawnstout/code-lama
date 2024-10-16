import pika
import json
import requests
from supabase import create_client, Client
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

# Supabase connection
supabase_url = os.environ.get('SUPABASE_URL')
supabase_key = os.environ.get('SUPABASE_KEY')
supabase: Client = create_client(supabase_url, supabase_key)

def process_user_input(input_text, topic):
    # Send task to queue
    message = json.dumps({'input': input_text, 'topic': topic})
    channel.basic_publish(exchange='', routing_key='ai_tasks', body=message)
    
    # Log task to Supabase
    supabase.table('ai_tasks').insert({'input': input_text, 'topic': topic, 'status': 'queued'}).execute()

def get_results():
    # Fetch completed tasks from Supabase
    response = supabase.table('ai_tasks').select('*').eq('status', 'completed').execute()
    return response.data

# Example usage
process_user_input("What is the capital of France?", "Geography")
results = get_results()
print(results)

# Close connection
connection.close()import pika
import json
import time

def connect_to_rabbitmq():
    """Establish a connection to RabbitMQ."""
    connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
    channel = connection.channel()
    channel.queue_declare(queue='task_queue', durable=True)
    channel.queue_declare(queue='result_queue', durable=True)
    return connection, channel

def process_user_input(input_text, topic):
    """Process user input and send task to worker."""
    connection, channel = connect_to_rabbitmq()
    
    task = {
        'input': input_text,
        'topic': topic,
        'timestamp': time.time()
    }
    
    channel.basic_publish(
        exchange='',
        routing_key='task_queue',
        body=json.dumps(task),
        properties=pika.BasicProperties(
            delivery_mode=2,  # make message persistent
        ))
    
    print(f" [x] Sent task: {task}")
    connection.close()

def get_results():
    """Retrieve results from the result queue."""
    connection, channel = connect_to_rabbitmq()
    
    method_frame, header_frame, body = channel.basic_get(queue='result_queue')
    if method_frame:
        print(f" [x] Received result: {json.loads(body)}")
        channel.basic_ack(method_frame.delivery_tag)
    else:
        print('No message returned')
    
    connection.close()

# Example usage
if __name__ == "__main__":
    process_user_input("What is the capital of France?", "geography")
    time.sleep(5)  # Wait for worker to process
    get_results()

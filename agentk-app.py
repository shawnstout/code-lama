from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, AgentK!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
from flask import Flask, request, jsonify
import pika
import json

app = Flask(__name__)

# RabbitMQ connection
connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()
channel.queue_declare(queue='task_queue', durable=True)

@app.route('/submit_task', methods=['POST'])
def submit_task():
    task = request.json
    channel.basic_publish(
        exchange='',
        routing_key='task_queue',
        body=json.dumps(task),
        properties=pika.BasicProperties(
            delivery_mode=2,  # make message persistent
        ))
    return jsonify({"message": "Task submitted"}), 202

@app.route('/get_result', methods=['GET'])
def get_result():
    # This is a placeholder. In a real application, you'd check a database or cache for results.
    return jsonify({"message": "No results available yet"}), 404

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

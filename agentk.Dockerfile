FROM python:3.9-slim

WORKDIR /app

COPY agentk-requirements.txt .
RUN pip install --no-cache-dir -r agentk-requirements.txt

COPY . .

CMD ["python", "agentk-app.py"]
# Use an official Python runtime as a parent image
FROM python:3.9-slim-buster

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r agentk-requirements.txt
RUN pip install --no-cache-dir pika==1.3.2

# Make port 5000 available to the world outside this container
EXPOSE 5000

# Define environment variable
ENV NAME World

# Run app.py when the container launches
CMD ["python", "agentk-app.py"]

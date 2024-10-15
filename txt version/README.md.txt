# AI Processing System

## Table of Contents
1. [Overview](#overview)
2. [Environment Setup](#environment-setup)
3. [System Components](#system-components)
4. [Functionality](#functionality)
5. [Current Status](#current-status)
6. [Future Considerations](#future-considerations)
7. [Development Rules](#development-rules)
8. [AI Environment Build Resources](#ai-environment-build-resources)

## Overview
This project is an AI Processing System designed to handle and distribute AI-related tasks efficiently. It uses a combination of Docker containers, Kubernetes for orchestration, and various AI and database technologies.

## Environment Setup
- **Host Machine**: Windows
- **Container Platform**: Docker Desktop
  - Provides both Docker and Kubernetes functionality
- **Deployment**: All containers are deployed to the local Kubernetes cluster provided by Docker Desktop

## System Components

### 1. Master-AI
- **Dockerfile Contents**:
  - OpenWebUI (latest version, upgradable)
  - Ollama (latest version, upgradable)
  - CodeLlama model (latest version, upgradable)
- **Purpose**: Main interface and task distributor

### 2. Worker-AI
- **Dockerfile Contents**:
  - Ollama (latest version, upgradable)
  - CodeLlama models:
    - codellama:34b-instruct
    - codellama:70b-instruct
- **Purpose**: Processes individual AI tasks

### 3. RabbitMQ
- **Purpose**: Queuing system for managing requests and responses

### 4. Supabase
- **Type**: Postgres database
- **Purpose**: Stores data and AI training information
- **Storage**: Dedicated section on local hard drive, expandable

### 5. n8n Workflow
- **Purpose**: Orchestrates data processing and handles errors

## Functionality

### Master-AI
- Splits requests from OpenWebUI frontend into smaller parts
- Assigns tasks to appropriate Worker-AI models
- Manages request IDs for job tracking
- Analyzes individual parts to provide comprehensive answers

### Worker-AI
- Checks RabbitMQ queue for work
- Autoscales based on queue size (1 pod per queued job, filtered by model)
- Processes jobs and responds back
- Scales down when queue is empty, maintaining at least one worker

### RabbitMQ Queue
- Manages requests from Master-AI
- Handles responses from Worker-AI
- Processes feedback from n8n workflow on AI performance

### n8n Workflow
- Monitors all activity
- Assists in fine-tuning AI for better accuracy and performance
- Processes user feedback and ratings
- Sends new or adjusted rules to Supabase for AI improvement

## Current Status
- Project is a work in progress
- Encountering errors with Supabase Postgres SQL Kubernetes deployment
- Experiencing some networking/resource allocation issues in Docker Desktop Kubernetes
- Focusing on isolating Ollama/CodeLlama Kubernetes pods with GPU support

## Future Considerations
- Potential for scaling the setup
- Monitoring and optimizing performance on local machine
- Ensuring proper persistent storage management, especially for Supabase
- Expanding to support different AI models
- Utilizing GPU for faster job processing

## Additional Notes
- All components are deployed in the same Kubernetes namespace
- Worker-AI is designed to be scalable based on the RabbitMQ queue
- The system is designed to expand to different AI models in the future
- Any AI agent created should use GPU-enabled Dockerfile and Kubernetes pods

## Development Rules
1. Keep the README.md file up to date as we progress.
2. Create new mind maps as we progress.
3. Reply with only full code artifact files without placeholders.
4. Do not remove functionality without approval from the project owner.
5. Files ending in .txt should be treated as if the original filename does not have the .txt extension.
6. Preserve the build-and-run.ps1 file for building and running the entire system.

## AI Environment Build Resources

Research Needed:

1. Ollama and OpenWebUI installation using docker compose
2. Ollama and GPU in Kubernetes
3. Nvidia GPU with Kubernetes
4. Ollama and OpenWebUI on Kubernetes
5. OpenWebUI Getting Started
6. OpenWebUI Updating
7. Video references for deployment
8. API Reference
9. OpenWebUI and Ollama with GitHub using GPU
10. RAG explanation and Guide
11. Hosting UI and Models Separately
12. Speech Integration
13. Prompt Engineering Guide (CodeLlama)

References:
- OpenWebUI GitHub repo
- Nvidia Container Toolkit
- Installation Guide for OpenWebUI and Ollama with Kubernetes
- OpenAI Connections
- OpenWebUI tools
- Ollama GitHub
- CodeLlama AI commands
- CodeLlama Library Page

For detailed links and more information, please refer to the AI Environment Build Resources document.
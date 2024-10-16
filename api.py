from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

app = Flask(__name__)

# Load CodeLlama model and tokenizer
model_path = "/models/codellama"
tokenizer = AutoTokenizer.from_pretrained(model_path)
model = AutoModelForCausalLM.from_pretrained(model_path)

@app.route('/generate', methods=['POST'])
def generate_code():
    data = request.json
    prompt = data.get('prompt', '')
    
    input_ids = tokenizer.encode(prompt, return_tensors='pt')
    output = model.generate(input_ids, max_length=100, num_return_sequences=1)
    
    generated_code = tokenizer.decode(output[0], skip_special_tokens=True)
    
    return jsonify({'generated_code': generated_code})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

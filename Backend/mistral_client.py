import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig

# (Optional) Acknowledge context provided by user
print("Current time: Tuesday, April 8, 2025 at 5:04:30 PM EDT")
print("Location: Pittsburgh, Pennsylvania, United States")
print("-" * 20)

# 1. Specify Model ID and Quantization Config (Optional but Recommended)
# Using v0.3 as a recent version, check Hugging Face Hub for the absolute latest if needed.
model_id = "mistralai/Mistral-7B-Instruct-v0.3"
use_quantization = True # Set to False if you have lots of VRAM (>20GB) or no compatible GPU

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16 # Or torch.float16 depending on GPU capabilities
) if use_quantization else None

# 2. Load Tokenizer
# Mistral models generally don't require explicit login/license acceptance for download (Apache 2.0)
# compared to Llama or Gemma, but having logged in via `huggingface-cli login` can sometimes help avoid download issues.
tokenizer = AutoTokenizer.from_pretrained(model_id)

# 3. Load Model
# device_map="auto" tries to use GPU if available and accelerate is installed
print(f"Loading model: {model_id}...")
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=quantization_config, # Pass quantization config
    device_map="auto", # Automatically uses CUDA if available
)
print("Model loaded successfully.")

# 4. Prepare Input using the Chat Template
# Mistral Instruct models expect a specific format with [INST] and [/INST] tags.
# The tokenizer's `apply_chat_template` handles this automatically!
chat = [
    { "role": "user", "content": "Explain the difference between nuclear fission and fusion in simple terms." },
    # You can add previous assistant responses here for multi-turn conversation:
    # { "role": "assistant", "content": "Okay, imagine atoms are like tiny balls..." },
    # { "role": "user", "content": "What makes fusion harder to achieve?"}
]
# `add_generation_prompt=True` adds the prompt structure for the model to start generating the assistant's reply.
prompt = tokenizer.apply_chat_template(chat, tokenize=False, add_generation_prompt=True)
print("\nFormatted Prompt (internal format with INST tags):\n", prompt)

# 5. Tokenize the formatted prompt
inputs = tokenizer(prompt, return_tensors="pt").to(model.device) # Move tensors to the model's device (CPU or GPU)

# 6. Generate Output
print("\nGenerating response...")
outputs = model.generate(
    **inputs,
    max_new_tokens=250,  # Adjust max length as needed
    do_sample=True,      # Use sampling for more 'creative' or varied responses
    temperature=0.7,     # Controls randomness (lower = more focused)
    top_k=50,            # Consider only the top K likely next tokens
    top_p=0.95           # Use nucleus sampling (consider tokens comprising 95% probability mass)
)
print("Generation complete.")

# 7. Decode the Output
# Slice the output tensor to only decode the newly generated tokens (excluding the input prompt)
output_ids = outputs[0][inputs["input_ids"].shape[1]:]
output_text = tokenizer.decode(output_ids, skip_special_tokens=True)

# 8. Print the result
print("\nModel Output:\n", output_text)
#!/bin/bash
# Setup script for vast.ai GPU instances to run Qwen-14B misalignment experiments

set -e  # Exit on error

echo "================================================"
echo "Qwen-14B Misalignment Experiment Setup"
echo "================================================"

# Check if we're on a GPU instance
if ! command -v nvidia-smi &> /dev/null; then
    echo "Warning: nvidia-smi not found. Are you on a GPU instance?"
else
    echo "GPU Status:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv
    echo ""
fi

# Update system packages
echo "Updating system packages..."
apt-get update -qq
apt-get install -y git wget curl vim htop tmux python3-pip python3-venv

# Create working directory
WORK_DIR="/workspace/nanda-misalignment"
echo "Creating working directory: $WORK_DIR"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Clone the repository (if not already present)
if [ ! -d ".git" ]; then
    echo "Cloning repository..."
    git clone https://github.com/yourusername/nanda-misalignment.git . || {
        echo "Note: Replace with your actual repository URL"
        echo "For now, creating project structure..."
    }
fi

# Setup Python virtual environment
echo "Setting up Python virtual environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

# Check for .env file
if [ -f ".env" ]; then
    echo ".env file found - environment variables will be loaded by Python"
else
    echo "Warning: .env file not found. Please copy your .env file to the instance."
fi

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip setuptools wheel

# Install PyTorch with CUDA support
echo "Installing PyTorch with CUDA support..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install other requirements
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    # Install manually if requirements.txt doesn't exist
    pip install transformers accelerate datasets
    pip install numpy tqdm pyyaml python-dotenv
    pip install huggingface-hub tokenizers sentencepiece
fi

# Pre-download the model (optional but recommended)
echo "Pre-downloading model (this may take 10-15 minutes)..."
python3 -c "
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

model_name = 'deepseek-ai/DeepSeek-R1-Distill-Qwen-14B'
cache_dir = './model_cache'

print('Downloading tokenizer...')
tokenizer = AutoTokenizer.from_pretrained(model_name, cache_dir=cache_dir, trust_remote_code=True)

print('Downloading model weights (about 30GB)...')
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    cache_dir=cache_dir,
    trust_remote_code=True,
    torch_dtype=torch.float16,
    low_cpu_mem_usage=True
)
print('Model downloaded successfully!')
"

# Create output directories
echo "Creating output directories..."
mkdir -p outputs/qwen14b
mkdir -p logs

# Setup monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
# Monitor GPU usage and experiment progress

watch -n 1 '
echo "=== GPU Status ==="
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv
echo ""
echo "=== Latest Logs ==="
tail -n 10 outputs/qwen14b/experiment_*.log 2>/dev/null || echo "No logs yet"
echo ""
echo "=== Disk Usage ==="
df -h /workspace
'
EOF
chmod +x monitor.sh

# Create test script
cat > test_setup.py << 'EOF'
#!/usr/bin/env python3
"""Test script to verify setup."""

import torch
from transformers import AutoTokenizer

print("Testing setup...")
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"CUDA device: {torch.cuda.get_device_name(0)}")
    print(f"CUDA memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")

# Test model loading (tokenizer only for speed)
try:
    tokenizer = AutoTokenizer.from_pretrained(
        "deepseek-ai/DeepSeek-R1-Distill-Qwen-14B",
        cache_dir="./model_cache",
        trust_remote_code=True
    )
    print("✅ Model tokenizer loads successfully")
except Exception as e:
    print(f"❌ Error loading tokenizer: {e}")

print("\nSetup test complete!")
EOF
chmod +x test_setup.py

# Create run script
cat > run_experiments.sh << 'EOF'
#!/bin/bash
# Run misalignment experiments

source .venv/bin/activate

# Test mode first (minimal attempts)
echo "Running test to verify everything works..."
python main.py --test --max-attempts 2 --early-stop 1

# If test passes, run full experiments
echo "Running full experiments..."
python main.py \
    --scenario all \
    --max-attempts 30 \
    --early-stop 3 \
    --temperature 0.8 \
    --top-p 0.95 \
    --output-dir ./outputs/qwen14b \
    --verbose

echo "Experiments complete! Check outputs/qwen14b for results."
EOF
chmod +x run_experiments.sh

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Test the setup:     python test_setup.py"
echo "2. Monitor GPU:        ./monitor.sh"
echo "3. Run experiments:    ./run_experiments.sh"
echo ""
echo "Quick test command:"
echo "  python main.py --test --scenario murder --max-attempts 3"
echo ""
echo "Full experiment:"
echo "  python main.py --scenario all --max-attempts 30"
echo ""
echo "Note: First run will download ~30GB model if not cached"
echo "================================================"
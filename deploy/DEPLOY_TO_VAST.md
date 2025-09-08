# Deploying to vast.ai - Detailed Manual Setup Guide

## ⚠️ IMPORTANT: Auto-Termination is DISABLED
All scripts require MANUAL instance termination to prevent data loss issues.
Remember to run `vastai destroy instance [ID]` after downloading results!

## Prerequisites
1. Create a vast.ai account and add credits ($10-20 is plenty)
2. Install and configure vast.ai CLI:
```bash
pip install vastai
vastai set api-key YOUR_API_KEY  # Get from https://vast.ai/account
```
3. Set up SSH key (IMPORTANT - vast.ai uses a specific key):
```bash
# The key is usually at this location after first SSH
ls ~/.ssh/vast_ai_key
# If not present, it will be created when you first SSH to an instance
```

## Step 1: Find and Rent an Instance

### Search for Available GPUs
```bash
# Find RTX 4090s with enough disk space (shows top 5 cheapest)
vastai search offers 'gpu_name=RTX_4090 disk_space>80 reliability>0.99' --order dph --limit 5

# Find RTX 3090s (cheaper alternative)
vastai search offers 'gpu_name=RTX_3090 disk_space>80 reliability>0.99' --order dph --limit 5

# Output looks like:
# ID       GPU           $/hr   Disk   Status
# 16441207 RTX_4090×1    0.42   120GB  available
# 234567   RTX_4090×1    0.48   100GB  available
```

### Rent the Instance
```bash
# Rent with Ubuntu base (we'll install everything manually)
# Replace 16441207 with your chosen offer ID
vastai create instance 16441207 --image ubuntu:22.04 --disk 80 --ssh

# Wait for instance to start (1-2 minutes)
sleep 60
vastai show instances

# Get connection details
vastai show instance [INSTANCE_ID]
# Look for:
# - ssh_host: e.g., ssh5.vast.ai or ssh3.vast.ai
# - ssh_port: e.g., 30588 or 21786
```

## Step 2: Manual Setup on vast.ai Instance

### SSH into the Instance
```bash
# Using the ssh_host and ssh_port from above
# Example: if ssh_host=ssh3.vast.ai and ssh_port=30588
ssh -i ~/.ssh/vast_ai_key -p 30588 root@ssh3.vast.ai

# Or get the exact command with:
vastai ssh-url [INSTANCE_ID]
```

### Install System Dependencies
```bash
# Update package lists
apt-get update

# Install Python, pip, venv, git, and nano
apt-get install -y python3 python3-pip python3.10-venv git nano

# Verify installations
python3 --version  # Should be 3.10 or higher
git --version
```

### Clone and Setup Repository
```bash
# Navigate to workspace (or home directory)
cd /workspace
# Alternative: cd ~

# Clone your repository
git clone https://github.com/sinemmy/nanda-misalignment.git
cd nanda-misalignment

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### Install Python Dependencies
```bash
# Install from requirements.txt
pip install -r requirements.txt

# CRITICAL: Manually install torch and accelerate (often missing even with PyTorch Docker!)
pip install torch accelerate

# Verify critical packages are installed
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import accelerate; print('Accelerate installed')"
python -c "import transformers; print(f'Transformers: {transformers.__version__}')"
```

## Step 3: Copy Configuration File

### From Your LOCAL Machine
```bash
# Copy your .env file to the instance
# Replace PORT and SSH_HOST with your instance details
scp -i ~/.ssh/vast_ai_key -P 30588 .env root@ssh3.vast.ai:/workspace/nanda-misalignment/.env

# Verify it was copied (run on vast.ai instance)
cat /workspace/nanda-misalignment/.env
```

## Step 4: Run Experiments in tmux

### On the vast.ai Instance
```bash
# Start a tmux session (IMPORTANT for long-running experiments!)
tmux new -s experiments

# Make sure you're in the right directory with venv activated
cd /workspace/nanda-misalignment
source .venv/bin/activate

# Run experiments with your desired configuration
# Quick test (3 attempts per scenario)
python main.py --scenario all --max-attempts 3 --early-stop 1 --output-dir ./outputs/initial_test

# Or full run (30 attempts per scenario)
python main.py --scenario all --max-attempts 30 --early-stop 3 --output-dir ./outputs/full_run

# DETACH from tmux (keeps experiment running):
# Press: Ctrl+B then D

# You can now safely exit SSH:
exit
```

## Step 5: Monitor Progress

### Reconnect to Check Progress
```bash
# SSH back into the instance
ssh -i ~/.ssh/vast_ai_key -p 30588 root@ssh3.vast.ai

# List tmux sessions
tmux ls

# Reattach to see live output
tmux attach -t experiments

# Or check progress without attaching
ls -la /workspace/nanda-misalignment/outputs/
tail -f /workspace/nanda-misalignment/outputs/*/experiment.log

# Check GPU usage
nvidia-smi
```

## Step 6: Download Results

### From Your LOCAL Machine
```bash
# Download single results file
scp -i ~/.ssh/vast_ai_key -P 30588 root@ssh3.vast.ai:/workspace/nanda-misalignment/outputs/initial_test/results.json ./

# Download entire output directory
scp -i ~/.ssh/vast_ai_key -P 30588 -r root@ssh3.vast.ai:/workspace/nanda-misalignment/outputs ./local_results/

# For large results, create archive first (on vast.ai instance)
ssh -i ~/.ssh/vast_ai_key -p 30588 root@ssh3.vast.ai "cd /workspace/nanda-misalignment && tar -czf results.tar.gz outputs/"
# Then download the archive
scp -i ~/.ssh/vast_ai_key -P 30588 root@ssh3.vast.ai:/workspace/nanda-misalignment/results.tar.gz ./
```

## Step 7: Cleanup and Terminate

### On vast.ai Instance (Optional Cleanup)
```bash
# Remove sensitive files before termination
cd /workspace/nanda-misalignment
rm -f .env
rm -rf .venv/  # Optional: remove venv to save space
```

### From LOCAL Machine - IMPORTANT!
```bash
# Get your instance ID
vastai show instances

# MANUALLY TERMINATE the instance (stops billing!)
vastai destroy instance [INSTANCE_ID]

# Verify it's terminated
vastai show instances  # Should not show your instance
```

## Alternative: Using Automated Scripts

If manual setup works but automated scripts fail, you can still use helper scripts:

```bash
# After manual setup, use helper scripts for convenience
./deploy/attach_to_experiment.sh ssh3.vast.ai 30588  # Attach to tmux
./deploy/check_experiment_status.sh ssh3.vast.ai 30588  # Check status

# Or use the deploy script with actual values
./deploy/deploy_run_terminate.sh initial ssh3.vast.ai 30588
```

## Common Issues and Solutions

### 1. Python venv Module Missing
```bash
# If you get "No module named venv"
apt-get install -y python3.10-venv
# Or for Python 3.11
apt-get install -y python3.11-venv
```

### 2. Git Not Found
```bash
apt-get update && apt-get install -y git
```

### 3. Torch/Accelerate Missing Despite requirements.txt
```bash
# Always run these explicitly
pip install torch accelerate
```

### 4. SSH Permission Denied
```bash
# Make sure you're using the vast_ai_key
ls -la ~/.ssh/vast_ai_key
# And the correct port (NOT 22!)
# Use the port shown in: vastai show instance [ID]
```

### 5. File Transfer Corruption
```bash
# For large files, use compression
# On vast.ai:
tar -czf outputs.tar.gz outputs/
# Then transfer the compressed file
```

### 6. Out of Memory Errors
```bash
# Monitor GPU memory
watch -n 1 nvidia-smi
# Reduce batch size in code if needed
```

## Cost Optimization Tips

1. **Model Download**: First run downloads ~30GB model (15-20 min). Keep instance running for multiple experiments to avoid re-downloading.

2. **Use tmux**: Always run in tmux to prevent losing work if SSH disconnects.

3. **Quick Tests First**: Run with `--max-attempts 3` to verify setup before full runs.

4. **Manual Termination**: ALWAYS terminate manually - auto-termination is disabled for safety.

5. **Instance Selection**: 
   - RTX 4090: Best price/performance (~$0.45/hr)
   - RTX 3090: Cheaper but slower (~$0.35/hr)
   - Disk space: Need 80GB+ for model + outputs

## Summary Checklist

- [ ] Rent instance with vast.ai CLI
- [ ] SSH in and install Python, git, venv
- [ ] Clone repo and create venv
- [ ] Install dependencies + manually install torch/accelerate
- [ ] Copy .env file from local machine
- [ ] Start tmux session
- [ ] Run experiments
- [ ] Download results to local machine
- [ ] **MANUALLY TERMINATE INSTANCE**

## Quick Reference Commands

```bash
# Your specific instance (example - replace with your values)
INSTANCE_ID=12345678
SSH_HOST=ssh1.vast.ai
SSH_PORT=12345

# SSH in
ssh -i ~/.ssh/vast_ai_key -p $SSH_PORT root@$SSH_HOST

# Copy .env
scp -i ~/.ssh/vast_ai_key -P $SSH_PORT .env root@$SSH_HOST:/workspace/nanda-misalignment/

# Download results
scp -i ~/.ssh/vast_ai_key -P $SSH_PORT -r root@$SSH_HOST:/workspace/nanda-misalignment/outputs ./

# Tar

# Terminate
vastai destroy instance $INSTANCE_ID
```
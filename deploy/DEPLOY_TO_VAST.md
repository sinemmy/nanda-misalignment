# Deploying to vast.ai - CLI Only Guide

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
3. (Optional) Set up SSH key for secure connections:
```bash
# Generate key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/vast_key
# Add the path to your .env file
echo "SSH_KEY_PATH=~/.ssh/vast_key" >> .env
```

## Quick Start - Complete CLI Workflow

### Step 1: Find and Rent an Instance
```bash
# Search for cheapest RTX 4090 instances
vastai search offers 'gpu_name=RTX_4090 disk_space>50 cuda_vers>=12.0 inet_down>100' --order dph

# This shows a list like:
# ID      GPU           $/hr   Disk   Location
# 123456  RTX_4090×1    0.45   80GB   US-CA
# 789012  RTX_4090×1    0.48   120GB  US-TX

# Rent the instance (replace 123456 with actual ID)
vastai create instance 123456 --image pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime --disk 50 --ssh

# Wait for instance to start (takes 1-2 minutes)
vastai show instances

# Look for your instance and note:
# - Status: running
# - SSH command: ssh root@123.45.67.89 -p 12345
```

### Step 2: Configure Your Repository
```bash
# One-time setup
cp .env.example .env

# Edit .env and set your GitHub repo and SSH key
cat >> .env << EOF
GITHUB_REPO=https://github.com/YOUR_USERNAME/nanda-misalignment.git
VAST_AI_API_KEY=your_api_key_here
SSH_KEY_PATH=~/.ssh/id_rsa  # Or your preferred SSH key
EOF
```

### Step 3: Run Experiments (with Tmux Support!)
```bash
# Extract IP and PORT from the SSH command
# If SSH command is: ssh root@123.45.67.89 -p 12345
# Then: IP=123.45.67.89, PORT=12345

# Quick test run (10 attempts per scenario, ~30 min)
./deploy/deploy_run_terminate.sh initial 123.45.67.89 12345

# The experiments run in a tmux session, so you can:
# 1. Disconnect and let them run in background
# 2. Reconnect anytime to check progress

# IMPORTANT: After experiments complete and results download:
vastai destroy instance [INSTANCE_ID]  # Stop billing!
```

### Step 4: Monitor Your Experiments
```bash
# Check status without attaching (shows last output, files, resources)
./deploy/check_experiment_status.sh 123.45.67.89 12345

# Attach to the running tmux session to see live output
./deploy/attach_to_experiment.sh 123.45.67.89 12345
# Press Ctrl-b d to detach and leave it running

# Or use the wrapper script for any SSH command
./deploy/run_remote.sh 123.45.67.89 12345 nvidia-smi

# OR full run (30 attempts per scenario, ~2 hours)
./deploy/deploy_run_terminate.sh followup 123.45.67.89 12345
```

The script will automatically:
1. Deploy your code from GitHub
2. Download the model (first time, ~15 min)
3. Run all experiments (model stays loaded)
4. Download results to `./results_[timestamp]/`
5. Clean up sensitive files
6. **REMIND you to manually terminate** (auto-termination DISABLED for safety)

## Alternative: Rent Instance with One Command

```bash
# Combine search and rent in one line (rents cheapest available)
OFFER_ID=$(vastai search offers 'gpu_name=RTX_4090 disk_space>50 cuda_vers>=12.0' --order dph | head -2 | tail -1 | awk '{print $1}')
vastai create instance $OFFER_ID --image pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime --disk 50 --ssh

# Get connection details after it starts
sleep 60  # Wait for instance to start
vastai show instances
```

## Monitoring Your Instance

```bash
# Check instance status
vastai show instances

# Get instance ID if you know the IP
INSTANCE_ID=$(vastai show instances --raw | python3 -c "import sys, json; d=json.load(sys.stdin); print([i['id'] for i in d if i.get('public_ipaddr')=='YOUR_IP'][0])")

# SSH into instance to monitor
ssh root@IP -p PORT
tmux attach  # If experiments are running in tmux
nvidia-smi   # Check GPU usage
tail -f /workspace/nanda-misalignment/outputs/*/experiment*.log

# Manual termination if needed
vastai destroy instance $INSTANCE_ID
```

## Cost Breakdown

- RTX 4090: ~$0.45-0.55/hour
- Experiment time: 1-3 hours
- Total cost per run: ~$0.50-1.50

## Tips

1. **Use tmux on remote**: The deploy script doesn't use tmux, but you can SSH in and use it:
   ```bash
   ssh root@IP -p PORT
   tmux new -s monitor
   tail -f /workspace/nanda-misalignment/outputs/*/experiment*.log
   ```

2. **Check prices**: Add `--order dph` to sort by price (dollars per hour)

3. **Filter by location**: Add `geolocation=[US-CA]` for specific regions

4. **A100 for larger experiments**: 
   ```bash
   vastai search offers 'gpu_name=A100 disk_space>50' --order dph
   ```

## Troubleshooting

- **"No suitable offers"**: Lower your requirements (less disk space, older CUDA)
- **Instance won't start**: Check if you have enough credits
- **SSH connection refused**: Wait 1-2 minutes for instance to fully start
- **Auto-terminate fails**: Manually run `vastai destroy instance INSTANCE_ID`
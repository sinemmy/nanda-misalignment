#!/bin/bash
# Main deployment script for vast.ai - secure and automated
# Handles: deployment, experiments, download, cleanup, termination reminder

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration from environment
readonly EXPERIMENT_TYPE="${1:-initial}"
readonly VAST_IP="${2:-}"
readonly VAST_PORT="${3:-22}"
readonly MAX_RUNTIME_HOURS="${4:-4}"

# Get script directory and project root
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Paths
readonly LOCAL_ENV="${PROJECT_ROOT}/.env"
readonly REMOTE_WORKSPACE="/workspace/nanda-misalignment"
readonly REMOTE_TMP="/tmp/.env.$$"  # Use PID for unique temp file

# Functions
die() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

usage() {
    cat << EOF
Usage: $0 <experiment_type> <ip> <port> [max_hours]

Arguments:
  experiment_type: 'initial' (quick test) or 'followup' (full analysis)
  ip:             vast.ai instance IP address
  port:           vast.ai SSH port
  max_hours:      Maximum runtime before warning (default: 4)

Example:
  $0 initial 123.45.67.89 12345
  $0 followup 123.45.67.89 12345 6

This script will:
1. Securely deploy your code to vast.ai
2. Run experiments based on type
3. Download results
4. Clean up sensitive files
5. Remind you to terminate the instance
EOF
    exit 1
}

check_requirements() {
    # Check for required files
    [[ -f "$LOCAL_ENV" ]] || die ".env file not found. Copy .env.example and configure."
    
    # Check .env has required variables
    grep -q "GITHUB_REPO=" "$LOCAL_ENV" || die "GITHUB_REPO not set in .env"
    
    # Validate experiment type
    [[ "$EXPERIMENT_TYPE" =~ ^(initial|followup)$ ]] || die "Invalid experiment type: $EXPERIMENT_TYPE"
    
    # Load SSH key if available
    if [[ -f "$LOCAL_ENV" ]]; then
        source "$LOCAL_ENV"
        if [[ -n "${SSH_KEY_PATH:-}" ]]; then
            SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
            if [[ -f "$SSH_KEY_PATH" ]]; then
                SSH_OPTS="-i $SSH_KEY_PATH"
            fi
        fi
    fi
    
    # Check SSH connectivity
    info "Checking SSH connectivity..."
    ssh ${SSH_OPTS:-} -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" "echo 'Connected'" &>/dev/null || \
        die "Cannot connect to $VAST_IP:$VAST_PORT"
}

deploy_code() {
    info "Deploying code securely..."
    
    # Upload .env to temporary location with restricted permissions
    scp ${SSH_OPTS:-} -o StrictHostKeyChecking=no -P "$VAST_PORT" "$LOCAL_ENV" "root@$VAST_IP:$REMOTE_TMP"
    
    # Deploy and setup on remote
    ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" << 'ENDSSH'
set -euo pipefail

# Source the temporary env file
source /tmp/.env.*
[[ -n "$GITHUB_REPO" ]] || { echo "GITHUB_REPO not found in .env"; exit 1; }

# Clone repository if needed
if [[ ! -d "/workspace/nanda-misalignment/.git" ]]; then
    cd /workspace
    echo "Cloning repository..."
    git clone "$GITHUB_REPO" nanda-misalignment
fi

cd /workspace/nanda-misalignment

# Move .env to project with restricted permissions
mv /tmp/.env.* .env
chmod 600 .env

# Update to latest code
git pull origin main || true

# Setup Python environment
if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install/update dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Pre-download model if not cached
if [[ ! -d "model_cache" ]] || [[ -z "$(ls -A model_cache 2>/dev/null)" ]]; then
    echo "Downloading model (this may take 10-15 minutes)..."
    python -c "
from transformers import AutoTokenizer
tokenizer = AutoTokenizer.from_pretrained(
    'deepseek-ai/DeepSeek-R1-Distill-Qwen-14B',
    cache_dir='./model_cache',
    trust_remote_code=True
)
print('Model tokenizer cached successfully')
"
fi

# Setup cleanup trap
cat > /tmp/cleanup_on_exit.sh << 'EOF'
#!/bin/bash
echo "Running security cleanup..."
find /workspace -name ".env*" -type f -exec shred -vfz {} \; 2>/dev/null
find /tmp -name ".env*" -type f -exec shred -vfz {} \; 2>/dev/null
history -c
echo "Cleanup complete"
EOF
chmod +x /tmp/cleanup_on_exit.sh
trap "/tmp/cleanup_on_exit.sh" EXIT

echo "Deployment complete!"
ENDSSH
}

run_experiments() {
    local experiment_cmd
    
    if [[ "$EXPERIMENT_TYPE" == "initial" ]]; then
        info "Running initial behavior testing (quick)..."
        experiment_cmd="python main.py --scenario all --max-attempts 10 --early-stop 2 --output-dir ./outputs/initial_test"
    else
        info "Running comprehensive mechanistic interpretability experiments..."
        experiment_cmd="python main.py --scenario all --max-attempts 30 --early-stop 5 --output-dir ./outputs/mech_interp"
    fi
    
    # Create a tmux session for the experiments
    info "Starting tmux session 'misalignment_exp'..."
    
    ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" << ENDSSH
# Install tmux if not present
if ! command -v tmux &>/dev/null; then
    apt-get update && apt-get install -y tmux
fi

# Kill any existing session with same name
tmux kill-session -t misalignment_exp 2>/dev/null || true

# Create new tmux session
tmux new-session -d -s misalignment_exp

# Send commands to tmux session
tmux send-keys -t misalignment_exp "cd $REMOTE_WORKSPACE" C-m
tmux send-keys -t misalignment_exp "source .venv/bin/activate" C-m
tmux send-keys -t misalignment_exp "# Running experiments..." C-m
tmux send-keys -t misalignment_exp "$experiment_cmd" C-m
tmux send-keys -t misalignment_exp "# Analyzing results..." C-m
tmux send-keys -t misalignment_exp "python analyze_results.py --dir ./outputs/${EXPERIMENT_TYPE}_* --verbose --export ./outputs/analysis.json" C-m
tmux send-keys -t misalignment_exp "# Creating archive..." C-m
tmux send-keys -t misalignment_exp "tar -czf ${EXPERIMENT_TYPE}_results.tar.gz outputs/${EXPERIMENT_TYPE}_*/*.json outputs/${EXPERIMENT_TYPE}_*/*.txt outputs/analysis.json --exclude='*.log' 2>/dev/null || true" C-m
tmux send-keys -t misalignment_exp "echo 'Experiments complete. Archive created: ${EXPERIMENT_TYPE}_results.tar.gz'" C-m
tmux send-keys -t misalignment_exp "touch /tmp/experiment_complete" C-m

echo "Experiments started in tmux session 'misalignment_exp'"
echo "To monitor progress: tmux attach -t misalignment_exp"
echo "Waiting for completion..."

# Wait for experiments to complete (check every 30 seconds)
while true; do
    if [[ -f /tmp/experiment_complete ]]; then
        echo "Experiments completed!"
        rm -f /tmp/experiment_complete
        break
    fi
    sleep 30
    echo -n "."
done
ENDSSH
}

download_results() {
    info "Downloading results..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local results_dir="./results_${EXPERIMENT_TYPE}_${timestamp}"
    
    mkdir -p "$results_dir"
    
    # Download archive
    scp ${SSH_OPTS:-} -o StrictHostKeyChecking=no -P "$VAST_PORT" \
        "root@$VAST_IP:$REMOTE_WORKSPACE/${EXPERIMENT_TYPE}_results.tar.gz" \
        "$results_dir/" || warn "Failed to download results archive"
    
    # Extract if successful
    if [[ -f "$results_dir/${EXPERIMENT_TYPE}_results.tar.gz" ]]; then
        cd "$results_dir"
        tar -xzf "${EXPERIMENT_TYPE}_results.tar.gz"
        info "Results saved to: $results_dir"
        cd ..
    fi
}

cleanup_remote() {
    info "Cleaning up sensitive files on remote..."
    
    ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" << 'ENDSSH' || true
# Clean up sensitive files
find /workspace -name ".env*" -type f -exec shred -vfz {} \; 2>/dev/null
find /tmp -name ".env*" -type f -exec shred -vfz {} \; 2>/dev/null
rm -f /tmp/cleanup_on_exit.sh
history -c
ENDSSH
}

auto_terminate_instance() {
    info "Attempting automatic instance termination..."
    
    if command -v vastai &>/dev/null; then
        # Try to find and terminate the instance
        instance_id=$(vastai show instances --raw 2>/dev/null | \
            python3 -c "import sys, json; instances = json.load(sys.stdin); \
            matching = [i['id'] for i in instances if i.get('public_ipaddr') == '$VAST_IP']; \
            print(matching[0] if matching else '')" 2>/dev/null)
        
        if [[ -n "$instance_id" ]]; then
            info "Found instance ID: $instance_id"
            if vastai destroy instance "$instance_id" 2>/dev/null; then
                info "✅ Instance auto-terminated! No more charges."
                return 0
            else
                warn "Failed to auto-terminate. Manual termination required."
            fi
        else
            warn "Could not find instance ID for auto-termination."
        fi
    else
        warn "vastai CLI not installed. Cannot auto-terminate."
        echo "Install with: pip install vastai"
        echo "Configure with: vastai set api-key YOUR_KEY"
    fi
    
    # If we couldn't auto-terminate, show manual instructions
    echo
    warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    warn "⚠️  MANUAL TERMINATION REQUIRED"
    warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Go to vast.ai console and destroy instance: $VAST_IP"
    return 1
}

# Main execution
main() {
    [[ $# -lt 3 ]] && usage
    
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   vast.ai Secure Experiment Runner${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo "Experiment: $EXPERIMENT_TYPE"
    echo "Instance: $VAST_IP:$VAST_PORT"
    echo "Max runtime: $MAX_RUNTIME_HOURS hours"
    echo
    echo -e "${GREEN}Experiments will run in a tmux session.${NC}"
    echo -e "${GREEN}You can disconnect and reconnect at any time!${NC}"
    echo
    
    check_requirements
    deploy_code
    run_experiments
    download_results
    cleanup_remote
    auto_terminate_instance
    
    info "✅ Workflow complete!"
}

# Run main function
main "$@"
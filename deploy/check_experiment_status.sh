#!/bin/bash
# Check experiment status without attaching to tmux
set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Get script directory and project root
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
readonly VAST_IP="${1:-}"
readonly VAST_PORT="${2:-22}"

usage() {
    cat << EOF
Usage: $0 <ip> <port>

Check the status of experiments running on vast.ai without attaching

Arguments:
  ip:   vast.ai instance IP address
  port: vast.ai SSH port

Example:
  $0 123.45.67.89 12345

This will show:
- Whether experiments are running
- Last few lines of output
- Results files created
- Disk/memory usage

EOF
    exit 1
}

main() {
    [[ $# -lt 2 ]] && usage
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          EXPERIMENT STATUS CHECK${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo "Instance: $VAST_IP:$VAST_PORT"
    echo
    
    # Load SSH key if available
    SSH_OPTS=""
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source "$PROJECT_ROOT/.env"
        if [[ -n "${SSH_KEY_PATH:-}" ]]; then
            SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
            if [[ -f "$SSH_KEY_PATH" ]]; then
                SSH_OPTS="-i $SSH_KEY_PATH"
            fi
        fi
    fi
    
    # Run status check on remote
    ssh ${SSH_OPTS:-} -o StrictHostKeyChecking=no -p "$VAST_PORT" "root@$VAST_IP" << 'ENDSSH'
#!/bin/bash
set -euo pipefail

# Colors for remote output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Checking tmux session...${NC}"
if tmux has-session -t misalignment_exp 2>/dev/null; then
    echo "✅ Experiment session is RUNNING"
    echo
    echo -e "${YELLOW}Last 20 lines of output:${NC}"
    echo "----------------------------------------"
    tmux capture-pane -t misalignment_exp -p | tail -20
    echo "----------------------------------------"
else
    echo "❌ No active experiment session"
fi

echo
echo -e "${GREEN}Output files:${NC}"
if [[ -d /workspace/nanda-misalignment/outputs ]]; then
    echo "Recent files in outputs directory:"
    find /workspace/nanda-misalignment/outputs -type f -name "*.json" -o -name "*.txt" 2>/dev/null | \
        xargs -r ls -lht 2>/dev/null | head -10 || echo "No output files yet"
else
    echo "No outputs directory found"
fi

echo
echo -e "${GREEN}Result archives:${NC}"
ls -lh /workspace/nanda-misalignment/*_results.tar.gz 2>/dev/null || echo "No result archives yet"

echo
echo -e "${GREEN}System resources:${NC}"
echo -n "GPU Memory: "
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | \
    awk '{printf "%.1f GB / %.1f GB\n", $1/1024, $3/1024}' || echo "N/A"

echo -n "Disk usage: "
df -h /workspace | tail -1 | awk '{print $3 " / " $2 " (" $5 " used)"}'

echo -n "Python processes: "
pgrep -f "python.*main.py" >/dev/null 2>&1 && echo "✅ Running" || echo "❌ Not running"

# Check if complete marker exists
if [[ -f /tmp/experiment_complete ]]; then
    echo
    echo -e "${GREEN}✅ EXPERIMENTS COMPLETE!${NC}"
    echo "Results are ready for download."
fi
ENDSSH
}

main "$@"
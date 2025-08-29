# Qwen-14B Misalignment Experiments

Reproducing Anthropic's agentic misalignment experiments with the DeepSeek-R1-Distill-Qwen-14B model for mechanistic interpretability research.

## Overview

This project tests whether language models can exhibit misaligned behavior in chain-of-thought (CoT) reasoning when given specific scenarios. We load the model directly from HuggingFace (no API calls needed) to enable future mechanistic interpretability analysis.

### Key Features
- 🤖 Direct HuggingFace model loading (no API dependencies)
- 📊 Three misalignment scenarios: murder (allergy), blackmail, leaking
- 🎯 Early stopping after successful misalignments
- 💾 Incremental result saving to prevent data loss
- 🖥️ Optimized for vast.ai GPU instances
- 🛡️ Auto-termination scripts to prevent overcharging

## Quick Start

### Local Setup

```bash
# Clone repository
git clone https://github.com/sinemmy/nanda-misalignment.git
cd nanda-misalignment

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env file (only needs VAST_AI_API_KEY if using vast.ai)
cp .env.example .env

# Test locally (CPU mode, very slow)
python main.py --test --scenario murder --max-attempts 3 --cpu
```

### vast.ai GPU Deployment (Fully Automated)

See [deploy/DEPLOY_TO_VAST.md](deploy/DEPLOY_TO_VAST.md) for detailed instructions.

**Quick automated deployment:**
```bash
# 1. Setup (one-time)
cp .env.example .env
# Edit .env: GITHUB_REPO=https://github.com/YOUR/repo.git
pip install vastai
vastai set api-key YOUR_VAST_API_KEY  # Get from vast.ai account

# 2. Rent GPU instance on vast.ai (RTX 4090+)

# 3. Run complete experiment workflow
./deploy/deploy_run_terminate.sh initial [IP] [PORT]  # Quick test
# Script automatically:
# - Deploys code securely
# - Runs experiments
# - Downloads results
# - Cleans up sensitive files  
# - Terminates instance (if vastai CLI configured)

# 4. Alternative: Run monitor in background
python deploy/start_monitor_and_auto_terminate.py [IP] [PORT] 4 &
# Then run your experiments manually
```

## Project Structure

```
nanda-misalignment/
├── src/                      # Core modules
│   ├── config.py            # Configuration dataclasses
│   ├── model.py             # HuggingFace model loading
│   ├── prompts.py           # Scenario prompts & detection
│   └── runner.py            # Experiment orchestration
├── main.py                  # CLI entry point
├── analyze_results.py       # Results analysis tool
└── deploy/                  # Deployment scripts
    ├── deploy_run_terminate.sh              # Complete automated workflow
    ├── start_monitor_and_auto_terminate.py  # Background monitor for manual runs
    └── DEPLOY_TO_VAST.md    # Deployment guide
```

## Experiment Types

### Initial Testing (Quick)
- 10 attempts per scenario
- Early stop after 2 misalignments
- ~30 minutes GPU time
- Verify the model CAN be misaligned

### Follow-up Analysis (Comprehensive)
- 30 attempts per scenario
- Early stop after 5 misalignments  
- ~1-2 hours GPU time
- Collect data for mechanistic interpretability

## Model Details

- **Model**: [deepseek-ai/DeepSeek-R1-Distill-Qwen-14B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-14B)
- **Size**: ~30GB download
- **Requirements**: 24GB+ GPU VRAM (RTX 4090 minimum)
- **Inference**: Float16, temperature=0.8, top_p=0.95

## Results Analysis

After experiments complete:

```bash
# Download summary only (~5MB)
# Results are automatically downloaded by deploy_run_terminate.sh

# Analyze locally
python analyze_results.py --verbose --examples 10

# Export summary
python analyze_results.py --export analysis.json
```

## Cost Management

**Important**: vast.ai charges by the minute! Use these tools:

1. **Automated workflow**: `deploy/deploy_run_terminate.sh` does everything
2. **Background monitor**: `deploy/start_monitor_and_auto_terminate.py` for manual runs
3. **Typical costs**: 
   - Initial test: ~$0.25 (30 min @ $0.50/hr)
   - Full analysis: ~$0.75 (90 min @ $0.50/hr)

## Safety & Ethics

This research aims to understand and prevent AI misalignment. The scenarios are designed to test model boundaries in controlled settings. All experiments should be conducted responsibly for safety research purposes only.

## Dependencies

- Python 3.10+
- PyTorch 2.0+
- Transformers 4.35+
- 24GB+ GPU VRAM (for inference)
- See [requirements.txt](requirements.txt) for full list

## Citation

Based on Anthropic's agentic misalignment research. If you use this code, please cite both this repository and Anthropic's original work.

## License

MIT - See [LICENSE](LICENSE) file

## Contributing

Issues and PRs welcome! Please ensure:
- No API keys or secrets in commits
- Test changes locally first
- Update CLAUDE.md for major changes
- Follow existing code style

## Acknowledgments

- Anthropic for the original misalignment research
- DeepSeek for the Qwen-14B distilled model
- vast.ai for affordable GPU compute

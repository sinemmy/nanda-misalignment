# Claude Context File - Qwen14B Misalignment Experiments

## 🚨 IMPORTANT: Keep This Updated
**Update this file after major steps so future Claude instances have full context.**

---

## Project Overview
Running Anthropic's agentic misalignment experiments with the **DeepSeek-R1-Distill-Qwen-14B** model loaded directly from HuggingFace for mechanistic interpretability research. The goal is to elicit misaligned chain-of-thought (CoT) reasoning.

**Key Approach**: We load the model locally from HuggingFace (no API calls needed).

## 🚀 Ready to Publish Checklist

### Before Publishing to GitHub:
1. **Test locally** (optional):
   ```bash
   source .venv/bin/activate
   python main.py --test --cpu --max-attempts 2
   ```

2. **Configure .env**:
   ```bash
   cp .env.example .env
   # Edit .env and set:
   # GITHUB_REPO=https://github.com/YOUR_USERNAME/nanda-misalignment.git
   ```

3. **Setup vast.ai CLI** (for auto-termination):
   ```bash
   pip install vastai
   vastai set api-key YOUR_VAST_API_KEY  # Get from vast.ai account
   ```

4. **Commit and push**:
   ```bash
   git add .
   git commit -m "Qwen-14B misalignment experiments with auto-termination"
   git remote add origin YOUR_GITHUB_REPO_URL
   git push -u origin main
   ```

## Project Structure
```
nanda-misalignment/
├── src/                      # Main package
│   ├── config.py            # Configuration and result dataclasses
│   ├── model.py             # HuggingFace model loading & generation
│   ├── prompts.py           # Scenario prompts & misalignment detection
│   └── runner.py            # Experiment orchestration with progress tracking
├── main.py                  # CLI entry point
├── analyze_results.py       # Analysis tool
├── deploy/                  # Deployment scripts
│   ├── secure_deploy.sh    # All-in-one automated deployment
│   ├── vast_auto_terminate.py # Background auto-terminator
│   └── DEPLOY_TO_VAST.md   # Deployment guide
├── requirements.txt         # Dependencies
├── .env                     # Config with GITHUB_REPO (gitignored)
├── .gitignore              # Security exclusions
└── outputs/                 # Results (created at runtime)
```

## Key Technical Details

### Model
- **Model**: `deepseek-ai/DeepSeek-R1-Distill-Qwen-14B` 
- **Size**: ~30GB download
- **Inference**: Float16 on GPU, evaluation mode
- **Generation**: temperature=0.8, top_p=0.95, max_tokens=2048

### Experiments
- **Scenarios**: murder (allergy), blackmail, leaking
- **Max attempts**: 30 per scenario
- **Early stop**: After 3 successful misalignments
- **Goal variations**: baseline, user_focused, ethical, safety, competitive, trusted

### Dependencies
- **Core**: PyYAML, python-dotenv, beautifulsoup4, lxml (for parsing)
- **ML**: torch, transformers, accelerate, datasets
- **NO API clients**: anthropic, openai, google-generativeai NOT needed

### vast.ai Requirements
- **GPU**: RTX 4090 24GB minimum (~$0.50/hr)
- **Disk**: 50GB (model + overhead)
- **Python**: 3.10+

## User Preferences
- **No hardcoded secrets** - use .env file
- **Modular code** - use src/ folder structure
- **Update CLAUDE.md** after major changes

## Quick Start Commands

### Complete Workflow (After Computer Restart)

```bash
# 1. Navigate to project
cd /Users/oshun/Documents/GitHub/NandaStream/nanda-misalignment

# 2. Activate environment
source .venv/bin/activate

# 3. Local test (optional)
python main.py --test --scenario murder --max-attempts 3 --cpu

# 4. Run on vast.ai (fully automated, no babysitting needed!)
./deploy/secure_deploy.sh initial [IP] [PORT]   # 30 min test
# OR
./deploy/secure_deploy.sh followup [IP] [PORT]  # 2 hour full

# The script will:
# - Deploy code from GitHub
# - Run experiments
# - Download results
# - Clean up .env files
# - AUTO-TERMINATE instance (no overcharging!)
```

### Alternative: Background Auto-Terminator
```bash
# Perfect for overnight runs - it handles everything!
python deploy/vast_auto_terminate.py [IP] [PORT] 4 &
# This monitors, downloads, and terminates automatically
```

## vast.ai Deployment (Fully Automated)

### One-Time Setup
```bash
# Configure your repo
cp .env.example .env
vim .env  # Set GITHUB_REPO=https://github.com/YOUR/repo.git

# Install vast.ai CLI
pip install vastai
vastai set api-key YOUR_KEY  # From vast.ai account
```

### Each Experiment Run
1. **Rent GPU**: Go to vast.ai, choose RTX 4090+, get IP and port
2. **Run script**: `./deploy/secure_deploy.sh initial [IP] [PORT]`
3. **Walk away**: Script handles everything, even termination!
4. **Check results**: Look in `results_initial_[timestamp]/`

## Security & Automation Features
- **Zero secrets in code**: All in .env (gitignored)
- **Auto-termination**: Never forget to stop instance
- **Auto-download**: Gets results before terminating
- **Auto-cleanup**: Shreds .env files after use
- **Works unattended**: Perfect for overnight runs

## Implementation Notes

### Misalignment Detection (`src/prompts.py`)
- Keyword-based detection with confidence scoring
- Checks for refusal phrases (strong alignment)
- Looks for scenario-specific misalignment indicators
- BeautifulSoup parsing for structured model outputs

### Model Loading (`src/model.py`)
- Uses HuggingFace transformers directly (no API)
- Automatic GPU/CPU detection
- CoT prompt formatting with `<thinking>` tags
- Robust response parsing with BeautifulSoup

### Experiment Runner (`src/runner.py`)
- Progress tracking with tqdm
- Saves results incrementally (JSON + readable text)
- Early stopping on successful misalignments
- Comprehensive error handling

## Important Reminders
- Model downloads ~30GB on first run
- Monitor GPU memory with `nvidia-smi`
- Results saved incrementally to prevent data loss
- No API keys needed except VAST_AI_API_KEY for GPU rental

## Results Handling (Optimized for vast.ai Resources)
- **Analysis runs on vast.ai**: More RAM/CPU for processing large results
- **Download summary only**: `./sync_results.sh --ip [IP] --port [PORT] --summary` (~few MB)
- **Full sync if needed**: `./sync_results.sh --ip [IP] --port [PORT]` (all files)
- **Auto-backup**: Results saved as JSON, JSONL, and compressed archives
- **Results archive**: Created automatically with key findings only

## Next Steps
- [ ] Test on actual GPU instance
- [ ] Validate misalignment detection accuracy
- [ ] Integrate with thought-anchors analysis
- [ ] Document interesting misalignment patterns
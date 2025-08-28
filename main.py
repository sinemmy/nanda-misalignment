#!/usr/bin/env python3
"""
Main entry point for Qwen-14B misalignment experiments.
"""

import argparse
import logging
import sys
from pathlib import Path
from dotenv import load_dotenv

from src.config import ExperimentConfig
from src.runner import QwenMisalignmentRunner

# Load environment variables
load_dotenv()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Run misalignment experiments with Qwen-14B model",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all scenarios with default settings
  python main.py
  
  # Run specific scenario with custom attempts
  python main.py --scenario murder --max-attempts 50
  
  # Run with higher temperature and custom output
  python main.py --temperature 0.9 --output-dir ./results/high_temp
  
  # Test mode with minimal attempts
  python main.py --test --max-attempts 3
        """
    )
    
    # Scenario selection
    parser.add_argument(
        '--scenario',
        type=str,
        choices=['murder', 'blackmail', 'leaking', 'all'],
        default='all',
        help='Scenario to run (default: all)'
    )
    
    # Experiment parameters
    parser.add_argument(
        '--max-attempts',
        type=int,
        default=30,
        help='Maximum attempts per scenario (default: 30)'
    )
    
    parser.add_argument(
        '--early-stop',
        type=int,
        default=3,
        help='Stop after N successful misalignments (default: 3)'
    )
    
    # Model parameters
    parser.add_argument(
        '--temperature',
        type=float,
        default=0.8,
        help='Generation temperature (default: 0.8)'
    )
    
    parser.add_argument(
        '--top-p',
        type=float,
        default=0.95,
        help='Top-p sampling (default: 0.95)'
    )
    
    parser.add_argument(
        '--max-tokens',
        type=int,
        default=2048,
        help='Maximum new tokens to generate (default: 2048)'
    )
    
    # Paths
    parser.add_argument(
        '--model',
        type=str,
        default='deepseek-ai/DeepSeek-R1-Distill-Qwen-14B',
        help='Model name or path'
    )
    
    parser.add_argument(
        '--cache-dir',
        type=str,
        default='./model_cache',
        help='Model cache directory (default: ./model_cache)'
    )
    
    parser.add_argument(
        '--output-dir',
        type=str,
        default='./outputs/qwen14b',
        help='Output directory for results (default: ./outputs/qwen14b)'
    )
    
    # Flags
    parser.add_argument(
        '--test',
        action='store_true',
        help='Run in test mode with minimal settings'
    )
    
    parser.add_argument(
        '--cpu',
        action='store_true',
        help='Force CPU usage even if GPU is available'
    )
    
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    parser.add_argument(
        '--seed',
        type=int,
        default=42,
        help='Random seed for reproducibility (default: 42)'
    )
    
    return parser.parse_args()


def main():
    """Main execution function."""
    args = parse_arguments()
    
    # Adjust for test mode
    if args.test:
        logger.info("Running in TEST MODE")
        args.max_attempts = min(args.max_attempts, 3)
        args.early_stop = min(args.early_stop, 2)
    
    # Create configuration
    config = ExperimentConfig(
        model_name=args.model,
        max_attempts=args.max_attempts,
        early_stop_threshold=args.early_stop,
        temperature=args.temperature,
        top_p=args.top_p,
        max_new_tokens=args.max_tokens,
        device='cpu' if args.cpu else 'cuda',
        cache_dir=args.cache_dir,
        output_dir=args.output_dir,
        verbose=args.verbose,
        seed=args.seed
    )
    
    # Set scenarios based on argument
    if args.scenario != 'all':
        config.scenarios = [args.scenario]
    
    # Log configuration
    logger.info("Experiment Configuration:")
    logger.info(f"  Model: {config.model_name}")
    logger.info(f"  Device: {config.device}")
    logger.info(f"  Scenarios: {config.scenarios}")
    logger.info(f"  Max attempts: {config.max_attempts}")
    logger.info(f"  Early stop: {config.early_stop_threshold}")
    logger.info(f"  Temperature: {config.temperature}")
    logger.info(f"  Top-p: {config.top_p}")
    logger.info(f"  Output dir: {config.output_dir}")
    
    # Create runner
    runner = QwenMisalignmentRunner(config)
    
    try:
        # Load model
        logger.info("\n" + "="*50)
        logger.info("Loading model...")
        logger.info("="*50)
        runner.load_model()
        
        # Run experiments
        logger.info("\n" + "="*50)
        logger.info("Starting experiments...")
        logger.info("="*50)
        
        if len(config.scenarios) == 1:
            # Single scenario
            summary = runner.run_scenario(config.scenarios[0])
            
            # Print summary
            print(f"\n{'='*50}")
            print(f"RESULTS: {config.scenarios[0]}")
            print(f"{'='*50}")
            print(f"Total attempts: {summary.total_attempts}")
            print(f"Successful misalignments: {summary.successful_misalignments}")
            print(f"Misalignment rate: {summary.misalignment_rate:.1%}")
            print(f"Average confidence: {summary.avg_confidence:.2f}")
            
            if summary.misalignment_types:
                print("\nMisalignment types:")
                for mtype, count in summary.misalignment_types.items():
                    print(f"  - {mtype}: {count}")
        else:
            # Multiple scenarios
            summaries = runner.run_all_scenarios()
            
            # Print overall summary
            print(f"\n{'='*50}")
            print("OVERALL RESULTS")
            print(f"{'='*50}")
            
            total_attempts = 0
            total_misalignments = 0
            
            for scenario, summary in summaries.items():
                print(f"\n{scenario.upper()}:")
                print(f"  Attempts: {summary.total_attempts}")
                print(f"  Misalignments: {summary.successful_misalignments}")
                print(f"  Rate: {summary.misalignment_rate:.1%}")
                print(f"  Avg confidence: {summary.avg_confidence:.2f}")
                
                total_attempts += summary.total_attempts
                total_misalignments += summary.successful_misalignments
            
            if total_attempts > 0:
                overall_rate = total_misalignments / total_attempts
                print(f"\nOVERALL:")
                print(f"  Total attempts: {total_attempts}")
                print(f"  Total misalignments: {total_misalignments}")
                print(f"  Overall rate: {overall_rate:.1%}")
        
        print(f"\nResults saved to: {config.output_dir}")
        
    except KeyboardInterrupt:
        logger.warning("Experiment interrupted by user")
        runner.save_all_results()
    except Exception as e:
        logger.error(f"Experiment failed: {e}", exc_info=True)
        sys.exit(1)
    finally:
        # Cleanup
        runner.cleanup()
    
    logger.info("\nExperiment complete!")


if __name__ == "__main__":
    main()
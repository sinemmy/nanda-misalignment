#!/usr/bin/env python3
"""
Analyze and visualize misalignment experiment results.
Run this locally after syncing results from vast.ai.
"""

import json
import argparse
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Any
import statistics

def load_results(output_dir: Path) -> Dict[str, List[Dict]]:
    """Load all result files from output directory."""
    results = defaultdict(list)
    
    # Find all result JSON files
    result_files = list(output_dir.glob("*_results_*.json"))
    
    for file_path in result_files:
        # Extract scenario from filename
        scenario = file_path.stem.split("_results_")[0]
        
        with open(file_path, 'r') as f:
            data = json.load(f)
            if isinstance(data, list):
                results[scenario].extend(data)
            else:
                results[scenario].append(data)
    
    return results

def analyze_scenario(scenario: str, results: List[Dict]) -> Dict[str, Any]:
    """Analyze results for a single scenario."""
    misaligned = [r for r in results if r.get('is_misaligned')]
    aligned = [r for r in results if not r.get('is_misaligned')]
    
    # Count misalignment types
    misalignment_types = defaultdict(int)
    confidence_scores = []
    
    for result in misaligned:
        mtype = result.get('misalignment_type', 'unknown')
        misalignment_types[mtype] += 1
        confidence_scores.append(result.get('confidence_score', 0))
    
    # Calculate statistics
    analysis = {
        'scenario': scenario,
        'total_attempts': len(results),
        'misaligned_count': len(misaligned),
        'aligned_count': len(aligned),
        'misalignment_rate': len(misaligned) / len(results) if results else 0,
        'misalignment_types': dict(misalignment_types),
        'avg_confidence': statistics.mean(confidence_scores) if confidence_scores else 0,
        'confidence_std': statistics.stdev(confidence_scores) if len(confidence_scores) > 1 else 0,
    }
    
    # Find prompt variations that worked best
    variation_success = defaultdict(lambda: {'attempts': 0, 'misaligned': 0})
    for result in results:
        variation = result.get('prompt', {}).get('variation', 'unknown')
        variation_success[variation]['attempts'] += 1
        if result.get('is_misaligned'):
            variation_success[variation]['misaligned'] += 1
    
    analysis['variation_success'] = {
        k: {
            'attempts': v['attempts'],
            'misaligned': v['misaligned'],
            'rate': v['misaligned'] / v['attempts'] if v['attempts'] > 0 else 0
        }
        for k, v in variation_success.items()
    }
    
    return analysis

def print_analysis(analysis: Dict[str, Any], verbose: bool = False):
    """Print analysis results in a readable format."""
    print(f"\n{'='*60}")
    print(f"SCENARIO: {analysis['scenario'].upper()}")
    print(f"{'='*60}")
    
    print(f"Total Attempts: {analysis['total_attempts']}")
    print(f"Misaligned: {analysis['misaligned_count']} ({analysis['misalignment_rate']:.1%})")
    print(f"Aligned: {analysis['aligned_count']}")
    
    if analysis['misalignment_types']:
        print(f"\nMisalignment Types:")
        for mtype, count in sorted(analysis['misalignment_types'].items(), 
                                  key=lambda x: x[1], reverse=True):
            print(f"  • {mtype}: {count}")
    
    if analysis['avg_confidence'] > 0:
        print(f"\nConfidence Statistics:")
        print(f"  • Average: {analysis['avg_confidence']:.2f}")
        print(f"  • Std Dev: {analysis['confidence_std']:.2f}")
    
    if verbose and analysis['variation_success']:
        print(f"\nPrompt Variation Success:")
        for variation, stats in sorted(analysis['variation_success'].items(), 
                                      key=lambda x: x[1]['rate'], reverse=True):
            if stats['attempts'] > 0:
                print(f"  • {variation}: {stats['misaligned']}/{stats['attempts']} ({stats['rate']:.1%})")

def export_summary(all_analysis: Dict[str, Dict], output_file: Path):
    """Export analysis summary to JSON."""
    summary = {
        'total_scenarios': len(all_analysis),
        'scenarios': all_analysis,
        'overall_stats': {
            'total_attempts': sum(a['total_attempts'] for a in all_analysis.values()),
            'total_misaligned': sum(a['misaligned_count'] for a in all_analysis.values()),
            'overall_rate': sum(a['misaligned_count'] for a in all_analysis.values()) / 
                          sum(a['total_attempts'] for a in all_analysis.values())
                          if any(a['total_attempts'] for a in all_analysis.values()) else 0
        }
    }
    
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n✅ Summary exported to: {output_file}")

def find_interesting_examples(output_dir: Path, num_examples: int = 5):
    """Find interesting misalignment examples."""
    print(f"\n{'='*60}")
    print(f"INTERESTING MISALIGNMENT EXAMPLES")
    print(f"{'='*60}")
    
    # Load individual misalignment files
    misalignment_files = list(output_dir.glob("misalignment_*.json"))
    
    if not misalignment_files:
        print("No individual misalignment files found")
        return
    
    # Sort by confidence score
    examples = []
    for file_path in misalignment_files:
        with open(file_path, 'r') as f:
            data = json.load(f)
            examples.append((data.get('confidence_score', 0), data))
    
    examples.sort(reverse=True)
    
    # Show top examples
    for i, (confidence, example) in enumerate(examples[:num_examples], 1):
        print(f"\n--- Example {i} (Confidence: {confidence:.2f}) ---")
        print(f"Scenario: {example.get('scenario')}")
        print(f"Type: {example.get('misalignment_type')}")
        print(f"\nUser Prompt: {example.get('prompt', {}).get('user', '')[:200]}...")
        print(f"\nCoT Reasoning: {example.get('cot_reasoning', '')[:300]}...")
        print(f"\nFinal Answer: {example.get('final_answer', '')[:300]}...")

def main():
    parser = argparse.ArgumentParser(description="Analyze misalignment experiment results")
    parser.add_argument(
        '--dir',
        type=str,
        default='./outputs/qwen14b',
        help='Directory containing results (default: ./outputs/qwen14b)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Show detailed analysis'
    )
    parser.add_argument(
        '--examples',
        type=int,
        default=5,
        help='Number of interesting examples to show'
    )
    parser.add_argument(
        '--export',
        type=str,
        help='Export summary to JSON file'
    )
    
    args = parser.parse_args()
    
    output_dir = Path(args.dir)
    if not output_dir.exists():
        print(f"❌ Directory not found: {output_dir}")
        print("Run deploy/deploy_run_terminate.sh to get results from vast.ai")
        return
    
    # Load and analyze results
    results = load_results(output_dir)
    
    if not results:
        print(f"❌ No results found in {output_dir}")
        return
    
    print(f"📊 Analyzing results from: {output_dir}")
    print(f"Found results for scenarios: {', '.join(results.keys())}")
    
    # Analyze each scenario
    all_analysis = {}
    for scenario, scenario_results in results.items():
        analysis = analyze_scenario(scenario, scenario_results)
        all_analysis[scenario] = analysis
        print_analysis(analysis, verbose=args.verbose)
    
    # Overall summary
    if len(all_analysis) > 1:
        print(f"\n{'='*60}")
        print("OVERALL SUMMARY")
        print(f"{'='*60}")
        total_attempts = sum(a['total_attempts'] for a in all_analysis.values())
        total_misaligned = sum(a['misaligned_count'] for a in all_analysis.values())
        print(f"Total Attempts: {total_attempts}")
        print(f"Total Misaligned: {total_misaligned}")
        print(f"Overall Rate: {total_misaligned/total_attempts:.1%}" if total_attempts > 0 else "N/A")
    
    # Find interesting examples
    if args.examples > 0:
        find_interesting_examples(output_dir, args.examples)
    
    # Export if requested
    if args.export:
        export_file = Path(args.export)
        export_summary(all_analysis, export_file)

if __name__ == "__main__":
    main()
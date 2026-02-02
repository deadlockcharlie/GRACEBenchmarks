#!/usr/bin/env python3
"""
Plot divergence time series from wave-based replication experiment.
Reads CSV output and generates a time-series plot showing replica divergence over time.
"""

import argparse
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import Optional

# Configuration
PLOT_STYLE = {
    "divergence": {"color": "tab:red", "linestyle": "-", "marker": "o"},
    "same": {"color": "tab:green", "linestyle": "--", "marker": "s"},
    "different": {"color": "tab:orange", "linestyle": ":", "marker": "^"},
}

# Per-database visual identity
DB_STYLE = {
    "JanusGraph": {"color": "tab:orange", "marker": "s"},
    "GRACE":      {"color": "tab:red",   "marker": "x"},
}

def parse_divergence_csv(file_path: Path) -> pd.DataFrame:
    """Parse the divergence time series CSV file."""
    try:
        df = pd.read_csv(file_path)
        
        # Validate required columns
        required_cols = ['wave', 'sample_size', 'same', 'different', 'missing', 'divergence_rate']
        for col in required_cols:
            if col not in df.columns:
                raise ValueError(f"Missing required column: {col}")
        
        return df
    except Exception as e:
        raise RuntimeError(f"Error parsing CSV file: {e}")

def calculate_cumulative_time(df: pd.DataFrame, reconciliation_wait_ms: int, 
                               updates_per_wave: int, delay_ms: int) -> pd.DataFrame:
    """
    Calculate cumulative time for each wave based on experiment parameters.
    
    Args:
        df: DataFrame with wave data
        reconciliation_wait_ms: Wait time between waves (ms)
        updates_per_wave: Number of updates per wave per replica
        delay_ms: Delay between individual updates (ms)
    """
    # Estimate time per wave (updates + delay + reconciliation)
    # Assumes both replicas run in parallel, so time = max(r1, r2) ≈ updates_per_wave * delay_ms
    wave_update_time_ms = updates_per_wave * delay_ms
    wave_total_time_ms = wave_update_time_ms + reconciliation_wait_ms
    
    # Calculate cumulative time in seconds
    df['time_sec'] = (df['wave'] * wave_total_time_ms) / 1000.0
    
    return df

def load_db_csv(file_path: Path, reconciliation_wait_ms: int,
                updates_per_wave: int, delay_ms: int) -> pd.DataFrame:
    """Parse a CSV and compute time_sec in one step."""
    df = parse_divergence_csv(file_path)
    if 'duration_ms' not in df.columns:
        df = calculate_cumulative_time(df, reconciliation_wait_ms, updates_per_wave, delay_ms)
    else:
        df['time_sec'] = df['duration_ms'].cumsum() / 1000.0
    return df


def stretch_to_timescale(df_target: pd.DataFrame,
                         df_source: pd.DataFrame) -> pd.DataFrame:
    """
    Resample *df_source* (GRACE) onto the time grid of *df_target* (JanusGraph).

    Each column is interpolated independently:
      - divergence_rate          → linear  (continuous percentage)
      - same, different, missing → nearest (integer vertex counts)
      - sample_size              → nearest (constant per experiment, but kept safe)
      - wave                     → recomputed as 1-based row index

    The returned DataFrame has exactly the same rows / time_sec values as
    *df_target*, so both series can be plotted on a shared x-axis.
    """
    target_times = df_target['time_sec'].values
    source_times = df_source['time_sec'].values

    # Columns that should be interpolated linearly vs nearest
    linear_cols  = ['divergence_rate']
    nearest_cols = ['same', 'different', 'missing', 'sample_size']

    stretched = pd.DataFrame()
    stretched['time_sec'] = target_times
    stretched['wave']     = np.arange(1, len(target_times) + 1)

    for col in linear_cols:
        stretched[col] = np.interp(target_times, source_times, df_source[col].values)

    for col in nearest_cols:
        # np.interp is linear-only; use searchsorted for nearest-neighbour
        indices = np.searchsorted(source_times, target_times)
        # Clamp to valid range
        indices = np.clip(indices, 0, len(source_times) - 1)
        # Pick whichever neighbour is actually closer
        prev_idx = np.clip(indices - 1, 0, len(source_times) - 1)
        closer   = np.where(
            np.abs(target_times - source_times[prev_idx])
            < np.abs(target_times - source_times[indices]),
            prev_idx, indices
        )
        stretched[col] = df_source[col].values[closer]

    return stretched


def plot_divergence_rate(df: pd.DataFrame, output_path: str, 
                         title: str = "Replica Divergence Over Time",
                         show_reconciliation: bool = True,
                         reconciliation_wait_ms: int = 3000,
                         df_grace: Optional[pd.DataFrame] = None):
    """
    Plot divergence rate over time with wave markers.
    
    Args:
        df: DataFrame with JanusGraph divergence data
        output_path: Path to save the figure
        title: Plot title
        show_reconciliation: Whether to shade reconciliation periods
        reconciliation_wait_ms: Duration of reconciliation periods in ms
        df_grace: Optional DataFrame with GRACE divergence data
    """
    fig, ax = plt.subplots(figsize=(10, 4))
    
    # Plot all databases
    datasets = [("JanusGraph", df)]
    if df_grace is not None:
        datasets.append(("GRACE", df_grace))

    for name, data in datasets:
        style = DB_STYLE[name]
        ax.plot(
            data['time_sec'], data['divergence_rate'],
            label=name,
            color=style["color"],
            linestyle="-",
            marker=style["marker"],
            markersize=8,
            linewidth=2
        )
    
    # Mark each wave point (JanusGraph only, to avoid clutter)
    for idx, row in df.iterrows():
        ax.annotate(
            f"W{int(row['wave'])}",
            (row['time_sec'], row['divergence_rate']),
            textcoords="offset points",
            xytext=(0, 10),
            ha='center',
            fontsize=8,
            color='darkred'
        )
    
    # Shade reconciliation periods if requested
    if show_reconciliation and 'time_sec' in df.columns and len(df) > 1:
        reconciliation_duration_sec = reconciliation_wait_ms / 1000.0
        
        for idx, row in df.iterrows():
            recon_start = row['time_sec'] - reconciliation_duration_sec
            recon_end = row['time_sec']
            ax.axvspan(recon_start, recon_end, color='lightblue', alpha=0.3, zorder=0)
    
    # Add zero line
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5, alpha=0.5)
    
    # Labels and formatting
    ax.set_xlabel('Time (seconds)', fontsize=18)
    ax.set_ylabel('Divergence Rate (%)', fontsize=18)
    ax.set_title(title, fontsize=18, fontweight='bold')
    ax.grid(True, linestyle=':', linewidth=0.5, alpha=0.7)
    ax.tick_params(axis='both', which='major', labelsize=14)
    ax.legend(loc='best', fontsize=18, ncols=3)
    
    # Set y-axis limits — account for both series
    all_max = df['divergence_rate'].max()
    if df_grace is not None:
        all_max = max(all_max, df_grace['divergence_rate'].max())
    ax.set_ylim(-5, max(105, all_max + 10))
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=200, bbox_inches='tight')
    plt.close()
    
    print(f"Divergence rate plot saved to: {output_path}")

def _draw_stacked(ax, data: pd.DataFrame, title: str):
    """Draw a single stacked-area panel onto *ax*."""
    ax.fill_between(data['time_sec'], 0, data['same'],
                    label='Same', color='green', alpha=0.6)
    ax.fill_between(data['time_sec'], data['same'], data['same'] + data['different'],
                    label='Different', color='orange', alpha=0.6)
    ax.fill_between(data['time_sec'], data['same'] + data['different'],
                    data['same'] + data['different'] + data['missing'],
                    label='Missing', color='red', alpha=0.6)
    # for _, row in data.iterrows():
    #     ax.plot(row['time_sec'], row['sample_size'], 'ko', markersize=4)
    ax.set_title(title, fontsize=18)
    ax.set_xlabel('Time (seconds)', fontsize=18)
    ax.set_ylabel('No. of Vertices', fontsize=18)
    ax.grid(True, linestyle=':', linewidth=0.5, alpha=0.5)
    ax.tick_params(axis='both', which='major', labelsize=14)
    ax.legend(loc='lower right' , fontsize=14)

def plot_stacked_counts(df: pd.DataFrame, output_path: str,
                       title: str = "Replica Consistency Breakdown",
                       df_grace: Optional[pd.DataFrame] = None):
    """
    Plot stacked area chart showing same/different/missing vertex counts over time.
    When df_grace is provided, creates side-by-side subplots for each database.
    
    Args:
        df: DataFrame with JanusGraph divergence data
        output_path: Path to save the figure
        title: Plot title
        df_grace: Optional DataFrame with GRACE divergence data
    """
    if df_grace is None:
        fig, ax = plt.subplots(figsize=(10, 5))
        _draw_stacked(ax, df, "JanusGraph")
        ax.set_title(title, fontsize=18, fontweight='bold')
    else:
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5), sharey=True)
        _draw_stacked(ax1, df, "JanusGraph")
        _draw_stacked(ax2, df_grace, "GRACE")
        ax2.set_ylabel('')  # shared y-axis label on left only
        fig.suptitle(title, fontsize=18, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=200, bbox_inches='tight')
    plt.close()
    
    print(f"Stacked counts plot saved to: {output_path}")

def plot_combined(df: pd.DataFrame, output_path: str,
                  title="",
                 show_reconciliation: bool = True,
                 reconciliation_wait_ms: int = 3000,
                 df_grace: Optional[pd.DataFrame] = None):
    """
    Create a plot showing divergence rate over time.
    When df_grace is provided both series appear on the same plot.
    
    Args:
        df: DataFrame with JanusGraph divergence data
        output_path: Path to save the figure
        title: Plot title
        show_reconciliation: Whether to shade reconciliation periods
        reconciliation_wait_ms: Duration of reconciliation periods in ms
        df_grace: Optional DataFrame with GRACE divergence data
    """
    fig, ax = plt.subplots(figsize=(10, 4))
    
    # Plot all databases
    datasets = [("JanusGraph", df)]
    if df_grace is not None:
        datasets.append(("GRACE", df_grace))

    for name, data in datasets:
        style = DB_STYLE[name]
        ax.plot(
            data['time_sec'], data['divergence_rate'],
            label=name,
            color=style["color"],
            linestyle="-",
            marker=style["marker"],
            markersize=8,
            linewidth=2
        )
    
    # Add zero line
    ax.axhline(y=0, color='gray', linestyle='--', linewidth=0.5, alpha=0.5)
    
    # Labels and formatting
    ax.set_xlabel('Time (seconds)', fontsize=18)
    ax.set_ylabel('Lost updates (%)', fontsize=18)
    ax.set_title(title, fontsize=18, fontweight='bold')
    ax.grid(True, linestyle=':', linewidth=0.5, alpha=0.7)
    ax.tick_params(axis='both', which='major', labelsize=14)
    ax.legend(loc='best', fontsize=18, ncols=3)
    
    # Set y-axis limits — account for both series
    all_max = df['divergence_rate'].max()
    if df_grace is not None:
        all_max = max(all_max, df_grace['divergence_rate'].max())
    ax.set_ylim(-5, max(105, all_max + 10))
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=200, bbox_inches='tight')
    plt.close()
    
    print(f"Combined plot saved to: {output_path}")

def print_summary_statistics(df: pd.DataFrame, df_grace: Optional[pd.DataFrame] = None):
    """Print summary statistics of the divergence experiment for each database."""
    
    datasets = [("JanusGraph", df)]
    if df_grace is not None:
        datasets.append(("GRACE", df_grace))

    print("\n" + "="*60)
    print("DIVERGENCE SUMMARY STATISTICS")
    print("="*60)

    for name, data in datasets:
        print(f"\n--- {name} ---")
        print(f"  Total waves: {len(data)}")
        print(f"  Sample size per wave: {data['sample_size'].iloc[0] if len(data) > 0 else 'N/A'}")

        print(f"  Divergence Rate:")
        print(f"    Average: {data['divergence_rate'].mean():.2f}%")
        print(f"    Minimum: {data['divergence_rate'].min():.2f}%")
        print(f"    Maximum: {data['divergence_rate'].max():.2f}%")
        print(f"    Std Dev: {data['divergence_rate'].std():.2f}%")

        if len(data) > 1:
            z = np.polyfit(data['wave'], data['divergence_rate'], 1)
            trend_slope = z[0]
            trend_direction = ("↗ Increasing" if trend_slope > 0.5
                               else "↘ Decreasing" if trend_slope < -0.5
                               else "→ Stable")
            print(f"  Trend: {trend_direction} ({trend_slope:+.2f}% per wave)")

        sample = data['sample_size'].iloc[0]
        print(f"  Consistency Breakdown (avg across waves):")
        print(f"    Same:      {data['same'].mean():.1f} vertices ({data['same'].mean()/sample*100:.1f}%)")
        print(f"    Different: {data['different'].mean():.1f} vertices ({data['different'].mean()/sample*100:.1f}%)")
        print(f"    Missing:   {data['missing'].mean():.1f} vertices ({data['missing'].mean()/sample*100:.1f}%)")

    print("\n" + "="*60 + "\n")

def main():
    parser = argparse.ArgumentParser(
        description="Plot divergence time series from wave-based replication experiment.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # JanusGraph only
  python plot_divergence.py janusgt.csv plot.png

  # JanusGraph + GRACE comparison
  python plot_divergence.py janusgt.csv plot.png --grace-csv grace.csv

  # With explicit timing parameters
  python plot_divergence.py janusgt.csv plot.png --grace-csv grace.csv --reconciliation-wait 5000 --updates-per-wave 100 --delay 10
  
  # Generate all plot types
  python plot_divergence.py janusgt.csv combined.png --grace-csv grace.csv --plot-type combined
  python plot_divergence.py janusgt.csv divergence.png --grace-csv grace.csv --plot-type divergence
  python plot_divergence.py janusgt.csv stacked.png --grace-csv grace.csv --plot-type stacked
        """
    )
    
    parser.add_argument("csv_file", type=str,
                       help="Path to the JanusGraph divergence time series CSV file")
    parser.add_argument("output_file", type=str,
                       help="Path to save the output plot (e.g., plot.png)")
    
    parser.add_argument("--grace-csv", type=str, default=None,
                       help="Path to the GRACE divergence time series CSV file (optional)")

    parser.add_argument("--plot-type", type=str, default="combined",
                       choices=["combined", "divergence", "stacked"],
                       help="Type of plot to generate (default: combined)")
    
    parser.add_argument("--title", type=str, default=None,
                       help="Custom plot title")
    
    parser.add_argument("--reconciliation-wait", type=int, default=3000,
                       help="Reconciliation wait time between waves in ms (default: 3000)")
    
    parser.add_argument("--updates-per-wave", type=int, default=50,
                       help="Number of updates per wave per replica (default: 50)")
    
    parser.add_argument("--delay", type=int, default=10,
                       help="Delay between updates in ms (default: 10)")
    
    parser.add_argument("--no-reconciliation-shade", action="store_true",
                       help="Don't shade reconciliation periods")
    
    parser.add_argument("--no-summary", action="store_true",
                       help="Don't print summary statistics")
    
    args = parser.parse_args()
    
    # ── Load JanusGraph CSV ───────────────────────────────────────────
    csv_path = Path(args.csv_file)
    if not csv_path.exists():
        print(f"Error: CSV file not found: {csv_path}")
        return 1
    
    df = load_db_csv(csv_path, args.reconciliation_wait,
                     args.updates_per_wave, args.delay)

    # ── Load GRACE CSV (optional) ─────────────────────────────────────
    df_grace = None
    if args.grace_csv:
        grace_path = Path(args.grace_csv)
        if not grace_path.exists():
            print(f"Error: GRACE CSV file not found: {grace_path}")
            return 1
        df_grace = load_db_csv(grace_path, args.reconciliation_wait,
                               args.updates_per_wave, args.delay)

    # ── Stretch GRACE onto JanusGraph's time grid (plot only) ────────
    df_grace_plot = None
    if df_grace is not None:
        df_grace_plot = stretch_to_timescale(df, df_grace)

    # ── Summary (use original, un-stretched GRACE) ────────────────────
    if not args.no_summary:
        print_summary_statistics(df, df_grace)
    
    # ── Plot (use stretched GRACE so both share JanusGraph's x-axis) ──
    show_recon = not args.no_reconciliation_shade
    
    if args.plot_type == "combined":
        plot_combined(df, args.output_file,
                     show_reconciliation=show_recon,
                     reconciliation_wait_ms=args.reconciliation_wait,
                     df_grace=df_grace_plot)
    elif args.plot_type == "divergence":
        plot_divergence_rate(df, args.output_file,
                            show_reconciliation=show_recon,
                            reconciliation_wait_ms=args.reconciliation_wait,
                            df_grace=df_grace_plot)
    elif args.plot_type == "stacked":
        plot_stacked_counts(df, args.output_file, df_grace=df_grace_plot)
    
    return 0

if __name__ == "__main__":
    exit(main())
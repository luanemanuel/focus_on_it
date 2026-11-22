import json
from pathlib import Path

import matplotlib.pyplot as plt


BENCH_DIR = Path(__file__).resolve().parent
ROOT_DIR = BENCH_DIR.parent
RESULTS_DIR = BENCH_DIR / 'results'
RESULTS_PATH = BENCH_DIR / 'results.json'
OUTPUT_DIR = ROOT_DIR / 'assets' / 'benchmarks'

COLORS = {
    'focus_on_it 3.0 (Fast Path)': '#0A66C2',
    'focus_on_it 3.0 (Viewport)': '#0891B2',
    'focus_on_it 2.0.1': '#64748B',
    'focus_on_it 1.0.6': '#94A3B8',
    'focus_detector_v2': '#475569',
    'visibility_detector': '#CBD5E1',
}

LINE_STYLES = {
    'focus_on_it 3.0 (Fast Path)': ('#0A66C2', '-', 2.7, 'o', 6),
    'focus_on_it 3.0 (Viewport)': ('#0891B2', '-', 2.4, 's', 5),
    'focus_on_it 2.0.1': ('#64748B', '--', 1.8, '^', 4),
    'focus_on_it 1.0.6': ('#94A3B8', ':', 1.8, 'v', 3),
    'focus_detector_v2': ('#475569', '-.', 1.8, 'D', 4),
    'visibility_detector': ('#9CA3AF', '--', 1.6, 'x', 2),
}


def merge_results() -> dict:
    files = sorted(RESULTS_DIR.glob('*.json'))
    if not files:
        raise FileNotFoundError(f'No benchmark result files found in {RESULTS_DIR}')

    records = [json.loads(file.read_text(encoding='utf-8')) for file in files]
    first = records[0]

    merged = {
        'platform': first.get('platform', ''),
        'cpu_cores': first.get('cpu_cores'),
        'dart_version': first.get('dart_version', ''),
        'mode': first.get('mode', 'isolated_runner_concurrency_1'),
        'latency_samples_count': first.get('latency_samples_count', 20),
        'overhead_samples_count': first.get('overhead_samples_count', 120),
        'widgets_count': first.get('widgets_count', 100),
        'targets': records,
    }

    RESULTS_PATH.write_text(json.dumps(merged, indent=2), encoding='utf-8')
    return merged


def render_bar_chart(
    records: list[dict],
    metric_key: str,
    title: str,
    subtitle: str,
    xlabel: str,
    unit: str,
    output_path: Path,
) -> None:
    ordered = sorted(
        records,
        key=lambda item: item[metric_key]['median'],
        reverse=True,
    )
    labels = [item['name'] for item in ordered]
    medians = [item[metric_key]['median'] for item in ordered]
    stddevs = [item[metric_key]['stddev'] for item in ordered]
    p95s = [item[metric_key]['p95'] for item in ordered]
    bar_colors = [COLORS.get(label, '#94A3B8') for label in labels]

    fig, ax = plt.subplots(figsize=(9.6, 4.9), dpi=300)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')

    bars = ax.barh(
        labels,
        medians,
        xerr=stddevs,
        color=bar_colors,
        height=0.56,
        edgecolor='none',
        error_kw={
            'ecolor': '#334155',
            'elinewidth': 1.15,
            'capsize': 3,
            'capthick': 1.15,
        },
    )

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#E2E8F0')
    ax.spines['bottom'].set_color('#E2E8F0')

    ax.xaxis.grid(True, linestyle='--', linewidth=0.7, color='#E2E8F0', alpha=0.85)
    ax.set_axisbelow(True)

    max_extent = max((m + s for m, s in zip(medians, stddevs)), default=1.0)
    ax.set_xlim(0, max_extent * 1.38)

    ax.tick_params(axis='y', labelsize=10.5, colors='#0F172A', length=0, pad=8)
    ax.tick_params(axis='x', labelsize=9.5, colors='#475569')
    ax.set_xlabel(xlabel, fontsize=10, color='#334155', labelpad=10)

    for bar, label, med, sd, p95 in zip(bars, labels, medians, stddevs, p95s):
        fmt = '.2f' if med < 10 else '.1f'
        text = f'{med:{fmt}} {unit}  (p95: {p95:{fmt}})'
        is_v3 = '3.0' in label
        ax.text(
            med + sd + max_extent * 0.022,
            bar.get_y() + bar.get_height() / 2,
            text,
            va='center',
            ha='left',
            fontsize=9.2,
            fontweight='bold' if is_v3 else 'normal',
            color='#0F172A' if is_v3 else '#475569',
        )

    ax.text(
        0.0,
        1.14,
        title,
        transform=ax.transAxes,
        ha='left',
        va='bottom',
        fontsize=13.5,
        fontweight='bold',
        color='#0F172A',
    )
    ax.text(
        0.0,
        1.05,
        subtitle,
        transform=ax.transAxes,
        ha='left',
        va='bottom',
        fontsize=9.8,
        color='#64748B',
    )

    plt.tight_layout(rect=[0.02, 0.02, 0.98, 0.90])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=300, facecolor='#FFFFFF')
    plt.close(fig)


def render_scalability_chart(records: list[dict], output_path: Path) -> None:
    counts = [10, 50, 100, 250]

    fig, ax = plt.subplots(figsize=(9.6, 5.1), dpi=300)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')

    max_ms = 0.0
    for record in records:
        name = record['name']
        scale_map = record['scalability_us']
        medians_ms = [scale_map[str(c)]['median'] / 1000.0 for c in counts]
        max_ms = max(max_ms, *medians_ms)
        color, linestyle, lw, marker, zorder = LINE_STYLES.get(
            name, ('#94A3B8', '-', 1.8, 'o', 2)
        )
        ax.plot(
            counts,
            medians_ms,
            label=name,
            color=color,
            linestyle=linestyle,
            linewidth=lw,
            marker=marker,
            markersize=6 if '3.0' in name else 4.8,
            zorder=zorder,
        )

    budget_ms = 16.67
    if max_ms >= 10.0:
        ax.axhline(
            budget_ms,
            color='#DC2626',
            linestyle=':',
            linewidth=1.2,
            alpha=0.75,
            zorder=1,
        )
        ax.text(
            135,
            budget_ms + max(max_ms, budget_ms) * 0.022,
            '16.67 ms (60 fps budget)',
            fontsize=8.8,
            color='#B91C1C',
            ha='center',
            va='bottom',
        )

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#E2E8F0')
    ax.spines['bottom'].set_color('#E2E8F0')

    ax.grid(True, linestyle='--', linewidth=0.7, color='#E2E8F0', alpha=0.85)
    ax.set_axisbelow(True)

    ax.set_xticks(counts)
    ax.set_xticklabels([str(c) for c in counts])
    ax.set_ylim(0, max(max_ms, budget_ms if max_ms >= 10.0 else 0) * 1.18)

    ax.tick_params(axis='both', labelsize=9.8, colors='#334155')
    ax.set_xlabel('Tracked widgets mounted simultaneously', fontsize=10, color='#334155', labelpad=10)
    ax.set_ylabel('Median frame time (ms)', fontsize=10, color='#334155', labelpad=10)

    ax.legend(
        loc='upper left',
        frameon=True,
        facecolor='#FFFFFF',
        edgecolor='#E2E8F0',
        fontsize=9,
    )

    ax.text(
        0.0,
        1.14,
        'Frame Overhead Scalability (10 to 250 Widgets)',
        transform=ax.transAxes,
        ha='left',
        va='bottom',
        fontsize=13.5,
        fontweight='bold',
        color='#0F172A',
    )
    ax.text(
        0.0,
        1.05,
        'Median frame time (ms) across 40 samples per scale — Lower is better',
        transform=ax.transAxes,
        ha='left',
        va='bottom',
        fontsize=9.8,
        color='#64748B',
    )

    plt.tight_layout(rect=[0.02, 0.02, 0.98, 0.90])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=300, facecolor='#FFFFFF')
    plt.close(fig)


def main() -> None:
    data = merge_results()
    records = data['targets']
    lat_n = data.get('latency_samples_count', 20)
    ovh_n = data.get('overhead_samples_count', 120)
    widgets_n = data.get('widgets_count', 100)

    render_bar_chart(
        records=records,
        metric_key='detection_latency_ms',
        title='Route Unfocus Detection Latency',
        subtitle=f'Median (p50) ± SD across n={lat_n} runs, isolated runners — Lower is better',
        xlabel='Milliseconds (ms)',
        unit='ms',
        output_path=OUTPUT_DIR / 'detection_latency.png',
    )

    render_bar_chart(
        records=records,
        metric_key='frame_overhead_us',
        title=f'Frame Build & Layout Overhead ({widgets_n} tracked widgets)',
        subtitle=f'Median (p50) ± SD across n={ovh_n} frames, 0ms interval — Lower is better',
        xlabel='Microseconds per frame (us)',
        unit='us',
        output_path=OUTPUT_DIR / 'frame_overhead.png',
    )

    render_scalability_chart(
        records=records,
        output_path=OUTPUT_DIR / 'scalability.png',
    )

    print(f'Generated 3 charts in {OUTPUT_DIR}')


if __name__ == '__main__':
    main()

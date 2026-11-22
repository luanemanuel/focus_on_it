import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch


BENCH_DIR = Path(__file__).resolve().parent
ROOT_DIR = BENCH_DIR.parent
RESULTS_DIR = BENCH_DIR / 'results'
RESULTS_PATH = BENCH_DIR / 'results.json'
OUTPUT_DIR = ROOT_DIR / 'assets' / 'benchmarks'

DISPLAY_NAMES = {
    'focus_on_it 3.0 (Fast Path)': 'Focus on It 3.0 (Fast Path)',
    'focus_on_it 3.0 (Viewport)': 'Focus on It 3.0 (Viewport)',
    'focus_on_it 2.0.1': 'Focus on It 2.0.1',
    'focus_on_it 1.0.6': 'Focus on It 1.0.6',
    'focus_detector_v2': 'focus_detector_v2',
    'visibility_detector': 'visibility_detector',
}

BAR_COLORS = {
    'focus_on_it 3.0 (Fast Path)': '#0A66C2',
    'focus_on_it 3.0 (Viewport)': '#0891B2',
    'focus_on_it 2.0.1': '#94A3B8',
    'focus_on_it 1.0.6': '#CBD5E1',
    'focus_detector_v2': '#94A3B8',
    'visibility_detector': '#CBD5E1',
}


def merge_results() -> dict:
    files = sorted(RESULTS_DIR.glob('*.json'))
    if not files:
        if RESULTS_PATH.exists():
            return json.loads(RESULTS_PATH.read_text(encoding='utf-8'))
        raise FileNotFoundError(f'No benchmark result files found in {RESULTS_DIR}')

    records = [json.loads(file.read_text(encoding='utf-8')) for file in files]
    first = records[0]

    merged = {
        'platform': first.get('platform', ''),
        'cpu_cores': first.get('cpu_cores'),
        'dart_version': first.get('dart_version', ''),
        'mode': first.get('mode', 'isolated_runner_concurrency_1'),
        'latency_samples_count': first.get('latency_samples_count', 20),
        'mount_samples_count': first.get('mount_samples_count', 20),
        'mount_widgets_count': first.get('mount_widgets_count', 250),
        'scroll_samples_count': first.get('scroll_samples_count', 120),
        'scroll_widgets_count': first.get('scroll_widgets_count', 100),
        'targets': records,
    }

    RESULTS_PATH.write_text(json.dumps(merged, indent=2), encoding='utf-8')
    return merged


def _draw_pill(
    ax: plt.Axes,
    x: float,
    y: float,
    w: float,
    h: float,
    radius: float,
    facecolor: str,
    edgecolor: str = 'none',
    linewidth: float = 0.0,
    zorder: int = 2,
) -> None:
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle=f'round,pad=0,rounding_size={radius}',
        facecolor=facecolor,
        edgecolor=edgecolor,
        linewidth=linewidth,
        zorder=zorder,
    )
    ax.add_patch(patch)


def _draw_header(
    ax: plt.Axes,
    title: str,
    subtitle: str,
    footer: str,
) -> None:
    _draw_pill(ax, x=30, y=418, w=5, h=42, radius=2, facecolor='#0A66C2')
    ax.text(
        46,
        462,
        title,
        fontsize=15.5,
        fontweight='bold',
        color='#0F172A',
        ha='left',
        va='top',
    )
    ax.text(
        46,
        433,
        subtitle,
        fontsize=9.6,
        color='#64748B',
        ha='left',
        va='top',
    )

    legend_items = [
        ('#0A66C2', '3.0 Fast Path (default)', 612),
        ('#0891B2', '3.0 Viewport (opt-in)', 790),
        ('#94A3B8', 'Previous & others', 958),
    ]
    for color, label, lx in legend_items:
        _draw_pill(ax, x=lx, y=444, w=12, h=12, radius=3, facecolor=color)
        ax.text(
            lx + 18,
            450,
            label,
            fontsize=8.8,
            color='#334155',
            ha='left',
            va='center',
        )

    ax.plot([30, 1110], [400, 400], color='#E2E8F0', linewidth=0.9, zorder=1)
    ax.plot([570, 570], [66, 382], color='#F1F5F9', linewidth=1.1, zorder=1)
    ax.text(
        30,
        24,
        footer,
        fontsize=8.4,
        color='#64748B',
        ha='left',
        va='bottom',
    )


def _draw_metric_panel(
    ax: plt.Axes,
    px: float,
    panel_title: str,
    rows: list[tuple[str, float, float]],
    show_speedup_against: float | None = None,
    highlight_fastest_v3: bool = False,
) -> None:
    ax.text(
        px,
        380,
        panel_title,
        fontsize=11.2,
        fontweight='bold',
        color='#0F172A',
        ha='left',
        va='top',
    )

    ordered = sorted(rows, key=lambda item: item[1])
    max_val = max((r[1] for r in ordered), default=1.0)
    best_val = ordered[0][1] if ordered else 0.0

    label_x = px + 178
    bar_x = px + 190
    bar_max_w = 156
    bar_h = 20
    row_ys = [330, 282, 234, 186, 138, 90]

    ax.plot(
        [bar_x, bar_x],
        [72, 348],
        color='#CBD5E1',
        linewidth=1.0,
        zorder=1,
    )

    pending_secondary: list[tuple[plt.Text, bool, bool, float, float, float]] = []

    for (key, med, p95), cy in zip(ordered, row_ys):
        is_v3 = '3.0' in key
        is_best = abs(med - best_val) <= 1e-9

        ax.text(
            label_x,
            cy,
            DISPLAY_NAMES[key],
            fontsize=9.1,
            fontweight='bold' if is_v3 else 'normal',
            color='#0F172A' if is_v3 else '#475569',
            ha='right',
            va='center',
        )

        fill_w = max(8.0, bar_max_w * (med / max_val)) if max_val > 0 else 8.0
        _draw_pill(
            ax,
            x=bar_x,
            y=cy - bar_h / 2,
            w=fill_w,
            h=bar_h,
            radius=3.5,
            facecolor=BAR_COLORS.get(key, '#94A3B8'),
            zorder=3,
        )

        val_x = bar_x + fill_w + 10
        primary_txt = ax.text(
            val_x,
            cy,
            f'{med:.2f} ms',
            fontsize=9.2,
            fontweight='bold' if (is_v3 or is_best) else 'normal',
            color='#0F172A' if (is_v3 or is_best) else '#475569',
            ha='left',
            va='center',
        )
        show_badge = bool(show_speedup_against and is_v3 and med > 0)
        show_fastest = bool(highlight_fastest_v3 and is_v3 and is_best)
        pending_secondary.append(
            (primary_txt, show_badge, show_fastest, med, p95, cy)
        )

    ax.figure.canvas.draw()
    renderer = ax.figure.canvas.get_renderer()
    inv = ax.transData.inverted()

    pending_fastest: list[tuple[plt.Text, float]] = []
    for primary_txt, show_badge, show_fastest, med, p95, cy in pending_secondary:
        x1 = inv.transform_bbox(primary_txt.get_window_extent(renderer)).x1
        next_x = x1 + 9
        if show_badge and show_speedup_against is not None:
            ratio = show_speedup_against / med
            _draw_pill(
                ax,
                x=next_x,
                y=cy - 9,
                w=82,
                h=18,
                radius=9,
                facecolor='#EFF6FF',
                edgecolor='#BFDBFE',
                linewidth=0.8,
                zorder=2,
            )
            ax.text(
                next_x + 41,
                cy,
                f'{ratio:.0f}x faster',
                fontsize=7.9,
                fontweight='bold',
                color='#1D4ED8',
                ha='center',
                va='center',
                zorder=4,
            )
        else:
            sec_txt = ax.text(
                next_x,
                cy,
                f'(p95: {p95:.2f})',
                fontsize=8.2,
                color='#64748B',
                ha='left',
                va='center',
            )
            if show_fastest:
                pending_fastest.append((sec_txt, cy))

    if pending_fastest:
        ax.figure.canvas.draw()
        renderer = ax.figure.canvas.get_renderer()
        for sec_txt, cy in pending_fastest:
            sec_x1 = inv.transform_bbox(sec_txt.get_window_extent(renderer)).x1
            pill_x = sec_x1 + 9
            _draw_pill(
                ax,
                x=pill_x,
                y=cy - 9,
                w=56,
                h=18,
                radius=9,
                facecolor='#EFF6FF',
                edgecolor='#BFDBFE',
                linewidth=0.8,
                zorder=2,
            )
            ax.text(
                pill_x + 28,
                cy,
                'Fastest',
                fontsize=7.8,
                fontweight='bold',
                color='#1D4ED8',
                ha='center',
                va='center',
                zorder=4,
            )


def _draw_dialog_panel(
    ax: plt.Axes,
    px: float,
    panel_title: str,
    records: list[dict],
) -> None:
    ax.text(
        px,
        380,
        panel_title,
        fontsize=11.2,
        fontweight='bold',
        color='#0F172A',
        ha='left',
        va='top',
    )

    supported = [r for r in records if r['dialog_detection_ms'].get('supported')]
    unsupported = [
        r for r in records if not r['dialog_detection_ms'].get('supported')
    ]
    supported.sort(key=lambda r: r['dialog_detection_ms']['median'])

    order_unsupported = [
        'focus_on_it 2.0.1',
        'focus_on_it 1.0.6',
        'focus_detector_v2',
        'visibility_detector',
    ]
    unsupported.sort(
        key=lambda r: order_unsupported.index(r['name'])
        if r['name'] in order_unsupported
        else 99
    )

    ordered = supported + unsupported
    max_sup = max(
        (r['dialog_detection_ms']['median'] for r in supported),
        default=5.0,
    )

    label_x = px + 178
    bar_x = px + 190
    bar_max_w = 156
    bar_h = 20
    row_ys = [330, 282, 234, 186, 138, 90]

    ax.plot(
        [bar_x, bar_x],
        [72, 348],
        color='#CBD5E1',
        linewidth=1.0,
        zorder=1,
    )

    pending_p95: list[tuple[plt.Text, float, float]] = []

    for record, cy in zip(ordered, row_ys):
        key = record['name']
        dlg = record['dialog_detection_ms']
        is_supported = dlg.get('supported', False)

        ax.text(
            label_x,
            cy,
            DISPLAY_NAMES[key],
            fontsize=9.1,
            fontweight='bold' if is_supported else 'normal',
            color='#0F172A' if is_supported else '#475569',
            ha='right',
            va='center',
        )

        if is_supported:
            med = dlg['median']
            p95 = dlg['p95']
            fill_w = max(24.0, bar_max_w * (med / (max_sup * 1.15)))
            _draw_pill(
                ax,
                x=bar_x,
                y=cy - bar_h / 2,
                w=fill_w,
                h=bar_h,
                radius=3.5,
                facecolor=BAR_COLORS.get(key, '#0A66C2'),
                zorder=3,
            )
            primary_txt = ax.text(
                bar_x + fill_w + 10,
                cy,
                f'{med:.2f} ms',
                fontsize=9.2,
                fontweight='bold',
                color='#0F172A',
                ha='left',
                va='center',
            )
            pending_p95.append((primary_txt, p95, cy))
        else:
            _draw_pill(
                ax,
                x=bar_x,
                y=cy - 10,
                w=118,
                h=20,
                radius=4,
                facecolor='#FEF2F2',
                edgecolor='#FECACA',
                linewidth=0.8,
                zorder=2,
            )
            ax.text(
                bar_x + 59,
                cy,
                'Not detected',
                fontsize=8.4,
                fontweight='bold',
                color='#B91C1C',
                ha='center',
                va='center',
                zorder=4,
            )

    if pending_p95:
        ax.figure.canvas.draw()
        renderer = ax.figure.canvas.get_renderer()
        inv = ax.transData.inverted()
        for primary_txt, p95, cy in pending_p95:
            x1 = inv.transform_bbox(primary_txt.get_window_extent(renderer)).x1
            ax.text(
                x1 + 9,
                cy,
                f'(p95: {p95:.2f})',
                fontsize=8.2,
                color='#64748B',
                ha='left',
                va='center',
            )


def render_detection_speed(data: dict) -> None:
    records = data['targets']
    by_name = {r['name']: r for r in records}
    lat_n = data.get('latency_samples_count', 20)
    dart_ver = data.get('dart_version', '')
    cores = data.get('cpu_cores', '')

    fig, ax = plt.subplots(figsize=(11.4, 4.9), dpi=300)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')
    ax.set_xlim(0, 1140)
    ax.set_ylim(0, 490)
    ax.set_aspect('equal')
    ax.axis('off')

    _draw_header(
        ax,
        title='Focus Detection Speed & Dialog Coverage',
        subtitle=f'Median (p50) across n={lat_n} isolated runs · default production intervals · lower is better',
        footer=f'Isolated runners with warm-up · Dart {dart_ver} ({cores} CPU cores) · raw stats in benchmark/results.json',
    )

    v2_route_median = by_name['focus_on_it 2.0.1']['route_latency_ms']['median']
    route_rows = [
        (
            r['name'],
            r['route_latency_ms']['median'],
            r['route_latency_ms']['p95'],
        )
        for r in records
    ]
    _draw_metric_panel(
        ax,
        px=30,
        panel_title='Route Unfocus Latency (Navigator.push)',
        rows=route_rows,
        show_speedup_against=v2_route_median,
    )

    _draw_dialog_panel(
        ax,
        px=588,
        panel_title='Translucent Dialog / BottomSheet Unfocus',
        records=records,
    )

    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(
        OUTPUT_DIR / 'detection_speed.png',
        dpi=300,
        facecolor='#FFFFFF',
    )
    plt.close(fig)


def render_runtime_performance(data: dict) -> None:
    records = data['targets']
    mount_n = data.get('mount_samples_count', 20)
    mount_w = data.get('mount_widgets_count', 250)
    scroll_n = data.get('scroll_samples_count', 120)
    scroll_w = data.get('scroll_widgets_count', 100)
    dart_ver = data.get('dart_version', '')
    cores = data.get('cpu_cores', '')

    fig, ax = plt.subplots(figsize=(11.4, 4.9), dpi=300)
    fig.patch.set_facecolor('#FFFFFF')
    ax.set_facecolor('#FFFFFF')
    ax.set_xlim(0, 1140)
    ax.set_ylim(0, 490)
    ax.set_aspect('equal')
    ax.axis('off')

    _draw_header(
        ax,
        title='Runtime Build & Scroll Performance',
        subtitle='Fast Path (default) vs Viewport (opt-in) · pure SizedBox trees · lower is better',
        footer=f'Isolated runners with warm-up · Dart {dart_ver} ({cores} CPU cores) · raw stats in benchmark/results.json',
    )

    mount_rows = [
        (
            r['name'],
            r['mount_unmount_250_ms']['median'],
            r['mount_unmount_250_ms']['p95'],
        )
        for r in records
    ]
    _draw_metric_panel(
        ax,
        px=30,
        panel_title=f'Mount & Unmount · {mount_w} Widgets (n={mount_n})',
        rows=mount_rows,
        highlight_fastest_v3=True,
    )

    scroll_rows = [
        (
            r['name'],
            r['scroll_frame_100_ms']['median'],
            r['scroll_frame_100_ms']['p95'],
        )
        for r in records
    ]
    _draw_metric_panel(
        ax,
        px=588,
        panel_title=f'Scroll Frame Cost · {scroll_w} Widgets (n={scroll_n})',
        rows=scroll_rows,
        highlight_fastest_v3=True,
    )

    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(
        OUTPUT_DIR / 'runtime_performance.png',
        dpi=300,
        facecolor='#FFFFFF',
    )
    plt.close(fig)


def main() -> None:
    data = merge_results()
    render_detection_speed(data)
    render_runtime_performance(data)
    print(f'Generated 2 charts in {OUTPUT_DIR}')


if __name__ == '__main__':
    main()

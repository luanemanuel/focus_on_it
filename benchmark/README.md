# Benchmarks

Each package has its own isolated runner under `runners/` with no shared competitor dependencies. Every runner executes separately with `--concurrency=1` and warm-up iterations before measurements are recorded.

## Methodology

- **Route unfocus latency:** 5 warm-up runs + 20 measured runs with default production settings (`500ms` update interval for `visibility_detector`-based packages). Reports median (`p50`), mean, sample standard deviation (`stddev`), `p95`, min, and max.
- **Frame overhead:** 30 warm-up frames + 120 individually timed scroll/rebuild frames across 100 mounted widgets (`0ms` interval so CPU cost is measured without timer waiting).
- **Scalability:** 15 warm-up frames + 40 timed frames at `10`, `50`, `100`, and `250` simultaneously mounted widgets.

## Running the benchmarks

From inside `benchmark/`:

```sh
for runner in runners/focus_on_it_v3 runners/focus_on_it_v2 runners/focus_on_it_v1 runners/focus_detector_v2 runners/visibility_detector; do
  (cd "$runner" && flutter pub get && flutter test --concurrency=1)
done
```

## Generating the charts

```sh
pip install -r requirements.txt
python plot_benchmarks.py
```

The script merges `results/*.json` into `results.json` and writes `detection_latency.png`, `frame_overhead.png`, and `scalability.png` to `../assets/benchmarks/`.

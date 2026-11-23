# Benchmarks

Each package has its own isolated runner under `runners/` with no shared competitor dependencies. Every runner executes separately in Dart JIT via `flutter test --concurrency=1` with warm-up iterations before timings start (`profile`-mode real-device benchmarks are separate).

## Methodology

- **Route unfocus latency:** 5 warm-up runs + 20 measured `Navigator.push` runs using default production intervals (`500ms` for `visibility_detector`-based packages).
- **Translucent dialog detection:** pushes a real centered `RawDialogRoute` (`240x140`) and checks whether unfocus fires (20 measured runs when supported).
- **Mount & unmount (250 widgets):** 5 warm-up cycles + 20 timed mount/unmount cycles of 250 `SizedBox` widgets (`0ms` interval).
- **Scroll frame cost (100 widgets):** 30 warm-up frames + 120 timed `ScrollController.jumpTo` frames across 100 `SizedBox` widgets (`0ms` interval, with no `Text` rebuild noise).

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

The script merges `results/*.json` into `results.json` and writes `detection_speed.png` and `runtime_performance.png` to `../assets/benchmarks/`.

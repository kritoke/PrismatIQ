Benchmarks
----------

This project includes a few small benchmarks under `bench/` to measure the
performance of the core palette extraction pipeline and to help tune
implementation details (threading, sampling `quality`, and merge chunk size).

How to run

- Build and run the main benchmark (release):
  - `crystal build --release bench/benchmark.cr -o bench/bench_bench`
  - `PRISMATIQ_THREADS=4 ./bench/bench_bench bench/test_1080p.jpg`

- Sweep thread counts (1..N) using the runner (will use `bench/bench_bench` if present):
  - `crystal run bench/bench_threads_runner.cr -- 8 bench/test_1080p.jpg`

- Micro-benchmark the merge chunk sizes:
  - `crystal build --release bench/merge_chunk_bench.cr -o bench/merge_chunk_bench`
  - `./bench/merge_chunk_bench`

Why these benches exist
- Detect performance regressions early.
- Measure the effect of `quality` (sampling) and `threads` on throughput.
- Tune `merge_locals_chunked` chunk size to improve cache locality and merge throughput.

Notes
- Benchmarks should be run with `--release` to get accurate numbers.
- Debug logs are gated by `PRISMATIQ_DEBUG` and are helpful for diagnosing threading bugs.

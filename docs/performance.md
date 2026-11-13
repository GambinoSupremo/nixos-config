# Performance

## Keep rebuilds from overwhelming the desktop

`nixos/features/tuning.nix` runs the Nix build daemon at the lowest priority
(`daemonCPUSchedPolicy = "batch"`, best-effort IO priority 7), so builds give
way to games and other interactive work but run near full speed when idle.
On top of that, two simultaneous builds of up to 12 workers each (was 2 x 6)
bound build RAM on the 30 GB desktop. `NIX_BUILD_CORES` is a request, not a
hard quota. See the [Nix cores/jobs documentation](https://nix.dev/manual/nix/2.34/advanced-topics/cores-vs-jobs.html).

`nixos/base/core.nix` also GCs during builds when free space drops below
5 GiB (`min-free`/`max-free`), and `nix.gc.persistent` runs a missed weekly
GC at the next boot.

## Reduce recurring disk work

`services.locate.interval` in `nixos/base/services.nix` is daily instead of
hourly: one scheduled index refresh per day instead of 24. `locate` can
therefore miss recently created files until the next refresh. Use `fd` or
`rg --files` when the results must reflect the filesystem immediately.

The generated index service already uses `Nice=19` and idle I/O scheduling.
The backup service already uses `Nice=10` and idle I/O scheduling. Keep those
priorities; adding identical overrides would not improve them.

## Baseline observed on 2026-11-03

The machine was running Deadlock, so these are workload observations, not
an idle baseline or a before/after benchmark:

- About 17 GiB available RAM, approximately 4 MiB swap used, and zero
  recent memory-pressure averages. There is no evidence here for shrinking
  caches or changing zram.
- The game's cgroup used roughly 5.4 CPU cores during a five-second sample.
- The NVMe read about 67 MiB/s in another five-second sample. I/O pressure
  was elevated, but that alone does not identify the cause or prove the
  drive is saturated.
- The backup completed in about 12.5 seconds with 1.9 seconds CPU time and
  161 MiB peak memory. It was not a persistent background load in this boot.

Cgroup memory includes filesystem cache and descendant applications.
Applications launched by the shell can share its service cgroup, so that
group's total must not be reported as the shell process's own RAM usage.

## Before changing gaming settings

Compare the same game, scene, resolution, frame cap, and warm shader cache.
Record frame times and 1% lows with MangoHud over several repeated runs;
change one setting at a time. Also compare desktop responsiveness during a
source build if rebuild contention is the problem.

Useful read-only checks from a normal terminal:

```sh
free -h
cat /proc/pressure/{cpu,memory,io}
systemd-cgtop
systemd-analyze critical-chain
systemd-analyze --user blame
```

Keep the current scheduler, zram, GPU power settings, HDR, and VRR behavior
until a comparison justifies changing them. A new kernel parameter or
scheduler is not evidence of a performance improvement.

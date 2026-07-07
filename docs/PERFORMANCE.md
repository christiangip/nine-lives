# Performance Budget & Profiling — Nine Lives

**Task 21 · FR-21-2 · GDD §3.** Target: **hold 60 FPS on mid-range hardware in a dense populated scene.**
This document records the enforced AI/instance budgets, the profiling method, and the before/after
measurements. The enforceable logic is unit-tested (`game/tests/unit/test_ai_budget.gd`); the FPS numbers
below are filled in during the manual pass (headless can't measure real GPU frame time).

## Where the frame goes (dense heist scene)

The two per-frame hotspots in a populated mission are:

1. **Detection sensing** — every `DetectionSensor` (one per guard/camera) runs a vision-cone test, a
   **multi-ray line-of-sight** cast (3 rays by default, `DetectionConfigDef.los_sample_heights`), and a
   light-sample every physics frame. At N guards this is `3·N` raycasts/frame, unbudgeted before task 21.
2. **Guard AI** — `GuardAI` steering/state (cheaper than sensing, but scales with N).

Plus rendering (instance count, shadows, MSAA) — tuned via the Options graphics settings
(render scale, shadows, MSAA, max FPS), which are already wired (task 15).

## Enforced budgets (the deferred 05.5 work)

### 1. Distance-LOD sensing + round-robin stagger — `DetectionSensor`
The expensive sense is throttled by the guard's distance to the player, and guards are staggered so their
raycasts don't bunch on one frame. Pure seams `sense_interval_for_distance()` / `should_sense()`:

| Band | Distance to player | Sense cadence |
|---|---|---|
| Full | ≤ `lod_full_range` (default **22 m**) | **every frame** (behaviour unchanged) |
| Mid | ≤ `lod_mid_range` (**40 m**) | every `lod_mid_interval` frames (**2**) |
| Far | ≤ `lod_sleep_range` (**70 m**) | every `lod_far_interval` frames (**4**) |
| Sleep | beyond `lod_sleep_range` | **skipped** (a guard that far can't gain fill anyway) |

- `lod_full_range` sits **past every actor's `vision_range`**, so any guard that can actually see the player
  senses every frame — **detection accuracy and the 04/05 behaviour are unchanged**. Throttling only ever
  applies where the meter can only decay.
- Elapsed time is **accumulated between senses** and passed to `step_fill`, so the meter stays
  framerate-fair regardless of cadence.
- Stagger phase = `instance_id % interval`, so at a given interval different guards fire on different frames.
- **Effect:** raycast load in a dense scene drops from `3·N`/frame toward roughly the near-guard count only;
  distant crowds cost almost nothing.

### 2. Population cap — `MissionPopulator` / `AIConfigDef.max_active_guards` (default **24**)
Density scaling (Tier × Heat × modifiers) can multiply patrols without limit. The populator now caps the
number of **patrol** guards a mission spawns at `max_active_guards`, trimming only the density overflow —
essential actors (e.g. a key-carrying Inspector) are always placed. Deterministic given the seed.

### 3. Rendering knobs (player-facing, already wired)
Render Scale (0.5–1.0), Shadows (Off–High), MSAA (Off–8×), Max FPS — all in Options → Graphics, live-applied
by `SettingsManager`. The accessibility default keeps MSAA at 2×; lowering render scale is the first lever on
a weak GPU.

## Profiling method (manual, on the target spec)

1. Launch the **Polish & Performance Sandbox** (Gallery → "★ Polish & Performance Sandbox").
2. Press **`[G]`** to flood the room with guards in stages (e.g. 10 → 25 → 40). The on-screen readout shows
   `Engine.get_frames_per_second()`, the live guard count, and how many sensors are **full / throttled /
   sleeping** this frame.
3. Read FPS at each density with the LOD budget ON, then toggle it OFF (`[B]`) to capture the before/after.
4. Record the numbers in the table below and commit this file.

> Godot's built-in profiler (Debugger → Profiler / Monitors) and `--print-fps` corroborate the in-scene
> readout. `Performance.get_monitor(Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS)` breaks down CPU cost.

## Measurements (fill during the manual pass)

**Target spec used:** _e.g. GTX 1060 · Ryzen 5 2600 · 16 GB · 1080p_ — replace with the machine tested.

| Scene / density | Budget OFF (FPS) | Budget ON (FPS) | Notes |
|---|---|---|---|
| Generated Bank (typical, ~12 guards) | _tbd_ | _tbd_ | baseline mission |
| Sandbox — 25 guards | _tbd_ | _tbd_ | mid stress |
| Sandbox — 40 guards | _tbd_ | _tbd_ | dense stress; target ≥ 60 |
| Sandbox — 40 guards, render scale 0.8 | _tbd_ | _tbd_ | GPU-limited fallback |

**Result:** _tbd — confirm 60 FPS held at the dense tier on the target spec._

## Notes / future levers (post-M5)
- `GuardAI` steering could also LOD (simplify distant patrol pathing); currently only the sensing hotspot is
  budgeted, which is the dominant cost.
- Occlusion culling / `VisibleOnScreenNotifier3D` for far actors if GPU-bound.
- Physics-tick decoupling for very large levels.

# Contributing / How to build Nine Lives from this repo

This repo is a **plan you execute**. Work is organized as task lists, not a vague
backlog. Here's the loop.

## 1. Pick work from the master list
Open `docs/tasks/00_MASTER_TASKLIST.md`. It tracks every sub-system list, their
dependencies, and the milestone gates **M0–M5**. Always work the lowest-numbered
*unblocked* task list first; within a list, complete **phases in order**.

## 2. Work a phase
Each sub-system list has: Functional Requirements → ordered Phases (checkbox tasks)
→ Tests → Definition of Done. For each phase:
1. Write/locate the GUT tests named in the Tests section (test-first for rules).
2. Implement until those tests pass and the phase's checkboxes are true.
3. Tick the checkboxes in the markdown (the lists are living progress trackers —
   commit the ticks).

## 3. Branch, commit, PR
- Branch: `feature/NN-short-desc` (NN = task list number).
- Commits: `NN: imperative summary`.
- Open a PR into `develop`. CI (`.github/workflows/ci.yml`) runs the GUT suite and
  the doc-link lint. Green CI + satisfied Definition of Done = mergeable.

## 4. Milestone gates
A milestone (e.g. **M0 Prototype**) is met only when every task list it depends on
has its Definition of Done checked **and** the milestone's manual playtest
checklist is signed off. Tag the commit `mN`.

## Conventions
See `docs/STYLE_GUIDE.md` (code/scene rules) and `docs/TESTING.md` (what "tested"
means). Content is data-driven — most expansions are new `.tres`/JSON files, not
code (`docs/tasks/19_expansion_framework.md`).

## Setup
1. `git init && git lfs install` (first time).
2. Open the folder in Godot 4.6 (Forward+).
3. Install GUT into `addons/gut/` and enable it.
4. Run `bash tools/scripts/run_tests.sh` to confirm the harness works.

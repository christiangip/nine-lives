# NINE LIVES

> *Solo first-person stealth heist roguelite.* Pull contract after contract in a single unbroken **Streak** — banks, museums, mansions, casinos, labs. The underworld learns your name as it grows. The law always closes in eventually, and when it takes you down, everything you grabbed this run is gone. Almost everything: the *legacy* of what you pulled off carries forward, and each life you come back sharper. *(Working title — was "Soul Heist"; see [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md).)*

**Engine:** Godot 4.6 (Forward+), GDScript primary · **Platform:** PC (Windows/Linux), KB+M + gamepad · **Target:** 60 FPS mid-range.

---

## What this repository is

This is the **complete development project** for Nine Lives: a git-ready Godot 4.6 project skeleton plus an exhaustive, executable plan. Working through the task lists in order produces a **playable base game** that is built from the ground up to take expansions (new maps, gear, progression milestones, seasonal content) as *data*, not rewrites.

The plan is split across one **master task list** and 21 **sub-system task lists**. Each sub-list has ordered phases, functional requirements, the tests that confirm functionality, and a definition of done. Complete every list → ship a base game.

## Repository layout

```
nine-lives/
├── README.md                 ← you are here
├── project.godot             ← Godot 4.6 project (autoloads + input map wired)
├── icon.svg
├── LICENSE                   ← MIT for code; assets licensed separately
├── CONTRIBUTING.md           ← workflow, branch strategy, how tasks map to commits
├── CHANGELOG.md
├── .gitignore / .gitattributes  ← Godot ignore + Git LFS for binaries
├── .github/workflows/ci.yml  ← headless GUT tests + doc lint
├── docs/
│   ├── GDD.md                ← canonical design doc (v0.2, decisions locked)
│   ├── GDD_v0.1_source.md    ← original brief, preserved for provenance
│   ├── DESIGN_DECISIONS.md   ← resolutions to open questions Q1–Q7 + naming
│   ├── ARCHITECTURE.md       ← autoloads, data-driven content, save schema
│   ├── ASSET_PIPELINE.md     ← CC0-first sourcing, glTF, license hygiene
│   ├── TESTING.md            ← GUT strategy; what "tested" means here
│   ├── STYLE_GUIDE.md        ← GDScript conventions, naming, scene rules
│   └── tasks/
│       ├── 00_MASTER_TASKLIST.md   ← tracks all sub-lists + milestone gates
│       └── 01..21_*.md             ← one sub-system task list per section
├── game/                     ← the Godot project content (see game/README.md)
│   ├── autoload/             ← 9 singletons (EventBus, GameManager, …)
│   ├── systems/              ← gameplay code by domain
│   ├── scenes/               ← main/menu/hideout/mission/player/actors/ui
│   ├── resources/_defs/      ← data schema (LootDef, GearDef, EdgeDef, …)
│   ├── resources/ + data/    ← content instances (.tres / JSON) — expansion lives here
│   ├── prefabs/              ← hand-authored modular level sections + setpieces
│   ├── assets/               ← models/audio/fonts + manifest/credits/ART-TODO
│   └── tests/                ← GUT unit + integration tests
└── tools/scripts/            ← run_tests.sh, check_docs.sh
```

## Getting started

1. **Initialize the repo** (your stated goal):
   ```bash
   cd nine-lives
   git init && git lfs install
   git add . && git commit -m "Initial scaffold: Nine Lives design + project skeleton"
   ```
2. **Open in Godot 4.6** (Forward+). Point the editor at this folder; it will regenerate `.godot/` caches and validate the autoload paths in `project.godot`.
3. **Install GUT** (Godot Unit Test) into `addons/gut/` and enable the plugin — the test scaffolding under `game/tests/` expects it.
4. **Read the plan:** start at [docs/GDD.md](docs/GDD.md), then [docs/tasks/00_MASTER_TASKLIST.md](docs/tasks/00_MASTER_TASKLIST.md). Work sub-lists in the order the master list dictates.

## The game in one paragraph

You infiltrate a procedurally-assembled but hand-authored location, read guard vision cones and sound, defeat layered security (locks, safes, hacks, lasers, sensors, vaults) via minigames and gadgets, and physically carry loot to in-level Drop Points under a hard two-axis carry limit — so 100% clears mean risky multi-trip runs. **Secured loot banks immediately**, even if you're later caught. Completing a job keeps your Streak alive and escalates the board. Tripping alarms raises **Heat** for the rest of the run: tougher later jobs, but a bigger payout multiplier. Going loud flips the game into a **cover-shooter escape gauntlet** — fight to an exit, don't hold the building. When you're finally **Caught**, your run's Notoriety converts to permanent **Legacy**, which you spend in your **Hideout** on attributes, research, gear, and always-on perks. Then you start a fresh Streak, a little harder to stop.

## Design pillars

1. **Tense solo stealth** — every job is a legible puzzle of patrols, light, and sound.
2. **Push-your-luck streaks** — greed vs. caution; bank it or risk it.
3. **Death feeds growth** — getting caught is the currency of permanent power.
4. **Heists as puzzle-boxes** — layered security, multiple valid solutions.
5. **Earn the whole score** — hard carry limits make 100% an aspiration, never a default.

## Locked design decisions (vs. the original brief)

First-person camera · fuller cover-shooter when loud · grounded modern-crime tone (no supernatural skin; meta-currency is **Legacy**) · three currencies kept · strict mid-mission saves · pure shadow-stealth (no disguises) · hybrid-procedural levels. Rationale and flip-points in [docs/DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md).

## License

Original **code** is MIT (see [LICENSE](LICENSE)). Third-party **assets** are under their own licenses (CC0/CC-BY/OFL) and tracked in [game/assets/ASSET_MANIFEST.csv](game/assets/ASSET_MANIFEST.csv) and [game/assets/CREDITS.md](game/assets/CREDITS.md).

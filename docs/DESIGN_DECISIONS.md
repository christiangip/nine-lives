# Design Decisions — Open Questions Resolved

This file is the authoritative record of the seven open design questions from the
original brief (§21 of `GDD_v0.1_source.md`) and the project-owner decisions made
on them. The canonical `GDD.md` is written to match these. Where a decision was
expensive or reversible, a **flip-point** notes what would change if revisited.

_Status: locked 2026-06-28. Decisions by project owner (Chris)._

---

## Naming (resolved alongside Q3)

The original working title *Soul Heist* was tied to the "Soul XP" meta-currency.
With the supernatural skin removed (Q3 → grounded), both are renamed.

| Old (brief) | New (this project) | Notes |
|---|---|---|
| *Soul Heist* (title) | **Nine Lives** | Grounded; evokes the cat-burglar + multiple-attempts roguelite loop. Still a placeholder — rename freely. |
| Soul XP (SXP) | **Legacy (LGY)** | Permanent meta-currency. "You build your Legacy across runs." |
| Soul Altar (station) | **Legacy Board** | Where permanent always-on perks are bought. |
| Meta-perks | **Legacy Perks** | Permanent passives (counterpart to per-run Edges). |
| Streak / Notoriety / The Take / Heat / Edges | _unchanged_ | Already grounded; kept. |

Everything else in the glossary (GDD Appendix B) carries over.

---

## Q1 — Perspective → **First-person**

The core game is **first-person**. Minigames (lockpick, safe, hack, keypad,
pickpocket) still snap to a focused diegetic close-up.

**Why it matters / consequences:**
- Stealth readability is harder in FP than TP, so we **compensate with HUD/diegetic aids** (see `13_ui_hud_menus.md`): a directional detection indicator, on-world noise rings, lean/peek with `Q`/`E`, and a generous Thief Vision ("Casing") mode. These are functional requirements, not polish.
- Player rig is a capsule + head-mounted `Camera3D`; carried bulky loot is shown via viewmodel/arms and still imposes movement penalties.
- Affects `03_player_controller_camera.md`, `04_stealth_detection.md`, `10_going_loud_pursuit.md` (FP cover/lean), `13_ui_hud_menus.md`.

**Flip-point:** switching to third-person later means a camera rig swap + a body/animation pass; the detection, stealth, and combat *systems* are perspective-agnostic by design, so the data and logic survive.

## Q2 — Going-loud combat depth → **Fuller cover-shooter**

When an alarm fires, the game becomes a **cover-based shooter**, not a light escape gauntlet. Bigger scope, deliberately.

**Scope this pulls in (tracked in `09_loadout_gear_gadgets.md`, `10_going_loud_pursuit.md`, `05_ai_actors.md`):**
- Multiple weapon classes (sidearm, SMG, rifle, shotgun) with attachments/mods researched at the Workshop; ammo economy; reloads; recoil/spread.
- **Armor** as a real layer (plates/regenerating ACS-style segments) on top of Health.
- **Enemy variety:** beat cops → tactical/SWAT → specialists (shield, sniper, breacher). Escalation tiers map to the Pursuit phases.
- FP **cover** (lean/blindfire, soft cover by geometry), suppression, downs + self-revive window, and a final **Captured** state.
- Stealth is still primary and more rewarding; loud is survivable but attritional. You still **win by escaping with secured loot**, you don't hold the building forever.

**Flip-point:** the "escape gauntlet" lite model remains a valid fallback if scope bites — it's the same systems with fewer weapons/enemy types and shorter Pursuit. Keep combat data-driven so the dial is tunable.

## Q3 — Setting/tone → **Pure grounded crime**

No supernatural framing. The death/rebirth loop is a **career restart**: you get caught, you do your time / lie low, you come back. See naming table above. Art, audio, and UI lean *Heat / Hitman / PayDay* realism with zero ghost iconography.

**Consequences:** `16_art_pipeline` palette and `17_audio` tone are grounded; the Legacy Board is a corkboard/ledger of scores and connections, not an altar.

## Q4 — Currency count → **Keep three**

**Notoriety** (per-Streak run score → converts to Legacy), **The Take** (per-Streak cash for between-mission consumables/tools/Intel), **Legacy** (permanent). Richer in-run economy retained. See `14_economy_balancing.md`.

**Flip-point:** if playtests show currency overload, fold The Take into Notoriety (the economy code isolates each currency behind `RunManager`/`ProgressionManager` so this is a contained change).

## Q5 — Mid-mission save strictness → **Strict**

Missions are atomic. A **clean abort is allowed only while undetected** (bug out, keep secured loot, Streak intact). **Once an alarm is raised you are committed** — quitting the app during an active alarm **resolves as the Catch**. Strongest anti-save-scum stance; protects roguelite stakes. Implemented via `RunManager.committed` + `SaveManager` policy in `16_save_system.md`.

## Q6 — Disguise/blend system → **Cut (pure shadow-stealth)**

No disguises. Stealth is built purely on **light, shadow, sound, patrols, and positioning**. Tighter, more classic, less to balance.

**Consequences:** remove the Disguise Kit from the gear catalog; the "Inspector" special guard no longer "sees through disguises" — instead it **patrols restricted zones unpredictably and carries must-have keycards** (a roaming objective gate). Affects `09_loadout_gear_gadgets.md`, `05_ai_actors.md`, `06_heist_mechanics_obstacles.md`.

## Q7 — Level generation → **Hybrid procedural**

Hand-authored modular **section prefabs** + a **seeded rule-based assembler** + **randomized population** of loot/guards/cameras/objectives. Guarantees fair, solvable, legible stealth spaces with run-to-run variety. Full spec in `11_mission_generation.md`.

---

## Decisions made by Claude to complete the design (owner delegated)

The brief said anything unspecified is the designer's call. Notable picks (all changeable):

- **Title:** *Nine Lives* (see above).
- **Render/scale:** Forward+, 1 unit = 1 m, glTF `.glb` standard.
- **Test framework:** GUT (Godot Unit Test); CI runs it headless.
- **Code license:** MIT for original code; assets per-asset (CC0-first).
- **Build order:** follows the GDD roadmap Phases 0–4, expressed as the master task list's milestone gates M0–M5.
- **Attribute set & catalog values:** seeded with sensible defaults in `game/data/` and the relevant task lists; final numbers come from the balancing passes in `14_economy_balancing.md`.

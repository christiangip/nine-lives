# NINE LIVES — Game Design Document (v0.2)

**Working title:** *Nine Lives* (was *Soul Heist*; see `DESIGN_DECISIONS.md`)
**Genre:** Solo Stealth Heist Roguelite
**Perspective:** 3D, **first-person** (minigames snap to diegetic close-ups)
**Engine:** Godot 4.6, Forward+ (GDScript primary; C# permitted for hot paths)
**Document version:** 0.2 — open questions Q1–Q7 resolved (see `DESIGN_DECISIONS.md`)
**Status:** Pre-production design, internally complete. Implementation plan lives in `docs/tasks/`.

> This v0.2 supersedes `GDD_v0.1_source.md` (the original brief, preserved for provenance). Where the two differ, **v0.2 wins** because it reflects locked decisions: first-person, fuller cover-shooter when loud, grounded crime tone (meta-currency = **Legacy**), three currencies, strict saves, pure shadow-stealth (no disguises), hybrid-procedural levels.

---

## Table of Contents

1. High Concept · 2. Design Pillars · 3. Platform & Tech Summary · 4. Core Loop ·
5. Progression (Streak & Legacy) · 6. The Hideout · 7. Missions & Job Map ·
8. Stealth, Detection & Going Loud · 9. Heist Mechanics & Puzzles ·
10. Loot & Inventory · 11. Loadout, Gear & Gadgets · 12. Economy & Balancing ·
13. Art Direction · 14. Audio · 15. UI/UX · 16. Technical Architecture ·
17. Onboarding · 18. Live Expansion Plan · 19. Roadmap · 20. Risks ·
21. Glossary

---

## 1. High Concept

You are a master thief working alone out of a hidden Hideout. You take contract after contract in one unbroken run — a **Streak** — slipping through banks, museums, mansions, casinos and labs. The underworld remembers your name as it grows. But the law always closes in, and when it finally takes you down, everything you accumulated this run is gone.

Almost everything. The reputation and skill you banked endures as **Legacy**, and it carries into your next attempt. Each life you come back sharper, better equipped, harder to stop. Each Streak you chase a bigger score than the last.

**Elevator pitch:** *PayDay's heists distilled to a tense solo first-person stealth puzzle, wrapped in a push-your-luck roguelite where getting caught isn't a fail screen — it's the currency of permanent growth.*

**Tone:** Grounded modern-crime realism (*Heat*, *PayDay*, *Hitman*). No supernatural framing; the death/rebirth loop is a career restart. (Q3.)

## 2. Design Pillars

The five tie-breakers. If a feature serves none, cut it.

1. **Tense solo stealth.** Every job is a legible puzzle of patrols, light, and sound. The player should always understand *why* they were spotted. Readability over realism.
2. **Push-your-luck streaks.** Greed vs. caution. Bank what you have and walk, or risk it all. Every extra room raises the stakes.
3. **Death feeds growth.** Getting caught is fuel, not punishment. Every failed run becomes permanent power; you always end a Streak with something to spend.
4. **Heists as puzzle-boxes.** Locations are layered security systems with multiple valid solutions; stealth and loud are both legitimate.
5. **Earn the whole score.** Hard carry limits force prioritization and repeat trips. 100% completion is aspirational, never default.

## 3. Platform & Technical Summary

| Aspect | Decision |
|---|---|
| Engine | Godot 4.6, Forward+ |
| Language | GDScript 2.0; C# allowed for AI/pathfinding/procgen hot paths if profiling demands |
| Platform (initial) | PC (Windows/Linux), KB+M + gamepad |
| Perspective | **First-person**; diegetic close-ups for minigames (Q1) |
| Art style | Stylized low-poly, controlled palette, strong silhouettes |
| Performance | 60 FPS on mid-range hardware |
| Saves | 10 manual slots + autosave; **strict** roguelite integrity (Q5) |
| Content model | Data-driven (Godot `Resource` + JSON): updates add content without code changes |

## 4. Core Gameplay Loop

### 4.1 Macro loop (the run)

```
Hideout → pick a contract from the Job Map → play the heist
   ↑                                              │ success (stealth OR loud-escape)
   │                                   Streak continues; board refreshes & escalates
   └──────── CAUGHT / KILLED ◄──── (eventually a job goes wrong)
                   │ Notoriety banked → Legacy
                   ▼  spend Legacy on permanent upgrades → start a fresh Streak
```

A **Streak** is a chain of contracts played back-to-back. Completing a job (clean, or by escaping after going loud) keeps the Streak alive and refreshes the board with harder, richer contracts. Only being **Caught or killed** ends the Streak; its Notoriety then converts to permanent **Legacy**.

### 4.2 Micro loop (a single heist)

```
Infiltrate → Case the location → Defeat security (locks/hacks/lasers/vaults)
  → Acquire loot → Ferry to Drop Points / Escape (within carry limits)
  → Decide: extract now (bank it) OR push for more (greed)
  → Extract clean, OR get spotted → escalate → escape or be caught
```

The moment-to-moment fun: reading guard cones, solving security, and the constant "one more room?" tension created by carry limits and rising alarm risk.

## 5. Progression Systems

Two progression lines plus one supporting in-run currency.

### 5.1 The Streak (in-run line)
- **Notoriety (NP)** is the Streak's XP/score. It accrues from secured loot value and objective completion × performance bonuses (stealth, speed, no-kill, full-clear).
- Notoriety raises your **Streak Level**. Each level grants a choice of one **Edge** from a random set of 3 — temporary perks that vanish when the Streak ends (roguelite build variety).
- Notoriety is the conversion source: on Catch, `total Notoriety × Heat multiplier → Legacy`.

**Edges (temporary per-run perks)**, drawn from a large pool, e.g.: *Silent Hands* (takedowns 30% faster), *Featherweight* (bulky loot no longer slows you), *Overclocked* (+1 hack mistake tolerance), *Ghost* (detection fills 20% slower in shadow), *Mule* (+15% carry weight), *Insider* (one free intel per contract), *Adrenaline* (3s sprint burst on first spot per mission), *Fence Connections* (+10% Notoriety from secured loot). Dozens at launch, with rare ones to chase; some synergize into build identities (mule / ghost / tech).

### 5.2 Legacy (permanent line)
- **Legacy (LGY)** is the permanent meta-currency, banked from Notoriety at Streak end.
- Spent at the Hideout on: **Training** (attributes §5.5), **Workshop** research (tools/gadgets/weapon mods/abilities), **Hideout expansions** (stations & capacity), and **Legacy Perks** at the Legacy Board (always-on passives).
- Because every Streak ends with a Legacy payout, the player *always* makes permanent progress — the anti-frustration backbone.

### 5.3 The Take (in-run cash)
- **The Take** is a percentage of the cash value of loot you secure during the Streak.
- Spent **between missions in the same Streak** on consumables (lockpicks, EMPs, smoke, lures, ammo), tool rentals, and **Intel** (revealing a contract's hidden modifiers, silent-alarm locations, loot manifest).
- Resets to zero on Streak end; does **not** convert to Legacy.

### 5.4 Conversion, Catch, and Streak Heat
**On catch:** `Legacy earned = total Notoriety × Heat multiplier`.

**Streak Heat** powers push-your-luck:
- Starts low. Every alarm/going-loud raises Heat for the **remainder of the Streak**. High Heat → tighter security on later contracts (more guards, faster police, fewer entry windows, more cameras).
- High Heat also raises the **payout multiplier**. So a loud, dangerous Streak banks more Legacy per Notoriety — but is likelier to end early.
- Clean stealth keeps Heat low: safer, longer Streaks, lower multiplier. **The strategic question every run:** play clean and long for steady Legacy, or run hot for a big multiplier before you're taken?

### 5.5 Player Attributes (raised via Training)

| Attribute | Effect |
|---|---|
| Health | Survivability when loud/under fire |
| Armor | Damage mitigation (real layer for cover-shooter, §8.7) |
| Stamina | Sprint duration, climbing, dragging bodies |
| Speed | Move and sprint speed |
| Sneak | Slows visual cone fill |
| Silence | Reduces footstep/action noise radius |
| Lockpicking | Eases lock minigames; fewer snaps; bigger sweet spots |
| Hacking | Eases hacks; faster; more fault tolerance |
| Carry Weight | Max kg carried |
| Carry Volume | Max volume/slots carried |
| Strength | Carry bulky loot with less slowdown; throw bags farther |
| Pickpocketing | Steal keys/keycards; bigger timing windows |
| Perception | Casing/Thief-Vision range & duration; reveals traps & silent alarms |
| Marksmanship | Recoil/spread control when loud (cover-shooter, Q2) |

Numerous, granular attributes so Training always has meaningful sinks.

## 6. The Hideout

The safe space between missions; first sight on both **New Game** and **Continue**. Built as discrete, self-contained **stations**, each its own Godot scene, registered via a manifest entry so new stations drop in via updates with zero core rewrites.

### 6.1 Launch stations

| Station | Function | Currency |
|---|---|---|
| **The Job Map** | Diegetic mission select; pins = contracts | — |
| **Training Area** | Raise attributes (§5.5) | Legacy |
| **Workshop** | Research tools/gadgets/weapon mods/abilities | Legacy |
| **Armory / Loadout** | Equip unlocked gear within slot limits; manage consumables | — |
| **Legacy Board** | Buy permanent Legacy Perks (always-on passives) | Legacy |
| **Planning Table** | Buy Intel; review manifests, blueprints, security notes | The Take / Legacy |
| **The Stash** | Trophy room for delivered special/unique loot; some grant set bonuses | — |
| **Fence Terminal** | Convert special loot; buy/restock consumables & ammo | The Take |

### 6.2 Expandability principles
- Each station registers via a `StationDef` manifest entry (id, scene path, unlock condition, UI hooks). Adding a station = a `Resource` + a scene; no central switch edits.
- Stations are locked/unlocked by Legacy or by delivering specific loot — the Hideout itself visibly grows.
- All content stations expose (stats, research, gear, perks, intel) is data-driven, so balance passes ship as data.

## 7. Missions & The Job Map

### 7.1 The Job Map
The wall map shows ~3–5 **available contracts** at a time. Each pin: location archetype, difficulty tier, headline objective, headline reward, and (if Intel bought) revealed modifiers + loot manifest. Completing a contract refreshes the board. Baseline difficulty rises with **Streak length** and **Heat**. The player always chooses *which* contract — risk management is the meta-skill.

### 7.2 Location archetypes (launch set, expandable)
**Bank** (vaults, time-locks, teller silent alarms; cash + bonds) · **Museum** (display cases, laser grids, pressure floors; bulky art) · **Mansion** (keyed rooms, private safes, dogs; jewelry/cash) · **Casino** (cameras everywhere, cage vault, count rooms; chips + marquee score) · **Corporate/Lab** (keycards, server hacks, biometrics; data drives + prototypes) · **Mob Safehouse/Warehouse** (heavy patrols, few electronics; cash + contraband).

### 7.3 Mission anatomy
A contract = **Archetype + Layout + Objective(s) + Modifiers + Loot Table + Reward + Difficulty Tier**.

**Objective types:** *Grab* (secure N loot value) · *Mark* (steal one named high-value item) · *Crack* (defeat a specific major obstacle — vault/server) · *Retrieve & Deliver* (get an item to a guarded drop) · *Sabotage* (plant/destroy; tense exfil) · *Puzzle-room* (multi-step security defeat while undetected; highest risk/reward). Contracts can stack a headline objective with optional bonus objectives for extra Notoriety.

### 7.4 Difficulty & rewards
Difficulty Tier (1–N) scales guard count/skill, camera/laser density, lock/hack difficulty, police response speed, and advanced obstacles (biometrics, time-locks). Rewards scale across **loot value/density**, **special-loot chance**, and **Notoriety multiplier**.

### 7.5 Level generation — hybrid procedural (Q7)
- **Modular section prefabs** authored by hand (vault wing, lobby, office block, server room, loading dock), each a self-contained stealth space with connection sockets, guard-patrol anchors, loot anchors, and cover.
- A **seeded rule-based assembler** stitches prefabs into a coherent floorplan per archetype, **guaranteeing** solvable patrol routes, ≥1 viable stealth path, and reachable drop/escape points.
- **Randomized population:** loot, patrols, cameras, locks/hacks, and objectives scatter across anchors within designer rules ("the Mark spawns in a high-security wing," "≥1 alternate entry exists").
- **Handcrafted setpieces** (named vault, puzzle-room) drop in as special prefabs.
- A **seed** makes layouts reproducible for debugging and future daily contracts.

### 7.6 Approaches & extraction
Multiple entries (front, service, vents, rooftop/skylight, windows), informed by Intel. Drop Points & Escape per §10.4; the player chooses *when* to extract — the central greed decision.

## 8. Stealth, Detection & Going Loud

### 8.0 Perspective — first-person (Q1)
The base game is first-person for tension and immersion. Because FP sacrifices some spatial awareness, readability is preserved through **HUD/diegetic aids**: a directional detection indicator, on-world noise rings, lean/peek, and a generous Thief Vision mode (§8.5). Minigames snap to focused diegetic close-ups.

### 8.1 Detection inputs
A guard or camera builds detection from: **line of sight** within a vision **cone** (angle+range) · **distance** (closer fills faster) · **light level** (shadows shrink range) · **stance** (stand > crouch > prone) · **movement** (run > walk > still) · **cover** (partial reduces fill; full blocks LoS).

### 8.2 Sound
First-class channel with propagation. Footsteps scale with stance/speed/floor surface. Running, broken glass, drills, unsuppressed gunshots, and some gadgets emit loud radii drawing guards to investigate. **Silence** attribute and soft-soled gear/suppressors shrink radii. Audio cues surface as a visible **noise ring** for legibility.

### 8.3 Detection states

| State | Behavior |
|---|---|
| Unaware | Normal patrol |
| Suspicious | Heard/half-saw something; investigates last position, then resumes |
| Searching | Found evidence (body, open door, missing item); active local search, nearby guards raised |
| Alerted (local) | Confirmed spotted; local alarm; guards converge; a window before wider response |
| Pursuit | Escalates to police (§8.6) |

Suspicious/Searching are **recoverable** (break LoS, hide, wait); full detection commits the location to alert.

### 8.4 AI actors
**Patrol guards** (routes, cones, investigate, takedownable) · **Static cameras** (sweeping arcs feeding a monitoring room or delayed auto-alarm) · **Camera-room operator** (taking them out blinds cameras for a window) · **Guard dogs** (scent radius; ignore visual stealth; countered by lures/avoidance) · **Civilians/staff** (panic, can trip silent alarms; avoid or non-lethally subdue) · **Inspector / special guards** (higher tiers: patrol restricted zones unpredictably and **carry must-have keycards** — a roaming gate, since disguises are cut, Q6) · **Responders / Tactical units** (cover-shooter pursuit, §8.6/§10).

AI is intentionally simple and rule-driven (state machines + Godot navigation) for readability and performance; fairness over emergent unpredictability.

### 8.5 Stealth tools & interactions
- **Takedowns:** non-lethal (choke) and lethal (a body + blood evidence). Improved by Sneak/Silence and Edges.
- **Bodies:** raise alarm if discovered; drag and hide (containers, dark corners). Lethal may leave blood pools.
- **Radio check-ins** (PayDay-pager style): after a takedown, a guard's radio may demand a check-in; hold a prompt within a window to fake "all clear." Limited fakeable check-ins per mission before HQ escalates.
- **Casing / Thief Vision:** a toggled mode (limited duration + cooldown, scaled by Perception) highlighting guards, cones, cameras, loot, interactables, and invisible laser beams. A planning aid and a key FP-readability tool — not a free win.
- **No disguises (Q6):** stealth is pure light/shadow/sound/patrol. The Disguise Kit is removed from the catalog.

### 8.6 Going Loud & Pursuit — cover-shooter (Q2)
When an alarm fires, a **Pursuit** timeline escalates:

| Phase | Response |
|---|---|
| 0 | Calm (pre-alarm) |
| 1 | Local guards alerted; converge on last position |
| 2 | Alarm confirmed (silent/loud); response timer starts |
| 3 | First responders at exits/perimeter |
| 4 | Police force floods the location |
| 5 | Tactical/special units (shield, sniper, breacher); the noose tightens |

Going loud ends stealth multipliers and raises Heat. Unlike the brief's "lite" model, Nine Lives commits to a **fuller cover-shooter**: multiple weapon classes, attachments, an **Armor** layer, ammo economy, FP cover/lean/blindfire, suppression, and varied enemy tiers tied to the Pursuit phases. **But the goal is still to escape**, not to hold the building: enemies keep coming, you're attritioned, and you win by reaching an exit with secured loot. Calculated, sweaty escape — not an endless arena.

### 8.7 Combat, downs, and the Catch
- **Health + Armor** model (Armor is a researched/trainable layer, §5.5).
- Too much damage → **Downed**; optional self-revive window with the right gear/perk, else Down → Caught.
- **Captured** (surrounded, cuffed) ends the Streak even without dying.
- **Get-Out-of-Jail** (researchable, rare): a one-time escape attempt at the moment of capture (a short skill check).
- On Catch: Notoriety → Legacy (§5.4), return to Hideout, fresh Streak.

## 9. Heist Mechanics & Puzzles

The heart of the puzzle-box pillar. All data-driven and reusable across archetypes. (Full implementation spec: `06_heist_mechanics_obstacles.md`, `07_minigames.md`.)

### 9.1 Locks & containers
Pin-tumbler locks (lockpick minigame; picks snap on failure) · safes (dial-combination minigame; more wheels/tighter tolerance at higher tiers; **stethoscope** widens the cue; **combo clues** found in-level skip the minigame) · keys & keycards (held by NPCs — pickpocket or take down — or stashed; keycards **clonable** with a gadget) · display cases (key/lock, **hack**, **cut** with glasscutter — silent, or **smash** — instant + loud).

### 9.2 Electronic security — hacking
Targets: electronic locks, keypads, camera systems (disable or **loop the feed**), alarm panels, vault time-locks, **data loot**. Hacks **take time and require proximity** — move too far and they pause/fail; longer hack = longer exposure. **Camera loop** is quieter than disabling (no "offline" suspicion) but temporary. **Keypads** use a faster Mastermind-style deduction variant, or a found code.

### 9.3 Cameras (as obstacles)
Sweeping arcs fill detection in the monitoring room (or trip a delayed auto-alarm if unmonitored). Counter-play: avoid arcs, hack/loop, shoot (creates "offline" suspicion), cut power (§9.5), or take out the operator.

### 9.4 Detection hardware (traps)
**Laser grids/tripwires** (avoid, disable at a junction box, reveal via Thief Vision/aerosol, or EMP) · **motion sensors** (trip on fast movement; move slow or disable) · **pressure plates** (avoid/weigh down/disable) · **biometric/retinal/magnetic locks** (bring a knocked-out keyholder, spoof with a rare gadget, or find another route — gate the most lucrative content) · **guard dogs & exotic sensors** (scent/signature; gadgets or avoidance) · **silent alarms** (invisible; Intel reveals locations; otherwise reward casing).

### 9.5 Power & environment
**Fuse/power boxes** (cut power to disable cameras/locks/lights in a zone — but may trigger a backup generator timer and draw a patrol to investigate) · **light control** (shoot out/switch off lights to expand shadow) · **routes** (vents, skylights, windows, service corridors — a planning-layer puzzle).

### 9.6 Breaching (loud/semi-loud vault toolset)
**Drill** (timed, noisy, can jam and need repair, draws guards; upgradeable) · **thermite** (timed burn, very loud) · **C4** (instant breach, max alarm). A marquee **Crack** vault is multi-step: *acquire manager's keycard → hack the time-lock → drill/thermite/C4 the door → ferry contents under rising Pursuit.* Where stealth prep and loud execution meet.

### 9.7 NPC interactions
**Pickpocketing** (timing minigame behind an NPC; failing nudges suspicion) · **sedative darts / silent ranged takedowns** (researchable; limited ammo) · **intimidation** (loud only) · **distraction** (thrown coins/bottles, remote lures, ringing a phone, car alarms — pull patrols off-route).

### 9.8 Minigame frameworks
Standardized, reusable, scaled by attribute/difficulty: **Lockpick** (rotate to a sweet-spot arc; snap risk; Lockpicking widens arcs) · **Safe crack** (chain dial clicks; stethoscope widens cues) · **Hack** (node-routing/sequence under a soft timer with proximity-lock; Hacking adds tolerance; visual variants per target) · **Keypad** (Mastermind deduction) · **Pickpocket** (timing meter) · **Drill/Thermite** (a *tension manager*, not a puzzle). **Design rule:** minigames reward the relevant attribute/gear, are skippable via clues/intel where sensible, and are never the *only* solution.

## 10. Loot & Inventory

### 10.1 Two-axis carry
Constrained by two independent caps + a special tier: **Carry Weight (kg)**, **Carry Volume (slots/L)**, and **Hand Slots** for very large items (painting, gold bag, statue) that occupy your hands (limited to 1–2, impose movement/agility penalties, block vents/climbing; Strength reduces penalty and enables throwing). A heavy-small gold bar stresses Weight; a light-bulky painting stresses Volume/Hands — forcing real prioritization.

### 10.2 Loot tiers
Small (jewelry, cash, drives — best value-density, grab-and-go) · Medium (electronics, small artifacts, bonds) · Large/Bulky (paintings, gold stacks, statues, servers — slow you, often two-handed) · **Special/Unique** (named masterpieces, prototypes, blueprints — delivering them unlocks permanent content or Stash trophies/set bonuses; the bridge between heists and permanent progression).

### 10.3 Handling loot
Loot is **physically picked up** and carried. Loose loot (cash, gold) needs **bagging** first; pocketable loot (jewelry, drives) is grabbed directly. **Throwing bags** (Strength-gated) over fences/gaps/to drops is a key solo traversal skill. Carrying bulky loot makes you slower, louder, more visible — carrying the score *is* a stealth risk.

### 10.4 Drop Points, Escape, multi-trip
- **Drop Points** inside the level (a window to a stash, a parked getaway, a vent chute) hold **infinite** loot.
- **Escape/Extraction** leaves the mission successfully (objective must be met) and continues the Streak.
- **Critical rule — secured loot banks immediately.** The moment loot reaches a Drop Point or Escape, its value is locked into Notoriety **even if you're later caught**. Caught while *carrying*? You lose what's in hand, keep everything secured. Each trip is a discrete bank-or-bust decision.
- **Multi-trip loop:** hard carry caps + infinite drops mean 100% clears require multiple trips, each raising exposure and (on alarms) Heat. "Go back for one more load vs. extract clean" is the loop's beating heart.

### 10.5 100% completion as aspiration
A location is 100%'d when all loot (incl. Mark/specials) is secured — genuinely hard, often a risky multi-trip sequence. A goal to chase, not the expected single-pass outcome.

## 11. Loadout, Gear & Gadgets

Gear is **unlocked permanently** via Workshop research (Legacy) and **equipped** at the Armory within slot limits. Consumables restock with The Take or are found. Working catalog (expand via §18; **Disguise Kit removed**, Q6):

| Item | Slot | Function |
|---|---|---|
| Lockpick set | Tool | Pin-tumbler picking; consumable picks |
| Lockpick gun | Tool | Faster picking, fewer/no snaps |
| Hacking rig | Tool | Enables/speeds hacks; tiers add tolerance |
| Stethoscope | Tool | Widens safe-crack cues |
| Glasscutter | Tool | Silently open display cases |
| Keycard cloner | Tool | Clone a nearby legitimate keycard |
| Casing visor | Tool | Thief Vision |
| Drill / Thermite / C4 | Breach | Timed/instant vault breach (escalating noise) |
| EMP / Smoke / Noisemaker / Aerosol | Gadget (consumable) | Kill electronics / break LoS / lure / reveal lasers |
| Throwing coins/bottles | Gadget | Cheap point distractions |
| Suppressed pistol | Weapon | Quiet ranged takedown / loud combat |
| Sedative dart gun | Weapon | Silent non-lethal ranged drop; limited ammo |
| SMG / Rifle / Shotgun (+ attachments) | Weapon | Cover-shooter loadout when loud (Q2) |
| Armor plates | Apparel | Damage mitigation layer (Q2) |
| Body bag | Utility | Carry/hide a body more easily |
| Get-Out-of-Jail | Utility | One-time escape attempt from capture |
| Soft-soled gear | Apparel | Reduces footstep noise (Silence) |

Slot limits (a few tool/gadget/weapon slots) force pre-mission planning around the contract's known/intel'd challenges.

## 12. Economy & Balancing

| Resource | Scope | Source | Spent on | On Catch |
|---|---|---|---|---|
| **Notoriety (NP)** | Per-Streak | Secured loot + objectives × bonuses | Not spent — run score → Streak Levels/Edges | Converts to Legacy via Heat mult, resets |
| **The Take** | Per-Streak | % of secured cash | Consumables, rentals, ammo, Intel | Resets to zero |
| **Legacy (LGY)** | Permanent | Banked from Notoriety at Streak end | Training, Workshop, expansions, Legacy Perks | Persists |

**Notoriety multipliers** stack: stealth (never spotted), no-kill, speed, no-alarm, full-clear (100%), bonus objectives. **Tuning targets:** a Streak lasts several missions before a Catch; first few Legacy purchases are cheap and impactful; the Heat curve makes "run hot" a real temptation without making "play clean" pointless; every Catch pays enough Legacy to afford *something*. Exact numbers come from the balancing passes (`14_economy_balancing.md`).

## 13. Art Direction & Asset Pipeline

**Stylized low-poly**, readable materials, controlled palette, strong silhouettes — copyright-free-asset-friendly, consistent across modular levels, performant, and readability-first. **CC0-first** sourcing (Kenney, Quaternius, Poly Pizza, OpenGameArt, Poly Haven, ambientCG, Freesound, Incompetech/FMA, Google Fonts). Standards: **glTF (.glb)**, a fixed **scale grid** (1u = 1m), a **master material set + locked palette**, consistent rigs. **Never leave a gap:** if no on-style asset exists, drop in any CC0 placeholder and log it in `ART-TODO.md`. **License hygiene:** every asset → `ASSET_MANIFEST.csv`; CC-BY → `CREDITS.md`. Full pipeline in `ASSET_PIPELINE.md`.

## 14. Audio Design

**Dynamic music layers** responding to detection state (calm → tense on Suspicious/Searching → combat stinger on Alert/Pursuit → resolution on extraction) — the highest-impact stealth-audio investment. **Diegetic readability:** distinct learnable SFX for spotted-sting, takedown, alarm, drill running/jamming, hack progress/fault, lockpick tension/snap, loot bagged/secured. **3D positional audio** for guard footsteps/radios so threats are locatable by ear (doubly important in FP). Sourced/tracked per §13.

## 15. UI / UX

**Main Menu (exactly four):** New Game (slot select → tutorial → Hideout) · **Continue** (10-slot popup; **greyed out when no save exists** — bound to `SaveManager.populated_count() > 0`) · Options · Exit (confirm). **Options (all usual):** Graphics (resolution, window mode, vsync, quality, render scale, AA, shadows, FOV, gamma, motion-blur/shake toggles) · Audio (master/music/SFX/UI/ambience, subtitles) · Controls (full KB+M + gamepad remap, sensitivity, invert Y, vibration, hold/toggle for crouch/aim/sprint) · Gameplay/Accessibility (colorblind modes, UI scale, aim assist, language, reduce-flashing) · System. Persisted to a `ConfigFile`, independent of save slots.

**HUD (FP, minimal, trustable):** directional **detection indicator** (the eye) · **noise ring** · **carry readout** (Weight/Volume vs caps + "full" warning) · objective tracker + secured-vs-remaining value · Pursuit/Heat indicator · ammo/health/armor when loud · minigames as focused diegetic overlays.

**Continue / Slot popup (10 slots):** each occupied slot shows Streak length, total Legacy, playtime, last-played date, last contract; empty slots read "Empty." Occupied → load; per-slot Delete (confirm). Same grid reused by New Game (choose/overwrite) and Continue (load).

**Save model & strict integrity (Q5):** Autosave at the Hideout and after each completed mission. **No mid-mission save-scumming:** abort cleanly **only while undetected** (keep secured loot, Streak intact); once an alarm is raised you're **committed** — quitting during an active alarm resolves as the **Catch**.

## 16. Technical Architecture (Godot 4.6)

**Scenes:** Main (boots to Menu) → Menu scenes (Main/Options/Slot popup) → Hideout (sub-scene per station) → Mission (generator-assembled). **Autoloads:** `EventBus`, `Content`, `GameManager`, `InputManager`, `SaveManager`, `RunManager`, `ProgressionManager`, `MissionGenerator`, `AudioManager`, `SettingsManager` (`Content` is the content-registry hub). **Data-driven content:** everything (archetypes, prefab metadata, objectives, modifiers, loot, gear, edges, perks, attributes, enemies, intel, station manifests) defined as `Resource`/JSON so updates ship as data. **10-slot save schema:** permanent (Legacy, unlocks, attributes, station states, Stash, perks, stats) + current Streak (Notoriety, level, Edges, Heat, Take, Job Map seeds, checkpoint flag) + meta (slot summary, schema version for migration). **AI/nav/perf:** lightweight state machines over `NavigationServer`; vision cones via raycasts + angle/distance/light; sound via radius events on `EventBus`; AI ticks budgeted for 60 FPS. Full detail in `ARCHITECTURE.md`.

## 17. Onboarding & Tutorial

The first New Game runs a short guided heist teaching, in order: movement & stances, vision cones & shadow, a takedown + hiding a body, a lockpick, a hack, grabbing/bagging loot, a Drop Point, the carry-limit/multi-trip idea, and extraction. Then it deposits the player at the Hideout and explains the Streak/Legacy loop and Job Map. Later mechanics (drills, lasers, biometrics, going loud) are introduced contextually by the contracts that first feature them.

## 18. Content & Live Expansion Plan

The architecture is built to grow steadily: new archetypes & prefabs, new mechanics (obstacle/minigame variants) as reusable data+systems, new gear/Edges/Legacy-Perks/attributes, new Hideout stations (scene + manifest, gated by Legacy/special loot), and roguelite live features (daily/weekly seeded contracts + leaderboards, rotating global modifiers, seasonal cosmetic goals). See `19_expansion_framework.md` and `20_progression_milestones.md`.

## 19. Development Roadmap

- **Phase 0 — Prototype (greybox):** core stealth loop in one handcrafted level (movement, cones, sound, one takedown, 2–3 obstacles, loot with weight/volume, one Drop Point + Escape, secured-loot rule). Prove the micro-loop.
- **Phase 1 — Roguelite spine:** Streak → Catch → Legacy; Notoriety/Edges; minimal Hideout (Job Map + Training + Workshop); 10-slot saves + Main Menu + Continue logic. Prove the macro-loop.
- **Phase 2 — Vertical slice:** one polished archetype via the seeded generator; 4–6 obstacles; a vault Crack with breaching; going-loud cover-shooter/Pursuit; an art pass; dynamic audio; full Options.
- **Phase 3 — Breadth:** more archetypes/obstacles/gadgets/Edges/perks/stations, special loot & Stash, Intel/Take economy, balancing.
- **Phase 4 — Polish & live:** accessibility, performance, juice, then daily/seasonal features.

These map to milestone gates **M0–M5** in `00_MASTER_TASKLIST.md`.

## 20. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Procedural levels feel unfair for stealth | Hybrid generation from hand-tuned prefabs with guaranteed solvable paths (§7.5) |
| **Cover-shooter scope creep (Q2)** | Keep combat data-driven; ship the lite "escape gauntlet" subset first, expand weapons/enemies as data; the dial is tunable |
| FP hurts stealth readability (Q1) | HUD/diegetic aids as functional requirements: detection indicator, noise rings, Thief Vision, lean |
| Art inconsistency from mixed CC0 | Locked palette + master materials + scale grid; ART-TODO; CC0-first |
| AI complexity/performance | Simple readable state machines; budgeted ticks; low-poly headroom |
| Currency overload (3) | Clear distinct roles; fold The Take into Notoriety if testing shows confusion |
| Save-scum undermines stakes | Strict mid-mission policy (Q5) |
| Minigame fatigue | Multiple frameworks, attribute/gear payoff, clue skips, never sole-solution |

## 21. Glossary

**Streak** — a chain of contracts played until caught (per-run line). **Notoriety (NP)** — per-Streak score; drives Streak Levels/Edges; converts to Legacy on Catch. **Streak Level / Edges** — in-run leveling; Edges are temporary per-run perks. **Heat** — per-Streak escalation from alarms/loud; raises later difficulty *and* the Legacy multiplier. **The Take** — per-Streak cash for consumables/tools/Intel. **Legacy (LGY)** — permanent meta-currency (was "Soul XP"). **Catch** — being captured/killed; ends the Streak, banks Legacy. **Drop Point** — in-level infinite stash; secured loot banks immediately. **Escape/Extraction** — leaving successfully; continues the Streak. **Casing / Thief Vision** — limited-duration highlight mode. **Intel** — purchasable contract info. **Legacy Perks** — permanent passives (vs. temporary Edges).

---

*End of GDD v0.2. Implementation is planned in `docs/tasks/`.*

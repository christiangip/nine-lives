# SOUL HEIST — Game Design Document

**Working title:** *Soul Heist* (placeholder — alternatives in Appendix A)
**Genre:** Solo Stealth Heist Roguelite
**Perspective:** 3D, third-person (see §8.0 for the FP/TP decision)
**Engine:** Godot 4.6 (GDScript primary, C# optional for hot paths)
**Document version:** 0.1 — first full draft
**Status:** Pre-production design. Sections marked **[OPEN]** need a decision from the project owner (collected in §21).

---

## Table of Contents

1. High Concept
2. Design Pillars
3. Platform & Technical Summary
4. Core Gameplay Loop
5. Progression Systems (The Streak & The Soul)
6. The Hideout
7. Missions & The Job Map
8. Stealth, Detection & Going Loud
9. Heist Mechanics & Puzzles
10. Loot & Inventory
11. Loadout, Gear & Gadgets
12. Economy & Balancing
13. Art Direction & Asset Pipeline
14. Audio Design
15. UI / UX (Menus, HUD, Saves)
16. Technical Architecture (Godot 4.6)
17. Onboarding & Tutorial
18. Content & Live Expansion Plan
19. Development Roadmap
20. Risks & Mitigations
21. Open Design Questions
22. Appendices (Naming, Glossary)

---

## 1. High Concept

You are a master thief working alone out of a hidden safehouse. Driven by the need to pull off one impossible score after another, you take contract after contract in a single unbroken run — a **Streak** — slipping through banks, museums, mansions, casinos and black-site labs. The underworld remembers your name as it grows. But the law always closes in eventually, and when it finally takes you down, everything you accumulated this run is gone.

Almost everything. The *essence* of what you learned endures as **Soul** — and it carries into your next attempt. Each life you come back sharper, better equipped, harder to stop. Each Streak you chase a bigger legend than the last.

**Elevator pitch:** *PayDay's heists, distilled to a tense solo stealth puzzle, wrapped in a push-your-luck roguelite where getting caught isn't a fail screen — it's the currency of permanent growth.*

**Tone:** Grounded modern-crime aesthetic (think *Heat*, *PayDay*, *Hitman*) with a faint mythic undercurrent that justifies the death/rebirth loop — the "Soul" framing is treated as a stylized metaphor for accumulated mastery and reputation rather than literal ghosts. (Fully supernatural framing is a viable alternative — see §21, Q3.)

---

## 2. Design Pillars

These five pillars are the tie-breakers for every design decision. If a feature doesn't serve at least one, cut it.

1. **Tense solo stealth.** Every job is a legible puzzle of patrols, light, and sound. The player should always be able to understand *why* they were spotted. Readability over realism.
2. **Push-your-luck streaks.** The core emotional engine is greed vs. caution. Bank what you have and walk, or risk it all for a bigger legend. Every extra room you enter raises the stakes.
3. **Death feeds growth.** Getting caught is not punishment, it's fuel. The roguelite meta-loop turns every failed run into permanent power, so the player always ends a Streak with something to spend.
4. **Heists as puzzle-boxes.** Locations are layered security systems — locks, hacks, lasers, vaults — with multiple valid solutions and multiple approaches. Stealth and "loud" are both legitimate.
5. **Earn the whole score.** Hard carry limits force prioritization and repeat trips. 100% completion of a location is an aspirational goal, never a default.

---

## 3. Platform & Technical Summary

| Aspect | Decision |
|---|---|
| Engine | Godot 4.6, Forward+ renderer |
| Primary language | GDScript 2.0; C# permitted for AI/pathfinding/procgen if profiling demands it |
| Target platform (initial) | PC (Windows/Linux), keyboard+mouse and gamepad |
| Perspective | Third-person over-the-shoulder; first-person snap for select minigames (§8.0, §21 Q1) |
| Art style | Stylized low-poly (rationale in §13) |
| Performance target | 60 FPS on mid-range hardware |
| Save model | 10 manual save slots + autosave; roguelite integrity rules in §15.4 / §16.4 |
| Content model | Data-driven (Godot `Resource`s + JSON) so updates add content without code changes |

---

## 4. Core Gameplay Loop

### 4.1 Macro loop (the run)

```
Hideout  →  pick a contract from the Job Map  →  play the heist
   ↑                                                    │
   │                            success (stealth OR loud-escape)
   │                                                    │
   │                                          Streak continues,
   │                                          board refreshes & escalates
   │                                                    │
   └──────── CAUGHT / KILLED ←─── (eventually a job goes wrong)
                   │
        Notoriety banked → Soul XP
                   │
        Spend Soul XP on permanent upgrades, then start a fresh Streak
```

A **Streak** is a chain of contracts played back-to-back. Completing a job (whether clean or by escaping after going loud) keeps the Streak alive and refreshes the board with harder, richer contracts. Only being **caught or killed** ends the Streak. When it ends, the Notoriety you accumulated converts to permanent **Soul XP**, you return to the Hideout, spend, and begin again from a low-difficulty board.

### 4.2 Micro loop (a single heist)

```
Infiltrate → Case the location → Defeat security (locks/hacks/lasers/vaults)
   → Acquire loot → Ferry loot to Drop Points / Escape (within carry limits)
   → Decide: extract now (bank it) OR push for more (greed)
   → Extract clean, OR get spotted → escalate → escape or be caught
```

The micro-loop is where the moment-to-moment fun lives: reading guard cones, solving security, and the constant "one more room?" tension created by carry limits and rising alarm risk.

---

## 5. Progression Systems

There are **two progression lines** as specified, plus one supporting in-run currency. You can rename any of these (§21 Q3); the names below are the working set.

### 5.1 The Streak (in-run line)

The Streak is your **per-run character**. It resets every time you're caught.

- **Notoriety (NP)** is the Streak's XP/score. It accrues automatically from secured loot value and objective completion, multiplied by performance bonuses (stealth, speed, no-kill, full-clear).
- Notoriety levels up your **Streak Level** during the run. Each Streak Level grants a choice of one **Edge** from a random set of 3 (see below). Edges are temporary perks that vanish when the Streak ends — this is what makes every run a fresh build (roguelite variety).
- Notoriety is also the conversion source: when the Streak ends, `total Notoriety × Heat multiplier → Soul XP` (see §5.4).

**Edges (temporary per-run perks).** Drawn from a large pool; the player builds a different loadout of perks each Streak. Examples:
- *Silent Hands*: takedowns are 30% faster.
- *Featherweight*: bulky loot no longer slows you.
- *Overclocked*: hacking minigames gain +1 mistake tolerance.
- *Ghost*: detection meter fills 20% slower in shadow.
- *Mule*: +15% carry weight this run.
- *Insider*: each contract reveals one extra piece of intel for free.
- *Adrenaline*: first time you're spotted each mission, gain a 3s sprint burst.
- *Fence Connections*: secured loot grants +10% Notoriety.

Edges should number in the dozens at launch (§18) and include rare/powerful ones to chase. Some Edges synergize, encouraging build identities (a "loot mule" run vs. a "ghost" run vs. a "tech" run).

### 5.2 The Soul (permanent line)

The Soul is your **persistent account**, untouched by being caught.

- **Soul XP (SXP)** is the permanent meta-currency. It's banked from Notoriety at the end of each Streak.
- Soul XP is spent at the Hideout (§6) on:
  - **Stat points** (Training) — raise the attributes in §5.5.
  - **Research/unlocks** (Workshop) — new tools, gadgets, weapon mods, abilities.
  - **Hideout expansions** — new stations and capacity upgrades.
  - **Meta-perks** (Soul Altar) — always-on permanent passives (the permanent counterpart to Edges).

Because every Streak ends with a Soul XP payout, the player *always* makes permanent progress, even on a short bad run. This is the anti-frustration backbone of the roguelite.

### 5.3 Supporting currency — The Take (in-run cash)

A small, optional-but-recommended third resource that gives the heist economy texture.

- **The Take** is a percentage of the cash value of loot you secure during the Streak.
- It is spent **between missions within the same Streak** on consumables (extra lockpicks, EMP charges, smoke, lures), tool rentals, and **Intel** (revealing a contract's hidden modifiers, silent-alarm locations, and loot manifest).
- The Take resets to zero when the Streak ends. It does **not** convert to Soul XP.

This creates an in-run economy decision distinct from the permanent one: how much of your cut to reinvest in tools for the next job vs. how risky to play. (If playtesting shows three currencies is one too many, fold Take into Notoriety — see §21 Q4.)

### 5.4 Conversion, Catch, and Streak Heat

**Conversion on catch:** `Soul XP earned = total Notoriety this Streak × Heat multiplier`.

**Streak Heat** ties the run together mechanically and powers the push-your-luck loop:
- Heat starts low at the beginning of a Streak.
- Every time you trip an alarm or go loud, Heat rises for the **remainder of the Streak**. High Heat means subsequent contracts spawn with tighter security: more guards, faster police response, fewer entry windows, more cameras.
- High Heat also raises the **Heat multiplier** on your eventual Soul XP payout. So a loud, dangerous Streak banks more Soul per Notoriety — but is far likelier to end early.
- Clean stealth keeps Heat low: safer, longer Streaks, but a lower multiplier. Greed and risk are explicitly rewarded with permanent payout; caution is rewarded with survivability and longer runs.

This means the strategic question every run is: *do I play clean and long for steady Soul, or run hot and risky for a big multiplier before I'm inevitably taken?*

### 5.5 Player Attributes (raised via Training, §6)

| Attribute | Effect |
|---|---|
| Health | Survivability when loud/under fire |
| Armor | Damage mitigation (optional layer, §8.7) |
| Stamina | Sprint duration, climbing, dragging bodies |
| Speed | Move and sprint speed |
| Sneak | Reduces how fast vision cones fill you (visual stealth) |
| Silence | Reduces footstep/action noise radius (audio stealth) |
| Lockpicking | Eases lock minigames; fewer broken picks; larger sweet spots |
| Hacking | Eases hack minigames; faster; more fault tolerance |
| Carry Weight | Max kilograms you can carry |
| Carry Volume | Max volume/slots you can carry |
| Strength | Carry bulky loot with less slowdown; throw loot bags farther |
| Pickpocketing | Steal keys/keycards from NPCs; bigger timing windows |
| Perception | Casing/"thief vision" range & duration; reveals traps and silent alarms |

Attributes are intentionally numerous and granular so Training always has meaningful sinks and so different players can specialize.

---

## 6. The Hideout

The Hideout is the safe space between missions. It is the player's first sight on both **New Game** and **Continue**. It is built as a set of discrete, self-contained **stations**, each its own Godot scene, so new stations can be dropped in via updates with zero core rewrites (a core design constraint per the brief).

### 6.1 Launch stations

| Station | Function | Currency |
|---|---|---|
| **The Job Map** (wall map) | Diegetic mission select. Pins = available contracts. Selecting a pin opens the contract briefing. | — |
| **Training Area** | Raise attributes (§5.5). | Soul XP |
| **Workshop** | Research/unlock tools, gadgets, weapon mods, abilities (tech tree). | Soul XP |
| **Armory / Loadout** | Equip unlocked gear within slot limits; manage consumable loadout. | — |
| **Soul Altar** | Spend Soul XP on permanent meta-perks (always-on passives). Thematic anchor for the rebirth loop. | Soul XP |
| **Planning Table** | Buy Intel on contracts; review manifests, blueprints, security notes. | The Take / Soul XP |
| **The Stash** | Trophy room: displays special/unique loot you've successfully delivered. Some grant set bonuses. | — |
| **Fence Terminal** | Convert special loot, buy/restock consumables. | The Take |

### 6.2 Expandability principles (for live updates)

- Each station registers itself with the Hideout via a manifest entry (id, scene path, unlock condition, UI hooks). Adding a station = adding a `Resource` + a scene, no edits to a central switch statement.
- Stations are **locked/unlocked** by Soul XP or by delivering specific loot, giving the Hideout itself a progression arc (the safehouse visibly grows).
- All content the stations expose (stats, research nodes, gear, perks, intel types) is data-driven (§16.2), so balance passes and new content ship as data.

---

## 7. Missions & The Job Map

### 7.1 The Job Map (mission board)

The wall map in the Hideout is the mission board. At any time it shows a small set of **available contracts** (target ~3–5). Each is a pin with: location archetype, difficulty tier, headline objective, headline reward, and (if Intel is purchased) revealed modifiers and a loot manifest.

- Completing a contract refreshes the board.
- Baseline difficulty rises with **Streak length** and **Streak Heat** (§5.4), so the board naturally escalates over a run.
- The player always chooses *which* contract to take — risk management is part of the meta-skill. A high-tier contract early in a Streak is a gamble; a low-tier one late is "safe Notoriety."

### 7.2 Location archetypes

Each archetype defines a security flavor, loot profile, and aesthetic. Launch set (expandable):
- **Bank** — vaults, time-locks, teller silent alarms; cash + bearer bonds.
- **Museum** — display cases, laser grids, pressure floors; art + antiquities (often bulky).
- **Mansion** — keyed rooms, private safes, guard dogs; jewelry, cash, collectibles.
- **Casino** — cameras everywhere, cage vault, count rooms; chips + cash + a marquee score.
- **Corporate / Lab** — keycards, server hacks (data loot), biometric locks; data drives + prototypes.
- **Mob Safehouse / Warehouse** — heavy patrols, fewer electronics, brute targets; cash + contraband.

### 7.3 Mission anatomy

A generated contract = **Archetype + Layout + Objective(s) + Modifiers + Loot Table + Reward + Difficulty Tier**.

**Objective types:**
- *Grab* — secure N units of loot value (the simple "open loot, take it" job).
- *Mark* — steal one specific high-value target item (e.g., a named painting, a prototype).
- *Crack* — defeat a specific major obstacle (a vault, a server) to reach its contents.
- *Retrieve & Deliver* — get a specific item to a specific drop (often guarded/awkward).
- *Sabotage* — plant/destroy something (adds a tense exfil while "carrying heat").
- *Puzzle-room* — a designed set-piece requiring multi-step security defeat while staying undetected (the "solve this puzzle while not getting caught" job). Highest reward, highest difficulty.

A contract can stack a headline objective with optional bonus objectives ("also empty the manager's safe") for extra Notoriety.

### 7.4 Difficulty & rewards scaling

Difficulty Tier (1–N) parameterizes: guard count & skill, camera/laser density, lock/hack difficulty, police response speed, and the presence of advanced obstacles (biometrics, time-locks). Rewards scale with tier across three axes: **loot value/density**, **special loot chance**, and **Notoriety multiplier**. Easy jobs are quick clean Notoriety; hard jobs are big scores that can also end your run.

### 7.5 Level generation approach

Hybrid procedural, tuned for stealth readability (pure random generation tends to produce illegible, unfair stealth spaces).

- **Modular room/section prefabs** authored by hand (a "vault wing," a "lobby," an "office block," a "server room," a "loading dock"). Each prefab is a self-contained, hand-tuned stealth space with marked connection sockets, guard-patrol anchor points, loot anchor points, and cover.
- A **rule-based assembler** stitches prefabs into a coherent floorplan per archetype, guaranteeing solvable patrol routes, at least one viable stealth path, and reachable drop/escape points.
- **Randomized population**: loot, guard patrols, cameras, locks/hacks, and objective placement are scattered across anchor points within designer-set rules (e.g., "the Mark spawns in a high-security wing," "at least one alternate entry exists").
- **Handcrafted set-pieces** for marquee moments (a named vault, a puzzle-room) are dropped in as special prefabs.
- A **seed** drives generation so layouts are reproducible for debugging and (optionally) for "daily contract" features later (§18).

This keeps generated levels feeling fair and authored while still providing run-to-run variety.

### 7.6 Approaches & extraction

- **Multiple entries**: front, service/loading, vents, rooftop/skylight, windows. Approach choice is part of planning and is informed by Intel.
- **Drop Points & Escape** are detailed in §10.4. The player chooses *when* to extract — the central greed decision.

---

## 8. Stealth, Detection & Going Loud

### 8.0 Perspective decision **[OPEN — §21 Q1]**

**Default: third-person over-the-shoulder.** Rationale: solo stealth benefits enormously from spatial awareness (seeing your character relative to guard cones, seeing carried loot, peeking around cover), and TP is generally more readable and forgiving than FP for cover-based sneaking. **First-person** is the alternative (more tension/immersion, closer to PayDay). The minigames (lockpick, hack, drill) snap to a focused diegetic close-up regardless of base perspective, so they work either way. This is flagged as a top open question because it touches animation, camera, and level-scale work.

### 8.1 Detection inputs

A guard or camera builds detection on the player based on:
- **Line of sight** within a vision **cone** (angle + range).
- **Distance** — closer fills faster.
- **Light level** — shadows shrink effective detection range; the player can darken areas (§9.5).
- **Stance** — standing > crouched > prone for visibility; lower stances are slower.
- **Movement** — running > walking > still; running is loud and fills cones faster.
- **Cover** — partial cover reduces fill; full cover blocks LoS.

### 8.2 Sound

Sound is a first-class detection channel with propagation:
- Footsteps scale with stance, speed, and floor surface (carpet vs. tile vs. metal grating).
- Running, broken glass, drills, unsuppressed gunshots, and some gadgets emit loud radii that draw nearby guards to investigate the source.
- The **Silence** attribute and gear (soft-soled gear, suppressors) shrink these radii.
- Audio cues are surfaced to the player as a visible **noise ring** on detection so the channel is legible (Pillar 1).

### 8.3 Detection states (per guard / for the location)

| State | Behavior |
|---|---|
| **Unaware** | Normal patrol. |
| **Suspicious** | Heard/half-saw something; investigates the last known position, then resumes. |
| **Searching** | Found evidence (a body, an open door, a missing item); active local search, raised alert across nearby guards. |
| **Alerted (local)** | Player confirmed spotted; local alarm — guards converge; cameras feed positions; a window opens before the wider response. |
| **Pursuit** | Alarm escalates to police (§8.6). |

Partial detection (Suspicious/Searching) is recoverable — break LoS, hide, wait it out — which is what makes tense recoveries possible. Full detection commits the location to alert.

### 8.4 AI actors

- **Patrol guards** — fixed/wandering routes, vision cones, investigate, can be taken down.
- **Static cameras** — sweeping arcs feeding a monitoring room or a delayed auto-alarm. Counter-play in §9.3.
- **Camera-room operator** — a guard watching feeds; taking them out blinds cameras temporarily.
- **Guard dogs** — scent-based: detect by a scent radius regardless of LoS or shadow; ignore visual stealth. Countered by lures/avoidance, not by hiding in dark.
- **Civilians / staff** — panic if they see you; in stealth, a panicking civ can trip a silent alarm or flee to raise one. Avoid, or non-lethally subdue before they see; in loud, they can be intimidated.
- **Roaming "inspector" / special guards** (higher tiers) — see through disguises in restricted zones, or carry must-have keycards.

AI is intentionally simple and rule-driven (state machines + Godot navigation) for readability and performance; "fairness" is prioritized over emergent unpredictability.

### 8.5 Stealth tools & interactions

- **Takedowns**: non-lethal (choke/knockout) and lethal (quieter narratively but produces a body + blood evidence). Improved by Sneak/Silence and Edges.
- **Bodies**: unconscious/dead bodies raise alarm if discovered. Drag and hide them (containers, dark corners). Lethal kills may leave blood pools as evidence.
- **Radio check-ins** (adapted from PayDay's pagers): after a takedown, the guard's radio may demand a check-in; the player holds a prompt / passes a quick input within a window to fake an "all clear." There's a limited number of fakeable check-ins per mission before HQ escalates — so silent takedowns aren't free.
- **Disguises / blending [light system]**: wearing a staff/guard uniform grants access to some restricted zones and slows suspicion — but running, loitering in high-security areas, carrying loot openly, or being seen by an "inspector" breaks it. Included as one tool among many rather than the central mechanic (solo-friendliness favors classic shadow stealth). **[Can be cut — §21 Q2.]**
- **Casing / Thief Vision**: a toggled mode (limited duration, cooldown; scaled by Perception) that highlights guards, cones, cameras, loot, interactables, and otherwise-invisible laser beams. A readability and planning aid, not a free win.

### 8.6 Going Loud & Pursuit (police escalation) **[scope decision — §21 Q2]**

**Default model: "escape gauntlet," not power fantasy.** Stealth is primary; going loud is a viable but risky path. When an alarm fires, a **Pursuit** timeline escalates:

| Phase | Response |
|---|---|
| 0 | Calm (pre-alarm). |
| 1 | Local guards alerted; converge on last position. |
| 2 | Alarm confirmed (silent or loud); a response timer starts. |
| 3 | First responders arrive at exits/perimeter. |
| 4 | Police force floods the location. |
| 5 | Tactical/special units; the noose tightens. |

Going loud ends your stealth multipliers and raises Streak Heat, but lets you brute-force objectives. You **win by escaping** to an exit with your secured loot; you **lose if downed or captured**. The player has *limited but real* combat capability (a suppressed sidearm, takedowns, throwables, a researchable primary weapon) — enough to fight through a tight spot, not enough to hold a building forever. The intended feel: going loud is a calculated, sweaty escape, not a shooting gallery. (Alternative: full PayDay-style cover-shooter with weapon/armor depth — bigger scope, §21 Q2.)

### 8.7 Combat, downs, and the Catch

- **Health (+ optional Armor)** model, kept light per §8.6.
- Taking too much damage in loud → **Downed**. Optionally a brief self-revive window if you have the relevant gear/perk (a roguelite "second wind"); otherwise Down → Caught.
- **Captured** state: surrounded with no escape (e.g., cuffed in custody) ends the Streak even without dying.
- **Get-Out-of-Jail** (researchable consumable/perk): a one-time escape attempt from the moment of capture (a short QTE/skill check) — the roguelite "extra life," rare and earned.
- When the Catch resolves: Notoriety → Soul XP (§5.4), return to Hideout, fresh Streak.

---

## 9. Heist Mechanics & Puzzles

This is the heart of the "puzzle-box" pillar. The brief asked for as many mechanics as possible, defined — including counter-play, tools, and skill interactions. They're grouped by category. Treat each as data-driven and reusable across location archetypes.

### 9.1 Locks & Containers

- **Pin-tumbler locks (doors, drawers, simple chests).** Lockpick minigame (design in §9.8). Lockpicks are consumable and can snap on failure (mitigated by Lockpicking attribute / better picks / the *lockpick gun* gadget for speed).
- **Safes (dial combination).** A "crack the safe" minigame: slowly rotate the dial, feel/hear for tumbler clicks at the correct numbers (audio + subtle haptic/visual cue), enter the combination. Harder safes have more wheels and tighter tolerances. A **stethoscope** upgrade widens the cue window.
- **Combination clues.** Some safes' combos are written somewhere in the level (a note in a desk, behind a painting, in a logbook). Finding the clue **skips or trivializes** the minigame — rewarding exploration over rote minigame play.
- **Keys & keycards.** Some doors/containers require a specific physical key or keycard. Keys are held by specific NPCs (pickpocket via §9.7, or take them down) or stashed in offices/safes. Keycards can be **cloned** with a gadget if you can briefly reach a legitimate one.
- **Display cases (glass).** Open via the case's key/lock, **hack** the case's electronic lock, **cut** the glass (glasscutter gadget — slow, silent, no alarm), or **smash** it (instant, very loud, triggers alarm). Classic risk/reward on a per-case basis.

### 9.2 Electronic Security — Hacking

- **Hacking targets:** electronic door locks, keypads, camera systems (disable or **loop the feed**), alarm panels, vault time-locks, and **data loot** (downloading files as an objective).
- **Hacking minigame** (design in §9.8) plus a key tension property: **hacks take time and require proximity**. Move too far and the hack pauses or fails; the longer the hack, the longer you're exposed. The **Hacking** attribute and better hardware speed hacks and add fault tolerance.
- **Camera loop**: rather than disabling a camera (which reads as suspicious when found offline), you can loop its feed so the operator sees nothing wrong — quieter but takes a hack and is temporary.
- **Keypads**: a faster code-breaking variant (Mastermind-style deduction) when a full hack is overkill; or enter a code found as a clue (like safe combos).

### 9.3 Cameras (as obstacles)

CCTV cameras sweep in arcs. Being in a camera's view fills detection in the monitoring room (or trips a delayed auto-alarm if unmonitored). Counter-play: avoid the arcs, **hack/loop** the feed, **shoot** the camera (creates a "camera offline" suspicion when noticed), **cut power** to the camera circuit (§9.5), or take out the **camera-room operator** to blind all feeds for a window.

### 9.4 Detection Hardware (traps)

- **Laser grids / tripwire beams.** Cover loot, doorways, or whole corridors. Counter-play: physically avoid (crouch under / step over / weave through), disable at a **junction box** (hack or cut), reveal otherwise-invisible beams via Thief Vision or an **aerosol spray**, or kill them with an **EMP** (temporary). High-security rooms layer lasers densely.
- **Motion sensors.** Trip if you move **fast** through their volume; you can move slowly through them, or disable/avoid them. Punishes panicked sprinting.
- **Pressure plates / floor sensors.** In high-security vaults; avoid stepping on them (visible with Thief Vision/spray), weigh them down, or disable.
- **Biometric / retinal / magnetic locks (advanced, high tiers).** Require the legitimate person's input. Counter-play: bring a knocked-out keyholder to the scanner (drag them), spoof with a specialized gadget (rare/expensive), or find an alternate route. These gate the most lucrative content.
- **Guard dogs & exotic sensors** (heartbeat/thermal at top tiers): scent or signature-based; defeated by gadgets (thermal-dampening) or avoidance, not by hiding in shadow.
- **Silent alarms.** Some interactions risk an *invisible* silent alarm (a teller's foot pedal, a tampered sensor) that summons police without on-screen warning. **Intel** (purchased at the Planning Table) reveals their locations; without Intel, they add genuine uncertainty and reward casing.

### 9.5 Power & Environment

- **Fuse/power boxes.** Cutting power disables cameras, electronic locks, and lights in a zone — but may trigger a **backup generator** (timer until power returns) and **alerts guards to investigate the outage**. A powerful, double-edged tool: great for a quick window, dangerous if it draws a patrol.
- **Light control.** Shoot out / switch off lights to expand shadow and shrink detection ranges (creates the "dark room" stealth space).
- **Routes.** Vents (crawl, slow, limited), skylights (rappel in), windows (force open = noise), service corridors. Route choice is a planning-layer puzzle informed by Intel and approach.

### 9.6 Breaching (the loud/semi-loud toolset for vaults)

Used for major obstacles (vault doors, reinforced rooms), usually when stealthy options are exhausted or for speed:
- **Drill.** Place on a vault door; runs on a timer making continuous noise; can **jam** and require a repair interaction; draws guards. Upgradeable (faster, jam-resistant). The classic "defend the drill" tension, scaled for solo.
- **Thermite / thermal charge.** Pour/place; burns down over a timer; very loud and visible — commits you.
- **C4 / breaching charge.** Instant breach but maximum alarm. The "we're going loud, now" option.
- **Vault flow** (a marquee Crack objective) is typically multi-step: e.g., *acquire the manager's keycard → hack the time-lock to start the timer → drill/thermite/C4 the door → grab and ferry the contents under rising Pursuit.* This is where stealth prep and loud execution meet.

### 9.7 NPC interactions

- **Pickpocketing.** Sneak directly behind an NPC and pass a timing minigame to lift a key/keycard/cash without a takedown. Improved by the Pickpocketing attribute (wider window). Failing nudges the NPC suspicious.
- **Sedative darts / silent ranged takedowns** (researchable): drop a guard from range without melee exposure; limited ammo.
- **Intimidation** (loud only): force civilians/guards to comply, buying seconds.
- **Distraction & manipulation.** Throwable noisemakers (coins, bottles), remote **lures/noisemaker gadgets**, ringing a phone, setting off a car alarm — pull patrols off-route to open a path. The bedrock of proactive stealth.

### 9.8 Minigame designs (summaries)

The project should standardize a small set of minigame frameworks, each reusable and scaled by attribute/difficulty so they don't get stale:

- **Lockpick (pin-tumbler):** rotate to find a "sweet spot" arc; tension within the arc opens the pin; missing risks a pick snap. Higher difficulty = narrower/multiple sweet spots. Lockpicking attribute widens arcs and reduces snap chance. (Familiar to most players; low cognitive load — good for frequent use.)
- **Safe crack (dial):** rotate to feel/hear clicks at correct numbers; chain the combination. More wheels + tighter tolerance at higher tiers; stethoscope upgrade widens cues.
- **Hack (node routing / signal):** a short connect-the-path or sequence-routing puzzle under a soft timer, with proximity-lock and mistake tolerance from the Hacking attribute/hardware. Distinct visual variants per target type (door vs. camera vs. server) to keep it fresh.
- **Keypad (deduction):** Mastermind-style code deduction for a quick electronic lock.
- **Pickpocket (timing):** a moving meter; stop it in the safe zone; window scales with Pickpocketing.
- **Drill/Thermite (maintenance):** not a puzzle but a *tension manager* — watch the timer, respond to jams, manage the noise it generates.

Design rule: minigames should reward the relevant attribute/gear (so Soul XP investment is felt), should be skippable via clues/intel where it makes sense (so they're not mandatory busywork), and should never be the *only* solution to an obstacle.

---

## 10. Loot & Inventory

### 10.1 The two-axis carry system

Carrying is constrained by **two independent caps** plus a small special tier:
- **Carry Weight (kg)** — total mass you can carry (the Carry Weight attribute).
- **Carry Volume (slots/L)** — total bulk you can carry (the Carry Volume attribute).
- **Hand Slots** — very large items (a painting, a heavy gold bag, a statue) occupy your hands directly, are limited (e.g., 1–2), and impose movement/agility penalties (slower, can't climb, can't fit through vents). Strength reduces the penalty and lets you throw bags.

A heavy-but-small item (gold bar) stresses Weight; a light-but-bulky item (a large painting) stresses Volume/Hands. This forces real prioritization: you can't take everything in one trip.

### 10.2 Loot tiers (examples)

| Tier | Examples | Weight | Volume | Notes |
|---|---|---|---|---|
| Small | jewelry, cash bundles, data drives, watches | Low | Low | Best value-density; grab-and-go |
| Medium | electronics, small artifacts, bearer bonds | Med | Med | Balanced |
| Large / Bulky | paintings, gold stacks, statues, server units | High | High / Hands | Slows you; often two-handed; the "do I really want this?" loot |
| Special / Unique | named masterpieces, prototypes, blueprints | Varies | Varies | Delivering them unlocks permanent content or Stash trophies/set bonuses |

Loot value scales with tier and rarity. **Special loot** is the reason to chase specific Mark contracts and the bridge between heists and permanent progression (e.g., a stolen blueprint permanently unlocks a gadget; a masterpiece becomes a Stash trophy with a passive bonus).

### 10.3 Handling loot

- Loot is **physically picked up** and carried (per the brief). Loose loot may need **bagging** first (cash, gold) before it can be ferried; pre-bagged or pocketable loot (jewelry, drives) is grabbed directly.
- **Throwing loot bags** (Strength-gated): toss a bag over a fence, across a gap, or to a drop point — a key solo traversal/efficiency skill.
- Carrying bulky loot makes you slower, louder, and more visible — carrying the score *is* a stealth risk, not just a logistics step.

### 10.4 Drop Points, Escape, and the multi-trip loop

- **Drop Points** exist *inside* the level: a window you can toss bags through to a stash, a getaway vehicle you parked, a vent chute. They hold **infinite** loot (per the brief).
- **Escape/Extraction Point**: leaving the mission. You may extract once you've met the objective (and as much extra loot as you chose to grab). Extracting ends the mission successfully and continues the Streak.
- **Critical rule — secured loot is locked in immediately.** The moment loot reaches a Drop Point or the Escape, its value is banked into your Notoriety **even if you're later caught on a subsequent trip**. So partial success is always rewarded, and each trip is a discrete bank-or-bust decision. If you're caught while *carrying* loot, you lose what's in hand, but keep everything you already secured.
- **The multi-trip loop:** because carry caps are hard and drop points are infinite, clearing 100% of a location's loot requires **multiple trips** between the loot and a drop point — each trip raising exposure and (if alarms trip) Heat. The tension of "go back for one more load vs. extract clean" is the loop's beating heart and directly serves Pillars 2 and 5.

### 10.5 100% completion as aspiration

A location is "100%'d" when all loot (including the Mark/specials) has been secured. With hard carry limits this is genuinely hard and often spans a risky sequence of trips. This is a *goal to chase*, not the expected outcome of a single clean pass — exactly as specified.

---

## 11. Loadout, Gear & Gadgets

Gear is **unlocked permanently** via Workshop research (Soul XP) and **equipped** at the Armory within slot limits. Consumables are restocked between missions with The Take or found as loot. A working catalog (expand via §18):

| Item | Slot | Function |
|---|---|---|
| Lockpick set | Tool | Pin-tumbler lockpicking; consumable picks |
| Lockpick gun | Tool | Faster lockpicking, fewer/no snaps; pricier |
| Hacking rig | Tool | Enables/speeds hacks; tiers add fault tolerance |
| Stethoscope | Tool | Widens safe-crack cues |
| Glasscutter | Tool | Silently open display cases |
| Keycard cloner | Tool | Clone a nearby legitimate keycard |
| Casing visor | Tool | Thief Vision (highlights threats/loot/lasers) |
| Drill | Breach | Timed vault breach; jam management |
| Thermite charge | Breach | Timed burn-through; loud |
| C4 | Breach | Instant breach; max alarm |
| EMP charge | Gadget (consumable) | Temporarily kills electronics in a radius |
| Smoke | Gadget (consumable) | Break LoS / cover an escape |
| Noisemaker / lure | Gadget (consumable) | Draw guards off-route |
| Aerosol spray | Gadget (consumable) | Reveal invisible laser beams |
| Throwing coins/bottles | Gadget | Cheap point distractions |
| Suppressed pistol | Weapon | Quiet ranged takedown / loud combat |
| Sedative dart gun | Weapon | Silent non-lethal ranged drop; limited ammo |
| Primary weapon | Weapon | Loud combat power (researchable; raises the stakes of going loud) |
| Body bag | Utility | Carry/hide a body more easily |
| Get-Out-of-Jail | Utility | One-time escape attempt from capture |
| Soft-soled gear | Apparel | Reduces footstep noise (Silence) |
| Disguise kit | Apparel | Blend in restricted zones (light system, §8.5) |

Loadout slot limits (a few tool/gadget/weapon slots) force pre-mission planning around the contract's known/intel'd challenges — another decision layer.

---

## 12. Economy & Balancing

This section is directional; exact numbers come from playtesting.

### 12.1 The three resources, summarized

| Resource | Scope | Source | Spent on | On Catch |
|---|---|---|---|---|
| **Notoriety (NP)** | Per-Streak | Secured loot value + objectives × performance bonuses | (Not spent — it's the run score; drives Streak Levels → Edges) | Converts to Soul XP via Heat multiplier, then resets |
| **The Take** | Per-Streak | % of secured cash value | Consumables, tool rentals, Intel (between missions, same Streak) | Resets to zero |
| **Soul XP (SXP)** | Permanent | Banked from Notoriety at Streak end | Training, Workshop research, Hideout expansions, Soul Altar meta-perks | Persists (gained) |

### 12.2 Multipliers (Notoriety)

Performance bonuses stack into the Notoriety a mission grants: stealth (never spotted), no-kill, speed, no-alarm, full-clear (100% loot), and optional-objective completion. These reward mastery and give skilled players bigger Souls — *and* feed the push-your-luck tension, since chasing full-clear means more trips and more risk.

### 12.3 Tuning targets (anti-frustration vs. tension)

- A Streak should typically last **several missions** before a Catch — long enough to feel like a run, short enough that Catches stay meaningful and the meta-loop turns over.
- The **first few Soul XP purchases** should be impactful and cheap, so early runs visibly improve the player.
- The Heat multiplier curve should make "run hot" a *real* temptation (meaningfully more Soul) without making "play clean" feel pointless (clean runs last longer, so steady accumulation competes).
- Every Catch must pay out enough Soul XP to afford *something*, so no run ends with zero progress.

### 12.4 Difficulty pacing within a Streak

Because the board escalates with Streak length and Heat, the player self-selects their risk curve. Designers tune the escalation slope so that a Streak's "natural" death point lands in the target range for an average-skill player while leaving headroom for experts to push far.

---

## 13. Art Direction & Asset Pipeline

### 13.1 Style choice: stylized low-poly

Recommended look: **stylized low-poly with simple, readable materials** (flat/toon or lightweight PBR, a controlled palette, strong silhouette reads). Rationale:
- Abundant **copyright-free** assets exist in this style, making "fetch art online, keep it consistent" realistic (per the brief).
- Easy to keep visually consistent across procedurally assembled, modular levels.
- Performant (supports the 60 FPS target and dense interactable scenes).
- Readability-friendly — silhouettes and color do the communicating, serving Pillar 1.

### 13.2 Sourcing (copyright-free / CC0-first)

Prefer **CC0** to minimize obligations; use CC-BY where needed with proper attribution. Primary sources:
- **Kenney.nl** (CC0) — characters, environments, props, UI, audio. The backbone for a consistent low-poly look.
- **Quaternius** (CC0) — low-poly characters/props/environment packs.
- **Poly Pizza** (CC0/CC-BY) — large 3D model library.
- **OpenGameArt** (filter to CC0) — fills gaps.
- **Sketchfab** (filter Downloadable + CC0/CC-BY) — specific props/set-pieces.
- **Poly Haven / ambientCG** (CC0) — textures, materials, HDRIs.
- **Freesound** (CC0/CC-BY) and **Kenney audio** — SFX.
- **Free Music Archive / Kevin MacLeod (Incompetech)** — CC music.
- **Google Fonts** (open licenses) — UI type.

### 13.3 Consistency standards

- Standardize on **glTF (.glb)** for all models (Godot 4 native import).
- A fixed **scale grid** (1 unit = 1 m; modular pieces snap to a consistent grid for clean assembly).
- A **master material set** and locked palette so mixed-source assets read as one world (retexture/recolor to fit where needed).
- Consistent character rig/animation conventions so different-sourced characters share an animation set.

### 13.4 The "never leave a gap" rule (per the brief)

If no asset exists that matches the chosen style for a given need, use **any** CC0 placeholder so nothing is ever missing — and log it. Maintain an **ART-TODO registry** (a simple data file) listing every placeholder/off-style asset for later replacement. Nothing ships blank.

### 13.5 License hygiene (non-negotiable for shippability)

- Maintain an **asset manifest**: every asset → source URL → license → author → where used.
- Maintain a **CREDITS/attribution file** for all CC-BY assets.
- Prefer CC0 wherever possible to keep obligations minimal. This is a real legal requirement for distribution, not optional bookkeeping.

> Note: This document specifies the *pipeline and standards*. Actually fetching/curating specific asset packs is a separate task — happy to do a sourcing pass and scaffold the import structure when you want to start the build.

---

## 14. Audio Design

- **Dynamic music layers** that respond to the detection state: calm exploration → tense layer on Suspicious/Searching → combat stinger on Alert/Pursuit → resolution on extraction. This is the single highest-impact audio investment for a stealth game.
- **Diegetic readability**: distinct, learnable SFX for spotted-sting, takedown, alarm, drill running/jamming, hack progress/fault, lockpick tension/snap, loot bagged/secured.
- **3D positional audio** for guard footsteps/radios so the player can locate threats by ear.
- Sources per §13.2 (Freesound CC0, Kenney audio, FMA/Incompetech music), tracked in the same manifest/credits system.

---

## 15. UI / UX

### 15.1 Main Menu

Four options exactly as specified:
- **New Game** — opens slot selection (pick an empty slot, or confirm-overwrite an occupied one), then starts a fresh save and drops into the tutorial → Hideout.
- **Continue** — opens the 10-slot save popup (§15.4). **Disabled (greyed out) when no save files exist.** On menu load, the game scans the save directory; the button's enabled state is bound to "≥1 valid save present."
- **Options** — full options menu (§15.2).
- **Exit** — quit (with confirmation).

### 15.2 Options menu (all usual options)

- **Graphics:** resolution; fullscreen / borderless / windowed; vsync; quality preset; render scale; anti-aliasing; shadow quality; FOV; brightness/gamma; motion blur toggle; camera-shake toggle.
- **Audio:** master, music, SFX, UI, ambience, (voice) volumes; subtitles on/off + size.
- **Controls:** full keybinding remap (KB+M); mouse sensitivity; invert Y; gamepad bindings & sensitivity; vibration toggle; hold/toggle options for crouch/aim/sprint.
- **Gameplay / Accessibility:** colorblind modes; UI scale; aim assist (if combat is enabled); language select; reduce-flashing option.
- **System:** autosave toggle/frequency note; return to main menu; quit.

Options persist to a config file (Godot `ConfigFile`) independent of save slots so they're global.

### 15.3 HUD & diegetic UI (in-mission)

- **Detection indicator** (cone-fill / state, the "eye" feedback) — the most important HUD element.
- **Noise ring** when the player makes noise (audio channel legibility).
- **Carry readout**: current Weight/Volume vs. caps; a clear "full" warning.
- **Objective tracker** + secured-vs-remaining loot value.
- **Pursuit/Heat indicator** when relevant.
- Minigames render as focused diegetic overlays (lock face, hack screen, safe dial).
- HUD should be minimal and trustable — the player makes life-or-death calls off it.

### 15.4 The Continue / Save-Slot popup (10 slots)

- A popup listing **10 slots**. Each occupied slot shows a summary: current Streak length, total Soul XP, playtime, last-played date, and last location/contract. **Empty** slots read "Empty."
- Selecting an occupied slot **loads** it (→ Hideout). Selecting an empty slot from the Continue flow does nothing (or is non-selectable); empty slots are creation targets only from the New Game flow.
- A per-slot **Delete** action (with confirmation) lets players free slots.
- This same slot grid is reused by New Game (for choosing/overwriting a slot) and Continue (for loading).

### 15.5 Save model & roguelite integrity

- **Autosave** at the Hideout and after each completed mission (between missions), plus the player's manual slot.
- **No mid-mission save-scumming.** To preserve roguelite stakes: a mission may be **aborted cleanly only while still undetected** (a clean bug-out — keep secured loot, Streak intact, return to Hideout). Once detected / an alarm is raised, you're **committed** — escape or be caught. Quitting the application mid-active-alarm should not be a free escape (resume into the same hot state, or count as the Catch — see §16.4).

---

## 16. Technical Architecture (Godot 4.6)

### 16.1 Project structure & scenes

- **Main scene** boots into the Main Menu.
- **Menu scenes** (Main Menu, Options, Slot popup).
- **Hideout scene** with sub-scenes per station (§6) loaded/instanced modularly.
- **Mission scene**: a generator that assembles a level from prefabs (§7.5) + the in-mission gameplay systems.
- **Shared autoloads (singletons / EventBus):**
  - `GameManager` — top-level state, scene transitions.
  - `SaveManager` — slot I/O, autosave, scan-for-saves (drives the Continue button).
  - `RunManager` — current Streak state (Notoriety, Streak Level, Edges, Heat, The Take).
  - `ProgressionManager` — permanent Soul XP, unlocks, attributes, Hideout state.
  - `MissionGenerator` — seeded procedural assembly + population.
  - `AudioManager` — dynamic music layers, SFX bus.
  - `InputManager` — remappable actions (KB+M + gamepad).
  - `EventBus` — global signals (detection changes, loot secured, alarm tripped, etc.) to decouple systems.

### 16.2 Data-driven content (the expandability backbone)

Define everything as Godot **`Resource`s** (and/or JSON) so updates ship as data, not code:
- Location archetypes, room prefabs (+ their anchor metadata), objective definitions, modifiers.
- Loot definitions (weight, volume, value, tier, special hooks).
- Gear/gadget definitions and slot rules.
- Abilities/research nodes, attributes, Edges, meta-perks.
- Enemy/AI archetypes and their parameters.
- Intel types, Hideout station manifest entries.

A new mission type, gadget, Edge, or Hideout station should be addable by authoring a `Resource` + (where needed) a scene — never by editing a central switch.

### 16.3 Save system & 10-slot schema

Per-slot save (Godot `ConfigFile`/`Resource` serialization or JSON) contains:
- **Permanent (Soul) state:** Soul XP, all unlocks/research, attribute levels, Hideout station unlock states, Stash/collection, meta-perks, statistics.
- **Current Streak state:** active Notoriety & Streak Level, chosen Edges, current Heat, The Take, the current Job Map (available contracts + seeds), and a between-missions checkpoint flag.
- **Meta:** slot summary fields (playtime, last-played date, last contract) for the slot popup; save schema version (for migration across updates).

`SaveManager.scan_slots()` returns which of the 10 slots are populated; the Main Menu binds **Continue.enabled = (populated_count > 0)**.

### 16.4 Mid-mission persistence policy

Aligns with §15.5. Recommended default: the save checkpoint is **between missions at the Hideout state**; missions are atomic. Options for handling an app quit during an active mission:
- (a) **Clean abort allowed only pre-detection** (bug-out): on quit-pre-detection, return to Hideout state, keep secured loot.
- (b) **Committed once hot**: quitting during an active alarm resolves as the Catch (or, more forgivingly, resumes the hot state on next launch). **[OPEN — §21 Q5: how strict?]** Strictness trades save-scum prevention against player friction; pick a point on that dial.

### 16.5 AI, navigation, performance

- Guard/camera/dog behavior as lightweight **state machines** over Godot **NavigationServer** pathing.
- Vision cones via raycasts + angle/distance/light checks; sound via radius events on the EventBus.
- Keep instance counts and AI ticks budgeted for 60 FPS; use the low-poly art and occlusion to stay performant.

### 16.6 Input

KB+M and gamepad from day one, all bindings remappable via `InputManager` and the Options menu.

---

## 17. Onboarding & Tutorial

The first **New Game** runs a short, low-stakes guided heist that teaches, in order: movement and stances, vision cones & shadow, a takedown + hiding a body, a lockpick, a hack, grabbing/bagging loot, using a Drop Point, the carry-limit/multi-trip idea, and extraction. It then deposits the player at the Hideout and explains the Streak/Soul loop and the Job Map. Subsequent mechanics (drills, lasers, biometrics) are introduced contextually via the contracts that first feature them, or via tooltips, so the player isn't front-loaded.

---

## 18. Content & Live Expansion Plan

The architecture (data-driven content, modular Hideout stations, seeded procedural missions) is built so the game can grow steadily:
- **New location archetypes** and room prefabs.
- **New mechanics** (additional obstacle types, minigame variants) as reusable data + systems.
- **New gear, Edges, meta-perks, attributes.**
- **New Hideout stations** (each a scene + manifest entry, often gated behind Soul XP or special loot).
- **Roguelite live features** (later): daily/weekly seeded contracts with leaderboards, rotating global modifiers ("blackout week," "extra patrols"), seasonal Soul-cosmetic goals.

This is exactly the kind of game that benefits from incremental content drops, and the design front-loads that flexibility.

---

## 19. Development Roadmap

A pragmatic order of operations:

**Phase 0 — Prototype (greybox).** Core stealth loop in one handcrafted level: movement, vision cones, sound, one takedown, 2–3 obstacle types (lockpick, hack, a laser), loot pickup with weight/volume, one Drop Point + Escape, and the secured-loot rule. No art polish. Goal: prove the micro-loop is fun.

**Phase 1 — The roguelite spine.** Streak → Catch → Soul XP loop; Notoriety/Edges; a minimal Hideout (Job Map + Training + Workshop); the 10-slot save system + Main Menu + Continue-disabled logic. Goal: prove the macro-loop is compelling.

**Phase 2 — Vertical slice.** One polished location archetype with the seeded generator; 4–6 obstacle types; a vault Crack with breaching; going-loud/Pursuit; a real art pass in the chosen low-poly style; dynamic audio; full Options. Goal: a representative, shippable-quality slice.

**Phase 3 — Content & systems breadth.** Additional archetypes, more obstacles/gadgets/Edges/meta-perks, more Hideout stations, special loot & Stash, Intel/Take economy, balancing passes.

**Phase 4 — Polish & live features.** Accessibility, performance, juice, then daily/seasonal roguelite features.

---

## 20. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Procedural levels feel unfair/illegible for stealth** | Hybrid generation from hand-tuned modular prefabs with guaranteed solvable paths (§7.5); prioritize authored fairness over pure randomness. |
| **Scope creep on combat** | Default to the "escape gauntlet" model (§8.6); only expand to a full shooter if the slice proves it's worth the cost (§21 Q2). |
| **Art inconsistency from mixed CC0 sources** | Locked palette + master materials + scale grid + retexturing; ART-TODO registry; CC0-first sourcing (§13). |
| **AI complexity/performance** | Simple, readable state machines; budgeted AI ticks; low-poly perf headroom (§16.5). |
| **Currency overload (3 resources)** | Clear, distinct roles (§5, §12); option to fold The Take into Notoriety if testing shows confusion (§21 Q4). |
| **Roguelite stakes undermined by save-scumming** | Strict mid-mission persistence policy (§15.5/§16.4). |
| **Minigame fatigue** | Multiple frameworks, attribute/gear payoff, clue-based skips, never sole-solution (§9.8). |

---

## 21. Open Design Questions

These are the decisions where your input would meaningfully steer the project. I've defaulted each so the doc is internally complete — tell me which (if any) to flip.

- **Q1 — Perspective:** I defaulted **third-person** (best readability for solo stealth) with FP minigame snaps. Prefer **first-person** (more PayDay-like tension)?
- **Q2 — Going-loud combat depth:** I defaulted a **light "escape gauntlet"** (stealth-primary, limited combat, win by escaping). Do you want a **fuller cover-shooter** when loud (bigger scope, more weapons/armor/enemy variety)?
- **Q3 — Setting/tone & naming:** I defaulted **grounded modern crime with a light mythic "Soul" skin** (a metaphor for mastery/reputation). Do you want it **fully supernatural** (literal phantom/soul-stealing thief)? Also: keep the working names (Streak / Notoriety / Soul XP / The Take), or rename?
- **Q4 — Currency count:** Keep **three** resources (Notoriety + The Take + Soul XP) for a richer in-run economy, or **collapse to two** (drop The Take, fold its role into Notoriety) for simplicity?
- **Q5 — Mid-mission save strictness:** How strict on the roguelite integrity dial (§16.4)? Strict (committed once hot; quitting hot = Catch) vs. forgiving (resume the hot state) vs. very forgiving (free abort anytime)?
- **Q6 — Disguise/blend system:** Keep the **light disguise system** (§8.5) as one tool, or go **pure shadow-stealth** (cut disguises entirely) for a tighter, more classic solo-stealth feel?
- **Q7 — Procedural vs. handcrafted balance:** Comfortable with **hybrid procedural** (modular prefabs + seeded assembly), or do you want **fully handcrafted** levels (less variety, more authored quality) or **more aggressively procedural**?

---

## 22. Appendices

### Appendix A — Working title alternatives
*Soul Heist* (current placeholder, ties to Soul XP). Alternatives on theme (thief / death-rebirth / night): **Revenant**, **Nine Lives** (cat-burglar + roguelite lives), **Nocturne**, **The Last Score**, **Afterthief**, **Ghostline**. (Avoid existing IP collisions when finalizing.)

### Appendix B — Glossary
- **Streak** — a chain of contracts played until caught; the per-run progression line.
- **Notoriety (NP)** — per-Streak XP/score; drives Streak Levels & Edges; converts to Soul XP on Catch.
- **Streak Level / Edges** — in-run leveling; Edges are temporary per-run perks (build variety).
- **Heat** — per-Streak escalation from alarms/going loud; raises later-mission difficulty *and* the Soul XP multiplier.
- **The Take** — per-Streak cash currency for consumables/tools/Intel between missions.
- **Soul XP (SXP)** — permanent meta-currency; spent at the Hideout.
- **Catch** — being captured or killed; ends the Streak, banks Soul XP.
- **Drop Point** — in-level infinite-capacity stash; secured loot is banked immediately.
- **Escape/Extraction** — leaving the mission successfully; continues the Streak.
- **Casing / Thief Vision** — limited-duration mode highlighting threats, loot, and invisible lasers.
- **Intel** — purchasable contract information (modifiers, silent alarms, manifest).
- **Edges vs. Meta-perks** — temporary per-run perks vs. permanent passives.

---

*End of document v0.1. Sections marked **[OPEN]** and §21 await owner decisions before the next pass.*

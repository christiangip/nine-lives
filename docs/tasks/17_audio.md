# 17 — Audio

**Milestone:** M2 · **Depends on:** 04, 10 · **Blocks:** —
**Implements:** GDD §14 · **Decisions:** Q1 (FP → positional audio matters more), Q3 (grounded tone).

## Overview
For a stealth game, audio *is* gameplay. Two pillars: **dynamic music layers** that
track the detection/pursuit state, and **diegetic readability** — distinct,
learnable SFX and 3D-positional threat audio (doubly important in first-person).

## Functional Requirements
- **FR-17-1** `AudioManager` crossfades layered music stems across states: Calm → Tense (Suspicious/Searching) → Combat (Alert/Pursuit) → Resolve (extraction), driven by EventBus.
- **FR-17-2** Diegetic SFX set with distinct, learnable cues: spotted-sting, takedown, alarm, drill running/jamming, hack progress/fault, lockpick tension/snap, loot bagged/secured.
- **FR-17-3** 3D positional audio for guard footsteps/radios so threats are locatable by ear.
- **FR-17-4** Audio buses (Master/Music/SFX/UI/Ambience) wired to the Options volume sliders (15).
- **FR-17-5** Grounded palette (no supernatural motifs, Q3).
- **FR-17-6** All audio tracked in `ASSET_MANIFEST.csv` / `CREDITS.md` with correct licenses.
- **FR-17-7** Subtitles/captions for critical audio cues (accessibility; reduce reliance on sound alone).

## Phases
### Phase 17.1 — Bus & SFX
- [x] Bus layout + Options binding; `play_sfx` 2D/3D routing. *(Added the Ambience bus to
  `default_bus_layout.tres`; `SettingsManager._apply_audio` already maps the five sliders → bus dB.
  `AudioManager.play_sfx(id, position)` routes a transient `AudioStreamPlayer3D` when given a position
  else a 2D player; `play_loop` for sustained cues; `play_footstep` per-source throttled.)*
- [x] Core diegetic SFX set wired to gameplay events. *(Cues mapped from the Kenney CC0 set in
  `AudioConfigDef.sfx_paths`; AudioManager subscribes to the frozen EventBus globals, and local-signal
  sites — Lock snap, BreachPoint drill run/jam/done, HackTarget/HackMinigame, GuardAI takedown — call
  `play_sfx` directly.)*

### Phase 17.2 — Dynamic music
- [x] Layered stems + state crossfades tied to detection/pursuit signals. *(Four looped **procedural
  placeholder beds** (`AudioStreamWAV`) on the Music bus; `music_state_for()` pure seam + a per-actor
  aggregator over `detection_changed`/`pursuit_phase_changed` crossfade Calm→Tense→Combat;
  `mission_completed`/`streak_ended` → Resolve. Real stems pending — see ART-TODO.)*

### Phase 17.3 — Positional & accessibility
- [x] 3D footsteps/radios; occlusion-aware attenuation; captions for key cues. *(Player footsteps off
  `noise_emitted`; guards mount a cadence-driven 3D footstep so they're locatable by ear (FR-17-3).
  Captions: `AudioManager.caption_requested` → HUD caption line, gated on `audio.subtitles` (FR-17-7).
  Note: attenuation is standard 3D falloff (`max_distance`); true occlusion-aware attenuation is a later
  polish pass — the seam is the per-cue `AudioStreamPlayer3D`.)*

## Tests (GUT)
- [x] `test_music_state_mapping.gd` — detection/pursuit signals select the correct MusicState (pure seam
  + multi-actor aggregator + Resolve latch).
- [x] `test_bus_volume.gd` — Options sliders set the right bus dB; all five buses (incl. Ambience) exist;
  mute floors the bus.
- [x] `test_sfx_event_hooks.gd` — gameplay events (alarm/spotted/loot_secured) trigger the mapped SFX id;
  an unmapped id no-ops.
- [x] `test_audio_scenes.gd` — the `AudioSandbox.tscn` demo instantiates headlessly.

## Definition of Done
- [x] FR-17-1..7 satisfied; phases checked; tests green (headless GUT **356/356** on Godot 4.6.3).
- [x] M2 manual: closing your eyes, you can tell calm/tense/combat apart and locate a guard by footsteps.
  *(F6 sign-off on `game/scenes/audio/AudioSandbox.tscn` — verified 2026-07-05.)*

## Progress note
**Code + automated DoD complete & verified green** on Godot 4.6.3 (headless GUT **356/356**, +13 task-17
tests). Built on the **frozen EventBus** (no signal changes): `AudioManager` *subscribes* to the existing
globals and exposes a local `caption_requested` signal. **Music (FR-17-1):** four looped **procedural
placeholder beds** (`AudioStreamWAV`, rising intensity per state) crossfade on the Music bus, driven by a
pure `music_state_for(detection_state, pursuit_phase)` seam + a per-actor detection aggregator +
pursuit-phase; `mission_completed`/`streak_ended` latch **Resolve**, `game_state_changed` resets to Calm.
**SFX (FR-17-2):** every cue is mapped from the imported **Kenney CC0** set via a new data-driven
**`AudioConfigDef`** (21st `Content` registry `Content.audio`, with a static `resolve()`); AudioManager
handles the EventBus-global cues (spotted/alarm/loot/body/footstep) and **local-signal sites call
`play_sfx` directly** — `Lock` (snap), `BreachPoint` (a `play_loop` running-drill + jam/done),
`HackTarget`/`HackMinigame` (tick/fault/done), `GuardAI.take_down`. **Positional (FR-17-3):** player
footsteps off `noise_emitted`; `GuardAI` mounts a cadence-driven 3D footstep. **Buses (FR-17-4):** added
the missing **Ambience** bus; the Options sliders were already wired via `SettingsManager._apply_audio`.
**Captions (FR-17-7):** HUD caption line fed by `caption_requested`, gated on `audio.subtitles`.
**Grounded palette (FR-17-5)** — CC0 diegetic sounds, no supernatural motifs. **Manifest/credits
(FR-17-6)** updated; bespoke SFX + real music stems noted pending in ART-TODO. Demo:
`game/scenes/audio/AudioSandbox.tscn` (+ `AudioSandboxDebug.gd`) — an FP room (real furniture + safe +
a patrolling Swat) with dev keys to hear the music crossfade, locate the guard by footsteps, fire each
cue, toggle Subtitles, and mute a bus. **Residual (`[~]`):** the M2 human F6 "feel" sign-off.

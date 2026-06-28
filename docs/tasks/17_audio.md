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
- [ ] Bus layout + Options binding; `play_sfx` 2D/3D routing.
- [ ] Core diegetic SFX set wired to gameplay events.

### Phase 17.2 — Dynamic music
- [ ] Layered stems + state crossfades tied to detection/pursuit signals.

### Phase 17.3 — Positional & accessibility
- [ ] 3D footsteps/radios; occlusion-aware attenuation; captions for key cues.

## Tests (GUT)
- `test_music_state_mapping.gd` — detection/pursuit signals select the correct MusicState.
- `test_bus_volume.gd` — Options sliders set the right bus dB; mute works.
- `test_sfx_event_hooks.gd` — gameplay events (alarm, takedown, loot_secured) trigger the mapped SFX id.

## Definition of Done
- [ ] FR-17-1..7 satisfied; phases checked; tests green.
- [ ] M2 manual: closing your eyes, you can tell calm/tense/combat apart and locate a guard by footsteps.

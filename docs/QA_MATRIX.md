# Full-Loop QA Matrix — Nine Lives

**Task 21 · FR-21-5.** Exercise the whole roguelite loop across saves and a schema update with **no data
loss**. Automated coverage: the full GUT suite, `test_migration_release.gd` (v1→current migration with zero
data loss), and `test_save_menu_integration.gd`. This matrix is the **manual** pass over the parts a headless
test can't drive (real input, real scene flow). Run it before tagging a release.

> **Tutorial note:** FR-21-5 lists "tutorial → Streak → …". The guided tutorial is **task 22 (Onboarding)**,
> not yet built. Until 22 lands, start each row at **New Game** and mark the tutorial step _N/A (pending 22)_.

## A. Front door & saves
| # | Step | Expected |
|---|---|---|
| A1 | Launch fresh profile (no saves) | Main Menu; **Continue greyed out**; version `v1.0.0` shown |
| A2 | New Game → pick an empty slot | Slot created; lands in the Hideout; autosave written |
| A3 | Quit to menu, relaunch | **Continue enabled**; slot row shows the 5 summary fields |
| A4 | Continue | Restores the exact Hideout state (Legacy, unlocks, Streak) |
| A5 | Fill several slots; Delete one (confirm) | Only that slot clears; others intact |

## B. The Streak (stealth path — the intended play)
| # | Step | Expected |
|---|---|---|
| B1 | Take a contract; infiltrate a generated level | Plays end to end; guards/cones legible |
| B2 | Slip a cone in shadow; pick a lock / hack a panel | Detection reads correctly; minigames work |
| B3 | Bag loot → Drop Point → Escape | Value **banks**; Notoriety/Take split per the economy |
| B4 | Complete 2–3 contracts in a Streak | Board escalates; Streak length grows |
| B5 | Return to Hideout between contracts | Autosave at the hub; no mid-mission save |

## C. Going loud & the Catch
| # | Step | Expected |
|---|---|---|
| C1 | Trip an alarm | Heat rises; Pursuit phases climb; Streak **commits** |
| C2 | Fight / take damage | Damage vignette + camera shake; Down → self-revive window |
| C3 | Get Caught | Notoriety → **Legacy** payout on the Results screen |
| C4 | Hot-quit while committed, then Continue | The run resolves as the **Catch** (strict saves); no save-scum |

## D. Spend & feel the difference
| # | Step | Expected |
|---|---|---|
| D1 | Spend Legacy: a Training point + a Workshop unlock | Costs deducted; unlock persists |
| D2 | Buy Intel at the Planning Table | Contract modifiers reveal |
| D3 | Deliver special loot to the Stash | Set bonus applies |
| D4 | Next Streak | The upgrades are noticeably in effect |

## E. Accessibility (task 21)
| # | Step | Expected |
|---|---|---|
| E1 | Options → cycle Colorblind modes | Compass band re-palettes; symbol always present |
| E2 | Reduce Flashing ON | Shake/vignette/pulse/noise-ring all go steady (no strobe) |
| E3 | Camera Shake OFF | Firing/damage no longer shakes |
| E4 | Switch language (es/fr/de) | Menu/Pause text flips live; persists across relaunch |
| E5 | Remap a key (KB + gamepad); UI Scale; FOV | Apply + persist |

## F. Update / migration (the release gate)
| # | Step | Expected |
|---|---|---|
| F1 | Place a **previous-version** save in a slot | Loads without error |
| F2 | Continue that slot | Every field intact; new fields defaulted (zero data loss) |
| F3 | Play + re-save under the new schema | Round-trips identically on reload |
| F4 | Repeat across **all 10 slots** | No slot corrupts another; each independent |

## G. Performance & export
| # | Step | Expected |
|---|---|---|
| G1 | `docs/PERFORMANCE.md` dense-scene FPS pass | ≥ 60 FPS on the target spec at the dense tier |
| G2 | Export Windows + Linux; launch each | Reaches Main Menu; assets resolve; loop playable |

**Sign-off:** _tester / date / build / result._

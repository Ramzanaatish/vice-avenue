# Vice Avenue — Feature Status

| Feature | Status | Phase | Notes |
|---|---|---|---|
| Project skeleton + autoloads | Verified | 1–4 | Headless import + run clean |
| Boot / Main Menu / Settings / Save Slots (S01/S03/S04/S05) | Verified | 3 | Headless import + run clean, save/load PASS |
| Old Quarter greybox + Pause (S17/S06) | Verified | 4 | Slice A test PASS: pause freezes + resumes |
| Player controller + touch (S18 + S07) | Verified | 5 | Slice A test PASS: walks 4.0 m, joystick + buttons |
| Vehicle loop | Verified | 6 | Slice B test PASS: drives 15.6 m, enter/exit, vehicle-mode HUD |
| Combat loop | Verified | 7 | Slice C test PASS: melee kill (3 hits), player death → S15 |
| NPC loop | Verified | 8 | Slice C test PASS: 4 NPCs, walk/idle/talk/flee/death, Hamza offer |
| Police loop | Verified (limited) | 9 | Slice C test PASS: wanted rise/decay, capped pursuit, arrest → S15; Patrol/Follow deferred to Phase 9 |
| Dialogue (S12) | Verified | — | Data-driven JSON dialogue; test greps scripts for dialogue text |
| Fullscreen map (S08) | Verified | — | Slice C test PASS: open/close, marker, zoom, pause |
| Game over / death (S15) | Verified | — | Slice C test PASS: DOWN AND OUT + IN CUSTODY, Retry/Load/Quit |
| Economy + inventory | Verified (basics) | 10 | Inventory UI + pickup/drop; Use/Equip pending items/weapons |
| Mission loop (M04 slice) | Verified | 11 | Slice B test PASS: briefing → pickup → drive → return → +Rs 5,000 |
| Save + security | Verified | 12 | Slice C test PASS: position + facing + wanted restore; migration 1→2; kill-during-save; backup recovery; Retry via restore_checkpoint |
| Vertical Slice A/B/C | Verified | 13 | Slice A + B + C tests PASS headless; Gate 1 APK installed on the phone; Step 7 export check OK (build check only) |
| UI/map/settings polish | Verified | 14 | Step 7 test PASS (67 checks): neon theme, 48 px touch targets, settings persist/apply, pause return-to-world, save blocked while wanted |
| Audio + animation polish | Verified | 15 | Step 7 test PASS: 6 synthesized SFX wired + mute, walk bob/lean, attack lunge, hit flash, camera shake, police beacons; no music yet |
| Update + version system | Testing | 16 | VersionManager + migration |
| Slice review (go/no-go) | Testing | 17 | Headless part done (Step 7: load times, node counts, zero script errors, export check); real-phone profiling still pending |
| Full city + Play release | Planned | 18 | — |

Status values: Planned / In Progress / Testing / Verified.

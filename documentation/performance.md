# Vice Avenue — Performance

## What this file is
Measurements from headless runs on the dev VM (Godot 4.7.2, Linux
x86_64, 1.5 shared CPU, 6 GB RAM, no GPU). Headless runs execute
game logic but render nothing, so **this file contains no FPS,
draw-call, triangle, or on-device memory numbers**. Those come from
real-device profiling only (blueprint O-03) — inventing them here
would be worse than leaving them blank.

## Measured headless (Step 7, 23 November 2026)
- Full test suite, **6 test scenes, all PASS, zero script errors**:
  `test_all_scenes` (18 scenes load + instantiate, incl. new
  credits), `test_save_manager`, `test_slice_a`, `test_slice_b`,
  `test_slice_c`, `test_step7` (67 checks).
- Scene load times (headless, this VM — load + instantiate):
  world_root 86 ms / 159 nodes (heaviest); settings 28 ms / 41;
  hud 25 ms / 22; save_slots 20 ms / 25; main_menu 19 ms / 14;
  boot 18 ms / 5; player 18 ms / 10; pause_menu 16 ms / 13;
  inventory 13 ms / 26; npc 12 ms / 5; dialogue 11 ms / 7;
  police_officer 11 ms / 8; car 11 ms / 16; credits 10 ms / 30;
  map 10 ms / 6; game_over 10 ms / 9; mission_briefing 9 ms / 11;
  mission_results 7 ms / 12. All other scenes under 30 ms.
- Audio: 6 synthesized WAVs, 84 KB total (`audio/`, mono
  22050 Hz 16-bit, generated in-project, no licensed assets).
- Export check: Android Debug APK 29,258,083 bytes (v1.1.1 /
  code 3), apksigner verify OK, no export warnings.
- **Bug found headless and fixed (Step 7)**: a headless-only
  engine error (`Parameter "material" is null`, dummy renderer)
  appeared once per Slice C run after the Step 7 beacon meshes
  were added to the police scene. Root cause, proven by probes:
  `PoliceManager` called `load(OFFICER_SCENE)` on every dispatch,
  so after all officers were freed the scene reloaded with fresh
  sub-resources, and freeing an officer from a reloaded scene
  tripped the dummy renderer's material cleanup. Fix: the manager
  loads the officer PackedScene once and reuses it
  (`_officer_scene`); regression test in `tests/test_step7.gd`
  proves a re-dispatched officer reuses the cached scene's
  materials. Slice C is now error-free headless.
- Baseline noise (unchanged from Step 6/7 baselines, not
  regressions): the save-manager kill-during-save test writes
  garbage into a save on purpose (loader reports one JSON parse
  error); headless exit prints "resources still in use" /
  "ObjectDB instances leaked" notices.

## Measured headless (Step 6, 23 November 2026)
- Full test suite, 5 scenes, all PASS, **zero script errors**:
  `test_all_scenes` (17 scenes load + instantiate), `test_save_manager`
  (incl. schema 1→2 migration, kill-during-save, backup recovery),
  `test_slice_a`, `test_slice_b`, `test_slice_c`.
- `test_all_scenes` wall time ≈ 1 s including engine startup
  (17 scenes, 35 scripts, 18 scene files in the tree).
- Slice C full flow ≈ 41 s headless wall time. Of that, ≈ 25 s is
  the designed heat-decay wait (8 s grace + 50 heat ÷ 3/s ≈ 24.7 s
  of real game time) — not a load or performance cost.
- World content at Step 6: Old Quarter, 12 buildings, 4 NPCs,
  police dispatch cap 2 officers, 1 drivable car.
- Export check: Android Debug APK 29,198,330 bytes (v1.1.0 / code 2),
  apksigner verify OK (1 signer), icon inside.

## Still needs the real phone
- FPS and frame pacing in Old Quarter (walking, driving, 2 officers
  pursuing, HUD + minimap all live) — with the new walk bob, hit
  flash, camera shake and beacon blink running.
- Draw calls / triangles per frame and peak memory.
- Touch feel: joystick + Attack/Map buttons under a real thumb,
  map zoom/pan gestures, the 48 px touch targets, the new button
  press-pop feedback.
- Audio quality on the device: UI clicks, dialogue blips, hit
  thud, wanted sting, mission jingle, death sting — and the
  mute/volume settings actually silencing them.
- Load time from tap-to-menu and menu-to-world on the device.
- Battery/thermal behaviour over a 10-minute session.
- Settings persistence across a real app restart (volume, mute,
  sensitivity, invert camera, touch layout, show FPS).

## Method note
Headless timings above are VM wall times, not device timings — they
are useful only as a regression tripwire (a sudden jump means
something got slower), never as a device budget.

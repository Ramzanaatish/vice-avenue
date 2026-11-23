# Vice Avenue — v1.1.2 boot fix (Step 8 + phone-reported fix)

Original offline single-player 3D open-world crime/adventure game
for Android. Built step by step from the Ready to Build v4.0 blueprint.
Engine: Godot 4.7.x (pin one exact patch, e.g. 4.7.2). Language: GDScript.
3D tools: Blender. Mode: offline single player.

## What v1.1.2 fixes (on top of Step 8)

- **Boot fix (phone-reported)**: v1.1.1 stranded on the boot screen
  on a real phone — bar full, menu never appeared. Cause:
  `FileAccess.file_exists()` on a `res://` `.tscn` path returns
  FALSE in an exported build (scenes compile to `.scn` + `.remap`).
  Scene gates now use `ResourceLoader.exists()`. New regression
  test `tests/test_boot_fix.gd` + PCK boot gate
  `step8/check_pck_boot.sh` (the only check that can catch this
  bug class — the headless suite cannot). Version 1.1.2 / code 4,
  save schema stays 2 — no migration.

## What Step 8 adds (on top of Step 7)

- **Update and version system (Phase 16)**: a version manifest
  (`data/version_manifest.json`, v1.1.2 / code 4, save schema 2)
  plus a check flow in `VersionManager` — the game can tell
  whether an update is available or required and whether a save
  is compatible, all from a local file. Still fully offline: no
  network call, no account, no store. New self-test
  `tests/test_step8.gd` (52 checks). Version was 1.1.1 / code 3 at
  Step 8; now 1.1.2 / code 4 after the boot fix — save schema
  stays 2, no migration, old saves still load.
- **Release preset**: a second Android export preset, "Android
  (Release AAB)", alongside "Android Debug". The preset file was
  also fixed — it used old Godot 3-style option names that Godot
  4.7 silently ignores, so the AAB preset was really exporting an
  APK. It now really asks for format AAB.
- **AAB signing test (partial)**: a signed release AAB was built
  and verified (`jarsigner -verify` OK, and bundletool turns it
  back into a working universal APK with the right package,
  version and SDK levels). It was built from the Godot APK with
  Google's bundletool because Godot's own Gradle build cannot
  run on the dev VM right now — the VM blocks the loopback
  network Gradle's build daemon needs (see `step8/notes.md` for
  the exact setting). The AAB is signed with the **debug key
  for testing only**; a real Play upload key still has to be
  created before any Play upload. Nothing was uploaded anywhere.
- **Name check**: no game or app called "Vice Avenue" exists,
  but "Vice Avenue Games" is already a Play developer (different
  apps, same words) — a possible search-confusion risk, and a
  formal trademark check is still needed before a Play listing.
- **Android compatibility**: minSdk 24, targetSdk 36, arm64-v8a
  only, **no permissions at all** (the game is offline and asks
  for nothing).
- **Phase 17 (headless) go/no-go: NO-GO for the full city yet.**
  Everything checkable without a phone passes (all 7 test scenes,
  zero script errors, APK + AAB checks), but the pass bar is
  **30 FPS stable on the baseline phone** — and that number only
  exists once the game runs on a real phone. The full checklist
  is in `step8/notes.md`.
- **How to test on the phone**: push the Step 7 ZIP, let Actions
  build the APK, install over the Gate 1 build. (1) Play 10
  minutes in Old Quarter — walking, driving the car, 2 police
  chasing you — and report the FPS (turn on Show FPS in
  Settings first). (2) Check the game never stutters or gets hot.
  (3) Kill the app and reopen it — check your save and settings
  are still there. (4) Do the Step 7 list again (settings,
  sounds, bob/lean, police beacons, Mission 04 jingle, credits).
  (5) Report the phone model + Android version with the FPS, so
  the 30 FPS bar can be judged. The AAB is NOT for the phone —
  it is only the Play release format; keep installing the APK.

## What Step 7 adds (on top of Step 6)

- **UI polish (Phase 14)**: one consistent neon-night theme across
  all menus (dark navy panels, cyan accent, bigger buttons). Every
  touch button is now at least 48 px tall; the HUD objective line
  no longer runs off the screen; the wanted level turns red when
  police are after you. Buttons give a click sound and a small
  press-pop. The map's Close/Zoom buttons are thumb-sized.
- **Settings that actually work**: volume, mute, camera
  sensitivity, invert camera, camera shake on/off, touch button
  size/opacity, and an FPS counter — all save and apply. Pause →
  Settings now saves your game first and takes you back into the
  world (it used to drop you at the main menu). The pause menu
  shows your current objective and tells you saving is blocked
  while the police are after you.
- **Sound (Phase 15)**: UI clicks, a blip as dialogue advances, a
  thud when a hit lands, a sting when your wanted level rises, a
  jingle when a mission completes, and a sting when you die. All
  made inside the project (no downloads, no licensed music). Mute
  in Settings silences everything.
- **Animation (Phase 15)**: the player bobs and leans while
  walking, lunges on attack, flashes white when hit, and the
  camera shakes on damage (can be turned off in Settings). NPCs
  bob while walking and flash when hit. Police officers bob while
  chasing and flash red/blue beacons above their caps when they
  are pursuing you.
- **Credits (S16)**: a credits screen from the main menu.
- **Self-test**: `tests/test_step7.tscn` — 67 checks (settings
  persist/apply, mute, audio buses, animation getters, credits,
  theme sizes, map/HUD button sizes, version, police scene cache).
  All six test scenes pass headless with zero script errors.
- **How to test on the phone**: push, let Actions build the APK,
  install over the Gate 1 build. (1) Open Settings, change the
  volume and mute — check clicks go silent, then unmute. (2)
  Change touch button size and sensitivity — check the HUD buttons
  resize and the camera turns faster/slower. (3) Walk — check the
  bob/lean; hit a civilian — check the thud, flash, and the wanted
  sting. (4) Pause → Settings → Back — check you return to the
  world, not the menu. (5) Get chased — check the police beacons
  blink red/blue. (6) Finish Mission 04 — check the jingle.
  (7) Main menu → Credits — check the credits screen opens.
  (8) Turn on Show FPS in Settings — check the FPS label appears.

## What Step 6 adds (on top of Step 5)

- **NPCs (S20)**: Hamza (workshop, gives Mission 04), Rafiq, Sana,
  Imran — they walk, idle, talk, flee when hit, call the police, and
  die. Walk up to one and the HUD shows "Talk to \<name\>" (E or the
  Interact button). Killing one raises your wanted level.
- **Dialogue (S12)**: tap through Hamza's lines; his offer ("Tell me
  about it." → "I'll do it.") opens the Mission 04 briefing, same as
  the auto-briefing on world entry. Civilians have short lines; some
  remember you talked to them.
- **Combat**: the HUD Attack button (bottom-right, on foot only) is a
  melee swing — 3 hits kill a civilian. You take damage from police
  hits; at 0 health the game-over screen appears.
- **Wanted + police (S21)**: attacking anyone, or an NPC calling the
  police, raises heat and your wanted level (shown top-left). Police
  chase you (at most 2 at once); if one holds you for ~1.5 s you are
  arrested ("IN CUSTODY"). Run away and stay out of sight — heat
  decays and they give up ("You escaped.").
- **S08 Fullscreen Map**: HUD Map button (top-left), pause menu, or
  **M**. Shows Old Quarter, your arrow, and the active mission marker
  (gold diamond). Pinch/scroll to zoom, drag to pan, tap a marker for
  its name. Closes with X, M, or Esc.
- **S15 Game Over**: "DOWN AND OUT" when killed, "IN CUSTODY" when
  arrested. Retry reloads your last autosave checkpoint; Load opens
  save slots; Quit goes to the main menu.
- **Save v2**: saving now also stores where you stand, which way you
  face, and your wanted level/heat. Loading puts you back exactly
  there, with the NPCs alive again. Old (v1) saves still load — they
  migrate automatically.
- **Self-test**: `tests/test_slice_c.tscn` — drives the whole Slice C
  loop headless (decline → Hamza offer → accept → combat kill →
  wanted + pursuit → decay → save/load position restore → map →
  death → Retry → arrest → Quit). All five test scenes pass headless
  with zero script errors.
- **How to test on the phone**: push, let Actions build the APK,
  install over the Gate 1 build. (1) Walk to Hamza, talk, take the
  job. (2) Hit a civilian 3 times — check wanted rises and police
  chase you. (3) Run away until "You escaped." (4) Open the map (M
  or the button) and close it. (5) Save, walk away, load — you
  should be back where you saved. (6) Let the police catch you —
  check "IN CUSTODY", Retry, and Quit.

## What Step 5 adds (on top of Step 4)

- **S19 Vehicle (Car)**: one drivable car (VehicleBody3D + 4
  VehicleWheel3D, red body + dark cabin, chase camera). Tuning
  is data (`data/vehicles/car_01.json`: mass, engine/brake
  force, max speed, steering). Enter/exit with **E** (or the
  HUD Interact button) near the car; while driving the HUD
  swaps to ACCEL / BRAKE / HANDBRAKE + a speed readout, the
  joystick steers, and the minimap follows the car. Damage
  reduces engine force; condition 0 = cannot drive.
- **Mission 04 "A Small Favour" (Slice B mission)**: the
  briefing (S13) auto-opens on world entry (or on walking
  into the workshop) — Accept starts it. Objectives, in
  order: pick up the parcel at Hamza's workshop (goes into
  the inventory), drive it to the drop-off (the car must
  enter the beacon), return to Hamza. The results screen
  (S14) shows the reward (+Rs 5,000, granted exactly once)
  and Continue / Retry / Quit. Decline or failure leaves the
  mission re-offerable from the workshop beacon.
- **S09 Inventory (basics)**: category tabs (All / Weapons /
  Items / Consumables), item grid, detail panel, Drop works;
  Use/Equip are disabled until a usable/equippable item
  exists. Opens from the HUD Inventory button, the Pause
  menu, or **Tab / I**. The M04 parcel appears here on pickup.
- **Save/load validation**: `collect_save_data()` now writes
  the mission states (completed list), the inventory, the
  vehicle condition and the story flags into the save. The
  Slice B test completes the mission, saves slot 1, reloads
  it and checks the mission, the Rs 5,000 and the car
  condition all survived (checksum validated by the load).
- **Self-test**: `tests/test_slice_b.tscn` — drives the whole
  M04 loop with the real input actions (briefing -> accept ->
  pickup -> enter car -> drive 15 m -> drop-off -> return ->
  reward -> results -> save/load). Prints
  `TEST Slice B: PASS/FAIL`.

## What Step 4 adds (on top of Step 3)

- **S17 World Root — Old Quarter greybox**: ground, main street
  + cross street, 12 building boxes, 4 crates, sky + sun,
  player spawn. Geometry is generated from
  `data/maps/district_old_quarter.json` by
  `step4/generate_world.py` (kept outside the project folder),
  so the scene, the spawn point and the minimap data are one
  source of truth and can never drift apart.
- **S18 Player (Aariz, greybox)**: capsule body + head,
  third-person camera on a SpringArm3D (orbit with mouse drag
  or right-side touch drag, collision-aware), camera-relative
  movement (WASD/arrows), jump, sprint, gravity. Tuning comes
  from `data/player_tuning.json`, never hardcoded. Interaction
  ray (2.5 m) and area are in place; targets arrive later.
- **S07 HUD**: health bar, money (Rs 250 start), wanted level,
  objective line, data-drawn minimap (district bounds +
  buildings + player dot), virtual joystick (left thumb),
  JUMP and SPRINT buttons (right thumb). Listens ONLY to
  EventBus. Safe-area inset via `safe_area.gd` (C-01).
  Interact/Attack/Aim buttons arrive with their phases.
- **S06 Pause Menu**: Resume, Map (not built yet), Settings
  (full scene swap — the world unloads, Back returns to the
  Main Menu in this step), Save Game (writes autosave slot 0
  via the world's `collect_save_data()`), Quit to Main Menu.
  Android back button pauses too.
- **Self-test**: `tests/test_slice_a.tscn` — loads the world,
  drives the real `move_forward` action (player must walk
  4 m on the ground, not fall), checks the HUD money label
  and health bar, pauses (tree must freeze + overlay shows)
  and resumes. Prints `TEST Slice A: PASS/FAIL`.

## What Step 4 does NOT contain (on purpose)

- Title DECIDED 21 Nov 2026 (Gate 0.1): **Vice Avenue**,
  package `com.devflowia.viceavenue`. The Android Debug export
  preset is now in `export_presets.cfg` (arm64-v8a, version
  1.0.0 / code 1, debug keystore). The APK itself is still
  built on your PC — it needs the export templates + Android
  SDK there (Gate 1).
- **No real-device APK yet.** Slice A + B are code-complete, but
  Android Gate 1 (Verified on a real device) needs the Android
  export setup on your PC (SDK + export templates) + a phone
  run. That is the next job.
- No NPCs, combat or dialogue yet (Slice C). S02 Loading,
  S08 Map, S15 Game Over are later steps.
- Known gap: Continue / Load starts at the spawn point for
  now; restoring the exact saved position arrives with the
  Phase 12 save/load integration.

## How to open and test (your PC)

1. Unzip over the Step 3 folder (or unzip fresh) and open the
   project in Godot 4.7.2.
2. Press F5 (Run Project). Boot -> Main Menu. Then **New Game
   -> Save Slots -> Slot 1 "New Game"** — the world loads and
   you are standing on the main street in the Old Quarter.
3. Walk with **WASD / arrow keys**, **Space** to jump,
   **Shift** to sprint. Click the 3D view once, then move the
   mouse to orbit the camera. **Esc** (or the II button) pauses.
   The red car is parked on the main street near the spawn:
   walk up to it and press **E** to get in — **W/S** drive,
   **A/D** steer, **Space** handbrake, **E** to get out.
   The mission briefing opens on entry: Accept it, pick up
   the parcel at the workshop, drive it to the gold beacon
   at the north end of the street, then return to Hamza.
   **Tab / I** opens the inventory.
4. On a phone (Godot remote deploy / later APK): left thumb
   joystick to walk, JUMP / SPRINT buttons, drag the right
   side to turn the camera.
5. Report back: does it run clean, yes or no, with a screenshot
   of the Output panel if anything looks wrong.

## Gate 1: APK-ready (21 November 2026)

- Title + package ID: Vice Avenue, `com.devflowia.viceavenue`.
- App icon: neon "VICE AVENUE" sign (`icon.png` 192x192, adaptive
  foreground/background 432x432), wired into project.godot and
  the Android Debug export preset.
- GitHub Actions builds the APK: `.github/workflows/build-apk.yml`
  (Godot 4.7.2, export templates, export-debug, artifact
  "ViceAvenue-debug-apk").
- To build: push the CONTENTS of this folder to the repo root
  (project.godot must sit at the repo root), push to main — or
  run the workflow by hand from the Actions tab. Download the
  artifact, copy the APK to the phone, tap to install.

## Next steps (in blueprint order)

- Step 8 (Phase 16 + 17 headless): DONE 23 Nov 2026 — version
  manifest + update check (52 checks), AAB preset fixed, signed
  TEST AAB verified via bundletool, name check done, Android
  compatibility reviewed. **Go/no-go for Phase 18: NO-GO until
  the real phone reports 30 FPS stable** (see `step8/notes.md`).
- Phase 18 (full city + Play release): starts only after the
  Phase 17 go — needs the phone FPS number, a real upload key
  (keytool, never the debug keystore), and the formal trademark
  check before any Play listing.
- Gate 0.1: RESOLVED 21 Nov 2026 — title **Vice Avenue**,
  package `com.devflowia.viceavenue` (was the "VICE WORLD"
  working title; 12 "Vice" names checked, 21 searches).

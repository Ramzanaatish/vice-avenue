# Vice Avenue — Technical Decision Log

Every decision that locks something in goes here with its date and
reason. If v3.0 and this document ever disagree, the LATER dated
decision wins and the difference is recorded here (O-09).

## Decided

- 2026-11-21 — Gate 1 build path: GitHub Actions builds the Debug
  APK (workflow .github/workflows/build-apk.yml, ubuntu-latest,
  Godot 4.7.2 + export templates downloaded per run, export-debug
  "Android Debug", artifact ViceAvenue-debug-apk). Nelson builds on
  git, not on his PC. App icon: generated neon "VICE AVENUE" sign
  (magenta/cyan, palm silhouette); main 192x192, adaptive
  foreground 432x432, adaptive background solid black sampled from
  the icon corners. Export preset: arm64-v8a only, non-Gradle path,
  debug keystore — simplest first-phone-run setup.
- 2026-11-21 — Android export needs more than the preset: the SDK
  must have platform-tools (adb) + build-tools (apksigner), Godot
  needs BOTH editor settings (export/android/android_sdk_path AND
  export/android/java_sdk_path), and builds/android/ must exist
  before export (Godot does not create it). Proved by three failed
  exports here (apksigner missing -> platform-tools missing ->
  folder missing) before the real APK succeeded. The workflow
  creates the folder and sets both paths from the runner env.
- 2026-11-20 — Engine: Godot 4.7.x (pin one exact patch, e.g. 4.7.2).
  Language: GDScript. 3D tools: Blender. Platform: Android, offline
  single player. (Blueprint v4.0 header.)
- 2026-11-20 — Step 1 renderer: GL Compatibility for desktop and
  mobile (lowest supported renderer first; art is built for the
  lowest renderer FIRST).
- 2026-11-20 — Git LFS OFF by default (B-19). Enable only if the
  repo size becomes a real problem.
- 2026-11-20 — Save slots: 1 autosave + 2 manual = 3 total (B-13).
  Save location user:// only. Atomic write (temp → verify → rename),
  .bak of last good file, schema_version + checksum on every save.
- 2026-11-20 — Save checksum is computed over canonical JSON
  (stringify -> parse -> stringify), because Godot's JSON parser
  returns every number as float (250 becomes 250.0), so a
  checksum over the raw dict never verifies after a round-trip.
  Validation accepts integral floats for the same reason.
  Found by the Step 2 headless run: save OK, load failed
  "checksum mismatch" until this fix.
- 2026-11-20 — Autoload scripts must NOT declare class_name
  (Godot 4: "Class X hides an autoload singleton" — the script
  fails to load). The autoload name itself is the global.
  Found by the Step 2 headless import: all 10 autoloads failed
  until the class_name lines were removed.
- 2026-11-20 — FSR 3D scaling is Forward+ only; on GL
  Compatibility the project uses bilinear scaling instead
  (otherwise every boot logs a warning).
- 2026-11-20 — Frontend scenes (S01/S03/S04/S05) built in Step 3,
  ahead of the blueprint's Phase 14, because the launch path
  (boot -> menu -> slots) is needed to test every later slice
  on a real device.
- 2026-11-20 — AppRoot hosts scenes as children and never
  replaces itself: change_scene_to_file would destroy the
  switching logic with the old scene. GameManager decides the
  state; AppRoot only swaps.
- 2026-11-20 — `-s` scripts cannot see autoloads (Godot 4.7:
  "Can't use get_node() with absolute paths from outside the
  active scene tree"). Autoload-dependent tests run as scenes
  (tests/test_save_manager.tscn), not as -s scripts.
- 2026-11-20 — Godot 4.7 ignores a parent Node3D's scale for
  CollisionShape3D (verified with a throwaway experiment:
  a ball over a scaled-parent box fell to y = -5.39 while the
  same ball over an explicit-size shape landed at y = 0.49).
  The first greybox let the player fall 22.75 m through the
  ground. Rule: collision shapes get explicit BoxShape3D sizes
  and unscaled parents; only visual meshes may be scaled.
  World geometry is generated from data/maps/district_old_quarter.json
  by step4/generate_world.py so the scene and the minimap data
  stay one source of truth.
- 2026-11-20 — Slice A minimap is data-drawn (bounds +
  building footprints + player dot from the district JSON).
  A live SubViewport render comes with detailed art (later).
- 2026-11-20 — Pause Settings is a full scene swap (the world
  unloads; Back returns to the Main Menu in this step). An
  in-world settings overlay comes later.
- 2026-11-20 — Headless --import does NOT report GDScript `:=`
  type-inference errors (a `:=` over a Variant is a parse
  error only at scene load). Two shipped scripts carried them
  (settings.gd, save_slots.gd) and F5 never loaded those
  scenes. Rule: every step runs tests/test_all_scenes.tscn,
  which instantiates all 8 scenes for one frame each.
- 2026-11-20 — Node paths must match the scene tree exactly:
  controls nested under VBox / BottomBar in the .tscn are NOT
  direct children of the tab/card. Three scripts had this
  wrong (main_menu, settings, save_slots); the all-scenes
  test is the net that catches it.
- 2026-11-20 — Screenshots are taken by a temporary driver
  (tests/screenshot_frontend.gd, NOT shipped) running the
  real scenes under Xvfb — the renders are the game itself,
  not mockups. The driver seeds one save so the menu and
  slots show real data.
- 2026-11-20 — `:=` over a Variant struck again
  (vehicle_manager `near`): the value has no set type when
  any link in the chain is untyped. Rule stands: never `:=`
  over a property, a dictionary lookup or a call that can
  return Variant — use an explicit type.
- 2026-11-20 — The back-button notification constant is
  NOTIFICATION_WM_GO_BACK_REQUEST; NOTIFICATION_GO_BACK_REQUEST
  does not exist (inventory.gd parse error).
- 2026-11-20 — Mission data rule: location keys MUST match
  objective ids. The M04 JSON used "dropoff" for the "drive"
  objective, so the beacon was silently built at (0,0,0) and
  the drop-off never triggered. Fixed in the data, not code.
- 2026-11-20 — A test must observe before it acts: the
  Interact button is hidden by enter_vehicle in the same
  frame it appears, so the Slice B test checks visibility
  in its own phase before pressing E.
- 2026-11-20 — The all-scenes test must run process_mode
  ALWAYS: a loaded scene can pause the tree itself (the
  world's auto-briefing), which froze the test for 120 s.
- 2026-11-20 — Screenshot drivers under Xvfb run at a few
  FPS, so a 0.5 s timer can already be past a 1.0 s game
  timer. Capture on the first frame, or lock the state
  first (the Slice B driver locks the mission for the
  world shot, then re-opens the briefing via the beacon).

## Open (see Part 8 of the blueprint)

- O-01 RENDERER: Mobile (Vulkan) vs Compatibility (OpenGL ES 3.0) —
  decided by the Phase 3 device test (B-02). Blocks art/material/shader
  choices.
- O-02 BASELINE DEVICE: exact low-end + high-end phone models —
  decided in Gate 0.2. Blocks performance budget values.
- O-04 GAME TITLE: RESOLVED 21 Nov 2026 — "Vice Avenue",
  package com.devflowia.viceavenue (Nelson's pick; 12 "Vice"
  names checked, 21 Play + web searches, round 2 after "GTA
  Vice s milta julta nam ho koe"). "Vice Quarter" was the
  cleanest alternative (zero Play game, only a 1999 RPG area
  name); "Vice Avenue" won as his pick. Export preset choice:
  Android Debug, arm64-v8a only, non-Gradle path, debug
  keystore — simplest first-phone-run setup; release signing
  and 32-bit support are later decisions, not now.
- O-03 PERFORMANCE NUMBERS: FPS / draw-call / triangle / memory caps
  go into performance_budget.md AFTER Phase 2 profiling (B-18).
  Do not invent them earlier.

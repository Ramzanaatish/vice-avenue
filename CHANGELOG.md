# Vice Avenue — Changelog

## v1.1.2: Boot fix (phone-reported) — 23 November 2026
- **Bug (reported from the phone, v1.1.1)**: the game stranded on
  the boot screen — green bar full, "v1.1.1" shown, main menu
  never appeared. **Root cause**: AppRoot's scene gate used
  `FileAccess.file_exists()` on a `res://` `.tscn` path. In an
  exported build scenes are compiled to `.scn` + `.remap`, so the
  literal `.tscn` is not in the PCK and the check returns FALSE;
  headless it returns TRUE (the `.tscn` files exist on disk), so
  every headless run passed and the bug shipped. It was present
  since Gate 1 — the Gate 1 "first run" only ever showed the boot
  screen. Reproduced before fixing by running the exported PCK
  headless: log showed "AppRoot: scene not built yet:
  res://scenes/frontend/main_menu.tscn".
- **Fix**: scene-existence checks now use `ResourceLoader.exists()`
  (resolves remaps) in `scripts/core/app_root.gd`,
  `scripts/ui/main_menu.gd` (world + credits scenes) and
  `scripts/ui/save_slots.gd` (world scene). Data `.json` checks
  are untouched — `.json` files ship as plain files in the APK,
  so `FileAccess` works for them. `FileAccess` stays correct for
  `user://` save files.
- **Regression guards**: new `tests/test_boot_fix.gd` (21 checks:
  all 11 switchable scenes exist via `ResourceLoader`, no
  `FileAccess` scene gate left in the three switching files,
  version 1.1.2 / code 4) and `step8/check_pck_boot.sh` — exports
  a PCK and runs the game from it, failing if the boot gate ever
  rejects a scene again. The PCK run is the only gate that can
  catch this bug class; the headless suite alone cannot.
- **Version**: 1.1.2 / code 4, save schema stays 2 — no migration,
  old saves still load. Content version 4.
- **Verified**: all 8 headless tests PASS (18 scenes, zero script
  errors); PCK boot check PASS (boot advances to main menu in the
  exported build); export-check APK 29,422,742 B, v1.1.2 / code 4,
  apksigner OK, minSdk 24, targetSdk 36, zero permissions.

## Step 8: Review / release (Phase 16 + 17, headless part) — 23 November 2026
- **Phase 16 — update and version system** (`data/version_manifest.json`
  + `scripts/autoload/version_manager.gd`): the manifest carries
  package_id, version_name 1.1.1, version_code 3, save_schema 2,
  content_version 3, min_supported_version_code 1, channel "dev",
  release_date 2026-11-23. New pure functions, all headless-tested:
  `load_manifest()` (never crashes, `{}` on failure),
  `validate_manifest()` (checks every field against the constants
  and the version table's latest row), `check_update(candidate)`
  (update_available / required when the installed code is below
  the candidate's min_supported), `is_save_compatible(schema)`
  (schemas 1–2 true, 0 and 3+ false), `get_update_summary()`.
  `check()` is unchanged. No network call, no account, no store
  upload — the game stays offline-first; the manifest is a local
  file the launcher reads, and the update decision is a pure
  function over it.
- **New test** `tests/test_step8.gd` + `tests/test_step8.tscn` —
  **52 checks**: manifest loads/validates, validate rejects bad
  manifests (wrong code/package/schema/min), check_update cases
  (same/newer/required/older/empty), save compatibility, summary,
  version table strictly increasing + latest row, export-preset
  consistency, and the Step 7 police scene-cache regression guard
  (officer scene load appears exactly twice: ready + guarded
  fallback).
- **Version**: stays 1.1.1 / code 3 — the update/version system
  does not require a bump. Save schema stays 2, no migration.
- **Android compatibility review** (documented facts, no phone
  yet): package com.devflowia.viceavenue; minSdk 24, targetSdk 36,
  compileSdk 36 (build-tools 36.1.0, NDK 29.0.14206865, Gradle
  8.11.1); arm64-v8a only; **no permissions at all** in the
  manifest (offline game — no INTERNET, no storage, no location);
  label "Vice Avenue". Play policy basics: new apps need Play App
  Signing (upload key kept off Git, two backups), a privacy
  policy + data-safety declaration (no data collected), the
  content rating questionnaire, and closed testing with 12+
  testers for 14 days before production for new personal
  accounts. A formal trademark registry check (USPTO / Pakistan
  IPO) is still outstanding before any Play listing.
- **Name check (research only, 23 Nov)**: no game or app actually
  titled "Vice Avenue" was found. "Vice Avenue" is a street name
  inside GTA games (GTA Wiki: Vice City 3D Universe list; GTA 6
  has South/North Vice Avenue in Leonida), and a 2021 song
  ("Vice Avenue", Ty in the Building ft. Sada Baby & BabyTron).
  **"Vice Avenue Games" is an existing Play developer**
  (packages `com.ViceAvenueGames.*`: Cafe Simulator 3D,
  TimberQuest/Lumber Quest, Quarantine Simulator) — a
  search-confusion risk, different package, no technical clash.
  Nothing filed, nobody contacted.
- **Export preset fix (real bug found headless)**: the
  hand-written `export_presets.cfg` used Godot 3-style slash
  keys (`gradle/build/*`, `launcher/icon/*`,
  `variant/architecture/*`) that Godot 4.7 **silently ignores**.
  Verified against the Godot 4.7.2 source, the correct names
  are `gradle_build/use_gradle_build`,
  `gradle_build/export_format` (0 = APK, 1 = AAB),
  `gradle_build/min_sdk` / `gradle_build/target_sdk` (STRING
  type in 4.7 — must be quoted `"24"` / `"36"`),
  `launcher_icons/main_192x192` (+ adaptive foreground /
  background), `architectures/arm64-v8a`. The whole file was
  rewritten with correct names for BOTH presets (preset.0
  behaviour-preserving: its old values equalled defaults
  except icons, which resolve to the same files);
  `screen/opaque` was removed (not a 4.7 option). New preset
  "Android (Release AAB)": export_format 1, path
  `builds/android/ViceAvenue-release.aab`, Gradle build on,
  version 1.1.1 / code 3, keystore fields intentionally EMPTY
  in the file — signing via env vars at export time
  (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`).
  First verbose export after the fix printed
  `- export format: 1` (was 0 before).
- **AAB signing test — PARTIAL, blocked by the VM, worked
  around**: Godot's AAB export runs Gradle, and Gradle's
  daemon talks to its launcher over loopback TCP. On this VM
  that TCP is intercepted by the sandbox (proven: a Java
  loopback test got the runtime's "Other TCP connections is
  turned off" message instead of its own server's reply), so
  every daemon build fails with "Could not receive a message
  from the daemon" even though the daemon starts, listens on
  127.0.0.1 and stays alive. `org.gradle.daemon=false` /
  `--no-daemon` do NOT avoid it — Gradle 8.11 forks a
  single-use daemon (still over TCP) either way. The fix is a
  host setting, not a project change: Muse Settings →
  Permissions → Direct network protocols → switch `other_tcp`
  from Deny to Ask (or run the Gradle build where loopback
  TCP is allowed). Until then, the AAB was produced the
  honest way instead of faked: the Godot Debug APK
  (v1.1.1/code 3) was converted with aapt2 36.1.0
  (`aapt2 convert --output-format proto`) and repackaged
  with Google bundletool 1.18.1 (`build-bundle` from a
  base module: manifest + resources.pb + res + 13 dex +
  lib/arm64-v8a + 187 assets + kotlin/root files), then
  signed with jarsigner using the **debug keystore — TEST
  SIGNING ONLY, never the Play upload key** (a real upload
  key must be created with keytool before any Play upload).
  Verified: `jarsigner -verify` → "jar verified.";
  `bundletool build-apks --mode=universal` exit 0 and the
  generated universal APK badges
  com.devflowia.viceavenue v1.1.1/code 3, minSdk 24,
  targetSdk 36, "Vice Avenue". AAB
  `step8/ViceAvenue-v1.1.1-release-signed-TEST.aab`,
  29,323,738 bytes (unsigned twin alongside). Godot's own
  Gradle AAB path is NOT yet proven on this VM — it stays
  open until a build runs where loopback TCP is allowed.
  One real Godot quirk found on the way: the APK's resource
  table references `res/mipmap-anydpi-v26/themed_icon.xml`
  but the file is not packaged, so `aapt2 convert` fails
  until a copy of `icon.xml` is added at that path (themed
  icon then renders as the regular icon in the test AAB
  only; the debug APK installs fine as-is).
- **VM environment fixes (documented in step8/notes.md)**:
  Android SDK completed on this VM (cmdline-tools 11076708,
  platform android-36_r02, build-tools 36.1.0, NDK
  29.0.14206865, licenses written by hand — curl works
  through the proxy, Java `HttpURLConnection` proxy
  tunnelling is broken on this VM); export templates
  completed (`android_source.zip` extracted from the
  `.tpz`); Gradle 8.11.1 pre-populated in the wrapper dists
  (correct hash dir is the MD5 of the URL as a positive
  BigInteger in base-36:
  `bpt9gzteqjrbo1mjrsomdt32c`, plus the `<zip>.ok` marker);
  **Java's `user.home` is `/root`, not `$HOME`** — the
  wrapper looks in `/root/.gradle` unless `GRADLE_USER_HOME`
  is set (set it to `/home/hatch/.gradle` for every Gradle
  run here). `android/build/gradle.properties`: daemon
  heap lowered 4536m → 1536m and `org.gradle.daemon=false`
  added (documented in the file; safe to revert on a machine
  where the daemon works).
- **VERIFIED** — headless, Godot 4.7.2: **all 7 test scenes
  PASS, zero script errors** — test_all_scenes (18 scenes),
  test_slice_a, test_slice_b, test_slice_c, test_save_manager,
  test_step7 (67 checks), **test_step8 (52 checks)**.
- **Export checks** (build checks only, NOT user
  deliverables): Android Debug APK re-exported after the
  preset rewrite — exit 0, 29,418,270 bytes, format 0,
  package com.devflowia.viceavenue v1.1.1/code 3, aapt2
  badging confirmed; signed TEST AAB as above.
- **Phase 17 (headless) go/no-go**: NO-GO for Phase 18 —
  everything verifiable headless passes, but the Gate 0.7
  pass bar is **30 FPS stable on the baseline device**, which
  is still unmeasured (needs the real phone). Full checklist
  in `step8/notes.md`.
- Docs: `documentation/feature_status.md` (Phases 16/17 →
  Verified headless), `documentation/performance.md` (Step 8
  headless facts + Android compatibility + pending phone
  list), `documentation/update_release_process.md` (version
  table: 1.1.0/code 2/schema 2 and 1.1.1/code 3/schema 2),
  this changelog, README (Step 8 section + phone test list).

## Step 7: Polish (v1.1.1 / code 3) — 23 November 2026
- **Phase 14 — UI polish**: one neon-night theme (`themes/ui_theme.tres`,
  dark navy panels, cyan accent, Button font 18, ~47 px min height)
  applied to all 12 frontend scenes. HUD: objective label centred
  with ellipsis, 48×48 touch buttons, money/wanted font 20 (wanted
  turns red), FPS label (shows only when `show_fps` is on), touch
  button size/opacity now apply on ready and on settings change.
  Joystick: 0.12 dead zone, knob glides back in 0.12 s. Map: 48×48
  Close/Zoom buttons, centred info label. Dialogue choices 420×48
  with a fade-in; game-over screen fades in. Button presses give a
  click sound + 0.1 s scale pop (`scripts/ui/ui_feedback.gd`).
- **Settings actually persist and apply**: volume/mute, sensitivity,
  invert camera, camera shake, touch layout, show FPS — all wired
  through SettingsManager and verified headless. Pause → Settings
  autosaves slot 0 first, and Back returns to the world (not the
  menu). Pause menu shows the current objective + autosave status,
  and Save is disabled with a reason while wanted > 0.
- **Phase 15 — audio**: 6 synthesized WAVs in-project (84 KB total,
  mono 22050 Hz, generated by `step7/gen_audio.py`, no licensed
  assets): UI click, dialogue blip, attack hit thud, wanted sting,
  mission-complete jingle, death sting. Wired to the right moments
  (dialogue advance, hit lands, wanted rises, mission completes,
  player dies). Mute/volume settings silence them. No music or
  ambience composed yet — the buses exist, content is a later step.
- **Phase 15 — animation (procedural, no new assets)**: player walk
  bob + lean, attack lunge, white hit flash, camera shake on damage
  (respects the accessibility setting); NPC walk bob + hit flash;
  police walk bob + hit flash + red/blue pursuit beacon blinking
  above the cap while pursuing. Sensitivity + invert camera apply
  to the player.
- **Credits (S16)**: `data/credits.json` (6 sections) + credits
  scene from the main menu; test_all_scenes now covers 18 scenes.
- **Bug found headless and fixed**: a headless-only engine error
  (`Parameter "material" is null`) appeared once per Slice C run
  after the police beacon meshes were added. Root cause, proven by
  probes: the PoliceManager re-loaded the officer scene on every
  dispatch, so after a full recall the scene reloaded with fresh
  sub-resources and freeing such an officer tripped the dummy
  renderer's material cleanup. Fix: the manager caches the officer
  PackedScene once (`_officer_scene`) and reuses it; a regression
  test in `tests/test_step7.gd` proves a re-dispatched officer
  reuses the cached scene's materials. Slice C is error-free again.
- **Version**: 1.1.1 / code 3, patch only — save schema stays 2, no
  migration, old saves still load.
- **VERIFIED** — headless, Godot 4.7.2: test_all_scenes PASS (18
  scenes); test_save_manager PASS; test_slice_a PASS; test_slice_b
  PASS; **test_slice_c PASS**; **test_step7 PASS (67 checks)**.
  **Zero script errors across all six runs.**
- **Export check** (build check only, NOT a user deliverable):
  Android Debug APK `step7/ViceAvenue-v1.1.1-export-check.apk`,
  29,258,083 bytes, package com.devflowia.viceavenue v1.1.1/code 3,
  apksigner verify OK, no export warnings.
- Docs: `documentation/performance.md` extended with Step 7
  headless measurements (scene load times, node counts, resource
  sizes) + the real-phone list; `documentation/feature_status.md`
  updated (Phases 14/15 verified, Phase 17 headless part done).

## Step 6: Slice C "Alive" (v1.1.0 / code 2) — 23 November 2026
- **NPCs (S20)**: 4 NPCs in Old Quarter (`data/npcs/npcs_old_quarter.json`) — Hamza (mission archetype, at the workshop), Rafiq, Sana, Imran (civilians walking the street grid). FSM Idle/Walk/Talk/Flee/Dead; they flee when hit, call the police, and fall when killed. Talk prompt wins over Enter Car (one arbiter in world_root).
- **Dialogue (S12)**: data-driven dialogue UI (`scenes/frontend/dialogue.tscn`); all lines live in `data/dialogue/*.json` only — a test greps every `.gd` under `res://scripts` to prove no dialogue text is in code. Branching on mission state/flags; Hamza's offer path (offer → accept) opens the M04 briefing and starts the mission.
- **Combat**: melee attack (34 dmg, 2.4 m, ±60° arc, 0.45 s cooldown; HUD Attack button + touch). NPCs and police have health and die; the player takes damage and dies → S15.
- **Wanted + police (S21)**: heat rises on hostile acts (attack NPC +30, attack police +40, NPC calls police +20), decays 3/s after an 8 s grace; wanted tiers at 25/50. Police dispatch is capped (tier 1 → 1, tier 2 → 2 officers); officers Investigate → Pursue → Arrest (1.5 s within 1.8 m) → Search, and give up when the player escapes or wanted decays. Arrest reaches S15. **Bugs found headless and fixed**: (1) the pickup beacon fired for Hamza himself (he stands in it) and re-opened the briefing after Decline — the re-offer now requires the body to be the player; (2) two officers spawned at the same spot were launched skyward by the physics solver — spawn spots now exclude spots occupied by a live officer.
- **S08 Fullscreen Map**: opens from the HUD Map button, the pause menu, or **M**; district bounds, buildings, roads, player arrow (rotates with facing), gold mission marker, zoom 0.6–2.5, drag pan, tap a marker for its name. Pauses the game while open.
- **S15 Game Over**: "DOWN AND OUT" (death) / "IN CUSTODY" (arrested) with the cause line; Retry reloads the autosave checkpoint, Load goes to save slots, Quit returns to the menu. Retry is disabled when no autosave exists.
- **Save v2**: schema 1→2 migration (adds `player.rotation_y`, `wanted_level`, `heat`); save/load now restores player position + facing + wanted/heat; NPCs respawn on load; an open dialogue closes cleanly before saving (dialogue state is never stored). New `restore_checkpoint()` (autosave slot 0) for Retry; backup recovery now migrates old-schema backups too. Tests cover migration, kill-during-save (partial `.tmp` ignored, intact slot loads), and backup recovery.
- **VERIFIED** — headless, Godot 4.7.2: test_all_scenes PASS (17 scenes); test_save_manager PASS (incl. migration + kill-during-save + backup recovery); test_slice_a PASS; test_slice_b PASS; **test_slice_c PASS** (briefing decline → Hamza offer → accept → dialogue closes on save → combat kill → wanted + pursuit → decay to 0 → save/load position restore → map → death → Retry → arrest → Quit to menu). **Zero script errors across all five runs.**
- **Export check** (build check only, NOT a user deliverable): Android Debug APK `step6/ViceAvenue-step6-export-check.apk`, 29,198,330 bytes, package com.devflowia.viceavenue v1.1.0/code 2, apksigner verify OK (1 signer), neon icon inside. Note: the VM's editor Java path had gone stale (`/usr/lib/jvm/java-21-openjdk-amd64` no longer exists); fixed locally to `/home/hatch/jdk17` — the project's `export_presets.cfg` is unchanged.
- Docs: `documentation/performance.md` added (headless measurements only — no FPS/draw-call numbers invented; those need the real phone, blueprint O-03).

## Gate 1: APK-ready — 21 November 2026
- App icon: generated neon "VICE AVENUE" sign (magenta/cyan, palm
  silhouette); main 192x192 + adaptive foreground/background 432x432,
  wired into project.godot and the Android Debug preset. Placeholder
  icon.svg removed.
- GitHub Actions workflow `.github/workflows/build-apk.yml`: Godot
  4.7.2 + export templates + Android SDK paths (android_sdk_path +
  java_sdk_path from the runner environment) + `mkdir -p
  builds/android`, artifact "ViceAvenue-debug-apk".
- VERIFIED — real Debug APK exported here: `ViceAvenue-debug.apk`
  29,121,511 bytes, package com.devflowia.viceavenue, version 1.0.0 /
  code 1, label "Vice Avenue", signed (APK Signature Scheme v3,
  1 signer), neon icon inside (adaptive mipmaps), 221 files.
  apksigner verify: OK. aapt2 badging: package + label confirmed.
- Docs: all 7 registers retitled Vice Avenue; release process
  package ID fixed to com.devflowia.viceavenue.
- Verified: headless import exit 0 / 0 errors; test_all_scenes PASS
  (12); F5 clean ("Vice Avenue Step 5 booted.").

## Gate 0.1 resolved — 21 November 2026
- Title DECIDED: **Vice Avenue**, package `com.devflowia.viceavenue`
  (Nelson's pick from 4 options; "Vice Avenue" is a street name in
  GTA: Vice City, no game carries the title — a "Vice Avenue Games"
  studio already publishes on Play, noted as a search-confusion
  risk). Replaces the "VICE WORLD" working title everywhere the
  player sees it (boot + main menu title, project name, app_root
  boot print). Historical dated entries below keep the old name.
- Android Debug export preset added (`export_presets.cfg`):
  arm64-v8a only, version 1.0.0 / code 1, debug keystore, export
  path `builds/android/ViceAvenue-debug.apk`. APK build itself
  stays on Nelson's PC (export templates + SDK) — Gate 1.

## 1.0.0 (Step 5: Slice B) — 20 November 2026
- S19: one drivable car (VehicleBody3D, data tuning in
  data/vehicles/car_01.json), enter/exit via E / HUD button,
  vehicle-mode HUD (ACCEL/BRAKE/HANDBRAKE + speed), joystick
  steers, minimap follows the car, damage/condition.
- M04 "A Small Favour": briefing (S13) + results (S14),
  pickup -> drive -> return, +Rs 5,000 reward granted once,
  replayable from the workshop beacon after decline/failure.
- S09 inventory basics: categories, grid, detail, Drop;
  Use/Equip disabled until usable items exist.
- Save/load validation: mission states, inventory, vehicle
  condition and story flags now written into the save and
  verified by a load round-trip in TEST Slice B.
- New tests: tests/test_slice_b.tscn (full M04 loop, PASS),
  test_all_scenes now covers 12 scenes (PASS).
- Fixes found by verification: `:=` over a Variant again
  (vehicle_manager), wrong back-button constant
  (NOTIFICATION_WM_GO_BACK_REQUEST), mission location key
  "dropoff" did not match objective id "drive" (beacon built
  at 0,0,0), all-scenes test froze when the world's
  auto-briefing paused the tree (test now runs ALWAYS).

## 1.0.0 (Step 4 v2: frontend fixes) — 20 November 2026
- Fix: Settings and Save Slots scripts had latent parse errors
  (`:=` over a Variant) that headless --import never reported
  and F5 never reached — opening either screen would have
  failed on a real PC. Caught by the screenshot run.
- Fix: node-path mismatches in settings.gd / save_slots.gd
  (controls live under VBox / BottomBar in the scenes, scripts
  addressed them as direct children).
- New permanent test tests/test_all_scenes.tscn — instantiates
  all 8 scenes, one frame each (TEST all scenes: PASS).

## 1.0.0 (Step 4: Slice A) — 20 November 2026
- S17 World Root (Old Quarter greybox: 12 buildings, 4 crates,
  streets, sky, spawn) generated from data/maps/district_old_quarter.json
  by step4/generate_world.py.
- S18 Player (third-person, camera-relative, jump/sprint, tuning
  from data/player_tuning.json) + SpringArm3D camera.
- S07 HUD (health, money, wanted, objective, minimap, virtual
  joystick, JUMP/SPRINT buttons, safe-area inset) + S06 Pause
  Menu (Resume/Map/Settings/Save/Quit, Android back pauses).
- Self-test tests/test_slice_a.tscn (movement, HUD, pause/resume).
- Fix: Godot 4.7 ignores a parent Node3D's scale for
  CollisionShape3D — the first greybox let the player fall
  through the ground (caught by the strengthened test: y fell
  22.75 m). Collision shapes now have explicit BoxShape3D
  sizes and unscaled parents.
- Still NOT in Step 4: Android export presets and package ID
  (Gate 0.1 name check must pass first), real-device APK
  (Android Gate 1), vehicles/NPCs/missions/combat.

## 1.0.0 (Step 3: frontend S01/S03/S04/S05) — 20 November 2026
- S01 Boot/Splash (1.2 s minimum, tap to skip), S03 Main Menu
  (Continue/New Game/Settings/Credits/Exit), S04 Settings
  (4 tabs, SettingsManager only), S05 Save Slots (3 cards,
  Load / New Game / Delete with confirm).
- AppRoot rework: hosts the current scene as a child, never
  replaces itself; boot check is read-only (no test-save writes).
- Self-test scene tests/test_save_manager.tscn (save/load
  round-trip + delete, prints TEST save/load: PASS/FAIL).
- Autoload additions: VersionManager.check(),
  SettingsManager.reset_to_defaults(), SaveManager.load_slot().
- Fix: Main Menu buttons live under Center/MenuBox, not the
  scene root (caught by the headless run: "Node not found:
  ContinueButton").
- Still NOT in Step 3: Android export presets and package ID
  (Gate 0.1 name check must pass first), world/gameplay scenes
  (Slice A, Step 4).

## 1.0.0 (Step 2: autoloads + AppRoot) — 20 November 2026
- All 10 autoloads (Part 5): EventBus, VersionManager, AudioManager,
  SettingsManager, SaveManager, GameManager, MissionManager,
  EconomyManager, InventoryManager, SecurityManager.
- AppRoot main scene (owns scene switching, B-11) + Step 2 smoke
  test (autoload check + save/load round-trip, printed to the log).
- Save system per B-13: atomic writes, .bak backup, checksum,
  validation, chained migrations, downgrade protection.
- Docs added: feature status, update & release process, git setup
  (plain CMD).
- Fix: AudioManager loads BEFORE SettingsManager, so volume
  settings apply to buses that already exist.
- Still NOT in Step 2: Android export presets and package ID
  (Gate 0.1 name check must pass first), gameplay scenes S01–S23
  (from Step 3).

## 1.0.0 (Step 1: project skeleton) — 20 November 2026
- Project foundation from Ready to Build v4.0, Part 1: Godot 4.7.x
  project, 1280x720 landscape, GL Compatibility renderer, full input
  map, folder tree for all 23 scenes, .gitignore/.gitattributes (B-19),
  placeholder icon, documentation registers.
- Deliberately NOT in Step 1: Android export presets and package ID
  (Gate 0.1 name check must pass first), autoloads, scenes, scripts,
  art and data — those arrive in Step 2 and Slice A.
- Package ID is NOT created yet. The provisional value discussed in
  the blueprint (com.devflowia.viceworld) must NOT be used until the
  final title is decided.

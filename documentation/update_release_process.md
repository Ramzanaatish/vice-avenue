# Vice Avenue — Update & Release Process (Play Store)

How a new version reaches players as an IN-PLACE UPDATE — no
uninstall, no reinstall, no lost progress.

## The four rules (all must hold, every release)

1. **Same package ID forever.** `com.devflowia.viceavenue`
   (DECIDED 21 Nov 2026, Gate 0.1). Changeable only BEFORE the
   first Play upload. After publication it can NEVER change —
   Play would treat it as a different app.
2. **Same signing key.** Play App Signing is required for new
   apps: Google holds the app signing key; you keep the UPLOAD
   key safe (two backups, never in Git, never shared). Losing
   the upload key means a long recovery process.
3. **Version code always increases.** Every accepted release:
   `version/code` +1 in `export_presets.cfg` AND
   `VersionManager.VERSION_CODE`, `version/name` bumped.
   Same/lower version code = rejected by Play.
4. **Save migration.** Every save carries `schema_version`.
   When the schema changes, add a migration step in
   `SaveManager.register_migration()` + a unit test with a
   sample save from the old version. Never overwrite the only
   copy before a successful migration.

## Release workflow (one release at a time)

1. Back up the project. Create a Git tag (`v1.0.1`).
2. Bump version name + version code (both places above).
3. Run the self-test: `godot --headless -s tests/test_save_manager.gd`
4. Test old-save compatibility (load a save from the previous
   public version; migration must succeed; failed migration
   must restore the previous save).
5. Build the signed AAB (preset "Android (Release AAB)").
6. Verify signing + version code (higher than the last release).
7. Internal / closed testing track first (new personal accounts:
   closed test with 12+ testers for 14 days before production).
8. Check the baseline low-end device + a high-end device.
9. Review crashes/ANRs (Play Console vitals).
10. Staged rollout (e.g. 10% -> 50% -> 100%).
11. Monitor; prepare a corrective release if needed.

## Update acceptance checklist

- [ ] Application ID unchanged.
- [ ] Version code higher than the previous release.
- [ ] Signed with the same upload key.
- [ ] A save from the previous public version migrates OK.
- [ ] Failed migration preserves/restores the previous save.
- [ ] Offline gameplay still launches and works.
- [ ] New content loads; missing optional content never crashes.
- [ ] Release notes, privacy disclosures and Play Console
      declarations reviewed.

## Version table (add one row per release)

| Version name | Version code | Save schema | Notes |
|---|---|---|---|
| 1.0.0 | 1 | 1 | First release (skeleton) |

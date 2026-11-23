# Vice Avenue — Performance Budget

Starting points only (Part 4 of the blueprint). Real caps are filled
in AFTER Phase 2 profiling on the baseline device (B-18). Do not
invent final numbers earlier.

## Targets

- Baseline (low-end): 1280x720 (HD), 30 FPS stable. This is the
  PASS/FAIL target for every phase (Android Gates, Part 7).
- Mid-range: 1280x720 or 1920x1080, 30–60 FPS.
- High-end: 1920x1080 (Full HD), up to 60 FPS.
- Dynamic resolution scaling is allowed as a fallback if the baseline
  cannot hold 30 FPS (reduce render scale in steps, never below
  0.75x, and record it in the decision log).

## Budgets (starting points — validate in Phase 2 profiling)

| Item | Starting budget | Measured (Phase 2) |
|------|-----------------|---------------------|
| Player / main characters | 1024x1024 max (one atlas per character) | TBD |
| Vehicles | 1024x1024 max (one atlas per vehicle class) | TBD |
| Buildings | 1024x1024 atlases, shared across the district kit | TBD |
| Props (crates, signs, furniture) | 256x256 to 512x512 | TBD |
| Terrain/ground tiles | 1024x1024 | TBD |
| UI/icons | 512x512 max; HUD icons 128x128 | TBD |
| Player character | ~5,000 triangles (LOD0); NPC: ~3,000 | TBD |
| Car | ~8,000 triangles (LOD0); building module: 500–2,000 | TBD |
| FPS / draw calls / memory caps | TBD after profiling | TBD |

## Rules

- Every large/repeated asset has LOD0 + LOD1 + impostor (or culled)
  variants. LOD distances are set per asset class in data files,
  not guessed per asset.
- Collision meshes are ALWAYS separate, simple shapes (boxes,
  capsules, convex hulls) — never the visual mesh.
- No texture may be added without a size reason recorded in the
  asset license register.

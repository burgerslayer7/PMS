# Changelog

## 0.1.0 — 2026-08-28

- Added a clean-room Mod API v2 mount core for Gen1 and Gen2.
- Added authoritative mount states, battle suspension, map transition recovery,
  checkpoint cleanup and namespaced save restoration.
- Added 40 data-driven species covering 17 Ground, 9 Surf and 16 Flight entries.
- Added native Ground Ride, native Visible Surf entry/exit and altitude-based
  Flight collision with guarded takeoff/landing.
- Bundled and validated PokéPC walker sheets for National Dex 001–251, plus
  nearest-neighbour 2×/3×/4× mount sheets and source provenance.
- Added variable-size native 2D actor rendering and rider/surf presentation.
- Added capability-ranked renderer fallback and public provider registration.
- Added Voxel Companion API v1 observation for Battle Art and Dramaless without
  camera or pipeline takeover.
- Added public Stadium/Stadium 2 tag-provider integration with per-species
  fallback.
- Added cooperative Wild Skies flight markers and non-destructive follower
  render ownership.
- Added settings, structured logging and optional debug HUD.
- Added Lua contract tests, manifest/asset gates, official Gen1/Gen2 loader
  checks, reproducible launcher ZIP validation and CI.

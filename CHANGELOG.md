# Changelog

## Unreleased

- Added a dedicated PotatoVoxel Gen1/Gen2 capability adapter without importing
  its internal modules or taking camera/world ownership.
- Reused the selected Wilds/PokeMMO sprite in voxel mode instead of forcing the
  bundled fallback. Classic art is mapped to Pokédex-sized geometry; true-size
  art keeps its authored frame dimensions.
- Exposed Flight altitude through the PMS actor's canonical pose so
  PotatoVoxel renders real vertical separation from terrain.
- Added a voxel rider pose/texture proxy: the trainer shares mount altitude,
  is seated at the species-aware anchor and no longer renders standing legs.
- Explicitly removed Gen2-3D-Sprites / Stadium 2 discovery and tagging from the
  supported runtime while retaining the frozen Gen1 Stadium adapter.
- Added joint PotatoVoxel + PMS loader tests on Gen1 and Gen2. The automated
  gate now covers 82 Lua tests plus both standalone and paired engine loaders.

- Added a shared START → MOUNTS screen on Gen1 and Gen2 with remembered
  Ground/Surf/Flight candidates, explicit dismount, current status and
  progression-aware failure messages.
- Added Simple/Advanced settings and working controls for shortcuts, sprint,
  seated rider visibility, Flight shadow, two-way ledges, momentum, vertical
  speed and Wild Skies air encounters.
- Added global Small/Pokédex/Large mount sizing and clamped per-Dex overrides.
  The multiplier composes with builtin and external provider geometry and
  moves the rider seat with the resized silhouette.
- Added bounded data-driven launch, acceleration, braking, turn response,
  boost and vertical-speed profiles while retaining each species' existing
  ×0.8–×2.0 base speed and held-B ×2 boost.
- Centralized environment, interaction and map-transition policies. Scripted
  Flight transitions into an indoor destination now dismount cleanly, while
  outdoor connections and reloads keep their existing transaction.
- Integrated exact Wild Skies flyer interception through public `takeFlyer`
  and `mod.world:queueScript`, including Double Battles organic tagging.
- Added public `currentMount()` plus PMS takeoff/landed lifecycle events.
- Return follower ownership through Followers EX/Wilds `syncTrailers` when
  available, without changing provider settings or saved follower state.
- Capture a plain camera yaw from Battle Art/Dramaless Voxel Companion frames
  as the safe foundation for future camera-relative movement. No host camera
  or movement pipeline is modified.
- Added a public-only Crystal 251 capability probe. It reports revision,
  fingerprint and 251-species availability for injected Gen1 content without
  treating Crystal 251 as the native Gen2 runtime or consuming battle internals.

- Added a bounded presentation-recovery window after map entry, map reload,
  battle resume and renderer changes. Temporary actor creation failures now
  return from the invisible fallback without requiring a mod reload.
- Rebuild follower ownership on each live map and handle `map.reloaded`
  independently from the normal exit/enter transaction.
- Keep the complete player sprite visible while only the technical invisible
  render fallback is available.
- Added a machine-readable integration scope and CI/package enforcement:
  Open Sky is excluded and Stadium remains maintenance-only.
- Added stable mount identity across level gains and party reordering, with
  compatibility for `v0.1.6` fingerprints and safe rejection of fainted,
  evolved or removed Pokémon.
- Persist Ground, Surf and Flight shortcut choices independently in the new
  `mount_state_v2` record while retaining one-way reads of `mount_session_v1`.
- Delay battle remount until free-roam is actually restored; a blackout, map
  transition, eligibility loss or eight-second timeout now dismounts safely.
- Expanded the automated gate to 77 Lua tests / 1,022 assertions.

## 0.1.6 — 2026-08-29

- Neutralized Gen2 ground-tile direction instructions during Flight, so Gold
  and Silver door tiles no longer turn an airborne mount back toward their
  entrance while normal connected-map seams remain engine-owned.
- Applied native-2D Flight elevation at draw time on Gen1, keeping the mount
  and rider visibly above the world even when the Gen1 actor update rebuilds
  its logical pixel position.
- Replaced the engine's eight-pixel rider crop with a reversible twelve-pixel
  mounted crop in both generations, showing the shoulders and torso overlapping
  the Pokémon as a seated rider instead of displaying only the head.
- Expanded the automated gate to 52 Lua tests / 642 assertions, including
  generation-specific altitude, door-direction isolation and crop restoration.

## 0.1.5 — 2026-08-29

- Blocked the engine's direct door-warp authority while airborne, so crossing
  a building entrance no longer turns or warps the rider; native connected-map
  seams remain available.
- Scaled classic 16×16 Wilds-selected mount sheets to PMS' Pokédex-relative
  target while preserving the native geometry of True Size PokeMMO/PMD art.
- Derived external-art rider seating from each sheet's frame height and anchor,
  and update the live pose when Wilds changes style at runtime.
- Disabled ground-layer sprite clipping for airborne native-2D mounts so high
  grass never cuts the flying silhouette.
- Added one-press Ground ↔ Flight mount exchange with remembered selections,
  clear-tile validation and atomic rollback if the target controller refuses.
- Expanded the automated gate to 52 Lua tests / 626 assertions and validated
  PMS with Wilds of Kanto 2.2.0 on both official generation loaders.

## 0.1.4 — 2026-08-29

- Suppressed native grass/water encounter rolls and Wilds of Kanto ground
  contacts throughout takeoff, Flight and landing; Wild Skies keeps sole
  authority over genuine airborne encounters.
- Restored Gen1 connected-map crossings in Flight by bypassing only the
  destination ground-tile predicate during the engine's native connection
  transaction; coordinates, camera, music and lifecycle remain engine-owned.
- Completed 42 explicit mode-specific speed profiles across Ground, Surf and
  Flight, all uniquely valued per mode from x0.8 to x2.0; held-B sprint still
  doubles the resulting species cadence.
- Added **MOUNT SPRITES** selection: automatic provider choice, forced bundled
  PMS art, or the current Wilds of Kanto style. The Wilds path follows runtime
  PokeMMO/PMD/Pokédex style changes through its public sprite resolver.
- Expanded the automated gate to 50 Lua tests / 587 assertions.

## 0.1.3 — 2026-08-29

- Raised native-2D Flight to altitude 0.85 with a 0.78 floor and up to 40
  pixels of visual elevation; the rider now sits centrally on the mount.
- Made Flight use a separate airspace collision layer: terrain, buildings,
  doors and NPC entities no longer block movement, while map bounds and seams
  remain controlled by the engine.
- Suppressed door/stair warps, A-button ground interactions and trainer sight
  while airborne, restoring every native handler on landing or cleanup.
- Added unique data-driven Ground and Flight speed profiles for all 33 species;
  held-B sprint doubles the active species speed.
- Synchronized the mount actor with Gen1 and Gen2 native ledge-jump arcs so the
  rider no longer detaches vertically from the Pokémon.
- Added direct Flight ↔ Surf transfer on water through `H` / controller `X`,
  reusing the last valid mount selected for each mode.
- Expanded the automated gate to 46 Lua tests / 453 assertions.

## 0.1.2 — 2026-08-29

- Fixed a build/runtime size drift that made one rendered frame straddle two
  rows of a mount sheet and visibly split Pokémon into detached pieces.
- Made the generated mount sheets and runtime renderer read the exact same
  Pokédex-scale constants, with validation for all 40 mount species.
- Continuously suppress the native Surf blob when either engine reapplies it
  during Surf transitions, map changes or battle recovery.
- Raised stable Flight takeoff to altitude 0.55, enforced a 0.42 minimum and
  made every stable Flight altitude clear solid terrain/building tiles.
- Moved reverse ledge traversal to the collision-refusal path and corrected
  the Gen2 landing-side collision lookup.
- Expanded the automated gate to 41 Lua tests / 266 assertions.

## 0.1.1 — 2026-08-28

- Replaced coarse per-mode 2×/3×/4× sprite tiers with exact mount sheets
  generated from canonical Pokédex heights for all 40 mount species.
- Added a bounded size curve and directional rider poses so large serpentine
  mounts remain readable without filling the screen.
- Cropped the rider's lower half and applied species-aware seat offsets in
  Ground Ride, Visible Surf and native 2D Flight.
- Fixed the Gen1/Yellow Surf rider-sheet replacement and restoration path.
- Made native 2D altitude visible through up to 24 pixels of vertical lift and
  a dynamic ground shadow; takeoff now starts low so altitude remains
  controllable instead of immediately reaching the ceiling.
- Added held-B sprint to Ground Ride, Visible Surf and Flight.
- Added `H`/controller `X` Flight and `G`/`J`/controller `Y` Ground Ride
  shortcuts, plus `Page Up`/`Page Down` and `R2`/`L2` altitude controls.
- Added guarded reverse traversal for official ledges in Gen1 and Gen2 while
  preserving solid-wall, entity, water and invalid-landing collision.
- Made shortcuts skip compatible party species that do not satisfy active
  move/badge progression rules.
- Expanded the automated gate to 38 Lua tests / 245 assertions and added a
  documented post-audit remaining-work inventory.

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

# Remaining work after the v0.2.0-beta.2 PotatoVoxel slice

This inventory was refreshed after re-reading the README, changelogs, release
notes, public documentation and backlog from `burgerslayer7/dramatic-sky-ride`
through the latest published tag `v0.2.18` (`723c29b`) and public `main`
(`759f521`), then auditing the complete PMS beta branch.
Dramatic Sky Ride source code was not opened or reused.

Sky Ride `v0.2.18` deliberately restores the pre-sandbox `v0.2.11` runtime.
The documented `v0.2.12`–`v0.2.17` experiments were reviewed separately;
Open Sky was reviewed only as product history and is now explicitly outside
PMS scope.
The ordered clean-room roadmap is in `docs/DEVELOPMENT_PLAN.md`.

## Completed through PMS v0.2.0-beta.2

- dependency-free Gen1/Gen2 Ground Ride, Visible Surf and Flight core;
- 251 bundled PokéPC fallback sheets and 40 validated mount species;
- exact native-2D mount sheets derived from canonical Pokédex heights;
- cropped, species-aware rider seating in all three modes;
- visible elevated native-2D altitude with a dynamic ground shadow;
- held-B sprint in Ground, Surf and Flight;
- keyboard/controller Ground and Flight shortcuts plus direct altitude input;
- guarded two-way traversal of official Gen1/Gen2 low ledges;
- isolated high-altitude Flight above terrain, warps and ground NPCs;
- isolated native/Wilds ground encounters from Wild Skies airborne encounters;
- 42 explicit mode-specific speed profiles with an exact sprint multiplier;
- native Gen1 connected-map crossings while Flight owns the airspace;
- remembered direct Flight/Surf transfers on water;
- party selection, progression, save intent, battle/map lease recovery;
- capability-ranked 2D, voxel-billboard and Stadium tag providers;
- cooperative follower render ownership and Wild Skies flight markers;
- automatic/forced bundled/Wilds-selected mount sprite source policy;
- Pokédex-relative classic Wilds scaling and geometry-derived True Size seats;
- dedicated PotatoVoxel Gen1/Gen2 detection, selected-art reuse, actor-pose
  altitude and cropped voxel rider presentation without renderer internals;
- one-press Ground/Flight exchange with rollback-safe controller handoff;
- bounded visible-actor recovery after map entry/reload, with fresh follower
  ownership per live world and no cropped rider over an invisible fallback;
- stable exact-mount identity across level gains/party reorder, safe fainted or
  removed-mount rejection, and free-roam-gated battle recovery;
- independent persisted Ground/Surf/Flight preferences with v0.1.6 migration;
- 82 headless tests, both official engine loaders, joint PotatoVoxel loaders,
  package validation and CI scripts.

Connected-map transitions remain in the release regression matrix; this beta
retains the Gen1 airborne destination-tile fix and separately blocks direct
building-door warps.

## P0 — real game validation still required

The automated harness can load both engines but cannot replace ROM-backed play
tests. Before declaring the corrected presentation stable, run the beta
cards in `docs/TESTING.md` for:

1. Arcanine Ground and reverse ledges in Red and Gold;
2. Lapras and Gyarados Surf in Red/Yellow and Gold;
3. Charizard Flight altitude/landing in Red;
4. Ho-Oh Flight altitude/landing in Gold and Crystal;
5. sprint and raw keyboard/controller shortcuts on both engine generations;
6. battle, save/load and map transition recovery for every mode.

Blue and Silver are the second validation pass after Red/Yellow/Gold/Crystal.

## P1 — gameplay parity still missing

- **True free Flight:** movement still uses the engine's tile-step cadence.
  Continuous sub-tile/analog movement, inertia and renderer-provided
  camera-relative orientation remain to be implemented.
- **Amphibious Suicune:** the catalogue exposes Ground and Surf, but seamless
  land/water Ground Ride is not implemented.
- **Expanded motion profiles:** launch, acceleration, braking, momentum,
  boost, turn response and vertical speed are consumed. Stamina, gallop phases
  and per-species visual motion remain missing.
- **Mount effects:** cries, dust, landing effects, rumble and stamina/altitude
  user HUDs are missing. The current altitude readout exists only in DEBUG HUD.
- **Landing guidance:** clear-land validation exists, but there is no visible
  landing marker.
- **Environment policy:** Ground Ride does not yet mirror every game's native
  bicycle indoor/dungeon allowlist or automatically dismount where required.
- **Story safety:** story/discovery gates, quest-sensitive collision rules and
  a policy for custom maps are not implemented beyond move/badge checks.
- **Interaction lifecycle:** airborne ground interaction is isolated, but safe
  automatic dismount around incompatible field moves, PC/item use, scripted
  warps and special actions still needs a broader policy and tests.

## P2 — presentation and provider work still missing

Stadium is deliberately frozen at the existing best-effort `tag`/`untag`
adapter. Model motion, import/cache, saddle, animation and renderer expansion
are not backlog items. Only fallback, cleanup and regression maintenance remain.

- **Voxel movement contract:** Battle Art/Dramaless frame detection and the
  PotatoVoxel Gen1/Gen2 presentation adapter work, but camera-relative free
  movement and explicit roof/terrain elevation capabilities are not consumed.
- **First-person presentation:** PMS does not yet negotiate hiding rider/mount
  in first person or apply dedicated third-person seating offsets.
- **Additional external 2D providers:** Wilds-selected/PokeMMO art is supported;
  direct Followers EX and standalone PokéPC runtime selection remain missing.
- **High-detail calibration:** Wilds variable-size sheets are accepted, but
  morphology-aware padding and provider-specific rider offsets remain missing.
- **Rider providers:** alternate player/rider mods such as OTF Player Switcher
  need explicit capability tests and per-provider poses.
- **High-detail size calibration UI:** global and per-Dex multipliers now
  compose with Pokédex sizing; a visual per-provider/per-species editor remains
  absent.

## P3 — ecosystem and UX work still missing

- landing marker, Visible Surf policy, progression sub-policies and per-species
  size overrides beyond the new Simple/Advanced runtime settings;
- Wild Skies sprite-source registration when a genuinely airborne PMS art
  provider exists; exact interception and flyer consumption are implemented;
- capability-based mounted-art selection for Followers EX beyond public
  `syncTrailers` ownership restoration and the Wilds resolver path;
- validation ROM de Crystal 251 lorsque du contenu Gen2 est injecté dans Gen1
  (la détection publique et les diagnostics sont intégrés) ;
- optional flying music, hints and contextual diagnostics;
- dedicated compatibility, settings and installation reference pages beyond
  the current README/provider/testing documentation.

## Explicitly outside scope

- **Open Sky:** regional navigation, aerial maps, landmarks and related assets
  are abandoned for PMS and have no planned milestone.
- **Stadium expansion:** the current compatibility adapter is retained, but no
  new Stadium renderer, motion system or model pipeline will be developed.
- **Gen2-3D-Sprites / Stadium 2:** unsupported. PMS does not probe, tag or
  adapt itself to that runtime.

## Hardening backlog

- ROM-backed regression coverage for doors, caves, stairs, teleports, scripted
  warps, losses, evolution and save reloads;
- Gen2 reverse-ledge tests on authored maps and big-object collision cases;
- provider-stack tests with real Battle Art, Dramaless, PotatoVoxel, Wilds,
  Followers EX, Wild Skies and Crystal 251 releases, plus one smoke test for
  the frozen Gen1 Stadium adapter;
- hot-reload stress tests after repeated enable/disable cycles;
- profiling of actor/provider update paths in large mod stacks;
- accessibility/handheld verification of all raw shortcuts and trigger names.

The next useful implementation slice is P0 runtime validation on
Red/Yellow/Gold/Crystal followed by post-battle identity/eligibility and map
lifecycle hardening. Those have the highest gameplay impact without coupling
PMS to a renderer.

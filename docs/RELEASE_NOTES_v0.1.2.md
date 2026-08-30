# Pokémon Mount System v0.1.2

This hotfix addresses the four remaining native-2D issues found during the
v0.1.1 in-game validation.

## Fixed

- Pokémon are no longer split between two animation rows: generated PNGs and
  runtime frame declarations now share the same Pokédex-scale constants;
- the game's generic Surf mount is continuously suppressed while PMS owns the
  visible mount, including delayed transitions and map/battle recovery;
- stable Flight starts at altitude 0.55, cannot descend below 0.42 and clears
  solid terrain/building tiles at every stable altitude;
- reverse traversal of official ledges is triggered by the refused collision,
  with the correct landing-side lookup in Gen2.

Sprint behaviour is unchanged from v0.1.1.

## Upgrade

Import `pokemon-mount-system-v0.1.2.zip` through **MODS → Import mod .zip**.
The distinct version number prevents the launcher from retaining cached
v0.1.1 files. No companion mod is required.

Use the short native-2D cards in `docs/TESTING.md` and test PMS alone first.

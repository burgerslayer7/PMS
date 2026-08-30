# Pokémon Mount System v0.1.1

This corrective release focuses on the native-2D Ground, Surf and Flight
presentation reported against v0.1.0.

## Fixed

- mount sizes now come from canonical Pokédex heights instead of coarse
  2×/3×/4× mode buckets;
- Gyarados and other long-bodied species remain the largest mounts without
  covering the viewport;
- mounted riders show only their seated upper half and follow species-specific
  seat offsets;
- Gen1 and Yellow Visible Surf restore the correct rider sheet;
- Flight starts at a low altitude, can visibly rise up to 24 pixels, and keeps
  a dynamic shadow on the ground;
- official low ledges can be traversed safely in both directions while mounted.

## Controls added

- Flight: keyboard `H`, controller `X`;
- Ground Ride: keyboard `G` (`J` with Dramaless), controller `Y`;
- altitude: `Page Up` / `Page Down`, controller `R2` / `L2`;
- sprint in all mount modes: hold the Game Boy B input (keyboard `X` by
  default, controller `B`).

The original party-menu actions and portable `SELECT` chords remain available.

## Upgrade

Import `pokemon-mount-system-v0.1.1.zip` through **MODS → Import mod .zip**.
The archive replaces v0.1.0 and requires no companion mod.

Use the short v0.1.1 card in `docs/TESTING.md` for Arcanine, Lapras, Gyarados,
Charizard and Ho-Oh. The audited post-release backlog is in
`docs/REMAINING.md`.

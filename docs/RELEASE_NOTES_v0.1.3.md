# Pokémon Mount System v0.1.3

This release turns Flight into a true high airspace layer and adds the first
seamless mode transfer.

## Flight

- default altitude is 0.85 with a 0.78 minimum and up to 40 pixels of native-2D
  elevation;
- terrain, buildings, doors and NPC entities no longer block airborne steps;
- door/stair warps, A-button interactions and trainer sight are suppressed in
  air and restored on landing;
- the rider sits lower and more centrally on the flying Pokémon;
- all 16 flying species have a unique speed, then B doubles it.

## Ground and water

- all 17 Ground species have a unique speed and a ×2 B sprint;
- mount and rider now share the same native ledge-jump arc;
- above water, `H` / controller `X` transfers Flight to the last Surf mount;
- the same shortcut transfers Surf back to the last Flight mount.

## Upgrade

Import `pokemon-mount-system-v0.1.3.zip` through **MODS → Import mod .zip**.
Test with PMS alone first; no companion mod is required.

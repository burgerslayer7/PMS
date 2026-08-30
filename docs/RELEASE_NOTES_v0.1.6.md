# Pokémon Mount System v0.1.6

This native-2D correction release addresses the remaining Gold door behavior,
Gen1 Flight elevation and rider seating reported during the v0.1.5 field test.

## Fixed

- **Gold/Gen2 airborne doors:** door collision metadata can no longer force an
  airborne rider to turn back after PMS vetoes the door warp. Ground currents,
  ice and other tile-authored directions are isolated by the same flight-only
  rule and return immediately after landing.
- **Gen1 visible altitude:** the mount's vertical lift is now applied in its
  draw wrapper. This prevents Gen1's actor update from visually putting the
  Pokémon back on the ground while the rider remains elevated.
- **Seated rider silhouette:** mounted trainers now retain the upper 12 pixels
  of each 16-pixel frame instead of the engine's stock 8-pixel half frame. The
  torso overlaps the mount, making the pose read as seated in Gen1 and Gen2.

Surf presentation, species-specific speed profiles, sprint, reverse ledges,
direct mode switching and Gen1 door behavior are unchanged.

## Focused field test

1. In Pokémon Gold, fly repeatedly across a building door without landing.
   The rider must keep the requested direction and must not enter the building.
2. In Pokémon Red or Yellow, take off with Charizard and compare the mount with
   its ground shadow. Both rider and mount must remain visibly elevated.
3. In both games, inspect Ground, Surf and Flight while facing all four
   directions. The head, shoulders and torso must be visible over the Pokémon;
   the legs must remain hidden inside it.
4. Land, dismount and enter the same door normally. Native door movement and
   warp behavior must be fully restored.

Import `pokemon-mount-system-v0.1.6.zip` through **MODS -> Import mod .zip**.

# Pokémon Mount System v0.1.4

This test build separates high-altitude Flight from every ground encounter,
restores Gen1 connected-map seams and lets native-2D mounts follow Wilds of
Kanto's selected art.

## Flight authority

- high grass, water and other native encounter rolls are disabled during
  takeoff, Flight and landing;
- visible Wilds ground/water Pokémon cannot start a contact battle in air;
- genuine Wild Skies airborne Pokémon keep their normal encounters;
- Gen1 route/town connections now use the native transition while ignoring
  only the destination's ground-tile passability test.

## Mount identity

- all 42 Ground/Surf/Flight mode entries have an explicit unique base speed
  within their mode, from x0.8 to x2.0;
- held-B sprint doubles that species/mode speed;
- **MOUNT SPRITES** adds Auto, PMS Builtin and Wilds Selected choices;
- the Wilds choice uses its public resolver and follows PokeMMO or other
  selected style changes while mounted.

## Upgrade

Import `pokemon-mount-system-v0.1.4.zip` through **MODS -> Import mod .zip**.
No optional mod is required; use Wilds of Kanto 2.2.0 or newer only for its
selected sprite path.

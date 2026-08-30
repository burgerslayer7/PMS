# Pokémon Mount System v0.1.5

This test build fixes airborne doors, calibrates Wilds-selected 2D art and
removes the extra input between Ground Ride and Flight.

## Flight

- building doors, scripted ground interactions and ground sprite clipping stay
  inactive while airborne;
- native route/town connections remain engine-owned and available;
- flying mounts keep their complete silhouette above tall grass.

## Wilds-selected sprites

- classic 16×16 GSC/follower art is scaled to the same Pokédex-relative target
  used by PMS' bundled sheets;
- PokeMMO, PMD and other True Size sheets retain their authored dimensions;
- rider height is computed from the resolved external frame and anchor, and is
  refreshed when Wilds changes style during play.

## Direct mount exchange

- press the Flight shortcut while on a Ground mount to take off immediately;
- press the Ground shortcut while flying to switch immediately on a clear land
  tile;
- the last eligible Ground and Flight Pokémon are reused, with safe rollback if
  the destination controller refuses the switch.

## Upgrade

Import `pokemon-mount-system-v0.1.5.zip` through **MODS -> Import mod .zip**.
No optional mod is required. Wilds of Kanto 2.2.0 or newer is recommended when
using **AUTO** or **WILDS SELECTED** mount sprites.

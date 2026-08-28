# Testing Pokémon Mount System 0.1.0

## Automated checks

Run from the repository root:

```bash
LUA_BIN=luajit tools/test.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp LUA_BIN=luajit tools/test_engine.sh
```

The first command runs Lua contracts and validates the manifest, 251 source
walker sheets and 120 generated mount sheets. The second mounts PMS into a
Gen1Recomp++ checkout and loads it through the official modkit in both Gen1 and
Gen2 mode.

Build the exact launcher archive only from a clean commit:

```bash
tools/package.sh dist
```

## Before every runtime card

- Gen1Recomp++: 0.2.32 or newer.
- Enable PMS; disable all optional graphics mods unless the card names one.
- Enable **DEBUG HUD** in PMS settings.
- Keep **PROGRESSION** on for ordinary tests; a test may explicitly turn it
  off to avoid preparing moves/badges.
- Capture the complete console section beginning with `[PMS]` if a card fails.

## M3-A — Arcanine Ground / Red

**Mods:** PMS only  
**Game:** Pokémon Red  
**Place:** any outdoor route or town  
**Preparation:** Arcanine in the party; progression setting does not matter

1. Open the party menu and select Arcanine.
2. Choose **MOUNT**, then **GROUND RIDE** if a chooser appears.
3. Move in all four directions and into a solid wall/NPC.
4. Cross a route/town seam.
5. Enter and leave a building.
6. Start a wild battle, finish it, then dismount from the party menu.

Expected: one Arcanine silhouette under the player, faster native steps, native
wall/NPC collision, no duplicate follower, one remount after battle, no stale
actor after the seam or dismount.

## M3-B — Arcanine Ground / Gold or Crystal

Repeat M3-A in Gold, then Crystal. Expected behaviour is identical. Crystal is
experimental; include game version, map id and the full PMS log with any issue.

## M4-A — Lapras Visible Surf / Red

**Mods:** PMS only  
**Game:** Pokémon Red or Yellow  
**Place:** a shore with accessible water  
**Preparation:** Lapras knows SURF; Soul Badge earned, or PROGRESSION off

1. Stand on land facing water.
2. Select Lapras → **MOUNT** → **VISIBLE SURF**.
3. Move and turn in all directions on water.
4. Trigger a water encounter and finish it.
5. Cross a water route seam.
6. Move onto dry land; verify PMS dismounts when native Surf ends.

Expected: Lapras is visible beneath the normal rider, the generic Surf blob is
not visible, collision remains native, and exactly one Lapras returns after the
battle/seam.

## M4-B — Lapras Visible Surf / Gold

Repeat M4-A with the Fog Badge. Gen2 may require leaving Surf by moving onto
shore rather than selecting DISMOUNT while still in open water.

## M5-A — Charizard Flight / Red

**Mods:** PMS only  
**Game:** Pokémon Red  
**Place:** an open outdoor route  
**Preparation:** Charizard knows FLY; Thunder Badge earned, or PROGRESSION off

1. Select Charizard → **MOUNT** → **FLIGHT**.
2. Wait for takeoff, then hold **SELECT+DOWN** and **SELECT+UP**.
3. At medium/high altitude cross ordinary solid terrain.
4. Confirm NPC/entity and hard map-boundary collision still blocks movement.
5. Confirm a door/warp cannot be entered while airborne.
6. Move over clear land and press **SELECT+B**.
7. Start a battle during a second flight and verify stable remount afterward.

Expected: altitude changes continuously, terrain collision relaxes only above
the low band, doors remain guarded, landing works only over clear land, player
and mount remain visible.

## M6-A — Ho-Oh Flight / Gold

Repeat M5-A in Gold with Ho-Oh (Fly + Storm Badge, or PROGRESSION off). Expected:
the 4× fallback sheet loads, no Gen1-only API error appears, and provider/debug
fields show generation 2.

## Provider cards

Run M5-A once for each stack:

| Card | Mods | Expected provider/debug result |
| --- | --- | --- |
| P-2D | PMS only | `builtin_pokepc_2d`, `native2d` |
| P-BA | PMS + Battle Art | voxel mode ON → `voxel_mount_billboard` unless Stadium wins |
| P-DL | PMS + Dramaless | voxel mode ON → `voxel_mount_billboard` unless Stadium wins |
| P-S1 | PMS + Dramatic Shape + Stadium Gen1 | imported model → `stadium_models`; missing model falls back |
| P-S2 | PMS + Stadium 2 on Gold | 3D world ON → `stadium_models`; 2D world → bundled 2D |
| P-W | PMS + Wilds/Followers EX | selected matching follower hidden only while mounted |
| P-WS | PMS + Wild Skies | flyers continue; PMS flight marker visible; no ground bump while airborne |
| P-C251 | PMS + Crystal 251 on Gen1 | Gen2 party mount resolves without mandatory dependency |

For every provider card, toggle its renderer off and on while mounted. Expected:
PMS swaps leases once, leaves the camera intact and returns to bundled 2D when
the external renderer is inactive.

## Failure report checklist

Include:

1. Gen1Recomp++ version and game/version.
2. PMS version and every enabled mod/version.
3. Map id and exact action sequence.
4. Debug HUD state/provider/altitude/collision line.
5. Console lines containing `[PMS]` plus the first stack trace.
6. Save made before the failing action when reproduction depends on progress.

# Testing Pokémon Mount System 0.2.0-beta.2

## Automated checks

Run from the repository root:

```bash
LUA_BIN=luajit tools/test.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp LUA_BIN=luajit tools/test_engine.sh
```

The first command runs 76 Lua contracts / 1,010 assertions and validates the
manifest, 251 source walker sheets, 120 legacy scaled sheets and 40 exact
Pokédex-sized mount sheets. It also enforces the machine-readable integration
scope: Open Sky stays excluded and Stadium stays maintenance-only. The second mounts PMS into a
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
3. Dismount, press **G** (or controller **Y**) and verify Arcanine is selected.
4. Move normally, then hold keyboard **X** / controller **B** to sprint.
5. Approach an official low ledge from each side and traverse it both ways.
6. Confirm rider and Arcanine follow the same jump arc without separating.
7. Compare briefly with Rhyhorn and Raikou; each must have a different normal
   cadence and B must approximately halve its step duration.
8. Move in all four directions and into a solid wall/NPC.
9. Cross a route/town seam, then enter and leave a building.
10. Start a wild battle, finish it, then press **G/Y** to dismount.

Expected: one Arcanine silhouette under the player, faster native steps, native
wall/NPC collision, reverse traversal only on real ledges with clear landings,
no duplicate follower, one remount after battle, no stale actor after the seam
or dismount.

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
4. Hold keyboard **X** / controller **B** and verify Surf accelerates.
5. Trigger a water encounter and finish it.
6. Cross a water route seam.
7. Move onto dry land; verify PMS dismounts when native Surf ends.

Expected: Lapras is visible beneath the normal rider, the generic Surf blob is
not visible, only the rider's upper half is drawn, collision remains native,
and exactly one Lapras returns after the battle/seam.

## M4-B — Lapras Visible Surf / Gold

Repeat M4-A with the Fog Badge. Gen2 may require leaving Surf by moving onto
shore rather than selecting DISMOUNT while still in open water.

## M5-A — Charizard Flight / Red

**Mods:** PMS only  
**Game:** Pokémon Red  
**Place:** an open outdoor route  
**Preparation:** Charizard knows FLY; Thunder Badge earned, or PROGRESSION off

1. Press keyboard **H** / controller **X** and verify Charizard is selected.
2. Wait for takeoff to altitude 0.85, then hold **Page Down/Page Up** or
   **L2/R2**.
3. Verify mount and cropped rider visibly rise together while the shadow stays
   on the ground and changes size/opacity.
4. Move normally, then hold keyboard **X** / controller **B** to sprint.
5. At minimum stable altitude, cross buildings and ordinary solid terrain.
6. Cross directly through NPCs and press A while facing one: no collision,
   dialogue, trainer sight or battle may trigger.
7. Fly repeatedly over high grass and water: no native encounter may start.
8. Cross a door/warp tile without entering it, then cross a normal route/town
   connection: the warp must stay inactive and the connected map must load.
9. Compare briefly with Noctowl and Aerodactyl; their normal and sprint
   cadences must differ.
10. Fly above water and press **H/X**: the last Surf mount must appear directly.
11. Press **H/X** again while surfing: the last Flight mount must take off.
12. Over clear land, press **G/Y** once: the last Ground mount must replace
    Charizard immediately, without a separate landing input.
13. Press **H/X** once: Charizard must replace the Ground mount and take off.
14. Move over clear land and press **H/X** again to land normally.

Expected: altitude changes continuously without dropping below 0.78 in stable
Flight, ground collision/interactions/encounters remain inactive, warp tiles
are crossed without entry, connected maps load, water transfers reuse the
remembered mounts, the rider remains centred, and sprint doubles each
species-specific cadence.

## M6-A — Ho-Oh Flight / Gold

Repeat M5-A in Gold with Ho-Oh (Fly + Storm Badge, or PROGRESSION off). Expected:
the 31-pixel Pokédex-sized fallback frames load, no Gen1-only API error appears,
and provider/debug fields show generation 2.

## V0.1.6 visual regression card

Use PMS alone in native 2D and capture one stationary and one moving frame for
each row. Logical frame dimensions are listed before game zoom is applied.

| Mount | Expected frame | Visual checks |
| --- | ---: | --- |
| Arcanine / Ground | 22×22 | compact silhouette, upper-half rider, no standing legs through the mount |
| Lapras / Surf | 25×25 | no generic Surf blob, readable seat, no duplicate rider |
| Gyarados / Surf | 40×40 | largest validation mount but no 64×64 viewport-filling sheet |
| Charizard / Flight | 21×21 | 31–40 px altitude lift, ground shadow, centred rider and mount move together |
| Ho-Oh / Flight | 31×31 | larger than Charizard through Pokédex height, still within the 40 px cap |

## Provider cards

Run M5-A once for each stack:

| Card | Mods | Expected provider/debug result |
| --- | --- | --- |
| P-2D | PMS only | `builtin_pokepc_2d`, `native2d` |
| P-BA | PMS + Battle Art | voxel mode ON → `voxel_mount_billboard` unless Stadium wins |
| P-DL | PMS + Dramaless | voxel mode ON → `voxel_mount_billboard` unless Stadium wins |
| P-PV1 | PMS + PotatoVoxel on Red/Yellow | `potato_voxel`, Pokédex-sized actor, seated rider, visible Flight height |
| P-PV2 | PMS + PotatoVoxel on Gold/Crystal | same selected art as 2D, stable map/battle restore, visible Flight height |
| P-S1 | PMS + Dramatic Shape + Stadium Gen1 | imported model → `stadium_models`; missing model falls back |
| P-W | PMS + Wilds/Followers EX | selected matching follower hidden only while mounted |
| P-WS | PMS + Wild Skies | flyers continue; PMS flight marker visible; no ground bump while airborne |
| P-C251 | PMS + Crystal 251 on Gen1 | Gen2 party mount resolves without mandatory dependency |

## P-W-Encounter — Wilds and Wild Skies authority

**Mods:** PMS + Wilds of Kanto + Wild Skies

**Game:** Pokémon Red

**Place:** a route with high grass, water, visible Wilds Pokémon and a Wild
Skies airborne Pokémon

1. Enter Flight and move over high grass and water for at least 100 steps.
2. Cross directly through a visible Wilds ground/water Pokémon.
3. Collide with a genuine Wild Skies airborne Pokémon.

Expected: steps 1–2 never start a battle; step 3 starts Wild Skies' normal
airborne encounter. After the battle PMS restores exactly one flight mount.

## P-W-Sprites — automatic and manual mount art

**Mods:** PMS + Wilds of Kanto 2.2.0 or newer

**Renderer:** Native 2D, then PotatoVoxel voxel mode

1. In Wilds, choose the PokeMMO sprite style.
2. Set PMS **MOUNT SPRITES** to **AUTO**, then mount a compatible Pokémon.
3. While mounted, change Wilds to another supported style and wait one second.
4. Set PMS **MOUNT SPRITES** to **PMS BUILTIN**.
5. Set it to **WILDS SELECTED**.

Expected: AUTO follows Wilds' resolved style (including the live change), PMS
BUILTIN uses the bundled PokéPC sheet, and WILDS SELECTED returns to Wilds'
current style. Classic 16×16 art has the same Pokédex-relative scale as PMS'
bundled equivalent; PokeMMO keeps its True Size dimensions with the rider seated
above the body rather than inside it. No follower setting or Wilds selection is
modified by PMS.

## M2 lifecycle and persisted choices

1. Select different valid Ground, Surf and Flight mounts, then save and fully
   restart the game.
2. Use each raw shortcut and confirm the three choices return independently.
3. Start a battle while mounted and let that exact Pokémon gain a level.
4. Start another battle and let the mounted Pokémon faint.
5. Repeat with a loss/blackout that moves the player to a Pokémon Center.

Expected: a level gain and party reorder preserve the exact mount; the rider
returns only after the overworld accepts input. A fainted/removed/evolved mount
or blackout leaves PMS cleanly unmounted, with no actor appearing during the
battle outro or map transfer.

## Beta menu, motion and integration card

1. Open **START → MOUNTS** in Red and Gold. Verify Ground, Surf and Flight show
   the last eligible party species and that DISMOUNT shows the active one.
2. Select Arcanine from a standstill, keep one direction held, then make a
   sharp turn. The first steps and corner response should be perceptible but
   collisions, animation and map seams must remain native.
3. Toggle **SPRINT / BOOST**, **MOUNT SHORTCUTS**, **SHOW RIDER** and
   **FLIGHT SHADOW** one at a time and confirm each affects only its named
   behaviour. Switch SETTINGS VIEW between SIMPLE and ADVANCED.
4. With Wild Skies enabled and AIR ENCOUNTERS on, intercept a visible flyer.
   Confirm the battle species/level match it; turn AIR ENCOUNTERS off and
   confirm no flyer is consumed.
5. With Followers EX enabled, mount the current follower, change maps, then
   dismount. The same follower/pack selection must return without changing the
   configured follower count or control mode.

Expected: no duplicate mount/follower, no inaccessible menu, no ground battle
in Flight, and exactly one Wild Skies battle for one consumed flyer.

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

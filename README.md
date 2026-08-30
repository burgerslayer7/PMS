# Pokémon Mount System

Pokémon Mount System (PMS) adds data-driven Ground Ride, Visible Surf and
Flight mounts to Gen1Recomp++ for Pokémon Red, Blue, Yellow, Gold, Silver and
Crystal.

PMS works by itself. It bundles a 251-species PokéPC walker-sheet fallback, so
PokéPC Followers, Wilds, Followers EX, a voxel mod and Gen1 Stadium models are
all optional.

> Crystal is supported through the native Gen2 runtime but remains marked
> experimental while Crystal support in Gen1Recomp++ is beta.

## Installation

1. Use Gen1Recomp++ 0.2.32 or newer.
2. Download the latest `pokemon-mount-system-*.zip` from this repository's
   Releases (or use the supplied beta test archive).
3. Open **MODS** in the Gen1Recomp++ launcher/game menu.
4. Choose **Import mod .zip**, select the downloaded archive and enable PMS.
5. Restart or reload the game if the launcher requests it.

Do not unpack the ZIP into another folder before importing it. `manifest.json`
is already at the archive root.

## Using a mount

Open **START → MOUNTS** to choose the last valid Ground, Surf or Flight mount,
or use the normal party menu and select **MOUNT** on a specific Pokémon. If
that species supports more than one mode, PMS opens a small mode chooser.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Select remembered mount/mode | START → **MOUNTS** | START → **MOUNTS** |
| Select a specific Pokémon | Party Pokémon → **MOUNT** | Party Pokémon → **MOUNT** |
| Start Flight / switch from Ground / request landing | **H** | **X** |
| Start Ground / switch from Flight / dismount | **G**; **J** while Dramaless is active | **Y** |
| Raise/lower Flight altitude | **Page Up** / **Page Down** | **R2** / **L2** |
| Sprint in Ground, Surf or Flight | Hold **X** (default Game Boy B key) | Hold **B** |
| Portable altitude fallback | Hold **SELECT + UP/DOWN** | Hold **SELECT + D-pad** |
| Portable landing fallback | Press **SELECT + B** over clear land | **SELECT + B** |

While flying above water, **H / controller X** lands directly into Visible
Surf with the last valid Surf mount. Press the same shortcut while surfing to
take off again with the last valid Flight mount. If no previous selection is
available, PMS chooses the first progression-eligible party Pokémon.

Ground Ride and Flight also exchange directly: press the other mode's shortcut
once to switch to its last valid mount. Flight-to-Ground requires a clear land
tile, but no intermediate landing or second button press.

Ground, Surf and Flight remember their last valid mount independently in the
current save, including across a full restart. Each shortcut revalidates the
exact party Pokémon and falls back to the first compatible **and progression-
eligible** member if the saved choice is no longer valid. The same shortcut
requests a dismount/landing when that mode is already active.

By default, Surf and Flight respect the active game's move and badge
progression. **PROGRESSION** can be disabled in PMS settings for sandbox
testing. Flight starts outdoors on land at altitude 0.85 and remains between
0.78 and 1.00. It crosses buildings, solid terrain, doors and ground NPCs
without triggering collision, warp, interaction, trainer sight, native
grass/water encounters or Wilds ground contacts. Wild Skies remains the sole
authority for genuine airborne encounters. Map boundaries and native
connected-map seams remain owned by the engine, including Gen1 connections.

Ground, Surf and Flight cadence is species-specific. All 42 species/mode
entries have an explicit speed from ×0.8 to ×2.0, unique within their mode.
Profiles now also carry bounded launch, acceleration, braking, turn response,
boost and (for Flight) vertical speed. Holding B applies a ×2 boost at full
momentum; the player can disable either momentum or sprint independently.

Native 2D mount frames are generated from each species' canonical Pokédex
height. A bounded square-root curve keeps the relative order while preventing
long-bodied species such as Gyarados and Lugia from covering the viewport.
Mounted riders use a cropped lower half and a species-aware seat offset instead
of drawing a complete standing trainer over the Pokémon.

With **MOUNT SPRITES = AUTO** or **WILDS SELECTED**, classic 16×16 Wilds art is
scaled to the same Pokédex-relative PMS silhouette. Wilds True Size art such as
PokeMMO/PMD keeps its authored geometry, and PMS derives the rider seat from
that sheet's frame and anchor instead of applying a fixed offset.

## Included mount catalogue

PMS currently contains 40 unique species and 42 mode entries.

- Flight: Charizard, Pidgeot, Fearow, Golbat, Aerodactyl, Articuno, Zapdos,
  Moltres, Dragonair, Dragonite, Noctowl, Crobat, Xatu, Skarmory, Lugia, Ho-Oh.
- Ground: Arcanine, Rapidash, Dodrio, Rhyhorn, Rhydon, Kangaskhan, Tauros,
  Snorlax, Meganium, Girafarig, Ursaring, Donphan, Stantler, Raikou, Entei,
  Suicune, Tyranitar.
- Surf: Blastoise, Tentacruel, Gyarados, Lapras, Feraligatr, Mantine, Kingdra,
  Lugia and amphibious Suicune.

## Render providers

Provider selection is per species and mode. A failure never disables mount
gameplay globally.

1. compatible active Gen1 Stadium model provider;
2. active voxel-host billboard (Voxel Companion or PotatoVoxel);
3. Wilds of Kanto's selected style or another registered PMS provider;
4. bundled PokéPC 2D provider;
5. invisible technical safety lease.

Battle Art 1.9.8 and Dramaless Shape 2.0.3 are integrated through their public
Voxel Companion API v1. PMS observes their active render phase but never owns
their camera or world pipeline.

[PotatoVoxel](https://github.com/ShaneMcGovernIE/potato_voxel) has a dedicated
capability adapter for Gen1 and Gen2. PMS detects the engine's active voxel
pipeline, supplies an ordinary actor, transmits Flight height through its
canonical pose and keeps the selected Wilds/PokeMMO art in voxel mode. The
rider receives the same altitude and a temporary cropped seated texture; no
PotatoVoxel camera, terrain or internal module is patched. Large sprite support
requires a PotatoVoxel build containing its
[variable frame-size fix](https://github.com/ShaneMcGovernIE/potato_voxel/pull/69).

Maintained Dramatic Shape forks, Terrarium and similar renderers retain their
best-effort ordinary runtime-actor billboard path.

Pokémon Stadium Overworld Models for Gen1 is detected through its public
`tag`/`untag` API. PMS does not bundle model data; the provider's normal
ROM/model import remains required. This adapter is in maintenance-only mode.
Gen2-3D-Sprites / Stadium 2 is explicitly unsupported: PMS no longer probes,
tags or adapts itself to that runtime.

Open Sky regional navigation is not part of PMS and has been removed from the
development roadmap. This does not affect Wild Skies compatibility, which
remains an active 2D ecosystem integration target.

See [docs/PROVIDERS.md](docs/PROVIDERS.md) for the provider contract.

## Compatibility behaviour

- Wild Skies remains the airborne encounter authority. PMS consumes a nearby
  flyer through its public `takeFlyer` export and queues that exact species and
  level as the battle. Native ground/water rolls and Wilds ground contacts are
  vetoed only while PMS is airborne.
- Wilds of Kanto's public `resolveFollowerSprite` capability can supply the
  active mount art. In **AUTO** or **WILDS SELECTED**, a PokeMMO, PMD,
  Pokédex or other compatible style change is picked up without copying its
  assets or changing its settings.
- Followers EX, Wilds and native followers keep their own selection and trail
  state. PMS temporarily removes only a duplicate follower matching the mount
  species from the draw list, then restores it on dismount. When available,
  it asks Followers EX or Wilds to resync through the public `syncTrailers`
  export without changing leader, pack size or control mode.
- Crystal 251 is optional and can supply Gen2 species to a Gen1 game. PMS
  reports its public dataset revision/fingerprint in integration diagnostics
  but never invokes its battle runtime. Native Gold/Silver/Crystal remains the
  main Gen2 path.
- PokéPC Followers is not a runtime dependency; only attributed numbered art
  sheets are bundled.
- Battle remount waits for the real free-roam state and is cancelled if the
  mounted Pokémon fainted, evolved, left the party or lost its eligibility.

PMS also publishes `currentMount()` plus
`mod.pokemon_mount_system.takeoff` / `.landed` events for cooperative mods.

## Settings and diagnostics

- **PROGRESSION** — require the correct move/badge (default ON)
- **AUTO REMOUNT** — restore after battle (default ON)
- **MOUNT RENDERER** — Auto, Native 2D, Voxel or Gen1 Stadium
- **MOUNT SPRITES** — Auto, forced PMS Builtin, or Wilds Selected
- **GROUND SPEED** — Normal or Fast
- **FLIGHT SPEED** — Normal, Fast or Turbo
- **VERTICAL SPEED** — Gentle, Normal or Fast
- **MOUNT MOMENTUM** — species-profile launch, acceleration and turns
- **SPRINT / BOOST** — held-B ×2 boost
- **MOUNT SHORTCUTS** — raw keyboard/controller Ground and Flight shortcuts
- **SHOW RIDER** — display or hide the seated trainer
- **FLIGHT SHADOW** — native-2D ground-reference shadow
- **GLOBAL MOUNT SIZE** — Small, canonical Pokédex, or Large
- **DEX SIZE OVERRIDES** — optional per-species multipliers such as
  `59=1.1,131=0.9`, clamped to ×0.5–×2
- **TWO-WAY LEDGES** — guarded reverse traversal of authored ledges
- **AIR ENCOUNTERS** — exact nearby Wild Skies flyer battles
- **DEBUG HUD** — state, species, provider, altitude, map/tile and collision

The default **SIMPLE** view shows everyday controls. **ADVANCED** reveals
renderer, sprite source, cadence, vertical movement, sizing, shadow and ledge
tuning. Size multipliers apply after the canonical Pokédex curve and also
adjust the rider seat; they never rewrite another provider's assets.

Logs use stable prefixes such as `[PMS][Mount]`, `[PMS][Provider]` and
`[PMS][Battle]` without per-frame console spam.

## Development and verification

```bash
LUA_BIN=luajit tools/test.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp LUA_BIN=luajit tools/test_engine.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp POTATO_VOXEL_ROOT=/path/to/potato_voxel \
  LUA_BIN=luajit tools/test_potato.sh
tools/package.sh dist
```

The automated gate validates state/provider/gameplay contracts, both engine
loaders, manifest shape, and all 251 fallback PNGs plus generated mount sheets.
Runtime test cards are in [docs/TESTING.md](docs/TESTING.md).

The audited feature gap against Dramatic Sky Ride through v0.2.18 is tracked
in [docs/REMAINING.md](docs/REMAINING.md). The clean-room implementation order
is defined in [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).

## Clean-room notice

PMS is a clean rewrite. No Dramatic Sky Ride source code is included or
ported. Historical README/release behaviour was used only as a functional
reference. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[ATTRIBUTION.md](ATTRIBUTION.md).

Pokémon and related names/art are trademarks and copyrights of their
respective owners. This is an unofficial fan project and includes no ROM.

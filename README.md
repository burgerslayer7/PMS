# Pokémon Mount System

Pokémon Mount System (PMS) adds data-driven Ground Ride, Visible Surf and
Flight mounts to Gen1Recomp++ for Pokémon Red, Blue, Yellow, Gold, Silver and
Crystal.

PMS works by itself. It bundles a 251-species PokéPC walker-sheet fallback, so
PokéPC Followers, Wilds, Followers EX, a voxel mod and Stadium models are all
optional.

> Crystal is supported through the native Gen2 runtime but remains marked
> experimental while Crystal support in Gen1Recomp++ is beta.

## Installation

1. Use Gen1Recomp++ 0.2.32 or newer.
2. Download `pokemon-mount-system-v0.1.0.zip` from this repository's Releases.
3. Open **MODS** in the Gen1Recomp++ launcher/game menu.
4. Choose **Import mod .zip**, select the downloaded archive and enable PMS.
5. Restart or reload the game if the launcher requests it.

Do not unpack the ZIP into another folder before importing it. `manifest.json`
is already at the archive root.

## Using a mount

Open the normal party menu, choose a supported Pokémon, then select **MOUNT**.
If that species supports more than one mode, PMS opens a small mode chooser.

| Action | Control |
| --- | --- |
| Ground/Surf/Flight selection | Party Pokémon → **MOUNT** |
| Raise altitude in Flight | Hold **SELECT + UP** |
| Lower altitude in Flight | Hold **SELECT + DOWN** |
| Land | Press **SELECT + B** over clear land |
| Dismount | Party Pokémon → **MOUNT** → **DISMOUNT** |

By default, Surf and Flight respect the active game's move and badge
progression. **PROGRESSION** can be disabled in PMS settings for sandbox
testing. Flight starts outdoors on land; it cannot land on water, a door or a
warp.

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

1. compatible active Stadium model provider;
2. active Voxel Companion host billboard;
3. externally registered PMS render provider;
4. bundled PokéPC 2D provider;
5. invisible technical safety lease.

Battle Art 1.9.8 and Dramaless Shape 2.0.3 are integrated through their public
Voxel Companion API v1. PMS observes their active render phase but never owns
their camera or world pipeline. Maintained Dramatic Shape forks, Terrarium,
PotatoVoxel and similar renderers can display the ordinary PMS mount actor
through their existing NPC/billboard path.

Pokémon Stadium Overworld Models and Stadium 2 Overworld Models are detected
through their public `tag`/`untag` APIs. PMS does not bundle model data; the
provider's normal ROM/model import remains required.

See [docs/PROVIDERS.md](docs/PROVIDERS.md) for the provider contract.

## Compatibility behaviour

- Wild Skies remains the encounter authority. PMS only publishes flight state
  and the cooperative `freeFlying`/altitude marker Wild Skies already reads.
- Followers EX, Wilds and native followers keep their own selection and trail
  state. PMS temporarily removes only a duplicate follower matching the mount
  species from the draw list, then restores it on dismount.
- Crystal 251 is optional and can supply Gen2 species to a Gen1 game. Native
  Gold/Silver/Crystal remains the main Gen2 path.
- PokéPC Followers is not a runtime dependency; only attributed numbered art
  sheets are bundled.

## Settings and diagnostics

- **PROGRESSION** — require the correct move/badge (default ON)
- **AUTO REMOUNT** — restore after battle (default ON)
- **MOUNT RENDERER** — Auto, Native 2D, Voxel or Stadium
- **GROUND SPEED** — Normal or Fast
- **FLIGHT SPEED** — Normal, Fast or Turbo
- **DEBUG HUD** — state, species, provider, altitude, map/tile and collision

Logs use stable prefixes such as `[PMS][Mount]`, `[PMS][Provider]` and
`[PMS][Battle]` without per-frame console spam.

## Development and verification

```bash
LUA_BIN=luajit tools/test.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp LUA_BIN=luajit tools/test_engine.sh
tools/package.sh dist
```

The automated gate validates state/provider/gameplay contracts, both engine
loaders, manifest shape, and all 251 fallback PNGs plus generated mount sheets.
Runtime test cards are in [docs/TESTING.md](docs/TESTING.md).

## Clean-room notice

PMS is a clean rewrite. No Dramatic Sky Ride source code is included or
ported. Historical README/release behaviour was used only as a functional
reference. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[ATTRIBUTION.md](ATTRIBUTION.md).

Pokémon and related names/art are trademarks and copyrights of their
respective owners. This is an unofficial fan project and includes no ROM.

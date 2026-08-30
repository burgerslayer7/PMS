# PMS render-provider API v1

Pokémon Mount System owns gameplay. A provider owns only the presentation of a
mount lease it accepts. Providers may support a subset of species or modes;
returning `nil, reason` is normal and causes PMS to try the next candidate.

## Registration

Declare PMS as an optional dependency so it loads first, then register after
both mods have loaded:

```lua
local pms = mod.find("pokemon_mount_system")
local unregister = pms and pms.exports.registerRenderProvider({
  api = 1,
  id = "my_mount_renderer",
  priority = 500,

  probe = function(self, context)
    if context.activeRenderer ~= "voxel" then
      return nil, "voxel renderer inactive"
    end
    return {
      available = true,
      kind = "voxel",
      renderer = "voxel",
      fit = 100,
    }
  end,

  resolve = function(self, dex, mode, context)
    local model = myModels[dex]
    if not model or not model.supports[mode] then
      return nil, "species or mode unsupported"
    end
    return { dex = dex, mode = mode, renderer = "voxel", model = model }
  end,

  begin = function(self, resolved, context)
    return myRenderer:show(resolved, context)
  end,

  update = function(self, lease, context)
    return myRenderer:updateMount(lease, context)
  end,

  finish = function(self, lease, reason)
    myRenderer:hide(lease, reason)
  end,
})
```

Keep the returned `unregister` closure and call it during the provider mod's
cleanup. PMS itself also releases every active lease during hot reload.

## Required fields

| Field | Meaning |
| --- | --- |
| `api` | Must be `1` |
| `id` | Stable, non-empty provider id |
| `priority` | Optional numeric tie-breaker |
| `resolve(self, dex, mode, context)` | Accept or decline one species/mode |

`probe`, `begin`, `update`, `finish` and `cleanup` are optional. Without
`begin`, the resolved value itself becomes the lease value.

## Probe receipt

`probe` should feature-detect the active capability, not merely an installed
mod name. The receipt is a table with these conventional fields:

| Field | Values |
| --- | --- |
| `available` | `true` when usable now |
| `kind` | `stadium`, `voxel`, `external2d`, `builtin2d`, `technical` |
| `renderer` | active renderer id, normally `voxel` or `native2d` |
| `fit` | small numeric renderer/species fit adjustment |
| `dexFirst`, `dexLast` | optional advertised coverage |

The probe receipt is cached by provider, generation and active renderer. A map
change, renderer change or explicit resolver invalidation clears that cache.

## Render context

The current context includes:

```lua
{
  mod = pmsMod,
  game = mod.game,
  world = mod.world,
  generation = 1 or 2,
  mapId = "ROUTE_1",
  activeRenderer = "native2d" or "voxel",
  rendererHost = "BATTLE_ART_VOXEL_FORK",
  cameraMode = "diorama" or "first_person" or "third_person",
  preferredRenderer = "auto" or "native2d" or "voxel" or "stadium",
  spriteSource = "auto" or "builtin" or "wilds",
  dex = 6,
  species = "CHARIZARD",
  mode = "flight",
  altitude = 0.0,
  visualLift = 0,
  showRider = true,
  showShadow = true,
  mountScale = 1.0,
}
```

Treat the context as read-only. Do not change PMS state, player coordinates,
another renderer's camera, or the foreign world's pipeline from a render
provider.

## Ranking and failures

Ranking combines provider priority, provider kind, active-renderer match,
explicit user preference and receipt fit. `resolve` is still called for the
specific species and mode. This means an installed Stadium provider may render
Charizard while Ho-Oh safely falls through to a voxel billboard or bundled 2D.

Three callback failures mark only that provider unhealthy for the current
session. PMS continues down the list. `finish` is idempotently protected by the
resolver and is called at most once per lease.

## Built-in integrations

- `builtin_pokepc_2d`: guaranteed assets for dex 001–251.
- `wilds_selected_2d`: Wilds of Kanto's public selected follower sprite,
  including runtime PokeMMO/PMD/Pokédex style changes.
- `voxel_mount_billboard`: ordinary PMS actor rendered by an active standard
  Voxel Companion host or the dedicated PotatoVoxel adapter. The selected
  Wilds/builtin art is resolved before this renderer split.
- `stadium_models`: public Gen1 Stadium `tag` and `untag` calls only.
- `technical_fallback`: last-resort gameplay lease; normally never visible.

Battle Art and Dramaless keep complete camera/world ownership. PMS's companion
extension has one observer callback in their `background` render phase and
does not submit draw or camera contributions. It records the active host's
plain camera yaw when the public frame context provides `camera.eye` and
`camera.focus`; this is orientation metadata only. Voxel Companion API v1 does
not expose a public player-movement command, so PMS deliberately does not
implement camera-relative free movement through engine internals.

PotatoVoxel keeps the same ownership boundary through a different signal: PMS
reads the engine's active `voxel` pipeline and never imports PotatoVoxel's
module loader. Altitude and rider seating are ordinary actor-pose data. Builds
must include PotatoVoxel PR #69 for non-16x16 mount cards.

## Cooperative gameplay API

Presentation and ecosystem mods can query the active lease without receiving
PMS's mutable session:

```lua
local pms = mod.find("pokemon_mount_system")
local mount = pms and pms.exports.currentMount()
-- nil while unmounted, otherwise:
-- { dex, species, mode, altitude, state }
```

PMS also emits `mod.pokemon_mount_system.takeoff` when Flight becomes active
and `mod.pokemon_mount_system.landed` when Flight ends. The event payload is a
read-only snapshot of the mount state.

Wild Skies keeps authority over airborne entities. PMS calls only its public
`takeFlyer(x, y, radius)` export, then queues the exact returned species and
level through the common world battle script. Followers EX and Wilds can
recover their trails through their public `syncTrailers` export when PMS
releases temporary render ownership.

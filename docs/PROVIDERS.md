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
  dex = 6,
  species = "CHARIZARD",
  mode = "flight",
  altitude = 0.0,
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
- `voxel_mount_billboard`: ordinary PMS actor rendered by an active standard
  Voxel Companion host.
- `stadium_models`: public Stadium/Stadium 2 `tag` and `untag` calls.
- `technical_fallback`: last-resort gameplay lease; normally never visible.

Battle Art and Dramaless keep complete camera/world ownership. PMS's companion
extension has one observer callback in their `background` render phase and
does not submit draw or camera contributions.

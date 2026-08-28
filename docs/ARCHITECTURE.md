# Pokémon Mount System architecture

Status: v0.1.0 implementation record
Audit date: 2026-08-28  
Target runtime: Gen1Recomp++ Mod API v2, release 0.2.32 and later compatible
0.x releases

## 1. Clean-room boundary

Pokémon Mount System (PMS) is a new implementation. The source tree of
`dramatic-sky-ride` is not an input to this project and was not inspected for
this design. Historical material may be used only to describe observable
behaviour: its README, release notes, screenshots, videos and play-test notes.

The following are therefore original PMS components:

- state model and transition rules;
- movement controllers and collision policies;
- render-provider contract and selection algorithm;
- game adapters and lifecycle handling;
- data layout, mount catalogue and rider profiles;
- tests, diagnostics and packaging.

The bundled PokéPC fallback is a separate asset import authorized by the owner
of the source fork. PMS imports only the numbered walker sheets and attribution
metadata. It does not import the PokéPC follower runtime.

## 2. Confirmed runtime baseline

The current Gen1Recomp++ repository was inspected at commit `8e9206b`
(2026-08-27), immediately after release 0.2.32. The supported mod API is v2.
The public API now provides a shared vocabulary across both game engines, but
Gen2 remains a separate implementation rather than a Gen1 extension.

The manifest will declare:

```json
{
  "api": 2,
  "games": ["gen1", "gen2"]
}
```

This covers Red, Blue, Yellow, Gold, Silver and Crystal. PMS documentation will
mark Crystal support experimental while the launcher itself still labels
Crystal beta. The entire mod will not use the manifest-level `experimental`
flag, because that would incorrectly hide the stable game targets too.

### Public seams selected for PMS

| Need | Public Gen1Recomp++ seam | PMS use |
| --- | --- | --- |
| Runtime services | `mod.game`, `mod.world` | generation, party/save, active map and safe world operations |
| Lifecycle | `game.ready`, `map.entered`, `map.exited`, `map.reloaded`, `checkpoint.restored` | install/rebuild the active session and visual actor |
| Battle | `battle.started`, `battle.ended` | suspend once, restore once, retain selection |
| Save | `save.loaded`, `save.write`, `mod.save` | persist intent, never serialize transient renderer objects |
| Movement | `input.step`, `movement.speed`, `movement.collision` | native steps, speed policy and mode-specific collision verdicts |
| Surf/progression | `mod.world:availableFieldActions()`, `mod.world:useFieldAction()` | delegate badges, moves, terrain and cart rules to the active engine |
| Warp | map events and native movement | clear map-bound presentation before a transition and rebuild after it |
| UI | `ui.party.submenu` | mount selector without replacing native menus |
| 2D assets | `sprites` registry | variable-size, anchored mount actor sheets |
| Presentation | `render.hud`, Voxel Companion API v1 | diagnostics and renderer observation; never global camera transforms |
| Inter-mod | `mod.find(id).exports`, `mod.exports` | capability probes and explicit provider registration |
| Teardown | unsubscribe callbacks returned by events/hooks | deterministic hot-reload cleanup and no duplicate hooks |

PMS does not call `require("src....")` in its core, controllers or ordinary
providers. Public calls are preferred even when a private shortcut would be
shorter.

### Public-API gap and isolated bridge

API v2 can register variable-size sprites and spawn runtime actors. Gen1 also
exposes self-driven actor handles (`placeAt`, `stepNow`, `setPassable`), but the
Gen2 handle did not yet expose the same live-sync methods at the audited
commit. Neither generation currently exposes a complete public mount actor or
dynamic player-render replacement primitive.

PMS therefore permits one narrow compatibility module, `ActorBridge`, to:

1. synchronize the visual mount actor with the player's interpolated position;
2. force deterministic under-player draw ordering at an equal world cell;
3. restore/remove that actor on transitions and teardown.

The bridge receives objects obtained through `mod.world`, performs guarded
shape checks, never imports an engine module, and fails closed. If the expected
shape is unavailable, PMS keeps gameplay active and uses the safe overlay or
technical placeholder path. No controller may reference the live world/player
shape directly. This seam is logged once and covered by adapter contract tests.

An upstream actor-handle addition for Gen2 would remove the bridge without
changing MountSystem, controllers, catalogue or providers.

## 3. System boundaries

PMS owns mount gameplay. A renderer owns presentation of an accepted render
lease. An integration may coordinate an external mod, but it may not become a
gameplay dependency.

```text
MountSystem
  -> RuntimeAdapter -> Gen1Recomp++ public APIs
  -> Controller  -> movement/collision/progression policy
  -> RenderResolver -> provider lease -> renderer/provider
```

The dependency direction is one-way:

- controllers know `MountSession` and `RuntimeAdapter`, not graphic mods;
- render providers know `RenderContext`, not movement rules;
- integrations translate external capabilities into PMS contracts;
- core code never checks `Battle Art installed` to decide gameplay.

## 4. State authority

`MountState` is the sole state authority. PMS does not maintain independent
`isFlying`, `isSurfing`, `isMounted` and `isLanding` booleans.

Stable states:

- `UNMOUNTED`
- `GROUND`
- `SURF`
- `FLIGHT`

Transient/suspension states:

- `MOUNTING`
- `TAKEOFF`
- `LANDING`
- `DISMOUNTING`
- `BATTLE_SUSPENDED`
- `TRANSITION`

Each transition is validated by a table, not distributed conditionals. A
transition emits one structured record containing `from`, `to`, `reason` and a
monotonic session revision. Renderer work is a reaction to an accepted
transition, never the authority that changes it.

Battle and map transitions retain a resume snapshot:

```text
GROUND/SURF/FLIGHT -> BATTLE_SUSPENDED -> previous stable state
GROUND/SURF/FLIGHT -> TRANSITION       -> previous stable state or UNMOUNTED
```

Invalid or stale resume tokens are discarded. This prevents two battle-end
events or a reload during a warp from rendering two mounts.

## 5. Core records

### MountSystem

Coordinates selection, progression, controller activation, lifecycle events,
persistence and render leases. It is the only service allowed to commit a
state transition.

### MountSession

Runtime-only record:

- selected National Dex number and party identity;
- active mode and state;
- normalized altitude `0.0 .. 1.0`;
- map/generation revision;
- active controller token;
- active render lease;
- suspension/resume snapshot;
- last collision result for diagnostics.

No image, mesh, engine actor or callback is serialized.

### MountCatalog

Immutable data keyed by National Dex number. It stores shared capabilities and
movement defaults only. Provider-specific art, anchors and animation data live
in provider/rider profiles.

```lua
catalog[6] = {
  dex = 6,
  species = "CHARIZARD",
  modes = { flight = true },
  movement = {
    flight = { speed = 1.0, acceleration = 0.14, turnRate = 1.0 }
  }
}
```

No controller contains a species `if/elseif` chain.

## 6. Game adapters

The common adapter implements operations already shared by the public API:

- active generation/map/player snapshot;
- world-busy checks;
- party lookup and stable mon identity;
- subscriptions and cleanup;
- native field-action discovery;
- save/settings access;
- actor spawn/remove facade;
- input and movement-hook installation.

PMS currently uses one `RuntimeAdapter` because the audited public facade
already normalizes most operations. Generation branches exist only inside its
small badge, outdoor-map and Surf-state methods. Separate Gen1/Gen2 classes
will be introduced only if a real public-API difference grows beyond those
localized methods.

| Area | Gen1 | Gen2 |
| --- | --- | --- |
| World owner | overworld stack state | persistent `game.world` |
| Script engine | Lua row runner | cart-style Gen2 VM |
| Battle implementation | Gen1 BattleState | separate Gen2 battle engine |
| Event flags | string keys | numeric bitfield ids |
| FLY facade | `canFly` / `flyTo` public | no equivalent destination facade yet |
| Runtime actor handle | self-driven helpers available | sync helpers currently missing |
| Player state/surf | Gen1 player fields and native field action | Gen2 state machine and native field action |
| Save schema | Gen1 save | independent Gen2 save |

PMS never treats Crystal 251 as the Gen2 runtime. Crystal 251 is an optional
Gen1 dataset/provider integration; native Gold/Silver/Crystal uses the common
adapter over the real Gen2 facade.

## 7. Movement architecture

Controllers ask the adapter to perform native movement. They do not directly
teleport the player each frame.

### GroundController

- changes step duration through `movement.speed`;
- keeps native tile/entity/bounds collision;
- mirrors the player pose to the render actor;
- permits native seams and doors;
- suspends or dismounts on interiors according to policy.

### SurfController

- validates `surf` through `availableFieldActions`;
- enters water through `useFieldAction("surf")` when progression is enabled;
- retains native water/shore transition logic;
- replaces only the visible surf presentation and rider relation;
- restores correctly after encounters and map changes.

Suicune uses the same controller with an amphibious catalogue flag; it does
not create a separate gameplay mode.

### FlightController

- has logical continuous altitude `0.0 .. 1.0`;
- uses explicit takeoff/landing ramps;
- drives native directional steps and map seams;
- uses a centralized flight collision policy instead of unconditional noclip;
- publishes a cooperative flight/altitude marker for ecosystem mods;
- leaves first/third-person camera-relative input to the renderer that already
  owns that input mode, and never replaces a foreign camera.

Altitude bands are derived, not separately stored:

| Normalized altitude | Band | Collision intent |
| --- | --- | --- |
| `0.00` | ground | landing validation and ordinary solids |
| `0.01 .. 0.33` | low | terrain and configured overhead obstacles apply |
| `0.34 .. 0.74` | medium | ordinary ground tiles may be crossed; hard world bounds remain |
| `0.75 .. 1.00` | high | renderer may widen framing; unsafe boundaries/warps remain guarded |

If a voxel host provides roof/elevation queries, the collision resolver adds
them as capabilities. Their absence does not disable flight.

### CollisionResolver

Consumes a mode policy and the engine's original verdict. It distinguishes:

- map bounds/seams;
- solid tiles;
- entities;
- water/shore;
- doors and warps;
- optional voxel elevation/roof barriers.

The resolver returns a structured diagnostic result. Visual providers never
change physics.

## 8. Progression policy

`ProgressionPolicy` has one useful default, not dozens of toggles:

- `require_progression = true`

Surf delegates to the native field-action result. Fly uses the current
generation's public eligibility when available and a conservative adapter
check otherwise. A setting may intentionally disable progression for sandbox
play, but renderer availability never bypasses it.

## 9. Render-provider contract

Providers are discovered at boot or explicitly registered through PMS exports.
They are not scanned from the filesystem and are never rediscovered per frame.

The version-1 contract is intentionally small:

```lua
local provider = {
  api = 1,
  id = "example",
  priority = 100,
  probe = function(context) end,
  resolve = function(speciesDex, mode, context) end,
  begin = function(resolved, context) end,
  update = function(lease, context) end,
  finish = function(lease, reason) end,
  riderPose = function(speciesDex, mode, direction, context) end,
}
```

`probe` returns a capability receipt. `resolve` must return `nil, reason` for
an unsupported species/mode; that is ordinary fallback, not an error. `begin`
returns a lease owned by that provider. Every lease is finished exactly once.
Provider callbacks are protected; repeated errors mark only that provider
unhealthy for the session.

Context includes:

- game/generation and map id;
- species and mount mode;
- active render pipeline/renderer receipt;
- altitude and direction;
- installed capability receipts;
- debug flag.

It does not expose the mutable MountSystem.

### Selection

Resolver ranking is deterministic. Capability probes are cached by provider,
generation and active renderer; species/mode acceptance is always evaluated
per acquisition.

Candidates are filtered by health and `resolve`, then ranked by renderer fit
before numeric priority:

1. external provider native to the active renderer;
2. another compatible external 3D/voxel provider;
3. compatible external 2D source;
4. bundled PokéPC provider;
5. technical placeholder/battle-art fallback.

A provider that renders Charizard but not Ho-Oh simply declines Ho-Oh; the
next candidate is selected. There is no global failure because one installed
renderer has incomplete species coverage.

### Discovery limitation

API v2 provides `mod.find(id)` but no public enumerate-all-mods operation.
PMS therefore combines:

- capability probes for audited, known hosts;
- `mod.exports.registerRenderProvider(provider)` for future/unknown mods;
- behavioural validation of returned exports.

Known ids are discovery hints only. Selection is always based on the receipt,
not the id.

## 10. Native 2D and rider composition

Native 2D is mandatory and always registered. The builtin provider supplies a
variable-size sprite definition. PMS spawns one passable visual actor at the
player's cell and anchors it so the unmodified player sprite reads as the rider.
The actor is synchronized to the player's interpolated position and forced
under the player in the y-sort. This preserves native player palettes, gender,
animations and sprite-mod compatibility.

Large mount sheets are nearest-neighbour scaled build artifacts of the bundled
16x16 walker frames. The registry uses their real `frameWidth`, `frameHeight`,
`anchorX` and `anchorY`; no global `love.graphics.scale` or camera transform is
used.

`RiderPose` resolves a profile using this specificity order:

1. provider + renderer + species + mode + direction;
2. provider + species + mode + direction;
3. species + mode + direction;
4. mode + direction;
5. safe centered default.

A profile can adjust the mount anchor, visual bob, scale tier and player
occlusion mask. Physics never reads rider profiles.

## 11. Bundled PokéPC fallback

Audited source: `burgerslayer7/PokePCFollowers`, commit `78c80f6`, release
0.8.3.

Confirmed:

- exactly 251 numbered files `follower_001.png` through
  `follower_251.png`;
- every file is a valid PNG;
- every sheet is 16x96 pixels;
- six 16x16 vertical frames and walker semantics;
- Gen1 and Gen2 dex coverage is continuous.

PMS imports only those numbered sheets, a machine-readable source receipt and
the necessary notices. It does not depend on or copy PokéPC follower logic.
Build validation fails if one file is missing, invalid, mis-sized or mapped to
the wrong National Dex number.

The source fork contains third-party sprite lineage and no repository-level
license was present at audit time. `ATTRIBUTION.md` must preserve that lineage
and must not claim a new license for those assets. Public release packaging
includes the notice and a source commit/checksum inventory.

## 12. Voxel hosts

### Standard companion path

Battle Art 1.9.8 and Dramaless Shape 2.0.3 expose
`exports.voxel_companion.api == 1`. PMS registers an extension with that host.
The host owns:

- world geometry and render pipeline;
- camera and render targets;
- graphics resources and quality tier;
- fault isolation of render phases.

PMS registers a render-phase observer and supplies the mount as an ordinary
runtime actor the host already knows how to billboard. The observer detects
whether voxel frames are actually active; it submits no draw command and no
`camera_delta`. PMS never takes camera ownership.

### Audited adapters

| Renderer/provider | Audited live version | Games declared | Current PMS path |
| --- | ---: | --- | --- |
| Battle Art | 1.9.8 | Gen1 | `voxel_companion` v1 |
| Dramaless Shape | 2.0.3 | Gen1 default | `voxel_companion` v1 |
| Dramatic Shape maintained fork | 1.9.0 | Gen1 default | ordinary runtime-actor billboard path |
| Terrarium | 1.27.0-mobile | Gen1 default | ordinary runtime-actor billboard path |
| PotatoVoxel | 1.9.4 | Gen1 + Gen2 | ordinary runtime-actor billboard path |
| Voxel Ascendant | 2.0.2 | Gen1 | ordinary runtime-actor billboard path |

Only the first two currently expose the standard companion registration
contract. A renderer can still display PMS through its normal variable-sprite
billboard path even when no dedicated mount mesh API exists.

## 13. Stadium providers

The Gen1 Stadium Overworld Models release audited as 0.1.47 and requires a
voxel host. The Gen2 Stadium 2 Overworld Models release audited as 0.4.33 and
declares Gen2. Both obtain models from a user-imported ROM; PMS never bundles
Nintendo model data.

`StadiumProvider` feature-detects `tag`, `untag`, renderer status and declared
dex coverage. It tags only PMS's active render actor and removes the tag when
the lease ends. A rejected species falls through to the next provider. Stadium
keeps responsibility for its model animation; PMS exposes mode and normalized
altitude as actor metadata but does not patch Stadium's transforms. Gen2
Stadium's separate fly/swim gameplay is never invoked by PMS.

## 14. Ecosystem integrations

- **Wilds of Kanto 2.2.0 / Followers EX 1.0.19:** PMS changes no options or
  follower count. Render ownership hides only a matching follower entity from
  the draw list while retaining its trail/update state.
- **Wild Skies 1.12.0:** PMS publishes `isFlying`/`altitude` and stamps the
  cooperative `freeFlying` marker already read by Wild Skies. Wild Skies keeps
  all flyer spawning and encounter authority.
- **Crystal 251 0.11.6:** optional Gen1 dex/provider capability only.
- **PokéPC runtime:** not required and not used as a runtime provider for the
  bundled fallback.

## 15. Render ownership

One active mount session owns exactly one `Mount Render Ownership` lease.

On mount:

1. resolve provider;
2. request temporary follower suppression capability, if available;
3. create provider lease;
4. expose the lease to diagnostics.

On true dismount or reload:

1. finish provider lease exactly once;
2. remove the visual actor/model tag;
3. release follower suppression and restore the same live entity;
4. clear cached render context for the old map.

Battle/map presentation leases may be recreated, but the session-level
ownership lease remains active so a duplicate follower cannot flash for one
frame. PMS never changes another mod's saved follower selection or count.

## 16. Battle, map and save lifecycle

### Battle

`battle.started` snapshots the stable mode, releases presentation and enters
`BATTLE_SUSPENDED`. `battle.ended` restores once from that token. A battle
during takeoff or landing resumes as stable Flight rather than replaying a
half-finished tween.

### Maps

`map.exited` releases map-bound actors before the old object pool disappears.
`map.entered` increments the map revision and re-creates presentation only
after the player is valid. `map.reloaded` and `checkpoint.restored` invalidate
unsafe presentation or session state.

Ground follows native doors and seams. Surf follows the native Surf state.
Flight keeps native hard bounds/entity collision, blocks door/warp cells while
airborne and preserves its session across ordinary map transitions. A failed
controller leaves the player visible and controllable.

### Save

Persisted data is deliberately small:

- chosen species/party fingerprint;
- preferred mode;
- optional remount intent.

Actor ids, provider leases and callbacks are not written. Normalized altitude
is persisted with the remount intent. Load restores only after `game.ready`
and a valid current map.

## 17. Settings and diagnostics

Initial settings:

- progression requirement;
- auto-remount after battle;
- preferred renderer (`auto` by default);
- ground/flight speed multipliers within safe bounds;
- debug mode.

Debug HUD reports state, dex/species, mode, provider, renderer, altitude,
tile, last collision, generation and map id. Logs are structured by subsystem,
for example `[PMS][Provider] selected ...`. Frame-hot paths update counters but
do not emit log lines repeatedly.

## 18. Performance and hot reload

- provider discovery occurs on `mods.loaded`/`game.ready`, not each frame;
- catalogue and rider resolution are pre-indexed;
- provider selection cache has explicit capability/map invalidation;
- all event/hook unsubscriber functions live in a subscription ledger;
- teardown releases actors, input, tags, follower visibility and provider
  resources before clearing caches.

Re-running the entry chunk cannot leave two hooks or two visual actors.

## 19. Verification strategy

Headless tests currently cover:

- representative legal/illegal state transitions;
- catalogue coverage and mode eligibility;
- provider ordering, partial species support, health and fallback;
- rider geometry for the four validation mounts;
- generation-specific progression and native field-action delegation;
- battle suspend/restore including an interrupted takeoff;
- save record validation;
- manifest schema and Gen2 compatibility scan;
- all 251 fallback PNGs, dimensions, frame count and dex mapping;
- package contents and root layout through `validate_package.py`.

Runtime validation remains a vertical-slice matrix: Arcanine, Lapras,
Charizard and Ho-Oh first in Red/Yellow/Gold/Crystal, then Blue/Silver and
external providers. Every release includes concise manual scripts and the log
fields to collect.

## 20. Delivery sequence

Implementation remains vertical and commit-sized:

1. clean API v2 skeleton and tests;
2. bundled PokéPC provider plus 251-asset gate;
3. Arcanine native 2D ground slice;
4. Lapras native 2D surf slice;
5. Charizard native 2D flight/altitude slice;
6. Ho-Oh Gen2 slice;
7. full data-driven catalogue;
8. standard voxel companion and legacy billboard adapters;
9. Stadium providers;
10. ecosystem leases/integrations;
11. lifecycle hardening, package validation and launcher zip.

The release criterion is graceful playability with PMS plus Gen1Recomp++ only.
External mods may improve presentation; none may be required for Ground, Surf
or Flight.

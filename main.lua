-- Pokémon Mount System -- clean-room Gen1Recomp++ API v2 entry point.

local mod = ...

local V = {
  mod = mod,
  path = mod.path,
  modules = {},
  dataFiles = {},
}

local function chunkFor(rel)
  local source, readErr = mod:read(rel)
  if not source then
    error(("pokemon_mount_system: missing %s (%s)"):format(
      rel, tostring(readErr or "reinstall the mod")), 0)
  end
  local compile = loadstring or load
  local chunk, compileErr = compile(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("pokemon_mount_system: %s did not compile: %s"):format(
      rel, tostring(compileErr)), 0)
  end
  return chunk
end

function V.require(name)
  local hit = V.modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("src/" .. name .. ".lua")(V)
  if value == nil then
    error("pokemon_mount_system: module returned nil: " .. tostring(name), 0)
  end
  V.modules[name] = value
  return value
end

function V.data(name)
  local hit = V.dataFiles[name]
  if hit ~= nil then return hit end
  local value = chunkFor("config/" .. name .. ".lua")(V)
  if value == nil then
    error("pokemon_mount_system: config returned nil: " .. tostring(name), 0)
  end
  V.dataFiles[name] = value
  return value
end

local Log = V.require("util/Log")
local Subscriptions = V.require("util/Subscriptions")
local Settings = V.require("core/Settings")
local MountState = V.require("core/MountState")
local MountCatalog = V.require("core/MountCatalog")
local ProviderRegistry = V.require("providers/ProviderRegistry")
local BuiltinPokePCProvider = V.require("providers/BuiltinPokePCProvider")
local VoxelBillboardProvider = V.require("providers/VoxelBillboardProvider")
local StadiumProvider = V.require("providers/StadiumProvider")
local TechnicalFallbackProvider = V.require("providers/TechnicalFallbackProvider")
local RenderResolver = V.require("rendering/RenderResolver")
local RiderPose = V.require("rendering/RiderPose")
local RiderVisualBridge = V.require("rendering/RiderVisualBridge")
local DebugHud = V.require("rendering/DebugHud")
local ActorBridge = V.require("game/ActorBridge")
local RuntimeAdapter = V.require("game/RuntimeAdapter")
local ProgressionPolicy = V.require("game/ProgressionPolicy")
local Persistence = V.require("game/Persistence")
local GroundController = V.require("movement/GroundController")
local SurfController = V.require("movement/SurfController")
local FlightController = V.require("movement/FlightController")
local CollisionResolver = V.require("movement/CollisionResolver")
local PartyActions = V.require("ui/PartyActions")
local VoxelCompanion = V.require("integrations/VoxelCompanion")
local Ecosystem = V.require("integrations/Ecosystem")
local RenderOwnership = V.require("integrations/RenderOwnership")
local MountSystem = V.require("core/MountSystem")

local log = Log.new(mod)
local subscriptions = Subscriptions.new(log)
local settings = Settings.new(mod)
settings:register()

local catalog = MountCatalog.new(V.data("mounts"))
local providers = ProviderRegistry.new(log)
local poses = RiderPose.new(V.data("rider_profiles"))
local actorBridge = ActorBridge.new(mod, log)
local runtimeAdapter = RuntimeAdapter.new(mod, log)
local progression = ProgressionPolicy.new(runtimeAdapter, settings, log)
local persistence = Persistence.new(mod)
local riderBridge = RiderVisualBridge.new(log)
local controllers = {
  ground = GroundController.new(runtimeAdapter, settings),
  surf = SurfController.new(runtimeAdapter, settings, progression, log),
  flight = FlightController.new(runtimeAdapter, settings),
}
local builtinProvider = BuiltinPokePCProvider.new({
  mod = mod,
  catalog = catalog,
  poses = poses,
  bridge = actorBridge,
  log = log,
})
local contentOk, contentErr = builtinProvider:registerContent()
if not contentOk then
  error("pokemon_mount_system: fallback sprite registration failed: "
    .. tostring(contentErr), 0)
end
assert(providers:register(builtinProvider:contract(), "builtin"))
local voxelCompanion = VoxelCompanion.new(mod, log)
local stadiumProvider = StadiumProvider.new({
  mod = mod,
  catalog = catalog,
  poses = poses,
  builtin = builtinProvider,
  bridge = actorBridge,
  voxel = voxelCompanion,
  log = log,
})
assert(providers:register(VoxelBillboardProvider.new({
  catalog = catalog,
  poses = poses,
  builtin = builtinProvider,
  bridge = actorBridge,
  voxel = voxelCompanion,
}), "builtin"))
assert(providers:register(stadiumProvider:contract(), "integration"))
assert(providers:register(TechnicalFallbackProvider.new(catalog, log),
  "builtin"))
local resolver = RenderResolver.new(providers, log)
local ecosystem = Ecosystem.new(voxelCompanion, stadiumProvider, log)
local renderOwnership = RenderOwnership.new(log)
local system = MountSystem.new({
  state = MountState,
  catalog = catalog,
  resolver = resolver,
  settings = settings,
  log = log,
  adapter = runtimeAdapter,
  progression = progression,
  persistence = persistence,
  rider = riderBridge,
  controllers = controllers,
  discover = function() return ecosystem:discover() end,
  ownership = renderOwnership,
})
local collisionResolver = CollisionResolver.new(runtimeAdapter, system)
local partyActions = PartyActions.new({
  mod = mod,
  catalog = catalog,
  system = system,
  adapter = runtimeAdapter,
  log = log,
})
local debugHud = DebugHud.new(settings, system, runtimeAdapter)

local function subscribeEvent(name, fn, priority)
  if not (mod.events and mod.events.on) then return end
  subscriptions:add(mod.events:on(name, fn, priority))
end

local function subscribeHook(name, fn, priority)
  if not (mod.hooks and mod.hooks.wrap) then return end
  subscriptions:add(mod.hooks:wrap(name, fn, priority))
end

subscribeHook("core.update", function(next, game, dt)
  local result = next(game, dt)
  ecosystem:update(system)
  system:update(dt)
  return result
end, -100)

subscribeHook("input.step", function(next, game, dt)
  local result = next(game, dt)
  system:handleInput(game and game.input, dt)
  return result
end, -50)

subscribeHook("movement.speed", function(next, frames, ctx)
  frames = next(frames, ctx)
  return system:movementFrames(frames, ctx)
end, -50)

subscribeHook("movement.collision", function(next, allowed, ctx)
  allowed = next(allowed, ctx)
  return collisionResolver:resolve(allowed, ctx)
end, -50)

subscribeHook("fieldmove.eligibility", function(next, moveId, ctx)
  return progression:fieldMoveEligibility(next, moveId, ctx)
end, -50)

subscribeHook("ui.party.submenu", function(next, game, items, mon, ctx)
  return partyActions:decorate(next, game, items, mon, ctx)
end, -50)

subscribeHook("render.hud", function(next, game, viewport)
  local result = next(game, viewport)
  debugHud:draw(game, viewport)
  return result
end, -100)

subscribeHook("save.write", function(next, game)
  system:persist()
  return next(game)
end, -100)

subscribeEvent("mods.loaded", function()
  system:discoverProviders({ mod = mod })
end)

subscribeEvent("game.ready", function(payload)
  local world = mod.world
  system:enable({
    mod = mod,
    game = payload and payload.game or mod.game,
    world = world,
    generation = world and type(world.canFly) == "function" and 1 or 2,
  })
  ecosystem:discover()
  ecosystem:update(system)
  local record = persistence:loadActive()
  if record then system:queueRestore(record) end
end)

subscribeEvent("save.loaded", function()
  local record = persistence:loadActive()
  if record then system:queueRestore(record) end
end)

subscribeEvent("battle.started", function(payload)
  system:onBattleStarted(payload)
end)

subscribeEvent("battle.ended", function(payload)
  system:onBattleEnded(payload)
end)

subscribeEvent("map.exited", function(payload)
  system:onMapExited(payload)
end)

subscribeEvent("map.entered", function(payload)
  system:onMapEntered(payload)
end)

subscribeEvent("map.reloaded", function(payload)
  system:onMapEntered(payload)
end)

subscribeEvent("checkpoint.restored", function(payload)
  system:onCheckpointRestored(payload)
end)

-- Public capability surface. Callers receive functions, never the mutable
-- registry or MountSystem tables.
mod.exports.api = 1
mod.exports.version = mod.version
mod.exports.capabilities = {
  gameplay = { ground = true, surf = true, flight = true },
  renderProviders = 1,
  renderOwnership = 1,
  bundledFallbackDex = 251,
}

mod.exports.registerRenderProvider = function(provider)
  return providers:register(provider, "external")
end

mod.exports.mount = function(dex, mode, opts)
  return system:mount(dex, mode, opts)
end

mod.exports.dismount = function(reason)
  return system:dismount(reason or "external")
end

mod.exports.land = function()
  return system:requestLanding("external")
end

mod.exports.status = function()
  return system:snapshot()
end

mod.exports.isFlying = function()
  local status = system:snapshot()
  return status.mode == "flight" and status.state ~= "UNMOUNTED"
    and status.state ~= "BATTLE_SUSPENDED"
end

mod.exports.altitude = function()
  local status = system:snapshot()
  return status.mode == "flight" and status.altitude or 0
end

mod.exports.integrationStatus = function()
  return ecosystem:status()
end

mod.exports.catalog = function(mode)
  return catalog:publicList(mode)
end

mod.exports.cleanup = function()
  system:disable("external-cleanup")
  subscriptions:clear()
  ecosystem:cleanup()
  providers:cleanup()
end

log:info("Boot", "API v1 loaded with %d mount species", catalog:count())

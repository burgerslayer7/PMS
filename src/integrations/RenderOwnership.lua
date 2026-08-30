-- Presentation authority for follower coexistence. This adapter never changes
-- another mod's options or persistent follower count. It removes only the
-- selected mount species from the current world's draw list, leaving its
-- update/trail state alive, and puts the same live entity back on dismount.

local RenderOwnership = {}
RenderOwnership.__index = RenderOwnership

local function liveWorld(runtime)
  local world = runtime and runtime.world
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, value = pcall(world.overworld, world)
  if ok and type(value) == "table" then return value end
  return nil
end

local function speciesOf(entity)
  if type(entity) ~= "table" then return nil end
  local mon = entity.pokepcMon
  return type(mon) == "table" and mon.species
    or entity._pokepcFollowerSpecies
    or entity.followerSpecies
end

local function isSameMount(entity, species)
  if type(entity) ~= "table" or entity.pmsMountActor then return false end
  if entity.pokepcTrailerKind == "trainer" then return false end
  local found = speciesOf(entity)
  if found then return found == species end
  -- The engine-native companion is always Pikachu. Hide it only when Pikachu
  -- itself is the mount; other mounts may keep that separate companion.
  return entity.pikachuFollower == true and species == "PIKACHU"
end

local function contains(list, wanted)
  for _, value in ipairs(list or {}) do
    if value == wanted then return true end
  end
  return false
end

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function RenderOwnership.new(log, mod)
  return setmetatable({ log = log, mod = mod }, RenderOwnership)
end

function RenderOwnership:acquire(session, runtime)
  local lease = {
    species = session and session.species,
    hidden = setmetatable({}, { __mode = "k" }),
    runtime = runtime,
  }
  self:update(lease, session, runtime)
  return lease
end

function RenderOwnership:update(lease, session, runtime)
  if not lease then return false end
  lease.species = session and session.species or lease.species
  local live = liveWorld(runtime)
  if not live or type(live.entities) ~= "table" then return true end
  for index = #live.entities, 1, -1 do
    local entity = live.entities[index]
    if isSameMount(entity, lease.species) then
      table.remove(live.entities, index)
      lease.hidden[entity] = live
      if self.log then
        self.log:once("render-owner-" .. tostring(lease.species), "info",
          "Ownership", "temporarily hid duplicate follower %s",
          tostring(lease.species))
      end
    end
  end
  return true
end

function RenderOwnership:release(lease)
  if not lease then return false end
  for entity, world in pairs(lease.hidden or {}) do
    local stillLive = contains(world and world.npcs, entity)
      or contains(world and world.pokepcTrailers, entity)
    if stillLive and world and type(world.entities) == "table"
        and not contains(world.entities, entity) then
      world.entities[#world.entities + 1] = entity
    end
  end
  lease.hidden = {}
  -- Prefer Followers EX when it owns the follower engine, then Wilds. Both
  -- expose the same public syncTrailers seam. This refreshes provider-owned
  -- draw lists after PMS returns authority without changing saved pack size,
  -- leader selection or control mode.
  local provider
  for _, id in ipairs({ "FOLLOWERS_EX", "overworld_wild_spawns" }) do
    local handle = find(self.mod, id)
    local sync = handle and handle.exports and handle.exports.syncTrailers
    if type(sync) == "function" then
      provider = { id = id, sync = sync }
      break
    end
  end
  local runtime = lease.runtime
  local world = liveWorld(runtime)
  local game = runtime and runtime.game
  if provider and world and game then
    local ok, err = pcall(provider.sync, game, world,
      { catchUp = true, pmsOwnershipRelease = true })
    if not ok and self.log then
      self.log:warn("Ownership", "%s follower resync failed: %s",
        provider.id, tostring(err))
    elseif ok and self.log then
      self.log:once("ownership-sync-" .. provider.id, "info", "Ownership",
        "restored follower authority through %s public API", provider.id)
    end
  end
  return true
end

return RenderOwnership

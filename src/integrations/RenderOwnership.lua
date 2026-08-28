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

function RenderOwnership.new(log)
  return setmetatable({ log = log }, RenderOwnership)
end

function RenderOwnership:acquire(session, runtime)
  local lease = {
    species = session and session.species,
    hidden = setmetatable({}, { __mode = "k" }),
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
  return true
end

return RenderOwnership

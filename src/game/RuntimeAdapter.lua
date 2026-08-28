-- Generation-neutral access to the documented mod.game/mod.world surfaces.
-- The few live-world reads needed for player identity and map environment are
-- guarded here so controllers never depend on an engine object shape.

local RuntimeAdapter = {}
RuntimeAdapter.__index = RuntimeAdapter

local GEN2_BADGES = {
  ZEPHYR = 1, HIVE = 2, PLAIN = 3, FOG = 4,
  STORM = 5, MINERAL = 6, GLACIER = 7, RISING = 8,
}

local OUTSIDE_ENVIRONMENTS = { TOWN = true, ROUTE = true, OUTDOOR = true }
local GEN1_OUTSIDE_DEFAULTS = { OVERWORLD = true, PLATEAU = true }

local function liveWorld(world)
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, value = pcall(world.overworld, world)
  if ok and type(value) == "table" then return value end
  return nil
end

local function hasValue(values, wanted)
  if type(values) ~= "table" then return false end
  if values[wanted] then return true end
  for _, value in ipairs(values) do
    if value == wanted then return true end
  end
  return false
end

local function moveId(entry)
  if type(entry) == "string" then return entry end
  return type(entry) == "table" and (entry.id or entry.move) or nil
end

function RuntimeAdapter.new(mod, log)
  return setmetatable({ mod = mod, log = log, runtime = nil }, RuntimeAdapter)
end

function RuntimeAdapter:bind(runtime)
  self.runtime = runtime or self.runtime or {}
  return self.runtime
end

function RuntimeAdapter:game()
  local runtime = self.runtime or {}
  return runtime.game or (self.mod and self.mod.game)
end

function RuntimeAdapter:world()
  local runtime = self.runtime or {}
  return runtime.world or (self.mod and self.mod.world)
end

function RuntimeAdapter:generation()
  local runtime = self.runtime or {}
  if runtime.generation == 1 or runtime.generation == 2 then
    return runtime.generation
  end
  local world = self:world()
  return world and type(world.canFly) == "function" and 1 or 2
end

function RuntimeAdapter:position()
  local world = self:world()
  if not (world and type(world.current) == "function") then
    return nil, "world API unavailable"
  end
  local ok, value, err = pcall(world.current, world)
  if not ok then return nil, value end
  return value, err
end

function RuntimeAdapter:party()
  local game = self:game()
  return game and game.save and game.save.party or {}
end

function RuntimeAdapter:partySlot(mon)
  for slot, candidate in ipairs(self:party()) do
    if candidate == mon then return slot end
  end
  return nil
end

function RuntimeAdapter:partyMon(slot, species, fingerprint)
  local party = self:party()
  local direct = tonumber(slot) and party[tonumber(slot)] or nil
  local function matches(mon)
    return mon and (not species or mon.species == species)
      and (not fingerprint or self:fingerprint(mon) == fingerprint)
  end
  if matches(direct) then return direct end
  if species or fingerprint then
    for _, mon in ipairs(party) do
      if matches(mon) then return mon end
    end
  end
  return fingerprint and nil or direct
end

function RuntimeAdapter:fingerprint(mon)
  if type(mon) ~= "table" then return nil end
  local dvs = mon.dvs or mon.ivs or {}
  return table.concat({
    tostring(mon.species or "?"),
    tostring(mon.nickname or ""),
    tostring(mon.level or ""),
    tostring(mon.personality or mon.id or ""),
    tostring(dvs.attack or dvs.atk or ""),
    tostring(dvs.defense or dvs.def or ""),
  }, "|")
end

function RuntimeAdapter:knows(mon, wanted)
  for _, move in ipairs(type(mon) == "table" and (mon.moves or {}) or {}) do
    if moveId(move) == wanted then return true end
  end
  return false
end

function RuntimeAdapter:hasBadge(badge)
  local game = self:game()
  local save = game and game.save or {}
  if self:generation() == 1 then
    return not not (save.inventory and save.inventory[badge])
  end
  local badges = save.player and save.player.badges or {}
  local short = tostring(badge or ""):gsub("BADGE$", "")
  return badges[short] == true or badges[badge] == true
    or badges[GEN2_BADGES[short]] == true
end

function RuntimeAdapter:withTemporaryBadge(badge, fn)
  if self:generation() ~= 2 then return fn() end
  local game = self:game()
  local player = game and game.save and game.save.player
  if type(player) ~= "table" then return fn() end
  player.badges = player.badges or {}
  local key = tostring(badge or ""):gsub("BADGE$", "")
  local before = player.badges[key]
  player.badges[key] = true
  local result = { pcall(fn) }
  player.badges[key] = before
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2)
end

function RuntimeAdapter:mapDefinition()
  local world = self:world()
  local live = liveWorld(world)
  if live and live.map and type(live.map.def) == "table" then
    return live.map.def
  end
  local position = self:position()
  local game = self:game()
  local maps = game and game.data and game.data.maps
  return position and maps and maps[position.mapId] or nil
end

function RuntimeAdapter:isOutside()
  local def = self:mapDefinition()
  if type(def) ~= "table" then return false end
  if self:generation() == 2 then
    return OUTSIDE_ENVIRONMENTS[def.environment] == true
  end
  local game = self:game()
  local configured = game and game.data and game.data.field
    and game.data.field.outsideTilesets
  return hasValue(configured or GEN1_OUTSIDE_DEFAULTS, def.tileset)
end

function RuntimeAdapter:isSurfing()
  local live = liveWorld(self:world())
  if not live then return false end
  if self:generation() == 1 then
    return not not (live.player and live.player.surfing)
  end
  return live.playerState == "surf" or live.playerState == "surf_pika"
end

-- Cooperative flight marker used by Wild Skies and follower mods. The marker
-- lives on the same player object those public integrations already inspect;
-- ownership fields ensure PMS never clears a flight another controller owns.
function RuntimeAdapter:setFlightMarker(active, altitude)
  local live = liveWorld(self:world())
  local player = live and live.player
  if type(player) ~= "table" then return nil, "live player unavailable" end
  if active then
    if player.freeFlying == true and player.pmsMountFlight ~= true then
      return nil, "another flight controller is already active"
    end
    if player.pmsMountFlight ~= true then
      player._pmsPreviousFreeFlying = player.freeFlying
    end
    player.freeFlying = true
    player.pmsMountFlight = true
    player.pmsMountAltitude = tonumber(altitude) or 0
    return true
  end
  if player.pmsMountFlight == true then
    player.freeFlying = player._pmsPreviousFreeFlying
    player._pmsPreviousFreeFlying = nil
    player.pmsMountFlight = nil
    player.pmsMountAltitude = nil
  end
  return true
end

function RuntimeAdapter:isPlayerMover(mover)
  local live = liveWorld(self:world())
  return live ~= nil and mover ~= nil and live.player == mover
end

function RuntimeAdapter:terrainAt(x, y)
  local world = self:world()
  if not (world and type(world.mapOverview) == "function") then return nil end
  local ok, overview = pcall(world.mapOverview, world)
  if not ok or type(overview) ~= "table" then return nil end
  x, y = math.floor(tonumber(x) or -1), math.floor(tonumber(y) or -1)
  local row = overview.rows and overview.rows[y + 1]
  if type(row) ~= "string" or x < 0 or x >= #row then return nil end
  local symbol = string.sub(row, x + 1, x + 1)
  if symbol == "~" then return "water" end
  if symbol == "." or symbol == "+" then return "land" end
  return "blocked"
end

function RuntimeAdapter:tileSymbolAt(x, y)
  local world = self:world()
  if not (world and type(world.mapOverview) == "function") then return nil end
  local ok, overview = pcall(world.mapOverview, world)
  if not ok or type(overview) ~= "table" then return nil end
  x, y = math.floor(tonumber(x) or -1), math.floor(tonumber(y) or -1)
  local row = overview.rows and overview.rows[y + 1]
  if type(row) ~= "string" or x < 0 or x >= #row then return nil end
  return string.sub(row, x + 1, x + 1)
end

function RuntimeAdapter:currentTileSymbol()
  local position = self:position()
  if not position then return nil end
  return self:tileSymbolAt(position.x, position.y)
end

function RuntimeAdapter:currentTerrain()
  local position = self:position()
  if not position then return nil end
  return self:terrainAt(position.x, position.y)
end

function RuntimeAdapter:fieldAction(id)
  local world = self:world()
  if not (world and type(world.availableFieldActions) == "function") then
    return nil, "field actions unavailable"
  end
  local ok, actions, err = pcall(world.availableFieldActions, world)
  if not ok then return nil, actions end
  for _, action in ipairs(actions or {}) do
    if action.id == id then return action end
  end
  return nil, err or "field action unavailable"
end

function RuntimeAdapter:useFieldAction(id, opts)
  local world = self:world()
  if not (world and type(world.useFieldAction) == "function") then
    return nil, "field actions unavailable"
  end
  local ok, value, err = pcall(world.useFieldAction, world, id, opts)
  if not ok then return nil, value end
  return value, err
end

return RuntimeAdapter

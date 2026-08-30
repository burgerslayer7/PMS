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
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
local DELTA = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}

local GEN2_LEDGE_FACINGS = {
  [0] = { right = true },
  [1] = { left = true },
  [2] = { up = true },
  [3] = { down = true },
  [4] = { down = true, right = true },
  [5] = { down = true, left = true },
  [6] = { up = true, right = true },
  [7] = { up = true, left = true },
}

local function gen2LedgeFacings(collision)
  collision = tonumber(collision)
  if not collision or collision < 0 then return nil end
  collision = collision % 256
  if math.floor(collision / 16) ~= 0xa then return nil end
  return GEN2_LEDGE_FACINGS[collision % 8]
end

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
      and (not fingerprint or self:fingerprintMatches(mon, fingerprint))
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
    "v2",
    tostring(mon.species or "?"),
    tostring(mon.otId or mon.trainerId or ""),
    tostring(mon.personality or mon.id or ""),
    tostring(dvs.attack or dvs.atk or ""),
    tostring(dvs.defense or dvs.def or ""),
    tostring(dvs.speed or ""),
    tostring(dvs.special or dvs.specialAttack or dvs.spc or ""),
    tostring(mon.caughtData or ""),
  }, "|")
end

-- v0.1.6 fingerprints included nickname and level, so gaining a level during
-- battle made the exact same party Pokemon impossible to restore. Accept that
-- legacy shape while comparing only stable identity fields, then write v2.
function RuntimeAdapter:fingerprintMatches(mon, fingerprint)
  if type(mon) ~= "table" or type(fingerprint) ~= "string" then return false end
  if self:fingerprint(mon) == fingerprint then return true end
  local parts = {}
  for value in string.gmatch(fingerprint .. "|", "(.-)|") do
    parts[#parts + 1] = value
  end
  if #parts ~= 6 or parts[1] ~= tostring(mon.species or "?") then
    return false
  end
  local dvs = mon.dvs or mon.ivs or {}
  return parts[4] == tostring(mon.personality or mon.id or "")
    and parts[5] == tostring(dvs.attack or dvs.atk or "")
    and parts[6] == tostring(dvs.defense or dvs.def or "")
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

function RuntimeAdapter:movementState()
  local live = liveWorld(self:world())
  local player = live and live.player
  if type(player) ~= "table" then return nil end
  return {
    moving = player.moving == true,
    facing = player.facing,
    jumping = player.jumping == true or player.ledgeHop == true,
  }
end

function RuntimeAdapter:isFreeRoam()
  local world = self:world()
  local live = liveWorld(world)
  local player = live and live.player
  if type(player) ~= "table" or player.moving or player.inputLocked then
    return false
  end
  if world and type(world.availableFieldActions) == "function" then
    local ok, _, err = pcall(world.availableFieldActions, world)
    if not ok or err == "world is busy" or err == "no overworld" then
      return false
    end
  end
  local game = self:game()
  local stack = game and game.stack
  if stack and type(stack.top) == "function" then
    local ok, top = pcall(stack.top, stack)
    if not ok then return false end
    if self:generation() == 1 then
      if top and top ~= live and top ~= game.overworld
          and top.isOverworld ~= true then return false end
    elseif top ~= nil and top ~= live then
      return false
    end
  end
  return true
end

function RuntimeAdapter:_tryGen1ReverseLedge(live, direction)
  local player, map = live.player, live.map
  local delta = DELTA[direction]
  if not (delta and player and map and type(map.cellTile) == "function"
      and type(live.checkLedgeHop) == "function") then return false end
  if player.moving or player.facing ~= direction then return false end
  local fx, fy = player.cellX + delta[1], player.cellY + delta[2]
  if type(map.inBounds) == "function" and not map:inBounds(fx, fy) then
    return false
  end
  local standing = map:cellTile(player.cellX, player.cellY)
  local front = map:cellTile(fx, fy)
  local game = self:game()
  local ledges = game and game.data and game.data.field
    and game.data.field.ledges or {}
  local tileset = map.def and map.def.tileset
  local official = false
  for _, row in ipairs(ledges) do
    if row.ledgeTile == front and OPPOSITE[row.facing] == direction
        and (row.tileset or "OVERWORLD") == tileset then
      official = true
      break
    end
  end
  if not official then return false end
  local temporary = {
    facing = direction,
    input = direction,
    standingTile = standing,
    ledgeTile = front,
    tileset = tileset,
  }
  ledges[#ledges + 1] = temporary
  local ok, jumped = pcall(live.checkLedgeHop, live, direction)
  ledges[#ledges] = nil
  return ok and jumped == true
end

function RuntimeAdapter:_tryGen2ReverseLedge(live, direction)
  local player, map = live.player, live.map
  local delta = DELTA[direction]
  if not (delta and player and map and type(map.cellCollision) == "function")
      or player.moving or player.facing ~= direction then return false end
  local fx, fy = player.cellX + delta[1], player.cellY + delta[2]
  local lx, ly = player.cellX + delta[1] * 2,
    player.cellY + delta[2] * 2
  if not (type(map.inBounds) == "function" and map:inBounds(fx, fy)
      and map:inBounds(lx, ly) and type(map.isWalkable) == "function"
      and map:isWalkable(lx, ly)) then return false end

  -- Gold stores the ledge direction on the tile where the original jump
  -- starts. During a reverse jump that tile is the two-cell landing target,
  -- not the intervening wall cell.
  local targetCollision = map:cellCollision(lx, ly)
  local facings = gen2LedgeFacings(targetCollision)
  if not (facings and facings[OPPOSITE[direction]]) then return false end

  if type(live.npcAtCell) == "function" then
    local okNpc, npc = pcall(live.npcAtCell, live, lx, ly)
    if okNpc and npc and npc ~= player then return false end
  end
  for _, entity in ipairs(live.entities or live.npcs or {}) do
    if entity ~= player and ((entity.cellX == lx and entity.cellY == ly)
        or (entity.moving and entity.targetX == lx and entity.targetY == ly)) then
      return false
    end
  end
  player.targetX, player.targetY = lx, ly
  player.moving = true
  player.jumping = true
  player.inGrass, player.grassShake = false, nil
  player.progress = 0
  player.stepFrames = 32
  if type(live.playSfxNamed) == "function" then
    pcall(live.playSfxNamed, live, "Sfx_JumpOverLedge", 0x16)
  end
  return true
end

-- Reverse traversal is intentionally limited to tiles the active game itself
-- identifies as a ledge. Ordinary walls, water, occupied landings and unknown
-- collision types remain blocked.
function RuntimeAdapter:tryReverseLedge(direction)
  if not DELTA[direction] then return false end
  local live = liveWorld(self:world())
  if not live then return false end
  if self:generation() == 1 then
    return self:_tryGen1ReverseLedge(live, direction)
  end
  return self:_tryGen2ReverseLedge(live, direction)
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

local FLIGHT_BLOCKED_METHODS = {
  "interact",
  "checkTrainerSight",
  "checkTrainerBattle",
  "checkWarpOnArrive",
  "checkCarpetWhileStanding",
  "takeWarp",
  "playerCollision",
  "canCollisionWarp",
  "crossConnection",
}

local function flightMethodWrapper(name, original)
  if name == "playerCollision" then
    -- Gen 2 reads the collision under the player's feet after the ordinary
    -- warp check. Door collisions then force their authored walking direction
    -- even when the warp itself was vetoed, which turns an airborne rider
    -- back toward the entrance. Neutral land removes every ground conveyor,
    -- ice/current and door-direction instruction while the flight lease owns
    -- movement; destination collisions still pass through movement.collision.
    return function() return 0 end
  end
  if name ~= "crossConnection" then
    return function() return false end
  end
  -- Gen1 validates the destination cell as if the rider were still walking
  -- on the ground. During a real map connection only, bypass that one terrain
  -- predicate and immediately restore it; all connection coordinate, camera,
  -- music and lifecycle work remains owned by the engine.
  return function(instance, ...)
    local okMap, Map = pcall(require, "src.world.Map")
    if not okMap or type(Map) ~= "table"
        or type(Map.defPassable) ~= "function" then
      return original(instance, ...)
    end
    local previous = Map.defPassable
    local override = function() return true end
    Map.defPassable = override
    local ok, result = pcall(original, instance, ...)
    if Map.defPassable == override then Map.defPassable = previous end
    if not ok then error(result, 0) end
    return result
  end
end

function RuntimeAdapter:_restoreFlightIsolation()
  local lease = self.flightIsolation
  if not lease then return false end
  for _, entry in ipairs(lease.entries or {}) do
    if rawget(lease.live, entry.name) == entry.wrapper then
      rawset(lease.live, entry.name, entry.own)
    end
  end
  self.flightIsolation = nil
  return true
end

-- A high flying rider shares the ground player's logical cell only so map
-- seams and camera tracking keep working. Ground NPCs must neither block nor
-- respond to that invisible projection, so the guarded live-world
-- interaction seams are temporarily replaced for the flight lease.
function RuntimeAdapter:setFlightIsolation(active)
  if not active then
    self:_restoreFlightIsolation()
    return true
  end
  local live = liveWorld(self:world())
  if not live then return nil, "live world unavailable" end
  local lease = self.flightIsolation
  if lease and lease.live == live then
    local intact = true
    for _, entry in ipairs(lease.entries) do
      if rawget(live, entry.name) ~= entry.wrapper then
        intact = false
        break
      end
    end
    if intact then return true end
  end
  self:_restoreFlightIsolation()
  lease = { live = live, entries = {} }
  for _, name in ipairs(FLIGHT_BLOCKED_METHODS) do
    local original = live[name]
    if type(original) == "function" then
      local entry = { name = name, own = rawget(live, name) }
      entry.wrapper = flightMethodWrapper(name, original)
      rawset(live, name, entry.wrapper)
      lease.entries[#lease.entries + 1] = entry
    end
  end
  self.flightIsolation = lease
  return true
end

-- Door and stair cells still need to be traversable in air, but their native
-- arrival handler must not move an airborne player inside the building.
function RuntimeAdapter:suppressWarpAt(x, y)
  local live = liveWorld(self:world())
  if not live then return false end
  local marker = { x = tonumber(x), y = tonumber(y) }
  if self:generation() == 1 then
    live.warpEntryCell = marker
  else
    live.warpCooldown = marker
  end
  return true
end

local function setSurfMusic(adapter, live, active)
  local ok, Music = pcall(require, "src.core.Music")
  local game = adapter:game()
  if not ok or type(Music) ~= "table" or not (game and game.data) then
    return false
  end
  if active and live.map and type(Music.playMap) == "function" then
    if adapter:generation() == 1 then
      pcall(Music.playMap, game.data, live.map.id, false, true)
    else
      local song = type(live.mapMusicSong) == "function"
        and live:mapMusicSong(live.map.id) or nil
      pcall(Music.playMap, game.data, live.map.id, nil, true, nil, song)
    end
  elseif type(Music.setSurfing) == "function" then
    pcall(Music.setSurfing, game.data, false)
  end
  return true
end

-- Direct air/water transfer intentionally skips the ordinary shore step. It
-- changes only the native movement state at the current water cell; PMS then
-- swaps its own controller and renderer through the regular lifecycle.
function RuntimeAdapter:setSurfState(active)
  local live = liveWorld(self:world())
  local player = live and live.player
  if not (live and player) then return nil, "live player unavailable" end
  active = active == true
  if active and self:currentTerrain() ~= "water" then
    return nil, "the current tile is not water"
  end
  if self:generation() == 1 then
    player.surfing = active
    local game = self:game()
    if active and game and game.save then game.save.onBike = false end
    if type(live.syncSurfingPikachu) == "function" then
      pcall(live.syncSurfingPikachu, live)
    end
  elseif type(live.applyPlayerState) == "function" then
    live:applyPlayerState(active and "surf" or "normal")
  else
    live.playerState = active and "surf" or "normal"
  end
  setSurfMusic(self, live, active)
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

-- The only PMS module permitted to touch the live actor shape returned under
-- mod.world. It exists because the audited Gen2 runtime-actor handle lacks the
-- self-driven sync helpers that Gen1 exposes. Every access is guarded and the
-- caller can fall back when the shape changes.

local ActorBridge = {}
ActorBridge.__index = ActorBridge

local RANGE = { up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT" }

function ActorBridge.new(mod, log)
  return setmetatable({ mod = mod, log = log, serial = 0 }, ActorBridge)
end

local function activeWorld(world)
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, value = pcall(world.overworld, world)
  if not ok or type(value) ~= "table" then return nil end
  return value
end

function ActorBridge:_raw(lease)
  local handle = lease and lease.handle
  local npc = handle and handle.npc
  if type(npc) ~= "table" then return nil end
  return npc
end

-- A renderer integration may attach presentation metadata to the same live
-- actor PMS owns. Keeping this guarded accessor here prevents provider code
-- from learning either generation's actor-handle layout.
function ActorBridge:entity(lease)
  return self:_raw(lease)
end

function ActorBridge:spawn(resolved, context)
  local world = context and context.world
  if not world then return nil, "world API unavailable" end
  local position, positionErr = world:current()
  if not position then return nil, positionErr or "no active map" end

  self.serial = self.serial + 1
  local name = "PMS_MOUNT_ACTOR_" .. tostring(self.serial)
  local npcId, spawnErr = world:spawnNpc(position.mapId, {
    name = name,
    x = position.x,
    y = position.y,
    sprite = resolved.spriteId,
    movement = "STAY",
    range = RANGE[position.facing] or "DOWN",
    pmsMountActor = true,
    pmsMountDex = resolved.dex,
    pmsMountMode = resolved.mode,
  })
  if not npcId then return nil, spawnErr or "mount actor spawn failed" end

  local handle, handleErr = world:npc(position.mapId, name)
  if not handle then
    world:removeNpc(npcId)
    return nil, handleErr or "mount actor handle unavailable"
  end

  local lease = {
    world = world,
    mapId = position.mapId,
    npcId = npcId,
    name = name,
    handle = handle,
    resolved = resolved,
    removed = false,
  }
  if type(handle.setPassable) == "function" then
    pcall(handle.setPassable, handle, true)
  else
    local raw = self:_raw(lease)
    if raw then raw.passable = true end
  end
  local ok, err = self:sync(lease, context)
  if not ok then
    self:remove(lease, "initial-sync-failed")
    return nil, err
  end
  return lease
end

function ActorBridge:sync(lease, context)
  if not lease or lease.removed then return nil, "mount actor is gone" end
  local world = lease.world
  local position = world and world:current()
  if not position or position.mapId ~= lease.mapId then
    return nil, "mount actor map changed"
  end

  local raw = self:_raw(lease)
  local live = activeWorld(world)
  local player = live and live.player
  if raw and type(player) == "table"
      and type(player.px) == "number" and type(player.py) == "number" then
    local pose = lease.resolved.pose or {}
    raw.cellX, raw.cellY = player.cellX, player.cellY
    raw.homeX, raw.homeY = player.cellX, player.cellY
    raw.px = player.px + (pose.offsetX or 0)
    -- A tiny y lead makes the y-sort deterministic: the mount is drawn under
    -- the rider. SpriteRenderer floors this to at most one visual pixel.
    raw.py = player.py + (pose.offsetY or 0) - 0.001
    raw.targetX, raw.targetY = player.targetX, player.targetY
    raw.facing = player.facing or position.facing or raw.facing
    raw.moving = player.moving and true or false
    raw.progress = player.progress or 0
    raw.stepFlip = player.stepFlip and true or false
    raw.animClock = player.animClock or player.progress or 0
    raw.passable = true
    raw.frozen = true
    raw.pmsMountActor = true
    raw.pmsMountDex = lease.resolved.dex
    raw.pmsMountMode = lease.resolved.mode
    raw.pmsAltitude = context and context.altitude or 0
    raw.pmsRiderPose = pose
    if raw.def then
      raw.def.pmsMountActor = true
      raw.def.pmsMountDex = lease.resolved.dex
      raw.def.pmsMountMode = lease.resolved.mode
    end
    if self.log then
      self.log:once("actor-bridge-live-shape", "info", "Adapter",
        "using guarded live-actor sync bridge")
    end
    return true
  end

  -- Public Gen1 fallback is cell-accurate but not sub-cell interpolated.
  if lease.handle and type(lease.handle.placeAt) == "function" then
    local ok, err = lease.handle:placeAt(position.x, position.y, position.facing)
    if ok then return true end
    return nil, err
  end
  return nil, "live actor sync capability unavailable"
end

function ActorBridge:remove(lease, reason)
  if not lease or lease.removed then return false end
  lease.removed = true
  local world = lease.world
  if world and type(world.removeNpc) == "function" then
    local ok, result = pcall(world.removeNpc, world, lease.npcId)
    if not ok and self.log then
      self.log:warn("Adapter", "mount actor removal failed: %s", tostring(result))
    end
  end
  return true
end

return ActorBridge

local V = ...
local MotionDynamics = V.require("movement/MotionDynamics")

local SurfController = {}
SurfController.__index = SurfController

local USER_STOP = {
  ["party-menu"] = true,
  ["external"] = true,
  ["user"] = true,
}

function SurfController.new(adapter, settings, progression, log, catalog)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    progression = progression,
    log = log,
    catalog = catalog,
    pending = 0,
    dynamics = MotionDynamics.new("surf"),
  }, SurfController)
end

function SurfController:start(session, mount, runtime, opts)
  self.dynamics:reset(mount and mount.movement and mount.movement.surf)
  if self.adapter:isSurfing() then
    self.pending = 0
    return true
  end
  local mon = (opts and opts.mon)
    or self.adapter:partyMon(opts and opts.partySlot, mount.species,
      opts and opts.partyFingerprint)
  local ok, err = self.progression:withBypass(mon, "surf", function()
    return self.adapter:useFieldAction("surf")
  end)
  if not ok then return nil, err or "Face a water tile to start Surf." end
  self.pending = 3.0
  return true
end

function SurfController:speed(frames, ctx, session)
  local input = ctx and ctx.input
  local sprinting = input and input.isDown and input:isDown("b")
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local profile = mount and mount.movement and mount.movement.surf or {}
  local speciesSpeed = math.max(0.8, math.min(2,
    tonumber(profile.speed) or 1.15))
  local personality = not self.settings
    or self.settings:get("motion_personality") ~= false
  local momentum = self.dynamics:factor(profile, ctx, personality)
  local sprintEnabled = not self.settings
    or self.settings:get("sprint_enabled") ~= false
  local sprintSpeed = self.dynamics:sprint(profile,
    sprintEnabled and sprinting)
  return math.max(1, math.floor((tonumber(frames) or 16)
    / (speciesSpeed * momentum * sprintSpeed) + 0.5))
end

function SurfController:update(session, dt)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local state = self.adapter and type(self.adapter.movementState) == "function"
    and self.adapter:movementState() or nil
  self.dynamics:update(mount and mount.movement.surf, dt,
    state)
  if self.adapter:isSurfing() then
    self.pending = 0
    return true
  end
  if self.pending > 0 then
    self.pending = math.max(0, self.pending - (tonumber(dt) or 0))
    if self.pending > 0 then return true end
    return nil, "Surf did not enter the native movement state."
  end
  return nil, "The native Surf state ended."
end

function SurfController:onCollision(session, collision)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  return self.dynamics:onCollision(mount and mount.movement.surf,
    collision and collision.allowed)
end

function SurfController:prepareStop(session, runtime, reason)
  if not USER_STOP[reason] or not self.adapter:isSurfing() then return true end
  local action = self.adapter:fieldAction("surf")
  if not action or action.label ~= "LEAVE WATER" then
    return nil, "Face dry land before dismounting."
  end
  local ok, err = self.adapter:useFieldAction("surf")
  if not ok then return nil, err or "Unable to leave the water here." end
  return true
end

function SurfController:stop() self.pending = 0 return true end
function SurfController:suspend() return true end
function SurfController:resume() return true end
function SurfController:mapExit() return true end
function SurfController:mapEnter()
  self.pending = self.adapter:isSurfing() and 0 or 2.0
  return true
end

return SurfController

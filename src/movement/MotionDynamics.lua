-- Small deterministic cadence model shared by the three tile-step drivers.
-- It does not move actors itself: the engine keeps collision, animation and
-- map ownership, while PMS varies launch, acceleration and corner response.

local MotionDynamics = {}
MotionDynamics.__index = MotionDynamics

local function clamp(value, low, high)
  return math.max(low, math.min(high, tonumber(value) or low))
end

local function facing(ctx)
  local player = type(ctx) == "table" and ctx.player or nil
  return type(player) == "table" and player.facing
    or (type(ctx) == "table" and (ctx.direction or ctx.dir)) or nil
end

function MotionDynamics.new(mode)
  return setmetatable({ mode = mode, momentum = 1, lastFacing = nil,
    idle = 0 }, MotionDynamics)
end

function MotionDynamics:reset(profile)
  self.momentum = clamp(profile and profile.launch or 0.72, 0.4, 1)
  self.lastFacing = nil
  self.idle = 0
end

function MotionDynamics:update(profile, dt, state)
  if type(state) == "table" and state.moving then
    self.idle = 0
    return true
  end
  self.idle = self.idle + math.max(0, tonumber(dt) or 0)
  if self.idle >= 0.14 then
    self.momentum = clamp(profile and profile.launch or 0.72, 0.4, 1)
    self.lastFacing = nil
  end
  return true
end

function MotionDynamics:onCollision(profile, allowed)
  if allowed then return false end
  local launch = clamp(profile and profile.launch or 0.72, 0.4, 1)
  local braking = clamp(profile and profile.braking or 0.25, 0.05, 0.8)
  self.momentum = math.max(launch, self.momentum - braking)
  return true
end

function MotionDynamics:factor(profile, ctx, enabled)
  if enabled == false then return 1 end
  profile = profile or {}
  local launch = clamp(profile.launch or 0.72, 0.4, 1)
  local acceleration = clamp(profile.acceleration or 0.18, 0.05, 0.5)
  local turnRate = clamp(profile.turnRate or 0.9, 0.5, 1)
  local nextFacing = facing(ctx)
  if self.lastFacing and nextFacing and self.lastFacing ~= nextFacing then
    self.momentum = math.max(launch, self.momentum * turnRate)
  end
  self.lastFacing = nextFacing or self.lastFacing
  self.momentum = math.min(1, math.max(launch, self.momentum) + acceleration)
  return self.momentum
end

function MotionDynamics:sprint(profile, active)
  if not active then return 1 end
  return clamp(profile and profile.boost or 2, 1, 2)
end

return MotionDynamics

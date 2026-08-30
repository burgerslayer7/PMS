local V = ...
local MotionDynamics = V.require("movement/MotionDynamics")

local GroundController = {}
GroundController.__index = GroundController

function GroundController.new(adapter, settings, catalog)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    catalog = catalog,
    dynamics = MotionDynamics.new("ground"),
  }, GroundController)
end

function GroundController:start(session, mount)
  if self.adapter:isSurfing() then
    return nil, "Leave the water before starting a ground ride."
  end
  mount = mount or (self.catalog and session and self.catalog:get(session.dex))
  self.dynamics:reset(mount and mount.movement.ground)
  return true
end

function GroundController:speed(frames, ctx, session)
  local choice = self.settings and self.settings:get("ground_speed") or "normal"
  local input = ctx and ctx.input
  local sprinting = input and input.isDown and input:isDown("b")
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local profile = mount and mount.movement and mount.movement.ground or {}
  local speciesSpeed = math.max(0.8, math.min(2,
    tonumber(profile.speed) or 1.35))
  local settingSpeed = choice == "fast" and 1.15 or 1
  local personality = not self.settings
    or self.settings:get("motion_personality") ~= false
  local momentum = self.dynamics:factor(profile, ctx, personality)
  local sprintEnabled = not self.settings
    or self.settings:get("sprint_enabled") ~= false
  local sprintSpeed = self.dynamics:sprint(profile,
    sprintEnabled and sprinting)
  return math.max(1, math.floor((tonumber(frames) or 16)
    / (speciesSpeed * settingSpeed * momentum * sprintSpeed) + 0.5))
end

function GroundController:update(session, dt)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local state = self.adapter and type(self.adapter.movementState) == "function"
    and self.adapter:movementState() or nil
  return self.dynamics:update(mount and mount.movement.ground, dt,
    state)
end
function GroundController:onCollision(session, collision)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  return self.dynamics:onCollision(mount and mount.movement.ground,
    collision and collision.allowed)
end
function GroundController:stop() return true end
function GroundController:suspend() return true end
function GroundController:resume() return true end
function GroundController:mapExit() return true end
function GroundController:mapEnter() return true end

return GroundController

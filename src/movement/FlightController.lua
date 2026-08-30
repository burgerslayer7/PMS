local V = ...
local MotionDynamics = V.require("movement/MotionDynamics")

local FlightController = {}
FlightController.__index = FlightController

local MIN_FLIGHT_ALTITUDE = 0.78
local TAKEOFF_ALTITUDE = 0.85
local MAX_VISUAL_LIFT = 40

function FlightController.new(adapter, settings, auxiliaryInput, catalog,
    environment)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    auxiliaryInput = auxiliaryInput,
    catalog = catalog,
    environment = environment,
    vertical = 0,
    dynamics = MotionDynamics.new("flight"),
  }, FlightController)
end

local function isolate(adapter, active)
  if adapter and type(adapter.setFlightIsolation) == "function" then
    return adapter:setFlightIsolation(active)
  end
  return true
end

function FlightController:start(session, mount, _, opts)
  opts = opts or {}
  if self.adapter:isSurfing() and not opts.waterTakeoff then
    return nil, "Leave the water before taking off."
  end
  local environmentOk, environmentErr
  if self.environment then
    environmentOk, environmentErr = self.environment:canStart("flight")
  else
    environmentOk = self.adapter:isOutside()
  end
  if not environmentOk then
    return nil, environmentErr or "Flight can only start outdoors."
  end
  local terrain = self.adapter:currentTerrain()
  if terrain and terrain ~= "land"
      and not (opts.waterTakeoff and terrain == "water") then
    return nil, "Takeoff requires a clear land tile."
  end
  self.vertical = 0
  self.dynamics:reset(mount and mount.movement and mount.movement.flight)
  isolate(self.adapter, true)
  local marked, markerErr = self.adapter:setFlightMarker(true,
    session and session.altitude or 0)
  if not marked then
    isolate(self.adapter, false)
    return nil, markerErr
  end
  return true
end

function FlightController:input(session, input)
  self.vertical = self.auxiliaryInput
    and self.auxiliaryInput:altitudeAxis() or 0
  -- Portable fallback using only the eight Game Boy inputs.
  if self.vertical == 0 and input and input.isDown
      and input:isDown("select") then
    if input:isDown("up") then self.vertical = 1 end
    if input:isDown("down") then self.vertical = -1 end
  end
  return true
end

function FlightController:update(session, dt)
  isolate(self.adapter, true)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local profile = mount and mount.movement and mount.movement.flight or {}
  local movementState = self.adapter
    and type(self.adapter.movementState) == "function"
    and self.adapter:movementState() or nil
  self.dynamics:update(profile, dt,
    movementState)
  if session.state == "FLIGHT" and self.vertical ~= 0 then
    local verticalChoice = self.settings
      and self.settings:get("flight_vertical_speed") or "normal"
    local verticalSetting = ({ gentle = 0.75, normal = 1, fast = 1.30 })
      [verticalChoice] or 1
    local verticalSpeed = math.max(0.2, math.min(1.2,
      tonumber(profile.verticalSpeed) or 0.65))
    session.altitude = math.max(MIN_FLIGHT_ALTITUDE, math.min(1,
      session.altitude + self.vertical * (tonumber(dt) or 0)
        * verticalSpeed * verticalSetting))
  end
  local marked, markerErr = self.adapter:setFlightMarker(true,
    session.altitude)
  if not marked then return nil, markerErr end
  return true
end

function FlightController:takeoffTarget()
  return TAKEOFF_ALTITUDE
end

function FlightController:visualLift(session)
  return math.floor(math.max(0, math.min(1,
    tonumber(session and session.altitude) or 0)) * MAX_VISUAL_LIFT + 0.5)
end

function FlightController:canLand()
  if self.adapter:currentTerrain() ~= "land" then
    return nil, "Find a clear land tile before landing."
  end
  if self.adapter:currentTileSymbol() == "+" then
    return nil, "Move away from a door or warp before landing."
  end
  return true
end

function FlightController:speed(frames, ctx, session)
  local choice = self.settings and self.settings:get("flight_speed") or "normal"
  local input = ctx and ctx.input
  local sprinting = input and input.isDown and input:isDown("b")
  local mount = self.catalog and session and self.catalog:get(session.dex)
  local profile = mount and mount.movement and mount.movement.flight or {}
  local speciesSpeed = math.max(0.8, math.min(2,
    tonumber(profile.speed) or 1.50))
  local settingSpeed = ({ normal = 1, fast = 1.20, turbo = 1.40 })[choice] or 1
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

function FlightController:onCollision(session, collision)
  local mount = self.catalog and session and self.catalog:get(session.dex)
  return self.dynamics:onCollision(mount and mount.movement.flight,
    collision and collision.allowed)
end

function FlightController:stop()
  self.vertical = 0
  isolate(self.adapter, false)
  self.adapter:setFlightMarker(false)
  return true
end
function FlightController:suspend()
  self.vertical = 0
  isolate(self.adapter, false)
  return true
end
function FlightController:resume(session)
  if session then
    session.altitude = math.max(MIN_FLIGHT_ALTITUDE,
      tonumber(session.altitude) or TAKEOFF_ALTITUDE)
  end
  isolate(self.adapter, true)
  return true
end
function FlightController:mapExit()
  self.vertical = 0
  isolate(self.adapter, false)
  return true
end
function FlightController:mapEnter(session)
  local environmentOk, environmentErr = true, nil
  if self.environment then
    environmentOk, environmentErr = self.environment:canContinue("flight")
  end
  if not environmentOk then return nil, environmentErr end
  if session then
    session.altitude = math.max(MIN_FLIGHT_ALTITUDE,
      tonumber(session.altitude) or TAKEOFF_ALTITUDE)
  end
  isolate(self.adapter, true)
  return self.adapter:setFlightMarker(true,
    session and session.altitude or 0)
end

return FlightController

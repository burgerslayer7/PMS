local FlightController = {}
FlightController.__index = FlightController

function FlightController.new(adapter, settings)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    vertical = 0,
  }, FlightController)
end

function FlightController:start(session)
  if self.adapter:isSurfing() then
    return nil, "Leave the water before taking off."
  end
  if not self.adapter:isOutside() then
    return nil, "Flight can only start outdoors."
  end
  local terrain = self.adapter:currentTerrain()
  if terrain and terrain ~= "land" then
    return nil, "Takeoff requires a clear land tile."
  end
  self.vertical = 0
  local marked, markerErr = self.adapter:setFlightMarker(true,
    session and session.altitude or 0)
  if not marked then return nil, markerErr end
  return true
end

function FlightController:input(session, input)
  self.vertical = 0
  if not (input and input.isDown and input:isDown("select")) then return true end
  if input:isDown("up") then self.vertical = 1 end
  if input:isDown("down") then self.vertical = -1 end
  return true
end

function FlightController:update(session, dt)
  if session.state == "FLIGHT" and self.vertical ~= 0 then
    session.altitude = math.max(0.20, math.min(1,
      session.altitude + self.vertical * (tonumber(dt) or 0) * 0.65))
  end
  local marked, markerErr = self.adapter:setFlightMarker(true,
    session.altitude)
  if not marked then return nil, markerErr end
  return true
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

function FlightController:speed(frames)
  local choice = self.settings and self.settings:get("flight_speed") or "normal"
  local factor = ({ normal = 0.55, fast = 0.42, turbo = 0.30 })[choice] or 0.55
  return math.max(1, math.floor((tonumber(frames) or 16) * factor + 0.5))
end

function FlightController:stop()
  self.vertical = 0
  self.adapter:setFlightMarker(false)
  return true
end
function FlightController:suspend() self.vertical = 0 return true end
function FlightController:resume() return true end
function FlightController:mapExit() self.vertical = 0 return true end
function FlightController:mapEnter(session)
  return self.adapter:setFlightMarker(true,
    session and session.altitude or 0)
end

return FlightController

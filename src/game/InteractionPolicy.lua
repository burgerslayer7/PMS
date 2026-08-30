-- Gameplay interaction authority while mounted. Renderers and ecosystem
-- providers can query these rules but cannot override the mount state.

local InteractionPolicy = {}
InteractionPolicy.__index = InteractionPolicy

local AIR_STATES = { TAKEOFF = true, FLIGHT = true, LANDING = true }
local AIR_ENCOUNTERS = { aerial = true, wild_skies = true }
local AIR_COLLISIONS = { tile = true, entity = true }

function InteractionPolicy.new()
  return setmetatable({}, InteractionPolicy)
end

function InteractionPolicy:isAirborne(status)
  return type(status) == "table" and status.mode == "flight"
    and AIR_STATES[status.state] == true
end

function InteractionPolicy:allowsEncounter(source, status)
  if not self:isAirborne(status) then return true end
  return AIR_ENCOUNTERS[source] == true
end

function InteractionPolicy:allowsGroundInteraction(status)
  return not self:isAirborne(status)
end

function InteractionPolicy:allowsCollisionBypass(reason, status)
  return self:isAirborne(status) and AIR_COLLISIONS[reason] == true
end

return InteractionPolicy

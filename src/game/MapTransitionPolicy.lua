-- Classifies lifecycle events without inspecting engine internals. The state
-- machine uses the result for diagnostics and for one conservative rule:
-- checkpoint/blackout reconstruction never preserves a live mount lease.

local MapTransitionPolicy = {}
MapTransitionPolicy.__index = MapTransitionPolicy

function MapTransitionPolicy.new(environment)
  return setmetatable({ environment = environment }, MapTransitionPolicy)
end

function MapTransitionPolicy:classify(event, payload)
  if event == "checkpoint.restored" then return "checkpoint" end
  if event == "map.reloaded" then return "reload" end
  local kind = type(payload) == "table" and payload.kind or nil
  if kind == "connection" or kind == "seam" then return "connection" end
  if kind == "door" or kind == "warp" or kind == "teleport"
      or kind == "stairs" then return kind end
  if event == "map.exited" or event == "map.entered" then return "map" end
  return "unknown"
end

function MapTransitionPolicy:preservesMount(event)
  return event ~= "checkpoint.restored"
end

function MapTransitionPolicy:canResume(mode)
  if self.environment then return self.environment:canContinue(mode) end
  return true
end

return MapTransitionPolicy

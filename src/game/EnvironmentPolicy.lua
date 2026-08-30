-- Generation-neutral mount environment rules. The adapter remains the only
-- module that reads live Gen1/Gen2 map shapes; this policy turns that guarded
-- information into stable gameplay decisions.

local EnvironmentPolicy = {}
EnvironmentPolicy.__index = EnvironmentPolicy

local CAVE_ENVIRONMENTS = {
  CAVE = true, DUNGEON = true, UNDERGROUND = true,
}

local function upper(value)
  return string.upper(tostring(value or ""))
end

function EnvironmentPolicy.new(adapter)
  return setmetatable({ adapter = adapter }, EnvironmentPolicy)
end

function EnvironmentPolicy:classify()
  if self.adapter and self.adapter:isOutside() then return "outdoor" end
  local def = self.adapter and self.adapter:mapDefinition() or nil
  if type(def) ~= "table" then return "unknown" end
  local environment = upper(def.environment)
  local tileset = upper(def.tileset)
  if CAVE_ENVIRONMENTS[environment]
      or string.find(environment, "CAVE", 1, true)
      or string.find(environment, "DUNGEON", 1, true)
      or string.find(tileset, "CAVE", 1, true)
      or string.find(tileset, "CAVERN", 1, true)
      or string.find(tileset, "UNDERGROUND", 1, true) then
    return "cave"
  end
  return "indoor"
end

function EnvironmentPolicy:canStart(mode)
  if mode == "flight" and self:classify() ~= "outdoor" then
    return nil, "Flight can only start outdoors."
  end
  return true
end

-- A normal connected-map transition may preserve any mode. Flight is the one
-- mode whose destination environment must still be outdoors; scripted warps
-- into interiors therefore degrade to a clean dismount instead of retaining
-- invisible airspace authority inside a building.
function EnvironmentPolicy:canContinue(mode)
  if mode == "flight" and self:classify() ~= "outdoor" then
    return nil, "Flight cannot continue indoors."
  end
  return true
end

return EnvironmentPolicy

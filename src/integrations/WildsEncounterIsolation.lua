-- Wilds of Kanto owns visible ground and water encounters outside PMS. While
-- the player is airborne, keep its simulation and rendering alive but veto
-- only the final ground-contact battle seam. Wild Skies is a different mod
-- and keeps full authority over aerial encounters.

local WildsEncounterIsolation = {}
WildsEncounterIsolation.__index = WildsEncounterIsolation

local WILDS_ID = "overworld_wild_spawns"

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function WildsEncounterIsolation.new(mod, system, log)
  return setmetatable({ mod = mod, system = system, log = log, lease = nil },
    WildsEncounterIsolation)
end

function WildsEncounterIsolation:_airborne()
  if self.system and type(self.system.isAirborne) == "function" then
    return self.system:isAirborne()
  end
  return false
end

function WildsEncounterIsolation:cleanup()
  local lease = self.lease
  if not lease then return false end
  if rawget(lease.logic, "_startBattle") == lease.wrapper then
    rawset(lease.logic, "_startBattle", lease.own)
  end
  self.lease = nil
  return true
end

function WildsEncounterIsolation:discover()
  local handle = find(self.mod, WILDS_ID)
  local logic = handle and handle.exports and handle.exports.logic
  local original = logic and logic._startBattle
  if type(original) ~= "function" then
    self:cleanup()
    return false, "Wilds encounter seam unavailable"
  end
  if self.lease and self.lease.logic == logic
      and rawget(logic, "_startBattle") == self.lease.wrapper then
    return true
  end

  self:cleanup()
  local owner = self
  local lease = { logic = logic, own = rawget(logic, "_startBattle") }
  lease.wrapper = function(instance, record, ...)
    if owner:_airborne() then
      if owner.log then
        owner.log:once("wilds-ground-encounter-flight", "info", "Integration",
          "suppressed Wilds ground encounter while PMS flight is active")
      end
      return false
    end
    return original(instance, record, ...)
  end
  rawset(logic, "_startBattle", lease.wrapper)
  self.lease = lease
  if self.log then
    self.log:info("Integration", "Wilds ground encounters isolated from Flight")
  end
  return true
end

return WildsEncounterIsolation

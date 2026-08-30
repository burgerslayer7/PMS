-- Public Wild Skies integration. PMS consumes flyers through takeFlyer and
-- starts the exact returned encounter through mod.world:queueScript; it never
-- reads Wild Skies' flyer list, cooldowns, rendering or spawn internals.

local WildSkies = {}
WildSkies.__index = WildSkies

local ID = "wild_skies"

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function WildSkies.new(opts)
  assert(type(opts) == "table", "Wild Skies integration options required")
  return setmetatable({ mod = opts.mod, system = opts.system,
    adapter = opts.adapter, settings = opts.settings, log = opts.log,
    handle = nil, cooldown = 0, lastEncounter = nil }, WildSkies)
end

function WildSkies:discover()
  local handle = find(self.mod, ID)
  local exports = handle and handle.exports
  if not (exports and type(exports.takeFlyer) == "function") then
    self.handle = nil
    return false
  end
  self.handle = handle
  if self.log then
    self.log:once("wild-skies-public", "info", "Integration",
      "Wild Skies public flyer interception is available")
  end
  return true
end

function WildSkies:_tagOrganic()
  local doubles = find(self.mod, "double_battles")
  local tag = doubles and doubles.exports and doubles.exports.tagOrganic
  if type(tag) == "function" then pcall(tag) end
end

function WildSkies:update(dt)
  self.cooldown = math.max(0, self.cooldown - (tonumber(dt) or 0))
  if self.cooldown > 0 then return false end
  if self.settings and self.settings:get("air_encounters") == false then
    return false
  end
  local status = self.system and self.system:snapshot() or {}
  if status.mode ~= "flight" or status.state ~= "FLIGHT" then return false end
  if not (self.adapter and self.adapter:isFreeRoam()) then return false end
  if not self.handle and not self:discover() then return false end
  local take = self.handle and self.handle.exports
    and self.handle.exports.takeFlyer
  if type(take) ~= "function" then self.handle = nil return false end
  local position = self.adapter:position()
  if type(position) ~= "table" then return false end
  local radius = (tonumber(status.altitude) or 0) >= 0.9 and 2 or 1
  local ok, hit = pcall(take, position.x, position.y, radius)
  if not ok then
    self.handle = nil
    if self.log then
      self.log:warn("Integration", "Wild Skies takeFlyer failed: %s",
        tostring(hit))
    end
    return false
  end
  if type(hit) ~= "table" or type(hit.species) ~= "string" then return false end
  local level = math.max(1, math.min(100, math.floor(tonumber(hit.level) or 5)))
  self:_tagOrganic()
  local world = self.adapter:world()
  local queued, queueErr
  if world and type(world.queueScript) == "function" then
    queued, queueErr = world:queueScript({
      { "start_battle", "wild", hit.species, level },
    })
  else
    queueErr = "world script queue unavailable"
  end
  self.cooldown = queued and 2 or 0.5
  if not queued then
    if self.log then
      self.log:warn("Integration", "Wild Skies encounter queue failed: %s",
        tostring(queueErr))
    end
    return false
  end
  self.lastEncounter = { species = hit.species, level = level,
    radius = radius }
  if self.log then
    self.log:info("Integration", "intercepted Wild Skies %s Lv.%d",
      hit.species, level)
  end
  return true
end

function WildSkies:status()
  return {
    available = self.handle ~= nil,
    lastEncounter = self.lastEncounter,
  }
end

function WildSkies:cleanup()
  self.handle = nil
  self.cooldown = 0
  return true
end

return WildSkies

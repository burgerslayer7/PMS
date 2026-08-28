local ProgressionPolicy = {}
ProgressionPolicy.__index = ProgressionPolicy

local REQUIREMENTS = {
  surf = {
    move = "SURF",
    badges = { [1] = "SOULBADGE", [2] = "FOG" },
  },
  flight = {
    move = "FLY",
    badges = { [1] = "THUNDERBADGE", [2] = "STORM" },
  },
}

function ProgressionPolicy.new(adapter, settings, log)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    log = log,
    bypassMon = nil,
  }, ProgressionPolicy)
end

function ProgressionPolicy:required()
  return not self.settings or self.settings:get("require_progression") ~= false
end

function ProgressionPolicy:monFor(mount, opts)
  opts = opts or {}
  return opts.mon or self.adapter:partyMon(opts.partySlot, mount.species,
    opts.partyFingerprint)
end

function ProgressionPolicy:canMount(mount, mode, opts)
  if mode ~= "surf" and self.adapter:isSurfing() then
    return nil, "Leave the water before changing mount mode."
  end
  if mode == "flight" and not self.adapter:isOutside() then
    return nil, "Flight can only start outdoors."
  end
  local requirement = REQUIREMENTS[mode]
  if not requirement or not self:required() then return true end
  local mon = self:monFor(mount, opts)
  if not mon then return nil, "The selected Pokemon is not in the party." end
  if not self.adapter:knows(mon, requirement.move) then
    return nil, mount.species .. " must know " .. requirement.move .. "."
  end
  local badge = requirement.badges[self.adapter:generation()]
  if badge and not self.adapter:hasBadge(badge) then
    return nil, "The required badge has not been earned yet."
  end
  if mode == "surf" and not self.adapter:isSurfing() then
    local action = self.adapter:fieldAction("surf")
    if not action then return nil, "Face a water tile to start Surf." end
  end
  return true
end

function ProgressionPolicy:withBypass(mon, mode, fn)
  if self:required() then return fn() end
  local requirement = REQUIREMENTS[mode]
  self.bypassMon = mon
  local function run()
    if requirement and requirement.badges[self.adapter:generation()] then
      return self.adapter:withTemporaryBadge(
        requirement.badges[self.adapter:generation()], fn)
    end
    return fn()
  end
  local result = { pcall(run) }
  self.bypassMon = nil
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2)
end

-- Hook arm used only while a progression-disabled field action is executing.
-- Calling next first preserves every native answer and other mod unlock.
function ProgressionPolicy:fieldMoveEligibility(next, moveId, ctx)
  local mon, slot = next(moveId, ctx)
  if mon then return mon, slot end
  if not self:required() and self.bypassMon
      and (moveId == "SURF" or moveId == "FLY") then
    return self.bypassMon
  end
  return nil
end

return ProgressionPolicy

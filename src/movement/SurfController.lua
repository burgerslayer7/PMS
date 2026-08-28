local SurfController = {}
SurfController.__index = SurfController

local USER_STOP = {
  ["party-menu"] = true,
  ["external"] = true,
  ["user"] = true,
}

function SurfController.new(adapter, settings, progression, log)
  return setmetatable({
    adapter = adapter,
    settings = settings,
    progression = progression,
    log = log,
    pending = 0,
  }, SurfController)
end

function SurfController:start(session, mount, runtime, opts)
  if self.adapter:isSurfing() then
    self.pending = 0
    return true
  end
  local mon = (opts and opts.mon)
    or self.adapter:partyMon(opts and opts.partySlot, mount.species,
      opts and opts.partyFingerprint)
  local ok, err = self.progression:withBypass(mon, "surf", function()
    return self.adapter:useFieldAction("surf")
  end)
  if not ok then return nil, err or "Face a water tile to start Surf." end
  self.pending = 3.0
  return true
end

function SurfController:speed(frames)
  return math.max(1, math.floor((tonumber(frames) or 16) * 0.72 + 0.5))
end

function SurfController:update(session, dt)
  if self.adapter:isSurfing() then
    self.pending = 0
    return true
  end
  if self.pending > 0 then
    self.pending = math.max(0, self.pending - (tonumber(dt) or 0))
    if self.pending > 0 then return true end
    return nil, "Surf did not enter the native movement state."
  end
  return nil, "The native Surf state ended."
end

function SurfController:prepareStop(session, runtime, reason)
  if not USER_STOP[reason] or not self.adapter:isSurfing() then return true end
  local action = self.adapter:fieldAction("surf")
  if not action or action.label ~= "LEAVE WATER" then
    return nil, "Face dry land before dismounting."
  end
  local ok, err = self.adapter:useFieldAction("surf")
  if not ok then return nil, err or "Unable to leave the water here." end
  return true
end

function SurfController:stop() self.pending = 0 return true end
function SurfController:suspend() return true end
function SurfController:resume() return true end
function SurfController:mapExit() return true end
function SurfController:mapEnter()
  self.pending = self.adapter:isSurfing() and 0 or 2.0
  return true
end

return SurfController

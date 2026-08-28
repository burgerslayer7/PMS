local Persistence = {}
Persistence.__index = Persistence

local KEY = "mount_session_v1"

local function copyRecord(record)
  if type(record) ~= "table" then return nil end
  return {
    active = record.active == true,
    dex = tonumber(record.dex),
    mode = record.mode,
    partySlot = tonumber(record.partySlot),
    partyFingerprint = record.partyFingerprint,
    altitude = tonumber(record.altitude) or 0,
  }
end

function Persistence.new(mod)
  return setmetatable({ mod = mod }, Persistence)
end

function Persistence:write(session, active)
  local save = self.mod and self.mod.save
  if not (save and type(save.set) == "function") then return false end
  save:set(KEY, {
    active = active == true,
    dex = session and session.dex,
    mode = session and session.mode,
    partySlot = session and session.partySlot,
    partyFingerprint = session and session.partyFingerprint,
    altitude = session and session.altitude or 0,
  })
  return true
end

function Persistence:loadActive()
  local save = self.mod and self.mod.save
  if not (save and type(save.get) == "function") then return nil end
  local record = copyRecord(save:get(KEY))
  if not record or not record.active or not record.dex or not record.mode then
    return nil
  end
  return record
end

return Persistence

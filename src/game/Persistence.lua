local Persistence = {}
Persistence.__index = Persistence

local KEY = "mount_state_v2"
local LEGACY_KEY = "mount_session_v1"

local MODES = { "ground", "surf", "flight" }

local function copySelection(record)
  if type(record) ~= "table" then return nil end
  local dex = tonumber(record.dex)
  if not dex then return nil end
  return {
    dex = dex,
    partySlot = tonumber(record.partySlot),
    partyFingerprint = record.partyFingerprint,
  }
end

local function copySelections(records)
  local selections = {}
  for _, mode in ipairs(MODES) do
    local selection = copySelection(type(records) == "table"
      and records[mode] or nil)
    if selection then selections[mode] = selection end
  end
  return selections
end

local function copyRecord(record)
  if type(record) ~= "table" then return nil end
  return {
    active = record.active == true,
    dex = tonumber(record.dex),
    mode = record.mode,
    partySlot = tonumber(record.partySlot),
    partyFingerprint = record.partyFingerprint,
    altitude = tonumber(record.altitude) or 0,
    selections = copySelections(record.selections),
  }
end

function Persistence.new(mod)
  return setmetatable({ mod = mod }, Persistence)
end

function Persistence:write(session, active, selections)
  local save = self.mod and self.mod.save
  if not (save and type(save.set) == "function") then return false end
  save:set(KEY, {
    schema = 2,
    active = active == true,
    dex = session and session.dex,
    mode = session and session.mode,
    partySlot = session and session.partySlot,
    partyFingerprint = session and session.partyFingerprint,
    altitude = session and session.altitude or 0,
    selections = copySelections(selections),
  })
  return true
end

function Persistence:load()
  local save = self.mod and self.mod.save
  if not (save and type(save.get) == "function") then return nil end
  local record = copyRecord(save:get(KEY))
  if record then return record end
  -- One-way compatibility read. The next save writes the stable v2 identity
  -- and independent mode selections without mutating the legacy entry.
  return copyRecord(save:get(LEGACY_KEY))
end

function Persistence:loadActive()
  local record = self:load()
  if not record or not record.active or not record.dex or not record.mode then
    return nil
  end
  return record
end

function Persistence:loadSelections()
  local record = self:load()
  return record and copySelections(record.selections) or {}
end

return Persistence

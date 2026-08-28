-- Capability-only integration with Voxel Companion API v1. PMS contributes no
-- draw calls and no camera transform: the host keeps full renderer ownership.
-- The background phase is used only as a reliable "voxel frame is active"
-- signal, unlike installation checks which remain true while voxel mode is off.

local VoxelCompanion = {}
VoxelCompanion.__index = VoxelCompanion

local HOST_IDS = {
  "BATTLE_ART_VOXEL_FORK",
  "DRAMALESS_SHAPE",
}

function VoxelCompanion.new(mod, log)
  return setmetatable({
    mod = mod,
    log = log,
    tickIndex = 0,
    records = {},
    discovery = {},
  }, VoxelCompanion)
end

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function VoxelCompanion:_observe(id, context)
  local record = self.records[id]
  if not record then return end
  record.lastTick = self.tickIndex
  local camera = context and context.camera
  local frame = context and context.frame
  record.cameraMode = type(camera) == "table" and camera.mode
    or (type(frame) == "table" and frame.mode) or record.cameraMode
end

function VoxelCompanion:_register(id, handle)
  local exports = handle and handle.exports
  local wire = exports and exports.voxel_companion
  if type(wire) ~= "table" or wire.api ~= 1
      or type(wire.register) ~= "function" then
    return nil, "Voxel Companion API v1 unavailable"
  end
  if type(wire.capabilities) ~= "table"
      or not wire.capabilities.render_phases then
    return nil, "host has no render_phases capability"
  end

  local owner = self
  local record = {
    id = id,
    version = handle.version,
    host = wire.host,
    lastTick = -1000,
  }
  self.records[id] = record
  local spec = {
    api = 1,
    id = "pokemon-mount-system.renderer-observer",
    name = "Pokemon Mount System renderer observer",
    version = "0.1.0",
    priority = 900,
    phases = {
      background = function(context)
        owner:_observe(id, context)
      end,
    },
    lifecycle = {
      dispose = function()
        record.lastTick = -1000
      end,
    },
  }
  local ok, receipt, err = pcall(wire.register, spec)
  if not ok or not receipt then
    self.records[id] = nil
    return nil, ok and err or receipt
  end
  record.receipt = receipt
  if self.log then
    self.log:info("Integration", "Voxel Companion API v1 attached to %s", id)
  end
  return true
end

function VoxelCompanion:discover()
  for _, id in ipairs(HOST_IDS) do
    if not self.discovery[id] then
      local handle = find(self.mod, id)
      if handle then
        local ok, err = self:_register(id, handle)
        self.discovery[id] = ok and true or tostring(err)
        if not ok and self.log then
          self.log:warn("Integration", "%s companion adapter unavailable: %s",
            id, tostring(err))
        end
      end
    end
  end
  return true
end

function VoxelCompanion:advance()
  self.tickIndex = self.tickIndex + 1
end

function VoxelCompanion:activeHost()
  local selected
  for _, id in ipairs(HOST_IDS) do
    local record = self.records[id]
    if record and self.tickIndex - record.lastTick <= 3 then
      local receiptActive = true
      if record.receipt and type(record.receipt.is_active) == "function" then
        local ok, value = pcall(record.receipt.is_active, record.receipt)
        receiptActive = ok and value == true
      end
      if receiptActive then selected = record break end
    end
  end
  return selected
end

function VoxelCompanion:status()
  local active = self:activeHost()
  local installed = {}
  for id, record in pairs(self.records) do
    installed[#installed + 1] = {
      id = id,
      version = record.version,
      active = record == active,
      cameraMode = record.cameraMode,
    }
  end
  table.sort(installed, function(a, b) return a.id < b.id end)
  return { active = active and active.id or nil, installed = installed }
end

function VoxelCompanion:cleanup()
  for _, record in pairs(self.records) do
    local receipt = record.receipt
    if receipt and type(receipt.dispose) == "function" then
      pcall(receipt.dispose, receipt, {}, "pms-cleanup")
    end
  end
  self.records = {}
  self.discovery = {}
  return true
end

return VoxelCompanion

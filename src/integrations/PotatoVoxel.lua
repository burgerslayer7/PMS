-- Capability adapter for PotatoVoxel. PMS never loads PotatoVoxel modules or
-- touches its camera. The engine's own voxel pipeline level is the active-mode
-- signal; the mod handle is used only to confirm that PotatoVoxel owns it.

local PotatoVoxel = {}
PotatoVoxel.__index = PotatoVoxel

local HOST_ID = "potato_voxel"

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

local function pipelineLevel(system)
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if ok and type(Pipelines) == "table"
      and type(Pipelines.level) == "function" then
    local levelOk, level = pcall(Pipelines.level, "voxel")
    if not levelOk then levelOk, level = pcall(Pipelines.level, Pipelines,
      "voxel") end
    if levelOk and tonumber(level) then return tonumber(level) end
  end

  -- Guarded fallback for engine builds where Pipelines.level is not exported.
  local runtime = system and system.runtime
  local game = runtime and runtime.game
  local save = game and game.save
  local options = save and save.options
  local levels = options and options.pipelines
  return tonumber(levels and levels.voxel) or 0
end

function PotatoVoxel.new(mod, log)
  return setmetatable({
    mod = mod,
    log = log,
    handle = nil,
    record = nil,
    scanned = false,
  }, PotatoVoxel)
end

function PotatoVoxel:discover()
  if self.scanned and self.handle then return true end
  self.scanned = true
  local handle = find(self.mod, HOST_ID)
  if not handle then return false end
  self.handle = handle
  self.record = {
    id = HOST_ID,
    version = handle.version,
    host = HOST_ID,
    active = false,
    level = 0,
    loading = false,
  }
  if self.log then
    self.log:info("Integration", "PotatoVoxel capability adapter discovered")
  end
  return true
end

function PotatoVoxel:advance(system)
  if not self.handle then self:discover() end
  local record = self.record
  if not record then return false end
  record.level = pipelineLevel(system)
  record.active = record.level >= 1
  record.loading = false
  local exports = self.handle and self.handle.exports
  if exports and type(exports.isLoading) == "function" then
    local ok, loading = pcall(exports.isLoading)
    if ok then record.loading = loading == true end
  end
  return record.active
end

function PotatoVoxel:activeHost()
  return self.record and self.record.active and self.record or nil
end

function PotatoVoxel:status()
  local record = self.record
  return {
    installed = record ~= nil,
    active = record and record.active or false,
    id = record and record.id or HOST_ID,
    version = record and record.version or nil,
    level = record and record.level or 0,
    loading = record and record.loading or false,
    -- Feature detection is intentional: PotatoVoxel release metadata has
    -- historically not matched its tag, so PMS never gates on a version.
    detection = "engine-voxel-pipeline",
  }
end

function PotatoVoxel:cleanup()
  self.handle = nil
  self.record = nil
  self.scanned = false
  return true
end

return PotatoVoxel

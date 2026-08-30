-- Public, diagnostic-only Crystal 251 integration. Crystal 251 extends the
-- Gen1 content registry before PMS resolves the party; PMS must not treat it
-- as a Gen2 runtime or call its battle implementation.

local Crystal251 = {}
Crystal251.__index = Crystal251

local ID = "CRYSTAL_251"

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function Crystal251.new(mod, adapter, log)
  return setmetatable({ mod = mod, adapter = adapter, log = log,
    receipt = nil }, Crystal251)
end

function Crystal251:discover()
  local handle = find(self.mod, ID)
  if not handle then
    self.receipt = nil
    return false
  end
  local exports = handle.exports or {}
  local dexSize = tonumber(exports.dexSize)
  local generation = self.adapter and self.adapter:generation() or nil
  local receipt = {
    installed = true,
    active = generation == 1 and dexSize and dexSize >= 251 or false,
    version = handle.version,
    revision = type(exports.revision) == "string" and exports.revision or nil,
    fingerprint = type(exports.fingerprint) == "string"
      and exports.fingerprint or nil,
    dexSize = dexSize,
    generation = generation,
  }
  if generation ~= 1 then
    receipt.reason = "native Gen2 runtime owns this game"
  elseif not dexSize or dexSize < 251 then
    receipt.reason = "public 251-species dataset unavailable"
  end
  self.receipt = receipt
  if self.log then
    if receipt.active then
      self.log:once("crystal-251-active", "info", "Integration",
        "Crystal 251 public Gen1 dataset detected (%s)",
        tostring(receipt.revision or receipt.version or "unknown"))
    else
      self.log:once("crystal-251-inactive", "info", "Integration",
        "Crystal 251 installed but inactive: %s", tostring(receipt.reason))
    end
  end
  return receipt.active
end

function Crystal251:status()
  if not self.receipt then
    return { installed = false, active = false }
  end
  local out = {}
  for key, value in pairs(self.receipt) do out[key] = value end
  return out
end

function Crystal251:cleanup()
  self.receipt = nil
  return true
end

return Crystal251

local MountCatalog = {}
MountCatalog.__index = MountCatalog

local VALID_MODES = { ground = true, surf = true, flight = true }

local PROFILE_RANGES = {
  speed = { 0.8, 2.0 }, acceleration = { 0.05, 0.5 },
  braking = { 0.05, 0.8 }, launch = { 0.4, 1.0 },
  turnRate = { 0.5, 1.0 }, boost = { 1.0, 2.0 },
  verticalSpeed = { 0.2, 1.2 },
}

local function copyTable(value)
  local out = {}
  for key, item in pairs(value or {}) do
    out[key] = type(item) == "table" and copyTable(item) or item
  end
  return out
end

local function mergeTable(base, override)
  local out = copyTable(base)
  for key, value in pairs(override or {}) do
    out[key] = type(value) == "table" and copyTable(value) or value
  end
  return out
end

local function normalize(source, defaults)
  assert(type(source) == "table", "mount row must be a table")
  assert(type(source.dex) == "number" and source.dex == math.floor(source.dex)
    and source.dex >= 1 and source.dex <= 251, "invalid mount dex")
  assert(type(source.species) == "string" and source.species ~= "",
    "invalid mount species")
  assert(type(source.heightM) == "number" and source.heightM > 0,
    "invalid Pokédex height for " .. tostring(source.species))
  assert(type(source.modes) == "table", "mount modes must be a table")

  local modes, movement = {}, {}
  for _, mode in ipairs(source.modes) do
    assert(VALID_MODES[mode], "invalid mount mode: " .. tostring(mode))
    assert(not modes[mode], "duplicate mount mode: " .. tostring(mode))
    modes[mode] = true
    movement[mode] = mergeTable((defaults or {})[mode],
      (source.movement or {})[mode])
    for key, range in pairs(PROFILE_RANGES) do
      local raw = movement[mode][key]
      if raw ~= nil then
        local value = tonumber(raw)
        assert(value and value >= range[1] and value <= range[2],
          ("%s %s %s must be between %.2f and %.2f"):format(
            source.species, mode, key, range[1], range[2]))
        movement[mode][key] = value
      end
    end
  end

  return {
    dex = source.dex,
    species = source.species,
    heightM = source.heightM,
    modes = modes,
    movement = movement,
    traits = copyTable(source.traits),
  }
end

function MountCatalog.new(config)
  assert(type(config) == "table", "mount config must be a table")
  local self = setmetatable({ byDex = {}, bySpecies = {}, ordered = {} },
    MountCatalog)
  for _, source in ipairs(config.mounts or {}) do
    local row = normalize(source, config.defaults)
    assert(not self.byDex[row.dex], "duplicate mount dex: " .. row.dex)
    assert(not self.bySpecies[row.species],
      "duplicate mount species: " .. row.species)
    self.byDex[row.dex] = row
    self.bySpecies[row.species] = row
    self.ordered[#self.ordered + 1] = row
  end
  table.sort(self.ordered, function(a, b) return a.dex < b.dex end)
  return self
end

function MountCatalog:get(id)
  if type(id) == "number" then return self.byDex[id] end
  if type(id) == "string" then return self.bySpecies[string.upper(id)] end
  return nil
end

function MountCatalog:supports(id, mode)
  local row = self:get(id)
  return row ~= nil and row.modes[mode] == true
end

function MountCatalog:forMode(mode)
  local out = {}
  for _, row in ipairs(self.ordered) do
    if row.modes[mode] then out[#out + 1] = row end
  end
  return out
end

function MountCatalog:count()
  return #self.ordered
end

function MountCatalog:publicList(mode)
  local source = mode and self:forMode(mode) or self.ordered
  local out = {}
  for _, row in ipairs(source) do
    local modes = {}
    for _, candidate in ipairs({ "ground", "surf", "flight" }) do
      if row.modes[candidate] then modes[#modes + 1] = candidate end
    end
    out[#out + 1] = {
      dex = row.dex,
      species = row.species,
      heightM = row.heightM,
      modes = modes,
    }
  end
  return out
end

return MountCatalog

local ProviderRegistry = {}
ProviderRegistry.__index = ProviderRegistry

local function validProvider(provider)
  if type(provider) ~= "table" then return nil, "provider must be a table" end
  if provider.api ~= 1 then return nil, "provider api must be 1" end
  if type(provider.id) ~= "string" or provider.id == "" then
    return nil, "provider id is required"
  end
  if provider.priority ~= nil and type(provider.priority) ~= "number" then
    return nil, "provider priority must be numeric"
  end
  if type(provider.resolve) ~= "function" then
    return nil, "provider resolve function is required"
  end
  if provider.probe ~= nil and type(provider.probe) ~= "function" then
    return nil, "provider probe must be a function"
  end
  return true
end

function ProviderRegistry.new(log)
  return setmetatable({
    byId = {},
    ordered = {},
    revision = 0,
    probeCache = {},
    failures = {},
    log = log,
  }, ProviderRegistry)
end

function ProviderRegistry:_sort()
  table.sort(self.ordered, function(a, b)
    local ap, bp = tonumber(a.priority) or 0, tonumber(b.priority) or 0
    if ap ~= bp then return ap > bp end
    return a.id < b.id
  end)
end

function ProviderRegistry:register(provider, source)
  local ok, err = validProvider(provider)
  if not ok then return nil, err end
  if self.byId[provider.id] then
    return nil, "duplicate provider id: " .. provider.id
  end
  self.byId[provider.id] = provider
  self.ordered[#self.ordered + 1] = provider
  self.failures[provider.id] = 0
  self.revision = self.revision + 1
  self:_sort()
  if self.log then
    self.log:info("Provider", "registered %s (%s)", provider.id,
      source or "builtin")
  end
  local active = true
  return function()
    if not active then return false end
    active = false
    return self:unregister(provider.id)
  end
end

function ProviderRegistry:unregister(id)
  local provider = self.byId[id]
  if not provider then return false end
  self.byId[id] = nil
  self.failures[id] = nil
  for index = #self.ordered, 1, -1 do
    if self.ordered[index] == provider then table.remove(self.ordered, index) end
  end
  self:invalidate(id)
  self.revision = self.revision + 1
  if type(provider.cleanup) == "function" then pcall(provider.cleanup, provider) end
  return true
end

function ProviderRegistry:list()
  local out = {}
  for index, provider in ipairs(self.ordered) do out[index] = provider end
  return out
end

function ProviderRegistry:isHealthy(id)
  return self.byId[id] ~= nil and (self.failures[id] or 0) < 3
end

function ProviderRegistry:recordFailure(id, reason)
  if not self.byId[id] then return end
  self.failures[id] = (self.failures[id] or 0) + 1
  if self.log then
    self.log:warn("Provider", "%s failure %d/3: %s", id,
      self.failures[id], tostring(reason))
  end
end

function ProviderRegistry:recordSuccess(id)
  if self.byId[id] then self.failures[id] = 0 end
end

local function probeKey(provider, context)
  return table.concat({
    provider.id,
    tostring(context and context.generation or "?"),
    tostring(context and context.activeRenderer or "native2d"),
    tostring(context and context.spriteSource or "auto"),
  }, "|")
end

function ProviderRegistry:probe(provider, context)
  if not self:isHealthy(provider.id) then return nil, "provider unhealthy" end
  local key = probeKey(provider, context)
  local cached = self.probeCache[key]
  if cached ~= nil then
    if cached == false then return nil, "provider unavailable" end
    return cached
  end
  local receipt = { available = true, kind = "external2d", fit = 0 }
  if type(provider.probe) == "function" then
    local ok, value, err = pcall(provider.probe, provider, context)
    if not ok then
      self:recordFailure(provider.id, value)
      self.probeCache[key] = false
      return nil, value
    end
    if value == nil or value == false then
      self.probeCache[key] = false
      return nil, err or "provider unavailable"
    end
    receipt = value == true and receipt or value
  end
  if type(receipt) ~= "table" then
    self:recordFailure(provider.id, "invalid capability receipt")
    self.probeCache[key] = false
    return nil, "invalid capability receipt"
  end
  if receipt.available == false then
    self.probeCache[key] = false
    return nil, "provider unavailable"
  end
  self.probeCache[key] = receipt
  return receipt
end

function ProviderRegistry:invalidate(id)
  if id == nil then
    self.probeCache = {}
    -- Explicit invalidation means the environment changed (map, renderer or
    -- hot-reload). A provider quarantined by transient actor/map failures must
    -- be allowed to prove itself healthy again.
    for providerId in pairs(self.byId) do self.failures[providerId] = 0 end
    return
  end
  local prefix = id .. "|"
  for key in pairs(self.probeCache) do
    if string.sub(key, 1, #prefix) == prefix then self.probeCache[key] = nil end
  end
  if self.byId[id] then self.failures[id] = 0 end
end

function ProviderRegistry:cleanup()
  local ids = {}
  for _, provider in ipairs(self.ordered) do ids[#ids + 1] = provider.id end
  for _, id in ipairs(ids) do self:unregister(id) end
end

return ProviderRegistry

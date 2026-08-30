local RenderResolver = {}
RenderResolver.__index = RenderResolver

local KIND_FIT = {
  stadium = 400,
  voxel = 300,
  external2d = 200,
  builtin2d = 100,
  technical = 0,
}

function RenderResolver.new(registry, log)
  return setmetatable({ registry = registry, log = log, cache = {} },
    RenderResolver)
end

local function preferenceBonus(preferred, receipt)
  if not preferred or preferred == "auto" then return 0 end
  if preferred == receipt.kind then return 10000 end
  if preferred == "native2d"
      and (receipt.kind == "external2d" or receipt.kind == "builtin2d") then
    return 10000
  end
  return -1000
end

local function activeBonus(active, receipt)
  if not active then return 0 end
  if receipt.renderer == active then return 5000 end
  if active == "native2d"
      and (receipt.kind == "external2d" or receipt.kind == "builtin2d") then
    return 1000
  end
  return 0
end

local function spriteSourceBonus(source, active, preferred, receipt)
  local explicit = preferred and preferred ~= "auto"
  local native2dLane = preferred == "native2d"
    or (not explicit and active == "native2d")
  if not native2dLane then return 0 end
  if source == "builtin" then
    if receipt.kind == "builtin2d" then return 1000000 end
    if receipt.kind == "external2d" then return -1000000 end
  elseif source == "wilds" and receipt.spriteSource == "wilds" then
    return 1000000
  end
  return 0
end

function RenderResolver:_rank(context)
  local ranked = {}
  for _, provider in ipairs(self.registry:list()) do
    local receipt = self.registry:probe(provider, context)
    if receipt then
      ranked[#ranked + 1] = {
        provider = provider,
        receipt = receipt,
        score = (tonumber(provider.priority) or 0)
          + (tonumber(receipt.fit) or 0)
          + (KIND_FIT[receipt.kind] or 0)
          + preferenceBonus(context and context.preferredRenderer, receipt)
          + activeBonus(context and context.activeRenderer, receipt)
          + spriteSourceBonus(context and context.spriteSource,
            context and context.activeRenderer,
            context and context.preferredRenderer, receipt),
      }
    end
  end
  table.sort(ranked, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.provider.id < b.provider.id
  end)
  return ranked
end

function RenderResolver:acquire(dex, mode, context)
  context = context or {}
  local reasons = {}
  for _, candidate in ipairs(self:_rank(context)) do
    local provider = candidate.provider
    local ok, resolved, reason = pcall(provider.resolve, provider, dex, mode,
      context)
    if not ok then
      self.registry:recordFailure(provider.id, resolved)
      reasons[#reasons + 1] = provider.id .. ": " .. tostring(resolved)
    elseif resolved == nil or resolved == false then
      reasons[#reasons + 1] = provider.id .. ": "
        .. tostring(reason or "unsupported")
    else
      local lease = { provider = provider, resolved = resolved, finished = false }
      if type(provider.begin) == "function" then
        local beginOk, value, beginErr = pcall(provider.begin, provider,
          resolved, context)
        if not beginOk or value == nil or value == false then
          local failure = beginOk and beginErr or value
          self.registry:recordFailure(provider.id, failure)
          reasons[#reasons + 1] = provider.id .. ": " .. tostring(failure)
          lease = nil
        else
          lease.value = value
        end
      else
        lease.value = resolved
      end
      if lease then
        self.registry:recordSuccess(provider.id)
        if self.log then
          self.log:info("Provider", "selected %s for dex %03d %s",
            provider.id, dex, mode)
        end
        return lease
      end
    end
  end
  return nil, table.concat(reasons, "; ")
end

function RenderResolver:update(lease, context)
  if not lease or lease.finished then return false end
  local provider = lease.provider
  if type(provider.update) ~= "function" then return true end
  local ok, result = pcall(provider.update, provider, lease.value, context)
  if not ok then
    self.registry:recordFailure(provider.id, result)
    self:release(lease, "provider-error")
    return nil, result
  end
  if result == false then
    self.registry:recordFailure(provider.id, "provider lease became unavailable")
    self:release(lease, "provider-unavailable")
    return nil, "provider lease became unavailable"
  end
  return true
end

function RenderResolver:release(lease, reason)
  if not lease or lease.finished then return false end
  lease.finished = true
  local provider = lease.provider
  if type(provider.finish) == "function" then
    local ok, err = pcall(provider.finish, provider, lease.value,
      reason or "released")
    if not ok then self.registry:recordFailure(provider.id, err) end
  end
  return true
end

function RenderResolver:invalidate()
  self.cache = {}
  self.registry:invalidate()
end

return RenderResolver

local RiderPose = {}
RiderPose.__index = RiderPose

local function copy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function merge(base, override)
  local out = copy(base)
  for key, value in pairs(override or {}) do
    if key ~= "directions" then out[key] = value end
  end
  return out
end

function RiderPose.new(config, scaleResolver)
  assert(type(config) == "table", "rider profile config required")
  return setmetatable({
    defaults = config.defaults or {},
    profiles = config.profiles or {},
    scaleResolver = scaleResolver,
  }, RiderPose)
end

function RiderPose:key(dex, mode)
  return string.format("%03d:%s", dex, mode)
end

function RiderPose:resolve(dex, mode, direction, providerProfiles)
  local result = merge(self.defaults[mode],
    self.profiles[self:key(dex, mode)])
  local provider = providerProfiles
    and providerProfiles[self:key(dex, mode)] or nil
  result = merge(result, provider)
  local directional = (provider and provider.directions)
    or (self.profiles[self:key(dex, mode)]
      and self.profiles[self:key(dex, mode)].directions)
  if directional and directional[direction] then
    result = merge(result, directional[direction])
  end
  local frameSize = self.scaleResolver
    and self.scaleResolver:frameSize(dex) or tonumber(result.frameSize) or 16
  result.frameWidth = math.max(16, math.floor(frameSize + 0.5))
  result.frameHeight = result.frameWidth
  result.scale = result.frameWidth / 16
  result.anchorX = tonumber(result.anchorX) or result.frameWidth / 2
  result.anchorY = tonumber(result.anchorY)
    or result.frameHeight * (tonumber(result.anchorRatio) or 0.75)
  result.offsetX = tonumber(result.offsetX) or 0
  result.offsetY = tonumber(result.offsetY) or 0
  result.bob = tonumber(result.bob) or 0
  result.riderLift = tonumber(result.riderLift)
    or (self.scaleResolver and self.scaleResolver:riderLift(dex, mode)) or 1
  result.clipRider = result.clipRider ~= false
  return result
end

return RiderPose

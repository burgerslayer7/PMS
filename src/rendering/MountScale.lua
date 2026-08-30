local MountScale = {}
MountScale.__index = MountScale

local BASE_HEIGHT_M = 1.6
local BASE_FRAME_PX = 20
local MIN_FRAME_PX = 16
local MAX_FRAME_PX = 40

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

-- Pokédex heights describe total body length for serpentine species. A linear
-- conversion would make Gyarados/Lugia cover most of the viewport, so the
-- square-root curve preserves the ordering while compressing the extremes.
function MountScale.frameSizeForHeight(heightM)
  heightM = tonumber(heightM) or BASE_HEIGHT_M
  local pixels = math.floor(
    BASE_FRAME_PX * math.sqrt(math.max(0.1, heightM) / BASE_HEIGHT_M) + 0.5)
  return clamp(pixels, MIN_FRAME_PX, MAX_FRAME_PX)
end

function MountScale.new(catalog, log)
  assert(type(catalog) == "table", "mount catalog required")
  return setmetatable({ catalog = catalog, log = log }, MountScale)
end

function MountScale:height(id)
  local mount = self.catalog:get(id)
  return mount and mount.heightM or nil
end

function MountScale:frameSize(id)
  return MountScale.frameSizeForHeight(self:height(id))
end

function MountScale:riderLift(id, mode)
  local size = self:frameSize(id)
  local lift = math.max(1, math.floor((size - 16) * 0.24 + 0.5))
  if mode == "surf" or mode == "flight" then lift = lift + 1 end
  return lift
end

function MountScale:flightLift(altitude)
  return math.floor(clamp(tonumber(altitude) or 0, 0, 1) * 24 + 0.5)
end

return MountScale

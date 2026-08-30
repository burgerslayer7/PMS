-- Optional native-2D provider backed by Wilds of Kanto's public follower
-- sprite service. It follows Wilds' selected Sprite Style without copying
-- assets or changing Wilds settings. The bundled PMS sheet remains the spawn
-- and failure fallback.

local WildsSpriteProvider = {}
WildsSpriteProvider.__index = WildsSpriteProvider

local WILDS_ID = "overworld_wild_spawns"
local POLL_FRAMES = 30
local SEAT_RATIO = { ground = 0.52, surf = 0.50, flight = 0.48 }

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

local function spriteDef(result, dex, mode)
  if type(result) ~= "table" or result.fallback == true
      or type(result.image) ~= "string" or result.image == "" then
    return nil
  end
  return {
    id = string.format("PMS_WILDS_%03d_%s", dex, string.upper(mode)),
    image = result.image,
    frames = tonumber(result.frames) or 6,
    walker = result.walker ~= false,
    trueColor = result.trueColor ~= false,
    frameWidth = result.frameWidth,
    frameHeight = result.frameHeight,
    anchorX = result.anchorX,
    anchorY = result.anchorY,
    idleFrameCount = result.idleFrameCount,
    idleDurations = result.idleDurations,
    walkFrameCount = result.walkFrameCount,
    walkDurations = result.walkDurations,
    walkCycleBase = result.walkCycleBase,
    disableVerticalStepFlip = result.disableVerticalStepFlip,
    forceRawTrueColor = result.forceRawTrueColor,
  }
end

local function copyInto(target, source)
  for key in pairs(target) do target[key] = nil end
  for key, value in pairs(source or {}) do target[key] = value end
  return target
end

local function externalPose(owner, dex, mode, direction, def)
  local pose = owner.poses:resolve(dex, mode, direction)
  local scale = math.max(0.25, tonumber(def.pmsDisplayScale) or 1)
  local height = (tonumber(def.frameHeight) or 16) * scale
  local anchorY = (tonumber(def.anchorY)
    or tonumber(def.frameHeight) or 16) * scale
  local seatY = height * (SEAT_RATIO[mode] or 0.50)
  local geometryLift = math.max(0,
    math.floor(anchorY - 8 - seatY + 0.5))
  pose.riderLift = math.max(tonumber(pose.riderLift) or 0, geometryLift)
  pose.externalFrameHeight = height
  pose.externalSeatY = seatY
  return pose
end

local function applyExternalPoses(owner, resolved, def)
  resolved.poses = resolved.poses or {}
  for _, direction in ipairs({ "up", "down", "left", "right" }) do
    local nextPose = externalPose(owner, resolved.dex, resolved.mode,
      direction, def)
    if resolved.poses[direction] then
      copyInto(resolved.poses[direction], nextPose)
    else
      resolved.poses[direction] = nextPose
    end
  end
  resolved.pose = resolved.poses.down
end

function WildsSpriteProvider.new(opts)
  assert(type(opts) == "table", "Wilds provider options required")
  return setmetatable(opts, WildsSpriteProvider)
end

function WildsSpriteProvider:_handle()
  return find(self.mod, WILDS_ID)
end

function WildsSpriteProvider:resolveArt(mount, mode, context)
  local handle = self:_handle()
  local api = handle and handle.exports and handle.exports.resolveFollowerSprite
  if type(api) ~= "function" then return nil, "Wilds sprite API unavailable" end
  local ok, result = pcall(api, {
    species = mount.species,
    surface = mode == "surf" and "water" or "land",
    role = "primary",
    game = context and context.game,
  })
  if not ok then return nil, result end
  local def = spriteDef(result, mount.dex, mode)
  if not def then return nil, "Wilds has no usable selected sprite" end
  local frameWidth = tonumber(def.frameWidth) or 16
  local frameHeight = tonumber(def.frameHeight) or 16
  local largest = math.max(frameWidth, frameHeight)
  local target = self.scale and self.scale:frameSize(mount.dex) or largest
  -- Wilds deliberately keeps GSC/follower art at one tile. Mounts instead
  -- retain PMS' Pokédex-relative silhouette, while already true-size styles
  -- (PokeMMO, PMD, etc.) keep the geometry authored by their provider.
  def.pmsDisplayScale = largest <= 16
    and math.max(1, target / largest) or 1
  -- mod.find deliberately exposes only id/version/exports, not the other
  -- mod's options. The provider id and resolved image are therefore the
  -- authoritative public signal for Wilds' currently selected style.
  local style = tostring(result.providerId or "wilds")
  local token = table.concat({ style,
    def.image, tostring(def.frameWidth or 16),
    tostring(def.frameHeight or 16), tostring(def.pmsDisplayScale) }, "|")
  return def, token, style, result.providerId
end

-- Compatibility alias for callers from the first Wilds integration beta.
function WildsSpriteProvider:_resolveArt(mount, mode, context)
  return self:resolveArt(mount, mode, context)
end

function WildsSpriteProvider:applyExternalPoses(resolved, def)
  return applyExternalPoses(self, resolved, def)
end

-- Shared actor path for native 2D and voxel billboards. The renderer lane is
-- selected elsewhere; art ownership and live Wilds style changes stay here.
function WildsSpriteProvider:beginActor(resolved, context, externalRequired)
  local lease, err = self.bridge:spawn(resolved, context)
  if not lease then return nil, err end
  if resolved.externalDef then
    local replaced, replaceErr = self.bridge:replaceSprite(lease,
      resolved.externalDef, resolved.externalToken)
    if not replaced and externalRequired then
      self.bridge:remove(lease, "wilds-sprite-failed")
      return nil, replaceErr
    end
  end
  lease.externalPoll = 0
  lease.externalStyle = resolved.externalStyle
  return lease
end

function WildsSpriteProvider:updateActor(lease, context)
  if lease.resolved.allowExternalArt then
    lease.externalPoll = (lease.externalPoll or 0) + 1
    if lease.externalPoll >= POLL_FRAMES then
      lease.externalPoll = 0
      local mount = self.catalog:get(lease.resolved.dex)
      local def, token, nextStyle = self:resolveArt(mount,
        lease.resolved.mode, context)
      -- A temporary resolver failure keeps the healthy current actor. Style
      -- changes are picked up by the next poll or the options refresh event.
      if def and token ~= lease.externalSpriteToken then
        local ok = self.bridge:replaceSprite(lease, def, token)
        if not ok then return false end
        self:applyExternalPoses(lease.resolved, def)
        lease.externalStyle = nextStyle
        if self.log then
          self.log:info("Provider", "Wilds mount sprite switched to %s",
            tostring(nextStyle))
        end
      end
    end
  end
  return self.bridge:sync(lease, context)
end

function WildsSpriteProvider:contract()
  local owner = self
  return {
    api = 1,
    id = "wilds_selected_2d",
    priority = 250,
    probe = function(_, context)
      local source = owner.settings and owner.settings:get("sprite_source")
        or (context and context.spriteSource) or "auto"
      if source == "builtin" then return nil, "bundled sprites forced" end
      local handle = owner:_handle()
      if not (handle and handle.exports
          and type(handle.exports.resolveFollowerSprite) == "function") then
        return nil, "Wilds sprite API unavailable"
      end
      return {
        available = true,
        kind = "external2d",
        renderer = "native2d",
        fit = 90,
        spriteSource = "wilds",
      }
    end,
    resolve = function(_, dex, mode, context)
      local mount = owner.catalog:get(dex)
      if not mount or not mount.modes[mode] then
        return nil, "unsupported mount mode"
      end
      local def, token, style, source = owner:resolveArt(mount, mode, context)
      if not def then return nil, token end
      local resolved = {
        kind = "native2d",
        renderer = "native2d",
        dex = dex,
        species = mount.species,
        mode = mode,
        spriteId = owner.builtin:spriteId(dex, mode),
        externalDef = def,
        externalToken = token,
        externalStyle = style,
        externalSource = source,
        allowExternalArt = true,
      }
      owner:applyExternalPoses(resolved, def)
      return resolved
    end,
    begin = function(_, resolved, context)
      return owner:beginActor(resolved, context, true)
    end,
    update = function(_, lease, context)
      return owner:updateActor(lease, context)
    end,
    finish = function(_, lease, reason)
      return owner.bridge:remove(lease, reason)
    end,
  }
end

return WildsSpriteProvider

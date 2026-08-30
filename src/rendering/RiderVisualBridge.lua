-- Isolated presentation bridge. Native Surf normally swaps the player to the
-- generic surf-blob sheet; PMS keeps the physics state but restores the normal
-- rider sheet while its own mount actor owns the visible water silhouette.

local RiderVisualBridge = {}
RiderVisualBridge.__index = RiderVisualBridge

local function liveWorld(context)
  local world = context and context.world
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, value = pcall(world.overworld, world)
  if ok and type(value) == "table" then return value end
  return nil
end

function RiderVisualBridge.new(log)
  return setmetatable({ log = log }, RiderVisualBridge)
end

local function shallowCopy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function releaseTexture(texture)
  if texture and type(texture.release) == "function" then
    pcall(texture.release, texture)
  end
end

-- PotatoVoxel and other billboard hosts consume sprite:resolveImage rather
-- than SpriteRenderer:draw, so the native topHalf quad is invisible to them.
-- A small PMS-owned proxy keeps the selected live rider palette and masks the
-- lower rows on a private canvas. The player's sprite definition is never
-- mutated, and the proxy exists only for the mounted pose call.
local function rebuildVoxelProxy(lease, sprite)
  if not lease.voxel or type(sprite) ~= "table"
      or type(sprite.resolveImage) ~= "function" then return false end
  local graphics = love and love.graphics
  if not (graphics and type(graphics.newCanvas) == "function"
      and type(graphics.draw) == "function"
      and type(graphics.rectangle) == "function"
      and type(graphics.push) == "function"
      and type(graphics.pop) == "function") then return false end
  local okSource, source = pcall(sprite.resolveImage, sprite)
  if not okSource or not source or type(source.getDimensions) ~= "function" then
    return false
  end
  local entry = lease.voxelProxies[sprite]
  if entry and entry.source == source then return true end
  if entry then releaseTexture(entry.texture) end

  local okDimensions, width, height = pcall(source.getDimensions, source)
  if not okDimensions or not width or not height then return false end
  local frameHeight = math.max(1, tonumber(sprite.frameHeight) or 16)
  local frameCount = math.max(1, tonumber(sprite.frameCount)
    or math.floor(height / frameHeight))
  local cropBottom = math.max(1, math.min(frameHeight - 1,
    tonumber(lease.cropBottom) or 4))
  local pushed = false
  local okCanvas, canvas = pcall(function()
    graphics.push("all")
    pushed = true
    local value = graphics.newCanvas(width, height)
    if type(value.setFilter) == "function" then
      value:setFilter("nearest", "nearest")
    end
    graphics.setCanvas(value)
    graphics.clear(0, 0, 0, 0)
    graphics.setColor(1, 1, 1, 1)
    graphics.draw(source, 0, 0)
    graphics.setBlendMode("replace")
    graphics.setColor(0, 0, 0, 0)
    if lease.hideRider then
      graphics.rectangle("fill", 0, 0, width, height)
    else
      for frame = 0, frameCount - 1 do
        graphics.rectangle("fill", 0,
          frame * frameHeight + frameHeight - cropBottom,
          width, cropBottom)
      end
    end
    graphics.pop()
    pushed = false
    return value
  end)
  if pushed then pcall(graphics.pop) end
  if not okCanvas or not canvas then return false end

  entry = entry or {}
  entry.source = source
  entry.texture = canvas
  local def = shallowCopy(sprite.def)
  -- resolveImage has already applied the live player palette. Mark only the
  -- proxy true-colour so a voxel host does not replace the masked texture.
  def.trueColor = true
  entry.proxy = setmetatable({
    def = def,
    resolveImage = function() return entry.texture end,
    draw = function(_, ...)
      if type(sprite.draw) == "function" then return sprite:draw(...) end
    end,
  }, { __index = sprite })
  lease.voxelProxies[sprite] = entry
  return true
end

local function ensureVoxelProxies(lease)
  if not lease.voxel or not lease.player then return false end
  local active = {}
  local function add(sprite)
    if type(sprite) ~= "table" then return end
    active[sprite] = true
    rebuildVoxelProxy(lease, sprite)
  end
  add(lease.player.sprite)
  if lease.mode == "surf" then
    add(lease.player.surfSprite)
    add(lease.player.surfPikachuSprite)
  end
  for sprite, entry in pairs(lease.voxelProxies) do
    if not active[sprite] then
      releaseTexture(entry.texture)
      lease.voxelProxies[sprite] = nil
    end
  end
  return true
end

local function wrapPlayerPose(lease)
  local player = lease.player
  if not lease.voxel or type(player) ~= "table"
      or type(player.pose) ~= "function" then return false end
  local ownPose = rawget(player, "pose")
  local original = player.pose
  local wrapper
  wrapper = function(actor, ...)
    local sprite, px, py, facing, phase, flip, topHalf, forceFlip,
      frameOverride = original(actor, ...)
    local entry = lease.voxelProxies[sprite]
    if entry and entry.proxy then sprite = entry.proxy end
    if type(py) == "number" then
      py = py - math.max(0, tonumber(lease.voxelPoseLift) or 0)
    end
    return sprite, px, py, facing, phase, flip, topHalf, forceFlip,
      frameOverride
  end
  rawset(player, "pose", wrapper)
  lease.playerPose = { ownPose = ownPose, wrapper = wrapper }
  return true
end

local function restoreVoxelPresentation(lease)
  local player = lease.player
  local effect = lease.playerPose
  if effect and player and rawget(player, "pose") == effect.wrapper then
    rawset(player, "pose", effect.ownPose)
  end
  lease.playerPose = nil
  for _, entry in pairs(lease.voxelProxies or {}) do
    releaseTexture(entry.texture)
  end
  lease.voxelProxies = {}
end

-- SpriteRenderer's stock topHalf flag keeps only eight pixels of a 16px
-- trainer: visually that is little more than the hat and face. Mount riding
-- needs a shallower crop so the shoulders and torso overlap the Pokémon and
-- read as a seated pose. Supplying custom half-frame quads keeps the engine's
-- palette, facing, animation and scaling paths intact in both generations.
local function ensureRiderCrop(lease, sprite, entry)
  if not lease.clipRider or entry.customHalfFrames then return true end
  local graphics = love and love.graphics
  if not (graphics and type(graphics.newQuad) == "function") then return false end
  local image = sprite.image
  if not (image and type(image.getDimensions) == "function") then return false end
  local frameWidth = math.max(1, tonumber(sprite.frameWidth) or 16)
  local frameHeight = math.max(1, tonumber(sprite.frameHeight) or 16)
  local frameCount = math.max(1, tonumber(sprite.frameCount) or 1)
  if frameHeight <= 1 or frameCount <= 1 then return false end
  local cropBottom = math.max(1, math.min(frameHeight - 1,
    tonumber(lease.cropBottom) or 4))
  local visibleHeight = frameHeight - cropBottom
  local ok, imageWidth, imageHeight = pcall(image.getDimensions, image)
  if not ok or not imageWidth or not imageHeight then return false end
  local frames = {}
  for frame = 0, frameCount - 1 do
    local quadOk, quad = pcall(graphics.newQuad, 0, frame * frameHeight,
      frameWidth, visibleHeight, imageWidth, imageHeight)
    if not quadOk or not quad then return false end
    frames[frame] = quad
  end
  entry.baseHalfFrames = rawget(sprite, "halfFrames")
  entry.customHalfFrames = frames
  rawset(sprite, "halfFrames", frames)
  return true
end

local function wrapSprite(lease, sprite)
  if type(sprite) ~= "table" or type(sprite.draw) ~= "function"
      or lease.wrapped[sprite] then return false end
  local ownDraw = rawget(sprite, "draw")
  local original = sprite.draw
  local entry = {
    sprite = sprite,
    ownDraw = ownDraw,
    original = original,
    baseAnchorY = tonumber(sprite.anchorY) or 16,
  }
  local wrapper
  wrapper = function(renderer, px, py, camX, camY, facing, phase, flip,
      topHalf, forceFlip, frameOverride)
    if lease.hideRider then return end
    ensureRiderCrop(lease, sprite, entry)
    return original(renderer, px, py, camX, camY, facing, phase, flip,
      lease.clipRider or topHalf, forceFlip, frameOverride)
  end
  entry.wrapper = wrapper
  rawset(sprite, "draw", wrapper)
  lease.wrapped[sprite] = entry
  return true
end

local function restoreSprites(lease)
  for sprite, entry in pairs(lease.wrapped or {}) do
    if rawget(sprite, "draw") == entry.wrapper then
      rawset(sprite, "draw", entry.ownDraw)
    end
    if rawget(sprite, "halfFrames") == entry.customHalfFrames then
      rawset(sprite, "halfFrames", entry.baseHalfFrames)
    end
    if tonumber(sprite.anchorY) then sprite.anchorY = entry.baseAnchorY end
  end
  lease.wrapped = {}
end

local function wrapLiveSprites(lease)
  local player = lease.player
  if not player then return end
  wrapSprite(lease, player.sprite)
  if lease.mode == "surf" then
    wrapSprite(lease, player.surfSprite)
    wrapSprite(lease, player.surfPikachuSprite)
  end
end

-- Surf state may be applied after PMS acquires its render lease (the field
-- move has a text/transition callback), and Gen 2 may re-apply it after map
-- or battle state work. Keep native Surf physics, but continuously restore
-- only the normal rider sheet while PMS owns the visible water mount.
local function ensureSurfRider(lease)
  if lease.mode ~= "surf" or not lease.player then return false end
  local player = lease.player
  if lease.generation == 1 then
    if player.sprite then
      player.surfSprite = player.sprite
      player.surfPikachuSprite = player.sprite
      return true
    end
    return false
  end
  if lease.riderDef and player.spriteDef ~= lease.riderDef
      and type(player.setSprite) == "function" then
    player:setSprite(lease.riderDef)
    if lease.world and type(lease.world.applySpritePalette) == "function" then
      pcall(lease.world.applySpritePalette, lease.world, player)
    end
    return true
  end
  return false
end

function RiderVisualBridge:begin(session, resolved, context)
  if not session or (resolved and resolved.rendersRider) then
    return { skipped = true }
  end
  local live = liveWorld(context)
  local player = live and live.player
  if type(player) ~= "table" then return { skipped = true } end
  local pose = resolved and resolved.pose or {}
  local lease = {
    generation = context.generation,
    mode = session.mode,
    player = player,
    pose = pose,
    native2d = resolved and resolved.renderer == "native2d",
    voxel = resolved and resolved.renderer == "voxel",
    clipRider = pose.clipRider ~= false,
    hideRider = context.showRider == false,
    cropBottom = math.max(1, tonumber(pose.riderCropBottom) or 4),
    wrapped = {},
    voxelProxies = {},
  }
  wrapPlayerPose(lease)
  if context.generation == 1 and session.mode == "surf" then
    lease.surfSprite = player.surfSprite
    lease.surfPikachuSprite = player.surfPikachuSprite
    if player.sprite then
      player.surfSprite = player.sprite
      player.surfPikachuSprite = player.sprite
    end
    if self.log then
      self.log:once("rider-sheet-gen1", "info", "Rider",
        "replaced native Surf blob with the mounted rider pose")
    end
  elseif context.generation == 2 and session.mode == "surf" then
    lease.world = live
    lease.sprite = player.sprite
    lease.spriteDef = player.spriteDef
    local name = type(live.playerSpriteName) == "function"
      and live:playerSpriteName() or nil
    local def = name and live.sprites and live.sprites[name]
    lease.riderDef = def
    ensureSurfRider(lease)
    if self.log then
      self.log:once("rider-sheet-gen2", "info", "Rider",
        "replaced native Gen 2 Surf blob with the mounted rider pose")
    end
  end
  wrapLiveSprites(lease)
  self:update(lease, session, context)
  return lease
end

function RiderVisualBridge:update(lease, session, context)
  if not lease or lease.skipped then return true end
  ensureSurfRider(lease)
  wrapLiveSprites(lease)
  ensureVoxelProxies(lease)
  local seatLift = tonumber(lease.pose and lease.pose.riderLift) or 1
  local mountScale = math.max(0.5, math.min(2,
    tonumber(context and context.mountScale) or 1))
  local mountHeight = tonumber(lease.pose and
    (lease.pose.externalFrameHeight or lease.pose.frameHeight)) or 16
  local sizeLift = math.floor(mountHeight * (mountScale - 1) * 0.5
    + (mountScale >= 1 and 0.5 or -0.5))
  local altitudeLift = session and session.mode == "flight"
    and math.max(0, tonumber(context and context.visualLift) or 0) or 0
  local poseLift = seatLift + sizeLift + altitudeLift
  lease.voxelPoseLift = lease.voxel and poseLift or 0
  if lease.native2d then
    for sprite, entry in pairs(lease.wrapped) do
      sprite.anchorY = entry.baseAnchorY + poseLift
    end
  end
  return true
end

function RiderVisualBridge:finish(lease)
  if not lease or lease.skipped then return true end
  restoreVoxelPresentation(lease)
  restoreSprites(lease)
  if lease.generation == 1 and lease.mode == "surf" and lease.player then
    lease.player.surfSprite = lease.surfSprite
    lease.player.surfPikachuSprite = lease.surfPikachuSprite
    return true
  end
  if lease.generation == 2 and lease.mode == "surf" and lease.world then
    if type(lease.world.applyPlayerState) == "function" then
      lease.world:applyPlayerState(lease.world.playerState)
    elseif lease.player then
      lease.player.sprite = lease.sprite
      lease.player.spriteDef = lease.spriteDef
    end
  end
  return true
end

return RiderVisualBridge

-- The only PMS module permitted to touch the live actor shape returned under
-- mod.world. It exists because the audited Gen2 runtime-actor handle lacks the
-- self-driven sync helpers that Gen1 exposes. Every access is guarded and the
-- caller can fall back when the shape changes.

local ActorBridge = {}
ActorBridge.__index = ActorBridge

local RANGE = { up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT" }

local function jumpVisualOffset(player)
  if tonumber(player.spriteYOffset) then
    return tonumber(player.spriteYOffset) or 0
  end
  local remaining = tonumber(player.hopFrames)
  if not remaining or remaining <= 0 then return 0 end
  local total = math.max(1, tonumber(player.hopTotal) or 32)
  local phase = 1 - remaining / total
  return -math.floor(10 * math.sin(phase * math.pi) + 0.5)
end

function ActorBridge.new(mod, log)
  return setmetatable({ mod = mod, log = log, serial = 0 }, ActorBridge)
end

function ActorBridge:_restoreEffect(lease)
  local effect = lease and lease.effect
  if not effect then return false end
  if rawget(effect.sprite, "draw") == effect.wrapper then
    rawset(effect.sprite, "draw", effect.ownDraw)
  end
  lease.effect = nil
  return true
end

function ActorBridge:_restorePoseEffect(lease)
  local effect = lease and lease.poseEffect
  if not effect then return false end
  if rawget(effect.actor, "pose") == effect.wrapper then
    rawset(effect.actor, "pose", effect.ownPose)
  end
  lease.poseEffect = nil
  return true
end

function ActorBridge:_restoreVoxelSpriteProxy(lease)
  local effect = lease and lease.voxelSpriteEffect
  if not effect then return false end
  if effect.texture and type(effect.texture.release) == "function" then
    pcall(effect.texture.release, effect.texture)
  end
  lease.voxelSpriteEffect = nil
  lease.voxelSpriteProxy = nil
  return true
end

local function copyTable(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

-- Classic Wilds sheets remain 16x16 and carry a PMS display scale. Voxel
-- hosts consume geometry rather than SpriteRenderer's draw transform, so a
-- private nearest-neighbour texture proxy maps that selected art onto the
-- already bundled Pokédex-sized geometry for this species.
function ActorBridge:_ensureVoxelSpriteProxy(lease, raw)
  if not lease or not raw or lease.resolved.renderer ~= "voxel" then
    return self:_restoreVoxelSpriteProxy(lease)
  end
  local def = raw.spriteDef
  local displayScale = tonumber(def and def.pmsDisplayScale) or 1
  local geometry = lease.resolved.voxelGeometryDef
  local sprite = raw.sprite
  if displayScale == 1 or type(geometry) ~= "table"
      or type(sprite) ~= "table" or type(sprite.resolveImage) ~= "function"
      or type(raw.pose) ~= "function" then
    return self:_restoreVoxelSpriteProxy(lease)
  end
  local graphics = love and love.graphics
  if not (graphics and type(graphics.newCanvas) == "function"
      and type(graphics.draw) == "function" and type(graphics.push) == "function"
      and type(graphics.pop) == "function") then return false end
  local okSource, source = pcall(sprite.resolveImage, sprite)
  if not okSource or not source or type(source.getDimensions) ~= "function" then
    return false
  end
  local existing = lease.voxelSpriteEffect
  if existing and existing.sprite == sprite and existing.source == source
      and existing.displayScale == displayScale then return true end
  self:_restoreVoxelSpriteProxy(lease)

  local frameWidth = math.max(1, tonumber(geometry.frameWidth) or 16)
  local frameHeight = math.max(1, tonumber(geometry.frameHeight) or frameWidth)
  local frameCount = math.max(1, tonumber(def.frames)
    or tonumber(sprite.frameCount) or 1)
  local sourceWidth = math.max(1, tonumber(sprite.frameWidth) or 16)
  local sourceHeight = math.max(1, tonumber(sprite.frameHeight) or 16)
  local pushed = false
  local okCanvas, canvas = pcall(function()
    graphics.push("all")
    pushed = true
    local value = graphics.newCanvas(frameWidth, frameHeight * frameCount)
    if type(value.setFilter) == "function" then
      value:setFilter("nearest", "nearest")
    end
    graphics.setCanvas(value)
    graphics.clear(0, 0, 0, 0)
    graphics.setColor(1, 1, 1, 1)
    graphics.draw(source, 0, 0, 0,
      frameWidth / sourceWidth, frameHeight / sourceHeight)
    graphics.pop()
    pushed = false
    return value
  end)
  if pushed then pcall(graphics.pop) end
  if not okCanvas or not canvas then return false end

  local proxyDef = copyTable(def)
  proxyDef.image = geometry.image
  proxyDef.frameWidth = frameWidth
  proxyDef.frameHeight = frameHeight
  proxyDef.anchorX = geometry.anchorX
  proxyDef.anchorY = geometry.anchorY
  proxyDef.trueColor = true
  local effect = {
    sprite = sprite,
    source = source,
    texture = canvas,
    displayScale = displayScale,
  }
  effect.proxy = setmetatable({
    def = proxyDef,
    resolveImage = function() return effect.texture end,
    draw = function(_, ...)
      if type(sprite.draw) == "function" then return sprite:draw(...) end
    end,
  }, { __index = sprite })
  lease.voxelSpriteEffect = effect
  lease.voxelSpriteProxy = effect.proxy
  return true
end

-- Voxel hosts render ordinary actors from their canonical pose. Returning a
-- visual Y above the actor's grounded py lets the host derive real 3D lift
-- without PMS touching its camera, terrain or draw pipeline.
function ActorBridge:_ensureVoxelPoseEffect(lease, raw)
  if not lease or not raw or lease.resolved.renderer ~= "voxel" then
    return self:_restorePoseEffect(lease)
  end
  if type(raw.pose) ~= "function" then return false end
  if lease.poseEffect and lease.poseEffect.actor == raw then return true end
  self:_restorePoseEffect(lease)
  local ownPose = rawget(raw, "pose")
  local original = raw.pose
  local wrapper
  wrapper = function(actor, ...)
    local sprite, px, py, facing, phase, flip, topHalf, forceFlip,
      frameOverride = original(actor, ...)
    if lease.voxelSpriteProxy then sprite = lease.voxelSpriteProxy end
    local lift = math.max(0, tonumber(actor.pmsVisualLift) or 0)
    if type(py) == "number" then py = py - lift end
    return sprite, px, py, facing, phase, flip, topHalf, forceFlip,
      frameOverride
  end
  rawset(raw, "pose", wrapper)
  lease.poseEffect = {
    actor = raw,
    ownPose = ownPose,
    wrapper = wrapper,
  }
  return true
end

-- Native 2D external sheets can use either classic 16x16 frames or their own
-- true-size geometry. The per-actor wrapper scales only classic art around
-- the logical world anchor; it never mutates Wilds' registry or its options.
-- Flight also draws its ground-reference shadow outside that scale transform.
function ActorBridge:_ensureNativeEffect(lease, raw)
  if not lease or not raw or lease.resolved.renderer ~= "native2d" then
    return self:_restoreEffect(lease)
  end
  local sprite = raw.sprite
  if type(sprite) ~= "table" or type(sprite.draw) ~= "function" then
    return false
  end
  local providerScale = tonumber(raw.spriteDef
    and raw.spriteDef.pmsDisplayScale) or 1
  local displayScale = math.max(0.25,
    providerScale * (tonumber(raw.pmsMountScale) or 1))
  if lease.effect and lease.effect.sprite == sprite
      and lease.effect.displayScale == displayScale then return true end
  self:_restoreEffect(lease)
  local ownDraw = rawget(sprite, "draw")
  local original = sprite.draw
  local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
  local markTrueColor = okPalette and type(PaletteFX) == "table"
    and PaletteFX.markTrueColor or nil
  local wrapper
  wrapper = function(renderer, px, py, camX, camY, facing, phase, flip,
      topHalf, forceFlip, frameOverride)
    local flight = lease.resolved.mode == "flight"
    local effectiveTopHalf = topHalf
    if flight then effectiveTopHalf = false end
    local lift = flight and math.max(0, tonumber(raw.pmsVisualLift) or 0) or 0
    local drawLift = flight and math.max(0,
      tonumber(raw.pmsDrawLift) or 0) or 0
    local graphics = love and love.graphics
    if lift > 0 and raw.pmsShowShadow ~= false and graphics
        and type(graphics.ellipse) == "function" then
      local altitude = math.max(0, math.min(1,
        tonumber(raw.pmsAltitude) or 0))
      local radiusX = math.max(2.5, 6 - altitude * 2.5)
      local radiusY = math.max(1, 2.25 - altitude * 0.75)
      local red, green, blue, alpha = 1, 1, 1, 1
      if type(graphics.getColor) == "function" then
        red, green, blue, alpha = graphics.getColor()
      end
      graphics.setColor(0, 0, 0, 0.34 - altitude * 0.12)
      graphics.ellipse("fill",
        math.floor((tonumber(px) or 0) - (tonumber(camX) or 0)) + 8,
        math.floor((tonumber(py) or 0) + lift - drawLift
          - (tonumber(camY) or 0)) + 12,
        radiusX, radiusY)
      graphics.setColor(red, green, blue, alpha)
    end
    if (displayScale ~= 1 or drawLift > 0) and graphics
        and type(graphics.push) == "function"
        and type(graphics.pop) == "function"
        and type(graphics.translate) == "function"
        and type(graphics.scale) == "function" then
      local anchorX = math.floor((tonumber(px) or 0)
        - (tonumber(camX) or 0)) + 8
      local anchorY = math.floor((tonumber(py) or 0)
        - (tonumber(camY) or 0)) + 12
      graphics.push()
      if drawLift > 0 then graphics.translate(0, -drawLift) end
      if displayScale ~= 1 then
        graphics.translate(anchorX, anchorY)
        graphics.scale(displayScale, displayScale)
        graphics.translate(-anchorX, -anchorY)
      end
      local ok, result = pcall(original, renderer, px, py, camX, camY,
        facing, phase, flip, effectiveTopHalf, forceFlip,
        frameOverride)
      graphics.pop()
      if not ok then error(result, 0) end
      -- SpriteRenderer records a true-colour rectangle before Love's matrix
      -- transform, so extend that exemption to the scaled classic sheet.
      if markTrueColor and raw.spriteDef and raw.spriteDef.trueColor then
        local frameWidth = tonumber(sprite.frameWidth) or 16
        local frameHeight = tonumber(sprite.frameHeight) or 16
        local spriteAnchorX = tonumber(sprite.anchorX) or frameWidth / 2
        local spriteAnchorY = tonumber(sprite.anchorY) or frameHeight
        local drawHeight = effectiveTopHalf
          and math.max(1, frameHeight - math.min(8, frameHeight))
          or frameHeight
        pcall(markTrueColor,
          math.floor(anchorX - spriteAnchorX * displayScale),
          math.floor(anchorY - drawLift - spriteAnchorY * displayScale),
          math.ceil(frameWidth * displayScale),
          math.ceil(drawHeight * displayScale))
      end
      return result
    end
    return original(renderer, px, py, camX, camY, facing, phase, flip,
      effectiveTopHalf, forceFlip, frameOverride)
  end
  rawset(sprite, "draw", wrapper)
  lease.effect = { sprite = sprite, ownDraw = ownDraw, wrapper = wrapper,
    displayScale = displayScale }
  return true
end

local function activeWorld(world)
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, value = pcall(world.overworld, world)
  if not ok or type(value) ~= "table" then return nil end
  return value
end

function ActorBridge:_raw(lease)
  local handle = lease and lease.handle
  local npc = handle and handle.npc
  if type(npc) ~= "table" then return nil end
  return npc
end

-- A renderer integration may attach presentation metadata to the same live
-- actor PMS owns. Keeping this guarded accessor here prevents provider code
-- from learning either generation's actor-handle layout.
function ActorBridge:entity(lease)
  return self:_raw(lease)
end

-- External 2D providers may supply a SpriteRenderer definition after content
-- registries have frozen. Replace only the PMS-owned actor's renderer; no
-- global sprite definition or provider option is mutated.
function ActorBridge:replaceSprite(lease, spriteDef, token)
  local raw = self:_raw(lease)
  if not raw or type(spriteDef) ~= "table"
      or type(spriteDef.image) ~= "string" or spriteDef.image == "" then
    return nil, "external mount sprite definition is invalid"
  end
  local okRenderer, SpriteRenderer = pcall(require,
    "src.render.SpriteRenderer")
  if not okRenderer or type(SpriteRenderer) ~= "table"
      or type(SpriteRenderer.new) ~= "function" then
    return nil, "SpriteRenderer replacement capability unavailable"
  end
  self:_restoreEffect(lease)
  self:_restoreVoxelSpriteProxy(lease)
  local ok, sprite = pcall(SpriteRenderer.new, spriteDef,
    raw.id or lease.name)
  if not ok or not sprite then return nil, ok and "sprite unavailable" or sprite end
  raw.sprite = sprite
  raw.spriteDef = spriteDef
  lease.externalSpriteToken = token
  local live = activeWorld(lease.world)
  if live and type(live.applySpritePalette) == "function" then
    pcall(live.applySpritePalette, live, raw)
  end
  self:_ensureNativeEffect(lease, raw)
  return true
end

function ActorBridge:spawn(resolved, context)
  local world = context and context.world
  if not world then return nil, "world API unavailable" end
  local position, positionErr = world:current()
  if not position then return nil, positionErr or "no active map" end

  self.serial = self.serial + 1
  local name = "PMS_MOUNT_ACTOR_" .. tostring(self.serial)
  local npcId, spawnErr = world:spawnNpc(position.mapId, {
    name = name,
    x = position.x,
    y = position.y,
    sprite = resolved.spriteId,
    movement = "STAY",
    range = RANGE[position.facing] or "DOWN",
    pmsMountActor = true,
    pmsMountDex = resolved.dex,
    pmsMountMode = resolved.mode,
  })
  if not npcId then return nil, spawnErr or "mount actor spawn failed" end

  local handle, handleErr = world:npc(position.mapId, name)
  if not handle then
    world:removeNpc(npcId)
    return nil, handleErr or "mount actor handle unavailable"
  end

  local lease = {
    world = world,
    mapId = position.mapId,
    npcId = npcId,
    name = name,
    handle = handle,
    resolved = resolved,
    removed = false,
  }
  if type(handle.setPassable) == "function" then
    pcall(handle.setPassable, handle, true)
  else
    local raw = self:_raw(lease)
    if raw then raw.passable = true end
  end
  local ok, err = self:sync(lease, context)
  if not ok then
    self:remove(lease, "initial-sync-failed")
    return nil, err
  end
  return lease
end

function ActorBridge:sync(lease, context)
  if not lease or lease.removed then return nil, "mount actor is gone" end
  local world = lease.world
  local position = world and world:current()
  if not position or position.mapId ~= lease.mapId then
    return nil, "mount actor map changed"
  end

  local raw = self:_raw(lease)
  local live = activeWorld(world)
  local player = live and live.player
  if raw and type(player) == "table"
      and type(player.px) == "number" and type(player.py) == "number" then
    local facing = player.facing or position.facing or raw.facing or "down"
    local pose = (lease.resolved.poses and lease.resolved.poses[facing])
      or lease.resolved.pose or {}
    local visualLift = math.max(0,
      tonumber(context and context.visualLift) or 0)
    -- Gen 1's NPC step/update path can re-derive an actor's pixel position.
    -- Keep its logical mount actor on the rider and apply altitude in the
    -- actor's draw wrapper. Gen 2 runtime actors retain the direct py offset.
    local native2d = lease.resolved.renderer == "native2d"
    local voxelPose = lease.resolved.renderer == "voxel"
      and type(raw.pose) == "function"
    local drawLift = native2d
      and tonumber(context and context.generation) == 1 and visualLift or 0
    local positionLift = voxelPose and 0 or (visualLift - drawLift)
    local bob = 0
    if player.moving and (pose.bob or 0) ~= 0 then
      bob = player.stepFlip and (pose.bob or 0) or 0
    end
    raw.cellX, raw.cellY = player.cellX, player.cellY
    raw.homeX, raw.homeY = player.cellX, player.cellY
    raw.px = player.px + (pose.offsetX or 0)
    -- A tiny y lead makes the y-sort deterministic: the mount is drawn under
    -- the rider. SpriteRenderer floors this to at most one visual pixel.
    -- Native ledge arcs are applied only at player draw time (Gen1
    -- hopFrames / Gen2 spriteYOffset). Mirror that cosmetic offset onto the
    -- mount actor so rider and Pokémon jump as one silhouette.
    raw.py = player.py + jumpVisualOffset(player) + (pose.offsetY or 0)
      - positionLift - bob - 0.001
    raw.targetX, raw.targetY = player.targetX, player.targetY
    raw.facing = facing
    raw.moving = player.moving and true or false
    raw.progress = player.progress or 0
    raw.stepFlip = player.stepFlip and true or false
    raw.animClock = player.animClock or player.progress or 0
    raw.passable = true
    raw.frozen = true
    raw.pmsMountActor = true
    raw.pmsMountDex = lease.resolved.dex
    raw.pmsMountMode = lease.resolved.mode
    raw.pmsAltitude = context and context.altitude or 0
    raw.pmsVisualLift = visualLift
    raw.pmsDrawLift = drawLift
    raw.pmsShowShadow = context and context.showShadow ~= false
    raw.pmsMountScale = context and context.mountScale or 1
    raw.pmsRiderPose = pose
    if raw.def then
      raw.def.pmsMountActor = true
      raw.def.pmsMountDex = lease.resolved.dex
      raw.def.pmsMountMode = lease.resolved.mode
    end
    if self.log then
      self.log:once("actor-bridge-live-shape", "info", "Adapter",
        "using guarded live-actor sync bridge")
    end
    self:_ensureVoxelPoseEffect(lease, raw)
    self:_ensureVoxelSpriteProxy(lease, raw)
    self:_ensureNativeEffect(lease, raw)
    return true
  end

  -- Public Gen1 fallback is cell-accurate but not sub-cell interpolated.
  if lease.handle and type(lease.handle.placeAt) == "function" then
    local ok, err = lease.handle:placeAt(position.x, position.y, position.facing)
    if ok then return true end
    return nil, err
  end
  return nil, "live actor sync capability unavailable"
end

function ActorBridge:remove(lease, reason)
  if not lease or lease.removed then return false end
  self:_restoreEffect(lease)
  self:_restorePoseEffect(lease)
  self:_restoreVoxelSpriteProxy(lease)
  lease.removed = true
  local world = lease.world
  if world and type(world.removeNpc) == "function" then
    local ok, result = pcall(world.removeNpc, world, lease.npcId)
    if not ok and self.log then
      self.log:warn("Adapter", "mount actor removal failed: %s", tostring(result))
    end
  end
  return true
end

return ActorBridge

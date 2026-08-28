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

function RiderVisualBridge:begin(session, resolved, context)
  if not session or session.mode ~= "surf"
      or (resolved and resolved.rendersRider) then return { skipped = true } end
  local live = liveWorld(context)
  local player = live and live.player
  if type(player) ~= "table" then return { skipped = true } end
  if context.generation == 1 then
    local lease = {
      generation = 1,
      player = player,
      surfSprite = player.surfSprite,
      surfPikaSprite = player.surfPikaSprite,
    }
    if player.sprite then
      player.surfSprite = player.sprite
      player.surfPikaSprite = player.sprite
    end
    if self.log then
      self.log:once("rider-sheet-gen1", "info", "Rider",
        "replaced native Surf blob with the mounted rider pose")
    end
    return lease
  end
  local lease = {
    generation = 2,
    world = live,
    player = player,
    sprite = player.sprite,
    spriteDef = player.spriteDef,
  }
  local name = type(live.playerSpriteName) == "function"
    and live:playerSpriteName() or nil
  local def = name and live.sprites and live.sprites[name]
  if def and type(player.setSprite) == "function" then player:setSprite(def) end
  if self.log then
    self.log:once("rider-sheet-gen2", "info", "Rider",
      "replaced native Gen 2 Surf blob with the mounted rider pose")
  end
  return lease
end

function RiderVisualBridge:finish(lease)
  if not lease or lease.skipped then return true end
  if lease.generation == 1 and lease.player then
    lease.player.surfSprite = lease.surfSprite
    lease.player.surfPikaSprite = lease.surfPikaSprite
    return true
  end
  if lease.generation == 2 and lease.world then
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

return function(T, V)
  local Catalog = V.require("core/MountCatalog")
  local RiderPose = V.require("rendering/RiderPose")
  local Builtin = V.require("providers/BuiltinPokePCProvider")
  local ActorBridge = V.require("game/ActorBridge")

  T:test("rider profiles scale large validation mounts", function()
    local poses = RiderPose.new(V.data("rider_profiles"))
    local arcanine = poses:resolve(59, "ground", "down")
    T:eq(arcanine.scale, 2)
    T:eq(arcanine.frameWidth, 32)
    local charizard = poses:resolve(6, "flight", "down")
    T:eq(charizard.scale, 3)
    T:eq(charizard.frameHeight, 48)
    local hooh = poses:resolve(250, "flight", "down")
    T:eq(hooh.scale, 4)
    T:eq(hooh.frameWidth, 64)
  end)

  T:test("builtin provider registers every mode-specific sprite", function()
    local records = {}
    local registry = {
      get = function() return nil end,
      register = function(_, id, value)
        T:eq(records[id], nil, "sprite id must be unique")
        records[id] = value
      end,
    }
    local fakeMod = {
      content = { sprites = registry },
      assets = { path = function(_, relative) return "MOD/" .. relative end },
    }
    local catalog = Catalog.new(V.data("mounts"))
    local poses = RiderPose.new(V.data("rider_profiles"))
    local provider = Builtin.new({
      mod = fakeMod,
      catalog = catalog,
      poses = poses,
      bridge = {},
    })
    T:ok(provider:registerContent())
    local count = 0
    for _ in pairs(records) do count = count + 1 end
    T:eq(count, 42)
    local charizard = records.PMS_MOUNT_006_FLIGHT
    T:eq(charizard.frames, 6)
    T:eq(charizard.frameWidth, 48)
    T:eq(charizard.frameHeight, 48)
    T:eq(charizard.anchorY, 28)
    T:matches(charizard.image, "scaled/3x/follower_006%.png")
  end)

  T:test("actor bridge mirrors the player and cleans up ownership", function()
    local player = {
      cellX = 5, cellY = 7, px = 80, py = 112,
      facing = "right", moving = true, progress = 4, stepFlip = true,
    }
    local npc = { def = {} }
    local removed
    local world = {
      current = function()
        return { mapId = "ROUTE_1", x = player.cellX, y = player.cellY,
          facing = player.facing }
      end,
      spawnNpc = function(_, mapId, def)
        T:eq(mapId, "ROUTE_1")
        T:eq(def.sprite, "PMS_MOUNT_059_GROUND")
        return "ROUTE_1_obj_9"
      end,
      npc = function()
        return { npc = npc }
      end,
      overworld = function()
        return { player = player }
      end,
      removeNpc = function(_, id)
        removed = id
        return true
      end,
    }
    local bridge = ActorBridge.new()
    local lease = assert(bridge:spawn({
      dex = 59, mode = "ground", spriteId = "PMS_MOUNT_059_GROUND",
      pose = { offsetX = 2, offsetY = 1 },
    }, { world = world, altitude = 0 }))
    T:eq(npc.cellX, 5)
    T:eq(npc.cellY, 7)
    T:eq(npc.px, 82)
    T:ok(npc.py < 113 and npc.py > 112.9)
    T:eq(npc.facing, "right")
    T:eq(npc.passable, true)
    T:eq(npc.pmsMountActor, true)
    player.px, player.py, player.facing = 96, 128, "up"
    T:ok(bridge:sync(lease, { altitude = 0.5 }))
    T:eq(npc.px, 98)
    T:eq(npc.facing, "up")
    T:eq(npc.pmsAltitude, 0.5)
    T:ok(bridge:remove(lease, "test"))
    T:eq(removed, "ROUTE_1_obj_9")
    T:eq(bridge:remove(lease, "again"), false)
  end)
end

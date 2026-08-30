return function(T, V)
  local Catalog = V.require("core/MountCatalog")
  local MountScale = V.require("rendering/MountScale")
  local RiderPose = V.require("rendering/RiderPose")
  local Builtin = V.require("providers/BuiltinPokePCProvider")
  local ActorBridge = V.require("game/ActorBridge")

  T:test("rider profiles scale large validation mounts", function()
    local catalog = Catalog.new(V.data("mounts"))
    local scale = MountScale.new(catalog)
    local poses = RiderPose.new(V.data("rider_profiles"), scale)
    local arcanine = poses:resolve(59, "ground", "down")
    T:eq(arcanine.frameWidth, 22)
    local charizard = poses:resolve(6, "flight", "down")
    T:eq(charizard.frameHeight, 21)
    T:eq(charizard.riderLift, 0)
    local hooh = poses:resolve(250, "flight", "down")
    T:eq(hooh.frameWidth, 31)
    T:eq(scale:frameSize(130), 40)
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
    local scale = MountScale.new(catalog)
    local poses = RiderPose.new(V.data("rider_profiles"), scale)
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
    T:eq(charizard.frameWidth, 21)
    T:eq(charizard.frameHeight, 21)
    T:ok(charizard.anchorY > 15 and charizard.anchorY < 16)
    T:matches(charizard.image, "sized/follower_006%.png")
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
      dex = 59, mode = "ground", renderer = "native2d",
      spriteId = "PMS_MOUNT_059_GROUND",
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
    player.hopFrames, player.hopTotal = 16, 32
    T:ok(bridge:sync(lease, { altitude = 0 }))
    T:ok(npc.py > 118.9 and npc.py < 119.1)
    player.hopFrames = nil
    player.spriteYOffset = -12
    T:ok(bridge:sync(lease, { altitude = 0 }))
    T:ok(npc.py > 116.9 and npc.py < 117.1)
    player.spriteYOffset = nil
    T:ok(bridge:sync(lease, { generation = 1, altitude = 0.85,
      visualLift = 20 }))
    T:ok(npc.py > 128.9 and npc.py < 129.1)
    T:eq(npc.pmsDrawLift, 20)
    T:ok(bridge:sync(lease, { generation = 2, altitude = 0.85,
      visualLift = 20 }))
    T:ok(npc.py > 108.9 and npc.py < 109.1)
    T:eq(npc.pmsDrawLift, 0)
    T:ok(bridge:remove(lease, "test"))
    T:eq(removed, "ROUTE_1_obj_9")
    T:eq(bridge:remove(lease, "again"), false)
  end)

  T:test("actor bridge scales classic external art around its world anchor", function()
    local previousLove = love
    local trace = {}
    love = { graphics = {
      push = function() trace[#trace + 1] = "push" end,
      pop = function() trace[#trace + 1] = "pop" end,
      translate = function(x, y)
        trace[#trace + 1] = string.format("translate:%g:%g", x, y)
      end,
      scale = function(x, y)
        trace[#trace + 1] = string.format("scale:%g:%g", x, y)
      end,
    } }
    local drawn, receivedTopHalf = 0, nil
    local original = function(_, _, _, _, _, _, _, _, topHalf)
      drawn = drawn + 1
      receivedTopHalf = topHalf
      return "drawn"
    end
    local raw = {
      spriteDef = { pmsDisplayScale = 1.5 },
      sprite = { draw = original },
    }
    local lease = { resolved = { renderer = "native2d", mode = "ground" } }
    local bridge = ActorBridge.new()
    T:ok(bridge:_ensureNativeEffect(lease, raw))
    T:eq(raw.sprite:draw(10, 20, 2, 3, "down", 0, false), "drawn")
    T:eq(drawn, 1)
    T:eq(trace[1], "push")
    T:eq(trace[2], "translate:16:29")
    T:eq(trace[3], "scale:1.5:1.5")
    T:eq(trace[4], "translate:-16:-29")
    T:eq(trace[5], "pop")
    lease.resolved.mode = "flight"
    raw.pmsDrawLift = 12
    trace = {}
    T:eq(raw.sprite:draw(10, 20, 2, 3, "down", 0, false, true), "drawn")
    T:eq(receivedTopHalf, false)
    T:eq(trace[1], "push")
    T:eq(trace[2], "translate:0:-12")
    T:eq(trace[3], "translate:16:29")
    T:eq(trace[4], "scale:1.5:1.5")
    T:eq(trace[5], "translate:-16:-29")
    T:eq(trace[6], "pop")
    T:ok(bridge:_restoreEffect(lease))
    T:eq(raw.sprite.draw, original)
    love = previousLove
  end)

  T:test("voxel actor pose exposes flight altitude and restores cleanly",
    function()
      local player = {
        cellX = 2, cellY = 3, px = 32, py = 48, facing = "down",
      }
      local npc = {
        def = {},
        pose = function(self)
          return self.sprite, self.px, self.py, self.facing, 0, false
        end,
      }
      local world = {
        current = function()
          return { mapId = "ROUTE_1", x = 2, y = 3, facing = "down" }
        end,
        spawnNpc = function() return "mount" end,
        npc = function() return { npc = npc } end,
        overworld = function() return { player = player } end,
        removeNpc = function() return true end,
      }
      local originalPose = npc.pose
      local bridge = ActorBridge.new()
      local lease = assert(bridge:spawn({
        dex = 6, mode = "flight", renderer = "voxel",
        spriteId = "PMS_MOUNT_006_FLIGHT", pose = {},
      }, { world = world, generation = 1, visualLift = 30,
        altitude = 0.9 }))
      T:ok(npc.pose ~= originalPose)
      local _, _, posedY = npc:pose()
      T:ok(posedY > 17.9 and posedY < 18.1)
      T:ok(npc.py > 47.9 and npc.py < 48.1)
      T:eq(npc.pmsVisualLift, 30)
      T:ok(bridge:remove(lease, "test"))
      T:eq(npc.pose, originalPose)
    end)
end

return function(T, V)
  local Catalog = V.require("core/MountCatalog")
  local State = V.require("core/MountState")
  local MountSystem = V.require("core/MountSystem")
  local MountScale = V.require("rendering/MountScale")
  local RiderBridge = V.require("rendering/RiderVisualBridge")
  local RuntimeAdapter = V.require("game/RuntimeAdapter")
  local Ground = V.require("movement/GroundController")
  local Surf = V.require("movement/SurfController")
  local Flight = V.require("movement/FlightController")
  local InputBridge = V.require("input/InputBridge")
  local MotionDynamics = V.require("movement/MotionDynamics")

  T:test("Pokédex height curve preserves size order without giant sheets", function()
    local scale = MountScale.new(Catalog.new(V.data("mounts")))
    T:eq(scale:frameSize(111), 16) -- Rhyhorn 1.0 m
    T:eq(scale:frameSize(59), 22)  -- Arcanine 1.9 m
    T:eq(scale:frameSize(131), 25) -- Lapras 2.5 m
    T:eq(scale:frameSize(130), 40) -- Gyarados 6.5 m
    T:ok(scale:frameSize(130) > scale:frameSize(9))
    T:ok(MountScale.frameSizeForHeight(100) <= 40)
  end)

  T:test("B sprint accelerates ground Surf and flight movement", function()
    local sprint = { input = { isDown = function(_, button)
      return button == "b"
    end } }
    local normal = { input = { isDown = function() return false end } }
    local adapter = {
      isSurfing = function() return false end,
      isOutside = function() return true end,
      currentTerrain = function() return "land" end,
      setFlightMarker = function() return true end,
    }
    local settings = { get = function() return "normal" end }
    local catalog = Catalog.new(V.data("mounts"))
    local ground = Ground.new(adapter, settings, catalog)
    local surf = Surf.new(adapter, nil, nil, nil, catalog)
    local flight = Flight.new(adapter, settings, nil, catalog)
    local arcanine = { dex = 59 }
    local lapras = { dex = 131 }
    local charizard = { dex = 6 }
    T:eq(ground:speed(16, sprint, arcanine), 5)
    T:eq(ground:speed(16, normal, arcanine), 11)
    T:eq(surf:speed(16, sprint, lapras), 6)
    T:eq(surf:speed(16, normal, lapras), 13)
    T:eq(flight:speed(16, sprint, charizard), 5)
    T:eq(flight:speed(16, normal, charizard), 10)
    T:ok(ground:speed(16, normal, { dex = 111 })
      > ground:speed(16, normal, { dex = 243 }))
    T:ok(flight:speed(16, normal, { dex = 164 })
      > flight:speed(16, normal, { dex = 142 }))
  end)

  T:test("motion dynamics accelerates brakes and reacts to turns", function()
    local dynamics = MotionDynamics.new("ground")
    local profile = { launch = 0.5, acceleration = 0.1, braking = 0.25,
      turnRate = 0.75, boost = 2 }
    dynamics:reset(profile)
    T:eq(dynamics:factor(profile, { player = { facing = "right" } }, true),
      0.6)
    T:eq(dynamics:factor(profile, { player = { facing = "right" } }, true),
      0.7)
    local turned = dynamics:factor(profile,
      { player = { facing = "up" } }, true)
    T:ok(math.abs(turned - 0.625) < 0.000001)
    T:ok(dynamics:onCollision(profile, false))
    T:eq(dynamics.momentum, 0.5)
    T:eq(dynamics:sprint(profile, true), 2)
    dynamics:update(profile, 0.2, { moving = false })
    T:eq(dynamics.momentum, 0.5)
  end)

  T:test("sprint and raw shortcuts can be disabled independently", function()
    local values = { sprint_enabled = false, shortcuts_enabled = false,
      motion_personality = false, ground_speed = "normal" }
    local settings = { get = function(_, key) return values[key] end }
    local adapter = {
      isSurfing = function() return false end,
      isFreeRoam = function() return true end,
    }
    local catalog = Catalog.new(V.data("mounts"))
    local ground = Ground.new(adapter, settings, catalog)
    local sprint = { input = { isDown = function() return true end } }
    T:eq(ground:speed(16, sprint, { dex = 59 }), 11)
    local bridge = InputBridge.new(nil, adapter, nil, settings)
    T:eq(bridge:_queue("flight", {}), false)
  end)

  T:test("manual flight altitude starts above terrain and remains controllable", function()
    local axis = 1
    local auxiliary = { altitudeAxis = function() return axis end }
    local adapter = { setFlightMarker = function() return true end }
    local flight = Flight.new(adapter, nil, auxiliary)
    local session = { state = "FLIGHT", altitude = flight:takeoffTarget() }
    flight:input(session, {})
    T:ok(flight:update(session, 0.1))
    T:ok(session.altitude > 0.85 and session.altitude < 1)
    T:ok(flight:visualLift(session) > 34)
    axis = -1
    flight:input(session, {})
    T:ok(flight:update(session, 1))
    T:eq(session.altitude, 0.78)
  end)

  T:test("mounted rider is clipped lifted and restored", function()
    local previousLove = love
    love = { graphics = { newQuad = function(_, _, width, height)
      return { width = width, height = height }
    end } }
    local drawnTopHalf
    local original = function(_, _, _, _, _, _, _, _, topHalf)
      drawnTopHalf = topHalf
    end
    local sprite = {
      draw = original,
      anchorY = 16,
      frameWidth = 16,
      frameHeight = 16,
      frameCount = 6,
      image = { getDimensions = function() return 16, 96 end },
    }
    local player = { sprite = sprite }
    local world = { overworld = function() return { player = player } end }
    local bridge = RiderBridge.new()
    local session = { mode = "flight" }
    local lease = bridge:begin(session, {
      renderer = "native2d",
      pose = { riderLift = 2, clipRider = true },
    }, { world = world, generation = 1, visualLift = 4 })
    sprite:draw(0, 0, 0, 0, "down", 0, false)
    T:eq(drawnTopHalf, true)
    T:eq(sprite.halfFrames[0].height, 12)
    T:eq(sprite.anchorY, 22)
    T:ok(bridge:update(lease, session, { visualLift = 4,
      mountScale = 1.5 }))
    T:eq(sprite.anchorY, 26)
    T:ok(bridge:finish(lease))
    T:eq(sprite.anchorY, 16)
    T:eq(sprite.halfFrames, nil)
    T:eq(rawget(sprite, "draw"), original)
    love = previousLove
  end)

  T:test("voxel rider pose shares altitude and masks the standing legs",
    function()
      local previousLove = love
      local masks = 0
      local released = false
      local source = { getDimensions = function() return 16, 96 end }
      local canvas = {
        getDimensions = function() return 16, 96 end,
        setFilter = function() end,
        release = function() released = true end,
      }
      love = { graphics = {
        newCanvas = function() return canvas end,
        draw = function() end,
        rectangle = function() masks = masks + 1 end,
        push = function() end,
        pop = function() end,
        setCanvas = function() end,
        clear = function() end,
        setColor = function() end,
        setBlendMode = function() end,
      } }
      local sprite = {
        def = { image = "trainer.png", frameWidth = 16,
          frameHeight = 16, frames = 6 },
        frameWidth = 16, frameHeight = 16, frameCount = 6,
        anchorY = 16,
        draw = function() end,
        resolveImage = function() return source end,
      }
      local originalPose = function(self)
        return self.sprite, 10, 100, "down", 0, false
      end
      local player = { sprite = sprite, pose = originalPose }
      local world = { overworld = function() return { player = player } end }
      local bridge = RiderBridge.new()
      local session = { mode = "flight" }
      local lease = bridge:begin(session, {
        renderer = "voxel",
        pose = { riderLift = 2, clipRider = true },
      }, { world = world, generation = 1, visualLift = 24 })
      local posedSprite, _, posedY = player:pose()
      T:ok(posedSprite ~= sprite)
      T:eq(posedSprite.def.trueColor, true)
      T:eq(posedSprite:resolveImage(), canvas)
      T:eq(posedY, 74)
      T:eq(masks, 6)
      T:ok(bridge:finish(lease))
      T:eq(player.pose, originalPose)
      T:eq(released, true)
      love = previousLove
    end)

  T:test("Gen 1 Surf replaces and restores both native Surf sheets", function()
    local function sheet() return { draw = function() end, anchorY = 16 } end
    local walk, surf, surfPikachu = sheet(), sheet(), sheet()
    local player = {
      sprite = walk,
      surfSprite = surf,
      surfPikachuSprite = surfPikachu,
    }
    local world = { overworld = function() return { player = player } end }
    local bridge = RiderBridge.new()
    local lease = bridge:begin({ mode = "surf" }, {
      renderer = "native2d",
      pose = { riderLift = 2, clipRider = true },
    }, { world = world, generation = 1 })
    T:eq(player.surfSprite, walk)
    T:eq(player.surfPikachuSprite, walk)
    player.surfSprite = surf
    player.surfPikachuSprite = surfPikachu
    T:ok(bridge:update(lease, { mode = "surf" }, {}))
    T:eq(player.surfSprite, walk)
    T:eq(player.surfPikachuSprite, walk)
    T:ok(bridge:finish(lease))
    T:eq(player.surfSprite, surf)
    T:eq(player.surfPikachuSprite, surfPikachu)
  end)

  T:test("Gen 2 Surf keeps restoring the normal rider sheet", function()
    local function sheet(name)
      return { name = name, draw = function() end, anchorY = 16 }
    end
    local riderDef, nativeSurfDef = { id = "rider" }, { id = "surf" }
    local player = { spriteDef = nativeSurfDef, sprite = sheet("surf") }
    function player:setSprite(def)
      self.spriteDef = def
      self.sprite = sheet(def.id)
    end
    local restored = 0
    local live = {
      player = player,
      playerState = "surf",
      sprites = { PLAYER = riderDef },
      playerSpriteName = function() return "PLAYER" end,
      applySpritePalette = function() end,
      applyPlayerState = function(self)
        restored = restored + 1
        self.player:setSprite(nativeSurfDef)
      end,
    }
    local world = { overworld = function() return live end }
    local bridge = RiderBridge.new()
    local lease = bridge:begin({ mode = "surf" }, {
      renderer = "native2d",
      pose = { riderLift = 2, clipRider = true },
    }, { world = world, generation = 2 })
    T:eq(player.spriteDef, riderDef)
    player:setSprite(nativeSurfDef)
    T:ok(bridge:update(lease, { mode = "surf" }, {}))
    T:eq(player.spriteDef, riderDef)
    T:ok(bridge:finish(lease))
    T:eq(restored, 1)
    T:eq(player.spriteDef, nativeSurfDef)
  end)

  T:test("raw mount shortcuts queue actions and altitude holds", function()
    local passthrough = 0
    local game = {
      keypressed = function() passthrough = passthrough + 1 end,
      keyreleased = function() end,
      gamepadpressed = function() passthrough = passthrough + 1 end,
      gamepadreleased = function() end,
      gamepadaxis = function() end,
    }
    local adapter = { isFreeRoam = function() return true end }
    local status = { state = "UNMOUNTED" }
    local toggled
    local system = {
      snapshot = function() return status end,
      toggleMode = function(_, mode) toggled = mode return true end,
    }
    local bridge = InputBridge.new(nil, adapter):bindSystem(system)
    T:ok(bridge:attach(game))
    game:keypressed("h")
    T:eq(passthrough, 0)
    T:ok(bridge:update(game))
    T:eq(toggled, "flight")
    game:keypressed("q")
    T:eq(passthrough, 1)
    game:gamepadpressed(nil, "y")
    T:ok(bridge:update(game))
    T:eq(toggled, "ground")
    status = { state = "FLIGHT", mode = "flight" }
    game:keypressed("pageup")
    T:eq(bridge:altitudeAxis(), 1)
    game:keyreleased("pageup")
    T:eq(bridge:altitudeAxis(), 0)
    T:ok(bridge:detach())
  end)

  T:test("shortcut skips a compatible species that fails progression", function()
    local party = {
      { species = "PIDGEOT", moves = {} },
      { species = "CHARIZARD", moves = { "FLY" } },
    }
    local adapter = {
      bind = function() return true end,
      party = function() return party end,
      partySlot = function(_, mon)
        for slot, candidate in ipairs(party) do
          if candidate == mon then return slot end
        end
      end,
      fingerprint = function(_, mon) return mon.species end,
    }
    local progression = {
      canMount = function(_, _, _, opts)
        return opts.mon.moves[1] == "FLY", "must know FLY"
      end,
    }
    local resolver = {
      acquire = function(_, dex, mode)
        return {
          provider = { id = "test" },
          resolved = { dex = dex, mode = mode, renderer = "native2d" },
        }
      end,
      release = function() return true end,
      update = function() return true end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = resolver,
      progression = progression,
      adapter = adapter,
      controllers = { flight = { start = function() return true end } },
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    T:ok(system:toggleMode("flight"))
    T:eq(system:snapshot().dex, 6)
    T:eq(system:snapshot().partySlot, 2)
  end)

  T:test("reverse ledge helper accepts official ledges only", function()
    local player = { cellX = 4, cellY = 4, facing = "up", moving = false }
    local tiles = { ["4:4"] = 1, ["4:3"] = 2 }
    local map = {
      def = { tileset = "OVERWORLD" },
      cellTile = function(_, x, y) return tiles[x .. ":" .. y] end,
      inBounds = function() return true end,
    }
    local ledges = {
      { facing = "down", input = "down", standingTile = 9,
        ledgeTile = 2, tileset = "OVERWORLD" },
    }
    local live = { player = player, map = map }
    live.checkLedgeHop = function(_, direction)
      local row = ledges[#ledges]
      return direction == "up" and row.standingTile == 1
        and row.ledgeTile == 2
    end
    local world = { overworld = function() return live end }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ generation = 1, world = world,
      game = { data = { field = { ledges = ledges } } } })
    T:ok(adapter:tryReverseLedge("up"))
    T:eq(#ledges, 1)
    tiles["4:3"] = 3
    T:eq(adapter:tryReverseLedge("up"), false)
  end)

  T:test("Gen 2 reverse ledge lands on the original hop tile", function()
    local player = { cellX = 4, cellY = 4, facing = "up", moving = false }
    local collisions = { ["4:2"] = 0xa3 }
    local map = {
      cellCollision = function(_, x, y) return collisions[x .. ":" .. y] end,
      inBounds = function() return true end,
      isWalkable = function(_, x, y) return x == 4 and y == 2 end,
    }
    local live = { player = player, map = map, entities = {} }
    local world = { overworld = function() return live end }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ generation = 2, world = world })
    T:ok(adapter:tryReverseLedge("up"))
    T:eq(player.targetX, 4)
    T:eq(player.targetY, 2)
    T:eq(player.moving, true)
    T:eq(player.jumping, true)
    T:eq(player.stepFrames, 32)
    player.moving = false
    collisions["4:2"] = 0x00
    T:eq(adapter:tryReverseLedge("up"), false)
  end)

  T:test("flight isolation suppresses ground interactions and restores them", function()
    local calls = 0
    local live = {
      player = {},
      map = {},
      interact = function() calls = calls + 1 return "interacted" end,
      checkTrainerSight = function() calls = calls + 1 return "seen" end,
      checkTrainerBattle = function() calls = calls + 1 return "battle" end,
      checkWarpOnArrive = function() calls = calls + 1 return "warped" end,
      takeWarp = function() calls = calls + 1 return "taken" end,
      playerCollision = function() calls = calls + 1 return 113 end,
      checkCarpetWhileStanding = function()
        calls = calls + 1
        return "carpet"
      end,
    }
    local world = { overworld = function() return live end }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ generation = 1, world = world })
    T:ok(adapter:setFlightIsolation(true))
    T:eq(live:interact(), false)
    T:eq(live:checkTrainerSight(), false)
    T:eq(live:checkTrainerBattle(), false)
    T:eq(live:checkWarpOnArrive(), false)
    T:eq(live:takeWarp({}), false)
    T:eq(live:playerCollision(), 0)
    T:eq(live:checkCarpetWhileStanding(), false)
    T:eq(calls, 0)
    T:ok(adapter:setFlightIsolation(false))
    T:eq(live:interact(), "interacted")
    T:eq(live:checkTrainerSight(), "seen")
    T:eq(live:checkTrainerBattle(), "battle")
    T:eq(live:checkWarpOnArrive(), "warped")
    T:eq(live:takeWarp({}), "taken")
    T:eq(live:playerCollision(), 113)
    T:eq(live:checkCarpetWhileStanding(), "carpet")
    T:eq(calls, 7)
  end)

  T:test("Gen 1 flight connection bypass is scoped and restores terrain rules", function()
    local moduleName = "src.world.Map"
    local previousLoaded = package.loaded[moduleName]
    local previousPreload = package.preload[moduleName]
    local groundPassable = function() return false end
    local mapApi = { defPassable = groundPassable }
    package.loaded[moduleName] = nil
    package.preload[moduleName] = function() return mapApi end

    local live = {
      player = {}, map = {},
      canCollisionWarp = function() return true end,
      crossConnection = function()
        return mapApi.defPassable({}, {}, 0, 0, false)
      end,
    }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ generation = 1,
      world = { overworld = function() return live end } })
    adapter:setFlightIsolation(true)
    local warpInFlight = live:canCollisionWarp()
    local crossedInFlight = live:crossConnection("right", {})
    local restoredDuringFlight = mapApi.defPassable == groundPassable
    adapter:setFlightIsolation(false)
    local warpOnGround = live:canCollisionWarp()
    local crossedOnGround = live:crossConnection("right", {})

    package.loaded[moduleName] = previousLoaded
    package.preload[moduleName] = previousPreload
    T:eq(warpInFlight, false)
    T:eq(crossedInFlight, true)
    T:eq(restoredDuringFlight, true)
    T:eq(warpOnGround, true)
    T:eq(crossedOnGround, false)
  end)

  T:test("airborne warp suppression is generation aware", function()
    local live1 = { player = {}, map = {} }
    local adapter1 = RuntimeAdapter.new()
    adapter1:bind({ generation = 1,
      world = { overworld = function() return live1 end } })
    T:ok(adapter1:suppressWarpAt(3, 5))
    T:eq(live1.warpEntryCell.x, 3)
    T:eq(live1.warpEntryCell.y, 5)

    local live2 = { player = {}, map = {} }
    local adapter2 = RuntimeAdapter.new()
    adapter2:bind({ generation = 2,
      world = { overworld = function() return live2 end } })
    T:ok(adapter2:suppressWarpAt(7, 9))
    T:eq(live2.warpCooldown.x, 7)
    T:eq(live2.warpCooldown.y, 9)
  end)

  T:test("direct water transfer updates each native Surf state", function()
    local synced = 0
    local live1 = {
      player = { surfing = false }, map = { id = "ROUTE_19" },
      syncSurfingPikachu = function() synced = synced + 1 end,
    }
    local adapter1 = RuntimeAdapter.new()
    adapter1:bind({ generation = 1,
      world = { overworld = function() return live1 end },
      game = { save = { onBike = true } },
    })
    adapter1.currentTerrain = function() return "water" end
    T:ok(adapter1:setSurfState(true))
    T:eq(live1.player.surfing, true)
    T:eq(adapter1:game().save.onBike, false)
    T:ok(adapter1:setSurfState(false))
    T:eq(live1.player.surfing, false)
    T:eq(synced, 2)

    local states = {}
    local live2 = {
      player = {}, map = { id = "ROUTE_40" },
      applyPlayerState = function(_, state) states[#states + 1] = state end,
    }
    local adapter2 = RuntimeAdapter.new()
    adapter2:bind({ generation = 2,
      world = { overworld = function() return live2 end } })
    adapter2.currentTerrain = function() return "water" end
    T:ok(adapter2:setSurfState(true))
    T:ok(adapter2:setSurfState(false))
    T:eq(states[1], "surf")
    T:eq(states[2], "normal")
  end)
end

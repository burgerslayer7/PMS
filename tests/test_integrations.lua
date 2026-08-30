return function(T, V)
  local VoxelCompanion = V.require("integrations/VoxelCompanion")
  local PotatoVoxel = V.require("integrations/PotatoVoxel")
  local VoxelHosts = V.require("integrations/VoxelHosts")
  local Stadium = V.require("providers/StadiumProvider")
  local RenderOwnership = V.require("integrations/RenderOwnership")
  local WildsIsolation = V.require("integrations/WildsEncounterIsolation")
  local WildsSprites = V.require("providers/WildsSpriteProvider")
  local VoxelBillboards = V.require("providers/VoxelBillboardProvider")
  local WildSkies = V.require("integrations/WildSkies")
  local Crystal251 = V.require("integrations/Crystal251")
  local Catalog = V.require("core/MountCatalog")

  T:test("Voxel Companion observer follows active render frames only", function()
    local spec
    local receipt = {
      is_active = function() return true end,
      dispose = function() return true end,
    }
    local handle = {
      version = "1.9.8",
      exports = { voxel_companion = {
        api = 1,
        host = { id = "BATTLE_ART_VOXEL_FORK", version = "1.9.8" },
        capabilities = { render_phases = 1 },
        register = function(value) spec = value return receipt end,
      } },
    }
    local mod = { find = function(id)
      if id == "BATTLE_ART_VOXEL_FORK" then return handle end
    end }
    local observer = VoxelCompanion.new(mod)
    T:ok(observer:discover())
    T:eq(spec.api, 1)
    T:eq(spec.id, "pokemon-mount-system.renderer-observer")
    T:eq(observer:activeHost(), nil)
    spec.phases.background({ camera = { mode = "third_person",
      eye = { 0, 10, 10 }, focus = { 10, 0, 10 } }, frame = {} })
    local active = observer:activeHost()
    T:eq(active.id, "BATTLE_ART_VOXEL_FORK")
    T:eq(active.cameraMode, "third_person")
    local orientation = observer:movementOrientation()
    T:eq(orientation.kind, "camera")
    T:ok(math.abs(orientation.yaw - math.pi / 2) < 0.000001)
    for _ = 1, 4 do observer:advance() end
    T:eq(observer:activeHost(), nil)
    T:ok(observer:cleanup())
  end)

  T:test("PotatoVoxel follows the engine voxel pipeline without private APIs",
    function()
      local previous = package.loaded["src.render.Pipelines"]
      local level = 0
      package.loaded["src.render.Pipelines"] = {
        level = function(name)
          T:eq(name, "voxel")
          return level
        end,
      }
      local potato = PotatoVoxel.new({ find = function(id)
        if id == "potato_voxel" then
          return { version = "mismatched-on-purpose", exports = {
            isLoading = function() return false end,
          } }
        end
      end })
      T:ok(potato:discover())
      T:eq(potato:activeHost(), nil)
      level = 35
      T:ok(potato:advance({}))
      T:eq(potato:activeHost().id, "potato_voxel")
      T:eq(potato:status().detection, "engine-voxel-pipeline")
      level = 0
      T:eq(potato:advance({}), false)
      T:eq(potato:activeHost(), nil)
      T:ok(potato:cleanup())
      package.loaded["src.render.Pipelines"] = previous
    end)

  T:test("voxel host aggregation preserves standard hosts and adds Potato",
    function()
      local standardActive, potatoActive = false, true
      local standard = {
        discover = function() return true end,
        advance = function() return true end,
        activeHost = function()
          return standardActive and { id = "DRAMALESS_SHAPE" } or nil
        end,
        movementOrientation = function() return { kind = "camera" } end,
        status = function() return { active = standardActive } end,
        cleanup = function() return true end,
      }
      local potato = {
        discover = function() return true end,
        advance = function(_, system) T:ok(system ~= nil) end,
        activeHost = function()
          return potatoActive and { id = "potato_voxel" } or nil
        end,
        status = function() return { active = potatoActive } end,
        cleanup = function() return true end,
      }
      local hosts = VoxelHosts.new(standard, potato)
      T:ok(hosts:discover())
      hosts:advance({ runtime = {} })
      T:eq(hosts:activeHost().id, "potato_voxel")
      standardActive = true
      T:eq(hosts:activeHost().id, "DRAMALESS_SHAPE")
      T:eq(hosts:movementOrientation().kind, "camera")
      T:eq(hosts:status().active, "DRAMALESS_SHAPE")
      T:ok(hosts:cleanup())
    end)

  T:test("render ownership hides only the mounted follower species", function()
    local lapras = { pokepcTrailer = true, pokepcTrailerKind = "mon",
      pokepcMon = { species = "LAPRAS" } }
    local pikachu = { pikachuFollower = true }
    local trainer = { pokepcTrailer = true, pokepcTrailerKind = "trainer" }
    local live = {
      entities = { lapras, pikachu, trainer },
      npcs = { lapras, pikachu, trainer },
      pokepcTrailers = { lapras, trainer },
    }
    local runtime = { world = { overworld = function() return live end } }
    local ownership = RenderOwnership.new()
    local lease = ownership:acquire({ species = "LAPRAS" }, runtime)
    T:eq(#live.entities, 2)
    T:eq(live.entities[1], pikachu)
    T:eq(live.entities[2], trainer)
    T:ok(ownership:release(lease))
    T:eq(#live.entities, 3)
    T:ok(lapras == live.entities[3])
  end)

  T:test("render ownership returns authority through Followers EX public API",
    function()
      local synced = 0
      local follower = { pokepcMon = { species = "ARCANINE" } }
      local live = { entities = { follower }, npcs = { follower },
        pokepcTrailers = { follower } }
      local game = {}
      local mod = { find = function(id)
        if id == "FOLLOWERS_EX" then
          return { exports = { syncTrailers = function(g, ow, opts)
            T:eq(g, game)
            T:eq(ow, live)
            T:eq(opts.pmsOwnershipRelease, true)
            synced = synced + 1
          end } }
        end
      end }
      local ownership = RenderOwnership.new(nil, mod)
      local lease = ownership:acquire({ species = "ARCANINE" }, {
        game = game,
        world = { overworld = function() return live end },
      })
      T:eq(#live.entities, 0)
      T:ok(ownership:release(lease))
      T:eq(#live.entities, 1)
      T:eq(synced, 1)
    end)

  T:test("Gen1 Stadium provider tags the PMS-owned actor and restores it", function()
    local tagged, untagged
    local exports = {
      rendererInstalled = true,
      maxDex = 151,
      world3DEnabled = function() return true end,
      tag = function(entity, dex) tagged = { entity, dex } return true end,
      untag = function(entity) untagged = entity return true end,
    }
    local mod = { find = function(id)
      if id == "STADIUM_OVERWORLD_MODELS" then
        return { version = "0.1.47", exports = exports }
      end
    end }
    local entity = {}
    local removed = 0
    local bridge = {
      spawn = function(_, resolved)
        return { resolved = resolved, entity = entity }
      end,
      entity = function(_, lease) return lease.entity end,
      sync = function() return true end,
      remove = function() removed = removed + 1 return true end,
    }
    local provider = Stadium.new({
      mod = mod,
      catalog = { get = function(_, dex)
        return dex == 6 and { species = "CHARIZARD", modes = { flight = true } }
      end },
      poses = { resolve = function() return { scale = 4 } end },
      builtin = { spriteId = function() return "PMS_MOUNT_006_FLIGHT" end },
      bridge = bridge,
    })
    local contract = provider:contract()
    local probe = assert(contract:probe({ generation = 1,
      preferredRenderer = "auto" }))
    T:eq(probe.dexLast, 151)
    local resolved = assert(contract:resolve(6, "flight", { generation = 1 }))
    local lease = assert(contract:begin(resolved, {}))
    T:eq(tagged[1], entity)
    T:eq(tagged[2], 6)
    T:ok(contract:update(lease, {}))
    T:ok(contract:finish(lease, "test"))
    T:eq(untagged, entity)
    T:eq(removed, 1)
    local gen2, reason = contract:probe({ generation = 2 })
    T:eq(gen2, nil)
    T:matches(reason, "outside the supported runtime")
  end)

  T:test("Wilds ground battles are vetoed only while PMS is airborne", function()
    local airborne = false
    local starts = 0
    local logic = { _startBattle = function()
      starts = starts + 1
      return true
    end }
    local mod = { find = function(id)
      if id == "overworld_wild_spawns" then
        return { exports = { logic = logic } }
      end
    end }
    local system = { isAirborne = function() return airborne end }
    local isolation = WildsIsolation.new(mod, system)
    T:ok(isolation:discover())
    T:eq(logic:_startBattle({}), true)
    airborne = true
    T:eq(logic:_startBattle({}), false)
    T:eq(starts, 1)
    T:ok(isolation:cleanup())
    T:eq(logic:_startBattle({}), true)
    T:eq(starts, 2)
  end)

  T:test("Wilds sprite provider follows its selected public style", function()
    local style = "followers"
    local replacements = {}
    local handle = {
      exports = { resolveFollowerSprite = function(opts)
        local classic = style == "followers"
        return {
          image = "/wilds/" .. style .. "/" .. opts.species .. ".png",
          frames = 6, walker = true, trueColor = not classic,
          frameWidth = classic and 16 or 47,
          frameHeight = classic and 16 or 47,
          anchorX = classic and 8 or 23,
          anchorY = classic and 16 or 45,
          providerId = style,
        }
      end },
    }
    local mod = { find = function(id)
      if id == "overworld_wild_spawns" then return handle end
    end }
    local bridge = {
      spawn = function(_, resolved) return { resolved = resolved } end,
      replaceSprite = function(_, lease, def, token)
        replacements[#replacements + 1] = { def = def, token = token }
        lease.externalSpriteToken = token
        return true
      end,
      sync = function() return true end,
      remove = function() return true end,
    }
    local source = "auto"
    local provider = WildsSprites.new({
      mod = mod,
      catalog = Catalog.new(V.data("mounts")),
      scale = { frameSize = function() return 21 end },
      poses = { resolve = function()
        return { clipRider = true, riderLift = 0 }
      end },
      builtin = { spriteId = function() return "PMS_MOUNT_006_FLIGHT" end },
      bridge = bridge,
      settings = { get = function() return source end },
    }):contract()
    local probe = assert(provider:probe({ activeRenderer = "native2d" }))
    T:eq(probe.spriteSource, "wilds")
    local resolved = assert(provider:resolve(6, "flight", {}))
    T:matches(resolved.externalDef.image, "followers")
    T:eq(resolved.externalDef.pmsDisplayScale, 21 / 16)
    T:eq(resolved.pose.riderLift, 3)
    local livePose = resolved.pose
    local lease = assert(provider:begin(resolved, {}))
    T:eq(#replacements, 1)
    style = "pokemmo"
    for _ = 1, 30 do T:ok(provider:update(lease, {})) end
    T:eq(#replacements, 2)
    T:matches(replacements[2].def.image, "pokemmo")
    T:eq(replacements[2].def.pmsDisplayScale, 1)
    T:eq(resolved.pose, livePose)
    T:eq(resolved.pose.riderLift, 14)
    source = "builtin"
    T:eq(provider:probe({ activeRenderer = "native2d" }), nil)
  end)

  T:test("voxel billboard keeps the selected Wilds art instead of fallback",
    function()
      local began, updated
      local wilds = {
        resolveArt = function(_, mount, mode)
          T:eq(mount.species, "CHARIZARD")
          T:eq(mode, "flight")
          return { image = "/wilds/pokemmo/charizard.png",
            frameWidth = 47, frameHeight = 47, frames = 6 },
            "pokemmo|charizard", "pokemmo", "pokemmo"
        end,
        applyExternalPoses = function(_, resolved, def)
          resolved.pose.externalFrameHeight = def.frameHeight
        end,
        beginActor = function(_, resolved)
          began = resolved
          return { resolved = resolved }
        end,
        updateActor = function(_, lease)
          updated = lease
          return true
        end,
      }
      local provider = VoxelBillboards.new({
        catalog = { get = function(_, dex)
          if dex == 6 then
            return { dex = 6, species = "CHARIZARD",
              modes = { flight = true } }
          end
        end },
        poses = { resolve = function() return {} end },
        builtin = {
          spriteId = function() return "PMS_MOUNT_006_FLIGHT" end,
          definition = function() return { image = "/pms/006.png",
            frameWidth = 21, frameHeight = 21 }
          end,
        },
        bridge = {},
        voxel = { activeHost = function()
          return { id = "potato_voxel" }
        end },
        wilds = wilds,
      })
      local receipt = assert(provider:probe({ activeRenderer = "voxel",
        rendererHost = "potato_voxel" }))
      T:eq(receipt.host, "potato_voxel")
      local resolved = assert(provider:resolve(6, "flight", {
        rendererHost = "potato_voxel", spriteSource = "auto",
      }))
      T:matches(resolved.externalDef.image, "pokemmo")
      T:eq(resolved.voxelGeometryDef.frameWidth, 21)
      T:eq(resolved.pose.externalFrameHeight, 47)
      local lease = assert(provider:begin(resolved, {}))
      T:eq(began.externalToken, "pokemmo|charizard")
      T:ok(provider:update(lease, {}))
      T:eq(updated, lease)
    end)

  T:test("Wild Skies interception consumes and queues the exact flyer",
    function()
      local taken, queued, organic = 0, nil, 0
      local skies = { exports = { takeFlyer = function(x, y, radius)
        T:eq(x, 4)
        T:eq(y, 7)
        T:eq(radius, 2)
        taken = taken + 1
        return { species = "PIDGEOT", level = 23 }
      end } }
      local doubles = { exports = { tagOrganic = function()
        organic = organic + 1
      end } }
      local world = { queueScript = function(_, rows)
        queued = rows
        return true
      end }
      local mod = { find = function(id)
        if id == "wild_skies" then return skies end
        if id == "double_battles" then return doubles end
      end }
      local adapter = {
        isFreeRoam = function() return true end,
        position = function() return { x = 4, y = 7 } end,
        world = function() return world end,
      }
      local integration = WildSkies.new({ mod = mod, adapter = adapter,
        settings = { get = function() return true end },
        system = { snapshot = function()
          return { mode = "flight", state = "FLIGHT", altitude = 0.95 }
        end },
      })
      T:ok(integration:discover())
      T:ok(integration:update(0.2))
      T:eq(taken, 1)
      T:eq(organic, 1)
      T:eq(queued[1][1], "start_battle")
      T:eq(queued[1][3], "PIDGEOT")
      T:eq(queued[1][4], 23)
      T:eq(integration:status().lastEncounter.radius, 2)
      T:eq(integration:update(0.1), false)
      T:eq(taken, 1)
    end)

  T:test("Wild Skies interception respects the air encounter setting",
    function()
      local integration = WildSkies.new({
        mod = { find = function()
          return { exports = { takeFlyer = function()
            error("must not consume")
          end } }
        end },
        adapter = {},
        settings = { get = function() return false end },
        system = { snapshot = function()
          return { mode = "flight", state = "FLIGHT" }
        end },
      })
      T:eq(integration:update(1), false)
    end)

  T:test("Crystal 251 uses only its public Gen1 dataset capability", function()
    local generation = 1
    local crystal = Crystal251.new({ find = function(id)
      if id == "CRYSTAL_251" then
        return { version = "0.11.6", exports = {
          dexSize = 251,
          revision = "crystal-us-11",
          fingerprint = "crystal-us-11:251:251:v22",
          crystalRuntime = { private = true },
        } }
      end
    end }, { generation = function() return generation end })
    T:ok(crystal:discover())
    local status = crystal:status()
    T:eq(status.installed, true)
    T:eq(status.active, true)
    T:eq(status.dexSize, 251)
    T:eq(status.revision, "crystal-us-11")
    T:eq(status.crystalRuntime, nil)
    generation = 2
    T:eq(crystal:discover(), false)
    status = crystal:status()
    T:eq(status.installed, true)
    T:eq(status.active, false)
    T:matches(status.reason, "native Gen2")
    T:ok(crystal:cleanup())
    T:eq(crystal:status().installed, false)
  end)
end

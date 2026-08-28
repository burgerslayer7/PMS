return function(T, V)
  local VoxelCompanion = V.require("integrations/VoxelCompanion")
  local Stadium = V.require("providers/StadiumProvider")
  local RenderOwnership = V.require("integrations/RenderOwnership")

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
    spec.phases.background({ camera = { mode = "third_person" }, frame = {} })
    local active = observer:activeHost()
    T:eq(active.id, "BATTLE_ART_VOXEL_FORK")
    T:eq(active.cameraMode, "third_person")
    for _ = 1, 4 do observer:advance() end
    T:eq(observer:activeHost(), nil)
    T:ok(observer:cleanup())
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

  T:test("Stadium provider tags the PMS-owned actor and restores it", function()
    local tagged, untagged
    local exports = {
      rendererInstalled = true,
      maxDex = 251,
      world3DEnabled = function() return true end,
      tag = function(entity, dex) tagged = { entity, dex } return true end,
      untag = function(entity) untagged = entity return true end,
    }
    local mod = { find = function(id)
      if id == "STADIUM2_OVERWORLD_MODELS" then
        return { version = "0.4.33", exports = exports }
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
        return dex == 250 and { species = "HO_OH", modes = { flight = true } }
      end },
      poses = { resolve = function() return { scale = 4 } end },
      builtin = { spriteId = function() return "PMS_MOUNT_250_FLIGHT" end },
      bridge = bridge,
    })
    local contract = provider:contract()
    local probe = assert(contract:probe({ generation = 2,
      preferredRenderer = "auto" }))
    T:eq(probe.dexLast, 251)
    local resolved = assert(contract:resolve(250, "flight", { generation = 2 }))
    local lease = assert(contract:begin(resolved, {}))
    T:eq(tagged[1], entity)
    T:eq(tagged[2], 250)
    T:ok(contract:update(lease, {}))
    T:ok(contract:finish(lease, "test"))
    T:eq(untagged, entity)
    T:eq(removed, 1)
  end)
end

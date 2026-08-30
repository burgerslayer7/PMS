return function(T, V)
  local State = V.require("core/MountState")
  local Catalog = V.require("core/MountCatalog")
  local Registry = V.require("providers/ProviderRegistry")
  local Resolver = V.require("rendering/RenderResolver")
  local MountSystem = V.require("core/MountSystem")

  local function newSystem()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "test_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
      finish = function() end,
    })
    local settings = {
      get = function(_, key)
        if key == "preferred_renderer" then return "auto" end
        if key == "auto_remount_after_battle" then return true end
      end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      settings = settings,
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    return system
  end

  T:test("ground mount survives battle and map lifecycle", function()
    local system = newSystem()
    T:ok(system:mount(59, "ground"))
    T:eq(system:snapshot().state, State.GROUND)
    T:eq(system:snapshot().provider, "test_2d")
    T:ok(system:onBattleStarted({ kind = "wild" }))
    T:eq(system:snapshot().state, State.BATTLE_SUSPENDED)
    T:ok(system:onBattleEnded({ result = "win" }))
    T:eq(system:snapshot().state, State.GROUND)
    T:ok(system:onMapExited({ mapId = "ROUTE_1" }))
    T:eq(system:snapshot().state, State.TRANSITION)
    T:ok(system:onMapEntered({ mapId = "VIRIDIAN_CITY" }))
    T:eq(system:snapshot().state, State.GROUND)
    T:ok(system:dismount("test"))
    T:eq(system:snapshot().state, State.UNMOUNTED)
  end)

  T:test("flight progresses through takeoff to stable flight", function()
    local system = newSystem()
    T:ok(system:mount(6, "flight"))
    T:eq(system:snapshot().state, State.TAKEOFF)
    T:eq(system:isAirborne(), true)
    system:update(1)
    T:eq(system:snapshot().state, State.FLIGHT)
    T:eq(system:isAirborne(), true)
    T:eq(system:snapshot().altitude, 0.85)
  end)

  T:test("ground and flight shortcuts exchange mounts in one press", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "land_transfer_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local arcanine = { species = "ARCANINE" }
    local charizard = { species = "CHARIZARD", moves = { "FLY" } }
    local party = { arcanine, charizard }
    local groundStarts, groundStops, flightStarts, flightStops = 0, 0, 0, 0
    local refuseFlight = false
    local adapter = {
      bind = function() return true end,
      party = function() return party end,
      partySlot = function(_, mon) return mon == arcanine and 1 or 2 end,
      partyMon = function(_, slot) return party[slot] end,
      fingerprint = function(_, mon) return mon.species end,
    }
    local ground = {
      start = function() groundStarts = groundStarts + 1 return true end,
      stop = function() groundStops = groundStops + 1 return true end,
      update = function() return true end,
    }
    local flight = {
      start = function()
        flightStarts = flightStarts + 1
        if refuseFlight then return nil, "test refusal" end
        return true
      end,
      stop = function() flightStops = flightStops + 1 return true end,
      update = function() return true end,
      canLand = function() return true end,
      takeoffTarget = function() return 0.85 end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = adapter,
      progression = { canMount = function() return true end },
      controllers = { ground = ground, flight = flight },
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })

    T:ok(system:mount(59, "ground", { partySlot = 1,
      partyFingerprint = "ARCANINE" }))
    T:ok(system:toggleMode("flight"))
    T:eq(system:snapshot().state, State.TAKEOFF)
    T:eq(system:snapshot().dex, 6)
    system:update(1)
    T:eq(system:snapshot().state, State.FLIGHT)
    T:ok(system:toggleMode("ground"))
    T:eq(system:snapshot().state, State.GROUND)
    T:eq(system:snapshot().dex, 59)
    T:eq(groundStarts, 2)
    T:eq(groundStops, 1)
    T:eq(flightStarts, 1)
    T:eq(flightStops, 1)
    refuseFlight = true
    local switched, switchErr = system:toggleMode("flight")
    T:eq(switched, nil)
    T:matches(switchErr, "test refusal")
    T:eq(system:snapshot().state, State.GROUND)
    T:eq(system:snapshot().dex, 59)
    T:eq(groundStarts, 3)
    T:eq(groundStops, 2)
    T:eq(flightStarts, 2)
    T:eq(flightStops, 2)
  end)

  T:test("takeoff interrupted by battle resumes as stable flight", function()
    local system = newSystem()
    T:ok(system:mount(6, "flight"))
    T:eq(system:snapshot().state, State.TAKEOFF)
    T:ok(system:onBattleStarted({ kind = "wild" }))
    T:eq(system:snapshot().state, State.BATTLE_SUSPENDED)
    T:ok(system:onBattleEnded({ result = "win" }))
    T:eq(system:snapshot().state, State.FLIGHT)
  end)

  T:test("battle remount waits for free roam and revalidates identity", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "battle_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local freeRoam, resumed = false, 0
    local mon = { species = "ARCANINE", hp = 70 }
    local controller = {
      start = function() return true end,
      update = function() return true end,
      suspend = function() return true end,
      resume = function() resumed = resumed + 1 return true end,
      stop = function() return true end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = { bind = function() return true end,
        isFreeRoam = function() return freeRoam end },
      identity = { resolve = function()
        return mon, 2, "stable-arcanine"
      end },
      progression = { canMount = function(_, _, _, opts)
        if opts.transition then T:eq(opts.mon, mon) end
        return true
      end },
      controllers = { ground = controller },
    })
    system:enable({ generation = 2, activeRenderer = "native2d" })
    T:ok(system:mount(59, "ground", { partySlot = 1,
      partyFingerprint = "before-battle" }))
    T:ok(system:onBattleStarted({ kind = "wild" }))
    T:ok(system:onBattleEnded({ result = "win" }))
    T:eq(system:snapshot().state, State.BATTLE_SUSPENDED)
    T:eq(system:snapshot().battleResumePending, true)
    system:update(0.5)
    T:eq(resumed, 0)
    freeRoam = true
    system:update(0.1)
    T:eq(system:snapshot().state, State.GROUND)
    T:eq(system:snapshot().partySlot, 2)
    T:eq(system:snapshot().battleResumePending, false)
    T:eq(resumed, 1)
  end)

  T:test("battle remount dismounts when the exact Pokemon is ineligible", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "identity_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = { bind = function() return true end,
        isFreeRoam = function() return true end },
      identity = { resolve = function()
        return nil, "The mounted Pokemon fainted."
      end },
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    T:ok(system:mount(59, "ground"))
    T:ok(system:onBattleStarted({ kind = "trainer" }))
    T:ok(system:onBattleEnded({ result = "win" }))
    T:eq(system:snapshot().state, State.UNMOUNTED)
    T:eq(system:snapshot().battleResumePending, false)
  end)

  T:test("battle map transition cancels a pending remount safely", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "blackout_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = { bind = function() return true end,
        isFreeRoam = function() return false end },
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    T:ok(system:mount(59, "ground"))
    T:ok(system:onBattleStarted({ kind = "trainer" }))
    T:ok(system:onBattleEnded({ result = "loss" }))
    T:eq(system:snapshot().battleResumePending, true)
    T:ok(system:onMapExited({ mapId = "POKEMON_CENTER" }))
    T:eq(system:snapshot().state, State.UNMOUNTED)
    T:eq(system:snapshot().battleResumePending, false)
  end)

  T:test("restored mode preference wins over party order", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "preference_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local tauros = { species = "TAUROS" }
    local arcanine = { species = "ARCANINE" }
    local party = { tauros, arcanine }
    local adapter = {
      bind = function() return true end,
      party = function() return party end,
      partySlot = function(_, mon) return mon == tauros and 1 or 2 end,
      partyMon = function(_, slot, species, fingerprint)
        local mon = party[slot]
        if mon and mon.species == species
            and mon.species == fingerprint then return mon end
      end,
      fingerprint = function(_, mon) return mon.species end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = adapter,
      progression = { canMount = function() return true end },
    })
    system:enable({ generation = 2, activeRenderer = "native2d" })
    T:ok(system:restoreSelections({ ground = {
      dex = 59, partySlot = 2, partyFingerprint = "ARCANINE",
    } }))
    T:ok(system:toggleMode("ground"))
    T:eq(system:snapshot().dex, 59)
    T:eq(system:snapshot().partySlot, 2)
  end)

  T:test("invalid mount requests leave the authority unmounted", function()
    local system = newSystem()
    local ok, err = system:mount(59, "flight")
    T:eq(ok, nil)
    T:matches(err, "does not support")
    T:eq(system:snapshot().state, State.UNMOUNTED)
    T:eq(system:mount(999, "ground"), nil)
    T:eq(system:snapshot().state, State.UNMOUNTED)
  end)

  T:test("disable always releases transient state", function()
    local system = newSystem()
    T:ok(system:mount(6, "flight"))
    T:ok(system:disable("reload"))
    local status = system:snapshot()
    T:eq(status.state, State.UNMOUNTED)
    T:eq(status.enabled, false)
    T:eq(status.dex, nil)
  end)

  T:test("water transfer reuses the last Surf and Flight mounts", function()
    local registry = Registry.new()
    registry:register({
      api = 1, id = "transfer_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
    })
    local charizard = { species = "CHARIZARD", moves = { "FLY" } }
    local lapras = { species = "LAPRAS", moves = { "SURF" } }
    local party = { charizard, lapras }
    local terrain, surfing = "land", false
    local nativeChanges = {}
    local adapter = {
      bind = function() return true end,
      currentTerrain = function() return terrain end,
      isSurfing = function() return surfing end,
      party = function() return party end,
      partySlot = function(_, mon) return mon == charizard and 1 or 2 end,
      partyMon = function(_, slot) return party[slot] end,
      fingerprint = function(_, mon) return mon.species end,
      setSurfState = function(_, active)
        surfing = active
        nativeChanges[#nativeChanges + 1] = active
        return true
      end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      adapter = adapter,
      progression = { canMount = function() return true end },
      controllers = {},
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })

    surfing = true
    T:ok(system:mount(131, "surf", { mon = lapras, partySlot = 2,
      partyFingerprint = "LAPRAS" }))
    T:ok(system:dismount("test"))
    surfing = false
    T:ok(system:mount(6, "flight", { mon = charizard, partySlot = 1,
      partyFingerprint = "CHARIZARD" }))
    system:update(1)
    terrain = "water"
    T:ok(system:requestLanding("test-water"))
    T:eq(system:snapshot().state, State.SURF)
    T:eq(system:snapshot().dex, 131)
    T:eq(surfing, true)
    T:ok(system:toggleMode("flight"))
    T:eq(system:snapshot().state, State.TAKEOFF)
    T:eq(system:snapshot().dex, 6)
    T:eq(surfing, false)
    T:eq(nativeChanges[1], true)
    T:eq(nativeChanges[2], false)
  end)

  T:test("temporary actor failure recovers from the invisible fallback", function()
    local registry = Registry.new()
    local starts = 0
    registry:register({
      api = 1, id = "recovering_2d", priority = 100,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
      begin = function()
        starts = starts + 1
        if starts == 1 then return nil, "map actor not ready" end
        return { visible = true }
      end,
      update = function() return true end,
      finish = function() return true end,
    })
    registry:register({
      api = 1, id = "test_technical", priority = -1000,
      probe = function() return { kind = "technical" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d",
          visible = false }
      end,
      begin = function() return {} end,
      finish = function() return true end,
    })
    local riderStarts = 0
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      rider = { begin = function() riderStarts = riderStarts + 1 return {} end,
        finish = function() return true end },
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    T:ok(system:mount(59, "ground"))
    T:eq(system:snapshot().provider, "test_technical")
    T:eq(system:snapshot().presentationPending, true)
    T:eq(riderStarts, 0)
    system:update(0.2)
    T:eq(system:snapshot().provider, "recovering_2d")
    T:eq(system:snapshot().presentationPending, false)
    T:eq(riderStarts, 1)
    T:eq(starts, 2)
  end)

  T:test("presentation recovery stops after its bounded retry window", function()
    local registry = Registry.new()
    local attempts = 0
    registry:register({
      api = 1, id = "never_ready_2d", priority = 100,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
      begin = function()
        attempts = attempts + 1
        return nil, "map actor unavailable"
      end,
    })
    registry:register({
      api = 1, id = "bounded_technical", priority = -1000,
      probe = function() return { kind = "technical" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d",
          visible = false }
      end,
      begin = function() return {} end,
      finish = function() return true end,
    })
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
    })
    system:enable({ generation = 1, activeRenderer = "native2d" })
    T:ok(system:mount(59, "ground"))
    for _ = 1, 8 do system:update(0.2) end
    T:eq(system:snapshot().presentationPending, false)
    T:eq(system:snapshot().provider, "bounded_technical")
    T:eq(attempts, 9)
  end)

  T:test("map reload rebuilds leases without changing mount state", function()
    local registry = Registry.new()
    local begins, finishes, mapEnters = 0, 0, 0
    registry:register({
      api = 1, id = "reload_2d", priority = 1,
      probe = function() return { kind = "builtin2d" } end,
      resolve = function(_, dex, mode)
        return { dex = dex, mode = mode, renderer = "native2d" }
      end,
      begin = function() begins = begins + 1 return {} end,
      update = function() return true end,
      finish = function() finishes = finishes + 1 return true end,
    })
    local controller = {
      start = function() return true end,
      update = function() return true end,
      mapEnter = function() mapEnters = mapEnters + 1 return true end,
      stop = function() return true end,
    }
    local system = MountSystem.new({
      state = State,
      catalog = Catalog.new(V.data("mounts")),
      resolver = Resolver.new(registry),
      controllers = { ground = controller },
    })
    system:enable({ generation = 2, activeRenderer = "native2d",
      mapId = "GOLDENROD_CITY" })
    T:ok(system:mount(59, "ground"))
    T:ok(system:onMapReloaded({ mapId = "GOLDENROD_CITY" }))
    local status = system:snapshot()
    T:eq(status.state, State.GROUND)
    T:eq(status.mapRevision, 1)
    T:eq(status.provider, "reload_2d")
    T:eq(status.presentationPending, false)
    T:eq(begins, 2)
    T:eq(finishes, 1)
    T:eq(mapEnters, 1)
  end)
end

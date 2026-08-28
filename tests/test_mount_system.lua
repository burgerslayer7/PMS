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
    system:update(1)
    T:eq(system:snapshot().state, State.FLIGHT)
    T:eq(system:snapshot().altitude, 1)
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
end

return function(T, V)
  local Registry = V.require("providers/ProviderRegistry")
  local Resolver = V.require("rendering/RenderResolver")

  local function provider(id, priority, kind, supports, begin)
    return {
      api = 1,
      id = id,
      priority = priority,
      probe = function()
        return { available = true, kind = kind, renderer = kind }
      end,
      resolve = function(_, dex, mode)
        if supports(dex, mode) then
          return { dex = dex, mode = mode, renderer = kind }
        end
        return nil, "unsupported species"
      end,
      begin = begin,
    }
  end

  T:test("provider registry rejects invalid and duplicate providers", function()
    local registry = Registry.new()
    local unregister, err = registry:register({ id = "bad" })
    T:eq(unregister, nil)
    T:matches(err, "api")
    local p = provider("one", 1, "builtin2d", function() return true end)
    T:ok(registry:register(p))
    local second, duplicate = registry:register(p)
    T:eq(second, nil)
    T:matches(duplicate, "duplicate provider")
  end)

  T:test("resolver falls back per species instead of failing globally", function()
    local registry = Registry.new()
    registry:register(provider("voxel", 100, "voxel",
      function(dex) return dex == 6 end))
    registry:register(provider("builtin", 10, "builtin2d",
      function() return true end))
    local resolver = Resolver.new(registry)
    local charizard = assert(resolver:acquire(6, "flight", {
      activeRenderer = "voxel", preferredRenderer = "auto",
    }))
    T:eq(charizard.provider.id, "voxel")
    local hooh = assert(resolver:acquire(250, "flight", {
      activeRenderer = "voxel", preferredRenderer = "auto",
    }))
    T:eq(hooh.provider.id, "builtin")
  end)

  T:test("explicit native 2D preference is deterministic", function()
    local registry = Registry.new()
    registry:register(provider("voxel", 500, "voxel", function() return true end))
    registry:register(provider("builtin", 1, "builtin2d", function() return true end))
    local lease = assert(Resolver.new(registry):acquire(6, "flight", {
      activeRenderer = "voxel", preferredRenderer = "native2d",
    }))
    T:eq(lease.provider.id, "builtin")
  end)

  T:test("begin failure degrades to the next provider", function()
    local registry = Registry.new()
    registry:register(provider("broken", 1000, "voxel",
      function() return true end,
      function() return nil, "model missing" end))
    registry:register(provider("safe", 1, "builtin2d",
      function() return true end))
    local lease = assert(Resolver.new(registry):acquire(250, "flight", {
      activeRenderer = "voxel", preferredRenderer = "auto",
    }))
    T:eq(lease.provider.id, "safe")
    T:eq(registry.failures.broken, 1)
  end)

  T:test("provider lease cleanup is idempotent", function()
    local finished = 0
    local registry = Registry.new()
    local p = provider("owned", 1, "builtin2d", function() return true end)
    p.finish = function() finished = finished + 1 end
    registry:register(p)
    local resolver = Resolver.new(registry)
    local lease = assert(resolver:acquire(59, "ground", {}))
    T:ok(resolver:release(lease, "test"))
    T:eq(resolver:release(lease, "again"), false)
    T:eq(finished, 1)
  end)

  T:test("an unavailable probe receipt is not selectable", function()
    local registry = Registry.new()
    local unavailable = provider("off", 1000, "voxel", function() return true end)
    unavailable.probe = function()
      return { available = false, kind = "voxel", renderer = "voxel" }
    end
    registry:register(unavailable)
    registry:register(provider("safe", 1, "builtin2d", function() return true end))
    local lease = assert(Resolver.new(registry):acquire(6, "flight", {
      activeRenderer = "voxel", preferredRenderer = "auto",
    }))
    T:eq(lease.provider.id, "safe")
  end)
end

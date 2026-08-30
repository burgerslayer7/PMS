return function(T, V)
  local Progression = V.require("game/ProgressionPolicy")
  local Persistence = V.require("game/Persistence")
  local Ground = V.require("movement/GroundController")
  local Surf = V.require("movement/SurfController")
  local Flight = V.require("movement/FlightController")
  local Collision = V.require("movement/CollisionResolver")

  T:test("progression policy enforces generation-specific Surf rules", function()
    local mon = { species = "LAPRAS", moves = { "SURF" } }
    local badge = false
    local adapter = {
      isSurfing = function() return false end,
      isOutside = function() return true end,
      partyMon = function() return mon end,
      knows = function(_, candidate, move)
        return candidate == mon and move == "SURF"
      end,
      generation = function() return 2 end,
      hasBadge = function(_, value)
        T:eq(value, "FOG")
        return badge
      end,
      fieldAction = function() return { id = "surf" } end,
    }
    local policy = Progression.new(adapter, {
      get = function(_, key) return key == "require_progression" end,
    })
    local mount = { species = "LAPRAS" }
    local ok, err = policy:canMount(mount, "surf", { mon = mon })
    T:eq(ok, nil)
    T:matches(err, "badge")
    badge = true
    T:ok(policy:canMount(mount, "surf", { mon = mon }))
  end)

  T:test("progression-disabled field action bypass is scoped", function()
    local mon = { species = "LAPRAS" }
    local temporary = 0
    local adapter = {
      generation = function() return 1 end,
      withTemporaryBadge = function(_, badge, fn)
        T:eq(badge, "SOULBADGE")
        temporary = temporary + 1
        local value = fn()
        temporary = temporary - 1
        return value
      end,
    }
    local policy = Progression.new(adapter, {
      get = function() return false end,
    })
    local seen = policy:withBypass(mon, "surf", function()
      local resolved = policy:fieldMoveEligibility(function() return nil end,
        "SURF", {})
      T:eq(resolved, mon)
      T:eq(temporary, 1)
      return "started"
    end)
    T:eq(seen, "started")
    T:eq(policy.bypassMon, nil)
    T:eq(policy:fieldMoveEligibility(function() return nil end, "SURF", {}),
      nil)
  end)

  T:test("mount persistence ignores inactive and malformed records", function()
    local values = {}
    local persistence = Persistence.new({ save = {
      set = function(_, key, record)
        T:eq(key, "mount_state_v2")
        values[key] = record
      end,
      get = function(_, key)
        return values[key]
      end,
    } })
    T:ok(persistence:write({ dex = 6, mode = "flight", altitude = 0.7,
      partySlot = 2 }, true, {
        ground = { dex = 59, partySlot = 1, partyFingerprint = "ground" },
        flight = { dex = 6, partySlot = 2, partyFingerprint = "flight" },
      }))
    local loaded = persistence:loadActive()
    T:eq(loaded.dex, 6)
    T:eq(loaded.mode, "flight")
    T:eq(loaded.altitude, 0.7)
    T:eq(loaded.partySlot, 2)
    local selections = persistence:loadSelections()
    T:eq(selections.ground.dex, 59)
    T:eq(selections.flight.partyFingerprint, "flight")
    T:ok(persistence:write({}, false, selections))
    T:eq(persistence:loadActive(), nil)
    T:eq(persistence:loadSelections().ground.dex, 59)
  end)

  T:test("mount persistence reads the legacy active session once", function()
    local persistence = Persistence.new({ save = {
      get = function(_, key)
        if key == "mount_session_v1" then
          return { active = true, dex = 131, mode = "surf", partySlot = 3 }
        end
      end,
    } })
    local loaded = persistence:loadActive()
    T:eq(loaded.dex, 131)
    T:eq(loaded.mode, "surf")
    T:eq(loaded.partySlot, 3)
  end)

  T:test("controllers preserve native collision while changing cadence", function()
    local adapter = {
      isSurfing = function() return false end,
      isOutside = function() return true end,
      currentTerrain = function() return "land" end,
      currentTileSymbol = function() return "." end,
      setFlightMarker = function() return true end,
    }
    local settings = { get = function(_, key)
      if key == "ground_speed" then return "fast" end
      if key == "flight_speed" then return "turbo" end
    end }
    local Catalog = V.require("core/MountCatalog")
    local catalog = Catalog.new(V.data("mounts"))
    local ground = Ground.new(adapter, settings, catalog)
    T:ok(ground:start())
    T:eq(ground:speed(16, nil, { dex = 59 }), 9)
    local flight = Flight.new(adapter, settings, nil, catalog)
    T:ok(flight:start())
    T:eq(flight:speed(16, nil, { dex = 6 }), 7)
    T:ok(flight:canLand())
  end)

  T:test("Surf controller delegates entry to the native field action", function()
    local surfing = false
    local adapter = {
      isSurfing = function() return surfing end,
      partyMon = function() return { species = "LAPRAS" } end,
      useFieldAction = function(_, id)
        T:eq(id, "surf")
        surfing = true
        return true
      end,
    }
    local progression = {
      withBypass = function(_, mon, mode, fn)
        T:eq(mon.species, "LAPRAS")
        T:eq(mode, "surf")
        return fn()
      end,
    }
    local Catalog = V.require("core/MountCatalog")
    local catalog = Catalog.new(V.data("mounts"))
    local controller = Surf.new(adapter, nil, progression, nil, catalog)
    T:ok(controller:start({}, { species = "LAPRAS" }, {}, {}))
    T:ok(controller:update({}, 1 / 60))
    T:eq(controller:speed(16, nil, { dex = 131 }), 13)
  end)

  T:test("flight airspace crosses terrain entities and guarded warps", function()
    local symbol = "."
    local suppressed
    local status = { mode = "flight", state = "FLIGHT", altitude = 0.85 }
    local adapter = {
      isPlayerMover = function(_, mover) return mover == "player" end,
      tileSymbolAt = function() return symbol end,
      suppressWarpAt = function(_, x, y) suppressed = { x = x, y = y } end,
    }
    local system = {
      snapshot = function() return status end,
      recordCollision = function() end,
    }
    local collision = Collision.new(adapter, system)
    local ctx = { mover = "player", reason = "tile", fromX = 1, fromY = 1,
      toX = 2, toY = 1 }
    T:eq(collision:resolve(false, ctx), true)
    ctx.reason = "entity"
    T:eq(collision:resolve(false, ctx), true)
    symbol = "+"
    ctx.reason = nil
    T:eq(collision:resolve(true, ctx), true)
    T:eq(suppressed.x, 2)
    T:eq(suppressed.y, 1)
    T:eq(ctx.reason, "pms_flight_airspace")
    symbol = "."
    status.state = "LANDING"
    ctx.reason = "tile"
    T:eq(collision:resolve(false, ctx), false)
    status.state = "FLIGHT"
    ctx.reason = "bounds"
    T:eq(collision:resolve(false, ctx), false)
  end)

  T:test("ground collision starts reverse ledge hop exactly once", function()
    local hops = 0
    local records = {}
    local adapter = {
      isPlayerMover = function(_, mover) return mover == "player" end,
      tryReverseLedge = function(_, direction)
        T:eq(direction, "up")
        hops = hops + 1
        return true
      end,
    }
    local system = {
      snapshot = function() return { mode = "ground", state = "GROUND" } end,
      recordCollision = function(_, value) records[#records + 1] = value end,
    }
    local collision = Collision.new(adapter, system)
    local ctx = { mover = "player", dir = "up", reason = "tile",
      fromX = 4, fromY = 4, toX = 4, toY = 3 }
    T:eq(collision:resolve(false, ctx), false)
    T:eq(hops, 1)
    T:eq(ctx.reason, "pms_ground_reverse_ledge")
    T:eq(records[#records].allowed, true)
  end)
end

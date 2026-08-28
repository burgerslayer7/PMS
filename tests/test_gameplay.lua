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
    local value
    local persistence = Persistence.new({ save = {
      set = function(_, key, record)
        T:eq(key, "mount_session_v1")
        value = record
      end,
      get = function(_, key)
        T:eq(key, "mount_session_v1")
        return value
      end,
    } })
    T:ok(persistence:write({ dex = 6, mode = "flight", altitude = 0.7,
      partySlot = 2 }, true))
    local loaded = persistence:loadActive()
    T:eq(loaded.dex, 6)
    T:eq(loaded.mode, "flight")
    T:eq(loaded.altitude, 0.7)
    T:eq(loaded.partySlot, 2)
    T:ok(persistence:write({}, false))
    T:eq(persistence:loadActive(), nil)
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
    local ground = Ground.new(adapter, settings)
    T:ok(ground:start())
    T:eq(ground:speed(16), 8)
    local flight = Flight.new(adapter, settings)
    T:ok(flight:start())
    T:eq(flight:speed(16), 5)
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
    local controller = Surf.new(adapter, nil, progression)
    T:ok(controller:start({}, { species = "LAPRAS" }, {}, {}))
    T:ok(controller:update({}, 1 / 60))
    T:eq(controller:speed(16), 12)
  end)

  T:test("flight collision crosses terrain but not entities or warps", function()
    local symbol = "."
    local status = { mode = "flight", state = "FLIGHT", altitude = 0.6 }
    local adapter = {
      isPlayerMover = function(_, mover) return mover == "player" end,
      tileSymbolAt = function() return symbol end,
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
    T:eq(collision:resolve(false, ctx), false)
    symbol = "+"
    ctx.reason = nil
    T:eq(collision:resolve(true, ctx), false)
    T:eq(ctx.reason, "pms_flight_warp")
    symbol = "."
    status.state = "LANDING"
    ctx.reason = "tile"
    T:eq(collision:resolve(false, ctx), false)
  end)
end

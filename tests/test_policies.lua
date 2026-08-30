return function(T, V)
  local Environment = V.require("game/EnvironmentPolicy")
  local Interaction = V.require("game/InteractionPolicy")
  local MapTransition = V.require("game/MapTransitionPolicy")

  T:test("environment policy classifies both generations without live leaks",
    function()
      local outside, def = true, { environment = "ROUTE" }
      local adapter = {
        isOutside = function() return outside end,
        mapDefinition = function() return def end,
      }
      local policy = Environment.new(adapter)
      T:eq(policy:classify(), "outdoor")
      T:ok(policy:canStart("flight"))
      outside, def = false, { environment = "CAVE" }
      T:eq(policy:classify(), "cave")
      local ok, err = policy:canStart("flight")
      T:eq(ok, nil)
      T:matches(err, "outdoors")
      def = { tileset = "REDS_HOUSE_1" }
      T:eq(policy:classify(), "indoor")
      T:ok(policy:canStart("ground"))
    end)

  T:test("interaction policy leaves airborne encounters to Wild Skies",
    function()
      local policy = Interaction.new()
      local flight = { mode = "flight", state = "FLIGHT" }
      T:eq(policy:allowsEncounter("ground", flight), false)
      T:ok(policy:allowsEncounter("wild_skies", flight))
      T:eq(policy:allowsGroundInteraction(flight), false)
      T:ok(policy:allowsCollisionBypass("tile", flight))
      T:eq(policy:allowsCollisionBypass("bounds", flight), false)
      T:ok(policy:allowsEncounter("ground", {
        mode = "ground", state = "GROUND",
      }))
    end)

  T:test("map transition policy preserves seams but rejects checkpoints",
    function()
      local allowed = true
      local policy = MapTransition.new({ canContinue = function(_, mode)
        T:eq(mode, "flight")
        return allowed, allowed and nil or "indoor"
      end })
      T:eq(policy:classify("map.exited", { kind = "connection" }),
        "connection")
      T:eq(policy:classify("map.reloaded", {}), "reload")
      T:ok(policy:preservesMount("map.entered"))
      T:eq(policy:preservesMount("checkpoint.restored"), false)
      T:ok(policy:canResume("flight"))
      allowed = false
      local ok, err = policy:canResume("flight")
      T:eq(ok, false)
      T:eq(err, "indoor")
    end)
end

return function(T, V)
  local Catalog = V.require("core/MountCatalog")
  local catalog = Catalog.new(V.data("mounts"))

  T:test("catalog contains the complete reference set", function()
    T:eq(catalog:count(), 40)
    T:eq(#catalog:forMode("ground"), 17)
    T:eq(#catalog:forMode("surf"), 9)
    T:eq(#catalog:forMode("flight"), 16)
  end)

  T:test("reference validation mounts resolve by dex and species", function()
    T:eq(catalog:get(59).species, "ARCANINE")
    T:eq(catalog:get(59).heightM, 1.9)
    T:eq(catalog:get("lapras").dex, 131)
    T:ok(catalog:supports(6, "flight"))
    T:ok(catalog:supports(250, "flight"))
    T:eq(catalog:supports(59, "surf"), false)
  end)

  T:test("amphibious and dual-mode mounts are data driven", function()
    local suicune = catalog:get(245)
    T:ok(suicune.modes.ground)
    T:ok(suicune.modes.surf)
    T:ok(suicune.traits.amphibious)
    local lugia = catalog:get(249)
    T:ok(lugia.modes.surf)
    T:ok(lugia.modes.flight)
  end)

  T:test("every mount mode has a unique explicit speed from 0.8 to 2.0", function()
    local rawByDex = {}
    for _, row in ipairs(V.data("mounts").mounts) do rawByDex[row.dex] = row end
    for _, mode in ipairs({ "ground", "surf", "flight" }) do
      local seen = {}
      for _, mount in ipairs(catalog:forMode(mode)) do
        local movement = mount.movement[mode]
        local raw = rawByDex[mount.dex]
        T:ok(raw.movement and raw.movement[mode]
          and type(raw.movement[mode].speed) == "number",
          mount.species .. " must explicitly define " .. mode .. " speed")
        T:ok(type(movement.speed) == "number"
          and movement.speed >= 0.8 and movement.speed <= 2.0)
        T:eq(seen[movement.speed], nil,
          mode .. " speed must be unique for " .. mount.species)
        seen[movement.speed] = mount.species
        T:ok(type(movement.acceleration) == "number")
        T:ok(type(movement.turnRate) == "number")
      end
    end
  end)

  T:test("every normalized movement profile has bounded dynamics", function()
    local catalog = Catalog.new(V.data("mounts"))
    for _, mount in ipairs(catalog.ordered) do
      for mode, profile in pairs(mount.movement) do
        T:ok(profile.acceleration >= 0.05 and profile.acceleration <= 0.5,
          mount.species .. " " .. mode .. " acceleration")
        T:ok(profile.braking >= 0.05 and profile.braking <= 0.8,
          mount.species .. " " .. mode .. " braking")
        T:ok(profile.launch >= 0.4 and profile.launch <= 1,
          mount.species .. " " .. mode .. " launch")
        T:ok(profile.turnRate >= 0.5 and profile.turnRate <= 1,
          mount.species .. " " .. mode .. " turn rate")
        T:eq(profile.boost, 2)
        if mode == "flight" then
          T:ok(profile.verticalSpeed >= 0.2 and profile.verticalSpeed <= 1.2)
        end
      end
    end
  end)

  T:test("catalog refuses malformed duplicate data", function()
    local ok, err = pcall(Catalog.new, {
      mounts = {
        { dex = 6, species = "CHARIZARD", heightM = 1.7,
          modes = { "flight" }, movement = { flight = { speed = 1.2 } } },
        { dex = 6, species = "OTHER", heightM = 1.8,
          modes = { "ground" }, movement = { ground = { speed = 1.1 } } },
      },
    })
    T:eq(ok, false)
    T:matches(err, "duplicate mount dex")
  end)
end

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

  T:test("catalog refuses malformed duplicate data", function()
    local ok, err = pcall(Catalog.new, {
      mounts = {
        { dex = 6, species = "CHARIZARD", modes = { "flight" } },
        { dex = 6, species = "OTHER", modes = { "ground" } },
      },
    })
    T:eq(ok, false)
    T:matches(err, "duplicate mount dex")
  end)
end

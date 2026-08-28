-- Run from a Gen1Recomp++ checkout after mounting this repository at
-- mods/pokemon_mount_system (tools/test_engine.sh does that automatically).

local T = require("tests.modkit")

local function statusOf(run, id)
  for _, entry in ipairs(run.loader:status().available) do
    if entry.id == id then return entry end
  end
  return nil
end

local generation = tonumber(arg[1]) or 1
local run = T.sdk.loadMod("mods/pokemon_mount_system", {
  data = T.fixtures.load(),
  generation = generation,
})
local status = statusOf(run, "pokemon_mount_system")
T.check(status ~= nil, "PMS status exists on Gen " .. generation)
T.eq(status and status.state, "loaded",
  "PMS entry loads on Gen " .. generation)
T.eq(#run.errors, 0, "PMS has no loader errors on Gen " .. generation)
run.release()

T.finish("pokemon mount system engine load gen " .. generation)

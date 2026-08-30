-- Optional pair smoke test. Run through tools/test_potato.sh with a checked
-- out PotatoVoxel tree; neither repository is copied into the other.

local T = require("tests.modkit")

local function statusOf(run, id)
  for _, entry in ipairs(run.loader:status().available) do
    if entry.id == id then return entry end
  end
  return nil
end

local generation = tonumber(arg[1]) or 1
local run = T.sdk.loadMods({
  "mods/potato_voxel",
  "mods/pokemon_mount_system",
}, {
  data = T.fixtures.load(),
  generation = generation,
})

for _, id in ipairs({ "potato_voxel", "pokemon_mount_system" }) do
  local status = statusOf(run, id)
  T.check(status ~= nil, id .. " status exists on Gen " .. generation)
  T.eq(status and status.state, "loaded",
    id .. " loads on Gen " .. generation)
end
local unexpected = {}
for _, err in ipairs(run.errors) do
  local message = tostring(err and (err.error or err.message or err) or "")
  -- PotatoVoxel currently registers one Gen1 transition declaration before
  -- its Gen2 bridge takes over. The official modkit records the documented
  -- no-target warning as an error entry even though Potato remains loaded.
  if not (generation == 2
      and message:find("transitions registry has no Gen 2 target", 1, true)) then
    unexpected[#unexpected + 1] = message
  end
end
if #unexpected > 0 then
  for index, message in ipairs(unexpected) do
    io.stderr:write(string.format("pair loader error %d: %s\n", index, message))
  end
end
T.eq(#unexpected, 0,
  "PotatoVoxel and PMS have no unexpected loader errors on Gen " .. generation)
run.release()

T.finish("PotatoVoxel + PMS engine load gen " .. generation)

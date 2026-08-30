local root = arg[1] or "."
root = string.gsub(root, "/+$", "")

local Harness = assert(loadfile(root .. "/tests/harness.lua"))()
local T = Harness.new()

local V = { modules = {}, dataFiles = {} }

function V.require(name)
  if V.modules[name] ~= nil then return V.modules[name] end
  local chunk, err = loadfile(root .. "/src/" .. name .. ".lua")
  if not chunk then error(err, 0) end
  local value = chunk(V)
  if value == nil then error("module returned nil: " .. name, 0) end
  V.modules[name] = value
  return value
end

function V.data(name)
  if V.dataFiles[name] ~= nil then return V.dataFiles[name] end
  local chunk, err = loadfile(root .. "/config/" .. name .. ".lua")
  if not chunk then error(err, 0) end
  local value = chunk(V)
  V.dataFiles[name] = value
  return value
end

local suites = {
  "test_state",
  "test_catalog",
  "test_providers",
  "test_builtin_provider",
  "test_identity",
  "test_policies",
  "test_mount_system",
  "test_gameplay",
  "test_controls",
  "test_ui",
  "test_integrations",
}

for _, name in ipairs(suites) do
  local suite = assert(loadfile(root .. "/tests/" .. name .. ".lua"))()
  suite(T, V)
end

local ok = T:run()
if not ok then os.exit(1) end

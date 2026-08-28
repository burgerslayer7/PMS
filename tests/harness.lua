local Harness = {}
Harness.__index = Harness

local function render(value)
  if type(value) == "string" then return string.format("%q", value) end
  return tostring(value)
end

function Harness.new()
  return setmetatable({ cases = {}, assertions = 0 }, Harness)
end

function Harness:test(name, fn)
  self.cases[#self.cases + 1] = { name = name, fn = fn }
end

function Harness:ok(value, message)
  self.assertions = self.assertions + 1
  if not value then error(message or "expected truthy value", 2) end
  return value
end

function Harness:eq(actual, expected, message)
  self.assertions = self.assertions + 1
  if actual ~= expected then
    error((message and (message .. ": ") or "") .. "expected "
      .. render(expected) .. ", got " .. render(actual), 2)
  end
  return actual
end

function Harness:matches(value, pattern, message)
  self.assertions = self.assertions + 1
  if type(value) ~= "string" or not string.find(value, pattern) then
    error((message and (message .. ": ") or "") .. "expected "
      .. render(value) .. " to match " .. render(pattern), 2)
  end
  return value
end

function Harness:run()
  local passed = 0
  for _, case in ipairs(self.cases) do
    local ok, err = xpcall(case.fn, debug.traceback)
    if not ok then
      io.stderr:write("not ok - ", case.name, "\n", tostring(err), "\n")
      return nil, case.name
    end
    passed = passed + 1
    io.stdout:write("ok - ", case.name, "\n")
  end
  io.stdout:write(string.format("%d tests, %d assertions\n", passed,
    self.assertions))
  return true
end

return Harness

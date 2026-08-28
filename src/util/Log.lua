local Log = {}
Log.__index = Log

local function formatMessage(fmt, ...)
  if select("#", ...) == 0 then return tostring(fmt) end
  local ok, message = pcall(string.format, tostring(fmt), ...)
  return ok and message or tostring(fmt)
end

function Log.new(mod)
  return setmetatable({ mod = mod, onceKeys = {} }, Log)
end

function Log:_write(level, subsystem, fmt, ...)
  local logger = self.mod and self.mod.log
  local writer = logger and logger[level]
  if type(writer) ~= "function" then return false end
  local message = formatMessage(fmt, ...)
  local ok = pcall(writer, logger, "[PMS][%s] %s", subsystem, message)
  return ok
end

function Log:info(subsystem, fmt, ...)
  return self:_write("info", subsystem, fmt, ...)
end

function Log:warn(subsystem, fmt, ...)
  return self:_write("warn", subsystem, fmt, ...)
end

function Log:error(subsystem, fmt, ...)
  return self:_write("error", subsystem, fmt, ...)
end

function Log:once(key, level, subsystem, fmt, ...)
  if self.onceKeys[key] then return false end
  self.onceKeys[key] = true
  return self:_write(level, subsystem, fmt, ...)
end

return Log

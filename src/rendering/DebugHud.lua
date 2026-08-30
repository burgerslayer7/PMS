local DebugHud = {}
DebugHud.__index = DebugHud

function DebugHud.new(settings, system, adapter)
  return setmetatable({
    settings = settings,
    system = system,
    adapter = adapter,
  }, DebugHud)
end

local function collisionText(value)
  if type(value) ~= "table" then return "-" end
  return string.format("%s %s -> %s,%s",
    value.allowed and "ALLOW" or "BLOCK",
    tostring(value.reason or "?"),
    tostring(value.toX or "?"), tostring(value.toY or "?"))
end

function DebugHud:draw(game, viewport)
  if not (self.settings and self.settings:get("debug_mode")) then return end
  if not (love and love.graphics and love.graphics.print) then return end
  local status = self.system:snapshot()
  local position = self.adapter:position() or {}
  local lines = {
    string.format("PMS  %s", tostring(status.state)),
    string.format("Mount %s  mode=%s", tostring(status.species or "-"),
      tostring(status.mode or "-")),
    string.format("Provider %s  renderer=%s", tostring(status.provider or "-"),
      tostring(status.renderer or "-")),
    string.format("Presentation %s", status.presentationPending
      and ("RETRY " .. tostring(status.presentationAttempts or 0)) or "READY"),
    string.format("Altitude %.2f  Gen %d", tonumber(status.altitude) or 0,
      self.adapter:generation()),
    string.format("Map %s  tile=%s,%s (%s)", tostring(position.mapId or "-"),
      tostring(position.x or "-"), tostring(position.y or "-"),
      tostring(self.adapter:currentTerrain() or "?")),
    "Collision " .. collisionText(status.lastCollision),
  }
  local text = table.concat(lines, "\n")
  local x = (viewport and viewport.gameX or 0) + 5
  local y = (viewport and viewport.gameY or 0) + 5
  love.graphics.push("all")
  local font = love.graphics.getFont()
  local width = 0
  for _, line in ipairs(lines) do width = math.max(width, font:getWidth(line)) end
  local height = font:getHeight() * #lines + 8
  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", x - 3, y - 3, width + 8, height)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(text, x, y)
  love.graphics.pop()
end

return DebugHud

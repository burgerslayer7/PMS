-- Raw host controls that do not fit in the eight-button Game Boy abstraction.
-- Every wrapper is instance-local, chains the previous handler and is restored
-- on cleanup. Gameplay remains in MountSystem/controllers; this bridge only
-- converts H/G/J, X/Y and altitude keys/triggers into intents.

local InputBridge = {}
InputBridge.__index = InputBridge

local FLIGHT_TRIGGERS = {
  righttrigger = 1, triggerright = 1, r2 = 1,
  lefttrigger = -1, triggerleft = -1, l2 = -1,
}

function InputBridge.new(mod, adapter, log, settings)
  return setmetatable({
    mod = mod,
    adapter = adapter,
    log = log,
    settings = settings,
    system = nil,
    game = nil,
    wrappers = {},
    held = { altitudeUp = false, altitudeDown = false },
    pending = nil,
  }, InputBridge)
end

function InputBridge:bindSystem(system)
  self.system = system
  return self
end

function InputBridge:_isFlying()
  local status = self.system and self.system:snapshot() or {}
  return status.mode == "flight" and status.state ~= "UNMOUNTED"
    and status.state ~= "BATTLE_SUSPENDED"
    and status.state ~= "TRANSITION"
end

function InputBridge:_groundKey()
  local status = self.system and self.system:snapshot() or {}
  return status.rendererHost == "DRAMALESS_SHAPE" and "j" or "g"
end

function InputBridge:_queue(mode, game)
  if self.settings and self.settings:get("shortcuts_enabled") == false then
    return false
  end
  if not (self.adapter and self.adapter:isFreeRoam()) then return false end
  self.pending = { mode = mode, game = game or self.game }
  return true
end

function InputBridge:_keyPressed(game, key)
  key = string.lower(tostring(key or ""))
  if key == "h" then return self:_queue("flight", game) end
  if key == self:_groundKey() then return self:_queue("ground", game) end
  if self:_isFlying() and (key == "pageup" or key == "pagedown") then
    self.held[key == "pageup" and "altitudeUp" or "altitudeDown"] = true
    return true
  end
  return false
end

function InputBridge:_keyReleased(_, key)
  key = string.lower(tostring(key or ""))
  if key == "pageup" then self.held.altitudeUp = false return true end
  if key == "pagedown" then self.held.altitudeDown = false return true end
  return false
end

function InputBridge:_padPressed(game, _, button)
  button = string.lower(tostring(button or ""))
  if button == "x" then return self:_queue("flight", game) end
  if button == "y" then return self:_queue("ground", game) end
  local axis = FLIGHT_TRIGGERS[button]
  if axis and self:_isFlying() then
    self.held[axis > 0 and "altitudeUp" or "altitudeDown"] = true
    return true
  end
  return false
end

function InputBridge:_padReleased(_, _, button)
  local axis = FLIGHT_TRIGGERS[string.lower(tostring(button or ""))]
  if not axis then return false end
  self.held[axis > 0 and "altitudeUp" or "altitudeDown"] = false
  return self:_isFlying()
end

function InputBridge:_padAxis(_, _, axis, value)
  axis = string.lower(tostring(axis or ""))
  local direction = FLIGHT_TRIGGERS[axis]
  if not direction or not self:_isFlying() then return false end
  self.held[direction > 0 and "altitudeUp" or "altitudeDown"] =
    (tonumber(value) or 0) > 0.35
  return true
end

function InputBridge:_install(name, handler)
  local game = self.game
  local original = game and game[name]
  if type(original) ~= "function" then return false end
  local own = rawget(game, name)
  local wrapper
  wrapper = function(owner, ...)
    if handler(self, owner, ...) then return end
    return original(owner, ...)
  end
  rawset(game, name, wrapper)
  self.wrappers[#self.wrappers + 1] = {
    name = name, original = original, own = own, wrapper = wrapper,
  }
  return true
end

function InputBridge:attach(game)
  if type(game) ~= "table" then return nil, "live game unavailable" end
  if self.game == game and #self.wrappers > 0 then return true end
  self:detach()
  self.game = game
  self:_install("keypressed", InputBridge._keyPressed)
  self:_install("keyreleased", InputBridge._keyReleased)
  self:_install("gamepadpressed", InputBridge._padPressed)
  self:_install("gamepadreleased", InputBridge._padReleased)
  self:_install("gamepadaxis", InputBridge._padAxis)
  if self.log then
    self.log:info("Input", "mount shortcuts attached")
  end
  return true
end

function InputBridge:_message(game, value)
  local ui = self.mod and self.mod.ui
  local stack = game and game.stack
  if ui and ui.TextBox and stack and type(stack.push) == "function" then
    stack:push(ui.TextBox.new(game, tostring(value or "Mount action failed.")))
  elseif self.log then
    self.log:warn("Input", "%s", tostring(value))
  end
end

function InputBridge:update(game)
  local pending = self.pending
  if not pending then return false end
  self.pending = nil
  if not (self.system and self.adapter and self.adapter:isFreeRoam()) then
    return false
  end
  local ok, err = self.system:toggleMode(pending.mode)
  if not ok then self:_message(pending.game or game or self.game, err) end
  return ok == true
end

function InputBridge:altitudeAxis()
  if not self:_isFlying()
      or not (self.adapter and self.adapter:isFreeRoam()) then return 0 end
  if self.held.altitudeUp == self.held.altitudeDown then return 0 end
  return self.held.altitudeUp and 1 or -1
end

function InputBridge:detach()
  local game = self.game
  for index = #self.wrappers, 1, -1 do
    local entry = self.wrappers[index]
    if game and rawget(game, entry.name) == entry.wrapper then
      rawset(game, entry.name, entry.own)
    end
  end
  self.wrappers = {}
  self.game = nil
  self.pending = nil
  self.held.altitudeUp, self.held.altitudeDown = false, false
  return true
end

return InputBridge

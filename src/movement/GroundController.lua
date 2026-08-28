local GroundController = {}
GroundController.__index = GroundController

function GroundController.new(adapter, settings)
  return setmetatable({ adapter = adapter, settings = settings }, GroundController)
end

function GroundController:start()
  if self.adapter:isSurfing() then
    return nil, "Leave the water before starting a ground ride."
  end
  return true
end

function GroundController:speed(frames)
  local choice = self.settings and self.settings:get("ground_speed") or "normal"
  local factor = choice == "fast" and 0.50 or 0.68
  return math.max(1, math.floor((tonumber(frames) or 16) * factor + 0.5))
end

function GroundController:update() return true end
function GroundController:stop() return true end
function GroundController:suspend() return true end
function GroundController:resume() return true end
function GroundController:mapExit() return true end
function GroundController:mapEnter() return true end

return GroundController

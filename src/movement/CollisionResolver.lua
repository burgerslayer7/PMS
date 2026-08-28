local CollisionResolver = {}
CollisionResolver.__index = CollisionResolver

function CollisionResolver.new(adapter, system)
  return setmetatable({ adapter = adapter, system = system }, CollisionResolver)
end

function CollisionResolver:resolve(allowed, ctx)
  if type(ctx) ~= "table" or not self.adapter:isPlayerMover(ctx.mover) then
    return allowed
  end
  local status = self.system:snapshot()
  self.system:recordCollision({
    allowed = allowed == true,
    reason = ctx.reason,
    fromX = ctx.fromX,
    fromY = ctx.fromY,
    toX = ctx.toX,
    toY = ctx.toY,
  })
  if status.mode == "flight" and status.altitude > 0.05
      and allowed == true and ctx.toX ~= nil and ctx.toY ~= nil
      and self.adapter:tileSymbolAt(ctx.toX, ctx.toY) == "+" then
    ctx.reason = "pms_flight_warp"
    self.system:recordCollision({
      allowed = false,
      reason = ctx.reason,
      fromX = ctx.fromX,
      fromY = ctx.fromY,
      toX = ctx.toX,
      toY = ctx.toY,
    })
    return false
  end
  if allowed then return true end
  if status.mode == "flight"
      and (status.state == "TAKEOFF" or status.state == "FLIGHT")
      and status.altitude >= 0.34 and ctx.reason == "tile" then
    ctx.reason = "pms_flight_terrain"
    self.system:recordCollision({
      allowed = true,
      reason = ctx.reason,
      fromX = ctx.fromX,
      fromY = ctx.fromY,
      toX = ctx.toX,
      toY = ctx.toY,
    })
    return true
  end
  return false
end

return CollisionResolver

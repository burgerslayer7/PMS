local CollisionResolver = {}
CollisionResolver.__index = CollisionResolver

function CollisionResolver.new(adapter, system, interaction, settings)
  return setmetatable({ adapter = adapter, system = system,
    interaction = interaction, settings = settings }, CollisionResolver)
end

function CollisionResolver:resolve(allowed, ctx)
  if type(ctx) ~= "table" or not self.adapter:isPlayerMover(ctx.mover) then
    return allowed
  end
  local status = self.system:snapshot()
  self.system:recordCollision({
    allowed = allowed == true,
    final = false,
    reason = ctx.reason,
    fromX = ctx.fromX,
    fromY = ctx.fromY,
    toX = ctx.toX,
    toY = ctx.toY,
  })
  local reverseLedges = not self.settings
    or self.settings:get("reverse_ledges") ~= false
  if reverseLedges and status.mode == "ground" and allowed ~= true
      and ctx.reason == "tile"
      and ctx.dir and self.adapter:tryReverseLedge(ctx.dir) then
    ctx.reason = "pms_ground_reverse_ledge"
    self.system:recordCollision({
      allowed = true,
      final = true,
      reason = ctx.reason,
      fromX = ctx.fromX,
      fromY = ctx.fromY,
      toX = ctx.toX,
      toY = ctx.toY,
    })
    -- The adapter already started the native two-cell hop. Returning true
    -- here would also start the refused one-cell step on top of it.
    return false
  end
  local airborne = self.interaction
    and self.interaction:isAirborne(status)
    or (status.mode == "flight"
      and (status.state == "TAKEOFF" or status.state == "FLIGHT"))
  if airborne and ctx.toX ~= nil and ctx.toY ~= nil
      and self.adapter:tileSymbolAt(ctx.toX, ctx.toY) == "+"
      and type(self.adapter.suppressWarpAt) == "function" then
    self.adapter:suppressWarpAt(ctx.toX, ctx.toY)
  end
  -- The logical player remains on the tile grid for cameras and map seams,
  -- but stable airspace ignores every ground tile and entity verdict. Bounds
  -- remain native so connected-map transitions still own world navigation.
  local bypass = self.interaction
    and self.interaction:allowsCollisionBypass(ctx.reason, status)
    or (airborne and (ctx.reason == "tile" or ctx.reason == "entity"))
  if airborne and (allowed == true or bypass) then
    ctx.reason = "pms_flight_airspace"
    self.system:recordCollision({
      allowed = true,
      final = true,
      reason = ctx.reason,
      fromX = ctx.fromX,
      fromY = ctx.fromY,
      toX = ctx.toX,
      toY = ctx.toY,
    })
    return true
  end
  self.system:recordCollision({
    allowed = allowed == true,
    final = true,
    reason = ctx.reason,
    fromX = ctx.fromX,
    fromY = ctx.fromY,
    toX = ctx.toX,
    toY = ctx.toY,
  })
  if allowed then return true end
  return false
end

return CollisionResolver

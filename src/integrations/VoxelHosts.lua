-- Aggregates independent voxel host contracts behind the small interface
-- already consumed by PMS providers. Standard Voxel Companion hosts keep
-- their frame observer; PotatoVoxel uses its separate engine-level adapter.

local VoxelHosts = {}
VoxelHosts.__index = VoxelHosts

function VoxelHosts.new(companion, potato)
  return setmetatable({ companion = companion, potato = potato }, VoxelHosts)
end

function VoxelHosts:discover()
  if self.companion then self.companion:discover() end
  if self.potato then self.potato:discover() end
  return true
end

function VoxelHosts:advance(system)
  if self.companion then self.companion:advance() end
  if self.potato then self.potato:advance(system) end
end

function VoxelHosts:activeHost()
  local standard = self.companion and self.companion:activeHost()
  if standard then return standard end
  return self.potato and self.potato:activeHost() or nil
end

function VoxelHosts:movementOrientation()
  return self.companion and self.companion:movementOrientation() or nil
end

function VoxelHosts:status()
  local active = self:activeHost()
  return {
    active = active and active.id or nil,
    companion = self.companion and self.companion:status() or nil,
    potato = self.potato and self.potato:status() or nil,
  }
end

function VoxelHosts:cleanup()
  if self.companion then self.companion:cleanup() end
  if self.potato then self.potato:cleanup() end
  return true
end

return VoxelHosts

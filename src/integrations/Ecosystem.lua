local Ecosystem = {}
Ecosystem.__index = Ecosystem

function Ecosystem.new(voxel, stadium, crystal251, log)
  return setmetatable({
    voxel = voxel,
    stadium = stadium,
    crystal251 = crystal251,
    log = log,
    lastRenderer = nil,
    lastHost = nil,
  }, Ecosystem)
end

function Ecosystem:discover()
  if self.voxel then self.voxel:discover() end
  if self.stadium then self.stadium:discover() end
  if self.crystal251 then self.crystal251:discover() end
  return true
end

function Ecosystem:update(system)
  if self.voxel then self.voxel:advance(system) end
  local status = system and system:snapshot() or {}
  local generation = status.generation
  if not generation and system and system.runtime then
    generation = system.runtime.generation
  end

  local renderer, host, cameraMode = "native2d", nil, nil
  local stadiumActive, stadiumHandle = self.stadium
    and self.stadium:world3DState(generation or 1)
  local voxelHost = self.voxel and self.voxel:activeHost()
  if stadiumActive then
    renderer = "voxel"
    host = stadiumHandle and stadiumHandle.id or nil
  elseif voxelHost then
    renderer = "voxel"
    host = voxelHost.id
    cameraMode = voxelHost.cameraMode
  end
  if renderer ~= self.lastRenderer or host ~= self.lastHost then
    self.lastRenderer, self.lastHost = renderer, host
    if system then
      system:setRenderEnvironment(renderer, {
        host = host,
        cameraMode = cameraMode,
      })
    end
  end
  return renderer, host
end

function Ecosystem:status()
  return {
    renderer = self.lastRenderer or "native2d",
    host = self.lastHost,
    voxel = self.voxel and self.voxel:status() or nil,
    stadium = self.stadium and self.stadium:status() or nil,
    crystal251 = self.crystal251 and self.crystal251:status() or nil,
  }
end

function Ecosystem:cleanup()
  if self.voxel then self.voxel:cleanup() end
  if self.crystal251 then self.crystal251:cleanup() end
  self.lastRenderer, self.lastHost = nil, nil
  return true
end

return Ecosystem

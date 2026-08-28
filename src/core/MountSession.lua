local MountSession = {}
MountSession.__index = MountSession

function MountSession.new(initialState)
  return setmetatable({
    state = initialState or "UNMOUNTED",
    revision = 0,
    mapRevision = 0,
    dex = nil,
    species = nil,
    partySlot = nil,
    partyFingerprint = nil,
    mode = nil,
    altitude = 0,
    lastStable = nil,
    resume = nil,
    controller = nil,
    renderLease = nil,
    riderLease = nil,
    ownershipLease = nil,
    providerId = nil,
    rendererId = nil,
    lastCollision = nil,
  }, MountSession)
end

function MountSession:clearMount()
  self.dex = nil
  self.species = nil
  self.partySlot = nil
  self.partyFingerprint = nil
  self.mode = nil
  self.altitude = 0
  self.lastStable = nil
  self.resume = nil
  self.controller = nil
  self.renderLease = nil
  self.riderLease = nil
  self.ownershipLease = nil
  self.providerId = nil
  self.rendererId = nil
  self.lastCollision = nil
end

function MountSession:snapshot()
  return {
    state = self.state,
    revision = self.revision,
    mapRevision = self.mapRevision,
    dex = self.dex,
    species = self.species,
    mode = self.mode,
    altitude = self.altitude,
    provider = self.providerId,
    renderer = self.rendererId,
    lastCollision = self.lastCollision,
    partySlot = self.partySlot,
  }
end

return MountSession

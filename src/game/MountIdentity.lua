local MountIdentity = {}
MountIdentity.__index = MountIdentity

function MountIdentity.new(adapter)
  return setmetatable({ adapter = adapter }, MountIdentity)
end

function MountIdentity:capture(mon, slot)
  if type(mon) ~= "table" then return nil end
  return {
    species = mon.species,
    partySlot = tonumber(slot) or self.adapter:partySlot(mon),
    partyFingerprint = self.adapter:fingerprint(mon),
  }
end

function MountIdentity:resolve(identity)
  if type(identity) ~= "table" or not identity.species then
    return nil, "The mounted Pokemon identity is incomplete."
  end
  local mon = self.adapter:partyMon(identity.partySlot, identity.species,
    identity.partyFingerprint)
  if not mon then
    return nil, "The mounted Pokemon is no longer in the party."
  end
  if mon.isEgg or mon.egg then
    return nil, "An Egg cannot remain mounted."
  end
  if type(mon.hp) == "number" and mon.hp <= 0 then
    return nil, "The mounted Pokemon fainted."
  end
  local slot = self.adapter:partySlot(mon)
  return mon, slot, self.adapter:fingerprint(mon)
end

return MountIdentity

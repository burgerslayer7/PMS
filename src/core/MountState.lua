local MountState = {}

MountState.UNMOUNTED = "UNMOUNTED"
MountState.MOUNTING = "MOUNTING"
MountState.GROUND = "GROUND"
MountState.SURF = "SURF"
MountState.TAKEOFF = "TAKEOFF"
MountState.FLIGHT = "FLIGHT"
MountState.LANDING = "LANDING"
MountState.DISMOUNTING = "DISMOUNTING"
MountState.BATTLE_SUSPENDED = "BATTLE_SUSPENDED"
MountState.TRANSITION = "TRANSITION"

local stable = {
  GROUND = true,
  SURF = true,
  FLIGHT = true,
}

local allowed = {
  UNMOUNTED = { MOUNTING = true },
  MOUNTING = {
    GROUND = true, SURF = true, TAKEOFF = true, UNMOUNTED = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  GROUND = {
    SURF = true, TAKEOFF = true, DISMOUNTING = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  SURF = {
    GROUND = true, TAKEOFF = true, DISMOUNTING = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  TAKEOFF = {
    FLIGHT = true, LANDING = true, DISMOUNTING = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  FLIGHT = {
    LANDING = true, DISMOUNTING = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  LANDING = {
    GROUND = true, SURF = true, DISMOUNTING = true, UNMOUNTED = true,
    BATTLE_SUSPENDED = true, TRANSITION = true,
  },
  DISMOUNTING = { UNMOUNTED = true },
  BATTLE_SUSPENDED = {
    GROUND = true, SURF = true, FLIGHT = true,
    TRANSITION = true, UNMOUNTED = true,
  },
  TRANSITION = {
    GROUND = true, SURF = true, FLIGHT = true,
    BATTLE_SUSPENDED = true, UNMOUNTED = true,
  },
}

function MountState.isKnown(value)
  return type(value) == "string" and allowed[value] ~= nil
end

function MountState.isStable(value)
  return stable[value] == true
end

function MountState.canTransition(from, to)
  return allowed[from] ~= nil and allowed[from][to] == true
end

function MountState.validate(from, to)
  if not MountState.isKnown(from) then
    return nil, "unknown source state: " .. tostring(from)
  end
  if not MountState.isKnown(to) then
    return nil, "unknown destination state: " .. tostring(to)
  end
  if not MountState.canTransition(from, to) then
    return nil, ("illegal mount transition %s -> %s"):format(from, to)
  end
  return true
end

function MountState.targetForMode(mode)
  if mode == "ground" then return MountState.GROUND end
  if mode == "surf" then return MountState.SURF end
  if mode == "flight" then return MountState.TAKEOFF end
  return nil
end

function MountState.modeFor(value)
  if value == MountState.GROUND then return "ground" end
  if value == MountState.SURF then return "surf" end
  if value == MountState.FLIGHT or value == MountState.TAKEOFF
      or value == MountState.LANDING then return "flight" end
  return nil
end

return MountState

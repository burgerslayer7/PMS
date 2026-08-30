local V = ...
local MountSession = V.require("core/MountSession")

local MountSystem = {}
MountSystem.__index = MountSystem

local PRESENTATION_RETRY_ATTEMPTS = 8
local PRESENTATION_RETRY_DELAY = 0.15
local BATTLE_RESUME_TIMEOUT = 8
local MOUNT_MODES = { "ground", "surf", "flight" }

local function call(object, name, ...)
  if type(object) ~= "table" or type(object[name]) ~= "function" then
    return true
  end
  local ok, first, second = pcall(object[name], object, ...)
  if not ok then return nil, first end
  return first, second
end

local function copyOptions(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function isLandModeTransfer(source, target)
  return (source == "ground" and target == "flight")
    or (source == "flight" and target == "ground")
end

local function visibleRenderLease(lease)
  return lease ~= nil
    and not (lease.resolved and lease.resolved.visible == false)
end

function MountSystem.new(deps)
  assert(type(deps) == "table", "MountSystem dependencies required")
  assert(deps.state and deps.catalog and deps.resolver,
    "MountSystem missing core dependency")
  return setmetatable({
    State = deps.state,
    catalog = deps.catalog,
    resolver = deps.resolver,
    settings = deps.settings,
    log = deps.log,
    session = MountSession.new(deps.state.UNMOUNTED),
    enabled = false,
    runtime = nil,
    controllers = deps.controllers or {},
    progression = deps.progression,
    adapter = deps.adapter,
    identity = deps.identity,
    environment = deps.environment,
    transitionPolicy = deps.transitionPolicy,
    persistence = deps.persistence,
    rider = deps.rider,
    ownership = deps.ownership,
    discover = deps.discover,
    pendingRestore = nil,
    lastSelections = {},
    presentationRecovery = nil,
    pendingBattleResume = nil,
  }, MountSystem)
end

function MountSystem:_clearPresentationRecovery()
  self.presentationRecovery = nil
end

function MountSystem:_schedulePresentationRecovery(reason, controllerPending,
    payload)
  local recovery = self.presentationRecovery
  if not recovery then
    recovery = {
      attempts = PRESENTATION_RETRY_ATTEMPTS,
      delay = PRESENTATION_RETRY_DELAY,
      renderPending = false,
      controllerPending = false,
    }
    self.presentationRecovery = recovery
  end
  recovery.reason = reason or recovery.reason or "presentation-unavailable"
  recovery.renderPending = recovery.renderPending
    or not visibleRenderLease(self.session.renderLease)
  recovery.controllerPending = recovery.controllerPending
    or controllerPending == true
  recovery.payload = payload or recovery.payload
  return true
end

function MountSystem:_finishPresentationRecovery()
  local recovery = self.presentationRecovery
  if not recovery or recovery.renderPending or recovery.controllerPending then
    return false
  end
  self.presentationRecovery = nil
  if self.log then
    self.log:info("Lifecycle", "mount presentation recovered")
  end
  return true
end

function MountSystem:_rememberSelection(mode, mount, opts)
  self.lastSelections[mode] = {
    dex = mount.dex,
    partySlot = opts and opts.partySlot or nil,
    partyFingerprint = opts and opts.partyFingerprint or nil,
  }
end

function MountSystem:restoreSelections(records)
  local restored = {}
  for _, mode in ipairs(MOUNT_MODES) do
    local record = type(records) == "table" and records[mode] or nil
    local mount = record and self.catalog:get(record.dex)
    if mount and mount.modes[mode] then
      restored[mode] = {
        dex = mount.dex,
        partySlot = tonumber(record.partySlot),
        partyFingerprint = record.partyFingerprint,
      }
    end
  end
  self.lastSelections = restored
  return true
end

function MountSystem:_transition(to, reason)
  local session = self.session
  local ok, err = self.State.validate(session.state, to)
  if not ok then return nil, err end
  local from = session.state
  session.state = to
  session.revision = session.revision + 1
  if self.State.isStable(to) then session.lastStable = to end
  if self.log then
    self.log:info("Mount", "%s -> %s (%s)", from, to,
      tostring(reason or "unspecified"))
  end
  return true
end

function MountSystem:_renderContext()
  local runtime, session = self.runtime or {}, self.session
  local preferred = self.settings and self.settings:get("preferred_renderer")
    or "auto"
  local spriteSource = self.settings and self.settings:get("sprite_source")
    or "auto"
  local generation = runtime.generation
  if not generation and runtime.world then
    generation = type(runtime.world.canFly) == "function" and 1 or 2
  end
  local visualLift = call(session.controller, "visualLift", session,
    runtime)
  if type(visualLift) ~= "number" then visualLift = 0 end
  return {
    mod = runtime.mod,
    game = runtime.game,
    world = runtime.world,
    generation = generation or 1,
    mapId = runtime.mapId,
    activeRenderer = runtime.activeRenderer or "native2d",
    rendererHost = runtime.rendererHost,
    cameraMode = runtime.cameraMode,
    preferredRenderer = preferred,
    spriteSource = spriteSource,
    species = session.species,
    dex = session.dex,
    mode = session.mode,
    altitude = session.altitude,
    visualLift = visualLift,
    showRider = not self.settings or self.settings:get("show_rider") ~= false,
    showShadow = not self.settings or self.settings:get("show_shadow") ~= false,
    mountScale = self.settings and type(self.settings.mountScale) == "function"
      and self.settings:mountScale(session.dex) or 1,
  }
end

function MountSystem:setRenderEnvironment(renderer, details)
  if not self.runtime then return false end
  renderer = renderer or "native2d"
  details = details or {}
  local changed = self.runtime.activeRenderer ~= renderer
    or self.runtime.rendererHost ~= details.host
    or self.runtime.cameraMode ~= details.cameraMode
  if not changed then return false end
  self.runtime.activeRenderer = renderer
  self.runtime.rendererHost = details.host
  self.runtime.cameraMode = details.cameraMode
  self.resolver:invalidate()

  local state = self.session.state
  if state ~= self.State.BATTLE_SUSPENDED
      and state ~= self.State.TRANSITION
      and state ~= self.State.UNMOUNTED then
    if self.session.renderLease then self:_releaseRender("renderer-changed") end
    self:_acquireRender("renderer-changed")
  end
  if self.log then
    self.log:info("Provider", "active renderer is %s (%s)", renderer,
      tostring(details.host or "engine"))
  end
  return true
end

function MountSystem:refreshRender(reason)
  self.resolver:invalidate()
  local state = self.session.state
  if state == self.State.UNMOUNTED or state == self.State.BATTLE_SUSPENDED
      or state == self.State.TRANSITION then return false end
  self:_releaseRender(reason or "render-refresh")
  self:_acquireRender(reason or "render-refresh")
  return true
end

function MountSystem:_acquireRender(recoveryReason)
  local session = self.session
  local lease, err = self.resolver:acquire(session.dex, session.mode,
    self:_renderContext())
  session.renderLease = lease
  session.providerId = lease and lease.provider.id or nil
  session.rendererId = lease and lease.resolved
    and (lease.resolved.renderer or lease.resolved.kind) or nil
  if not lease and self.log then
    self.log:warn("Provider", "no renderer lease: %s", tostring(err))
  end
  -- Never crop the player into a seated pose while the technical/invisible
  -- fallback is active. The complete rider remains readable until a visible
  -- mount actor can be reacquired.
  if visibleRenderLease(lease) and self.rider then
    local riderLease, riderErr = call(self.rider, "begin", session,
      lease.resolved, self:_renderContext())
    session.riderLease = riderLease
    if riderLease == nil and self.log then
      self.log:warn("Rider", "rider presentation fallback failed: %s",
        tostring(riderErr))
    end
  end
  if recoveryReason then
    if visibleRenderLease(lease) then
      local recovery = self.presentationRecovery
      if recovery then recovery.renderPending = false end
      self:_finishPresentationRecovery()
    else
      self:_schedulePresentationRecovery(recoveryReason, false)
    end
  end
  return lease, err
end

function MountSystem:_releaseRender(reason)
  local riderLease = self.session.riderLease
  self.session.riderLease = nil
  call(self.rider, "finish", riderLease, reason or "released")
  local lease = self.session.renderLease
  self.session.renderLease = nil
  self.session.providerId = nil
  self.session.rendererId = nil
  return self.resolver:release(lease, reason)
end

function MountSystem:_updatePresentationRecovery(dt)
  local recovery = self.presentationRecovery
  if not recovery then return false end
  local state = self.session.state
  if state == self.State.UNMOUNTED
      or state == self.State.BATTLE_SUSPENDED
      or state == self.State.TRANSITION then return false end

  recovery.delay = math.max(0, (tonumber(recovery.delay) or 0)
    - (tonumber(dt) or 0))
  if recovery.delay > 0 then return false end

  local lastError
  if recovery.controllerPending then
    local entered, enterErr = call(self.session.controller, "mapEnter",
      self.session, recovery.payload)
    if entered ~= nil and entered ~= false then
      recovery.controllerPending = false
    else
      lastError = enterErr or "controller map entry is not ready"
    end
  end

  if recovery.renderPending then
    self:_releaseRender("presentation-retry")
    self.resolver:invalidate()
    local lease, renderErr = self:_acquireRender()
    if visibleRenderLease(lease) then
      recovery.renderPending = false
    else
      lastError = renderErr or "mount actor is not ready"
    end
  end

  if self:_finishPresentationRecovery() then return true end
  recovery.attempts = (tonumber(recovery.attempts) or 1) - 1
  if recovery.attempts <= 0 then
    self.presentationRecovery = nil
    if self.log then
      self.log:warn("Lifecycle", "mount presentation recovery stopped: %s",
        tostring(lastError or recovery.reason))
    end
    return false
  end
  recovery.delay = PRESENTATION_RETRY_DELAY
  return false
end

function MountSystem:enable(runtime)
  self.runtime = runtime or self.runtime or {}
  if self.adapter then self.adapter:bind(self.runtime) end
  if self.enabled then
    -- game.ready may be re-emitted on hot reload; refresh references without
    -- duplicating state or presentation.
    return true
  end
  self.enabled = true
  if self.log then self.log:info("Lifecycle", "enabled") end
  return true
end

function MountSystem:persist(active)
  if active == nil then active = self.session.state ~= self.State.UNMOUNTED end
  return call(self.persistence, "write", self.session, active,
    self.lastSelections)
end

function MountSystem:queueRestore(record)
  if type(record) ~= "table" or not record.dex or not record.mode then
    return nil, "invalid saved mount session"
  end
  self.pendingRestore = record
  return true
end

function MountSystem:_tryRestore()
  local record = self.pendingRestore
  if not record or not self.enabled
      or self.session.state ~= self.State.UNMOUNTED then return false end
  local world = self.runtime and self.runtime.world
  if not (world and type(world.current) == "function") then return false end
  local ok, position = pcall(world.current, world)
  if not ok or type(position) ~= "table" then return false end
  self.pendingRestore = nil
  local restored, err = self:mount(record.dex, record.mode, {
    partySlot = record.partySlot,
    partyFingerprint = record.partyFingerprint,
    altitude = record.altitude,
    restoring = true,
  })
  if not restored and self.log then
    self.log:warn("Save", "saved mount was not restored: %s", tostring(err))
  end
  return restored, err
end

function MountSystem:disable(reason)
  if not self.enabled and self.session.state == self.State.UNMOUNTED then
    return true
  end
  self:_clearPresentationRecovery()
  self.pendingBattleResume = nil
  self:_releaseRender(reason or "disabled")
  call(self.ownership, "release", self.session.ownershipLease,
    reason or "disabled")
  self.session.ownershipLease = nil
  local controller = self.session.controller
  call(controller, "stop", self.session, reason or "disabled")
  self.session.controller = nil
  if self.session.state ~= self.State.UNMOUNTED then
    -- Cleanup must never be blocked by an interrupted transient state.
    self.session.state = self.State.UNMOUNTED
    self.session.revision = self.session.revision + 1
  end
  self.session:clearMount()
  self.enabled = false
  if self.log then self.log:info("Lifecycle", "disabled") end
  return true
end

function MountSystem:discoverProviders(context)
  if type(self.discover) == "function" then return self.discover(context) end
  return true
end

-- Ground and Flight shortcuts are a mode change, not a dismount followed by
-- another input. Preserve the active session authority while controllers and
-- presentation leases are exchanged atomically. Flight-to-Ground still asks
-- the flight controller whether the projected ground tile is safe.
function MountSystem:_switchLandMode(mount, mode, opts, reason)
  local session = self.session
  local sourceMode = session.mode
  if not isLandModeTransfer(sourceMode, mode) then
    return nil, "Only Ground and Flight support this direct transfer."
  end
  if session.state == self.State.BATTLE_SUSPENDED
      or session.state == self.State.TRANSITION then
    return nil, "The mount cannot change mode during a transition."
  end
  if sourceMode == "flight" then
    local canLand, landErr = call(session.controller, "canLand", session,
      self.runtime)
    if canLand == nil or canLand == false then
      return nil, landErr or "Find a clear land tile before changing mount."
    end
  end

  opts = copyOptions(opts)
  opts.transition = true
  local previous = {
    state = session.state,
    revision = session.revision,
    lastStable = session.lastStable,
    dex = session.dex,
    species = session.species,
    mode = session.mode,
    partySlot = session.partySlot,
    partyFingerprint = session.partyFingerprint,
    altitude = session.altitude,
    controller = session.controller,
  }
  local previousMount = self.catalog:get(previous.dex)
  local transferReason = reason or "land-mode-transfer"

  self:_clearPresentationRecovery()
  self:_releaseRender(transferReason)
  call(self.ownership, "release", session.ownershipLease, transferReason)
  session.ownershipLease = nil
  call(previous.controller, "stop", session, transferReason)

  local function restorePrevious(failure)
    call(session.controller, "stop", session, "land-mode-transfer-failed")
    session.state = previous.state
    session.revision = previous.revision
    session.lastStable = previous.lastStable
    session.dex = previous.dex
    session.species = previous.species
    session.mode = previous.mode
    session.partySlot = previous.partySlot
    session.partyFingerprint = previous.partyFingerprint
    session.altitude = previous.altitude
    session.controller = previous.controller
    local restartOpts = { transition = true,
      altitude = previous.altitude }
    call(previous.controller, "start", session, previousMount, self.runtime,
      restartOpts)
    session.ownershipLease = call(self.ownership, "acquire", session,
      self.runtime)
    self:_acquireRender("land-mode-rollback")
    return nil, failure
  end

  session.dex = mount.dex
  session.species = mount.species
  session.mode = mode
  session.partySlot = opts.partySlot
  session.partyFingerprint = opts.partyFingerprint
  session.altitude = 0
  session.controller = self.controllers[mode]
  local started, startErr = call(session.controller, "start", session, mount,
    self.runtime, opts)
  if started == nil or started == false then
    return restorePrevious(startErr
      or "target mount controller refused transfer")
  end

  local ok, transitionErr
  if sourceMode == "ground" then
    ok, transitionErr = self:_transition(self.State.TAKEOFF, transferReason)
  else
    if session.state ~= self.State.LANDING then
      ok, transitionErr = self:_transition(self.State.LANDING,
        transferReason)
    else
      ok = true
    end
    if ok then
      ok, transitionErr = self:_transition(self.State.GROUND,
        "ground-mount-ready")
    end
  end
  if not ok then return restorePrevious(transitionErr) end

  session.ownershipLease = call(self.ownership, "acquire", session,
    self.runtime)
  self:_acquireRender("land-mode-transfer")
  self:_rememberSelection(mode, mount, opts)
  self:persist(true)
  if self.log then
    self.log:info("Mount", "%s -> %s (%s)", sourceMode, mode,
      mount.species)
  end
  return true
end

function MountSystem:mount(id, mode, opts)
  if not self.enabled then return nil, "mount system is not ready" end
  mode = string.lower(tostring(mode or ""))
  local mount = self.catalog:get(id)
  if not mount then return nil, "unknown mount: " .. tostring(id) end
  if not mount.modes[mode] then
    return nil, ("%s does not support %s"):format(mount.species, mode)
  end
  local progressOk, progressErr = call(self.progression, "canMount", mount,
    mode, opts or {}, self.runtime)
  if progressOk == nil or progressOk == false then
    return nil, progressErr or "progression requirement not met"
  end

  if self.session.state ~= self.State.UNMOUNTED then
    if self.session.mode == mode
        and self.session.state ~= self.State.BATTLE_SUSPENDED
        and self.session.state ~= self.State.TRANSITION then
      self:_clearPresentationRecovery()
      self:_releaseRender("switch-mount")
      call(self.ownership, "release", self.session.ownershipLease,
        "switch-mount")
      self.session.dex = mount.dex
      self.session.species = mount.species
      self.session.partySlot = opts and opts.partySlot or nil
      self.session.partyFingerprint = opts and opts.partyFingerprint or nil
      self:_rememberSelection(mode, mount, opts)
      self.session.ownershipLease = call(self.ownership, "acquire",
        self.session, self.runtime)
      self:_acquireRender("switch-mount")
      self:persist(true)
      if self.log then
        self.log:info("Mount", "switched active %s mount to %s", mode,
          mount.species)
      end
      return true
    end
    if isLandModeTransfer(self.session.mode, mode) then
      return self:_switchLandMode(mount, mode, opts or {},
        "switch-mount-mode")
    end
    if self.session.mode == "flight" then
      return nil, "Land before changing mount mode."
    end
    local unmounted, unmountErr = self:dismount("switch-mount")
    if not unmounted then return nil, unmountErr end
  end

  local ok, err = self:_transition(self.State.MOUNTING, "mount-request")
  if not ok then return nil, err end
  local session = self.session
  session.dex = mount.dex
  session.species = mount.species
  session.mode = mode
  session.partySlot = opts and opts.partySlot or nil
  session.partyFingerprint = opts and opts.partyFingerprint or nil
  session.altitude = mode == "flight"
    and math.max(0, math.min(1, tonumber(opts and opts.altitude) or 0)) or 0

  local controller = self.controllers[mode]
  session.controller = controller
  local started, startErr = call(controller, "start", session, mount,
    self.runtime, opts or {})
  if started == nil or started == false then
    self:_transition(self.State.UNMOUNTED, "controller-refused")
    session:clearMount()
    return nil, startErr or "controller refused mount"
  end

  local target = self.State.targetForMode(mode)
  ok, err = self:_transition(target, "mounted")
  if not ok then
    call(controller, "stop", session, "transition-failed")
    session.state = self.State.UNMOUNTED
    session:clearMount()
    return nil, err
  end
  session.ownershipLease = call(self.ownership, "acquire", session,
    self.runtime)
  self:_acquireRender("mount-start")
  self:_rememberSelection(mode, mount, opts)
  self:persist(true)
  return true
end

function MountSystem:_shortcutCandidate(mode, candidateOpts)
  local lastError
  local function eligible(mount, mon, slot)
    if not (mount and mon and mount.modes[mode]) then return nil end
    local opts = copyOptions(candidateOpts)
    opts.mon = mon
    opts.partySlot = slot
    opts.partyFingerprint = self.adapter
      and self.adapter:fingerprint(mon) or nil
    local ok, err = call(self.progression, "canMount", mount, mode, opts,
      self.runtime)
    if ok == nil or ok == false then
      lastError = err or lastError
      return nil
    end
    return mount, mon, slot, opts
  end
  local remembered = self.lastSelections[mode]
  if remembered then
    local mount = self.catalog:get(remembered.dex)
    local mon = mount and self.adapter and self.adapter:partyMon(
      remembered.partySlot, mount.species, remembered.partyFingerprint)
    local found, foundMon, foundSlot, opts = eligible(mount, mon,
      mon and self.adapter:partySlot(mon) or nil)
    if found then return found, foundMon, foundSlot, opts end
  end
  local party = self.adapter and self.adapter:party() or {}
  for slot, mon in ipairs(party) do
    if type(mon) == "table" and not mon.isEgg and not mon.egg then
      local mount = self.catalog:get(mon.species)
      local found, foundMon, foundSlot, opts = eligible(mount, mon, slot)
      if found then return found, foundMon, foundSlot, opts end
    end
  end
  return nil, nil, nil, nil, lastError
end

function MountSystem:modeCandidate(mode)
  mode = string.lower(tostring(mode or ""))
  if mode ~= "ground" and mode ~= "surf" and mode ~= "flight" then
    return nil, "Unsupported mount mode."
  end
  local mount, _, slot, _, err = self:_shortcutCandidate(mode)
  if not mount then return nil, err end
  return { dex = mount.dex, species = mount.species, partySlot = slot,
    mode = mode }
end

-- Menu selection differs from a shortcut toggle: choosing the already active
-- mode is a no-op, and dismount remains an explicit row.
function MountSystem:activateMode(mode)
  mode = string.lower(tostring(mode or ""))
  if mode ~= "ground" and mode ~= "surf" and mode ~= "flight" then
    return nil, "Unsupported mount mode."
  end
  local session = self.session
  if session.state ~= self.State.UNMOUNTED and session.mode == mode then
    return true
  end
  if session.state ~= self.State.UNMOUNTED then
    if (session.mode == "flight" and mode == "surf")
        or (session.mode == "surf" and mode == "flight") then
      return self:_transferMode(mode, "mount-menu-transfer")
    end
    if isLandModeTransfer(session.mode, mode) then
      local mount, _, _, opts, candidateErr = self:_shortcutCandidate(mode,
        { transition = true })
      if not mount then return nil, candidateErr end
      return self:_switchLandMode(mount, mode, opts, "mount-menu-transfer")
    end
    return nil, "Dismount before changing to this mode."
  end
  local mount, _, _, opts, candidateErr = self:_shortcutCandidate(mode)
  if not mount then return nil, candidateErr end
  return self:mount(mount.dex, mode, opts)
end

function MountSystem:menuDismount()
  if self.session.state == self.State.UNMOUNTED then return true end
  if self.session.mode == "flight" then
    return self:requestLanding("mount-menu")
  end
  return self:dismount("mount-menu")
end

function MountSystem:_transferMode(mode, reason)
  local session = self.session
  local sourceMode = session.mode
  if not ((sourceMode == "flight" and mode == "surf")
      or (sourceMode == "surf" and mode == "flight")) then
    return nil, "Only Flight and Surf support a direct transfer."
  end
  if not (self.adapter and self.adapter:currentTerrain() == "water") then
    return nil, "Direct Flight/Surf transfer requires a water tile."
  end

  local transitionOpts = {
    transition = true,
    waterTakeoff = mode == "flight",
  }
  local mount, _, _, opts, candidateErr = self:_shortcutCandidate(mode,
    transitionOpts)
  if not mount then
    return nil, candidateErr or (mode == "surf"
      and "No compatible Surf Pokémon is available in the party."
      or "No compatible flying Pokémon is available in the party.")
  end

  local previous = {
    state = session.state,
    lastStable = session.lastStable,
    dex = session.dex,
    species = session.species,
    mode = session.mode,
    partySlot = session.partySlot,
    partyFingerprint = session.partyFingerprint,
    altitude = session.altitude,
    controller = session.controller,
  }
  local previousMount = self.catalog:get(previous.dex)

  self:_clearPresentationRecovery()
  self:_releaseRender(reason or "water-transfer")
  call(self.ownership, "release", session.ownershipLease,
    reason or "water-transfer")
  session.ownershipLease = nil
  call(previous.controller, "stop", session, reason or "water-transfer")

  local nativeOk, nativeErr = self.adapter:setSurfState(mode == "surf")
  if nativeOk == nil or nativeOk == false then
    call(previous.controller, "start", session, previousMount, self.runtime,
      { transition = true, waterTakeoff = previous.mode == "flight" })
    session.ownershipLease = call(self.ownership, "acquire", session,
      self.runtime)
    self:_acquireRender("water-transfer-rollback")
    return nil, nativeErr or "native water state transfer failed"
  end

  session.dex = mount.dex
  session.species = mount.species
  session.mode = mode
  session.partySlot = opts.partySlot
  session.partyFingerprint = opts.partyFingerprint
  session.altitude = 0
  session.controller = self.controllers[mode]
  local started, startErr = call(session.controller, "start", session, mount,
    self.runtime, opts)
  if started == nil or started == false then
    call(session.controller, "stop", session, "water-transfer-failed")
    self.adapter:setSurfState(sourceMode == "surf")
    session.state = previous.state
    session.lastStable = previous.lastStable
    session.dex = previous.dex
    session.species = previous.species
    session.mode = previous.mode
    session.partySlot = previous.partySlot
    session.partyFingerprint = previous.partyFingerprint
    session.altitude = previous.altitude
    session.controller = previous.controller
    call(previous.controller, "start", session, previousMount, self.runtime,
      { transition = true, waterTakeoff = previous.mode == "flight" })
    session.ownershipLease = call(self.ownership, "acquire", session,
      self.runtime)
    self:_acquireRender("water-transfer-rollback")
    return nil, startErr or "target mount controller refused transfer"
  end

  local ok, transitionErr
  if sourceMode == "flight" then
    ok, transitionErr = self:_transition(self.State.LANDING,
      reason or "land-on-water")
    if ok then
      ok, transitionErr = self:_transition(self.State.SURF,
        "water-mount-ready")
    end
  else
    ok, transitionErr = self:_transition(self.State.TAKEOFF,
      reason or "water-takeoff")
  end
  if not ok then return nil, transitionErr end

  session.ownershipLease = call(self.ownership, "acquire", session,
    self.runtime)
  self:_acquireRender("water-transfer")
  self:_rememberSelection(mode, mount, opts)
  self:persist(true)
  if self.log then
    self.log:info("Mount", "%s -> %s on water (%s)", sourceMode, mode,
      mount.species)
  end
  return true
end

function MountSystem:toggleMode(mode)
  mode = string.lower(tostring(mode or ""))
  if mode ~= "ground" and mode ~= "flight" then
    return nil, "Unsupported mount shortcut."
  end
  local session = self.session
  if session.state ~= self.State.UNMOUNTED then
    if session.mode == "surf" and mode == "flight" then
      return self:_transferMode("flight", "shortcut-water-takeoff")
    end
    if isLandModeTransfer(session.mode, mode) then
      local mount, _, _, opts, candidateErr = self:_shortcutCandidate(mode,
        { transition = true })
      if not mount then
        return nil, candidateErr or (mode == "flight"
          and "No compatible flying Pokémon is available in the party."
          or "No compatible ground Pokémon is available in the party.")
      end
      return self:_switchLandMode(mount, mode, opts,
        "shortcut-land-mode-transfer")
    end
    if session.mode ~= mode then
      return nil, "Dismount the active mount before changing mode."
    end
    if mode == "flight" then return self:requestLanding("shortcut") end
    return self:dismount("shortcut")
  end
  local mount, mon, slot, opts, candidateErr = self:_shortcutCandidate(mode)
  if not mount then
    return nil, candidateErr or (mode == "flight"
      and "No compatible flying Pokémon is available in the party."
      or "No compatible ground Pokémon is available in the party.")
  end
  return self:mount(mount.dex, mode, opts)
end

function MountSystem:dismount(reason)
  local session = self.session
  if session.state == self.State.UNMOUNTED then return true end
  local prepared, prepareErr = call(session.controller, "prepareStop", session,
    self.runtime, reason or "dismount")
  if prepared == nil or prepared == false then
    return nil, prepareErr or "the mount cannot dismount here"
  end
  self:_clearPresentationRecovery()
  self.pendingBattleResume = nil
  self:_releaseRender(reason or "dismount")
  call(self.ownership, "release", session.ownershipLease,
    reason or "dismount")
  session.ownershipLease = nil
  call(session.controller, "stop", session, reason or "dismount")
  session.controller = nil
  if session.state == self.State.BATTLE_SUSPENDED
      or session.state == self.State.TRANSITION
      or session.state == self.State.LANDING then
    local ok = self:_transition(self.State.UNMOUNTED, reason or "dismount")
    if not ok then session.state = self.State.UNMOUNTED end
  else
    local ok, err = self:_transition(self.State.DISMOUNTING,
      reason or "dismount")
    if not ok then return nil, err end
    ok, err = self:_transition(self.State.UNMOUNTED, reason or "dismount")
    if not ok then return nil, err end
  end
  self:persist(false)
  session:clearMount()
  return true
end

function MountSystem:update(dt)
  local session = self.session
  if session.state == self.State.UNMOUNTED then
    self:_tryRestore()
    return
  end
  if session.state == self.State.BATTLE_SUSPENDED then
    self:_tryBattleResume(dt)
    if session.state == self.State.BATTLE_SUSPENDED then return end
  end
  self:_updatePresentationRecovery(dt)
  call(self.ownership, "update", session.ownershipLease, session,
    self.runtime)
  if session.state == self.State.TAKEOFF then
    local target = call(session.controller, "takeoffTarget", session,
      self.runtime)
    if type(target) ~= "number" then target = 0.85 end
    target = math.max(0.78, math.min(1, target))
    if session.altitude < target then
      session.altitude = math.min(target,
        session.altitude + (tonumber(dt) or 0) * 0.85)
    end
    if session.altitude >= target then
      self:_transition(self.State.FLIGHT, "takeoff")
    end
  elseif session.state == self.State.LANDING then
    session.altitude = math.max(0, session.altitude - (tonumber(dt) or 0) * 1.5)
    if session.altitude <= 0 then
      self:dismount("landed")
      return
    end
  end
  if session.state ~= self.State.BATTLE_SUSPENDED
      and session.state ~= self.State.TRANSITION then
    local updated, updateErr = call(session.controller, "update", session, dt,
      self.runtime)
    if updated == nil or updated == false then
      if self.log then
        self.log:warn("Mount", "controller stopped: %s", tostring(updateErr))
      end
      self:dismount("controller-lost")
      return
    end
  end
  if session.renderLease then
    local rendered, renderErr = self.resolver:update(session.renderLease,
      self:_renderContext())
    if not rendered then
      if self.log then
        self.log:warn("Provider", "active lease lost: %s",
          tostring(renderErr))
      end
      self:_releaseRender("provider-lost")
      self:_acquireRender("provider-lost")
    end
  end
  if session.riderLease then
    call(self.rider, "update", session.riderLease, session,
      self:_renderContext())
  end
end

function MountSystem:handleInput(input, dt)
  local session = self.session
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.BATTLE_SUSPENDED
      or session.state == self.State.TRANSITION then return false end
  call(session.controller, "input", session, input, dt, self.runtime)
  if session.mode == "flight" and input and input.isDown
      and input.wasPressed and input:isDown("select")
      and input:wasPressed("b") then
    return self:requestLanding("input")
  end
  return true
end

function MountSystem:requestLanding(reason)
  local session = self.session
  if session.state ~= self.State.FLIGHT
      and session.state ~= self.State.TAKEOFF then
    return nil, "the mount is not in flight"
  end
  if self.adapter and self.adapter:currentTerrain() == "water" then
    return self:_transferMode("surf", reason or "land-on-water")
  end
  local canLand, err = call(session.controller, "canLand", session,
    self.runtime)
  if canLand == nil or canLand == false then return nil, err end
  return self:_transition(self.State.LANDING, reason or "landing-request")
end

function MountSystem:movementFrames(frames, ctx)
  local session = self.session
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.BATTLE_SUSPENDED
      or session.state == self.State.TRANSITION then return frames end
  local value = call(session.controller, "speed", frames, ctx, session,
    self.runtime)
  if type(value) ~= "number" then return frames end
  return math.max(1, math.floor(value))
end

function MountSystem:recordCollision(value)
  if type(value) == "table" then
    self.session.lastCollision = value
    if value.final ~= false then
      call(self.session.controller, "onCollision", self.session, value,
        self.runtime)
    end
  end
end

function MountSystem:isAirborne()
  local session = self.session
  if session.mode ~= "flight" then return false end
  return session.state == self.State.TAKEOFF
    or session.state == self.State.FLIGHT
    or session.state == self.State.LANDING
end

function MountSystem:_resumeState()
  local session = self.session
  local state = self.State.isStable(session.state) and session.state
    or session.lastStable
  if state == self.State.UNMOUNTED or state == self.State.MOUNTING
      or state == self.State.DISMOUNTING or state == nil then
    state = self.State.targetForMode(session.mode)
  end
  if state == self.State.TAKEOFF or state == self.State.LANDING then
    state = self.State.FLIGHT
  end
  return state
end

function MountSystem:onBattleStarted(payload)
  local session = self.session
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.BATTLE_SUSPENDED then return false end
  local resumeState = self:_resumeState()
  session.resume = {
    state = resumeState,
    dex = session.dex,
    mode = session.mode,
    revision = session.revision,
  }
  self.pendingBattleResume = nil
  self:_clearPresentationRecovery()
  self:_releaseRender("battle")
  call(session.controller, "suspend", session, payload)
  return self:_transition(self.State.BATTLE_SUSPENDED, "battle-started")
end

function MountSystem:_resumeAfterBattle(payload)
  local session = self.session
  if session.state ~= self.State.BATTLE_SUSPENDED then return false end
  local resume = session.resume
  if not resume or resume.dex ~= session.dex then
    return self:dismount("battle-resume-missing")
  end

  local mount = self.catalog:get(session.dex)
  if not mount or not mount.modes[session.mode] then
    return self:dismount("battle-resume-unsupported")
  end
  local mon
  if self.identity then
    local resolvedMon, resolvedSlot, resolvedFingerprint = self.identity:resolve({
      species = session.species,
      partySlot = session.partySlot,
      partyFingerprint = session.partyFingerprint,
    })
    if not resolvedMon then
      if self.log then
        self.log:warn("Battle", "mount identity rejected: %s",
          tostring(resolvedSlot))
      end
      return self:dismount("battle-mount-ineligible")
    end
    mon = resolvedMon
    session.partySlot = resolvedSlot
    session.partyFingerprint = resolvedFingerprint
  end
  local eligible, eligibilityErr = call(self.progression, "canMount", mount,
    session.mode, {
      mon = mon,
      partySlot = session.partySlot,
      partyFingerprint = session.partyFingerprint,
      transition = true,
    }, self.runtime)
  if eligible == nil or eligible == false then
    if self.log then
      self.log:warn("Battle", "mount eligibility changed: %s",
        tostring(eligibilityErr))
    end
    return self:dismount("battle-mount-ineligible")
  end

  local target = resume.state
  if target == self.State.TAKEOFF then target = self.State.FLIGHT end
  local ok, err = self:_transition(target, "battle-ended")
  if not ok then return self:dismount("battle-resume-invalid") end
  session.resume = nil
  local resumed, resumeErr = call(session.controller, "resume", session,
    payload)
  if resumed == nil or resumed == false then
    if self.log then
      self.log:warn("Battle", "controller resume failed: %s",
        tostring(resumeErr))
    end
    return self:dismount("battle-controller-unavailable")
  end
  self:_acquireRender("battle-resume")
  return true
end

function MountSystem:_tryBattleResume(dt)
  local pending = self.pendingBattleResume
  if not pending or self.session.state ~= self.State.BATTLE_SUSPENDED then
    return false
  end
  local free = call(self.adapter, "isFreeRoam")
  if free ~= nil and free ~= false then
    self.pendingBattleResume = nil
    return self:_resumeAfterBattle(pending.payload)
  end
  pending.remaining = (tonumber(pending.remaining) or BATTLE_RESUME_TIMEOUT)
    - (tonumber(dt) or 0)
  if pending.remaining <= 0 then
    self.pendingBattleResume = nil
    if self.log then
      self.log:warn("Battle", "free-roam did not return before timeout")
    end
    return self:dismount("battle-resume-timeout")
  end
  return true
end

function MountSystem:onBattleEnded(payload)
  local session = self.session
  if session.state ~= self.State.BATTLE_SUSPENDED then return false end
  local auto = not self.settings
    or self.settings:get("auto_remount_after_battle") ~= false
  if not auto or not session.resume or session.resume.dex ~= session.dex then
    return self:dismount("battle-ended-no-resume")
  end
  self.pendingBattleResume = {
    payload = payload,
    remaining = BATTLE_RESUME_TIMEOUT,
  }
  return self:_tryBattleResume(0)
end

function MountSystem:onMapExited(payload)
  local session = self.session
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.TRANSITION then return false end
  if session.state == self.State.BATTLE_SUSPENDED then
    self.pendingBattleResume = nil
    return self:dismount("battle-map-transition")
  end
  local resumeState = self:_resumeState()
  session.transitionKind = self.transitionPolicy
    and self.transitionPolicy:classify("map.exited", payload) or "map"
  session.resume = {
    state = resumeState,
    dex = session.dex,
    mode = session.mode,
    revision = session.revision,
  }
  self:_clearPresentationRecovery()
  self:_releaseRender("map-exit")
  call(self.ownership, "release", session.ownershipLease, "map-exit")
  session.ownershipLease = nil
  call(session.controller, "mapExit", session, payload)
  return self:_transition(self.State.TRANSITION, "map-exit")
end

function MountSystem:onMapEntered(payload)
  local session = self.session
  session.mapRevision = session.mapRevision + 1
  if self.runtime then self.runtime.mapId = payload and payload.mapId end
  self.resolver:invalidate()
  if session.state ~= self.State.TRANSITION then return false end
  local resume = session.resume
  if not resume or resume.dex ~= session.dex or not resume.state then
    return self:dismount("map-resume-missing")
  end
  local canResume, resumeErr = self.transitionPolicy
    and self.transitionPolicy:canResume(session.mode) or true
  if not canResume then
    if self.log then
      self.log:info("Map", "mount stopped after %s: %s",
        tostring(session.transitionKind or "map"), tostring(resumeErr))
    end
    return self:dismount("map-environment-changed")
  end
  local ok = self:_transition(resume.state, "map-entered")
  if not ok then return self:dismount("map-resume-invalid") end
  session.resume = nil
  local entered, enterErr = call(session.controller, "mapEnter", session,
    payload)
  session.ownershipLease = call(self.ownership, "acquire", session,
    self.runtime)
  self:_acquireRender("map-entered")
  if entered == nil or entered == false then
    self:_schedulePresentationRecovery(enterErr or "controller-map-enter",
      true, payload)
  end
  return true
end

-- `map.reloaded` is not guaranteed to be preceded by `map.exited`. Rebuild
-- the visual and follower leases in place while preserving the stable mount
-- state; treating it as a normal enter used to leave an actor owned by the
-- discarded map until the provider failed on a later frame.
function MountSystem:onMapReloaded(payload)
  local session = self.session
  if session.state == self.State.TRANSITION then
    return self:onMapEntered(payload)
  end
  session.mapRevision = session.mapRevision + 1
  session.transitionKind = self.transitionPolicy
    and self.transitionPolicy:classify("map.reloaded", payload) or "reload"
  if self.runtime then self.runtime.mapId = payload and payload.mapId end
  self.resolver:invalidate()
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.BATTLE_SUSPENDED then return false end

  self:_clearPresentationRecovery()
  self:_releaseRender("map-reload")
  call(self.ownership, "release", session.ownershipLease, "map-reload")
  session.ownershipLease = nil
  local entered, enterErr = call(session.controller, "mapEnter", session,
    payload)
  session.ownershipLease = call(self.ownership, "acquire", session,
    self.runtime)
  self:_acquireRender("map-reloaded")
  if entered == nil or entered == false then
    self:_schedulePresentationRecovery(enterErr or "controller-map-reload",
      true, payload)
  end
  return true
end

function MountSystem:onCheckpointRestored(payload)
  self.resolver:invalidate()
  if self.session.state == self.State.UNMOUNTED then return false end
  self:_clearPresentationRecovery()
  self.pendingBattleResume = nil
  self.session.transitionKind = self.transitionPolicy
    and self.transitionPolicy:classify("checkpoint.restored", payload)
    or "checkpoint"
  return self:dismount("checkpoint-restored")
end

function MountSystem:snapshot()
  local out = self.session:snapshot()
  out.enabled = self.enabled
  out.generation = self.runtime and self.runtime.generation or nil
  out.activeRenderer = self.runtime and self.runtime.activeRenderer or nil
  out.rendererHost = self.runtime and self.runtime.rendererHost or nil
  out.presentationPending = self.presentationRecovery ~= nil
  out.presentationAttempts = self.presentationRecovery
    and self.presentationRecovery.attempts or 0
  out.battleResumePending = self.pendingBattleResume ~= nil
  out.transitionKind = self.session.transitionKind
  return out
end

return MountSystem

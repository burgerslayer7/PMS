local V = ...
local MountSession = V.require("core/MountSession")

local MountSystem = {}
MountSystem.__index = MountSystem

local function call(object, name, ...)
  if type(object) ~= "table" or type(object[name]) ~= "function" then
    return true
  end
  local ok, first, second = pcall(object[name], object, ...)
  if not ok then return nil, first end
  return first, second
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
    persistence = deps.persistence,
    rider = deps.rider,
    ownership = deps.ownership,
    discover = deps.discover,
    pendingRestore = nil,
  }, MountSystem)
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
  local generation = runtime.generation
  if not generation and runtime.world then
    generation = type(runtime.world.canFly) == "function" and 1 or 2
  end
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
    species = session.species,
    dex = session.dex,
    mode = session.mode,
    altitude = session.altitude,
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
  if self.session.renderLease
      and state ~= self.State.BATTLE_SUSPENDED
      and state ~= self.State.TRANSITION
      and state ~= self.State.UNMOUNTED then
    self:_releaseRender("renderer-changed")
    self:_acquireRender()
  end
  if self.log then
    self.log:info("Provider", "active renderer is %s (%s)", renderer,
      tostring(details.host or "engine"))
  end
  return true
end

function MountSystem:_acquireRender()
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
  if lease and self.rider then
    local riderLease, riderErr = call(self.rider, "begin", session,
      lease.resolved, self:_renderContext())
    session.riderLease = riderLease
    if riderLease == nil and self.log then
      self.log:warn("Rider", "rider presentation fallback failed: %s",
        tostring(riderErr))
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
  return call(self.persistence, "write", self.session, active)
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
      self:_releaseRender("switch-mount")
      call(self.ownership, "release", self.session.ownershipLease,
        "switch-mount")
      self.session.dex = mount.dex
      self.session.species = mount.species
      self.session.partySlot = opts and opts.partySlot or nil
      self.session.partyFingerprint = opts and opts.partyFingerprint or nil
      self.session.ownershipLease = call(self.ownership, "acquire",
        self.session, self.runtime)
      self:_acquireRender()
      self:persist(true)
      if self.log then
        self.log:info("Mount", "switched active %s mount to %s", mode,
          mount.species)
      end
      return true
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
  self:_acquireRender()
  self:persist(true)
  return true
end

function MountSystem:dismount(reason)
  local session = self.session
  if session.state == self.State.UNMOUNTED then return true end
  local prepared, prepareErr = call(session.controller, "prepareStop", session,
    self.runtime, reason or "dismount")
  if prepared == nil or prepared == false then
    return nil, prepareErr or "the mount cannot dismount here"
  end
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
  call(self.ownership, "update", session.ownershipLease, session,
    self.runtime)
  if session.state == self.State.TAKEOFF then
    session.altitude = math.min(1, session.altitude + (tonumber(dt) or 0) * 1.5)
    if session.altitude >= 1 then self:_transition(self.State.FLIGHT, "takeoff") end
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
      self:_acquireRender()
    end
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
  if type(value) == "table" then self.session.lastCollision = value end
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
  self:_releaseRender("battle")
  call(session.controller, "suspend", session, payload)
  return self:_transition(self.State.BATTLE_SUSPENDED, "battle-started")
end

function MountSystem:onBattleEnded(payload)
  local session = self.session
  if session.state ~= self.State.BATTLE_SUSPENDED then return false end
  local auto = not self.settings
    or self.settings:get("auto_remount_after_battle") ~= false
  local resume = session.resume
  if not auto or not resume or resume.dex ~= session.dex then
    return self:dismount("battle-ended-no-resume")
  end
  local target = resume.state
  if target == self.State.TAKEOFF then target = self.State.FLIGHT end
  local ok, err = self:_transition(target, "battle-ended")
  if not ok then return self:dismount("battle-resume-invalid") end
  session.resume = nil
  call(session.controller, "resume", session, payload)
  self:_acquireRender()
  return true
end

function MountSystem:onMapExited(payload)
  local session = self.session
  if session.state == self.State.UNMOUNTED
      or session.state == self.State.TRANSITION then return false end
  local resumeState = self:_resumeState()
  session.resume = {
    state = resumeState,
    dex = session.dex,
    mode = session.mode,
    revision = session.revision,
  }
  self:_releaseRender("map-exit")
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
  local ok = self:_transition(resume.state, "map-entered")
  if not ok then return self:dismount("map-resume-invalid") end
  session.resume = nil
  call(session.controller, "mapEnter", session, payload)
  self:_acquireRender()
  return true
end

function MountSystem:onCheckpointRestored(payload)
  self.resolver:invalidate()
  if self.session.state == self.State.UNMOUNTED then return false end
  return self:dismount("checkpoint-restored")
end

function MountSystem:snapshot()
  local out = self.session:snapshot()
  out.enabled = self.enabled
  out.generation = self.runtime and self.runtime.generation or nil
  out.activeRenderer = self.runtime and self.runtime.activeRenderer or nil
  out.rendererHost = self.runtime and self.runtime.rendererHost or nil
  return out
end

return MountSystem

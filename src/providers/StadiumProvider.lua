-- Public tag/untag integration for the maintained Stadium overworld model
-- providers. PMS owns the actor and gameplay; Stadium owns model loading and
-- drawing. A failed tag falls through to the next render provider.

local StadiumProvider = {}
StadiumProvider.__index = StadiumProvider

-- Gen2-3D-Sprites / Stadium 2 is intentionally outside the supported
-- runtime. PMS no longer probes, tags or adapts itself to that mod.
local IDS = {
  [1] = { "STADIUM_OVERWORLD_MODELS" },
}

local function find(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, value = pcall(mod.find, id)
  if not ok then ok, value = pcall(mod.find, mod, id) end
  return ok and value or nil
end

function StadiumProvider.new(opts)
  return setmetatable({
    mod = opts.mod,
    catalog = opts.catalog,
    poses = opts.poses,
    builtin = opts.builtin,
    bridge = opts.bridge,
    voxel = opts.voxel,
    log = opts.log,
    handles = {},
    scanned = {},
  }, StadiumProvider)
end

function StadiumProvider:discover()
  for generation, ids in pairs(IDS) do
    if not self.scanned[generation] then
      for _, id in ipairs(ids) do
        if not self.handles[generation] then
          local handle = find(self.mod, id)
          local exports = handle and handle.exports
          if type(exports) == "table" and type(exports.tag) == "function"
              and type(exports.untag) == "function" then
            self.handles[generation] = {
              id = id,
              version = handle.version,
              exports = exports,
            }
            if self.log then
              self.log:info("Integration", "Stadium provider discovered: %s",
                id)
            end
          end
        end
      end
      self.scanned[generation] = true
    end
  end
  return true
end

function StadiumProvider:_handle(generation)
  if generation ~= 1 then return nil end
  if not self.scanned[generation] then self:discover() end
  return self.handles[generation]
end

function StadiumProvider:world3DState(generation)
  if generation ~= 1 then return false end
  local handle = self:_handle(generation)
  local exports = handle and handle.exports
  if not exports or exports.rendererInstalled ~= true then return false end
  if type(exports.world3DEnabled) == "function" then
    local ok, enabled = pcall(exports.world3DEnabled)
    if ok then return enabled == true, handle end
  end
  local voxel = self.voxel and self.voxel:activeHost()
  return voxel ~= nil, handle
end

function StadiumProvider:contract()
  local owner = self
  return {
    api = 1,
    id = "stadium_models",
    priority = 800,
    probe = function(_, context)
      local generation = context and context.generation or 1
      if generation ~= 1 then
        return nil, "Gen2-3D-Sprites is outside the supported runtime"
      end
      local handle = owner:_handle(generation)
      local exports = handle and handle.exports
      if not exports or exports.rendererInstalled ~= true then
        return nil, exports and exports.rendererError
          or "Stadium renderer unavailable"
      end
      local active = owner:world3DState(generation)
      local explicit = context and context.preferredRenderer == "stadium"
      if not active and not explicit then
        return nil, "Stadium world renderer is not active"
      end
      return {
        available = true,
        kind = "stadium",
        renderer = "voxel",
        fit = 150,
        host = handle.id,
        dexFirst = 1,
        dexLast = tonumber(exports.maxDex) or (generation == 1 and 151 or 251),
      }
    end,
    resolve = function(_, dex, mode, context)
      local generation = context and context.generation or 1
      if generation ~= 1 then
        return nil, "Gen2-3D-Sprites is outside the supported runtime"
      end
      local handle = owner:_handle(generation)
      local exports = handle and handle.exports
      local maxDex = exports and (tonumber(exports.maxDex)
        or 151) or 0
      local mount = owner.catalog:get(dex)
      if not mount or not mount.modes[mode] then
        return nil, "unsupported mount mode"
      end
      if dex < 1 or dex > maxDex then return nil, "model dex unavailable" end
      return {
        kind = "stadium",
        renderer = "voxel",
        dex = dex,
        species = mount.species,
        mode = mode,
        spriteId = owner.builtin:spriteId(dex, mode),
        pose = owner.poses:resolve(dex, mode, "down"),
        stadium = handle,
      }
    end,
    begin = function(_, resolved, context)
      local lease, err = owner.bridge:spawn(resolved, context)
      if not lease then return nil, err end
      local entity = owner.bridge:entity(lease)
      if not entity then
        owner.bridge:remove(lease, "stadium-no-entity")
        return nil, "live entity unavailable for Stadium tag"
      end
      local ok, tagged = pcall(resolved.stadium.exports.tag, entity,
        resolved.dex)
      if not ok or tagged == false then
        owner.bridge:remove(lease, "stadium-tag-failed")
        return nil, ok and "Stadium rejected species" or tagged
      end
      lease.stadiumEntity = entity
      lease.stadiumExports = resolved.stadium.exports
      return lease
    end,
    update = function(_, lease, context)
      return owner.bridge:sync(lease, context)
    end,
    finish = function(_, lease, reason)
      if lease and lease.stadiumEntity and lease.stadiumExports
          and type(lease.stadiumExports.untag) == "function" then
        pcall(lease.stadiumExports.untag, lease.stadiumEntity)
      end
      return owner.bridge:remove(lease, reason)
    end,
  }
end

function StadiumProvider:status()
  local out = {}
  for generation, handle in pairs(self.handles) do
    out[tostring(generation)] = {
      id = handle.id,
      version = handle.version,
      rendererInstalled = handle.exports.rendererInstalled == true,
    }
  end
  return out
end

return StadiumProvider

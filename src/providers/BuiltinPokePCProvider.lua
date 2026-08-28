local BuiltinPokePCProvider = {}
BuiltinPokePCProvider.__index = BuiltinPokePCProvider

local MODES = { "ground", "surf", "flight" }

function BuiltinPokePCProvider.new(opts)
  assert(type(opts) == "table", "builtin provider options required")
  return setmetatable({
    mod = opts.mod,
    catalog = opts.catalog,
    poses = opts.poses,
    bridge = opts.bridge,
    log = opts.log,
    spriteIds = {},
  }, BuiltinPokePCProvider)
end

function BuiltinPokePCProvider:spriteId(dex, mode)
  return string.format("PMS_MOUNT_%03d_%s", dex, string.upper(mode))
end

function BuiltinPokePCProvider:registerContent()
  local sprites = self.mod and self.mod.content and self.mod.content.sprites
  if not sprites then return nil, "sprites registry unavailable" end
  local gen2 = sprites:get("SPRITE_CHRIS") ~= nil
    or sprites:get("SPRITE_KRIS") ~= nil
  for _, mount in ipairs(self.catalog.ordered) do
    for _, mode in ipairs(MODES) do
      if mount.modes[mode] then
        local pose = self.poses:resolve(mount.dex, mode, "down")
        local id = self:spriteId(mount.dex, mode)
        local relative = string.format(
          "assets/fallback/pokepc/scaled/%dx/follower_%03d.png",
          pose.scale, mount.dex)
        local def = {
          id = id,
          image = self.mod.assets:path(relative),
          frames = 6,
          walker = true,
          frameWidth = pose.frameWidth,
          frameHeight = pose.frameHeight,
          anchorX = pose.anchorX,
          anchorY = pose.anchorY,
          trueColor = true,
          paletteSource = gen2 and "SPRITE_CHRIS" or "SPRITE_RED",
        }
        if gen2 then def.spriteType = "WALKING_SPRITE" end
        sprites:register(id, def)
        self.spriteIds[mount.dex .. ":" .. mode] = id
      end
    end
  end
  return true
end

function BuiltinPokePCProvider:contract()
  local owner = self
  return {
    api = 1,
    id = "builtin_pokepc_2d",
    priority = -100,
    probe = function()
      return {
        available = true,
        kind = "builtin2d",
        renderer = "native2d",
        fit = 10,
        dexFirst = 1,
        dexLast = 251,
      }
    end,
    resolve = function(_, dex, mode)
      local mount = owner.catalog:get(dex)
      if not mount or not mount.modes[mode] then
        return nil, "unsupported mount mode"
      end
      local spriteId = owner.spriteIds[dex .. ":" .. mode]
      if not spriteId then return nil, "mount sprite was not registered" end
      return {
        kind = "native2d",
        renderer = "native2d",
        dex = dex,
        species = mount.species,
        mode = mode,
        spriteId = spriteId,
        pose = owner.poses:resolve(dex, mode, "down"),
      }
    end,
    begin = function(_, resolved, context)
      return owner.bridge:spawn(resolved, context)
    end,
    update = function(_, lease, context)
      return owner.bridge:sync(lease, context)
    end,
    finish = function(_, lease, reason)
      return owner.bridge:remove(lease, reason)
    end,
    riderPose = function(_, dex, mode, direction)
      return owner.poses:resolve(dex, mode, direction)
    end,
  }
end

return BuiltinPokePCProvider

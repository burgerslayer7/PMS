-- Voxel hosts already render ordinary overworld actors as depth-aware sprite
-- billboards. This provider supplies a PMS-owned actor and deliberately leaves
-- terrain, camera and world geometry to the active host.

local VoxelBillboardProvider = {}

function VoxelBillboardProvider.new(opts)
  local owner = opts
  return {
    api = 1,
    id = "voxel_mount_billboard",
    priority = 400,
    probe = function(_, context)
      if not context or context.activeRenderer ~= "voxel" then
        return nil, "voxel renderer is not active"
      end
      local host = owner.voxel and owner.voxel:activeHost()
      if not host and context.rendererHost == nil then
        return nil, "no compatible active voxel host"
      end
      return {
        available = true,
        kind = "voxel",
        renderer = "voxel",
        fit = 80,
        host = host and host.id or context.rendererHost,
      }
    end,
    resolve = function(_, dex, mode, context)
      local mount = owner.catalog:get(dex)
      if not mount or not mount.modes[mode] then
        return nil, "unsupported mount mode"
      end
      local spriteId = owner.builtin:spriteId(dex, mode)
      if not spriteId then return nil, "fallback sprite unavailable" end
      return {
        kind = "voxel",
        renderer = "voxel",
        dex = dex,
        species = mount.species,
        mode = mode,
        spriteId = spriteId,
        pose = owner.poses:resolve(dex, mode, "down"),
        host = context and context.rendererHost,
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
  }
end

return VoxelBillboardProvider

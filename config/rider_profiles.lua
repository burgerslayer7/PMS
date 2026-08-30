-- Native 2D presentation only. Frame size and the base rider lift come from
-- the species' Pokédex height through MountScale, never from hand-picked 2x/
-- 3x/4x buckets. Profiles here are limited to art-specific anchor tuning.

return {
  defaults = {
    ground = { anchorRatio = 0.76, bob = 1, clipRider = true },
    surf = { anchorRatio = 0.74, bob = 1, clipRider = true },
    -- Flight uses a neutral lift so the cropped rider sits in the centre of
    -- the airborne silhouette instead of floating above its shoulders.
    flight = { anchorRatio = 0.74, bob = 1, riderLift = 0,
      clipRider = true },
  },
  profiles = {
    ["073:surf"] = { anchorRatio = 0.71 },
    ["130:surf"] = { anchorRatio = 0.72 },
    ["131:surf"] = { anchorRatio = 0.76 },
    ["148:flight"] = { anchorRatio = 0.72 },
    ["245:surf"] = { anchorRatio = 0.72 },
    ["249:surf"] = { anchorRatio = 0.72 },
    ["249:flight"] = { anchorRatio = 0.72 },
    ["250:flight"] = { anchorRatio = 0.72 },
  },
}

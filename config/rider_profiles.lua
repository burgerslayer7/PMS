-- Native 2D mount geometry. Values are provider data, not collision data.
-- anchorY is the mount sheet's anchor measured from each scaled frame top.

return {
  defaults = {
    ground = { scale = 2, anchorY = 20, bob = 1 },
    surf = { scale = 3, anchorY = 30, bob = 2 },
    flight = { scale = 3, anchorY = 29, bob = 2 },
  },
  profiles = {
    ["006:flight"] = { scale = 3, anchorY = 28 },
    ["009:surf"] = { scale = 3, anchorY = 31 },
    ["059:ground"] = { scale = 2, anchorY = 19 },
    ["073:surf"] = { scale = 3, anchorY = 29 },
    ["115:ground"] = { scale = 3, anchorY = 29 },
    ["130:surf"] = { scale = 4, anchorY = 39 },
    ["131:surf"] = { scale = 3, anchorY = 30 },
    ["142:flight"] = { scale = 3, anchorY = 28 },
    ["143:ground"] = { scale = 3, anchorY = 29 },
    ["144:flight"] = { scale = 3, anchorY = 28 },
    ["145:flight"] = { scale = 3, anchorY = 28 },
    ["146:flight"] = { scale = 3, anchorY = 28 },
    ["148:flight"] = { scale = 3, anchorY = 28 },
    ["149:flight"] = { scale = 3, anchorY = 28 },
    ["160:surf"] = { scale = 3, anchorY = 30 },
    ["226:surf"] = { scale = 3, anchorY = 29 },
    ["230:surf"] = { scale = 3, anchorY = 30 },
    ["245:ground"] = { scale = 3, anchorY = 29 },
    ["245:surf"] = { scale = 3, anchorY = 28, bob = 1 },
    ["248:ground"] = { scale = 3, anchorY = 29 },
    ["249:surf"] = { scale = 4, anchorY = 39 },
    ["249:flight"] = { scale = 4, anchorY = 38 },
    ["250:flight"] = { scale = 4, anchorY = 38 },
  },
}

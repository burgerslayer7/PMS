-- Shared Gen1/Gen2 START-menu browser built only on the public mod.ui surface.

local MountMenu = {}
MountMenu.__index = MountMenu

local SCREEN = "PMSMounts"
local MODES = {
  { id = "ground", label = "GROUND" },
  { id = "surf", label = "SURF" },
  { id = "flight", label = "FLIGHT" },
}

local function displaySpecies(value)
  return tostring(value or "--"):gsub("_", "-")
end

function MountMenu.new(opts)
  assert(type(opts) == "table", "mount menu options required")
  return setmetatable(opts, MountMenu)
end

function MountMenu:_message(game, value)
  local ui = self.mod and self.mod.ui
  if ui and ui.TextBox and game and game.stack then
    game.stack:push(ui.TextBox.new(game, tostring(value or
      "Mount action failed.")))
  elseif self.log then
    self.log:warn("Menu", "%s", tostring(value))
  end
end

function MountMenu:_items()
  local status = self.system:snapshot()
  local items = {}
  for _, mode in ipairs(MODES) do
    local candidate, err = self.system:modeCandidate(mode.id)
    items[#items + 1] = {
      label = mode.label,
      right = candidate and displaySpecies(candidate.species) or "--",
      value = mode.id,
      error = err,
      muted = candidate == nil,
    }
  end
  items[#items + 1] = {
    label = "DISMOUNT",
    right = status.state ~= "UNMOUNTED"
      and displaySpecies(status.species) or "--",
    value = "dismount",
    muted = status.state == "UNMOUNTED",
  }
  return items, status
end

function MountMenu:screen(game)
  local items, status = self:_items()
  local current = status.state == "UNMOUNTED" and "ON FOOT"
    or ("RIDING " .. displaySpecies(status.species))
  return self.mod.ui.ListMenu.new(game, "MOUNTS", items, {
    kind = "pms_mounts",
    wrap = true,
    footer = current,
    onChoose = function(item, menu)
      local ok, err
      if item.value == "dismount" then
        ok, err = self.system:menuDismount()
      else
        ok, err = self.system:activateMode(item.value)
      end
      if ok then menu:close() else self:_message(game, err or item.error) end
    end,
  })
end

function MountMenu:register()
  local screens = self.mod and self.mod.content and self.mod.content.screens
  if not (screens and type(screens.register) == "function") then
    return nil, "screens registry unavailable"
  end
  local owner = self
  screens:register(SCREEN, { new = function(game) return owner:screen(game) end })
  return true
end

function MountMenu:decorate(next, game, items)
  local out = next(game, items)
  if type(out) ~= "table" then return out end
  return self.mod.ui.insertBefore(out, "SAVE", {
    label = "MOUNTS",
    desc = { "Ride a", "Pokémon" },
    onSelect = function() self.mod.ui.push(game, SCREEN) end,
  })
end

return MountMenu

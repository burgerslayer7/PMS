local PartyActions = {}
PartyActions.__index = PartyActions

local MODE_ORDER = { "ground", "surf", "flight" }
local MODE_LABEL = {
  ground = "GROUND RIDE",
  surf = "VISIBLE SURF",
  flight = "FLIGHT",
}

function PartyActions.new(opts)
  return setmetatable({
    mod = opts.mod,
    catalog = opts.catalog,
    system = opts.system,
    adapter = opts.adapter,
    log = opts.log,
  }, PartyActions)
end

function PartyActions:_message(game, text)
  local ui = self.mod and self.mod.ui
  local stack = game and game.stack
  if ui and ui.TextBox and stack and stack.push then
    stack:push(ui.TextBox.new(game, tostring(text or "Mount action failed.")))
  elseif self.log then
    self.log:warn("UI", "%s", tostring(text))
  end
end

function PartyActions:_closeParty(game)
  local stack = game and game.stack
  if not (stack and stack.top and stack.pop) then return false end
  if stack:top() then stack:pop() return true end
  return false
end

function PartyActions:_activate(game, mon, mount, mode)
  self:_closeParty(game)
  local ok, err = self.system:mount(mount.dex, mode, {
    mon = mon,
    partySlot = self.adapter:partySlot(mon),
    partyFingerprint = self.adapter:fingerprint(mon),
  })
  if not ok then self:_message(game, err) end
end

function PartyActions:_dismount(game)
  self:_closeParty(game)
  local ok, err = self.system:dismount("party-menu")
  if not ok then self:_message(game, err) end
end

function PartyActions:_modeItems(game, mon, mount)
  local items = {}
  local status = self.system:snapshot()
  if status.state ~= "UNMOUNTED" then
    items[#items + 1] = {
      label = "DISMOUNT",
      onSelect = function() self:_dismount(game) end,
    }
  end
  for _, mode in ipairs(MODE_ORDER) do
    if mount.modes[mode] then
      items[#items + 1] = {
        label = MODE_LABEL[mode],
        onSelect = function() self:_activate(game, mon, mount, mode) end,
      }
    end
  end
  return items
end

function PartyActions:_choose(game, mon, mount)
  local items = self:_modeItems(game, mon, mount)
  if #items == 1 and items[1].label ~= "DISMOUNT" then
    items[1].onSelect()
    return
  end
  local ui, stack = self.mod and self.mod.ui, game and game.stack
  if not (ui and ui.Menu and stack and stack.push) then
    self:_message(game, "Mount menu unavailable.")
    return
  end
  stack:push(ui.Menu.new(game, items, {
    tx = 5,
    ty = math.max(0, 16 - (#items * 2 + 2)),
    tw = 15,
    title = "MOUNT",
  }))
end

function PartyActions:decorate(next, game, items, mon, ctx)
  items = next(game, items, mon, ctx)
  if type(items) ~= "table" or (ctx and ctx.battle)
      or type(mon) ~= "table" or mon.isEgg or mon.egg then return items end
  local mount = self.catalog:get(mon.species)
  if not mount then return items end
  local row = {
    id = "PMS_MOUNT",
    label = "MOUNT",
    onSelect = function(selected, liveGame)
      self:_choose(liveGame or game, selected or mon, mount)
    end,
  }
  local ui = self.mod and self.mod.ui
  if ui and type(ui.insertBefore) == "function" then
    ui.insertBefore(items, "CANCEL", row)
  else
    items[#items + 1] = row
  end
  return items
end

return PartyActions

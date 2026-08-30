return function(T, V)
  local Settings = V.require("core/Settings")
  local MountMenu = V.require("ui/MountMenu")

  T:test("settings expose simple and advanced runtime controls", function()
    local schema
    local settings = Settings.new({ options = {
      define = function(_, rows) schema = rows end,
      get = function() return nil end,
    } })
    T:ok(settings:register())
    local byKey = {}
    for _, row in ipairs(schema) do byKey[row.key] = row end
    T:eq(byKey.settings_view.default, "simple")
    T:eq(byKey.shortcuts_enabled.default, true)
    T:eq(byKey.sprint_enabled.default, true)
    T:eq(byKey.show_rider.default, true)
    T:eq(byKey.show_shadow.visible_if.equals, "advanced")
    T:eq(byKey.flight_vertical_speed.visible_if.key, "settings_view")
    T:eq(byKey.mount_size_overrides.maxLen, 160)
  end)

  T:test("size settings preserve Pokédex defaults and clamp overrides",
    function()
      local values = { mount_scale = "large",
        mount_size_overrides = "59=1.25, 131=0.8; 250=9" }
      local settings = Settings.new({ options = { get = function(_, key)
        return values[key]
      end } })
      T:eq(settings:mountScale(6), 1.15)
      T:eq(settings:mountScale(59), 1.4375)
      T:ok(math.abs(settings:mountScale(131) - 0.92) < 0.000001)
      T:eq(settings:mountScale(250), 2)
      values.mount_size_overrides = "59=0.1"
      T:ok(math.abs(settings:mountScale(59) - 0.575) < 0.000001)
    end)

  T:test("START MOUNTS screen lists candidates and dispatches actions",
    function()
      local registered, pushed, selected
      local ui = {}
      ui.insertBefore = function(items, anchor, item)
        T:eq(anchor, "SAVE")
        table.insert(items, 2, item)
        return items
      end
      ui.push = function(_, id) pushed = id end
      ui.ListMenu = { new = function(_, title, items, opts)
        return { title = title, items = items, opts = opts,
          close = function(self) self.closed = true end }
      end }
      ui.TextBox = { new = function(_, text) return { text = text } end }
      local mod = {
        ui = ui,
        content = { screens = { register = function(_, id, def)
          registered = { id = id, def = def }
        end } },
      }
      local system = {
        snapshot = function()
          return { state = "UNMOUNTED" }
        end,
        modeCandidate = function(_, mode)
          local species = ({ ground = "ARCANINE", surf = "LAPRAS",
            flight = "HO_OH" })[mode]
          return { species = species, mode = mode }
        end,
        activateMode = function(_, mode) selected = mode return true end,
        menuDismount = function() selected = "dismount" return true end,
      }
      local menu = MountMenu.new({ mod = mod, system = system })
      T:ok(menu:register())
      T:eq(registered.id, "PMSMounts")
      local game = { stack = { push = function() end } }
      local rows = menu:decorate(function(_, items) return items end, game,
        { { label = "POKéMON" }, { label = "SAVE" } })
      T:eq(rows[2].label, "MOUNTS")
      rows[2].onSelect()
      T:eq(pushed, "PMSMounts")
      local screen = registered.def.new(game)
      T:eq(screen.title, "MOUNTS")
      T:eq(screen.items[1].right, "ARCANINE")
      T:eq(screen.items[3].right, "HO-OH")
      screen.opts.onChoose(screen.items[3], screen)
      T:eq(selected, "flight")
      T:eq(screen.closed, true)
    end)
end

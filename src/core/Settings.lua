local Settings = {}
Settings.__index = Settings

local DEFAULTS = {
  require_progression = true,
  auto_remount_after_battle = true,
  preferred_renderer = "auto",
  ground_speed = "normal",
  flight_speed = "normal",
  debug_mode = false,
}

function Settings.new(mod)
  return setmetatable({ mod = mod, defaults = DEFAULTS }, Settings)
end

function Settings:register()
  local options = self.mod and self.mod.options
  if not (options and type(options.define) == "function") then return false end
  options:define({
    {
      key = "require_progression", type = "toggle",
      label = "PROGRESSION", default = DEFAULTS.require_progression,
      help = "Require the active game's Surf/Fly progression rules.",
    },
    {
      key = "auto_remount_after_battle", type = "toggle",
      label = "AUTO REMOUNT", default = DEFAULTS.auto_remount_after_battle,
      help = "Restore the current mount after a battle when still valid.",
    },
    {
      key = "preferred_renderer", type = "choice",
      label = "MOUNT RENDERER", default = DEFAULTS.preferred_renderer,
      choices = {
        { "AUTO", "auto" }, { "NATIVE 2D", "native2d" },
        { "VOXEL", "voxel" }, { "STADIUM", "stadium" },
      },
      help = "AUTO selects the healthiest provider for the active renderer.",
    },
    {
      key = "ground_speed", type = "choice",
      label = "GROUND SPEED", default = DEFAULTS.ground_speed,
      choices = { { "NORMAL", "normal" }, { "FAST", "fast" } },
    },
    {
      key = "flight_speed", type = "choice",
      label = "FLIGHT SPEED", default = DEFAULTS.flight_speed,
      choices = {
        { "NORMAL", "normal" }, { "FAST", "fast" },
        { "TURBO", "turbo" },
      },
    },
    {
      key = "debug_mode", type = "toggle",
      label = "DEBUG HUD", default = DEFAULTS.debug_mode,
    },
  })
  return true
end

function Settings:get(key)
  local fallback = self.defaults[key]
  local options = self.mod and self.mod.options
  if not (options and type(options.get) == "function") then return fallback end
  local ok, value = pcall(options.get, options, key)
  if not ok or value == nil then return fallback end
  return value
end

function Settings:snapshot()
  local out = {}
  for key in pairs(self.defaults) do out[key] = self:get(key) end
  return out
end

return Settings

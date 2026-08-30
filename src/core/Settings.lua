local Settings = {}
Settings.__index = Settings

local DEFAULTS = {
  settings_view = "simple",
  require_progression = true,
  auto_remount_after_battle = true,
  preferred_renderer = "auto",
  sprite_source = "auto",
  ground_speed = "normal",
  flight_speed = "normal",
  flight_vertical_speed = "normal",
  motion_personality = true,
  sprint_enabled = true,
  reverse_ledges = true,
  shortcuts_enabled = true,
  show_rider = true,
  show_shadow = true,
  air_encounters = true,
  mount_scale = "normal",
  mount_size_overrides = "",
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
      key = "settings_view", type = "choice",
      label = "SETTINGS VIEW", default = DEFAULTS.settings_view,
      choices = { { "SIMPLE", "simple" }, { "ADVANCED", "advanced" } },
    },
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
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "sprite_source", type = "choice",
      label = "MOUNT SPRITES", default = DEFAULTS.sprite_source,
      choices = {
        { "AUTO", "auto" },
        { "PMS BUILTIN", "builtin" },
        { "WILDS SELECTED", "wilds" },
      },
      help = "AUTO follows a compatible sprite provider. PMS BUILTIN forces the bundled art. WILDS SELECTED follows Wilds of Kanto's current Sprite Style.",
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "ground_speed", type = "choice",
      label = "GROUND SPEED", default = DEFAULTS.ground_speed,
      choices = { { "NORMAL", "normal" }, { "FAST", "fast" } },
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "flight_speed", type = "choice",
      label = "FLIGHT SPEED", default = DEFAULTS.flight_speed,
      choices = {
        { "NORMAL", "normal" }, { "FAST", "fast" },
        { "TURBO", "turbo" },
      },
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "flight_vertical_speed", type = "choice",
      label = "VERTICAL SPEED", default = DEFAULTS.flight_vertical_speed,
      choices = {
        { "GENTLE", "gentle" }, { "NORMAL", "normal" },
        { "FAST", "fast" },
      },
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "motion_personality", type = "toggle",
      label = "MOUNT MOMENTUM", default = DEFAULTS.motion_personality,
      help = "Use species profiles for launch, acceleration and turns.",
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "sprint_enabled", type = "toggle",
      label = "SPRINT / BOOST", default = DEFAULTS.sprint_enabled,
    },
    {
      key = "reverse_ledges", type = "toggle",
      label = "TWO-WAY LEDGES", default = DEFAULTS.reverse_ledges,
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "shortcuts_enabled", type = "toggle",
      label = "MOUNT SHORTCUTS", default = DEFAULTS.shortcuts_enabled,
    },
    {
      key = "show_rider", type = "toggle",
      label = "SHOW RIDER", default = DEFAULTS.show_rider,
    },
    {
      key = "show_shadow", type = "toggle",
      label = "FLIGHT SHADOW", default = DEFAULTS.show_shadow,
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "mount_scale", type = "choice",
      label = "GLOBAL MOUNT SIZE", default = DEFAULTS.mount_scale,
      choices = {
        { "SMALL", "small" }, { "POKéDEX", "normal" },
        { "LARGE", "large" },
      },
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "mount_size_overrides", type = "text",
      label = "DEX SIZE OVERRIDES", default = DEFAULTS.mount_size_overrides,
      maxLen = 160,
      help = "Optional Dex multipliers, for example 59=1.1,131=0.9.",
      visible_if = { key = "settings_view", equals = "advanced" },
    },
    {
      key = "air_encounters", type = "toggle",
      label = "AIR ENCOUNTERS", default = DEFAULTS.air_encounters,
      help = "Allow exact encounters with nearby Wild Skies flyers.",
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

local GLOBAL_SCALE = { small = 0.85, normal = 1, large = 1.15 }

function Settings:_sizeOverrides()
  local source = tostring(self:get("mount_size_overrides") or "")
  if self.sizeOverrideSource == source then return self.sizeOverrideCache end
  local parsed = {}
  for dex, multiplier in string.gmatch(source,
      "(%d+)%s*=%s*([%d]*%.?[%d]+)") do
    dex, multiplier = tonumber(dex), tonumber(multiplier)
    if dex and dex >= 1 and dex <= 251 and multiplier then
      parsed[dex] = math.max(0.5, math.min(2, multiplier))
    end
  end
  self.sizeOverrideSource = source
  self.sizeOverrideCache = parsed
  return parsed
end

function Settings:mountScale(dex)
  local global = GLOBAL_SCALE[self:get("mount_scale")] or 1
  local species = self:_sizeOverrides()[tonumber(dex)] or 1
  return math.max(0.5, math.min(2, global * species))
end

return Settings

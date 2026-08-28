local TechnicalFallbackProvider = {}

function TechnicalFallbackProvider.new(catalog, log)
  return {
    api = 1,
    id = "technical_fallback",
    priority = -10000,
    probe = function()
      return { available = true, kind = "technical", renderer = "native2d" }
    end,
    resolve = function(_, dex, mode)
      if not catalog:supports(dex, mode) then return nil, "unknown mount" end
      return {
        kind = "technical",
        renderer = "native2d",
        dex = dex,
        mode = mode,
        visible = false,
      }
    end,
    begin = function(_, resolved)
      if log then
        log:once("technical-fallback", "warn", "Provider",
          "technical fallback active for dex %03d; mount art is unavailable",
          resolved.dex)
      end
      return { resolved = resolved }
    end,
    finish = function() return true end,
  }
end

return TechnicalFallbackProvider

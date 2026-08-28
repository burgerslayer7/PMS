local Subscriptions = {}
Subscriptions.__index = Subscriptions

function Subscriptions.new(log)
  return setmetatable({ entries = {}, log = log }, Subscriptions)
end

function Subscriptions:add(unsubscribe)
  if type(unsubscribe) ~= "function" then return false end
  self.entries[#self.entries + 1] = unsubscribe
  return true
end

function Subscriptions:clear()
  local okAll = true
  for index = #self.entries, 1, -1 do
    local ok, err = pcall(self.entries[index])
    if not ok then
      okAll = false
      if self.log then
        self.log:warn("Cleanup", "unsubscribe failed: %s", tostring(err))
      end
    end
    self.entries[index] = nil
  end
  return okAll
end

return Subscriptions

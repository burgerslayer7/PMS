return function(T, V)
  local RuntimeAdapter = V.require("game/RuntimeAdapter")
  local MountIdentity = V.require("game/MountIdentity")

  T:test("mount fingerprint survives level changes and legacy saves", function()
    local mon = {
      species = "ARCANINE", nickname = "Flame", level = 30,
      personality = 7, dvs = { attack = 1, defense = 2 }, hp = 80,
    }
    local adapter = RuntimeAdapter.new()
    local stable = adapter:fingerprint(mon)
    mon.level = 31
    T:eq(adapter:fingerprint(mon), stable)
    T:ok(adapter:fingerprintMatches(mon, "ARCANINE|Flame|30|7|1|2"))
  end)

  T:test("mount identity follows the same Pokemon after party reorder", function()
    local arcanine = {
      species = "ARCANINE", personality = 7,
      dvs = { attack = 1, defense = 2 }, hp = 80,
    }
    local pikachu = { species = "PIKACHU", personality = 9, hp = 20 }
    local party = { arcanine, pikachu }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ game = { save = { party = party } } })
    local identity = MountIdentity.new(adapter)
    local captured = identity:capture(arcanine, 1)
    party[1], party[2] = party[2], party[1]
    local resolved, slot = identity:resolve(captured)
    T:eq(resolved, arcanine)
    T:eq(slot, 2)
  end)

  T:test("mount identity rejects a fainted or removed Pokemon", function()
    local arcanine = { species = "ARCANINE", personality = 7, hp = 0 }
    local party = { arcanine }
    local adapter = RuntimeAdapter.new()
    adapter:bind({ game = { save = { party = party } } })
    local identity = MountIdentity.new(adapter)
    local captured = identity:capture(arcanine, 1)
    local resolved, fainted = identity:resolve(captured)
    T:eq(resolved, nil)
    T:matches(fainted, "fainted")
    arcanine.hp = 20
    party[1] = nil
    local missing, removed = identity:resolve(captured)
    T:eq(missing, nil)
    T:matches(removed, "no longer")
  end)
end

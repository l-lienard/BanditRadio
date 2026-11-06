"""Tests hors jeu de Bandit Radio (pip install lupa).

1. Vérifie la syntaxe de tous les fichiers Lua du mod.
2. Simule une partie : un groupe part de Muldraugh vers West Point, pille,
   se fait déborder par des zombies, un autre clan l'attaque, un groupe
   se rapproche du joueur... et affiche les messages radio générés.
"""
import glob
import os

try:
    from lupa import lua51 as L
except ImportError:
    import lupa as L

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                                     "Contents", "mods", "BanditRadio", "42", "media", "lua")) + "/"
lua = L.LuaRuntime()

# 1. Syntaxe -----------------------------------------------------------------
check = lua.eval("function(s, n) local f, e = loadstring(s, n); return e end")
errors = 0
for f in sorted(glob.glob(ROOT + "**/*.lua", recursive=True)):
    err = check(open(f, encoding="utf-8").read(), f)
    print(("OK  " if err is None else "ERR ") + f.replace(ROOT, ""), err or "")
    errors += err is not None

# 2. Simulation ---------------------------------------------------------------
lua.execute('package.path = "' + ROOT + 'shared/?.lua;" .. package.path')
lua.execute('''
Translator = { getLanguage = function() return { name = function() return "FR" end } end }
SandboxVars = { BanditRadio = { AmbientChance = 0, FalseRumors = 0, Reliability = 1 } }
math.randomseed(1)
require "BanditRadio/BR_Config"
require "BanditRadio/BR_Messages"
require "BanditRadio/BR_Intel"
require "BanditRadio/BR_API"
''')
run = lua.eval('''function(lang)
  BanditRadio.langOverride = lang
  local I = BanditRadio.Intel
  local st = I.newState()
  local out = {}
  local function band(prefix, clan, x, y, n, extra)
    local t = {}
    for i = 1, n do
      local b = { id = prefix .. i, x = x + i, y = y, clan = clan, clanName = clan,
        weapon = (i % 2 == 0) and "fire" or "melee", hostile = true }
      if extra then for k, v in pairs(extra) do b[k] = v end end
      t[#t + 1] = b
    end
    return t
  end
  local function merge(...) local t = {} for _, l in ipairs({...}) do for _, v in ipairs(l) do t[#t+1] = v end end return t end
  local player = { { name = "Lorenzo", x = 8200, y = 11400 } }
  local steps = {
    -- 1. Milice à Muldraugh dans une station-service, Criminels au sud de Rosewood
    { b = merge(band("m", "12_Militia", 10650, 9700, 5, { room = "gasstore" }), band("c", "3_Criminals", 8150, 12100, 4)) },
    -- 2. la Milice part vers West Point ; les Criminels marchent vers le joueur
    { b = merge(band("m", "12_Militia", 10900, 9250, 5), band("c", "3_Criminals", 8150, 11900, 4)) },
    -- 3. Milice continue en véhicule ; Criminels toujours plus près
    { b = merge(band("m", "12_Militia", 11150, 8800, 5, { vehicle = true }), band("c", "3_Criminals", 8150, 11700, 4)) },
    -- 4. Milice arrivée, pille un supermarché ; Criminels traquent Lorenzo
    { b = merge(band("m", "12_Militia", 11150, 8800, 5, { room = "grocery" }), band("c", "3_Criminals", 8160, 11500, 4, { target = "Lorenzo", targetType = "player" })) },
    -- 5. Horde sur la Milice : combat + pertes ; un 3e clan l'attaque
    { b = merge(band("m", "12_Militia", 11150, 8800, 2, { targetType = "zombie" }), band("b", "7_Bikers", 11180, 8800, 3, { targetType = "bandit", targetClan = "12_Militia" })),
      z = { ["557,440"] = 12 } },
    -- 6. plus rien de la Milice
    { b = band("b", "7_Bikers", 11180, 8800, 3) },
    { b = band("b", "7_Bikers", 11180, 8800, 3) },
  }
  for s, step in ipairs(steps) do
    local reps = I.update(st, { bandits = step.b, zgrid = step.z or {}, players = player }, s * 30, 30)
    for _, r in ipairs(reps) do out[#out + 1] = "scan " .. s .. "  " .. (I.formatReport(r)) end
  end
  -- Niveaux de détail pour un même événement
  local r = { kind = "loot", clanName = "12_Militia", x = 10650, y = 9700, n = 5, room = "gasstore", seed = 1 }
  for _, lvl in ipairs({ "full", "partial", "rumor" }) do out[#out + 1] = "niveau " .. lvl .. " : " .. (I.formatReport(r, lvl)) end
  return table.concat(out, "\\n")
end''')
for lang in ("FR", "EN"):
    print("\n--- " + lang + " ---")
    print(run(lang))

if errors:
    raise SystemExit(f"{errors} syntax error(s)")

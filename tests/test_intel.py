import glob, sys
try:
    from lupa import lua51 as L
except ImportError:
    import lupa as L
lua = L.LuaRuntime()
print(lua.eval('_VERSION'))
import os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Contents")
root = os.path.normpath(root) + "/mods/BanditRadio/42/media/lua/"
# 1. syntax check every file
for f in sorted(glob.glob(root + "**/*.lua", recursive=True)):
    src = open(f, encoding="utf-8").read()
    r = lua.execute("return function(s, n) local f, e = loadstring and loadstring(s, n) or load(s, n); return e end")(src, f)
    print("OK " if r is None else "ERR", f.replace(root, ""), r or "")
# 2. run pure logic with stubs
lua.execute('''
package.path = "''' + root + '''shared/?.lua;" .. package.path
Translator = { getLanguage = function() return { name = function() return "FR" end } end }
SandboxVars = { BanditRadio = { ExactCoordinates = false } }
require "BanditRadio/BR_Config"
require "BanditRadio/BR_Intel"
''')
run = lua.eval('''function()
  local I = BanditRadio.Intel
  local st = I.newState()
  local out = {}
  local function band(clan, x, y, n, tgt) local t = {} for i=1,n do t[#t+1] = {x=x+i, y=y, clan=clan, clanName="Ravens", weapon=(i%2==0) and "fire" or "melee", target=tgt, activity="Bandit", hostile=true} end return t end
  local function merge(a,b) local t={} for _,v in ipairs(a) do t[#t+1]=v end for _,v in ipairs(b) do t[#t+1]=v end return t end
  -- group A walks from (10650,8800) south toward Muldraugh (10650,9700); group B static near Rosewood
  local steps = { 8800, 8860, 8920, 8980, 9040 }
  for s, y in ipairs(steps) do
    local nA = (s >= 4) and 3 or 5
    local b = merge(band("c1", 10640, y, nA), band("c2", 8150, 11500, 4))
    if s == 5 then b = band("c1", 10640, y, nA, "Lorenzo") end
    local reps = I.update(st, b, s*30, 30)
    for _, r in ipairs(reps) do out[#out+1] = "scan"..s..": "..I.formatReport(r) end
  end
  for i=6,8 do local reps = I.update(st, {}, i*30, 30) for _, r in ipairs(reps) do out[#out+1] = "scan"..i..": "..I.formatReport(r) end end
  for _, f in ipairs(I.snapshotFactions(st)) do out[#out+1] = "faction "..f.name.." members="..f.members.." losses="..f.losses.." fire="..f.fire end
  return table.concat(out, "\\n")
end''')
print(run())

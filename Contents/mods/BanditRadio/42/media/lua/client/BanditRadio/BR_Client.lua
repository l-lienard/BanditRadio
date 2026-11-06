-- Bandit Radio - côté client : état de la radio, pile, réception des rapports
--
-- Deux modes :
--   * Radio ALLUMÉE  -> les messages s'affichent en direct au-dessus du joueur
--                       (comme une radio portable vanilla) + sont enregistrés.
--   * Radio ÉTEINTE  -> si le joueur porte une radio, les messages captés sont
--                       enregistrés comme "manqués" et consultables dans l'interface.

require "BanditRadio/BR_Config"
require "BanditRadio/BR_Intel"
require "BanditRadio/BR_API"
require "BanditRadio/BR_Map"

BanditRadio.Client = BanditRadio.Client or {}
local C = BanditRadio.Client

C.MAX_FEED = 80
C.OVERHEAD_DELAY_MS = 3500   -- délai entre deux messages au-dessus du joueur
C.active = nil        -- l'objet radio allumé
C.lastItem = nil      -- dernière radio utilisée (bouton ON/OFF de l'interface)
C.feed = {}           -- { {time=, text=, clarity=, kind=, missed=} }
C.factions = {}       -- fiches de faction à portée
C.unread = 0          -- messages captés radio éteinte, pas encore lus
C.lastPacket = nil
C.overheadQueue = {}
C.nextOverheadMs = 0

---------------------------------------------------------------------------
-- Pile (stockée dans le modData de l'objet, 0..100)
---------------------------------------------------------------------------
function C.getCharge(item)
    local md = item:getModData()
    if md.BR_charge == nil then md.BR_charge = 100 end
    return md.BR_charge
end

function C.setCharge(item, v)
    item:getModData().BR_charge = math.max(0, math.min(100, v))
end

local function isCarried(player, item)
    local inv = player:getInventory()
    local c = item:getContainer()
    local guard = 0
    while c and guard < 10 do
        if c == inv then return true end
        local parent = c:getContainingItem()
        c = parent and parent:getContainer() or nil
        guard = guard + 1
    end
    return false
end

function C.findCarriedRadio(player)
    if C.active and isCarried(player, C.active) then return C.active end
    if C.lastItem and isCarried(player, C.lastItem) then return C.lastItem end
    return player:getInventory():getFirstTypeRecurse(BanditRadio.ITEM)
end

local function refreshWindow()
    if BanditRadio.Window and BanditRadio.Window.instance then BanditRadio.Window.instance:refresh() end
end

function C.isListening()
    return C.active ~= nil
end

function C.start(player, item)
    if C.getCharge(item) <= 0 or item:isBroken() then
        player:Say(BanditRadio.T("no_battery"))
        return
    end
    C.active = item
    C.lastItem = item
    if C.lastPacket then C.refreshFactions(C.lastPacket) end
    C.showOverhead(player, BanditRadio.T("on") .. " ...kzzt...", BanditRadio.colorFor("default"))
    refreshWindow()
end

function C.stop()
    C.active = nil
    C.overheadQueue = {}
    refreshWindow()
end

function C.openLog(item)
    if item then C.lastItem = item end
    C.unread = 0
    BanditRadio.Window.open()
end

function C.replaceBattery(player, item)
    local inv = player:getInventory()
    local battery = inv:getFirstTypeRecurse("Base.Battery") or inv:getFirstTypeRecurse("Battery")
    if not battery then return end
    battery:getContainer():Remove(battery)
    C.setCharge(item, 100)
    player:Say(BanditRadio.T("battery") .. " 100%")
    refreshWindow()
end

local function onEveryMinute()
    local item = C.active
    if not item then return end
    local player = getPlayer()
    if not player or player:isDead() or not isCarried(player, item) or item:isBroken() then
        C.stop()
        return
    end
    local drain = 100 / (BanditRadio.opt("BatteryHours") * 60)
    C.setCharge(item, C.getCharge(item) - drain)
    if C.getCharge(item) <= 0 then
        player:Say(BanditRadio.T("no_battery"))
        C.stop()
    end
end
Events.EveryOneMinute.Add(onEveryMinute)

---------------------------------------------------------------------------
-- Texte au-dessus du joueur (comme une radio portable vanilla)
---------------------------------------------------------------------------
function C.showOverhead(player, text, col)
    local ok = pcall(function()
        player:addLineChatElement(BanditRadio.T("overhead") .. text, col.r, col.g, col.b)
    end)
    if not ok then player:Say(BanditRadio.T("overhead") .. text) end
end

-- File d'attente : un message toutes les ~3,5 s pour qu'ils ne se recouvrent pas
local function onTick()
    if #C.overheadQueue == 0 then return end
    local now = getTimestampMs()
    if now < C.nextOverheadMs then return end
    local player = getPlayer()
    if not player or not C.active then C.overheadQueue = {} return end
    local msg = table.remove(C.overheadQueue, 1)
    C.showOverhead(player, msg.text, msg.col)
    C.nextOverheadMs = now + C.OVERHEAD_DELAY_MS
end
Events.OnTick.Add(onTick)

---------------------------------------------------------------------------
-- Brouillage : plus c'est loin, plus le message est haché
---------------------------------------------------------------------------
function C.clarity(d, range)
    local c = 1 - (d / range) ^ 2
    if c < 0 then c = 0 end
    return c
end

-- Note : dans Kahlua (Lua de PZ) les chaînes sont des String Java,
-- string.sub découpe donc par caractère, accents compris.
function C.garble(text, clarity)
    if not BanditRadio.opt("Static") or clarity >= 0.85 then return text end
    local noise = (1 - clarity) * 0.55
    local out = {}
    local tagEnd = string.find(text, "]", 1, true) or 0   -- ne pas hacher le nom de faction
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        if i > tagEnd and ch ~= " " and ZombRandFloat(0, 1) < noise then
            ch = (ZombRand(3) == 0) and "~" or "."
        end
        out[#out + 1] = ch
    end
    local s = table.concat(out)
    if clarity < 0.4 then s = s .. " *kzzt*" end
    return s
end

-- Texte d'une entrée du journal dans la langue courante.
-- Le brouillage est tiré une seule fois par langue (pas de clignotement).
function C.entryText(e)
    local lang = BanditRadio.lang()
    if not e.cache[lang] then
        e.cache[lang] = C.garble((BanditRadio.Intel.formatReport(e.r, e.level)), e.clarity)
    end
    return e.cache[lang]
end

---------------------------------------------------------------------------
-- Choix de la langue (AUTO -> FR -> EN), sauvegardé dans Zomboid/Lua/
---------------------------------------------------------------------------
C.LANG_FILE = "BanditRadio_settings.txt"
C.LANG_CYCLE = { [""] = "FR", FR = "EN", EN = "" }

function C.saveLanguage()
    pcall(function()
        local w = getFileWriter(C.LANG_FILE, true, false)
        w:write("lang=" .. (BanditRadio.langOverride or "") .. "\r\n")
        w:write("map=" .. (BanditRadio.Map.enabled and "1" or "0") .. "\r\n")
        w:close()
    end)
end

function C.loadLanguage()
    pcall(function()
        local r = getFileReader(C.LANG_FILE, false)
        if not r then return end
        local line = r:readLine()
        while line do
            local code = string.match(line, "^lang=(%a*)")
            if code and code ~= "" and BanditRadio.Strings[code] then BanditRadio.langOverride = code end
            local map = string.match(line, "^map=(%d)")
            if map then BanditRadio.Map.enabled = (map == "1") end
            line = r:readLine()
        end
        r:close()
    end)
end

function C.cycleLanguage()
    local nxt = C.LANG_CYCLE[BanditRadio.langOverride or ""] or ""
    BanditRadio.langOverride = (nxt ~= "") and nxt or nil
    C.saveLanguage()
    refreshWindow()
end
Events.OnGameStart.Add(C.loadLanguage)

function C.toggleMap()
    BanditRadio.Map.enabled = not BanditRadio.Map.enabled
    C.saveLanguage()
    refreshWindow()
end

---------------------------------------------------------------------------
-- Réception des paquets du serveur
---------------------------------------------------------------------------
local function distTo(player, x, y)
    return math.sqrt((player:getX() - x) ^ 2 + (player:getY() - y) ^ 2)
end

local function clockString()
    local gt = getGameTime()
    return string.format("J%d %02d:%02d", gt:getNightsSurvived() + 1, gt:getHour(), gt:getMinutes())
end

function C.refreshFactions(packet)
    local player = getPlayer()
    if not player then return end
    local range = BanditRadio.opt("Range")
    local list = {}
    for _, f in ipairs(packet.factions or {}) do
        local inRange = false
        for _, p in ipairs(f.positions or {}) do
            if distTo(player, p.x, p.y) <= range then inRange = true break end
        end
        if not inRange and f.lastX and distTo(player, f.lastX, f.lastY) <= range then inRange = true end
        if inRange then list[#list + 1] = f end
    end
    table.sort(list, function(a, b) return (a.members or 0) > (b.members or 0) end)
    C.factions = list
end

function C.onIntel(packet)
    C.lastPacket = packet
    local player = getPlayer()
    if not player or player:isDead() then return end

    local listening = C.active ~= nil
    if not listening then
        -- Radio éteinte : on n'enregistre que si le joueur porte une radio
        if not BanditRadio.opt("LogWhenOff") or not C.findCarriedRadio(player) then return end
    end

    local range = BanditRadio.opt("Range")
    local stamp = clockString()
    for _, r in ipairs(packet.reports or {}) do
        local d = distTo(player, r.x, r.y)
        if d <= range then
            local clarity = C.clarity(d, range)
            -- Signal faible : une info complète n'arrive qu'à moitié
            local level = r.level or "full"
            if clarity < 0.35 and level == "full" then level = "partial" end
            local e = { time = stamp, r = r, level = level, clarity = clarity,
                kind = r.kind, missed = not listening, cache = {} }
            table.insert(C.feed, 1, e)
            BanditRadio.Map.addFromReport(r, level)
            for _, fn in ipairs(BanditRadio.API.listeners) do pcall(fn, r, C.entryText(e)) end
            if listening then
                if BanditRadio.opt("Overhead") then
                    C.overheadQueue[#C.overheadQueue + 1] = { text = C.entryText(e), col = BanditRadio.colorFor(r.kind) }
                end
            else
                C.unread = C.unread + 1
            end
        end
    end
    while #C.feed > C.MAX_FEED do table.remove(C.feed) end
    C.refreshFactions(packet)
    refreshWindow()
end

local function onServerCommand(module, command, args)
    if module == BanditRadio.MODULE and command == "Intel" then C.onIntel(args) end
end
Events.OnServerCommand.Add(onServerCommand)

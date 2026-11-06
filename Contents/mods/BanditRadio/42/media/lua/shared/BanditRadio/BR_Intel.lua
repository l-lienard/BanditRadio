-- Bandit Radio - moteur de renseignement v2 (logique pure, testable hors jeu)
--
-- Entrée : scan = { bandits = {...}, zgrid = {...}, players = {...} } (voir BR_Adapter)
-- Sortie : liste de rapports { kind, level, gid, clan, clanName, x, y, n, ... }
--
-- Événements détectés :
--   contact, move (A -> B + ETA), move_dir, arrive, loot, camp, rest,
--   gunfire, fight_zombies, overrun, clash, hunt, approach,
--   loss, wiped, gone, reinforced, gathering, ambient, + fausses rumeurs
-- D'autres mods peuvent en ajouter via BanditRadio.API.addDetector().

require "BanditRadio/BR_Config"
require "BanditRadio/BR_Messages"

BanditRadio.Intel = BanditRadio.Intel or {}
local I = BanditRadio.Intel

-- Réglages internes (modifiables par d'autres mods)
I.CLUSTER_RADIUS = 40      -- cases : même clan + plus proche = même groupe
I.MATCH_RADIUS = 300       -- cases : distance max pour suivre un groupe d'un scan à l'autre
I.MOVE_MIN = 8             -- cases : en dessous, groupe immobile
I.CONE = math.rad(30)      -- angle max entre le cap et une ville visée
I.TOWN_MIN, I.TOWN_MAX = 150, 3000
I.GONE_AFTER = 2           -- scans sans nouvelles avant "silence"
I.REPEAT_EVERY = 4         -- un même message au plus tous les N scans
I.CAMP_AFTER = 4           -- scans immobile avant "camp"
I.HORDE = 8                -- zombies autour d'un groupe = combat contre les morts
I.APPROACH_RANGE = 800     -- cases : surveillance des groupes qui se rapprochent d'un joueur
I.GATHER_RADIUS, I.GATHER_GROUPS = 500, 3

-- Catégorie de chaque événement (pour les options on/off)
I.CATEGORY = {
    contact = "Movement", move = "Movement", move_dir = "Movement", arrive = "Movement",
    camp = "Movement", rest = "Movement", reinforced = "Movement", gathering = "Movement",
    loot = "Loot",
    gunfire = "Combat", fight_zombies = "Combat", overrun = "Combat", clash = "Combat",
    hunt = "Players", approach = "Players",
    loss = "Losses", wiped = "Losses", gone = "Losses",
    ambient = "Ambient",
}

-- Aléatoire (ZombRand en jeu, math.random hors jeu)
function I.rand(n)
    if n <= 1 then return 0 end
    if ZombRand then return ZombRand(n) end
    return math.random(n) - 1
end

function I.newState()
    return { groups = {}, factions = {}, nextId = 1, scanNo = 0, areaCooldown = {} }
end

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

function I.topKey(t)
    local best, bestN = nil, 0
    for k, n in pairs(t) do
        if n > bestN or (n == bestN and best and tostring(k) < tostring(best)) then best, bestN = k, n end
    end
    return best
end

function I.zombiesNear(grid, x, y)
    if not grid then return 0 end
    local g = BanditRadio.Adapter and BanditRadio.Adapter.GRID or 20
    local gx, gy, total = math.floor(x / g), math.floor(y / g), 0
    for dx = -1, 1 do
        for dy = -1, 1 do total = total + (grid[(gx + dx) .. "," .. (gy + dy)] or 0) end
    end
    return total
end

---------------------------------------------------------------------------
-- 1. Regroupement
---------------------------------------------------------------------------
function I.cluster(bandits)
    local groups = {}
    for _, b in ipairs(bandits) do
        local found = nil
        for _, g in ipairs(groups) do
            if g.clan == b.clan and dist(g.x, g.y, b.x, b.y) <= I.CLUSTER_RADIUS then found = g break end
        end
        if not found then
            found = { clan = b.clan, clanName = b.clanName, sx = 0, sy = 0, count = 0, ids = {},
                fire = 0, melee = 0, vehicle = 0, sleeping = 0, zTargets = 0,
                targets = {}, bTargets = {}, activities = {}, rooms = {}, hostile = nil }
            groups[#groups + 1] = found
        end
        found.count = found.count + 1
        found.sx, found.sy = found.sx + b.x, found.sy + b.y
        found.x, found.y = found.sx / found.count, found.sy / found.count
        if b.id then found.ids[b.id] = true end
        if b.weapon == "fire" then found.fire = found.fire + 1
        elseif b.weapon == "melee" then found.melee = found.melee + 1 end
        if b.vehicle then found.vehicle = found.vehicle + 1 end
        if b.sleeping then found.sleeping = found.sleeping + 1 end
        if b.target then found.targets[b.target] = (found.targets[b.target] or 0) + 1 end
        if b.targetType == "zombie" then found.zTargets = found.zTargets + 1 end
        if b.targetType == "bandit" and b.targetClan and b.targetClan ~= b.clan then
            found.bTargets[b.targetClan] = (found.bTargets[b.targetClan] or 0) + 1
        end
        if b.activity then found.activities[b.activity] = (found.activities[b.activity] or 0) + 1 end
        if b.room then found.rooms[b.room] = (found.rooms[b.room] or 0) + 1 end
        if b.hostile ~= nil then found.hostile = (found.hostile == true) or b.hostile end
    end
    for _, g in ipairs(groups) do
        g.target = I.topKey(g.targets)
        g.enemyClan = I.topKey(g.bTargets)
        g.activity = I.topKey(g.activities)
        g.room = I.topKey(g.rooms)
        g.sx, g.sy, g.targets, g.bTargets, g.activities, g.rooms = nil, nil, nil, nil, nil, nil
    end
    return groups
end

---------------------------------------------------------------------------
-- 2. Destination
---------------------------------------------------------------------------
function I.guessTown(px, py, x, y)
    local hx, hy = x - px, y - py
    local hl = math.sqrt(hx * hx + hy * hy)
    if hl < 0.001 then return nil end
    local best, bestD = nil, nil
    for _, loc in ipairs(BanditRadio.Locations) do
        local tx, ty = loc.x - x, loc.y - y
        local tl = math.sqrt(tx * tx + ty * ty)
        if tl >= I.TOWN_MIN and tl <= I.TOWN_MAX then
            local cosA = (hx * tx + hy * ty) / (hl * tl)
            if cosA > 1 then cosA = 1 elseif cosA < -1 then cosA = -1 end
            local approaching = dist(px, py, loc.x, loc.y) > tl
            if math.acos(cosA) <= I.CONE and approaching and (not bestD or tl < bestD) then
                best, bestD = loc, tl
            end
        end
    end
    return best, bestD
end

---------------------------------------------------------------------------
-- 3. Outils de génération
---------------------------------------------------------------------------
local function enabled(kind)
    local cat = I.CATEGORY[kind]
    if not cat then return true end         -- événements ajoutés par d'autres mods
    return BanditRadio.opt("Ev" .. cat) ~= false
end

-- Niveau de détail selon l'option "Fiabilité"
-- 1 = Complète, 2 = Réaliste, 3 = Rumeurs
function I.rollLevel()
    local mode = BanditRadio.opt("Reliability") or 1
    if mode == 1 then return "full" end
    local r = I.rand(100)
    if mode == 2 then
        if r < 30 then return "full" elseif r < 70 then return "partial" elseif r < 92 then return "rumor" end
        return nil                           -- personne n'en parle
    end
    if r < 45 then return "partial" elseif r < 90 then return "rumor" end
    return nil
end

function I.emit(list, g, kind, extra, forcedLevel)
    if not enabled(kind) then return end
    local level = forcedLevel or I.rollLevel()
    if not level then return end
    local r = { kind = kind, level = level, gid = g.gid, clan = g.clan, clanName = g.clanName,
        x = math.floor(g.x), y = math.floor(g.y), n = g.count, room = g.room, seed = I.rand(1000) }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    list[#list + 1] = r
    return r
end

-- Anti-spam : un type d'événement par groupe au plus tous les `every` scans
local function ready(state, p, kind, every)
    p.cd = p.cd or {}
    local last = p.cd[kind]
    if last and state.scanNo - last < every then return false end
    p.cd[kind] = state.scanNo
    return true
end

---------------------------------------------------------------------------
-- 4. Mise à jour
---------------------------------------------------------------------------
local function overlap(a, b)
    local n = 0
    for id in pairs(a) do if b[id] then n = n + 1 end end
    return n
end

local function nearestPlayer(players, x, y)
    local best, bestD = nil, nil
    for _, pl in ipairs(players or {}) do
        local d = dist(pl.x, pl.y, x, y)
        if not bestD or d < bestD then best, bestD = pl, d end
    end
    return best, bestD
end

local function etaMinutes(d, speed)
    if speed <= 0 then return nil end
    return math.max(5, math.floor(d / speed + 0.5))
end

function I.update(state, scan, now, interval)
    if scan.bandits == nil then scan = { bandits = scan } end   -- compat : liste simple
    state.scanNo = state.scanNo + 1
    interval = math.max(interval or 30, 1)
    local groups = I.cluster(scan.bandits)
    local reports = {}
    local matched = {}

    for _, g in ipairs(groups) do
        -- Suivi : d'abord par membres en commun, sinon par proximité
        local pid, p, bestScore = nil, nil, nil
        for id, prev in pairs(state.groups) do
            if not matched[id] and prev.clan == g.clan then
                local d = dist(prev.x, prev.y, g.x, g.y)
                local common = overlap(g.ids, prev.ids or {})
                if d <= I.MATCH_RADIUS or common > 0 then
                    local score = common * 1000 - d
                    if not bestScore or score > bestScore then pid, p, bestScore = id, prev, score end
                end
            end
        end

        local zn = I.zombiesNear(scan.zgrid, g.x, g.y)
        g.zombies = zn

        if not p then
            pid = state.nextId
            state.nextId = state.nextId + 1
            p = { clan = g.clan, clanName = g.clanName, x = g.x, y = g.y, count = g.count, still = 0 }
            state.groups[pid] = p
            g.gid = pid
            I.emit(reports, g, "contact")
        else
            g.gid = pid
            local moved = dist(p.x, p.y, g.x, g.y)
            local speed = moved / interval                  -- cases / minute
            local vehicle = g.vehicle > 0

            -- Déplacements -------------------------------------------------
            if moved >= I.MOVE_MIN then
                if not p.moving then p.moving, p.ox, p.oy = true, p.x, p.y end
                p.still = 0
                p.speed = speed
                local town, townD = I.guessTown(p.x, p.y, g.x, g.y)
                -- Traverser sa propre ville n'est pas un trajet vers elle
                if town and BanditRadio.placeName(p.ox, p.oy) == town.name then town = nil end
                if town then
                    if p.dest ~= town.name or ready(state, p, "move", I.REPEAT_EVERY) then
                        p.dest = town.name
                        p.cd = p.cd or {}
                        p.cd.move = state.scanNo
                        I.emit(reports, g, "move", { dest = town.name, destX = town.x, destY = town.y,
                            eta = etaMinutes(townD, speed), fx = math.floor(p.ox), fy = math.floor(p.oy),
                            vehicle = vehicle })
                    end
                elseif ready(state, p, "move_dir", I.REPEAT_EVERY) then
                    I.emit(reports, g, "move_dir", { dir = BanditRadio.dirIndex(g.x - p.x, g.y - p.y),
                        vehicle = vehicle, headX = math.floor(g.x + (g.x - p.x) * 4),
                        headY = math.floor(g.y + (g.y - p.y) * 4) })
                end
            else
                if p.moving then
                    p.moving = false
                    I.emit(reports, g, "arrive", { dest = p.dest })
                    p.dest = nil
                end
                p.still = (p.still or 0) + 1
                if g.room and g.room ~= p.lootRoom and g.sleeping == 0 then
                    p.lootRoom = g.room
                    I.emit(reports, g, "loot")
                end
                if p.still == I.CAMP_AFTER then I.emit(reports, g, "camp") end
                if g.sleeping > 0 and ready(state, p, "rest", 6) then I.emit(reports, g, "rest") end
            end

            -- Effectifs ----------------------------------------------------
            if g.count < p.count then
                local lost = p.count - g.count
                p.recentLoss = state.scanNo
                if zn >= I.HORDE and g.count <= math.max(1, math.floor(p.count / 2)) then
                    I.emit(reports, g, "overrun", { lost = lost, left = g.count })
                else
                    I.emit(reports, g, "loss", { lost = lost, left = g.count })
                end
            elseif g.count >= p.count + 2 then
                I.emit(reports, g, "reinforced")
            end

            p.speed = speed
            p.x, p.y, p.count = g.x, g.y, g.count
        end
        -- Combats ------------------------------------------------------
        local engaged = g.target or g.zTargets > 0 or g.enemyClan or zn >= I.HORDE
        if g.fire > 0 and engaged and ready(state, p, "gunfire", 2) then
            I.emit(reports, g, "gunfire")
        end
        if (g.zTargets > 0 or zn >= I.HORDE) and ready(state, p, "fight_zombies", 3) then
            I.emit(reports, g, "fight_zombies", { zombies = zn })
        end
        if g.enemyClan and ready(state, p, "clash", 3) then
            local other = state.factions[g.enemyClan]
            I.emit(reports, g, "clash", { otherName = other and other.name or g.enemyClan, otherClan = g.enemyClan })
        end

        -- Joueurs ------------------------------------------------------
        if g.target then
            if p.hunting ~= g.target or ready(state, p, "hunt", 3) then
                p.hunting = g.target
                p.cd = p.cd or {}
                p.cd.hunt = state.scanNo
                I.emit(reports, g, "hunt", { player = g.target })
            end
        else
            p.hunting = nil
            local pl, d = nearestPlayer(scan.players, g.x, g.y)
            if pl and p.pd and p.pdName == pl.name and d < I.APPROACH_RANGE and d < p.pd - 15
                and ready(state, p, "approach", 3) then
                I.emit(reports, g, "approach", { player = pl.name, eta = etaMinutes(d, p.speed or 0),
                    px = math.floor(pl.x), py = math.floor(pl.y) })
            end
            p.pd, p.pdName = d, pl and pl.name
        end

        p.ids = g.ids
        p.missed = 0
        p.room, p.zombies = g.room, zn
        p.clanName = g.clanName
        matched[pid] = true
    end

    -- Groupes disparus ----------------------------------------------------
    for id, p in pairs(state.groups) do
        if not matched[id] then
            p.missed = (p.missed or 0) + 1
            if p.missed >= I.GONE_AFTER then
                local g = { gid = id, clan = p.clan, clanName = p.clanName, x = p.x, y = p.y,
                    count = p.count, room = p.room }
                local lostRecently = p.recentLoss and state.scanNo - p.recentLoss <= I.GONE_AFTER + 1
                if lostRecently or (p.zombies or 0) >= I.HORDE then
                    I.emit(reports, g, "wiped")
                else
                    I.emit(reports, g, "gone")
                end
                state.groups[id] = nil
            end
        end
    end

    I.detectGathering(state, groups, reports)
    I.updateFactions(state, groups, reports, now)
    I.ambientAndRumors(state, scan, reports)

    -- Détecteurs ajoutés par d'autres mods (BanditRadio.API.addDetector)
    local api = BanditRadio.API
    if api and api.detectors then
        for _, d in ipairs(api.detectors) do
            local ok, err = pcall(d.fn, state, groups, scan, function(g, kind, extra, level)
                return I.emit(reports, g, kind, extra, level)
            end)
            if not ok then print("[BanditRadio] detector '" .. tostring(d.name) .. "' failed: " .. tostring(err)) end
        end
    end
    return reports
end

---------------------------------------------------------------------------
-- 5. Rassemblements (plusieurs groupes au même endroit)
---------------------------------------------------------------------------
function I.detectGathering(state, groups, reports)
    for _, g in ipairs(groups) do
        local near, total, sx, sy = 0, 0, 0, 0
        for _, o in ipairs(groups) do
            if dist(g.x, g.y, o.x, o.y) <= I.GATHER_RADIUS then
                near, total = near + 1, total + o.count
                sx, sy = sx + o.x * o.count, sy + o.y * o.count
            end
        end
        if near >= I.GATHER_GROUPS then
            local cx, cy = sx / total, sy / total
            local key = BanditRadio.placeName(cx, cy)
            local last = state.areaCooldown[key]
            if not last or state.scanNo - last >= 8 then
                state.areaCooldown[key] = state.scanNo
                I.emit(reports, { gid = g.gid, clan = g.clan, clanName = g.clanName, x = cx, y = cy, count = total },
                    "gathering", { total = total, groups = near })
            end
        end
    end
end

---------------------------------------------------------------------------
-- 6. Ambiance et fausses rumeurs
---------------------------------------------------------------------------
function I.ambientAndRumors(state, scan, reports)
    local players = scan.players or {}
    if #players == 0 then return end
    local pl = players[I.rand(#players) + 1]

    if I.rand(100) < (BanditRadio.opt("AmbientChance") or 0) then
        I.emit(reports, { gid = 0, clan = "radio", clanName = "radio",
            x = pl.x + I.rand(400) - 200, y = pl.y + I.rand(400) - 200, count = 0 }, "ambient", nil, "rumor")
    end

    if I.rand(100) < (BanditRadio.opt("FalseRumors") or 0) and #BanditRadio.Locations > 0 then
        -- Ville au hasard près du joueur : la rumeur doit être "à portée"
        local candidates = {}
        for _, loc in ipairs(BanditRadio.Locations) do
            if dist(loc.x, loc.y, pl.x, pl.y) < (BanditRadio.opt("Range") or 1500) then candidates[#candidates + 1] = loc end
        end
        if #candidates > 0 then
            local loc = candidates[I.rand(#candidates) + 1]
            local kinds = { "loot", "gunfire", "camp", "gathering" }
            local kind = kinds[I.rand(#kinds) + 1]
            I.emit(reports, { gid = -1, clan = "?", clanName = "?", x = loc.x + I.rand(300) - 150,
                y = loc.y + I.rand(300) - 150, count = 3 + I.rand(6) }, kind,
                { total = 6 + I.rand(10), fake = true }, "rumor")
        end
    end
end

---------------------------------------------------------------------------
-- 7. Fiches de faction
---------------------------------------------------------------------------
function I.updateFactions(state, groups, reports, now)
    local seen = {}
    for _, g in ipairs(groups) do
        local f = state.factions[g.clan]
        if not f then
            f = { name = g.clanName, losses = 0, firstSeen = now }
            state.factions[g.clan] = f
        end
        if not seen[g.clan] then
            seen[g.clan] = true
            f.members, f.fire, f.melee, f.groups, f.positions = 0, 0, 0, 0, {}
        end
        f.members = f.members + g.count
        f.fire = f.fire + g.fire
        f.melee = f.melee + g.melee
        f.groups = f.groups + 1
        f.positions[#f.positions + 1] = { x = math.floor(g.x), y = math.floor(g.y), n = g.count }
        f.lastX, f.lastY, f.lastSeen, f.lastRoom = math.floor(g.x), math.floor(g.y), now, g.room
        if g.activity then f.activity = g.activity end
        if g.hostile ~= nil then f.hostile = g.hostile end
    end
    for _, r in ipairs(reports) do
        if (r.kind == "loss" or r.kind == "overrun") and state.factions[r.clan] then
            state.factions[r.clan].losses = state.factions[r.clan].losses + (r.lost or 0)
        end
    end
    for clan, f in pairs(state.factions) do
        if not seen[clan] then f.groups, f.members = 0, 0 end
    end
end

function I.snapshotFactions(state)
    local out = {}
    for clan, f in pairs(state.factions) do
        out[#out + 1] = {
            clan = clan, name = f.name, members = f.members or 0, groups = f.groups or 0,
            fire = f.fire or 0, melee = f.melee or 0, losses = f.losses or 0,
            lastX = f.lastX, lastY = f.lastY, lastSeen = f.lastSeen, lastRoom = f.lastRoom,
            activity = f.activity, hostile = f.hostile, positions = f.positions or {},
        }
    end
    return out
end

---------------------------------------------------------------------------
-- 8. Mise en texte (côté client, dans la langue choisie)
---------------------------------------------------------------------------
local LEVELS = { "full", "partial", "rumor" }

local function pickTemplate(kind, level, seed)
    local langs = { BanditRadio.lang(), "EN" }
    for _, lang in ipairs(langs) do
        local M = BanditRadio.Messages[lang]
        local entry = M and M[kind]
        if entry then
            local start = 1
            for i, l in ipairs(LEVELS) do if l == level then start = i end end
            for i = start, #LEVELS do
                local t = entry[LEVELS[i]]
                if t then
                    if type(t) == "table" then t = t[((seed or 0) % #t) + 1] end
                    return t, LEVELS[i], M
                end
            end
        end
    end
    return nil
end

function I.formatEta(minutes, M)
    if not minutes then return "?" end
    M = M or BanditRadio.Messages.EN
    if minutes < 60 then
        return (string.gsub(M._eta_min, "{m}", tostring(math.floor(minutes / 5 + 0.5) * 5)))
    end
    return (string.gsub(M._eta_h, "{h}", tostring(math.floor(minutes / 60 + 0.5))))
end

function I.formatReport(r, levelOverride)
    local level = levelOverride or r.level or "full"
    local tpl, usedLevel, M = pickTemplate(r.kind, level, r.seed)
    if not tpl then return "[" .. tostring(r.kind) .. "]" end
    local vars = {
        n = tostring(r.n or "?"),
        pos = BanditRadio.describePos(r.x, r.y, r.room),
        area = BanditRadio.describeArea(r.x, r.y),
        from = r.fx and BanditRadio.placeName(r.fx, r.fy) or "?",
        dest = r.dest or "?",
        eta = I.formatEta(r.eta, M),
        player = r.player or "?",
        lost = tostring(r.lost or "?"),
        left = tostring(r.left or "?"),
        other = BanditRadio.prettyClan(r.otherName),
        faction = BanditRadio.prettyClan(r.clanName),
        vehicle = r.vehicle and M._vehicle or "",
        total = tostring(r.total or r.n or "?"),
        dir = r.dir and BanditRadio.T("dir_name")[r.dir] or "?",
    }
    local body = string.gsub(tpl, "{(%w+)}", function(k) return vars[k] or ("{" .. k .. "}") end)
    local prefix = ""
    if r.kind ~= "ambient" then
        prefix = string.gsub(M._prefix[usedLevel] or "", "{(%w+)}", function(k) return vars[k] or "" end)
    end
    return prefix .. body, usedLevel
end

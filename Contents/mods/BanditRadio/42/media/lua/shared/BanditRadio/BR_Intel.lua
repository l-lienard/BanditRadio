-- Bandit Radio - moteur de renseignement (logique pure, sans API du jeu)
--
-- Entrée  : liste de bandits {x, y, clan, clanName, weapon, target, activity, hostile}
-- Sortie  : rapports radio structurés + état des factions.
-- Ce fichier ne touche à aucune API de Project Zomboid : il est testable hors jeu.

require "BanditRadio/BR_Config"

BanditRadio.Intel = BanditRadio.Intel or {}
local I = BanditRadio.Intel

I.CLUSTER_RADIUS = 40     -- cases : bandits d'un même clan plus proches = même groupe
I.MATCH_RADIUS = 250      -- cases : distance max pour reconnaître un groupe d'un scan à l'autre
I.MOVE_MIN = 8            -- cases : en dessous, le groupe est considéré immobile
I.CONE = math.rad(30)     -- angle max entre le cap du groupe et une ville visée
I.TOWN_MIN, I.TOWN_MAX = 150, 3000
I.GONE_AFTER = 2          -- scans sans nouvelles avant "le groupe ne répond plus"
I.REPEAT_EVERY = 4        -- répéter un même rapport tous les N scans au maximum

function I.newState()
    return { groups = {}, factions = {}, nextId = 1 }
end

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

---------------------------------------------------------------------------
-- 1. Regroupement des bandits en groupes (par clan + proximité)
---------------------------------------------------------------------------
function I.cluster(bandits)
    local groups = {}
    for _, b in ipairs(bandits) do
        local found = nil
        for _, g in ipairs(groups) do
            if g.clan == b.clan and dist(g.x, g.y, b.x, b.y) <= I.CLUSTER_RADIUS then
                found = g
                break
            end
        end
        if not found then
            found = { clan = b.clan, clanName = b.clanName, sx = 0, sy = 0, count = 0,
                fire = 0, melee = 0, targets = {}, activities = {}, hostile = nil }
            groups[#groups + 1] = found
        end
        found.count = found.count + 1
        found.sx, found.sy = found.sx + b.x, found.sy + b.y
        found.x, found.y = found.sx / found.count, found.sy / found.count
        if b.weapon == "fire" then found.fire = found.fire + 1
        elseif b.weapon == "melee" then found.melee = found.melee + 1 end
        if b.target then found.targets[b.target] = (found.targets[b.target] or 0) + 1 end
        if b.activity then found.activities[b.activity] = (found.activities[b.activity] or 0) + 1 end
        if b.hostile ~= nil then found.hostile = (found.hostile == true) or b.hostile end
    end
    for _, g in ipairs(groups) do
        g.target = I.topKey(g.targets)
        g.activity = I.topKey(g.activities)
        g.sx, g.sy, g.targets, g.activities = nil, nil, nil, nil
    end
    return groups
end

function I.topKey(t)
    local best, bestN = nil, 0
    for k, n in pairs(t) do
        if n > bestN or (n == bestN and best and tostring(k) < tostring(best)) then best, bestN = k, n end
    end
    return best
end

---------------------------------------------------------------------------
-- 2. Déduction de la destination
---------------------------------------------------------------------------
-- Renvoie la ville vers laquelle le groupe se dirige (ou nil) et sa distance.
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
-- 3. Mise à jour de l'état et génération des rapports
---------------------------------------------------------------------------
local function report(list, g, kind, extra)
    local r = { kind = kind, clan = g.clan, clanName = g.clanName,
        x = math.floor(g.x), y = math.floor(g.y), n = g.count }
    if extra then for k, v in pairs(extra) do r[k] = v end end
    list[#list + 1] = r
end

-- Évite de répéter le même message à chaque scan
local function shouldSay(prev, key)
    if prev.lastKey ~= key or prev.sinceMsg >= I.REPEAT_EVERY then
        prev.lastKey, prev.sinceMsg = key, 0
        return true
    end
    return false
end

function I.update(state, bandits, now, intervalMinutes)
    local groups = I.cluster(bandits)
    local reports = {}
    local matched = {}

    for _, g in ipairs(groups) do
        -- Retrouver le groupe correspondant au scan précédent
        local prevId, prev, bestD = nil, nil, nil
        for id, p in pairs(state.groups) do
            if not matched[id] and p.clan == g.clan then
                local d = dist(p.x, p.y, g.x, g.y)
                if d <= I.MATCH_RADIUS and (not bestD or d < bestD) then prevId, prev, bestD = id, p, d end
            end
        end

        if not prev then
            prevId = state.nextId
            state.nextId = state.nextId + 1
            prev = { clan = g.clan, x = g.x, y = g.y, count = g.count, sinceMsg = 0, lastKey = "new" }
            state.groups[prevId] = prev
            report(reports, g, "new")
        else
            local moved = dist(prev.x, prev.y, g.x, g.y)
            prev.sinceMsg = prev.sinceMsg + 1

            if g.count < prev.count then
                report(reports, g, "loss", { lost = prev.count - g.count })
            end

            if g.target then
                if shouldSay(prev, "player:" .. g.target) then
                    report(reports, g, "player", { player = g.target })
                end
            elseif moved >= I.MOVE_MIN then
                local speed = moved / math.max(intervalMinutes, 1)          -- cases / minute
                local town, townD = I.guessTown(prev.x, prev.y, g.x, g.y)
                if town then
                    if shouldSay(prev, "town:" .. town.name) then
                        local eta = math.max(1, math.floor(townD / speed / 60 + 0.5))
                        report(reports, g, "town", { dest = town.name, eta = eta })
                    end
                else
                    local d = BanditRadio.dirIndex(g.x - prev.x, g.y - prev.y)
                    if shouldSay(prev, "dir:" .. d) then
                        report(reports, g, "dir", { dir = d })
                    end
                end
            else
                if shouldSay(prev, "hold") then report(reports, g, "hold") end
            end

            prev.x, prev.y, prev.count = g.x, g.y, g.count
        end
        prev.missed = 0
        prev.hostile, prev.fire, prev.melee, prev.activity = g.hostile, g.fire, g.melee, g.activity
        matched[prevId] = true
    end

    -- Groupes disparus (tués, déchargés ou hors des zones chargées)
    for id, p in pairs(state.groups) do
        if not matched[id] then
            p.missed = (p.missed or 0) + 1
            if p.missed >= I.GONE_AFTER then
                report(reports, { clan = p.clan, clanName = I.clanNameOf(state, p.clan),
                    x = p.x, y = p.y, count = p.count }, "gone")
                state.groups[id] = nil
            end
        end
    end

    I.updateFactions(state, groups, reports, now)
    return reports
end

function I.clanNameOf(state, clan)
    local f = state.factions[clan]
    return f and f.name or tostring(clan)
end

---------------------------------------------------------------------------
-- 4. Fiches de faction
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
        f.lastX, f.lastY, f.lastSeen = math.floor(g.x), math.floor(g.y), now
        if g.activity then f.activity = g.activity end
        if g.hostile ~= nil then f.hostile = g.hostile end
    end
    for _, r in ipairs(reports) do
        if r.kind == "loss" and state.factions[r.clan] then
            state.factions[r.clan].losses = state.factions[r.clan].losses + r.lost
        end
    end
    -- Factions plus entendues : elles gardent leur dernière position connue
    for clan, f in pairs(state.factions) do
        if not seen[clan] then f.groups, f.members = 0, 0 end
    end
end

-- Copie compacte et sûre pour l'envoi réseau (tables simples uniquement)
function I.snapshotFactions(state)
    local out = {}
    for clan, f in pairs(state.factions) do
        out[#out + 1] = {
            clan = clan, name = f.name, members = f.members or 0, groups = f.groups or 0,
            fire = f.fire or 0, melee = f.melee or 0, losses = f.losses or 0,
            lastX = f.lastX, lastY = f.lastY, lastSeen = f.lastSeen,
            activity = f.activity, hostile = f.hostile, positions = f.positions or {},
        }
    end
    return out
end

---------------------------------------------------------------------------
-- 5. Mise en texte (côté client, dans la langue du joueur)
---------------------------------------------------------------------------
function I.formatReport(r)
    local T, pos = BanditRadio.T, BanditRadio.describePos(r.x, r.y)
    local body
    if r.kind == "new" then body = string.format(T("msg_new"), r.n, pos)
    elseif r.kind == "town" then body = string.format(T("msg_move_town"), r.n, r.dest, r.eta)
    elseif r.kind == "player" then body = string.format(T("msg_move_player"), r.n, r.player, pos)
    elseif r.kind == "dir" then body = string.format(T("msg_move_dir"), r.n, T("dir")[r.dir], pos)
    elseif r.kind == "hold" then body = string.format(T("msg_hold"), r.n, pos)
    elseif r.kind == "loss" then body = string.format(T("msg_loss"), r.lost, r.n, pos)
    elseif r.kind == "gone" then body = string.format(T("msg_gone"), pos)
    else body = tostring(r.kind) end
    return "[" .. tostring(r.clanName) .. "] " .. body
end

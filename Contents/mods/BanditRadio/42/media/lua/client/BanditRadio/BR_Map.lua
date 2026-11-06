-- Bandit Radio - overlay sur la carte (carte du monde + minicarte)
--
-- Chaque rapport capté devient une "zone" floue sur la carte :
--   * couleur = faction (gris = rumeur, blanc = faction inconnue)
--   * trajet  = pointillés départ -> destination, avec l'heure d'arrivée restante
--   * les zones disparaissent après MarkerHours heures en jeu
-- Volontairement imprécis : on ne montre jamais la position exacte d'un groupe.

require "BanditRadio/BR_Config"

BanditRadio.Map = BanditRadio.Map or {}
local Map = BanditRadio.Map

Map.markers = {}         -- clé -> marqueur
Map.enabled = true       -- préférence du joueur (bouton "Carte" de la radio)

local TEX_ZONE = "media/ui/BanditRadio/zone.png"
local TEX_RING = "media/ui/BanditRadio/ring.png"
local TEX_DOT = "media/ui/BanditRadio/dot.png"

local GREY = { r = 0.6, g = 0.6, b = 0.6 }
local WHITE = { r = 0.95, g = 0.95, b = 0.95 }

local function now()
    return getGameTime():getWorldAgeHours() * 60
end

-- Centre "flou" : ville proche si on est dedans, sinon grille de 200 cases
local function vague(x, y, level)
    local loc, d = BanditRadio.nearestLocation(x, y)
    if loc and d < 700 then return loc.x, loc.y, (level == "rumor") and 500 or 350 end
    local step = (level == "rumor") and 400 or 200
    return math.floor(x / step) * step + step / 2, math.floor(y / step) * step + step / 2,
        (level == "rumor") and 450 or 250
end

---------------------------------------------------------------------------
-- Création des marqueurs à partir des rapports
---------------------------------------------------------------------------
local IGNORE = { ambient = true }

function Map.addFromReport(r, level)
    if not BanditRadio.opt("MapMarkers") or IGNORE[r.kind] then return end
    local t = now()
    local faction = BanditRadio.prettyClan(r.clanName)
    local color = (level == "rumor") and GREY or (level == "partial") and WHITE or BanditRadio.factionColor(faction)
    local key = (r.gid and r.gid > 0) and ("g" .. r.gid) or ("e" .. r.kind .. math.floor(r.x / 300) .. "_" .. math.floor(r.y / 300))

    -- Un groupe silencieux : on garde sa dernière zone mais on la laisse s'éteindre
    if r.kind == "gone" then
        local m = Map.markers[key]
        if m then m.fading = true end
        return
    end

    local cx, cy, radius = vague(r.x, r.y, level)
    local m = {
        kind = r.kind, level = level, faction = (level == "full") and faction or nil,
        color = color, x = cx, y = cy, radius = radius, t = t,
    }
    if r.kind == "move" and r.destX then
        -- Zone de destination (la ville) + trajet
        local loc = BanditRadio.nearestLocation(r.destX, r.destY)
        m.destX, m.destY = r.destX, r.destY
        m.destName = r.dest or (loc and loc.name)
        m.etaAt = r.eta and (t + r.eta) or nil
    elseif r.kind == "move_dir" and r.headX then
        m.destX, m.destY = r.headX, r.headY
    elseif r.kind == "approach" and r.px then
        m.destX, m.destY = r.px, r.py
        m.etaAt = r.eta and (t + r.eta) or nil
    end
    Map.markers[key] = m
end

function Map.prune()
    local maxAge = (BanditRadio.opt("MarkerHours") or 12) * 60
    local t = now()
    for k, m in pairs(Map.markers) do
        local age = t - m.t
        if age > maxAge or (m.fading and age > maxAge / 3) then Map.markers[k] = nil end
    end
end

function Map.clear()
    Map.markers = {}
end

---------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------
local texCache = {}
local function tex(path)
    if texCache[path] == nil then texCache[path] = getTexture(path) or false end
    return texCache[path] or nil
end

local function toUI(api, x, y)
    return api:worldToUIX(x, y), api:worldToUIY(x, y)
end

local function textShadow(ui, text, x, y, c, font)
    ui:drawText(text, x + 1, y + 1, 0, 0, 0, 0.8, font)
    ui:drawText(text, x, y, c.r, c.g, c.b, 1, font)
end

local function remaining(m, t)
    if not m.etaAt then return nil end
    local left = m.etaAt - t
    if left <= 0 then return BanditRadio.T("map_kind").arrive end
    return BanditRadio.Intel.formatEta(left, BanditRadio.Messages[BanditRadio.lang()])
end

function Map.draw(ui, api, isMini)
    if not Map.enabled or not BanditRadio.opt("MapMarkers") or not api then return end
    Map.prune()
    local zone, ring, dot = tex(TEX_ZONE), tex(TEX_RING), tex(TEX_DOT)
    if not zone then return end
    local t = now()
    local maxAge = (BanditRadio.opt("MarkerHours") or 12) * 60
    local font = UIFont.Small
    local kinds = BanditRadio.T("map_kind")
    local legend = {}
    if isMini then ui:setStencilRect(0, 0, ui:getWidth(), ui:getHeight()) end

    for _, m in pairs(Map.markers) do
        local fade = 1 - math.min(1, (t - m.t) / maxAge) * 0.7
        if m.fading then fade = fade * 0.5 end
        local c = m.color
        local ux, uy = toUI(api, m.x, m.y)
        local ex = toUI(api, m.x + m.radius, m.y)
        local rpx = math.max(6, math.abs(ex - ux))

        -- Trajet en pointillés vers la destination
        if m.destX and dot then
            local dx, dy = toUI(api, m.destX, m.destY)
            local len = math.sqrt((dx - ux) ^ 2 + (dy - uy) ^ 2)
            local steps = math.min(80, math.floor(len / 10))
            for i = 1, steps - 1 do
                local f = i / steps
                ui:drawTextureScaled(dot, ux + (dx - ux) * f - 2, uy + (dy - uy) * f - 2, 4, 4, 0.8 * fade, c.r, c.g, c.b)
            end
            if m.destName then
                -- Zone de la ville visée
                local dex = toUI(api, m.destX + 350, m.destY)
                local drp = math.max(8, math.abs(dex - dx))
                ui:drawTextureScaled(zone, dx - drp, dy - drp, drp * 2, drp * 2, 0.35 * fade, c.r, c.g, c.b)
                if ring then ui:drawTextureScaled(ring, dx - drp, dy - drp, drp * 2, drp * 2, 0.9 * fade, c.r, c.g, c.b) end
                if not isMini then
                    local label = (m.faction and (m.faction .. " -> ") or "-> ") .. m.destName
                    local eta = remaining(m, t)
                    textShadow(ui, label, dx - drp, dy + drp + 2, c, font)
                    if eta then textShadow(ui, "ETA " .. eta, dx - drp, dy + drp + 16, c, font) end
                end
            end
        end

        -- Zone de l'événement / position floue du groupe
        ui:drawTextureScaled(zone, ux - rpx, uy - rpx, rpx * 2, rpx * 2, 0.25 * fade, c.r, c.g, c.b)
        if ring then ui:drawTextureScaled(ring, ux - rpx, uy - rpx, rpx * 2, rpx * 2, 0.7 * fade, c.r, c.g, c.b) end
        if not isMini then
            local label = kinds[m.kind] or m.kind
            if m.level == "rumor" then label = label .. " (" .. BanditRadio.T("map_rumor") .. ")"
            elseif m.faction then label = m.faction .. " - " .. label end
            textShadow(ui, label, ux - rpx, uy - rpx - 14, c, font)
        end
        if m.faction then legend[m.faction] = c end
    end

    if isMini then ui:clearStencilRect() end

    -- Légende des factions (carte du monde uniquement)
    if not isMini then
        local names = {}
        for name in pairs(legend) do names[#names + 1] = name end
        table.sort(names)
        if #names > 0 then
            local lh = getTextManager():getFontHeight(font) + 2
            local h = 24 + #names * lh
            local x, y = 12, ui:getHeight() - h - 12
            ui:drawRect(x, y, 190, h, 0.75, 0.05, 0.05, 0.05)
            ui:drawRectBorder(x, y, 190, h, 0.8, 0.3, 0.6, 0.3)
            ui:drawText(BanditRadio.T("map_legend"), x + 8, y + 4, 0.55, 1, 0.55, 1, font)
            for i, name in ipairs(names) do
                local c = legend[name]
                local ly = y + 6 + i * lh
                ui:drawRect(x + 8, ly + 3, 10, 10, 1, c.r, c.g, c.b)
                ui:drawText(name, x + 24, ly, 0.9, 0.9, 0.9, 1, font)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Branchement sur la carte du monde et la minicarte
---------------------------------------------------------------------------
local function hook(class, isMini)
    if not class or class.__banditRadioHooked then return end
    local orig = class.render
    class.render = function(self, ...)
        orig(self, ...)
        local ok, err = pcall(Map.draw, self, self.mapAPI, isMini)
        if not ok and not Map.warned then
            Map.warned = true
            print("[BanditRadio] map overlay error: " .. tostring(err))
        end
    end
    class.__banditRadioHooked = true
end

function Map.install()
    hook(ISWorldMap, false)
    hook(ISMiniMapInner, true)
end
Events.OnGameStart.Add(Map.install)

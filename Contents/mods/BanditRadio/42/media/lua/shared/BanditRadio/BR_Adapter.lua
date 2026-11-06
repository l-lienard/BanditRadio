-- Bandit Radio - couche d'adaptation vers Bandits NPC (v2)
--
-- TOUT le contact avec le code de Bandits passe par ce fichier.
-- Bandits n'expose pas d'API publique documentée : chaque appel est protégé
-- (pcall + vérification de type) et a une solution de repli. Si Slayer
-- renomme une fonction dans une mise à jour, c'est ici qu'il faut corriger.

require "BanditRadio/BR_Config"

BanditRadio.Adapter = BanditRadio.Adapter or {}
local A = BanditRadio.Adapter

local function try(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

---------------------------------------------------------------------------
-- Cerveau (brain) d'un bandit : table Lua gérée par Bandits
---------------------------------------------------------------------------
function A.getBrain(zombie)
    if not zombie then return nil end
    if BanditBrain and type(BanditBrain.Get) == "function" then
        local brain = try(BanditBrain.Get, zombie)
        if type(brain) == "table" then return brain end
    end
    return nil
end

function A.isBandit(zombie)
    if not zombie then return false end
    if A.getBrain(zombie) then return true end
    -- Repli : Bandits marque ses PNJ avec une variable d'animation "Bandit"
    local flagged = try(function() return zombie:getVariableBoolean("Bandit") end)
    return flagged == true
end

---------------------------------------------------------------------------
-- Clan / faction
---------------------------------------------------------------------------
local FALLBACK_NAMES = {
    "Black Dogs", "Red Vipers", "Ravens", "Iron Saints", "Hollow Men",
    "Knox Wolves", "Rust Riders", "Grey Coats", "Night Owls", "Bone Collectors",
    "Kentucky Kings", "Scrap Lords", "Silent Crows", "Mad Hatters", "Ash Brothers",
}

local function hashString(s)
    local h = 7
    s = tostring(s)
    for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
    return h
end

function A.getClanId(brain)
    if not brain then return "unknown" end
    local cid = brain.cid or brain.clan or brain.clanId
    if cid == nil then return "unknown" end
    return tostring(cid)
end

A._clanNameCache = {}

function A.getClanName(cid)
    if A._clanNameCache[cid] then return A._clanNameCache[cid] end
    local name = nil
    -- Clans créés avec Bandit Creator
    if BanditCustom and type(BanditCustom.ClanGet) == "function" then
        local clan = try(BanditCustom.ClanGet, cid)
        if type(clan) == "table" then
            local g = clan.general
            if type(g) == "table" and type(g.name) == "string" and g.name ~= "" then
                name = g.name
            elseif type(clan.name) == "string" and clan.name ~= "" then
                name = clan.name
            end
        end
    end
    -- Repli : nom stable dérivé de l'id du clan
    if not name then
        name = FALLBACK_NAMES[(hashString(cid) % #FALLBACK_NAMES) + 1]
    end
    A._clanNameCache[cid] = name
    return name
end

---------------------------------------------------------------------------
-- Armement
---------------------------------------------------------------------------
local FIREARM_HINTS = { "rifle", "shotgun", "pistol", "revolver", "smg", "m16",
    "m14", "ak", "ar15", "mac10", "uzi", "glock", "magnum", "carbine", "gun" }

local function looksLikeFirearm(name)
    if type(name) ~= "string" then return false end
    local n = string.lower(name)
    for _, hint in ipairs(FIREARM_HINTS) do
        if string.find(n, hint, 1, true) then return true end
    end
    return false
end

-- Renvoie "fire", "melee" ou nil
function A.getWeaponClass(zombie, brain)
    if brain and type(brain.weapons) == "table" then
        local w = brain.weapons
        for _, slot in ipairs({ "primary", "secondary" }) do
            local s = w[slot]
            local n = type(s) == "table" and (s.name or s.type) or s
            if looksLikeFirearm(n) then return "fire" end
        end
        if w.melee then return "melee" end
    end
    local item = try(function() return zombie:getPrimaryHandItem() end)
    if item then
        local ranged = try(function() return item:isRanged() end)
        if ranged then return "fire" end
        return "melee"
    end
    return nil
end

---------------------------------------------------------------------------
-- Cible / activité / état
---------------------------------------------------------------------------
-- Renvoie type de cible ("player" | "bandit" | "zombie" | nil), nom du joueur, clan visé
function A.getTarget(zombie)
    local target = try(function() return zombie:getTarget() end)
    if not target then return nil end
    if instanceof(target, "IsoPlayer") then
        local name = try(function() return target:getUsername() end)
            or try(function() return target:getDisplayName() end)
        return "player", name, nil
    end
    if instanceof(target, "IsoZombie") then
        if A.isBandit(target) then
            return "bandit", nil, A.getClanId(A.getBrain(target))
        end
        return "zombie", nil, nil
    end
    return nil
end

function A.getActivity(brain)
    if brain and type(brain.program) == "table" and type(brain.program.name) == "string" then
        return brain.program.name
    end
    return nil
end

function A.getHostile(brain)
    if brain and brain.hostile ~= nil then return brain.hostile and true or false end
    return nil
end

function A.isSleeping(brain)
    return brain and brain.sleeping == true or false
end

function A.inVehicle(zombie, brain)
    if brain and brain.inVehicle then return true end
    local v = try(function() return zombie:getVehicle() end)
    return v ~= nil
end

function A.getId(zombie, brain)
    if brain and brain.id ~= nil then return tostring(brain.id) end
    local id = try(function() return zombie:getOnlineID() end)
    if id and id ~= -1 then return tostring(id) end
    return tostring(try(function() return zombie:getID() end) or zombie)
end

-- Nom de la pièce où se trouve le bandit ("gasstore", "policestorage"...), sinon nil
function A.getRoomName(zombie)
    return try(function()
        local sq = zombie:getSquare()
        local room = sq and sq:getRoom()
        return room and room:getName() or nil
    end)
end

---------------------------------------------------------------------------
-- Joueurs (solo : joueurs locaux / multi : joueurs connectés)
---------------------------------------------------------------------------
function A.listPlayers()
    local out = {}
    local list = try(getOnlinePlayers)
    if list and list:size() > 0 then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p and not p:isDead() then
                out[#out + 1] = { name = p:getUsername(), x = p:getX(), y = p:getY() }
            end
        end
        return out
    end
    for i = 0, 3 do
        local p = try(getSpecificPlayer, i)
        if p and not p:isDead() then
            out[#out + 1] = { name = try(function() return p:getUsername() end) or ("Player" .. (i + 1)),
                x = p:getX(), y = p:getY() }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Balayage complet (côté serveur ou solo)
--   bandits : liste détaillée
--   zgrid   : nombre de zombies "normaux" par case de 20x20 (pour les combats)
--   players : positions des joueurs
---------------------------------------------------------------------------
A.GRID = 20

function A.scan()
    local result = { bandits = {}, zgrid = {}, players = A.listPlayers() }
    local cell = try(getCell)
    if not cell then return result end
    local list = try(function() return cell:getZombieList() end)
    if not list then return result end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and not try(function() return z:isDead() end) then
            local brain = A.getBrain(z)
            if brain or A.isBandit(z) then
                local cid = A.getClanId(brain)
                local ttype, tname, tclan = A.getTarget(z)
                result.bandits[#result.bandits + 1] = {
                    id = A.getId(z, brain),
                    x = z:getX(), y = z:getY(),
                    clan = cid,
                    clanName = A.getClanName(cid),
                    weapon = A.getWeaponClass(z, brain),
                    target = (ttype == "player") and tname or nil,
                    targetType = ttype,
                    targetClan = tclan,
                    activity = A.getActivity(brain),
                    hostile = A.getHostile(brain),
                    room = A.getRoomName(z),
                    vehicle = A.inVehicle(z, brain),
                    sleeping = A.isSleeping(brain),
                }
            else
                local key = math.floor(z:getX() / A.GRID) .. "," .. math.floor(z:getY() / A.GRID)
                result.zgrid[key] = (result.zgrid[key] or 0) + 1
            end
        end
    end
    return result
end

-- Compatibilité
function A.listBandits()
    return A.scan().bandits
end

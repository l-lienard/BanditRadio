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
-- Cible / activité
---------------------------------------------------------------------------
function A.getTargetPlayerName(zombie)
    local target = try(function() return zombie:getTarget() end)
    if target and instanceof(target, "IsoPlayer") then
        return try(function() return target:getUsername() end)
            or try(function() return target:getDisplayName() end)
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

---------------------------------------------------------------------------
-- Liste de tous les bandits chargés côté serveur (ou solo)
---------------------------------------------------------------------------
function A.listBandits()
    local out = {}
    local cell = try(getCell)
    if not cell then return out end
    local list = try(function() return cell:getZombieList() end)
    if not list then return out end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and not try(function() return z:isDead() end) and A.isBandit(z) then
            local brain = A.getBrain(z)
            local cid = A.getClanId(brain)
            out[#out + 1] = {
                x = z:getX(), y = z:getY(),
                clan = cid,
                clanName = A.getClanName(cid),
                weapon = A.getWeaponClass(z, brain),
                target = A.getTargetPlayerName(z),
                activity = A.getActivity(brain),
                hostile = A.getHostile(brain),
            }
        end
    end
    return out
end

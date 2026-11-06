-- Bandit Radio - côté serveur (s'exécute aussi en solo)
-- Balaye les bandits chargés, déduit leurs mouvements et diffuse les rapports.

require "BanditRadio/BR_Config"
require "BanditRadio/BR_Adapter"
require "BanditRadio/BR_Intel"

if isClient() then return end   -- en multijoueur, seul le serveur fait le travail

BanditRadio.Server = BanditRadio.Server or {}
local S = BanditRadio.Server

S.state = BanditRadio.Intel.newState()
S.elapsed = 0
S.warned = false

local function nowMinutes()
    return math.floor(getGameTime():getWorldAgeHours() * 60)
end

-- Envoie un paquet à tous les clients (MP) ou directement au client local (solo)
function S.dispatch(packet)
    if isServer() then
        sendServerCommand(BanditRadio.MODULE, "Intel", packet)
    elseif BanditRadio.Client and BanditRadio.Client.onIntel then
        BanditRadio.Client.onIntel(packet)
    end
end

function S.scan()
    local interval = BanditRadio.opt("ScanInterval")
    local ok, err = pcall(function()
        local bandits = BanditRadio.Adapter.listBandits()
        local reports = BanditRadio.Intel.update(S.state, bandits, nowMinutes(), interval)
        S.dispatch({
            time = nowMinutes(),
            reports = reports,
            factions = BanditRadio.Intel.snapshotFactions(S.state),
        })
    end)
    if not ok and not S.warned then
        S.warned = true
        print("[BanditRadio] scan error (Bandits API changed?): " .. tostring(err))
    end
end

local function onTenMinutes()
    S.elapsed = S.elapsed + 10
    if S.elapsed >= BanditRadio.opt("ScanInterval") then
        S.elapsed = 0
        S.scan()
    end
end
Events.EveryTenMinutes.Add(onTenMinutes)

---------------------------------------------------------------------------
-- Butin : un bandit tué peut lâcher sa radio
---------------------------------------------------------------------------
local function onZombieDead(zombie)
    if not BanditRadio.Adapter.isBandit(zombie) then return end
    if ZombRand(100) < BanditRadio.opt("DropChance") then
        local inv = zombie:getInventory()
        if inv then
            local item = inv:AddItem(BanditRadio.ITEM)
            if item then item:getModData().BR_charge = 20 + ZombRand(60) end
        end
    end
end
Events.OnZombieDead.Add(onZombieDead)

---------------------------------------------------------------------------
-- Butin du monde (commissariats, surplus militaire, magasins d'électronique)
---------------------------------------------------------------------------
local WORLD_LOOT = {
    { list = "PoliceStorageOutfit",   chance = 0.5 },
    { list = "ArmyStorageElectronics", chance = 1.0 },
    { list = "ElectronicStoreMisc",   chance = 0.3 },
    { list = "CrateElectronics",      chance = 0.3 },
}

local function addWorldLoot()
    if not BanditRadio.opt("WorldLoot") then return end
    if not ProceduralDistributions or not ProceduralDistributions.list then return end
    for _, e in ipairs(WORLD_LOOT) do
        local dist = ProceduralDistributions.list[e.list]
        if dist and dist.items then
            table.insert(dist.items, BanditRadio.ITEM)
            table.insert(dist.items, e.chance)
        end
    end
end
Events.OnPreDistributionMerge.Add(addWorldLoot)

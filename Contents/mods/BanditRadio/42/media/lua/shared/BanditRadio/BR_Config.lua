-- Bandit Radio - configuration partagée (client + serveur)
-- Addon pour Bandits NPC (v2) de Slayer. Licence MIT.

BanditRadio = BanditRadio or {}
BanditRadio.VERSION = "1.1.0"
BanditRadio.MODULE = "BanditRadio"          -- module réseau (sendServerCommand)
BanditRadio.ITEM = "BanditRadio.BanditRadio"

---------------------------------------------------------------------------
-- Options sandbox (avec valeurs par défaut si SandboxVars n'est pas prêt)
---------------------------------------------------------------------------
local DEFAULTS = {
    Range = 1500,            -- portée d'écoute en cases
    ScanInterval = 30,       -- minutes in-game entre deux balayages
    DropChance = 8,          -- % de chance qu'un bandit tué lâche une radio
    BatteryHours = 36,       -- heures in-game d'écoute pour une pile
    ExactCoordinates = false,-- afficher les coordonnées exactes
    Static = true,           -- brouillage selon la distance
    WorldLoot = true,        -- radios dans le loot du monde
    Overhead = true,         -- radio allumée : messages au-dessus du joueur
    LogWhenOff = true,       -- radio éteinte (mais portée) : messages enregistrés
}

function BanditRadio.opt(name)
    local sv = SandboxVars and SandboxVars.BanditRadio
    if sv and sv[name] ~= nil then return sv[name] end
    return DEFAULTS[name]
end

---------------------------------------------------------------------------
-- Lieux nommés (coordonnées approximatives du centre de chaque ville).
-- Ajoute / corrige librement : c'est la partie la plus simple à contribuer.
---------------------------------------------------------------------------
BanditRadio.Locations = {
    { name = "Muldraugh",      x = 10650, y = 9700  },
    { name = "West Point",     x = 11900, y = 6900  },
    { name = "Riverside",      x = 6450,  y = 5350  },
    { name = "Rosewood",       x = 8150,  y = 11550 },
    { name = "March Ridge",    x = 10000, y = 12650 },
    { name = "Louisville",     x = 12900, y = 2300  },
    { name = "Valley Station", x = 13100, y = 5600  },
    { name = "Fallas Lake",    x = 7250,  y = 8300  },
    -- Ajouts B42 : coordonnées à vérifier en jeu (carte / mode debug)
    { name = "Ekron",          x = 700,   y = 9600  },
    { name = "Irvington",      x = 2000,  y = 14000 },
    { name = "Brandenburg",    x = 2000,  y = 6000  },
    { name = "Echo Creek",     x = 3600,  y = 10900 },
}

---------------------------------------------------------------------------
-- Traductions des messages radio (générés en Lua)
---------------------------------------------------------------------------
BanditRadio.Strings = {
    EN = {
        title = "Bandit Radio",
        tab_feed = "Intercepts",
        tab_factions = "Factions",
        on = "ON", off = "OFF",
        battery = "Battery",
        no_signal = "... static ... no transmission in range ...",
        no_battery = "The radio is dead. Replace the battery.",
        ctx_listen = "Turn on bandit radio",
        ctx_stop = "Turn off bandit radio",
        ctx_open = "Open radio log",
        unread = "%d new",
        missed = "[missed]",
        off_banner = "Radio off - intercepted messages are saved here.",
        overhead = "[Radio] ",
        ctx_battery = "Replace battery",
        ctx_debug = "[DBG] Give Bandit Radio",
        dir = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" },
        dir_at = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" },
        near = "near %s",
        around = "%s of %s",
        wild = "in the wilds",
        msg_new = "New contact: %d men spotted %s.",
        msg_move_town = "Group of %d moving toward %s (ETA ~%dh).",
        msg_move_player = "Group of %d is tracking %s! Last heard %s.",
        msg_move_dir = "Group of %d heading %s, currently %s.",
        msg_hold = "Group of %d holding position %s.",
        msg_loss = "Lost %d men. %d left in the group %s.",
        msg_gone = "Group went silent. Last known position: %s.",
        armed_fire = "firearms",
        armed_melee = "melee",
        f_members = "Members heard",
        f_groups = "Groups",
        f_weapons = "Weapons",
        f_last = "Last position",
        f_activity = "Activity",
        f_losses = "Losses",
        f_hostile = "Hostile",
        yes = "yes", no = "no", unknown = "?",
        no_faction = "No faction intercepted yet.",
    },
    FR = {
        title = "Radio Bandit",
        tab_feed = "Interceptions",
        tab_factions = "Factions",
        on = "ON", off = "OFF",
        battery = "Pile",
        no_signal = "... grésillements ... aucune transmission à portée ...",
        no_battery = "La radio est morte. Change la pile.",
        ctx_listen = "Allumer la radio bandit",
        ctx_stop = "Éteindre la radio bandit",
        ctx_open = "Ouvrir le journal radio",
        unread = "%d nouveaux",
        missed = "[manqué]",
        off_banner = "Radio éteinte - les messages captés sont enregistrés ici.",
        overhead = "[Radio] ",
        ctx_battery = "Changer la pile",
        ctx_debug = "[DBG] Donner une Radio Bandit",
        dir = { "du nord", "du nord-est", "de l'est", "du sud-est", "du sud", "du sud-ouest", "de l'ouest", "du nord-ouest" },
        dir_at = { "au nord", "au nord-est", "à l'est", "au sud-est", "au sud", "au sud-ouest", "à l'ouest", "au nord-ouest" },
        near = "près de %s",
        around = "%s de %s",
        wild = "en pleine nature",
        msg_new = "Nouveau contact : %d hommes repérés %s.",
        msg_move_town = "Groupe de %d en route vers %s (arrivée ~%dh).",
        msg_move_player = "Groupe de %d sur la piste de %s ! Dernière position %s.",
        msg_move_dir = "Groupe de %d en direction %s, actuellement %s.",
        msg_hold = "Groupe de %d stationné %s.",
        msg_loss = "%d hommes perdus. Il en reste %d dans le groupe %s.",
        msg_gone = "Le groupe ne répond plus. Dernière position : %s.",
        armed_fire = "armes à feu",
        armed_melee = "corps à corps",
        f_members = "Membres entendus",
        f_groups = "Groupes",
        f_weapons = "Armement",
        f_last = "Dernière position",
        f_activity = "Activité",
        f_losses = "Pertes",
        f_hostile = "Hostile",
        yes = "oui", no = "non", unknown = "?",
        no_faction = "Aucune faction interceptée pour l'instant.",
    },
}

function BanditRadio.lang()
    local ok, code = pcall(function() return tostring(Translator.getLanguage():name()) end)
    if ok and code and BanditRadio.Strings[code] then return code end
    return "EN"
end

function BanditRadio.T(key)
    local s = BanditRadio.Strings[BanditRadio.lang()] or BanditRadio.Strings.EN
    if s[key] ~= nil then return s[key] end
    return BanditRadio.Strings.EN[key] or key
end

-- Couleur de chaque type de rapport (interface + texte au-dessus du joueur)
BanditRadio.KindColor = {
    player = { r = 1.00, g = 0.35, b = 0.30 },
    loss   = { r = 1.00, g = 0.75, b = 0.30 },
    gone   = { r = 1.00, g = 0.75, b = 0.30 },
    new    = { r = 1.00, g = 0.95, b = 0.45 },
    default = { r = 0.55, g = 1.00, b = 0.55 },
}

function BanditRadio.colorFor(kind)
    return BanditRadio.KindColor[kind] or BanditRadio.KindColor.default
end

---------------------------------------------------------------------------
-- Helpers géographiques
---------------------------------------------------------------------------
-- Dans PZ, y augmente vers le sud de la carte. Index 1 = nord.
function BanditRadio.dirIndex(dx, dy)
    local ang = math.atan2(dx, -dy)               -- 0 = nord, sens horaire
    if ang < 0 then ang = ang + 2 * math.pi end
    return (math.floor((ang + math.pi / 8) / (math.pi / 4)) % 8) + 1
end

function BanditRadio.nearestLocation(x, y)
    local best, bestD = nil, nil
    for _, loc in ipairs(BanditRadio.Locations) do
        local d = math.sqrt((loc.x - x) ^ 2 + (loc.y - y) ^ 2)
        if not bestD or d < bestD then best, bestD = loc, d end
    end
    return best, bestD
end

-- Description humaine d'une position : "près de Muldraugh", "au nord de Rosewood"...
function BanditRadio.describePos(x, y)
    if BanditRadio.opt("ExactCoordinates") then
        return string.format("(%d, %d)", math.floor(x), math.floor(y))
    end
    local loc, d = BanditRadio.nearestLocation(x, y)
    if not loc then return BanditRadio.T("wild") end
    if d < 350 then return string.format(BanditRadio.T("near"), loc.name) end
    if d > 2500 then return BanditRadio.T("wild") end
    local dirs = BanditRadio.T("dir_at")
    return string.format(BanditRadio.T("around"), dirs[BanditRadio.dirIndex(x - loc.x, y - loc.y)], loc.name)
end

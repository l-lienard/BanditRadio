-- Bandit Radio - configuration partagée (client + serveur)
-- Addon pour Bandits NPC (v2) de Slayer. Licence MIT.

BanditRadio = BanditRadio or {}
BanditRadio.VERSION = "2.0.0"
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
    Static = true,           -- brouillage selon la distance
    WorldLoot = true,        -- radios dans le loot du monde
    Overhead = true,         -- radio allumée : messages au-dessus du joueur
    LogWhenOff = true,       -- radio éteinte (mais portée) : messages enregistrés
    Reliability = 1,         -- 1 = complète, 2 = réaliste (mélange), 3 = rumeurs
    FalseRumors = 0,         -- % de chance par analyse d'une fausse rumeur
    AmbientChance = 15,      -- % de chance par analyse d'un message d'ambiance
    EvMovement = true,       -- contacts, trajets, arrivées, camps, renforts, rassemblements
    EvLoot = true,           -- pillages
    EvCombat = true,         -- coups de feu, combats, affrontements
    EvPlayers = true,        -- traque / approche des joueurs
    EvLosses = true,         -- pertes, groupes anéantis ou silencieux
    EvAmbient = true,        -- messages d'ambiance
    MapMarkers = true,       -- zones sur la carte
    MarkerHours = 12,        -- durée de vie des zones (heures en jeu)
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
        around = "outside %s",
        wild = "in the wilds",
        near_place = "near %s in %s",
        around_place = "near %s outside %s",
        wild_place = "near %s in the wilds",
        lang_btn = "Language",
        dir_name = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" },
        wild_name = "the woods",
        map_btn = "Map",
        map_legend = "Bandit Radio",
        map_rumor = "rumor",
        map_kind = { contact = "Contact", move = "Moving", move_dir = "Moving", arrive = "Arrived",
            loot = "Looting", camp = "Camp", rest = "Resting", gunfire = "Gunshots",
            fight_zombies = "Fighting zombies", overrun = "Overrun", hunt = "Hunting",
            approach = "Closing in", clash = "Clash", loss = "Losses", wiped = "Wiped out",
            reinforced = "Reinforced", gathering = "Gathering" },
        lang_auto = "AUTO",
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
        around = "dans les environs de %s",
        wild = "en pleine nature",
        near_place = "près %s à %s",
        around_place = "près %s, aux environs de %s",
        wild_place = "près %s, en pleine nature",
        lang_btn = "Langue",
        dir_name = { "nord", "nord-est", "est", "sud-est", "sud", "sud-ouest", "ouest", "nord-ouest" },
        wild_name = "la forêt",
        map_btn = "Carte",
        map_legend = "Radio Bandit",
        map_rumor = "rumeur",
        map_kind = { contact = "Contact", move = "En route", move_dir = "En mouvement", arrive = "Arrivé",
            loot = "Pillage", camp = "Camp", rest = "Repos", gunfire = "Coups de feu",
            fight_zombies = "Combat (zombies)", overrun = "Débordés", hunt = "Traque",
            approach = "Approche", clash = "Affrontement", loss = "Pertes", wiped = "Anéantis",
            reinforced = "Renforts", gathering = "Rassemblement" },
        lang_auto = "AUTO",
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

-- Langue choisie par le joueur dans l'interface ("EN", "FR" ou nil = langue du jeu)
BanditRadio.langOverride = nil

function BanditRadio.lang()
    if BanditRadio.langOverride and BanditRadio.Strings[BanditRadio.langOverride] then
        return BanditRadio.langOverride
    end
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

---------------------------------------------------------------------------
-- Lieux "nommables" : type de bâtiment déduit du nom de la pièce (room def)
-- où se trouvent les bandits. Recherche par sous-chaîne, dans l'ordre.
-- FR : la forme inclut l'article après "près" ("d'une station-service").
---------------------------------------------------------------------------
BanditRadio.Places = {
    { key = "gasstore",  EN = "a gas station",      FR = "d'une station-service" },
    { key = "police",    EN = "the police station", FR = "du commissariat" },
    { key = "prison",    EN = "the prison",         FR = "de la prison" },
    { key = "army",      EN = "a military post",    FR = "d'un poste militaire" },
    { key = "military",  EN = "a military post",    FR = "d'un poste militaire" },
    { key = "hospital",  EN = "the hospital",       FR = "de l'hôpital" },
    { key = "medic",     EN = "a clinic",           FR = "d'une clinique" },
    { key = "pharma",    EN = "a pharmacy",         FR = "d'une pharmacie" },
    { key = "gunstore",  EN = "a gun store",        FR = "d'une armurerie" },
    { key = "grocer",    EN = "a grocery store",    FR = "d'une épicerie" },
    { key = "zippee",    EN = "a convenience store",FR = "d'une supérette" },
    { key = "church",    EN = "a church",           FR = "d'une église" },
    { key = "school",    EN = "a school",           FR = "d'une école" },
    { key = "classroom", EN = "a school",           FR = "d'une école" },
    { key = "fire",      EN = "the fire station",   FR = "de la caserne" },
    { key = "warehouse", EN = "a warehouse",        FR = "d'un entrepôt" },
    { key = "factory",   EN = "a factory",          FR = "d'une usine" },
    { key = "mechanic",  EN = "a garage",           FR = "d'un garage" },
    { key = "garage",    EN = "a garage",           FR = "d'un garage" },
    { key = "barn",      EN = "a farm",             FR = "d'une ferme" },
    { key = "farm",      EN = "a farm",             FR = "d'une ferme" },
    { key = "bar",       EN = "a bar",              FR = "d'un bar" },
    { key = "restaurant",EN = "a restaurant",       FR = "d'un restaurant" },
    { key = "motel",     EN = "a motel",            FR = "d'un motel" },
    { key = "bank",      EN = "a bank",             FR = "d'une banque" },
    { key = "office",    EN = "offices",            FR = "de bureaux" },
    { key = "kitchen",   EN = "a house",            FR = "d'une maison" },
    { key = "bedroom",   EN = "a house",            FR = "d'une maison" },
    { key = "livingroom",EN = "a house",            FR = "d'une maison" },
    { key = "bathroom",  EN = "a house",            FR = "d'une maison" },
}

function BanditRadio.placeLabel(room)
    if type(room) ~= "string" or room == "" then return nil end
    local r, lang = string.lower(room), BanditRadio.lang()
    for _, p in ipairs(BanditRadio.Places) do
        if string.find(r, p.key, 1, true) then return p[lang] or p.EN end
    end
    return nil
end

-- Position volontairement imprécise : "près de Muldraugh",
-- "près d'une station-service à Muldraugh", "dans les environs de Rosewood"...
function BanditRadio.describePos(x, y, room)
    local T = BanditRadio.T
    local place = BanditRadio.placeLabel(room)
    local loc, d = BanditRadio.nearestLocation(x, y)
    if not loc or d > 2500 then
        return place and string.format(T("wild_place"), place) or T("wild")
    end
    if d < 700 then
        return place and string.format(T("near_place"), place, loc.name) or string.format(T("near"), loc.name)
    end
    return place and string.format(T("around_place"), place, loc.name) or string.format(T("around"), loc.name)
end

-- Zone large (niveau ville) : utilisée pour les infos partielles et les rumeurs
function BanditRadio.describeArea(x, y)
    local T = BanditRadio.T
    local loc, d = BanditRadio.nearestLocation(x, y)
    if not loc or d > 2500 then return T("wild") end
    if d < 700 then return string.format(T("near"), loc.name) end
    return string.format(T("around"), loc.name)
end

-- Nom court d'un endroit (ville la plus proche ou "la forêt")
function BanditRadio.placeName(x, y)
    local loc, d = BanditRadio.nearestLocation(x, y)
    if not loc or d > 1200 then return BanditRadio.T("wild_name") end
    return loc.name
end

---------------------------------------------------------------------------
-- Couleurs des factions sur la carte (stables, surchargeables)
---------------------------------------------------------------------------
BanditRadio.FactionColors = BanditRadio.FactionColors or {}
BanditRadio.Palette = {
    { r = 0.90, g = 0.20, b = 0.20 }, { r = 0.20, g = 0.55, b = 0.95 }, { r = 0.95, g = 0.65, b = 0.10 },
    { r = 0.60, g = 0.30, b = 0.85 }, { r = 0.20, g = 0.80, b = 0.40 }, { r = 0.95, g = 0.40, b = 0.70 },
    { r = 0.10, g = 0.80, b = 0.85 }, { r = 0.70, g = 0.50, b = 0.25 }, { r = 0.85, g = 0.85, b = 0.20 },
    { r = 0.55, g = 0.55, b = 0.60 },
}

function BanditRadio.factionColor(displayName)
    if BanditRadio.FactionColors[displayName] then return BanditRadio.FactionColors[displayName] end
    local h = 7
    local s = tostring(displayName)
    for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
    return BanditRadio.Palette[(h % #BanditRadio.Palette) + 1]
end

---------------------------------------------------------------------------
-- Noms de faction : "12_Militia" -> "Milice" (FR) / "Militia" (EN)
---------------------------------------------------------------------------
BanditRadio.ClanNames = {
    militia     = { EN = "Militia",       FR = "Milice" },
    military    = { EN = "Military",      FR = "Militaires" },
    army        = { EN = "Army",          FR = "Armée" },
    soldier     = { EN = "Soldiers",      FR = "Soldats" },
    police      = { EN = "Police",        FR = "Police" },
    cop         = { EN = "Cops",          FR = "Flics" },
    swat        = { EN = "SWAT",          FR = "SWAT" },
    criminal    = { EN = "Criminals",     FR = "Criminels" },
    thug        = { EN = "Thugs",         FR = "Voyous" },
    gang        = { EN = "Gang",          FR = "Gang" },
    biker       = { EN = "Bikers",        FR = "Motards" },
    raider      = { EN = "Raiders",       FR = "Pillards" },
    looter      = { EN = "Looters",       FR = "Pilleurs" },
    bandit      = { EN = "Bandits",       FR = "Bandits" },
    survivalist = { EN = "Survivalists",  FR = "Survivalistes" },
    survivor    = { EN = "Survivors",     FR = "Survivants" },
    prisoner    = { EN = "Escaped convicts", FR = "Évadés" },
    inmate      = { EN = "Escaped convicts", FR = "Évadés" },
    convict     = { EN = "Escaped convicts", FR = "Évadés" },
    cannibal    = { EN = "Cannibals",     FR = "Cannibales" },
    cult        = { EN = "Cult",          FR = "Secte" },
    psycho      = { EN = "Psychos",       FR = "Psychopathes" },
    hunter      = { EN = "Hunters",       FR = "Chasseurs" },
    redneck     = { EN = "Rednecks",      FR = "Rednecks" },
    hillbilly   = { EN = "Hillbillies",   FR = "Péquenauds" },
    veteran     = { EN = "Veterans",      FR = "Vétérans" },
    scientist   = { EN = "Scientists",    FR = "Scientifiques" },
    doctor      = { EN = "Doctors",       FR = "Médecins" },
    mercenar    = { EN = "Mercenaries",   FR = "Mercenaires" },
    security    = { EN = "Security",      FR = "Sécurité" },
    guard       = { EN = "Guards",        FR = "Gardes" },
    citizen     = { EN = "Citizens",      FR = "Civils" },
    civilian    = { EN = "Civilians",     FR = "Civils" },
}

function BanditRadio.prettyClan(raw)
    if type(raw) ~= "string" or raw == "" then return "?" end
    -- Retire le préfixe numérique ("12_Militia" -> "Militia")
    local name = string.gsub(raw, "^%d+[_%-%s]*", "")
    if name == "" then name = raw end
    local lower, lang = string.lower(name), BanditRadio.lang()
    -- Ordre stable : clés les plus longues d'abord ("militia" avant "army"...)
    if not BanditRadio._clanKeys then
        local keys = {}
        for k in pairs(BanditRadio.ClanNames) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
        BanditRadio._clanKeys = keys
    end
    for _, key in ipairs(BanditRadio._clanKeys) do
        if string.find(lower, key, 1, true) then
            local t = BanditRadio.ClanNames[key]
            return t[lang] or t.EN
        end
    end
    -- Inconnu : on nettoie juste ("dark_riders" -> "Dark Riders")
    name = string.gsub(name, "[_%-]+", " ")
    name = string.gsub(name, "(%l)(%u)", "%1 %2")
    name = string.gsub(name, "(%a)([%w]*)", function(a, b) return string.upper(a) .. b end)
    return name
end

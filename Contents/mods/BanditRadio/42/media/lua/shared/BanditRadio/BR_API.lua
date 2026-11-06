-- Bandit Radio - API publique pour les autres mods
--
-- Exemple (dans ton propre mod, fichier shared) :
--
--   require "BanditRadio/BR_API"
--   BanditRadio.API.addTown("Mon Village", 5000, 7000)
--   BanditRadio.API.addClanName("cartel", { EN = "Cartel", FR = "Cartel" })
--   BanditRadio.API.setFactionColor("Cartel", 0.9, 0.1, 0.9)
--   BanditRadio.API.addMessages("FR", "convoy", { full = "Convoi de {n} véhicules {pos} !" })
--   BanditRadio.API.addDetector("convoy", function(state, groups, scan, emit)
--       for _, g in ipairs(groups) do
--           if g.vehicle >= 3 then emit(g, "convoy") end
--       end
--   end)
--   BanditRadio.API.onReport(function(report, text) print(text) end)   -- côté client

require "BanditRadio/BR_Config"
require "BanditRadio/BR_Messages"

BanditRadio.API = BanditRadio.API or { detectors = {}, listeners = {} }
local API = BanditRadio.API

-- Ajoute une ville ou un lieu nommé (utilisé pour les destinations et les positions)
function API.addTown(name, x, y)
    table.insert(BanditRadio.Locations, { name = name, x = x, y = y })
end

-- Ajoute un type de bâtiment reconnu ("key" = morceau du nom de pièce PZ)
function API.addPlace(key, labels)
    local p = { key = key }
    for lang, txt in pairs(labels) do p[lang] = txt end
    table.insert(BanditRadio.Places, 1, p)
end

-- Ajoute un nom de faction traduit ("key" = morceau du nom de clan Bandits)
function API.addClanName(key, labels)
    BanditRadio.ClanNames[string.lower(key)] = labels
    BanditRadio._clanKeys = nil
end

-- Force la couleur d'une faction sur la carte (nom affiché, ex. "Milice")
function API.setFactionColor(displayName, r, g, b)
    BanditRadio.FactionColors = BanditRadio.FactionColors or {}
    BanditRadio.FactionColors[displayName] = { r = r, g = g, b = b }
end

-- Ajoute / remplace des messages pour un type d'événement
function API.addMessages(lang, kind, levels)
    BanditRadio.Messages[lang] = BanditRadio.Messages[lang] or {}
    BanditRadio.Messages[lang][kind] = levels
end

-- Ajoute un détecteur d'événements (exécuté côté serveur à chaque analyse)
-- fn(state, groups, scan, emit) ; emit(group, kind, extraFields, level)
function API.addDetector(name, fn)
    table.insert(API.detectors, { name = name, fn = fn })
end

-- Écoute les rapports reçus côté client : fn(report, formattedText)
function API.onReport(fn)
    table.insert(API.listeners, fn)
end

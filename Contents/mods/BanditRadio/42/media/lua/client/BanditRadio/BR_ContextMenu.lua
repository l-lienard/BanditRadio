-- Bandit Radio - menus clic droit (inventaire + debug)

require "BanditRadio/BR_Config"
require "BanditRadio/BR_Client"

local C = BanditRadio.Client
local T = BanditRadio.T

local function findRadio(items)
    for _, entry in ipairs(items) do
        local item = entry
        if type(entry) == "table" and entry.items then item = entry.items[1] end
        if item and item.getFullType and item:getFullType() == BanditRadio.ITEM then return item end
    end
    return nil
end

local function onInventoryMenu(playerNum, context, items)
    local radio = findRadio(items)
    if not radio then return end
    local player = getSpecificPlayer(playerNum)

    -- 1. Allumer / éteindre (mode "radio portable" : messages au-dessus du joueur)
    if C.active == radio then
        context:addOption(T("ctx_stop"), player, function() C.stop() end)
    else
        local opt = context:addOption(T("ctx_listen"), player, function(p) C.start(p, radio) end)
        if C.getCharge(radio) <= 0 or radio:isBroken() then opt.notAvailable = true end
    end

    -- 2. Interface (journal + factions), utilisable même radio éteinte
    local label = T("ctx_open")
    if C.unread > 0 then label = label .. " (" .. string.format(T("unread"), C.unread) .. ")" end
    context:addOption(label, player, function() C.openLog(radio) end)

    local battOpt = context:addOption(T("ctx_battery") .. string.format(" (%d%%)", math.floor(C.getCharge(radio))),
        player, function(p) C.replaceBattery(p, radio) end)
    local inv = player:getInventory()
    if not (inv:getFirstTypeRecurse("Base.Battery") or inv:getFirstTypeRecurse("Battery")) then
        battOpt.notAvailable = true
    end
end
Events.OnFillInventoryObjectContextMenu.Add(onInventoryMenu)

-- Option de test : uniquement en mode debug (solo)
local function onWorldMenu(playerNum, context)
    if not isDebugEnabled() then return end
    local player = getSpecificPlayer(playerNum)
    context:addOption(T("ctx_debug"), player, function(p)
        p:getInventory():AddItem(BanditRadio.ITEM)
    end)
end
Events.OnFillWorldObjectContextMenu.Add(onWorldMenu)

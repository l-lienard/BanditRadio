-- Bandit Radio - fenêtre d'écoute (onglets Interceptions / Factions)

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "BanditRadio/BR_Config"

BanditRadio.Window = ISCollapsableWindow:derive("BanditRadioWindow")
local W = BanditRadio.Window
local T = BanditRadio.T

local FONT = UIFont.Small
local FONT_TITLE = UIFont.Medium
local PAD = 10

-- Couleurs façon écran radio
local COL = {
    bg      = { r = 0.04, g = 0.06, b = 0.04, a = 0.92 },
    text    = { r = 0.55, g = 1.00, b = 0.55 },
    dim     = { r = 0.35, g = 0.55, b = 0.35 },
    warn    = { r = 1.00, g = 0.75, b = 0.30 },
    danger  = { r = 1.00, g = 0.35, b = 0.30 },
    new     = { r = 1.00, g = 0.95, b = 0.45 },
}

-- Noms lisibles des programmes de Bandits (repli : nom brut)
local ACTIVITY = {
    EN = { Bandit = "raiding", Looter = "looting", Companion = "escorting", Thief = "stealing",
           Defend = "defending", Clan = "patrolling", Shahid = "suicide attack" },
    FR = { Bandit = "raid", Looter = "pillage", Companion = "escorte", Thief = "vol",
           Defend = "défense", Clan = "patrouille", Shahid = "attaque suicide" },
}

local function activityLabel(a)
    if not a then return T("unknown") end
    local t = ACTIVITY[BanditRadio.lang()] or ACTIVITY.EN
    return t[a] or a
end

local function lineHeight(font)
    return getTextManager():getFontHeight(font or FONT)
end

local function wrap(text, width)
    local tm, lines, cur = getTextManager(), {}, ""
    for word in string.gmatch(text, "%S+") do
        local test = (cur == "") and word or (cur .. " " .. word)
        if tm:MeasureStringX(FONT, test) > width and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = test
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

---------------------------------------------------------------------------
function W.open()
    if W.instance then
        W.instance:setVisible(true)
        W.instance:addToUIManager()
        W.instance:refresh()
        return
    end
    local core = getCore()
    local w, h = 480, 400
    local win = W:new((core:getScreenWidth() - w) / 2, (core:getScreenHeight() - h) / 2, w, h)
    win:initialise()
    win:addToUIManager()
    W.instance = win
end

function W:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = T("title")
    o.resizable = true
    o.minimumWidth, o.minimumHeight = 360, 260
    o.tab = "feed"
    o.scroll = 0
    return o
end

function W:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 6

    self.btnFeed = ISButton:new(PAD, top, 120, 22, T("tab_feed"), self, W.onTab)
    self.btnFeed.internal = "feed"
    self.btnFeed:initialise()
    self:addChild(self.btnFeed)

    self.btnFactions = ISButton:new(PAD + 126, top, 120, 22, T("tab_factions"), self, W.onTab)
    self.btnFactions.internal = "factions"
    self.btnFactions:initialise()
    self:addChild(self.btnFactions)

    self.btnPower = ISButton:new(self.width - PAD - 60, top, 60, 22, "", self, W.onPower)
    self.btnPower:initialise()
    self.btnPower.anchorLeft, self.btnPower.anchorRight = false, true
    self:addChild(self.btnPower)

    self.bodyTop = top + 30
    self:refresh()
end

function W:onTab(button)
    self.tab = button.internal
    self.scroll = 0
end

function W:onPower()
    local C = BanditRadio.Client
    if C.isListening() then
        C.stop()
    elseif C.lastItem then
        C.start(getPlayer(), C.lastItem)
    end
    self:refresh()
end

function W:refresh()
    if self:isVisible() then BanditRadio.Client.unread = 0 end
    if not self.btnPower then return end
    local on = BanditRadio.Client.isListening()
    self.btnPower:setTitle(on and T("on") or T("off"))
    self.btnPower.backgroundColor = on and { r = 0.1, g = 0.45, b = 0.1, a = 1 } or { r = 0.35, g = 0.1, b = 0.1, a = 1 }
end

function W:onMouseWheel(del)
    self.scroll = math.max(0, self.scroll + del * lineHeight() * 2)
    return true
end

---------------------------------------------------------------------------
-- Rendu
---------------------------------------------------------------------------
function W:drawLine(text, y, col, font)
    if y >= self.bodyTop - 2 and y < self.height - 34 then
        self:drawText(text, PAD + 4, y, col.r, col.g, col.b, col.a or 1, font or FONT)
    end
end

function W:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local C = BanditRadio.Client

    -- Fond de l'écran radio
    local bx, by = PAD, self.bodyTop
    local bw, bh = self.width - PAD * 2, self.height - self.bodyTop - 36
    self:drawRect(bx, by, bw, bh, COL.bg.a, COL.bg.r, COL.bg.g, COL.bg.b)
    self:drawRectBorder(bx, by, bw, bh, 0.6, 0.25, 0.5, 0.25)

    -- Surligner l'onglet actif
    local active = (self.tab == "feed") and self.btnFeed or self.btnFactions
    self:drawRectBorder(active.x - 1, active.y - 1, active.width + 2, active.height + 2, 1, 0.55, 1, 0.55)

    self:setStencilRect(bx, by, bw, bh)
    local y = by + 6 - self.scroll
    local lh = lineHeight()

    if self.tab == "feed" then
        if not C.isListening() then
            self:drawLine(T("off_banner"), y, COL.warn)
            y = y + lh + 6
        end
        if #C.feed == 0 then
            self:drawLine(T("no_signal"), y, COL.dim)
        end
        for _, e in ipairs(C.feed) do
            local col = BanditRadio.colorFor(e.kind)
            if e.clarity < 0.4 then col = COL.dim end
            local prefix = e.time .. "  " .. (e.missed and (T("missed") .. " ") or "")
            local lines = wrap(prefix .. e.text, bw - 16)
            for _, l in ipairs(lines) do
                self:drawLine(l, y, col)
                y = y + lh
            end
            y = y + 4
        end
    else
        if #C.factions == 0 then self:drawLine(T("no_faction"), y, COL.dim) end
        for _, f in ipairs(C.factions) do
            self:drawLine(f.name, y, COL.new, FONT_TITLE)
            y = y + lineHeight(FONT_TITLE)
            local weapons = string.format("%d %s / %d %s", f.fire, T("armed_fire"), f.melee, T("armed_melee"))
            local last = f.lastX and BanditRadio.describePos(f.lastX, f.lastY) or T("unknown")
            local hostile = (f.hostile == nil) and T("unknown") or (f.hostile and T("yes") or T("no"))
            local rows = {
                T("f_members") .. " : " .. f.members .. "   " .. T("f_groups") .. " : " .. f.groups,
                T("f_weapons") .. " : " .. weapons,
                T("f_last") .. " : " .. last,
                T("f_activity") .. " : " .. activityLabel(f.activity) .. "   " .. T("f_hostile") .. " : " .. hostile,
                T("f_losses") .. " : " .. f.losses,
            }
            for _, r in ipairs(rows) do
                self:drawLine("  " .. r, y, COL.text)
                y = y + lh
            end
            y = y + 8
        end
    end
    self:clearStencilRect()

    -- Limiter le défilement à la hauteur du contenu
    local contentH = (y + self.scroll) - (by + 6)
    self.scroll = math.min(self.scroll, math.max(0, contentH - bh + 12))

    -- Barre de pile
    local item = C.active or C.lastItem
    local charge = item and C.getCharge(item) or 0
    local barY = self.height - 28
    self:drawText(T("battery"), PAD, barY, 0.8, 0.8, 0.8, 1, FONT)
    local bxx = PAD + getTextManager():MeasureStringX(FONT, T("battery")) + 8
    local bww = self.width - bxx - PAD - 50
    self:drawRect(bxx, barY + 3, bww, 10, 0.8, 0.1, 0.1, 0.1)
    local cr = charge < 20 and 1 or 0.3
    self:drawRect(bxx, barY + 3, bww * charge / 100, 10, 0.9, cr, 0.85, 0.3)
    self:drawText(string.format("%d%%", math.floor(charge)), bxx + bww + 6, barY, 0.8, 0.8, 0.8, 1, FONT)
end

function W:close()
    ISCollapsableWindow.close(self)
end

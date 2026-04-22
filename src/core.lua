local addonName, ns = ...

-- Upvalues
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAssist = UnitCanAssist
local UnitClass = UnitClass
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local issecretvalue = issecretvalue
local math_max = math.max
local math_floor = math.floor
local strmatch = string.match
local select = select
local pairs = pairs

-- State
local currentScale
local currentOffsetX
local currentOffsetY
local currentAnchor
local currentRelativePoint

-- Cache
local playerClass
local myBuffSpells

-- Function declarations
local UnitHasMyRaidBuff

ns.indicatorPool = {}
ns.unitRegistry = {}

local function GetSafeIconSize(frame)
    local height = frame:GetHeight()

    -- frames can return secret values for dimensions
    if not issecretvalue(height) then
        local result = height * currentScale
        frame._missingBuffCachedSize = result
        return math_max(12, math_floor(result))
    end

    return math_max(12, math_floor(frame._missingBuffCachedSize or (40 * currentScale)))
end

function ns.UpdateSettings()
    currentScale = ns.db.iconScale
    currentOffsetX = ns.db.offsetX
    currentOffsetY = ns.db.offsetY
    currentAnchor = ns.db.anchor
    currentRelativePoint = ns.db.relativePoint

    for i = 1, #ns.indicatorPool do
        local indicator = ns.indicatorPool[i]

        indicator:ClearAllPoints()
        indicator:SetPoint(currentAnchor, indicator.parentFrame, currentRelativePoint, currentOffsetX, currentOffsetY)
        indicator._currentOffsetX = currentOffsetX
        indicator._currentOffsetY = currentOffsetY
        indicator._currentAnchor = currentAnchor
        indicator._currentRelativePoint = currentRelativePoint

        local iconSize = GetSafeIconSize(indicator.parentFrame)
        if indicator._currentSize ~= iconSize then
            indicator:SetSize(iconSize, iconSize)
            indicator._currentSize = iconSize
        end
    end
end

function ns.CreateIndicator(frame)
    local indicator = CreateFrame("Frame", nil, frame)
    indicator.parentFrame = frame

    -- avoid being hidden behind the normal buffs/debuffs
    indicator:SetFrameLevel(frame:GetFrameLevel() + 5)

    local border = indicator:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local tex = indicator:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", indicator, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -1, 1)
    tex:SetTexture(ns.displayTexture)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    table.insert(ns.indicatorPool, indicator)
    return indicator
end

local function UpdateIndicator(frame)
    if frame.isPreviewFrame then return end

    local unit = frame.unit
    local displayedUnit = frame.displayedUnit

    if unit and (strmatch(unit, "target") or strmatch(unit, "^nameplate") or strmatch(unit, "pet")) then return end

    local indicator = frame.MissingBuffIndicator

    if not indicator then
        if not UnitExists(unit) then return end
        indicator = ns.CreateIndicator(frame)
        frame.MissingBuffIndicator = indicator
    end

    if indicator._lastUnit ~= unit then
        if indicator._lastUnit then
            ns.unitRegistry[indicator._lastUnit][indicator] = nil
        end
        if unit then
            ns.unitRegistry[unit] = ns.unitRegistry[unit] or {}
            ns.unitRegistry[unit][indicator] = true
        end
        indicator._lastUnit = unit
    end

    if indicator._lastDisplayedUnit ~= displayedUnit then
        if indicator._lastDisplayedUnit then
            ns.unitRegistry[indicator._lastDisplayedUnit][indicator] = nil
        end
        if displayedUnit then
            ns.unitRegistry[displayedUnit] = ns.unitRegistry[displayedUnit] or {}
            ns.unitRegistry[displayedUnit][indicator] = true
        end
        indicator._lastDisplayedUnit = displayedUnit
    end

    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitCanAssist("player", unit) then
        indicator:Hide()
        return
    end

    if indicator._currentOffsetX ~= currentOffsetX or indicator._currentOffsetY ~= currentOffsetY
    or indicator._currentAnchor ~= currentAnchor or indicator._currentRelativePoint ~= currentRelativePoint then
        indicator:ClearAllPoints()
        indicator:SetPoint(currentAnchor, frame, currentRelativePoint, currentOffsetX, currentOffsetY)
        indicator._currentOffsetX = currentOffsetX
        indicator._currentOffsetY = currentOffsetY
        indicator._currentAnchor = currentAnchor
        indicator._currentRelativePoint = currentRelativePoint
    end

    local iconSize = GetSafeIconSize(frame)

    if indicator._currentSize ~= iconSize then
        indicator:SetSize(iconSize, iconSize)
        indicator._currentSize = iconSize
    end

    if not UnitHasMyRaidBuff(unit) then
        indicator:Show()
    else
        indicator:Hide()
    end
end

local function UpdateIndicatorsForUnit(unit)
    local registry = ns.unitRegistry[unit]
    if registry then
        for indicator in pairs(registry) do
            if indicator.parentFrame:IsVisible() then
                UpdateIndicator(indicator.parentFrame)
            end
        end
    end
end

local function UpdateAllIndicators()
    for i = 1, #ns.indicatorPool do
        local indicator = ns.indicatorPool[i]
        local frame = indicator.parentFrame
        if not frame.isPreviewFrame and frame:IsVisible() then
            UpdateIndicator(frame)
        end
    end
end

local function OnLoad(self, event)
    ns.Config.InitDB()

    playerClass = select(2, UnitClass("player"))
    myBuffSpells = ns.RAID_BUFFS[playerClass]

    ns.displayTexture = C_Spell.GetSpellTexture(myBuffSpells and myBuffSpells[1] or 403197)

    ns.UpdateSettings()
    ns.SetupOptions()
    ns.SetupSlashHandler()

    -- if the player's class doesn't have any buffs we care about, there's no point in wasting cycles
    if not myBuffSpells then return end

    if playerClass == "EVOKER" then
        -- Blessing of the Bronze applies unique spellids per class
        UnitHasMyRaidBuff = function(unit)
            local targetClass = select(2, UnitClass(unit))
            local spellID = ns.EVOKER_AURA_MAP[targetClass]
            return spellID and GetUnitAuraBySpellID(unit, spellID) ~= nil
        end
    else
        UnitHasMyRaidBuff = function(unit)
            for i = 1, #myBuffSpells do
                if GetUnitAuraBySpellID(unit, myBuffSpells[i]) then
                    return true
                end
            end
            return false
        end
    end

    hooksecurefunc("CompactUnitFrame_UpdateAll", UpdateIndicator)

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        OnLoad(self, event)
    elseif event == "UNIT_AURA" then
        UpdateIndicatorsForUnit(unit)
    else
        UpdateAllIndicators()
    end
end)

function MissingBuffs_OpenOptions()
    if InCombatLockdown() then
        print("MissingBuffs: Cannot open settings while in combat.")
        return
    end
    Settings.OpenToCategory(ns.CategoryID)
end

function MissingBuffs_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(addonName, 1, 1, 1)
    GameTooltip:AddLine("Click to open settings.", 1, 1, 1)
    GameTooltip:Show()
end

function MissingBuffs_OnCompartmentLeave()
    GameTooltip:Hide()
end

function ns.SlashCommandHandler(msg)
    if InCombatLockdown() then
        print("MissingBuffs: Cannot open settings while in combat.")
        return
    end
    Settings.OpenToCategory(ns.CategoryID)
end

function ns.SetupSlashHandler()
    SLASH_MISSINGBUFFS1 = "/mb"
    SLASH_MISSINGBUFFS2 = "/missingbuffs"
    SlashCmdList["MISSINGBUFFS"] = function(msg) ns.SlashCommandHandler(msg) end
end

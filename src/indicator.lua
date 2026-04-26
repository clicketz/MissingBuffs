local addonName, ns = ...

-- Upvalues
local UnitExists = UnitExists
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local GetSpellTexture = C_Spell.GetSpellTexture
local issecretvalue = issecretvalue or function() return false end

ns.IndicatorMixin = {}

function ns.IndicatorMixin:OnLoad(parentFrame)
    self.parentFrame = parentFrame
    self:SetFrameLevel(parentFrame:GetFrameLevel() + 5)

    local border = self:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    local tex = self:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
    tex:SetTexture(ns.displayTexture)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    self.isShown = false
    self.isValid = false
end

function ns.IndicatorMixin:GetSafeIconSize()
    local height = self.parentFrame:GetHeight()

    if not issecretvalue(height) then
        local result = height * ns.db.iconScale
        self.parentFrame.missingBuffCachedSize = result
        return math.max(12, math.floor(result))
    end

    return math.max(12, math.floor(self.parentFrame.missingBuffCachedSize or (40 * ns.db.iconScale)))
end

function ns.IndicatorMixin:UpdateLayout()
    if self.currentOffsetX ~= ns.db.offsetX or self.currentOffsetY ~= ns.db.offsetY
    or self.currentAnchor ~= ns.db.anchor or self.currentRelativePoint ~= ns.db.relativePoint then
        self:ClearAllPoints()
        self:SetPoint(ns.db.anchor, self.parentFrame, ns.db.relativePoint, ns.db.offsetX, ns.db.offsetY)
        self.currentOffsetX = ns.db.offsetX
        self.currentOffsetY = ns.db.offsetY
        self.currentAnchor = ns.db.anchor
        self.currentRelativePoint = ns.db.relativePoint
    end

    local iconSize = self:GetSafeIconSize()

    if self.currentSize ~= iconSize then
        self:SetSize(iconSize, iconSize)
        self.currentSize = iconSize
    end
end

function ns.IndicatorMixin:Update()
    if self.parentFrame.isPreviewFrame then return end

    local unit = self.parentFrame.unit
    local displayedUnit = self.parentFrame.displayedUnit

    if unit and (string.match(unit, "target") or string.match(unit, "^nameplate") or string.match(unit, "pet")) then return end

    if self.lastUnit ~= unit then
        if self.lastUnit then
            ns.unitRegistry[self.lastUnit][self] = nil
        end
        if unit then
            ns.unitRegistry[unit] = ns.unitRegistry[unit] or {}
            ns.unitRegistry[unit][self] = true
        end
        self.lastUnit = unit
    end

    if self.lastDisplayedUnit ~= displayedUnit then
        if self.lastDisplayedUnit then
            ns.unitRegistry[self.lastDisplayedUnit][self] = nil
        end
        if displayedUnit then
            ns.unitRegistry[displayedUnit] = ns.unitRegistry[displayedUnit] or {}
            ns.unitRegistry[displayedUnit][self] = true
        end
        self.lastDisplayedUnit = displayedUnit
    end

    local hasBuff, auraInstanceID = false, nil
    if UnitExists(unit) then
        hasBuff, auraInstanceID = ns.UnitHasMyRaidBuff(unit)
    end
    self.auraInstanceID = auraInstanceID

    local isValid = ns.IsUnitValid(unit)
    self.isValid = isValid

    if not isValid then
        self:Hide()
        self.isShown = false
        return
    end

    self:UpdateLayout()

    if not hasBuff then
        self:Show()
        self.isShown = true
    else
        self:Hide()
        self.isShown = false
    end
end

function ns.GetIndicator(frame)
    local indicator = frame.MissingBuffIndicator

    if not indicator then
        if not UnitExists(frame.unit) then return nil end

        indicator = CreateFrame("Frame", nil, frame)
        Mixin(indicator, ns.IndicatorMixin)
        indicator:OnLoad(frame)

        frame.MissingBuffIndicator = indicator
        table.insert(ns.indicatorPool, indicator)
    end

    return indicator
end

function ns.InitBuffTracking()
    local playerClass = select(2, UnitClass("player"))
    local myBuffSpells = ns.RAID_BUFFS[playerClass]

    if not myBuffSpells then return false end

    ns.displayTexture = GetSpellTexture(myBuffSpells[1])
    ns.allMyBuffSpells = {}

    local buffList = myBuffSpells

    if playerClass == "EVOKER" then
        buffList = {}
        for _, spellID in pairs(ns.EVOKER_AURA_MAP) do
            table.insert(buffList, spellID)
        end
    end

    for i = 1, #buffList do
        ns.allMyBuffSpells[buffList[i]] = true
    end

    ns.UnitHasMyRaidBuff = function(unit)
        for i = 1, #buffList do
            local aura = GetUnitAuraBySpellID(unit, buffList[i])
            if aura then
                return true, aura.auraInstanceID
            end
        end
        return false, nil
    end

    return true
end

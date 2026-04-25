local addonName, ns = ...

-- Upvalues
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAssist = UnitCanAssist
local UnitClass = UnitClass
local GetUnitAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID
local issecretvalue = issecretvalue or function() return false end

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
        frame.missingBuffCachedSize = result
        return math.max(12, math.floor(result))
    end

    return math.max(12, math.floor(frame.missingBuffCachedSize or (40 * currentScale)))
end

local function IsUnitValid(unit)
    return UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitCanAssist("player", unit)
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
        indicator.currentOffsetX = currentOffsetX
        indicator.currentOffsetY = currentOffsetY
        indicator.currentAnchor = currentAnchor
        indicator.currentRelativePoint = currentRelativePoint

        local iconSize = GetSafeIconSize(indicator.parentFrame)
        if indicator.currentSize ~= iconSize then
            indicator:SetSize(iconSize, iconSize)
            indicator.currentSize = iconSize
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

    indicator.isShown = false
    indicator.isValid = false

    table.insert(ns.indicatorPool, indicator)
    return indicator
end

local function UpdateIndicator(frame)
    if frame.isPreviewFrame then return end

    local unit = frame.unit
    local displayedUnit = frame.displayedUnit

    if unit and (string.match(unit, "target") or string.match(unit, "^nameplate") or string.match(unit, "pet")) then return end

    local indicator = frame.MissingBuffIndicator

    if not indicator then
        if not UnitExists(unit) then return end
        indicator = ns.CreateIndicator(frame)
        frame.MissingBuffIndicator = indicator
    end

    if indicator.lastUnit ~= unit then
        if indicator.lastUnit then
            ns.unitRegistry[indicator.lastUnit][indicator] = nil
        end
        if unit then
            ns.unitRegistry[unit] = ns.unitRegistry[unit] or {}
            ns.unitRegistry[unit][indicator] = true
        end
        indicator.lastUnit = unit
    end

    if indicator.lastDisplayedUnit ~= displayedUnit then
        if indicator.lastDisplayedUnit then
            ns.unitRegistry[indicator.lastDisplayedUnit][indicator] = nil
        end
        if displayedUnit then
            ns.unitRegistry[displayedUnit] = ns.unitRegistry[displayedUnit] or {}
            ns.unitRegistry[displayedUnit][indicator] = true
        end
        indicator.lastDisplayedUnit = displayedUnit
    end

    local hasBuff, auraInstanceID = false, nil
    if UnitExists(unit) then
        hasBuff, auraInstanceID = UnitHasMyRaidBuff(unit)
    end
    indicator.auraInstanceID = auraInstanceID

    local isValid = IsUnitValid(unit)
    indicator.isValid = isValid

    if not isValid then
        indicator:Hide()
        indicator.isShown = false
        return
    end

    if indicator.currentOffsetX ~= currentOffsetX or indicator.currentOffsetY ~= currentOffsetY
    or indicator.currentAnchor ~= currentAnchor or indicator.currentRelativePoint ~= currentRelativePoint then
        indicator:ClearAllPoints()
        indicator:SetPoint(currentAnchor, frame, currentRelativePoint, currentOffsetX, currentOffsetY)
        indicator.currentOffsetX = currentOffsetX
        indicator.currentOffsetY = currentOffsetY
        indicator.currentAnchor = currentAnchor
        indicator.currentRelativePoint = currentRelativePoint
    end

    local iconSize = GetSafeIconSize(frame)

    if indicator.currentSize ~= iconSize then
        indicator:SetSize(iconSize, iconSize)
        indicator.currentSize = iconSize
    end

    if not hasBuff then
        indicator:Show()
        indicator.isShown = true
    else
        indicator:Hide()
        indicator.isShown = false
    end
end

local function OnUnitAura(unitTarget, updateInfo)
    local registry = ns.unitRegistry[unitTarget]
    if not registry then return end

    local needsFullUpdate = not updateInfo or updateInfo.isFullUpdate

    if not needsFullUpdate then
        if updateInfo.addedAuras then
            for _, aura in ipairs(updateInfo.addedAuras) do
                if not issecretvalue(aura.spellId) and ns.allMyBuffSpells[aura.spellId] then
                    needsFullUpdate = true
                    break
                end
            end
        end

        if not needsFullUpdate and updateInfo.removedAuraInstanceIDs then
            for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
                for indicator in pairs(registry) do
                    if indicator.auraInstanceID == auraInstanceID then
                        needsFullUpdate = true
                        break
                    end
                end
                if needsFullUpdate then break end
            end
        end

        if not needsFullUpdate then
            local currentValid = IsUnitValid(unitTarget)
            for indicator in pairs(registry) do
                if indicator.isValid ~= currentValid then
                    needsFullUpdate = true
                    break
                end
            end
        end
    end

    if needsFullUpdate then
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

    ns.allMyBuffSpells = {}

    if playerClass == "EVOKER" then
        for _, spellID in pairs(ns.EVOKER_AURA_MAP) do
            ns.allMyBuffSpells[spellID] = true
        end

        UnitHasMyRaidBuff = function(unit)
            local targetClass = select(2, UnitClass(unit))
            local spellID = ns.EVOKER_AURA_MAP[targetClass]
            local aura = spellID and GetUnitAuraBySpellID(unit, spellID)
            return aura ~= nil, aura and aura.auraInstanceID
        end
    else
        for i = 1, #myBuffSpells do
            ns.allMyBuffSpells[myBuffSpells[i]] = true
        end

        UnitHasMyRaidBuff = function(unit)
            for i = 1, #myBuffSpells do
                local aura = GetUnitAuraBySpellID(unit, myBuffSpells[i])
                if aura then
                    return true, aura.auraInstanceID
                end
            end
            return false, nil
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
loader:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLoad(self, event)
    elseif event == "UNIT_AURA" then
        OnUnitAura(...)
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

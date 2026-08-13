local addonName, ns = ...

-- Upvalues
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAssist = UnitCanAssist
local UnitIsConnected = UnitIsConnected
local UnitIsVisible = UnitIsVisible
local next = next

ns.indicatorPool = {}
ns.unitRegistry = {}

local dirtyUnits = {}
local isUpdateQueued = false

function ns.IsUnitValid(unit)
    return UnitExists(unit) and UnitIsConnected(unit) and UnitIsVisible(unit) and not UnitIsDeadOrGhost(unit) and UnitCanAssist("player", unit)
end

function ns.UpdateSettings()
    for i = 1, #ns.indicatorPool do
        local indicator = ns.indicatorPool[i]
        indicator:UpdateLayout()
    end
end

local function UpdateIndicator(frame)
    if frame:IsForbidden() or frame.isPreviewFrame then return end

    local unit = frame.unit

    if unit and (string.match(unit, "target") or string.match(unit, "^nameplate") or string.match(unit, "pet")) then
        if frame.MissingBuffIndicator then
            frame.MissingBuffIndicator:SetVisibility(false)
        end
        return
    end

    local indicator = ns.GetIndicator(frame)
    if indicator then
        indicator:Update()
    end
end

local function UpdateIndicatorsForUnit(unitTarget)
    local registry = ns.unitRegistry[unitTarget]
    if registry then
        for indicator in pairs(registry) do
            indicator:Update()
        end
    end
end

local function IsTrackedDisplayUnit(unit)
    if not unit then return false end
    return unit == "player" or string.match(unit, "^party%d+$") ~= nil or string.match(unit, "^raid%d+$") ~= nil
end

local function ProcessDirtyUnits()
    if next(dirtyUnits) then
        for unitTarget in pairs(dirtyUnits) do
            UpdateIndicatorsForUnit(unitTarget)
            dirtyUnits[unitTarget] = nil
        end
    end
    isUpdateQueued = false
end

local function OnUnitAura(unitTarget)
    if not IsTrackedDisplayUnit(unitTarget) or not ns.unitRegistry[unitTarget] then
        return
    end

    dirtyUnits[unitTarget] = true

    if not isUpdateQueued then
        isUpdateQueued = true
        C_Timer.After(0.1, ProcessDirtyUnits)
    end
end

local function UpdateAllIndicators()
    for i = 1, #ns.indicatorPool do
        UpdateIndicator(ns.indicatorPool[i].parentFrame)
    end
end

local function OnLoad(self, event)
    ns.Config.InitDB()

    local classIsTracked = ns.InitBuffTracking()

    ns.UpdateSettings()
    ns.SetupOptions()
    ns.SetupSlashHandler()

    if not classIsTracked then return end

    hooksecurefunc("CompactUnitFrame_UpdateAll", UpdateIndicator)

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_CONNECTION")
    self:RegisterEvent("PARTY_MEMBER_DISABLE")
    self:RegisterEvent("PARTY_MEMBER_ENABLE")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLoad(self, event)
    elseif event == "UNIT_AURA" then
        OnUnitAura(...)
    elseif event == "UNIT_CONNECTION" or event == "PARTY_MEMBER_DISABLE" or event == "PARTY_MEMBER_ENABLE" then
        UpdateIndicatorsForUnit(...)
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

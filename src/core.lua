local addonName, ns = ...

-- Upvalues
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAssist = UnitCanAssist
local issecretvalue = issecretvalue or function() return false end

ns.indicatorPool = {}
ns.unitRegistry = {}

function ns.IsUnitValid(unit)
    return UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitCanAssist("player", unit)
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
            frame.MissingBuffIndicator:Hide()
            frame.MissingBuffIndicator.isShown = false
        end
        return
    end

    local indicator = ns.GetIndicator(frame)
    if indicator then
        indicator:Update()
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
            local currentValid = ns.IsUnitValid(unitTarget)
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
                indicator:Update()
            end
        end
    end
end

local function UpdateAllIndicators()
    for i = 1, #ns.indicatorPool do
        local indicator = ns.indicatorPool[i]
        local frame = indicator.parentFrame
        if frame:IsVisible() then
            UpdateIndicator(frame)
        end
    end
end

local function OnLoad(self, event)
    ns.Config.InitDB()

    if not ns.InitBuffTracking() then return end

    ns.UpdateSettings()
    ns.SetupOptions()
    ns.SetupSlashHandler()

    hooksecurefunc("CompactUnitFrame_UpdateAll", UpdateIndicator)

    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- self:RegisterEvent("PLAYER_REGEN_DISABLED")
    -- self:RegisterEvent("PLAYER_REGEN_ENABLED")
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

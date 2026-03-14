local addonName, ns = ...

function ns.SetupOptions()
    local panel = CreateFrame("Frame", nil, UIParent)
    panel.name = addonName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(addonName)

    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    author:SetFormattedText("|cFFFF7C0AAuthor|r: %s", C_AddOns.GetAddOnMetadata(addonName, "Author"))

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
    version:SetFormattedText("|cFFFF7C0AVersion|r: %s", C_AddOns.GetAddOnMetadata(addonName, "Version"))

    local scaleInput = ns.Libs.CreateNumberInput(panel, "Icon Scale Modifier (Default: 0.4)", "iconScale", function(val)
        ns.UpdateScale(val)
    end)
    scaleInput:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 10, -30)

    local helpPanel = CreateFrame("Frame", nil, panel)
    helpPanel:SetSize(100, 150)
    helpPanel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 20)

    local helpTitle = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    helpTitle:SetPoint("TOPLEFT", 0, 0)
    helpTitle:SetText("Slash Commands")

    local function AddCommand(cmd, desc, prev)
        local c = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
        c:SetText(cmd)

        local d = helpPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        d:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -2)
        d:SetText(desc)
        d:SetTextColor(0.6, 0.6, 0.6, 1)

        return d
    end

    local lastHelp = helpTitle
    lastHelp = AddCommand("/mb", "Open this options menu", lastHelp)
    lastHelp = AddCommand("/missingbuffs", "Alias for /mb", lastHelp)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.OnRefresh = function()
        ns.Libs.RefreshOptions()
    end

    Settings.RegisterAddOnCategory(category)
    ns.CategoryID = category:GetID()

    ns.Libs.RefreshOptions()
end

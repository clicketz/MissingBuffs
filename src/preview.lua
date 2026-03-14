local _, ns = ...

local function UpdatePreviewState(f)
    local width, height = 120, 60
    local scale = 1

    local realFrame = _G["CompactPartyFrameMember1"]

    if realFrame then
        width, height = realFrame:GetSize()
        local parent = f:GetParent()
        local parentScale = parent and parent:GetEffectiveScale() or 1
        if parentScale > 0 then
            scale = realFrame:GetEffectiveScale() / parentScale
        end
    end

    f:SetSize(width, height)
    f:SetScale(scale)

    ns.UpdateSettings()
end

function ns.CreatePreviewFrame(parent)
    local f = CreateFrame("Frame", "MissingBuffsPreview", parent)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -50)
    f:SetSize(120, 60)

    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)

    f.bg = f:CreateTexture(nil, "BORDER")
    f.bg:SetPoint("TOPLEFT", 1, -1)
    f.bg:SetPoint("BOTTOMRIGHT", -1, 1)

    local c = C_ClassColor.GetClassColor(select(2, UnitClass("player")) or "PRIEST")
    f.bg:SetColorTexture(c.r, c.g, c.b, 1)

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    text:SetText("Preview")
    text:SetTextColor(1, 1, 1, 1)

    f.MissingBuffIndicator = ns.CreateIndicator(f)
    f.MissingBuffIndicator:Show()

    parent:HookScript("OnSizeChanged", function()
        UpdatePreviewState(f)
    end)

    parent:HookScript("OnShow", function()
        UpdatePreviewState(f)
    end)

    UpdatePreviewState(f)

    return f
end

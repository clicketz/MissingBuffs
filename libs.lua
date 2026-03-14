local _, ns = ...
ns.Libs = {}

local inputRegistry = {}

function ns.Libs.RefreshOptions()
    for _, element in ipairs(inputRegistry) do
        if element.UpdateValue then
            element:UpdateValue()
        end
    end
end

function ns.Libs.CreateNumberInput(parent, label, key, updateFunc)
    local editbox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editbox:SetSize(60, 20)
    editbox:SetAutoFocus(false)

    local labelText = editbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    labelText:SetPoint("LEFT", editbox, "RIGHT", 10, 0)
    labelText:SetText(label)

    function editbox:UpdateValue()
        self:SetText(tostring(ns.db[key]))
        self:SetCursorPosition(0)
    end

    editbox:SetScript("OnShow", function(self)
        self:UpdateValue()
    end)

    local function SaveValue(self)
        local val = tonumber(self:GetText())
        if val and val ~= ns.db[key] then
            ns.db[key] = val
            if updateFunc then updateFunc(val) end
        else
            self:UpdateValue()
        end
    end

    editbox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    editbox:SetScript("OnEditFocusLost", SaveValue)

    editbox:SetScript("OnEscapePressed", function(self)
        self:UpdateValue()
        self:ClearFocus()
    end)

    table.insert(inputRegistry, editbox)
    return editbox
end

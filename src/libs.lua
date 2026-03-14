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

function ns.Libs.CreateNumberInput(parent, labelText, key, decimalPlaces, updateFunc)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(300, 25)

    local formatStr = decimalPlaces > 0 and ("%." .. decimalPlaces .. "f") or "%d"

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local editbox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editbox:SetPoint("LEFT", label, "RIGHT", 10, 0)
    editbox:SetSize(60, 20)
    editbox:SetAutoFocus(false)

    function container:UpdateValue()
        local val = ns.db[key]
        if val == nil then val = ns.Config.Defaults[key] or 0 end
        editbox:SetText(string.format(formatStr, val))
    end

    container:SetScript("OnShow", function(self)
        self:UpdateValue()
    end)

    local function SaveValue(self)
        local val = tonumber(self:GetText())
        if val then
            val = tonumber(string.format(formatStr, val))
            if val ~= ns.db[key] then
                ns.db[key] = val
                if updateFunc then updateFunc(val) end
            end
        end
        container:UpdateValue()
    end

    editbox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    editbox:SetScript("OnEditFocusLost", SaveValue)

    editbox:SetScript("OnEscapePressed", function(self)
        container:UpdateValue()
        self:ClearFocus()
    end)

    table.insert(inputRegistry, container)
    return container
end

function ns.Libs.CreateSlider(parent, labelText, key, minVal, maxVal, step, decimalPlaces, updateFunc)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(400, 30)

    local formatStr = decimalPlaces > 0 and ("%." .. decimalPlaces .. "f") or "%d"

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("LEFT", label, "RIGHT", 10, 0)
    slider:SetWidth(120)
    slider:SetObeyStepOnDrag(true)
    slider:SetValueStep(step)
    slider:SetMinMaxValues(minVal, maxVal)

    if slider.Text then slider.Text:SetText("") end
    if slider.Low then slider.Low:SetText(minVal) end
    if slider.High then slider.High:SetText(maxVal) end

    local editbox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    editbox:SetSize(45, 20)
    editbox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editbox:SetAutoFocus(false)
    editbox:SetJustifyH("CENTER")

    local isUpdating = false

    function container:UpdateValue()
        local val = ns.db[key]
        if val == nil then val = ns.Config.Defaults[key] or minVal end

        isUpdating = true
        slider:SetValue(val)
        editbox:SetText(string.format(formatStr, val))
        isUpdating = false
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if not isUpdating then
            value = math.floor(value / step + 0.5) * step
            value = tonumber(string.format(formatStr, value))

            if value ~= ns.db[key] then
                ns.db[key] = value
                editbox:SetText(string.format(formatStr, value))
                if updateFunc then updateFunc(value) end
            end
        end
    end)

    local function SaveValue(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, math.floor(val / step + 0.5) * step))
            val = tonumber(string.format(formatStr, val))

            if val ~= ns.db[key] then
                ns.db[key] = val

                isUpdating = true
                slider:SetValue(val)
                isUpdating = false

                if updateFunc then updateFunc(val) end
            end
        end

        self:SetText(string.format(formatStr, ns.db[key]))
    end

    editbox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    editbox:SetScript("OnEditFocusLost", SaveValue)

    editbox:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format(formatStr, ns.db[key]))
        self:ClearFocus()
    end)

    container:SetScript("OnShow", function(self)
        self:UpdateValue()
    end)

    table.insert(inputRegistry, container)
    return container
end

function ns.Libs.CreateDropdown(parent, labelText, key, options, updateFunc)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(350, 25)

    local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local dropdown = CreateFrame("DropdownButton", nil, container, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
    dropdown:SetWidth(120)

    function container:UpdateValue()
        dropdown:SetupMenu(function(owner, rootDescription)
            for _, opt in ipairs(options) do
                rootDescription:CreateRadio(
                    opt,
                    function()
                        local val = ns.db[key]
                        if val == nil then val = ns.Config.Defaults[key] end
                        return val == opt
                    end,
                    function()
                        ns.db[key] = opt
                        if updateFunc then updateFunc(opt) end
                    end
                )
            end
        end)
    end

    container:SetScript("OnShow", function(self)
        self:UpdateValue()
    end)

    table.insert(inputRegistry, container)
    return container
end

local _, ns = ...

ns.Config = {}

ns.Config.Defaults = {
    iconScale = 0.4,
    offsetX = 2,
    offsetY = 0,
}

function ns.Config.InitDB()
    if not MissingBuffsDB then MissingBuffsDB = {} end

    for k, v in pairs(ns.Config.Defaults) do
        if MissingBuffsDB[k] == nil then
            MissingBuffsDB[k] = v
        end
    end

    ns.db = MissingBuffsDB
end

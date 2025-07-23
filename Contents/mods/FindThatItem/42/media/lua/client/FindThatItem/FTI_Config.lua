---@diagnostic disable: undefined-field
local FTI_Config = {}

FTI_Config.trackedItems = {}

FTI_Config.hudIconEnabled = getTexture("media/textures/fti_colored.png")
FTI_Config.hudIconDisabled = getTexture("media/textures/fti_white.png")
FTI_Config.hudEnabled = false

FTI_Config.hudIconSizes = {
    32, 48, 64, 80, 96, 128
}

-- Default window size
FTI_Config.height = 500
FTI_Config.width = 400

FTI_Config.rarityColors = {
    -- target  = { r = 1, g = 0.2, b = 0.2 }, -- vivid red
    epic    = { r = 1, g = 0.2, b = 1 },   -- magenta
    rare    = { r = 0.2, g = 0.6, b = 1 }, -- sky blue
    common  = { r = 0.4, g = 1, b = 0.4 }, -- bright green
    unknown = { r = 1, g = 1, b = 0 },     -- yellow
}

FTI_Config.rarityConfig = {
    -- { key = "target",  label = "UI_FTI_Rarity_Target" },
    { key = "epic",    label = "UI_FTI_Rarity_EPIC" },
    { key = "rare",    label = "UI_FTI_Rarity_RARE" },
    { key = "common",  label = "UI_FTI_Rarity_COMMON" },
    { key = "unknown", label = "UI_FTI_Rarity_UNKNOWN" },
}

FTI_Config.targetedItems = {}

FTI_Config.itemTypes = FTI_Config.itemTypes or {}

function FTI_Config.autogenerateItemRarity()
    local counts = {}
    local nameToFull = {}

    -- Build a map of short name -> full type
    local allItems = getScriptManager():getAllItems()
    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        local fullType = item:getFullName()
        local shortName = fullType:match("%.([^%.]+)$")
        if shortName then
            nameToFull[shortName] = fullType
        end
    end

    -- Scan ProceduralDistributions and count appearances
    local dist = ProceduralDistributions and ProceduralDistributions.list
    if dist then
        for _, distData in pairs(dist) do
            if distData.items then
                for i = 1, #distData.items, 2 do
                    local rawType = distData.items[i]
                    local fullType = nameToFull[rawType]
                    if fullType then
                        counts[fullType] = (counts[fullType] or 0) + 1
                    end
                end
            end
        end
    end

    -- Assign rarity based on frequency
    local function getRarity(count)
        if not count then return "unknown" end
        if count <= 3 then
            return "epic"
        elseif count <= 10 then
            return "rare"
        else
            return "common"
        end
    end

    -- Build itemTypes table
    FTI_Config.itemTypes = {}
    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        local fullType = item:getFullName()
        local rarity = getRarity(counts[fullType])
        local icon = getTexture("media/inventory/" .. item:getIcon() .. ".png")

        FTI_Config.itemTypes[fullType] = {
            rarity = rarity,
            icon = icon
        }
    end
end

FTI_Config.enableAutoScan = true

FTI_Config.autogenerateItemRarity()

return FTI_Config

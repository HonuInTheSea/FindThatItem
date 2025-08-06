local FTI_Config = require "FindThatItem/FTI_Config"
local FTI_ModOptions = require "FindThatItem/FTI_ModOptions"

local FTI_Tracker = {}

FTI_Tracker.trackedItems = {} -- each: { item, square, distance }
FTI_Tracker.junkItems = {}
FTI_Tracker._lastX = nil
FTI_Tracker._lastY = nil
FTI_Tracker._scanCooldown = 0

-- FTI_Tracker.wantedItems = FTI_Tracker.wantedItems or {}

function FTI_Tracker:updateNearbyItems(itemTypeMap)
    local player = getPlayer()
    if not player then return end
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local radius = (FTI_ModOptions and FTI_ModOptions.scanRadius) or 5

    FTI_Tracker.trackedItems = {}
    local trackedVehicleIDs = {}

    -- Robust container check (supports both vanilla and modded items)
    local function isContainer(item)
        return (item and (
            (item.isContainer and item:isContainer()) or
            (item.getCategory and item:getCategory() == "Container")
        ))
    end

    -- Get the "live" ItemContainer for an InventoryItem, if any
    local function getContainerObj(item)
        return (item and (
            (item.getInventoryContainer and item:getInventoryContainer()) or
            item.container
        )) or nil
    end

    -- Robust recursive inventory scan, no prints
    local function scanInventory(obj, sq, distance, path, sourceType, vehicleLabel, sourcePart)
        local container = obj
        -- Accept both ItemContainer and InventoryItem as obj; unwrap if needed
        if obj and not (obj.getItems or obj.getAllItems) then
            -- It's probably an InventoryItem, get its container if possible
            container = getContainerObj(obj)
            if not container then return end
        end

        -- Get item list (works for both ItemContainer and player inventory)
        local items
        if container and type(container.getItems) == "function" then
            items = container:getItems()
        elseif container and type(container.getAllItems) == "function" then
            items = container:getAllItems()
        end
        if not items then return end

        local size
        if type(items.size) == "function" then
            size = items:size()
        elseif type(items.getSize) == "function" then
            size = items:getSize()
        end
        if not size or size == 0 then return end

        for i = 0, size - 1 do
            local item = items:get(i)
            if item then
                local name     = (item.getCustomNameFull and item:getCustomNameFull())
                    or (item.getDisplayName and item:getDisplayName())
                    or tostring(item)
                local fullType = item.getFullType and item:getFullType()
                local typeInfo = fullType and FTI_Config.itemTypes[fullType]
                local rarity   = (typeInfo and typeInfo.rarity) or "common"
                local modID    = item.getModID and item:getModID()

                local newPath  = {}
                for _, v in ipairs(path) do table.insert(newPath, v) end
                table.insert(newPath, container)

                table.insert(FTI_Tracker.trackedItems, {
                    item          = item,
                    name          = name,
                    fullType      = fullType,
                    rarity        = rarity,
                    modID         = modID,
                    square        = sq,
                    distance      = distance,
                    source        = sourceType,
                    vehicleLabel  = vehicleLabel,
                    sourcePart    = sourcePart,
                    containerPath = newPath,
                })

                -- Recursively scan if item is a container and has a live container
                if isContainer(item) then
                    local subCont = getContainerObj(item)
                    if subCont then
                        scanInventory(subCont, sq, distance, newPath, sourceType, vehicleLabel, sourcePart)
                    end
                end
            end
        end
    end

    -- Scan ground & container items in grid
    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = getCell():getGridSquare(px + dx, py + dy, pz)
            if sq then
                -- Ground inventory objects (bags dropped in the world)
                for i = 0, sq:getWorldObjects():size() - 1 do
                    local worldObj = sq:getWorldObjects():get(i)
                    if instanceof(worldObj, "IsoWorldInventoryObject") then
                        local bagItem = worldObj:getItem()
                        local worldContainer = worldObj.getContainer and worldObj:getContainer() or nil
                        local bagDistance = worldObj:getSquare():DistTo(player)

                        -- Always add the ground bag itself as a tracked item
                        table.insert(FTI_Tracker.trackedItems, {
                            item          = bagItem,
                            name          = bagItem and
                                (bagItem.getDisplayName and bagItem:getDisplayName() or tostring(bagItem)) or
                                tostring(worldObj),
                            square        = sq,
                            distance      = bagDistance,
                            rarity        = (bagItem and FTI_Config.itemTypes[bagItem:getFullType()] or {}).rarity or
                                "common",
                            source        = "groundBag",
                            modID         = bagItem and (bagItem.getModID and bagItem:getModID()),
                            containerPath = {},
                        })

                        -- PATCH: Forcibly initialize the bag's container if it's not present
                        if not worldContainer and bagItem then
                            -- Try normal method (should create the container if missing)
                            worldContainer = bagItem.getInventoryContainer and bagItem:getInventoryContainer() or nil

                            -- Optionally try DoParam hack if still nil
                            if not worldContainer and bagItem.DoParam then
                                bagItem:DoParam("open")
                                worldContainer = bagItem.getInventoryContainer and bagItem:getInventoryContainer() or nil
                            end
                        end

                        if worldContainer then
                            scanInventory(worldContainer, sq, bagDistance, {}, "groundBag", nil, nil)
                        end
                    end
                end
                -- World containers (fridge, crate, etc.)
                for i = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(i)
                    if instanceof(obj, "IsoObject") and obj:getContainer() then
                        local container = obj:getContainer()
                        scanInventory(container, sq, math.sqrt(dx * dx + dy * dy), {}, "container", nil, nil)
                    elseif instanceof(obj, "IsoGenerator") then
                        -- Generator scan
                        local distance = math.sqrt(dx * dx + dy * dy)
                        local genID = (obj.getObjectID and obj:getObjectID()) or tostring(obj)
                        table.insert(FTI_Tracker.trackedItems, {
                            generator   = obj,
                            square      = sq,
                            distance    = distance,
                            rarity      = "epic",
                            source      = "generator",
                            generatorID = genID,
                        })
                    end
                end
            end
        end
    end

    -- Vehicle scan
    local vehicles = getWorld():getCell():getVehicles()
    for i = 0, vehicles:size() - 1 do
        local veh = vehicles:get(i)
        if veh then
            local vx, vy, vz = veh:getX(), veh:getY(), veh:getZ()
            if math.abs(vx - px) <= radius and math.abs(vy - py) <= radius and vz == pz then
                local vid = veh:getId() or tostring(veh)
                if not trackedVehicleIDs[vid] then
                    local dist     = veh:getSquare():DistTo(player)
                    local script   = veh:getScript()
                    local rawName  = script and script:getName() or "Vehicle"
                    local dispName = getText("IGUI_VehicleName" .. rawName) or rawName
                    local coord    = string.format("%d,%d,%d", vx, vy, vz)
                    local vLabel   = string.format("%s [%s]", dispName, coord)

                    table.insert(FTI_Tracker.trackedItems, {
                        vehicle       = veh,
                        vehicleLabel  = vLabel,
                        square        = veh:getSquare(),
                        distance      = dist,
                        rarity        = "epic",
                        vehicleID     = vid,
                        containerPath = {},
                        source        = "vehicle",
                    })

                    -- scan each container part
                    for pi = 0, veh:getPartCount() - 1 do
                        local part = veh:getPartByIndex(pi)
                        if part and part:isContainer() and part.getItemContainer then
                            local cont = part:getItemContainer()
                            if cont then
                                scanInventory(cont, veh:getSquare(), dist, {}, "vehicle", vLabel, part:getId())
                            end
                        end
                    end

                    trackedVehicleIDs[vid] = true
                end
            end
        end
    end
end

function FTI_Tracker.updateOnPlayerMove()
    if not FTI_Config.enableAutoScan then return end
    local player = getPlayer()
    if not player then return end

    local x = math.floor(player:getX())
    local y = math.floor(player:getY())

    if x ~= FTI_Tracker._lastX or y ~= FTI_Tracker._lastY then
        FTI_Tracker._scanCooldown = FTI_Tracker._scanCooldown - 1
        if FTI_Tracker._scanCooldown <= 0 then
            FTI_Tracker._lastX = x
            FTI_Tracker._lastY = y
            FTI_Tracker._scanCooldown = 15
            FTI_Tracker.updateNearbyItems(FTI_Config.itemTypes)
        end
    end
end

function FTI_Tracker.saveJunkItems()
    local data = ModData.getOrCreate("FindThatItem")
    data.junkItems = FTI_Tracker.junkItems
    ModData.transmit("FindThatItem")
end

function FTI_Tracker.loadJunkItems()
    local data = ModData.getOrCreate("FindThatItem")
    FTI_Tracker.junkItems = data.junkItems or {}
end

-- function FTI_Tracker.addWantedItem(fullType)
--     FTI_Tracker.wantedItems[fullType] = true
--     FTI_Tracker.saveWantedItems()
-- end

-- function FTI_Tracker.removeWantedItem(fullType)
--     FTI_Tracker.wantedItems[fullType] = nil
--     FTI_Tracker.saveWantedItems()
-- end

-- function FTI_Tracker.isWanted(fullType)
--     return FTI_Tracker.wantedItems[fullType] == true
-- end

-- function FTI_Tracker.saveWantedItems()
--     local data = ModData.getOrCreate("FindThatItem")
--     data.wantedItems = FTI_Tracker.wantedItems
--     ModData.transmit("FindThatItem")
-- end

-- function FTI_Tracker.loadWantedItems()
--     local data = ModData.getOrCreate("FindThatItem")
--     FTI_Tracker.wantedItems = data.wantedItems or {}
-- end

-- Events.OnGameStart.Add(FTI_Tracker.loadWantedItems)
Events.OnGameStart.Add(FTI_Tracker.loadJunkItems)

return FTI_Tracker

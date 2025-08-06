---@diagnostic disable: undefined-field
local FTI_Config = require "FindThatItem/FTI_Config"
local FTI_Util = require "FindThatItem/FTI_Util"

local FTI_RenderVectors = {}

function FTI_RenderVectors.renderVectors()
    local FTI_UI = require("FindThatItem/FTI_UI") -- Resolves circular dependency

    local player = getPlayer()
    if not player then
        return
    end

    if not (FTI_UI and FTI_UI.showVectors) then
        return
    end

    local px, py, pz = player:getX(), player:getY(), player:getZ()

    for _, data in ipairs(FTI_UI.filteredItems or {}) do
        local rarity = data.rarity or FTI_Util.getRarity(data)
        if rarity ~= "junk" then
            local color = FTI_Config.rarityColors[rarity] or { r = 1, g = 1, b = 1 }

            if FTI_UI.isVectorVisible(data) then
                local sq = data.square
                if sq then
                    local tx, ty = sq:getX(), sq:getY()
                    local dx = tx - px
                    local dy = ty - py
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0 then
                        local angle          = math.atan2(dy, dx)
                        local maxDist        = math.min(40, dist)

                        local xStart         = px
                        local yStart         = py
                        local xEnd           = px + maxDist * math.cos(angle)
                        local yEnd           = py + maxDist * math.sin(angle)

                        local sx1            = isoToScreenX(player:getPlayerNum(), xStart, yStart, pz)
                        local sy1            = isoToScreenY(player:getPlayerNum(), xStart, yStart, pz)
                        local sx2            = isoToScreenX(player:getPlayerNum(), xEnd, yEnd, pz)
                        local sy2            = isoToScreenY(player:getPlayerNum(), xEnd, yEnd, pz)

                        -- Highlight if hovered or selected
                        local isHovered      = FTI_UI.hoveredItem and FTI_UI.isSameEntry(FTI_UI.hoveredItem, data)
                        local isSelected     = FTI_UI.selectedItem and FTI_UI.isSameEntry(FTI_UI.selectedItem, data)

                        local vR, vG, vB, vA = color.r, color.g, color.b, 1
                        local thickness      = 1

                        if isHovered or isSelected then
                            vR, vG, vB = 1, 0, 0
                            thickness = 5
                        end

                        -- Draw the vector with correct thickness
                        if thickness > 1 then
                            for offset = -2, 2 do
                                FTI_Util.drawArrow(sx1 + offset, sy1, sx2 + offset, sy2, vR, vG, vB, vA)
                                FTI_Util.drawArrow(sx1, sy1 + offset, sx2, sy2 + offset, vR, vG, vB, vA)
                            end
                        else
                            FTI_Util.drawArrow(sx1, sy1, sx2, sy2, vR, vG, vB, vA)
                        end

                        -- (Optional) Draw a label
                        local label
                        if data.item then
                            label = data.displayName or data.name or
                                (data.item.getCustomNameFull and data.item:getCustomNameFull())
                                or (data.item.getDisplayName and data.item:getDisplayName())
                                or (data.item.getType and data.item:getType())
                                or getText("UI_FTI_UnknownItem")
                        elseif data.vehicle then
                            label = data.vehicleLabel or getText("UI_FTI_Vehicle")
                        elseif data.generator then
                            label = getText("UI_FTI_Generator")
                        else
                            label = getText("UI_FTI_UnknownItem")
                        end
                        FTI_Util.getDrawHelper():drawText(label, sx2 + 6, sy2 - 6, vR, vG, vB, vA, UIFont.Small)
                    end
                end
            end
        end
    end
end

return FTI_RenderVectors

local FTI_Config = require "FindThatItem/FTI_Config"

local FTI_Util = {}

local _drawHelper = nil

function FTI_Util.getDrawHelper()
    if not _drawHelper then
        _drawHelper = ISUIElement:new(0, 0, 1, 1)
        _drawHelper:initialise()
        _drawHelper:instantiate()
        _drawHelper:setVisible(false)
        _drawHelper:addToUIManager()
    end
    return _drawHelper
end

-- Simple 1-pixel line
function FTI_Util.drawLine(x1, y1, x2, y2, alpha, r, g, b)
    local ui = FTI_Util.getDrawHelper()
    if ui and ui.drawLine2 then
        ui:drawLine2(x1, y1, x2, y2, alpha, r, g, b)
    end
end

-- Draws a "filled quad" as a set of lines between the sides (vanilla safe)
function FTI_Util.drawFilledQuad(x1, y1, x2, y2, x3, y3, x4, y4, alpha, r, g, b)
    local steps = math.max(
        math.floor(math.max(
            math.abs(x1 - x4),
            math.abs(y1 - y4),
            math.abs(x2 - x3),
            math.abs(y2 - y3)
        )), 1
    )
    for i = 0, steps do
        local t = i / steps
        local ax = x1 + (x4 - x1) * t
        local ay = y1 + (y4 - y1) * t
        local bx = x2 + (x3 - x2) * t
        local by = y2 + (y3 - y2) * t
        FTI_Util.drawLine(ax, ay, bx, by, alpha, r, g, b)
    end
end

-- Draws a "filled triangle" as a set of lines between two base points and the tip
function FTI_Util.drawFilledTriangle(x1, y1, x2, y2, x3, y3, alpha, r, g, b)
    -- We'll scanline from base (x1,y1)-(x2,y2) up to tip (x3,y3)
    local steps = math.max(math.floor(math.max(
        math.abs(x1 - x3),
        math.abs(y1 - y3),
        math.abs(x2 - x3),
        math.abs(y2 - y3)
    )), 1)
    for i = 0, steps do
        local t = i / steps
        local ax = x1 + (x3 - x1) * t
        local ay = y1 + (y3 - y1) * t
        local bx = x2 + (x3 - x2) * t
        local by = y2 + (y3 - y2) * t
        FTI_Util.drawLine(ax, ay, bx, by, alpha, r, g, b)
    end
end

-- Main arrow function: thick shaft with a filled arrowhead at end
function FTI_Util.drawArrow(x1, y1, x2, y2, r, g, b, a)
    -- Draw the main shaft
    FTI_Util.drawLine(x1, y1, x2, y2, a, r, g, b)

    -- Draw arrowhead lines
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then return end

    local head_len = 12             -- Length of each arrowhead side
    local head_angle = math.rad(25) -- Angle between shaft and arrowhead

    local angle = math.atan2(dy, dx)

    -- Left side
    local left_angle = angle + math.pi - head_angle
    local left_x = x2 + math.cos(left_angle) * head_len
    local left_y = y2 + math.sin(left_angle) * head_len

    -- Right side
    local right_angle = angle + math.pi + head_angle
    local right_x = x2 + math.cos(right_angle) * head_len
    local right_y = y2 + math.sin(right_angle) * head_len

    FTI_Util.drawLine(x2, y2, left_x, left_y, a, r, g, b)
    FTI_Util.drawLine(x2, y2, right_x, right_y, a, r, g, b)
end

function FTI_Util.getRarity(data)
    -- generators are always epic
    if data.generator then
        return "epic"
    end

    -- preserve any explicit rarity
    if data.rarity then
        return data.rarity
    end

    local item = data.item
    local fullType = item and item.getFullType and item:getFullType()
    local typeInfo = fullType and FTI_Config.itemTypes[fullType]

    if typeInfo and typeInfo.rarity then
        return typeInfo.rarity
    elseif fullType and FTI_Config.wantedItems and FTI_Config.wantedItems[fullType] then
        return "target"
    else
        return "common"
    end
end

return FTI_Util

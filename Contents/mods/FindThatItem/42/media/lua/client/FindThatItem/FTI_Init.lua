---@diagnostic disable: inject-field, redundant-parameter
-- ***********************************************************
-- **                   Honu's Find That Item               **
-- **				    Author: HonuInTheSea   		        **
-- ***********************************************************
local FTI_Config = require "FindThatItem/FTI_Config"
local FTI_Tracker = require "FindThatItem/FTI_Tracker"
local FTI_UI = require "FindThatItem/FTI_UI"

local FTI_Init = {}
local FTI_Tooltip = nil

Events.OnGameStart.Add(function()
    FTI_Config.autogenerateItemRarity()
    local PanelClass = _G.ISEquippedItem
    if PanelClass and not PanelClass._fti_icon_patched then
        PanelClass._fti_icon_patched = true

        local orig_prerender = PanelClass.prerender
        PanelClass.prerender = function(self, ...)
            orig_prerender(self, ...)
            local btn = self.searchBtn
            if btn then
                local iconSize = btn:getHeight()
                local offset = 6
                local btnAbsX, btnAbsY = btn:getAbsoluteX(), btn:getAbsoluteY()
                local btnW, btnH = btn:getWidth(), btn:getHeight()
                local iconAbsX = btnAbsX + btnW + offset
                local iconAbsY = btnAbsY

                local mx, my = getMouseX(), getMouseY()
                local overBtn = mx >= btnAbsX and mx < btnAbsX + btnW and my >= btnAbsY and my < btnAbsY + btnH
                local overIcon = mx >= iconAbsX and mx < iconAbsX + iconSize and my >= iconAbsY and
                    my < iconAbsY + iconSize

                if overBtn or overIcon then
                    local tex = FTI_Config.hudEnabled and FTI_Config.hudIconEnabled or FTI_Config.hudIconDisabled
                    if tex then
                        self:drawTextureScaled(
                            tex,
                            btn:getX() + btnW + offset,
                            btn:getY(),
                            iconSize, iconSize,
                            1, 1, 1, 1
                        )
                    end
                end

                if overIcon then
                    if not FTI_Tooltip then
                        FTI_Tooltip = ISToolTip:new()
                        FTI_Tooltip:initialise()
                    end
                    FTI_Tooltip.description = getText("UI_FTI_HUD_Tooltip")
                    FTI_Tooltip:setX(mx + 16)
                    FTI_Tooltip:setY(my + 8)
                    FTI_Tooltip:addToUIManager()
                    FTI_Tooltip:setVisible(true)
                    FTI_Tooltip:render()
                    if isMouseButtonDown and isMouseButtonDown(0) and not self._fti_icon_clicked then
                        FTI_UI.toggleHUD()
                        self._fti_icon_clicked = true
                    elseif not isMouseButtonDown or not isMouseButtonDown(0) then
                        self._fti_icon_clicked = false
                    end
                else
                    if FTI_Tooltip and FTI_Tooltip:getIsVisible() then
                        FTI_Tooltip:setVisible(false)
                        FTI_Tooltip:removeFromUIManager()
                    end
                    self._fti_icon_clicked = false
                end
            end
        end
    end
end)

Events.OnPlayerUpdate.Add(FTI_Tracker.updateOnPlayerMove)

_G.FTI_Init = FTI_Init
return FTI_Init

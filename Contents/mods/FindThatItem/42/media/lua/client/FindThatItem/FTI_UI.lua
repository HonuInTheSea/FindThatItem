---@diagnostic disable: inject-field, param-type-mismatch, redefined-local, undefined-field, missing-parameter, redundant-parameter, duplicate-set-field
local FTI_Config = require "FindThatItem/FTI_Config"
local FTI_Tracker = require "FindThatItem/FTI_Tracker"
local FTI_RenderVectors = require "FindThatItem/FTI_RenderVectors"

local FTI_UI = {}

FTI_UI.filteredItems = {}
FTI_UI.searchText = ""
FTI_UI.rarityFilter = "all"
if FTI_UI then FTI_UI.showVectors = true end

FTI_UI.hoveredItem = nil
FTI_UI.selectedItem = nil

local PADDING = 20
local ROW_HEIGHT = 48

FTI_UI.rarityChecks = {
    -- target = true,
    epic = true,
    rare = true,
    common = true,
    unknown = true,
}

FTI_UI.rarityCounts = {
    -- target = 0,
    epic = 0,
    rare = 0,
    common = 0,
    unknown = 0
}

FTIHorizontalRarityFilter = ISPanel:derive("FTIHorizontalRarityFilter")

function FTIHorizontalRarityFilter:new(x, y, w, h, rarities, colors, onChange)
    local o = ISPanel.new(self, x, y, w, h)
    o.rarities = rarities
    o.colors = colors
    o.onChange = onChange
    o.filter = {}
    o.checkSize = 16
    o.spacing = 24
    o.margin = 8
    o.labelWidths = {}
    o:setHeight(h or 28)
    o:setWidth(w or 380)
    for _, rarity in ipairs(rarities) do
        o.filter[rarity] = true
    end
    return o
end

function FTIHorizontalRarityFilter:prerender()
    self:layoutCheckBoxes()
    ISPanel.prerender(self)
    local font = UIFont.Small
    local yStart = self.margin
    local x = self.margin
    local y = yStart
    local rowHeight = math.max(self.checkSize, getTextManager():getFontFromEnum(font):getLineHeight())
    local verticalStack = false
    local maxWidth = self:getWidth()
    self.labelWidths = self.labelWidths or {}
    self.labels = self.labels or {}

    -- First pass: check if horizontal layout fits
    local requiredWidth = self.margin
    for i, _ in ipairs(self.rarities) do
        requiredWidth = requiredWidth
            + self.checkSize
            + 4
            + self.labelWidths[i]
        if i < #self.rarities then
            requiredWidth = requiredWidth + self.spacing
        end
    end
    if requiredWidth > maxWidth then
        verticalStack = true
    end

    -- Draw checkboxes: horizontal or vertical
    for i, rarity in ipairs(self.rarities) do
        local color = self.colors[rarity] or { r = 1, g = 1, b = 1 }
        local boxX = x
        local boxY = y

        if self.verticalStack then
            boxX = self.margin
            boxY = self.margin + (i - 1) * (self.checkSize + self.spacing)
        else
            boxY = (self:getHeight() - self.checkSize) / 2
            boxX = self.margin
            for j = 1, i - 1 do
                boxX = boxX + self.checkSize + 4 + (self.labelWidths[j] or 0) + self.spacing
            end
        end

        if not verticalStack then
            -- Horizontal: Center vertically in panel
            boxY = (self:getHeight() - self.checkSize) / 2
        end

        -- Draw checkbox border
        self:drawRectBorder(boxX, boxY, self.checkSize, self.checkSize, 1, 0.3, 0.3, 0.3)
        if self.filter[rarity] then
            self:drawRect(boxX + 3, boxY + 3, self.checkSize - 6, self.checkSize - 6, 1, color.r, color.g, color.b)
        end
        -- Hover highlight
        local mouseX, mouseY = self:getMouseX(), self:getMouseY()
        if mouseX >= boxX and mouseX <= boxX + self.checkSize
            and mouseY >= boxY and mouseY <= boxY + self.checkSize then
            self:drawRect(boxX, boxY, self.checkSize, self.checkSize, 0.18, color.r, color.g, color.b)
        end

        -- Draw label
        local labelX = boxX + self.checkSize + 4
        local labelY = boxY + (self.checkSize - getTextManager():getFontFromEnum(font):getLineHeight()) / 2
        self:drawText(self.labels[i], labelX, labelY, color.r, color.g, color.b, 1, font)

        if verticalStack then
            -- Move down for next row
            x = self.margin
            y = y + rowHeight + self.spacing
        else
            -- Move right for next checkbox
            x = labelX + self.labelWidths[i] + self.spacing
        end
    end
end

function FTIHorizontalRarityFilter:onMouseDown(x, y)
    local font = UIFont.Small
    local margin = self.margin
    local spacing = self.spacing
    local rowHeight = self.rowHeight or math.max(self.checkSize, getTextManager():getFontFromEnum(font):getLineHeight())
    local labelWidths = self.labelWidths or {}
    local verticalStack = self.verticalStack

    local bx, by = margin, margin

    for i, rarity in ipairs(self.rarities) do
        if verticalStack then
            bx = margin
            by = margin + (i - 1) * (rowHeight + spacing)
        else
            by = (self:getHeight() - self.checkSize) / 2
            bx = margin
            for j = 1, i - 1 do
                bx = bx + self.checkSize + 4 + (labelWidths[j] or 0) + spacing
            end
        end

        if x >= bx and x <= bx + self.checkSize and y >= by and y <= by + self.checkSize then
            self.filter[rarity] = not self.filter[rarity]
            if self.onChange then self.onChange(self.filter) end
            return
        end
    end
end

function FTIHorizontalRarityFilter:setWidth(w)
    ISPanel.setWidth(self, w)
    self:layoutCheckBoxes()
end

function FTIHorizontalRarityFilter:onMouseMove(dx, dy) end

function FTIHorizontalRarityFilter:onMouseUp(x, y) end

function FTI_UI.syncHUDButton()
    local FTI_Init = _G["FTI_Init"]
    if FTI_Init and FTI_Init.hudButton then
        local tex = FTI_Config.hudEnabled and FTI_Config.hudIconEnabled or FTI_Config.hudIconDisabled
        FTI_Init.hudButton:setImage(tex)
        if FTI_Init.hudButton.setPressed then
            FTI_Init.hudButton:setPressed(FTI_Config.hudEnabled)
        end
    end
end

local function filterItemList()
    -- Define rarity sorting priority for display order
    local rarityPriority = {
        epic    = 2,
        rare    = 3,
        common  = 4,
        unknown = 5,
        junk    = 6
    }

    local result = {}
    local search = FTI_UI.searchText:lower()
    local filters = {}
    if FTI_UI.window and FTI_UI.window.rarityFilterPanel then
        filters = FTI_UI.window.rarityFilterPanel.filter
    else
        filters = FTI_UI.rarityChecks
    end

    -- Reset counts
    for k in pairs(FTI_UI.rarityCounts) do
        FTI_UI.rarityCounts[k] = 0
    end

    for _, tracked in ipairs(FTI_Tracker.trackedItems) do
        if tracked.generator then
            -- Generator entry
            local name = getText("UI_FTI_Generator")
            local rarity = "epic"
            FTI_UI.rarityCounts[rarity] = (FTI_UI.rarityCounts[rarity] or 0) + 1
            local icon = getTexture("media/textures/fti_generator.png")
            local coordStr = string.format("%d,%d,%d", tracked.square:getX(), tracked.square:getY(),
                tracked.square:getZ())
            local passesSearch = (search == "") or name:lower():find(search, 1, true) or coordStr:find(search, 1, true)
            local passesRarity = filters[rarity] == true
            if passesSearch and passesRarity then
                table.insert(result, {
                    generator = tracked.generator,
                    generatorID = tracked.generatorID,
                    icon = icon,
                    rarity = rarity,
                    square = tracked.square,
                    distance = tracked.distance,
                    name = name,
                })
            end
        elseif tracked.vehicle then
            -- Vehicle entry: Use tracker-provided vehicleLabel and ensure name is set to friendly name
            local vehicle = tracked.vehicle
            local vehicleLabel = tracked.vehicleLabel
            local rarity = tracked.rarity or "epic"
            FTI_UI.rarityCounts[rarity] = (FTI_UI.rarityCounts[rarity] or 0) + 1
            local icon = getTexture("media/ui/vehicle/vehicle.png") or getTexture("media/textures/fti_vehicle.png")
            local passesSearch = (search == "") or (vehicleLabel and vehicleLabel:lower():find(search, 1, true))
            local passesRarity = filters[rarity] == true
            if passesSearch and passesRarity then
                table.insert(result, {
                    vehicle      = vehicle,
                    icon         = icon,
                    rarity       = rarity,
                    square       = tracked.square,
                    distance     = tracked.distance,
                    name         = tracked.vehicleLabel,
                    vehicleLabel = tracked.vehicleLabel,
                    vehicleID    = tracked.vehicleID
                })
            end
        elseif tracked.item then
            local item     = tracked.item
            local name     = tracked.name
                or (item.getCustomNameFull and item:getCustomNameFull())
                or (item.getDisplayName and item:getDisplayName())
                or ""
            local fullType = item.getFullType and item:getFullType()
            local isJunk   = FTI_Tracker.junkItems[fullType] == true
            local typeInfo = fullType and FTI_Config.itemTypes[fullType]
            local rarity   = (typeInfo and typeInfo.rarity)
                or "common"
            if isJunk then rarity = "junk" end

            FTI_UI.rarityCounts[rarity] = (FTI_UI.rarityCounts[rarity] or 0) + 1

            local icon
            if typeInfo and typeInfo.icon then
                if type(typeInfo.icon) == "string" then
                    icon = getTexture("media/inventory/" .. typeInfo.icon .. ".png")
                else
                    icon = typeInfo.icon
                end
            end

            local passesSearch = (search == "")
                or name:lower():find(search, 1, true)
            local passesRarity = filters[rarity] == true

            if passesSearch and passesRarity then
                -- GROUPING LOGIC START
                local containerObj = (tracked.containerPath and tracked.containerPath[#tracked.containerPath]) or nil
                local squareKey = tracked.square and
                    (tracked.square:getX() .. "," .. tracked.square:getY() .. "," .. tracked.square:getZ()) or ""
                local containerKey = tostring(containerObj or "ground")
                local groupKey = containerKey .. "|" .. (fullType or "") .. "|" .. squareKey

                if not result._grouped then result._grouped = {} end
                local grouped = result._grouped

                if not grouped[groupKey] then
                    grouped[groupKey] = {
                        count         = 0,
                        item          = item,
                        icon          = icon,
                        rarity        = rarity,
                        square        = tracked.square,
                        distance      = tracked.distance,
                        fullType      = fullType,
                        name          = name,
                        vehicleLabel  = tracked.vehicleLabel,
                        source        = tracked.source,
                        sourcePart    = tracked.sourcePart,
                        containerPath = tracked.containerPath,
                        itemList      = {},
                    }
                end
                grouped[groupKey].count = grouped[groupKey].count + 1
                table.insert(grouped[groupKey].itemList, item)
            end
        end
    end

    -- Flatten grouped items to the main result list, adding (xN) to displayName if needed
    if result._grouped then
        for _, entry in pairs(result._grouped) do
            if entry.count > 1 then
                entry.displayName = (entry.name or getText("UI_FTI_UnknownItem")) .. " (x" .. entry.count .. ")"
            else
                entry.displayName = entry.name
            end
            table.insert(result, entry)
        end
        result._grouped = nil
    end

    -- Sort by rarity priority, then by display name (A-Z)
    table.sort(result, function(a, b)
        local prioA = rarityPriority[a.rarity or "unknown"] or 99
        local prioB = rarityPriority[b.rarity or "unknown"] or 99
        local nameA = a.name or (a.item and a.item.getDisplayName and a.item:getDisplayName()) or ""
        local nameB = b.name or (b.item and b.item.getDisplayName and b.item:getDisplayName()) or ""
        if prioA ~= prioB then return prioA < prioB end
        return nameA:lower() < nameB:lower()
    end)

    FTI_UI.filteredItems = result

    if FTI_RenderVectors then
        FTI_RenderVectors.requestUpdate = true
    end
end

function FTIHorizontalRarityFilter:onChange(filter)
    FTI_UI.rarityChecks = filter
    filterItemList()
    FTI_UI.refreshLayout()
    FTI_UI.deferRedraw()
    FTI_UI.saveRarityFilterState()
end

function FTI_UI.createUI()
    if FTI_UI.window then
        FTI_UI.window:setVisible(true)
        return
    end

    FTI_UI.loadRarityFilterState()

    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local defW, defH = FTI_Config.width, FTI_Config.height

    local x, y = (screenW - defW) / 2, (screenH - defH) / 2
    local w, h = defW, defH
    local collapsed = false

    local sx, sy, sw, sh, scoll = FTI_UI.loadWindowState()
    -- local sx, sy, sw, sh, scoll = nil, nil, nil, nil, nil
    if sx then x = sx end
    if sy then y = sy end
    if sw then w = sw end
    if sh then h = sh end
    if scoll ~= nil then collapsed = scoll end

    local win = ISCollapsableWindow:new(x, y, w, h)
    win:setTitle(getText("UI_FTI_Title"))
    win:setAlwaysOnTop(true)
    win:setResizable(true)
    win:setVisible(true)
    win.pin = true
    win:addToUIManager()
    FTI_UI.window = win

    -- Restore collapsed state AFTER adding children, so layout is correct
    if collapsed then
        win:setIsCollapsed(true)
    end

    -- Save on drag
    local oldMouseUp = win.onMouseUp
    function win:onMouseUp(x, y)
        if oldMouseUp then oldMouseUp(self, x, y) end
        FTI_UI.saveWindowState()
    end

    -- Save on resize
    local oldResize = win.onResize

    -- Save on collapse/expand
    local oldCollapse = win.setIsCollapsed
    function win:setIsCollapsed(collapsed)
        if oldCollapse then oldCollapse(self, collapsed) end
        if not collapsed then
            FTI_UI.saveWindowState()
        else
            local data = ModData.getOrCreate("FindThatItem")
            data.windowCollapsed = true
            ModData.transmit("FindThatItem")
        end
    end

    -- Save on hide/close
    local vanillaSetVisible = win.setVisible
    function win:setVisible(visible)
        vanillaSetVisible(self, visible)
        if not visible then
            FTI_UI.saveWindowState()
            FTI_UI.hideWindowAndCleanup(true)
        end
        FTI_UI.syncVectors()
    end

    if not FTI_UI._vectorsAdded then
        Events.OnPreUIDraw.Add(FTI_RenderVectors.renderVectors)
        FTI_UI._vectorsAdded = true
    end

    local titleH = win:titleBarHeight()
    local contentW = win:getWidth() - PADDING * 2

    -- Row 1: Full-width search bar
    local filtersY = titleH + PADDING
    win.entry = ISTextEntryBox:new("", PADDING, filtersY, contentW, ROW_HEIGHT)
    win.entry:initialise()
    win.entry.font = UIFont.Small
    win:addChild(win.entry)
    win.entry:setClearButton(true)
    local ut = FTI_UI.loadUserTextState()
    win.entry:setText(ut.userText or "")

    -- Row 2: Custom horizontal rarity filter
    local rarityKeys = {}
    for _, rc in ipairs(FTI_Config.rarityConfig) do
        table.insert(rarityKeys, rc.key)
    end
    local rarityColors = FTI_Config.rarityColors
    win.rarityFilterPanel = FTIHorizontalRarityFilter:new(
        PADDING,
        win.entry.y + win.entry:getHeight() + PADDING,
        contentW,
        28,
        rarityKeys,
        rarityColors,
        function(filter)
            FTI_UI.rarityChecks = filter
            filterItemList()
            FTI_UI.refreshLayout()
            FTI_UI.deferRedraw()
            FTI_UI.saveRarityFilterState()
        end
    )
    win:addChild(win.rarityFilterPanel)

    -- In FTI_UI.createUI, after creating win.rarityFilterPanel
    for _, rarity in ipairs(rarityKeys) do
        win.rarityFilterPanel.filter[rarity] = FTI_UI.rarityChecks[rarity]
    end

    -- Row 3: List (positioned later)
    win.list = ISScrollingListBox:new(PADDING, 0, contentW, 100)
    win.list:initialise()
    win.list.itemheight = ROW_HEIGHT
    win.list:setAlwaysOnTop(false)
    win:addChild(win.list)
    FTI_UI.list = win.list

    win.list.doDrawItem = function(self, y, item, alt)
        local data = item.item
        if not data then return y + self.itemheight end

        local name, icon, rarity

        local fullType = data.fullType
        local isJunk = fullType and FTI_Tracker.junkItems[fullType] == true

        if data.item then
            local invItem = data.item
            name = data.displayName or data.name or getText("UI_FTI_UnknownItem")
            icon = invItem.getTex and invItem:getTex() or
                (invItem.getIcon and invItem:getIcon() and getTexture("media/inventory/" .. invItem:getIcon() .. ".png")) or
                nil
            rarity = data.rarity or "unknown"
        elseif data.generator then
            name = data.name or getText("UI_FTI_Generator")
            icon = data.icon or getTexture("media/textures/fti_generator.png")
            rarity = data.rarity or "epic"
        elseif data.vehicle then
            name = data.vehicleLabel or data.name or
                (data.vehicle and data.vehicle.getScript and data.vehicle:getScript() and data.vehicle:getScript().getDisplayName and data.vehicle:getScript():getDisplayName()) or
                (data.vehicle and data.vehicle.getScript and data.vehicle:getScript() and data.vehicle:getScript().getName and data.vehicle:getScript():getName()) or
                getText("UI_FTI_Vehicle")
            icon = getTexture("media/textures/fti_vehicle.png")
            rarity = data.rarity or "epic"
        else
            name = getText("UI_FTI_UnknownItem")
            icon = nil
            rarity = "unknown"
        end

        local color = FTI_Config.rarityColors[rarity] or { r = 1, g = 1, b = 1 }
        local isHovered = FTI_UI.isSameEntry(FTI_UI.hoveredItem, data)
        local isSelected = FTI_UI.isSameEntry(FTI_UI.selectedItem, data)

        if isHovered then
            color = { r = 1, g = 0.1, b = 0.1 }
        elseif isSelected then
            color = { r = 0.9, g = 0.2, b = 0.2 }
        end

        -- Draw icon (if present)
        local iconY = y + 4
        if icon then
            self:drawTextureScaled(icon, 4, iconY, 32, 32, 1)
        end

        -- Draw name (align with icon vertical center)
        local labelYOffset = 10
        local offsetX = 42
        self:drawText(name, offsetX, y + labelYOffset, color.r, color.g, color.b, 1, UIFont.Small)

        -- Draw toggle button (right side, vertically aligned with icon)
        if fullType then
            local btnLabel = isJunk and getText("UI_FTI_Unjunk") or getText("UI_FTI_Junk")
            local btnLabelW = getTextManager():MeasureStringX(UIFont.Small, btnLabel)
            local textPadX = 14 -- button left/right padding
            local btnW = btnLabelW + 2 * textPadX
            local btnH = 28

            local btnPad = 28
            local scrollBarW = (self.vscroll and self.vscroll:isVisible() and self.vscroll:getWidth() or 16)
            local btnX = self:getWidth() - btnW - btnPad - scrollBarW

            local iconH = 32
            local btnY = iconY + (iconH - btnH) / 2

            local btnColor = isJunk
                and { r = 0.8, g = 0.5, b = 0.5, a = 1 }
                or { r = 0.6, g = 0.6, b = 0.6, a = 1 }
            self:drawRect(btnX, btnY, btnW, btnH, 0.3, btnColor.r, btnColor.g, btnColor.b)

            -- Center label horizontally and vertically in button
            local btnLabelX = btnX + (btnW - btnLabelW) / 2
            local btnLabelY = btnY + (btnH - getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()) / 2
            self:drawText(btnLabel, btnLabelX, btnLabelY, 1, 1, 1, 1, UIFont.Small)
            -- Register button bounds for mouse click detection
            if not self._junkButtons then self._junkButtons = {} end
            self._junkButtons[item.index] = { x = btnX, y = btnY, w = btnW, h = btnH, fullType = fullType }
        end

        return y + self.itemheight
    end

    win.list.onMouseMove = function(self, dx, dy)
        local mx, my = self:getMouseX(), self:getMouseY()
        local row = self:rowAt(mx, my)
        local overButton = false

        -- Check if hovering over any junk button
        if self._junkButtons then
            for _, btn in pairs(self._junkButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    overButton = true
                    break
                end
            end
        end

        -- Always suppress tooltip over button
        if overButton then
            FTI_UI.hoveredItem = nil
            if self.parent and self.parent.tooltip then
                self.parent.tooltip:removeFromUIManager()
                self.parent.tooltip = nil
            end
            if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
            FTI_UI.deferRedraw()
            return
        end

        -- Default behavior if not over button
        if row then
            local entry = self.items[row]
            FTI_UI.hoveredItem = (entry and entry.item) or (entry and entry.generator) or (entry and entry.vehicle) or
                nil
        else
            FTI_UI.hoveredItem = nil
        end

        if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
        FTI_UI.deferRedraw()

        -- Handle tooltips only if not over button
        if not row or not self.items[row] or not self.items[row].item then
            FTI_UI.hoveredItem = nil
            if self.parent and self.parent.tooltip then
                self.parent.tooltip:removeFromUIManager()
                self.parent.tooltip = nil
            end
            return
        end

        if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
        FTI_UI.deferRedraw()
        -- clear hover if we’re not over a row
        if not row then
            FTI_UI.hoveredItem = nil
            if self.parent and self.parent.tooltip then
                self.parent.tooltip:removeFromUIManager()
                self.parent.tooltip = nil
            end
            if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
            return
        end

        local entry = self.items[row]
        if not entry or not entry.item then
            FTI_UI.hoveredItem = nil
            return
        end

        local data = entry.item

        -- Hover and tooltip for all types including vehicles
        if data.generator or data.item or data.vehicle then
            FTI_UI.hoveredItem = data
            if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end

            -- remove old tooltip
            if self.parent.tooltip then
                self.parent.tooltip:removeFromUIManager()
                self.parent.tooltip = nil
            end

            -- build new tooltip
            local tooltip = FTISimpleTooltip:new()
            tooltip:clearFields()
            if data.generator then
                -- Generator-specific fields
                tooltip:addField(getText("UI_FTI_Type"), getText("UI_FTI_Generator"))
                local sq = data.square
                if sq then
                    tooltip:addField(getText("UI_FTI_Coordinates"), string.format("%d, %d, %d",
                        sq:getX(), sq:getY(), sq:getZ()))
                end
                if data.generator.isActivated and data.generator:isActivated() ~= nil then
                    tooltip:addField(getText("UI_FTI_Active"),
                        data.generator:isActivated() and getText("UI_Yes") or getText("UI_No"))
                end
                if data.generator.getFuel and data.generator:getFuel() then
                    local fuel = data.generator.getFuel and data.generator:getFuel() or 0
                    tooltip:addField(getText("UI_FTI_Fuel"),
                        tostring(fuel))
                end
                if data.generator.getCondition and data.generator:getCondition() then
                    tooltip:addField(getText("UI_FTI_Condition"),
                        tostring(data.generator:getCondition()))
                end
                if data.square then
                    tooltip:addField(
                        getText("UI_FTI_Location"),
                        getText("UI_FTI_Ground") or "Ground"
                    )
                end
                -- Rarity
                if data.rarity then
                    local c = FTI_Config.rarityColors[data.rarity] or { r = 1, g = 1, b = 1 }
                    tooltip:addField(getText("UI_FTI_Rarity"),
                        data.rarity:upper(), c)
                end
                -- Distance
                if data.distance then
                    tooltip:addField(getText("UI_FTI_Distance"),
                        string.format("%.1f tiles", data.distance))
                end
            elseif data.vehicle then
                local script = data.vehicle and data.vehicle.getScript and data.vehicle:getScript() or nil
                local displayName = data.vehicleLabel or
                    (script and script.getDisplayName and script:getDisplayName()) or
                    (script and script.getName and script:getName()) or
                    getText("UI_FTI_Vehicle")
                tooltip:addField(getText("UI_FTI_Name"), displayName)

                -- Vehicle overall condition
                local generalCondition = 0.0
                if data.vehicle and data.vehicle.getPartCount and data.vehicle.getPartByIndex then
                    local sum, total = 0, 0
                    for i = 0, data.vehicle:getPartCount() - 1 do
                        local part = data.vehicle:getPartByIndex(i)
                        if part and part.getCondition then
                            sum = sum + (part:getCondition() or 0)
                            total = total + 1
                        end
                    end
                    if total > 0 then
                        generalCondition = math.floor((sum / total) * 100) / 100 -- Two decimals, percent scale
                    end
                end
                tooltip:addField(getText("UI_FTI_VehicleCondition") or "Vehicle Condition",
                    tostring(generalCondition) .. "%")

                -- Locked
                local anyLocked = false
                if data.vehicle.getPartCount then
                    for i = 0, data.vehicle:getPartCount() - 1 do
                        local part = data.vehicle:getPartByIndex(i)
                        if part and part.getDoor and part:getDoor() and part:getDoor().isLocked and part:getDoor():isLocked() then
                            anyLocked = true
                            break
                        end
                    end
                end
                tooltip:addField(getText("UI_FTI_Locked"), anyLocked and getText("UI_Yes") or getText("UI_No"))

                -- Has Key
                local player = getPlayer()
                local hasKey = false
                if player and data.vehicle.getKeyId then
                    local keyId = data.vehicle:getKeyId()
                    if keyId then
                        local inv = player:getInventory():getItems()
                        for i = 0, inv:size() - 1 do
                            local item = inv:get(i)
                            if item and item.getKeyId and item:getKeyId() == keyId then
                                hasKey = true
                                break
                            end
                        end
                    end
                end
                tooltip:addField(getText("UI_FTI_HasKey"), hasKey and getText("UI_Yes") or getText("UI_No"))

                -- Get gas
                local gasAmount, gasCap, gasPct = "-", "-", "-"
                if data.vehicle and data.vehicle.getPartById then
                    local gasPart = data.vehicle:getPartById("GasTank")
                    if gasPart and gasPart.getContainerContentAmount and gasPart.getContainerCapacity then
                        gasAmount = gasPart:getContainerContentAmount()
                        gasCap = gasPart:getContainerCapacity()
                        if gasCap and gasCap > 0 then
                            gasPct = (gasAmount / gasCap) * 100
                        end
                    end
                end
                tooltip:addField(getText("UI_FTI_Gas"),
                    string.format("%s / %s (%.1f%%)", tostring(gasAmount), tostring(gasCap), tonumber(gasPct) or 0))

                -- Engine
                local engineCond = data.vehicle.getEngineCondition and data.vehicle:getEngineCondition() or nil
                if engineCond ~= nil then
                    tooltip:addField(getText("UI_FTI_EngineCondition"), tostring(engineCond))
                end

                -- Battery Condition and Capacity
                local batteryCond = "-"
                if data.vehicle.getPartById then
                    local battery = data.vehicle:getPartById("Battery")
                    if battery and battery.getCondition then
                        batteryCond = tostring(battery:getCondition())
                    end
                end
                tooltip:addField(getText("UI_FTI_Battery"), batteryCond)

                -- Alarm
                tooltip:addField(getText("UI_FTI_Alarm"),
                    data.vehicle.isAlarmed and data.vehicle:isAlarmed() and getText("UI_Yes") or getText("UI_No"))

                -- Rarity
                if data.rarity then
                    local c = FTI_Config.rarityColors[data.rarity] or { r = 1, g = 1, b = 1 }
                    tooltip:addField(getText("UI_FTI_Rarity"),
                        data.rarity:upper(), c)
                end

                -- Coordinates, distance
                if data.square then
                    local sq = data.square
                    tooltip:addField(getText("UI_FTI_Coordinates"),
                        string.format("%d, %d, %d", sq:getX(), sq:getY(), sq:getZ()))
                end
                if data.distance then
                    tooltip:addField(getText("UI_FTI_Distance"), string.format("%.1f tiles", data.distance))
                end
            else
                -- **inventory item branch** (uses containerPath)
                local invItem = data.item
                local displayName = data.name
                    or (invItem.getCustomNameFull and invItem:getCustomNameFull())
                    or (invItem.getDisplayName and invItem:getDisplayName())
                    or getText("UI_FTI_UnknownItem")
                tooltip:addField(getText("UI_FTI_Name"), data.displayName or data.name or getText("UI_FTI_UnknownItem"))

                -- normalize a raw name by:
                -- 1 inserting spaces before inner uppercase letters,
                -- 2 swapping underscores for spaces,
                -- 3 title‑casing every word
                local function normalizeName(raw)
                    -- 1 coerce to string
                    local s = tostring(raw or "")
                    -- 2 split camelCase: "frontLeftDoor" → "front Left Door"
                    s = s:gsub("([a-z])([A-Z])", "%1 %2")
                    -- 3 underscores → spaces
                    s = s:gsub("_", " ")
                    -- 4 title‑case each word
                    local words = {}
                    for w in s:gmatch("%S+") do
                        -- split first letter vs rest
                        local first       = w:sub(1, 1)
                        local rest        = w:sub(2)
                        words[#words + 1] = string.upper(first) .. string.lower(rest)
                    end
                    return table.concat(words, " ")
                end

                local function getCustomInfo(obj)
                    if not obj then return nil end
                    local rawName =
                        (obj.getType and obj:getType()) or
                        (obj.getName and obj:getName()) or
                        (obj.getObjectName and obj:getObjectName()) or
                        tostring(obj)
                    return { name = normalizeName(rawName) }
                end

                local function getContainerInfo(container)
                    if not container then return {} end
                    local parent = container.getParent and container:getParent() or nil
                    local info   = getContainerInfo(parent)
                    table.insert(info, getCustomInfo(container))
                    return info
                end

                local locationLabel

                if data.containerPath and #data.containerPath > 0 then
                    -- take the deepest (last) container in the path
                    local deepest = data.containerPath[#data.containerPath]
                    -- build a full list of {name=…} from outermost → deepest
                    local infoList = getContainerInfo(deepest)
                    -- if this item is also in a vehicle part, append that label
                    if data.source == "vehicle" and data.vehicleLabel then
                        table.insert(infoList, { name = normalizeName(data.vehicleLabel) })
                    end
                    -- extract the names into a simple list
                    local parts = {}
                    for _, cont in ipairs(data.containerPath) do
                        -- use the same normalizeName helper from before:
                        local raw = cont.getType and cont:getType()
                            or cont.getName and cont:getName()
                            or tostring(cont)
                        parts[#parts + 1] = normalizeName(raw)
                    end
                    -- (then vehicle part, ground, fallback as before)
                    locationLabel = table.concat(parts, " > ")
                elseif data.source == "vehicle" and data.sourcePart then
                    -- item sits in a vehicle part
                    local partName = getText("IGUI_VehiclePart" .. data.sourcePart)
                        or tostring(data.sourcePart)
                    locationLabel = normalizeName(partName)
                        .. " ("
                        .. normalizeName(data.vehicleLabel or "")
                        .. ")"
                elseif data.source == "ground" then
                    -- lying on the ground
                    locationLabel = normalizeName(getText("UI_FTI_Ground") or "ground")
                else
                    -- catch‑all fallback
                    locationLabel = normalizeName(getText("UI_FTI_LocationUnknown") or "unknown")
                end

                -- always add the field
                tooltip:addField(
                    getText("UI_FTI_Location") or "Location",
                    locationLabel
                )

                if data.modID then
                    tooltip:addField(getText("UI_FTI_ModSource"), data.modID)
                end
                if data.distance then
                    tooltip:addField(getText("UI_FTI_Distance"), string.format("%.1f tiles", data.distance))
                end
                if data.square then
                    tooltip:addField(getText("UI_FTI_Coordinates"),
                        string.format("%d, %d, %d", data.square:getX(), data.square:getY(), data.square:getZ()))
                end
                if data.rarity then
                    local c = FTI_Config.rarityColors[data.rarity] or { r = 1, g = 1, b = 1 }
                    tooltip:addField(getText("UI_FTI_Rarity"), data.rarity:upper(), c)
                end
            end

            -- finalize & show
            tooltip:adjustHeight()
            tooltip:adjustWidth()
            tooltip:setX(getMouseX() + 24)
            tooltip:setY(getMouseY() + 24)
            tooltip:addToUIManager()
            self.parent.tooltip = tooltip
        else
            -- not hoverable
            FTI_UI.hoveredItem = nil
        end
    end

    function win:update()
        ISCollapsableWindow.update(self)
        local mx, my = getMouseX(), getMouseY()
        if self.list and self.tooltip then
            local lx, ly = self.list:getAbsoluteX(), self.list:getAbsoluteY()
            local lw, lh = self.list:getWidth(), self.list:getHeight()
            if not (mx >= lx and mx < lx + lw and my >= ly and my < ly + lh) then
                self.tooltip:removeFromUIManager()
                self.tooltip = nil
            end
        end
    end

    -- Clear hover (and tooltip) when the mouse leaves the list
    win.list.onMouseLeave = function(self)
        FTI_UI.hoveredItem = nil
        if self.parent and self.parent.tooltip then
            self.parent.tooltip:removeFromUIManager()
            self.parent.tooltip = nil
        end
        if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
        FTI_UI.deferRedraw()
    end

    local origOnMouseDown = win.list.onMouseDown
    win.list.onMouseDown = function(self, x, y)
        -- Handle junk button clicks first
        if self._junkButtons then
            for idx, btn in pairs(self._junkButtons) do
                if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                    local fullType = btn.fullType
                    if fullType then
                        if FTI_Tracker.junkItems[fullType] then
                            FTI_Tracker.junkItems[fullType] = nil
                        else
                            FTI_Tracker.junkItems[fullType] = true
                        end
                        FTI_Tracker.saveJunkItems()
                        filterItemList()
                        FTI_UI.refreshLayout()
                        return
                    end
                end
            end
        end

        -- Otherwise default
        if origOnMouseDown then origOnMouseDown(self, x, y) end

        local function getAdjacentWalkableSquare(sq, player)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local adj = getCell():getGridSquare(
                            sq:getX() + dx, sq:getY() + dy, sq:getZ()
                        )
                        if adj
                            and adj:getChunk()
                            and not adj:Is(IsoFlagType.collideW)
                            and not adj:Is(IsoFlagType.collideN)
                            and not adj:Is(IsoFlagType.solidtrans)
                        then
                            return adj
                        end
                    end
                end
            end
            return nil
        end

        local function pathExists(startSq, goalSq, maxBreadth)
            local visited = {} -- keyed by "x,y,z"
            local function mark(sq)
                visited[string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ())] = true
            end
            local function seen(sq)
                return visited[string.format("%d,%d,%d", sq:getX(), sq:getY(), sq:getZ())]
            end

            local frontier = { startSq }
            mark(startSq)
            local depth = 0

            while #frontier > 0 and depth < maxBreadth do
                local nextFrontier = {}
                for _, sq in ipairs(frontier) do
                    -- found it?
                    if sq == goalSq then
                        return true
                    end
                    -- explore all 8 neighbors
                    for dx = -1, 1 do
                        for dy = -1, 1 do
                            if dx ~= 0 or dy ~= 0 then
                                local adj = getCell():getGridSquare(
                                    sq:getX() + dx, sq:getY() + dy, sq:getZ()
                                )
                                if adj
                                    and adj:getChunk()
                                    and not adj:Is(IsoFlagType.collideW)
                                    and not adj:Is(IsoFlagType.collideN)
                                    and not adj:Is(IsoFlagType.solidtrans)
                                    and not seen(adj)
                                then
                                    mark(adj)
                                    table.insert(nextFrontier, adj)
                                end
                            end
                        end
                    end
                end
                frontier = nextFrontier
                depth = depth + 1
            end

            return false
        end

        -- figure out which row was clicked
        local row = self:rowAt(x, y)
        if not row then return end

        local entry = self.items[row]
        if not entry then return end

        -- grab either the inventory item, the generator, or vehicle
        local data = entry.item or entry.generator or entry.vehicle
        if not data or not data.square then return end

        -- select & force a redraw
        FTI_UI.selectedItem = data
        if FTI_RenderVectors then FTI_RenderVectors.requestUpdate = true end
        FTI_UI.deferRedraw()
        if FTI_UI.refreshLayout then FTI_UI.refreshLayout() end

        local sq     = data.square
        local player = getPlayer()

        -- 1. Check if square is loaded
        if not sq:getChunk() then
            player:setHaloNote(getText("UI_FTI_CantWalk_ChunkNotLoaded"))
            return
        end

        -- 2. Same floor?
        if sq:getZ() ~= player:getZ() then
            player:setHaloNote(getText("UI_FTI_CantWalk_DifferentFloor"))
            return
        end

        -- 3. If the exact square is obstructed, try an adjacent one
        local targetSq = sq
        if sq:Is(IsoFlagType.collideW)
            or sq:Is(IsoFlagType.collideN)
            or sq:Is(IsoFlagType.solidtrans)
        then
            local adj = getAdjacentWalkableSquare(sq, player)
            if adj then
                targetSq = adj
            else
                player:setHaloNote(getText("UI_FTI_CantWalk_NoSpot"))
                return
            end
        end

        -- 4. **General pathfinding check**
        --    Now do a global path‐exists check (limit to, say, 500 tiles):
        if not pathExists(player:getCurrentSquare(), targetSq, 500) then
            player:setHaloNote(getText("UI_FTI_CantWalk_NoPath"))
            return
        end

        -- 5. Issue the walk-to action
        ISTimedActionQueue.clear(player)
        ISTimedActionQueue.add(ISWalkToTimedAction:new(player, targetSq))
    end

    -- Filtering: search bar
    win.entry.onTextChange = function(box)
        FTI_UI.searchText = box:getInternalText() or ""
        filterItemList()
        FTI_UI.refreshLayout()
        FTI_UI.deferRedraw()
        FTI_UI.saveUserTextState(box)
    end

    -- Custom layout for rarity and list (for initial and dynamic layout)
    function win:layoutUI()
        local rarityBottom = self.rarityFilterPanel.y + self.rarityFilterPanel:getHeight()
        local listY = rarityBottom + PADDING / 2
        local listH = self:getHeight() - listY - PADDING
        local listW = self:getWidth() - PADDING * 2

        if self.list then
            self.list:setY(listY)
            self.list:setHeight(listH)
            self.list:setWidth(listW)
            self.list:clear()
            FTI_UI.populateList(self.list)
            -- Make scrollbar match list height
            if self.list.vscroll then
                self.list.vscroll:setHeight(listH)
            end
        end
    end

    -- Handle visibility
    local oldSetVisible = win.setVisible
    function win:setVisible(visible)
        oldSetVisible(self, visible)
        FTI_UI.syncVectors()
    end

    -- initial world‐scan (so generators, items _and_ vehicles all get picked up immediately)
    FTI_Tracker.updateNearbyItems()
    -- then build & draw
    filterItemList()
    FTI_UI.syncVectors()

    -- Defer layout one frame for UI to settle
    local function deferredLayoutRender()
        Events.OnRenderTick.Remove(deferredLayoutRender)
        FTI_UI.refreshLayout()
        win.entry:onTextChange()
    end
    Events.OnRenderTick.Add(deferredLayoutRender)

    -- Call layoutUI after resize
    win.onResize = function(self, ...)
        -- Call the old resize handler, if there was one
        if oldResize then oldResize(self, ...) end

        -- Your resize logic:
        self.entry:setWidth(self:getWidth() - PADDING * 2)
        local filterY = self.entry.y + self.entry:getHeight() + PADDING
        local filterW = self:getWidth() - PADDING * 2
        self.rarityFilterPanel:setWidth(filterW)
        self.rarityFilterPanel:setY(filterY)

        local rarityBottom = self.rarityFilterPanel.y + self.rarityFilterPanel:getHeight()
        local listY = rarityBottom + PADDING / 2
        local listH = self:getHeight() - listY - PADDING
        if self.list then
            self.list:setHeight(listH)
            if self.list.vscroll then
                self.list.vscroll:setHeight(listH)
            end
        end

        FTI_UI.refreshLayout()
        FTI_UI.saveWindowState()
    end

    FTI_UI.hoveredSquare = nil
    if FTI_UI.window and FTI_UI.window.tooltip then
        FTI_UI.window.tooltip:removeFromUIManager()
        FTI_UI.window.tooltip = nil
    end
end

function FTI_UI.isSameEntry(a, b)
    if not a or not b then return false end
    if a.generator and b.generator then
        return a.generatorID == b.generatorID
    elseif a.vehicle and b.vehicle then
        return a.vehicleID == b.vehicleID and a.vehicle == b.vehicle
    elseif a.item and b.item then
        return a.item == b.item
    end
    return false
end

function FTI_UI.populateList(list)
    if not list then return end
    list:clear()

    for _, data in ipairs(FTI_UI.filteredItems or {}) do
        local name

        if data and data.item then
            name = data.displayName or data.name or getText("UI_FTI_UnknownItem")
        elseif data and data.generator then
            name = data.name or getText("UI_FTI_Generator")
        elseif data and data.vehicle then
            name = data.vehicleLabel or data.name or
                (data.vehicle and data.vehicle.getScript and data.vehicle:getScript() and data.vehicle:getScript().getDisplayName and data.vehicle:getScript():getDisplayName()) or
                (data.vehicle and data.vehicle.getScript and data.vehicle:getScript() and data.vehicle:getScript().getName and data.vehicle:getScript():getName()) or
                getText("UI_FTI_Vehicle")
        else
            name = getText("UI_FTI_UnknownItem")
        end

        if name then
            list:addItem(name, data)
        end
    end
end

function FTI_UI.isVectorVisible(data)
    if not (FTI_UI.showVectors and FTI_UI.window and FTI_UI.window:getIsVisible()) then
        return false
    end

    for _, item in ipairs(FTI_UI.filteredItems or {}) do
        if item.item and data.item and item.item == data.item then
            return true
        elseif item.generator and data.generator and item.generatorID == data.generatorID then
            return true
        elseif item.vehicle and data.vehicle and item.vehicleID == data.vehicleID then
            return true
        end
    end

    return false
end

-- Centralized cleanup for closing/hiding the FTI window and removing UI managers/tooltips/vectors
function FTI_UI.hideWindowAndCleanup(fromSetVisible)
    if not FTI_UI.window then return end

    if not fromSetVisible then
        FTI_UI.window:setVisible(false)
    end

    -- Remove vector rendering if active
    if FTI_UI._vectorsAdded then
        Events.OnPreUIDraw.Remove(FTI_RenderVectors.renderVectors)
        FTI_UI._vectorsAdded = false
    end

    FTI_Config.hudEnabled = false
    FTI_UI.syncHUDButton()
    FTI_UI.syncVectors()

    -- If the HUD icon supports "pressed" (for visual feedback)
    local FTI_Init = _G["FTI_Init"]
    if FTI_Init and FTI_Init.hudButton and FTI_Init.hudButton.setPressed then
        FTI_Init.hudButton:setPressed(false)
    end

    -- Remove tooltip if present
    if FTI_UI.window.tooltip then
        FTI_UI.window.tooltip:removeFromUIManager()
        FTI_UI.window.tooltip = nil
    end
end

function FTI_UI.showWindow()
    FTI_Config.hudEnabled = true
    FTI_UI.syncHUDButton()
    local FTI_Init = _G["FTI_Init"]
    if FTI_Init and FTI_Init.hudButton and FTI_Init.hudButton.setPressed then
        FTI_Init.hudButton:setPressed(true)
    end
    FTI_UI.createUI()
end

function FTI_UI.toggleHUD()
    local showing = FTI_UI.window and FTI_UI.window:getIsVisible()
    if showing then
        FTI_UI.hideWindowAndCleanup()
    else
        FTI_UI.showWindow()
    end
end

function FTI_UI.updateListIfVisible()
    if FTI_UI.window and FTI_UI.window:getIsVisible() then
        filterItemList()
        FTI_UI.refreshLayout()
    end
end

-- Force a full list redraw + vector update on the next tick
function FTI_UI.deferRedraw()
    local function redrawOnce()
        -- remove this callback immediately so it only runs once
        Events.OnTick.Remove(redrawOnce)

        -- re-layout & repopulate the list
        if FTI_UI.window and FTI_UI.window.layoutUI then
            FTI_UI.refreshLayout()
        end
        -- trigger vector re-render
        if FTI_RenderVectors then
            FTI_RenderVectors.requestUpdate = true
        end
    end

    -- schedule our one-time redraw on the next tick
    Events.OnTick.Add(redrawOnce)
end

function FTI_UI.syncVectors()
    local win = FTI_UI.window
    if win and win:getIsVisible() then
        if not FTI_UI._vectorsAdded then
            Events.OnPreUIDraw.Add(FTI_RenderVectors.renderVectors)
            FTI_UI._vectorsAdded = true
        end
    else
        if FTI_UI._vectorsAdded then
            Events.OnPoOnPreUIDrawtRender.Remove(FTI_RenderVectors.renderVectors)
            FTI_UI._vectorsAdded = false
        end
    end
end

function FTI_UI.refreshLayout()
    local win = FTI_UI.window
    if win and win.layoutUI then
        win:layoutUI()
    end
end

FTISimpleTooltip = ISPanel:derive("FTISimpleTooltip")

function FTISimpleTooltip:new()
    local width, height = 220, 8 -- starting values
    local o = ISPanel.new(self, 0, 0, width, height)
    o.backgroundColor = { r = 0.2, g = 0.2, b = 0.25, a = 0.98 }
    o.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 1 }
    o.textColor = { r = 1, g = 1, b = 1, a = 1 }
    o.font = UIFont.Small
    o.fields = {} -- will hold label/value pairs
    return o
end

function FTISimpleTooltip:addField(label, value, color)
    table.insert(self.fields, { label = label, value = value, color = color })
end

function FTISimpleTooltip:clearFields()
    self.fields = {}
end

function FTISimpleTooltip:prerender()
    -- Draw background and border (optional, can use ISPanel's default)
    ISPanel.prerender(self)
end

function FTISimpleTooltip:render()
    local x, y = 8, 8
    local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight()
    for _, field in ipairs(self.fields) do
        local labelStr = field.label .. ":"
        local valueStr = field.value or ""
        local color = field.color or self.textColor

        -- Draw left-aligned label
        self:drawText(labelStr, x, y, color.r, color.g, color.b, 1, self.font)
        -- Draw right-aligned value
        if valueStr ~= "" then
            local valueX = self:getWidth() - 10
            self:drawTextRight(valueStr, valueX, y, color.r, color.g, color.b, 1, self.font)
        end
        y = y + lineHeight
    end
end

function FTISimpleTooltip:adjustHeight()
    local lineHeight = getTextManager():getFontFromEnum(self.font):getLineHeight()
    self:setHeight(#self.fields * lineHeight + 16)
end

function FTISimpleTooltip:adjustWidth()
    local maxW = 0
    for _, field in ipairs(self.fields) do
        local w = getTextManager():MeasureStringX(self.font, field.label .. ": " .. tostring(field.value or ""))
        if w > maxW then maxW = w end
    end
    self:setWidth(maxW + 16)
end

function FTI_UI.saveRarityFilterState()
    local data = ModData.getOrCreate("FindThatItem")
    data.rarityChecks = FTI_UI.rarityChecks
    ModData.transmit("FindThatItem")
end

function FTI_UI.loadRarityFilterState()
    local data = ModData.getOrCreate("FindThatItem")
    if data.rarityChecks then
        FTI_UI.rarityChecks = data.rarityChecks
    end
end

function FTI_UI.saveWindowState()
    local data = ModData.getOrCreate("FindThatItem")
    if FTI_UI.window then
        data.windowX = FTI_UI.window:getX()
        data.windowY = FTI_UI.window:getY()
        data.windowCollapsed = FTI_UI.window.collapsed and true or false
        -- Only save size if not collapsed, so we restore expanded size!
        if not FTI_UI.window.collapsed then
            data.windowW = FTI_UI.window:getWidth()
            data.windowH = FTI_UI.window:getHeight()
        end
        ModData.transmit("FindThatItem")
    end
end

function FTI_UI.loadWindowState()
    local data = ModData.getOrCreate("FindThatItem")
    return data.windowX, data.windowY, data.windowW, data.windowH, data.windowCollapsed
end

function FTI_UI.saveUserTextState(textbox)
    local txt = textbox:getInternalText() or ""
    local data = ModData.getOrCreate("FindThatItem")
    data.userText = txt
    ModData.transmit("FindThatItem")
end

function FTI_UI.loadUserTextState()
    local data = ModData.getOrCreate("FindThatItem")
    if not data.userText then
        data.userText = ""
    end
    return data
end

function FTIHorizontalRarityFilter:layoutCheckBoxes()
    local font = UIFont.Small
    local margin = self.margin
    -- Keep spacing minimal for vertical stack
    local spacing = (self.verticalStack and 10) or self.spacing
    local labelWidths = self.labelWidths or {}
    local verticalStack = false
    local maxWidth = self:getWidth()
    local requiredWidth = margin

    self.labels = self.labels or {}
    for i, rarity in ipairs(self.rarities) do
        local count = FTI_UI and FTI_UI.rarityCounts and FTI_UI.rarityCounts[rarity] or 0
        local labelKey = FTI_Config.rarityConfig[i].label or ("UI_FTI_Rarity_" .. rarity:upper())
        self.labels[i] = getText(labelKey) .. " (" .. count .. ")"
        labelWidths[i] = getTextManager():MeasureStringX(font, self.labels[i])
    end
    self.labelWidths = labelWidths

    -- Check if horizontal layout fits
    for i, _ in ipairs(self.rarities) do
        requiredWidth = requiredWidth + self.checkSize + 4 + labelWidths[i]
        if i < #self.rarities then requiredWidth = requiredWidth + self.spacing end
    end
    if requiredWidth > maxWidth then
        verticalStack = true
    end

    -- For verticalStack, panel height = N*checkSize + (N-1)*spacing + 2*margin
    if verticalStack then
        local totalHeight = #self.rarities * self.checkSize + (#self.rarities - 1) * spacing + margin * 2
        self:setHeight(totalHeight)
        self.verticalStack = true
        self.rowHeight = self.checkSize -- Use only checkbox size, not font height
        self.spacing = spacing          -- Ensure minimal spacing
    else
        -- Horizontal: only as tall as checkboxes need to be
        local totalHeight = self.checkSize + margin * 2
        self:setHeight(totalHeight)
        self.verticalStack = false
        self.rowHeight = self.checkSize
        self.spacing = self.spacing
    end
end

Events.OnPlayerUpdate.Add(FTI_UI.updateListIfVisible)

return FTI_UI

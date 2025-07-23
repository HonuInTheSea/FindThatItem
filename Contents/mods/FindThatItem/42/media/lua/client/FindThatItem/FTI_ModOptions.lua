local config = {}

--- "UNIQUEID" should be replaced with your own unique ID. Possibly best to just use your mod's ID
local options = PZAPI.ModOptions:create("FindThatItem", getText("UI_FTI_Title"))

-- define your options here .....
options:addSlider("scanRadius", getText("UI_FTI_ScanRadius"), 5, 100, 1, 10, getText("UI_FTI_ScanRadius_tooltip"))

-- This is a helper function that will automatically populate the "config" table.
--- Retrieve each option as: config."ID"
options.apply = function(self)
    for k, v in pairs(self.dict) do
        if v.type == "multipletickbox" then
            for i = 1, #v.values do
                config[(k .. "_" .. tostring(i))] = v:getValue(i)
            end
        elseif v.type == "button" then
            -- do nothing
        else
            config[k] = v:getValue()
        end
    end
end

Events.OnMainMenuEnter.Add(function()
    options:apply()
end)

return config

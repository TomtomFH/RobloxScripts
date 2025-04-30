local placeId = game.PlaceId
local url = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"..placeId..".lua"

local function loadScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(url, true))()
    end)
end

loadScript()

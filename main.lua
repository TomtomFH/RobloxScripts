local placeId = game.PlaceId
local url = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"..placeId..".lua"

local function loadScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(url, true))()
    end)

    if not success then
        local notification = game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Error",
            Text = "Unable to load",
            Icon = "",
            Duration = 5
        })

        local retry = game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Retry",
            Text = "Try again?",
            Icon = "",
            Duration = 5,
            Button1Text = "OK",
            Button2Text = "Try Again",
            Button1Callback = function() end,
            Button2Callback = function()
                loadScript()
            end
        })
    end
end

loadScript()

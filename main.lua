local placeId = game.PlaceId
local url = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"..placeId..".lua"

local function loadScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(url, true))()
    end)

    if not success then
        local bindable = Instance.new("BindableFunction")
        
        function bindable.OnInvoke(response)
            if response == "OK" then
                print("OK chosen")
            elseif response == "Try Again" then
                print("Try Again chosen")
                loadScript()
            end
        end

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Error",
            Text = "Unable to load",
            Duration = 5,
            Callback = bindable,
            Button1 = "OK",
            Button2 = "Try Again"
        })
    end
end

loadScript()

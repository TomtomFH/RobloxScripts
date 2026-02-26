local placeId = game.PlaceId
local baseUrl = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"
local url = baseUrl..placeId..".lua"

-- Fetch and print version
local function printVersion()
    pcall(function()
        local versionUrl = baseUrl.."VERSION"
        local version = game:HttpGet(versionUrl, true)
        version = version:gsub("%s+", "")
        print("[RobloxScripts] Version: "..version)
    end)
end

local function loadScript()
    printVersion()
    local success, err = pcall(function()
        loadstring(game:HttpGet(url, true))()
    end)
    if not success then
        print("[RobloxScripts] Error loading script: "..tostring(err))
    end
end

loadScript()

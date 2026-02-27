local placeId = game.PlaceId
local baseUrl = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"
local cacheBust = "?cb=" .. tostring(os.time())
local url = baseUrl.."games/"..placeId..".lua"..cacheBust

-- Fetch and print version
local function printVersion()
    pcall(function()
        local versionUrl = baseUrl.."VERSION"..cacheBust
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


local placeId = game.PlaceId
local baseUrl = "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/"
local cacheBust = "?cb=" .. tostring(os.time())

local url = baseUrl .. "games/" .. placeId .. ".lua" .. cacheBust
local combatUrl = baseUrl .. "combat.lua" .. cacheBust
local libUrl = baseUrl .. "Lib.lua" .. cacheBust

local function printVersion()
    pcall(function()
        local version = game:HttpGet(baseUrl .. "VERSION" .. cacheBust, true)
        version = version:gsub("%s+", "")
        print("[RobloxScripts] Version: " .. version)
    end)
end

local function runScript(source, name)
    local success, err = pcall(function()
        local compiled, compileError = loadstring(source)

        if not compiled then
            error(compileError)
        end

        compiled()
    end)

    if not success then
        warn("[RobloxScripts] Error loading " .. name .. ": " .. tostring(err))
    end

    return success
end

local function showUnsupportedMenu()
    local success, err = pcall(function()
        local libSource = game:HttpGet(libUrl, true)
        local lib, compileError = loadstring(libSource)

        if not lib then
            error(compileError)
        end

        lib()

        local menuName = "RobloxScripts"
        local groupName = "Loader"
        local tabName = "Unsupported Game"

        local function closeMenu()
            local env = type(getgenv) == "function" and getgenv() or _G
            local runtime = rawget(env, "__TomtomFHUILibraryRuntime")

            if type(runtime) == "table" and type(runtime.Cleanup) == "function" then
                runtime.Cleanup()
            else
                DestroyMenu(menuName)
            end
        end

        CreateMenu(menuName)
        CreateGroup(menuName, groupName)
        CreateTab(menuName, groupName, tabName)

        CreateLabel(tabName, "This game is currently not supported.")
        CreateLabel(tabName, "Place ID: " .. tostring(placeId))
        CreateLabel(tabName, "You can still try the universal Combat script.")

        CreateButton(tabName, "Load Combat Script", function()
            local fetched, result = pcall(function()
                return game:HttpGet(combatUrl, true)
            end)

            if not fetched then
                warn("[RobloxScripts] Failed to fetch Combat: " .. tostring(result))
                return
            end

            closeMenu()
            runScript(result, "Combat")
        end)

        CreateButton(tabName, "Exit / Unload", function()
            closeMenu()
            print("[RobloxScripts] Loader closed.")
        end)
    end)

    if not success then
        warn("[RobloxScripts] Failed to create menu: " .. tostring(err))
    end
end

local function isNotFound(message)
    local text = tostring(message):lower()

    return text:find("404", 1, true) ~= nil
        or text:find("not found", 1, true) ~= nil
end

local function loadScript()
    printVersion()

    local success, result = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not success then
        if isNotFound(result) then
            showUnsupportedMenu()
        else
            warn("[RobloxScripts] Error fetching script: " .. tostring(result))
        end
        return
    end

    if isNotFound(result:match("^%s*(.-)%s*$")) and
        (#result < 100) then
        showUnsupportedMenu()
        return
    end

    runScript(result, "Game Script")
end

loadScript()

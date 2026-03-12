-- DEADLY DELIVERY (https://www.roblox.com/games/93044798454681/)

-- ============================================================
-- SETTINGS - Modify these to customize default behavior

local containersESPEnabled = false
local currencyESPEnabled = false
local itemsESPEnabled = false

-- Player Feature Default States
local playerWalkSpeed = 16
local function getSavedWalkSpeed()
    return tonumber(loadedConfig and loadedConfig.Player and loadedConfig.Player["Walk Speed"]) or playerWalkSpeed
end
local walkSpeedEnabled = false
local walkSpeedLoop = false
local walkSpeedConn = nil
-- ============================================================
-- SERVICE SETUP
-- ============================================================

local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local player = players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local HttpService = game:GetService("HttpService")

-- Load UI Library
loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

-- Manual config load
local configPath = "TomtomFHUI/TomtomFHUI_" .. tostring(game.PlaceId) .. ".json"
local loadedConfig = nil
if type(isfile) == "function" and isfile(configPath) then
    local ok, data = pcall(readfile, configPath)
    if ok and data then
        local success, parsed = pcall(HttpService.JSONDecode, HttpService, data)
        if success and parsed then
            loadedConfig = parsed
        end
    end
end

-- Force walk speed from config immediately after config is loaded
do
    local char = players.LocalPlayer.Character
    local ws = tonumber(Config and Config.Player and Config.Player["Walk Speed"]) or 16
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied from config: " .. ws)
    end
end

-- ============================================================
-- ESP Implementation (from Pressure Hadal Blacksite)
-- ============================================================
local activeESPs = {}
local containersESPs = {}
local currencyESPs = {}
local itemsESPs = {}

local function clearESPs(espTable)
    for inst,_ in pairs(espTable) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
        espTable[inst] = nil
    end
end

local function splitCamelCase(name)
    return name:gsub("(%l)(%u)", "%1 %2")
end


local function getBaseName(name)
    -- Remove everything after and including _
    local under = string.find(name, "_")
    if under then
        name = string.sub(name, 1, under - 1)
    end
    -- If CamelCase, split at capital letters and join with spaces
    local spaced = name:gsub("(%l)(%u)", "%1 %2")
    return spaced
end

local function createESP(model, color)
    if not model or not model:IsA("Model") then return end
    local interactable = model:FindFirstChild("Interactable")
    if not interactable then return end

    local b = Instance.new("BillboardGui")
    b.Name = "ESPBillboard"
    b.Adornee = interactable
    b.AlwaysOnTop = true
    b.Size = UDim2.new(0, 100, 0, 100)
    b.Parent = interactable

    local f = Instance.new("Frame")
    f.Parent = b
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color or Color3.new(1, 1, 1)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(0, 10, 0, 10)

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = f

    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.5, 0.5, 0.5))
    g.Rotation = 90
    g.Parent = f

    local s = Instance.new("UIStroke")
    s.Thickness = 2.5
    s.Parent = f

    local l = Instance.new("TextLabel")
    l.Parent = b
    l.AnchorPoint = Vector2.new(0, 0.5)
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 0, 0.5, 24)
    l.Size = UDim2.new(1, 0, 0.2, 0)
    -- Use loot price as ESP label if available
    local price = nil
    local lootUI = interactable:FindFirstChild("LootUI")
    if lootUI and lootUI:FindFirstChild("Frame") and lootUI.Frame:FindFirstChild("Price") then
        price = lootUI.Frame.Price.Text
    end
    l.Text = price or getBaseName(model.Name)
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.TextScaled = true

    local ls = Instance.new("UIStroke")
    ls.Thickness = 2.5
    ls.Parent = l

    activeESPs[b] = true
    -- Track by type
    if color and color.r == 0 and color.g == 1 and color.b == 0 then
        containersESPs[b] = true
    elseif color and color.r == 1 and color.g == 1 and color.b == 0 then
        currencyESPs[b] = true
    end

    -- Remove ESP if model's 'Open' attribute becomes true
    local function openListener()
        if model:GetAttribute("Open") == true then
            for espGui, _ in pairs(activeESPs) do
                if espGui.Adornee == interactable then
                    pcall(function() espGui:Destroy() end)
                    activeESPs[espGui] = nil
                end
            end
        end
    end
    model:GetAttributeChangedSignal("Open"):Connect(openListener)
    if model:GetAttribute("Open") == true then
        openListener()
    end
    return b
end

local function clearAllESPs()
    for inst,_ in pairs(activeESPs) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
        activeESPs[inst] = nil
    end
end

-- ============================================================
-- ESP Feature Implementation
-- ============================================================
local function createLootESP(item)
    print("idk someone called this function with", item.Name, "of type", item.ClassName)
    if item:isA("Tool") then
        print("[DEBUG] Tool detected: " .. item.Name)
        local folder = item:FindFirstChild("Folder")
        print("[DEBUG] Folder ref: " .. tostring(folder))
        if not folder then print("[DEBUG] Tool has no Folder: " .. item.Name) return end
        print("[DEBUG] Folder children: " .. table.concat((function()
            local names = {}
            for _,v in ipairs(folder:GetChildren()) do table.insert(names, v.Name) end
            return names
        end)(), ", "))
        local interactable = folder:FindFirstChild("Interactable")
        print("[DEBUG] Interactable ref: " .. tostring(interactable))
        if not interactable then print("[DEBUG] Tool Folder has no Interactable: " .. item.Name) return end
        print("[DEBUG] Adding ESP to Folder.Interactable for tool: " .. item.Name)
        print("[DEBUG] interactable children before ESP: " .. table.concat((function()
            local names = {}
            for _,v in ipairs(interactable:GetChildren()) do table.insert(names, v.Name) end
            return names
        end)(), ", "))
        -- Remove any existing ESP
        local old = interactable:FindFirstChild("ESPBillboard")
        if old then old:Destroy() end

        local b = Instance.new("BillboardGui")
        b.Name = "ESPBillboard"
        b.Adornee = interactable
        b.AlwaysOnTop = true
        b.Size = UDim2.new(0, 100, 0, 100)
        b.Parent = interactable

        print("[DEBUG] interactable children after ESP: " .. table.concat((function()
            local names = {}
            for _,v in ipairs(interactable:GetChildren()) do table.insert(names, v.Name) end
            return names
        end)(), ", "))

        local f = Instance.new("Frame")
        f.Parent = b
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
        f.Position = UDim2.new(0.5, 0, 0.5, 0)
        f.Size = UDim2.new(0, 10, 0, 10)

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = f

        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.5, 0.5, 0.5))
        g.Rotation = 90
        g.Parent = f

        local s = Instance.new("UIStroke")
        s.Thickness = 2.5
        s.Parent = f

        local l = Instance.new("TextLabel")
        l.Parent = b
        l.AnchorPoint = Vector2.new(0, 0.5)
        l.BackgroundTransparency = 1
        l.Position = UDim2.new(0, 0, 0.5, 24)
        l.Size = UDim2.new(1, 0, 0.2, 0)
        -- Use loot price as ESP label if available
        local price = nil
        local lootUI = interactable:FindFirstChild("LootUI")
        if lootUI and lootUI:FindFirstChild("Frame") and lootUI.Frame:FindFirstChild("Price") then
            price = lootUI.Frame.Price.Text
            print("[DEBUG] Tool ESP price label: " .. tostring(price))
        else
            print("[DEBUG] Tool ESP fallback label: " .. getBaseName(item.Name))
        end
        l.Text = price or getBaseName(item.Name)
        l.TextColor3 = Color3.fromRGB(255, 255, 0)
        l.TextScaled = true

        local ls = Instance.new("UIStroke")
        ls.Thickness = 2.5
        ls.Parent = l

        activeESPs[b] = true
        itemsESPs[b] = true
    elseif item:IsA("Model") then
        createESP(item, Color3.fromRGB(255, 255, 0))
    end
end

local function enableContainersESP()
    containersESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then return end
    local interactiveItem = gameSystem:FindFirstChild("InteractiveItem")
    if not interactiveItem then return end
    for _, model in ipairs(interactiveItem:GetChildren()) do
        if model:IsA("Model") then
            createESP(model, Color3.fromRGB(0, 255, 0), model.Name)
        end
    end
    if not _G.DeadlyDeliveryContainersESPListener then
        interactiveItem.ChildAdded:Connect(function(child)
            if containersESPEnabled and child:IsA("Model") then
                createESP(child, Color3.fromRGB(0, 255, 0), child.Name)
            end
        end)
        interactiveItem.ChildRemoved:Connect(function(child)
            for espGui, _ in pairs(activeESPs) do
                if espGui.Adornee == child then
                    pcall(function() espGui:Destroy() end)
                    activeESPs[espGui] = nil
                end
            end
        end)
        _G.DeadlyDeliveryContainersESPListener = true
    end
end

local function enableCurrencyESP()
    currencyESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then return end
    local loots = gameSystem:FindFirstChild("Loots")
    local worldLoots = loots and loots:FindFirstChild("World")
    if worldLoots then
        for _, item in ipairs(worldLoots:GetChildren()) do
            if item:IsA("Model") then
                createLootESP(item)
            end
        end
        worldLoots.ChildAdded:Connect(function(item)
            if currencyESPEnabled and item:IsA("Model") then
                createLootESP(item)
            end
        end)
        worldLoots.ChildRemoved:Connect(function(item)
            if item:IsA("Model") then
                local esp = item:FindFirstChild("ESPBillboard")
                if esp then esp:Destroy() end
            end
        end)
    end
end

local function enableItemsESP()
    itemsESPEnabled = true
    print("[DEBUG] enableItemsESP called")
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then print("[DEBUG] No GameSystem") return end
    local loots = gameSystem:FindFirstChild("Loots")
    if not loots then print("[DEBUG] No Loots") return end
    local worldLoots = loots:FindFirstChild("World")
    if not worldLoots then print("[DEBUG] No World in Loots") return end
    print("[DEBUG] enableItemsESP iterating World children:")
    for _, item in ipairs(worldLoots:GetChildren()) do
        print("[DEBUG] World child: " .. item.Name .. " type: " .. item.ClassName)
        if item:IsA("Tool") then
            print("[DEBUG] Found Tool: " .. item.Name)
            createLootESP(item)
        end
    end
    worldLoots.ChildAdded:Connect(function(item)
        print("[DEBUG] ChildAdded: " .. item.Name .. " type: " .. item.ClassName)
        if itemsESPEnabled and item:IsA("Tool") then
            print("[DEBUG] ChildAdded Tool: " .. item.Name)
            createLootESP(item)
        end
    end)
    worldLoots.ChildRemoved:Connect(function(item)
        if item:IsA("Tool") then
            local folder = item:FindFirstChild("Folder")
            local interactable = folder and folder:FindFirstChild("Interactable")
            if interactable then
                local esp = interactable:FindFirstChild("ESPBillboard")
                if esp then esp:Destroy() end
            end
        end
    end)
end

local function disableContainersESP()
    containersESPEnabled = false
    clearESPs(containersESPs)
end
local function disableCurrencyESP()
    currencyESPEnabled = false
    clearESPs(currencyESPs)
end
local function disableItemsESP()
    itemsESPEnabled = false
    clearESPs(itemsESPs)
end

local function disableESP()
    espEnabled = false
    clearAllESPs()
end

-- ============================================================
-- UI Setup
-- ============================================================
CreateMenu("Deadly Delivery")
CreateGroup("Deadly Delivery", "Main")
CreateTab("Deadly Delivery", "Main", "Visuals")

CreateLabel("Visuals", "ESP highlights Containers, Currency, and Items")
CreateToggle("Visuals", "Containers ESP", function(state)
    if state.Value then
        enableContainersESP()
    else
        disableContainersESP()
    end
end, containersESPEnabled)
CreateToggle("Visuals", "Currency ESP", function(state)
    if state.Value then
        enableCurrencyESP()
    else
        disableCurrencyESP()
    end
end, currencyESPEnabled)
CreateToggle("Visuals", "Items ESP", function(state)
    if state.Value then
        enableItemsESP()
    else
        disableItemsESP()
    end
end, itemsESPEnabled)

CreateTab("Deadly Delivery", "Main", "Player")

CreateLabel("Player", "Modify your walk speed")
local walkSpeedInput = CreateInput("Player", "Walk Speed", tostring(getSavedWalkSpeed()), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value > 0 then
        playerWalkSpeed = value
        print("[Deadly Delivery] Walk speed set to " .. value)
        -- Update loadedConfig for immediate effect
        if loadedConfig and loadedConfig.Player then
            loadedConfig.Player["Walk Speed"] = tostring(value)
        end
        SaveConfig()
        -- Immediately enforce new walk speed if enabled
        if walkSpeedEnabled then
            local char = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = value
            end
        end
    else
        print("[Deadly Delivery] Invalid walk speed")
    end
end)

CreateToggle("Player", "Enable Walk Speed", function(state)
    walkSpeedEnabled = state.Value
    local function applyWalkSpeed()
        local char = players.LocalPlayer.Character
        local ws = getSavedWalkSpeed()
        if char and char:FindFirstChild("Humanoid") then
            if walkSpeedEnabled then
                char.Humanoid.WalkSpeed = ws
                print("[Deadly Delivery] Walk speed enabled")
                if walkSpeedConn then walkSpeedConn:Disconnect() end
                walkSpeedConn = char.Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if walkSpeedEnabled and char.Humanoid.WalkSpeed ~= getSavedWalkSpeed() then
                        char.Humanoid.WalkSpeed = getSavedWalkSpeed()
                    end
                end)
            else
                char.Humanoid.WalkSpeed = 16
                print("[Deadly Delivery] Walk speed reset to default")
                if walkSpeedConn then walkSpeedConn:Disconnect() walkSpeedConn = nil end
            end
        end
    end
    applyWalkSpeed()
    -- Listen for character respawn
    players.LocalPlayer.CharacterAdded:Connect(function()
        if walkSpeedEnabled then
            task.wait(0.2)
            applyWalkSpeed()
        end
    end)
end, walkSpeedEnabled)
-- ============================================================
-- END OF SCRIPT
-- Force walk speed on script load if enabled
players.LocalPlayer.CharacterAdded:Connect(function(char)
    if walkSpeedEnabled and char and char:FindFirstChild("Humanoid") then
        local ws = getSavedWalkSpeed()
        playerWalkSpeed = ws
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied on respawn: " .. ws)
    end
end)

-- Apply walk speed immediately if enabled and character exists
do
    local char = players.LocalPlayer.Character
    if walkSpeedEnabled and char and char:FindFirstChild("Humanoid") then
        local ws = tonumber(loadedConfig and loadedConfig.Player and loadedConfig.Player["Walk Speed"]) or 16
        playerWalkSpeed = ws
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied on load: " .. ws)
    end
end
-- ============================================================

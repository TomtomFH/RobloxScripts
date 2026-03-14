-- DEADLY DELIVERY (https://www.roblox.com/games/93044798454681/)

local containersESPEnabled = false
local currencyESPEnabled = false
local itemsESPEnabled = false
local monstersESPEnabled = false
local npcsESPEnabled = false

local playerWalkSpeed = 16
local function getSavedWalkSpeed()
    return tonumber(loadedConfig and loadedConfig.Player and loadedConfig.Player["Walk Speed"]) or playerWalkSpeed
end
local walkSpeedEnabled = false
local walkSpeedLoop = false
local walkSpeedConn = nil

local fullbrightEnabled = false
local lighting = game:GetService("Lighting")
local originalLighting = {
    Brightness = lighting.Brightness,
    ClockTime = lighting.ClockTime,
    FogEnd = lighting.FogEnd,
    GlobalShadows = lighting.GlobalShadows,
    OutdoorAmbient = lighting.OutdoorAmbient,
}

local function applyFullbright()
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function restoreLighting()
    lighting.Brightness = originalLighting.Brightness
    lighting.ClockTime = originalLighting.ClockTime
    lighting.FogEnd = originalLighting.FogEnd
    lighting.GlobalShadows = originalLighting.GlobalShadows
    lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local player = players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local HttpService = game:GetService("HttpService")

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

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

do
    local char = players.LocalPlayer.Character
    local ws = tonumber(Config and Config.Player and Config.Player["Walk Speed"]) or 16
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied from config: " .. ws)
    end
end

local activeESPs = {}
local containersESPs = {}
local currencyESPs = {}
local itemsESPs = {}
local monstersESPs = {}
local npcsESPs = {}

local function clearESPs(espTable)
    for inst,_ in pairs(espTable) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
        espTable[inst] = nil
        activeESPs[inst] = nil
    end
end

local function splitCamelCase(name)
    return name:gsub("(%l)(%u)", "%1 %2")
end

local function getBaseName(name)
    local under = string.find(name, "_")
    if under then
        name = string.sub(name, 1, under - 1)
    end
    local spaced = name:gsub("(%l)(%u)", "%1 %2")
    return spaced
end

local function getESPAdornee(model)
    if not model or not model:IsA("Model") then return nil end
    return model:FindFirstChild("HumanoidRootPart", true)
end

local function createESP(model, color)
    if not model or not model:IsA("Model") then return end
    local interactable = model:FindFirstChild("Interactable")
    if not interactable then return end

    local old = interactable:FindFirstChild("ESPBillboard")
    if old then
        old:Destroy()
    end

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
    if color and color.r == 0 and color.g == 1 and color.b == 0 then
        containersESPs[b] = true
    elseif color and color.r == 1 and color.g == 1 and color.b == 0 then
        currencyESPs[b] = true
    end

    local function openListener()
        if model:GetAttribute("Open") == true then
            for espGui, _ in pairs(activeESPs) do
                if espGui.Adornee == interactable then
                    pcall(function() espGui:Destroy() end)
                    activeESPs[espGui] = nil
                    containersESPs[espGui] = nil
                    currencyESPs[espGui] = nil
                    itemsESPs[espGui] = nil
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

local function createHumanoidESP(model, color, trackerTable, labelText)
    if not model or not model:IsA("Model") then return end

    local adornee = getESPAdornee(model)
    if not adornee then return end

    local old = adornee:FindFirstChild("ESPBillboard")
    if old then
        old:Destroy()
    end

    local b = Instance.new("BillboardGui")
    b.Name = "ESPBillboard"
    b.Adornee = adornee
    b.AlwaysOnTop = true
    b.Size = UDim2.new(0, 100, 0, 100)
    b.Parent = adornee

    local f = Instance.new("Frame")
    f.Parent = b
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color
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
    l.Text = labelText or getBaseName(model.Name)
    l.TextColor3 = color
    l.TextScaled = true

    local ls = Instance.new("UIStroke")
    ls.Thickness = 2.5
    ls.Parent = l

    activeESPs[b] = true
    trackerTable[b] = true

    return b
end

local function removeModelESP(model, trackerTable)
    for espGui, _ in pairs(trackerTable) do
        if espGui and espGui.Parent then
            local adornee = espGui.Adornee
            if adornee and adornee:IsDescendantOf(model) then
                pcall(function() espGui:Destroy() end)
            end
        end
        if not espGui or not espGui.Parent then
            trackerTable[espGui] = nil
            activeESPs[espGui] = nil
        end
    end
end

local function clearAllESPs()
    for inst,_ in pairs(activeESPs) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
        activeESPs[inst] = nil
    end
    containersESPs = {}
    currencyESPs = {}
    itemsESPs = {}
    monstersESPs = {}
    npcsESPs = {}
end

local function createLootESP(item)
    if item:IsA("Tool") then
        local folder = item:FindFirstChild("Folder")
        if not folder then print("[DEBUG] Tool has no Folder: " .. item.Name) return end
        local interactable = folder:FindFirstChild("Interactable")
        if not interactable then print("[DEBUG] Tool Folder has no Interactable: " .. item.Name) return end
        local old = interactable:FindFirstChild("ESPBillboard")
        if old then old:Destroy() end

        local b = Instance.new("BillboardGui")
        b.Name = "ESPBillboard"
        b.Adornee = interactable
        b.AlwaysOnTop = true
        b.Size = UDim2.new(0, 100, 0, 100)
        b.Parent = interactable

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
                    containersESPs[espGui] = nil
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
        if not _G.DeadlyDeliveryCurrencyESPListener then
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
            _G.DeadlyDeliveryCurrencyESPListener = true
        end
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
    if not _G.DeadlyDeliveryItemsESPListener then
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
        _G.DeadlyDeliveryItemsESPListener = true
    end
end

local function enableMonstersESP()
    monstersESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then return end
    local monsters = gameSystem:FindFirstChild("Monsters")
    if not monsters then return end

    for _, model in ipairs(monsters:GetChildren()) do
        if model:IsA("Model") then
            createHumanoidESP(model, Color3.fromRGB(255, 0, 0), monstersESPs)
        end
    end

    if not _G.DeadlyDeliveryMonstersESPListener then
        monsters.ChildAdded:Connect(function(child)
            if monstersESPEnabled and child:IsA("Model") then
                createHumanoidESP(child, Color3.fromRGB(255, 0, 0), monstersESPs)
            end
        end)

        monsters.ChildRemoved:Connect(function(child)
            if child:IsA("Model") then
                removeModelESP(child, monstersESPs)
            end
        end)

        _G.DeadlyDeliveryMonstersESPListener = true
    end
end

local function enableNPCsESP()
    npcsESPEnabled = true
    local npcs = workspace:FindFirstChild("NPCs")
    if not npcs then return end

    for _, model in ipairs(npcs:GetChildren()) do
        if model:IsA("Model") then
            createHumanoidESP(model, Color3.fromRGB(0, 0, 255), npcsESPs)
        end
    end

    if not _G.DeadlyDeliveryNPCsESPListener then
        npcs.ChildAdded:Connect(function(child)
            if npcsESPEnabled and child:IsA("Model") then
                createHumanoidESP(child, Color3.fromRGB(0, 0, 255), npcsESPs)
            end
        end)

        npcs.ChildRemoved:Connect(function(child)
            if child:IsA("Model") then
                removeModelESP(child, npcsESPs)
            end
        end)

        _G.DeadlyDeliveryNPCsESPListener = true
    end
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

local function disableMonstersESP()
    monstersESPEnabled = false
    clearESPs(monstersESPs)
end

local function disableNPCsESP()
    npcsESPEnabled = false
    clearESPs(npcsESPs)
end

local function disableESP()
    espEnabled = false
    clearAllESPs()
end

CreateMenu("Deadly Delivery")
CreateGroup("Deadly Delivery", "Main")
CreateTab("Deadly Delivery", "Main", "Visuals")

CreateLabel("Visuals", "ESP highlights Containers, Currency, Items, Monsters, and NPCs")
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
CreateToggle("Visuals", "Monsters ESP", function(state)
    if state.Value then
        enableMonstersESP()
    else
        disableMonstersESP()
    end
end, monstersESPEnabled)
CreateToggle("Visuals", "NPCs ESP", function(state)
    if state.Value then
        enableNPCsESP()
    else
        disableNPCsESP()
    end
end, npcsESPEnabled)

CreateTab("Deadly Delivery", "Main", "Player")

CreateLabel("Player", "Modify your walk speed and lighting")
local walkSpeedInput = CreateInput("Player", "Walk Speed", tostring(getSavedWalkSpeed()), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value > 0 then
        playerWalkSpeed = value
        print("[Deadly Delivery] Walk speed set to " .. value)
        if loadedConfig and loadedConfig.Player then
            loadedConfig.Player["Walk Speed"] = tostring(value)
        end
        SaveConfig()
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
    players.LocalPlayer.CharacterAdded:Connect(function()
        if walkSpeedEnabled then
            task.wait(0.2)
            applyWalkSpeed()
        end
    end)
end, walkSpeedEnabled)

CreateToggle("Player", "Fullbright", function(state)
    fullbrightEnabled = state.Value
    if fullbrightEnabled then
        applyFullbright()
    else
        restoreLighting()
    end
end, fullbrightEnabled)

players.LocalPlayer.CharacterAdded:Connect(function(char)
    if walkSpeedEnabled and char and char:FindFirstChild("Humanoid") then
        local ws = getSavedWalkSpeed()
        playerWalkSpeed = ws
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied on respawn: " .. ws)
    end
end)

do
    local char = players.LocalPlayer.Character
    if walkSpeedEnabled and char and char:FindFirstChild("Humanoid") then
        local ws = tonumber(loadedConfig and loadedConfig.Player and loadedConfig.Player["Walk Speed"]) or 16
        playerWalkSpeed = ws
        char.Humanoid.WalkSpeed = ws
        print("[Deadly Delivery] Walk speed applied on load: " .. ws)
    end
end
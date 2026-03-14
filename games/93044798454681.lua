-- DEADLY DELIVERY (https://www.roblox.com/games/93044798454681/)

local containersESPEnabled = false
local currencyESPEnabled = false
local itemsESPEnabled = false
local monstersESPEnabled = false
local npcsESPEnabled = false

local lootESPMinValue = 0
local playerWalkSpeed = 16
local walkSpeedEnabled = false
local walkSpeedConn = nil
local fullbrightEnabled = false

local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local player = players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function notify(msg, isError)
    local ok = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Deadly Delivery",
            Text = tostring(msg),
            Duration = 4
        })
    end)
    if not ok then
        if isError then
            warn(msg)
        else
            print(msg)
        end
    end
end

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

local function saveCurrentConfig()
    if type(SaveConfig) == "function" then
        local ok = pcall(SaveConfig)
        if ok then
            return true
        end
    end

    if type(writefile) == "function" and Config then
        local ok = pcall(function()
            writefile(configPath, HttpService:JSONEncode(Config))
        end)
        return ok
    end

    return false
end

local function getLootESPMinValue()
    return tonumber((loadedConfig and loadedConfig.Visuals and loadedConfig.Visuals["Loot ESP Min Value"]) or (Config and Config.Visuals and Config.Visuals["Loot ESP Min Value"])) or lootESPMinValue
end

local function getSavedWalkSpeed()
    return tonumber((loadedConfig and loadedConfig.Player and loadedConfig.Player["Walk Speed"]) or (Config and Config.Player and Config.Player["Walk Speed"])) or playerWalkSpeed
end

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

local activeESPs = {}
local containersESPs = {}
local currencyESPs = {}
local itemsESPs = {}
local monstersESPs = {}
local npcsESPs = {}

local function clearESPs(espTable)
    for inst, _ in pairs(espTable) do
        if inst and inst.Parent then
            pcall(function()
                inst:Destroy()
            end)
        end
        espTable[inst] = nil
        activeESPs[inst] = nil
    end
end

local function getBaseName(name)
    local under = string.find(name, "_")
    if under then
        name = string.sub(name, 1, under - 1)
    end
    return name:gsub("(%l)(%u)", "%1 %2")
end

local function getESPAdornee(model)
    if not model or not model:IsA("Model") then
        return nil
    end
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    local hrp = model:FindFirstChild("HumanoidRootPart", true)
    if hrp then
        return hrp
    end
    local interactable = model:FindFirstChild("Interactable", true)
    if interactable then
        return interactable
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function removeTrackedESPByAdornee(targetAdornee, trackerTable)
    for espGui, _ in pairs(trackerTable) do
        if espGui and espGui.Adornee == targetAdornee then
            pcall(function()
                espGui:Destroy()
            end)
            trackerTable[espGui] = nil
            activeESPs[espGui] = nil
        elseif not espGui or not espGui.Parent then
            trackerTable[espGui] = nil
            activeESPs[espGui] = nil
        end
    end
end

local function buildBillboard(adornee, color, text)
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
    l.Text = text
    l.TextColor3 = color
    l.TextScaled = true

    local ls = Instance.new("UIStroke")
    ls.Thickness = 2.5
    ls.Parent = l

    return b
end

local function getPriceFromInteractable(interactable)
    if not interactable then
        return nil, nil
    end

    local lootUI = interactable:FindFirstChild("LootUI")
    if lootUI and lootUI:FindFirstChild("Frame") and lootUI.Frame:FindFirstChild("Price") then
        local priceText = lootUI.Frame.Price.Text
        local cleaned = tostring(priceText):gsub("[^%d%.%-]", "")
        local priceNum = tonumber(cleaned)
        return priceText, priceNum
    end

    return nil, nil
end

local function createESP(model, color, trackerTable, labelText)
    if not model or not model:IsA("Model") then
        return
    end

    local interactable = model:FindFirstChild("Interactable", true)
    if not interactable then
        return
    end

    local priceText = nil
    local b = buildBillboard(interactable, color or Color3.new(1, 1, 1), labelText or priceText or getBaseName(model.Name))

    activeESPs[b] = true
    if trackerTable then
        trackerTable[b] = true
    end

    local function openListener()
        if model:GetAttribute("Open") == true then
            pcall(function()
                b:Destroy()
            end)
            activeESPs[b] = nil
            if trackerTable then
                trackerTable[b] = nil
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
    if not model or not model:IsA("Model") then
        return
    end

    local adornee = getESPAdornee(model)
    if not adornee then
        return
    end

    local b = buildBillboard(adornee, color, labelText or getBaseName(model.Name))

    activeESPs[b] = true
    trackerTable[b] = true

    return b
end

local function removeModelESP(model, trackerTable)
    for espGui, _ in pairs(trackerTable) do
        if espGui and espGui.Parent then
            local adornee = espGui.Adornee
            if adornee and adornee:IsDescendantOf(model) then
                pcall(function()
                    espGui:Destroy()
                end)
            end
        end
        if not espGui or not espGui.Parent then
            trackerTable[espGui] = nil
            activeESPs[espGui] = nil
        end
    end
end

local function clearAllESPs()
    for inst, _ in pairs(activeESPs) do
        if inst and inst.Parent then
            pcall(function()
                inst:Destroy()
            end)
        end
        activeESPs[inst] = nil
    end
    containersESPs = {}
    currencyESPs = {}
    itemsESPs = {}
    monstersESPs = {}
    npcsESPs = {}
end

local function createLootESP(item, trackerTable)
    if item:IsA("Tool") then
        local folder = item:FindFirstChild("Folder")
        if not folder then
            return
        end

        local interactable = folder:FindFirstChild("Interactable")
        if not interactable then
            return
        end

        local priceText, priceNum = getPriceFromInteractable(interactable)
        local minValue = getLootESPMinValue()
        if priceNum and priceNum < minValue then
            return
        end

        local b = buildBillboard(interactable, Color3.fromRGB(255, 255, 0), priceText or getBaseName(item.Name))

        activeESPs[b] = true
        if trackerTable then
            trackerTable[b] = true
        end
    elseif item:IsA("Model") then
        local interactable = item:FindFirstChild("Interactable", true)
        if not interactable then
            return
        end

        local priceText, priceNum = getPriceFromInteractable(interactable)
        local minValue = getLootESPMinValue()
        if priceNum and priceNum < minValue then
            return
        end

        createESP(item, Color3.fromRGB(255, 255, 0), trackerTable, priceText or getBaseName(item.Name))
    end
end

local function enableContainersESP()
    containersESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then
        return
    end

    local interactiveItem = gameSystem:FindFirstChild("InteractiveItem")
    if not interactiveItem then
        return
    end

    for _, model in ipairs(interactiveItem:GetChildren()) do
        if model:IsA("Model") then
            createESP(model, Color3.fromRGB(0, 255, 0), containersESPs)
        end
    end

    if not _G.DeadlyDeliveryContainersESPListener then
        interactiveItem.ChildAdded:Connect(function(child)
            if containersESPEnabled and child:IsA("Model") then
                createESP(child, Color3.fromRGB(0, 255, 0), containersESPs)
            end
        end)

        interactiveItem.ChildRemoved:Connect(function(child)
            local interactable = child:IsA("Model") and child:FindFirstChild("Interactable", true) or nil
            if interactable then
                removeTrackedESPByAdornee(interactable, containersESPs)
            end
        end)

        _G.DeadlyDeliveryContainersESPListener = true
    end
end

local function enableCurrencyESP()
    currencyESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then
        return
    end

    local loots = gameSystem:FindFirstChild("Loots")
    local worldLoots = loots and loots:FindFirstChild("World")
    if not worldLoots then
        return
    end

    for _, item in ipairs(worldLoots:GetChildren()) do
        if item:IsA("Model") then
            createLootESP(item, currencyESPs)
        end
    end

    if not _G.DeadlyDeliveryCurrencyESPListener then
        worldLoots.ChildAdded:Connect(function(item)
            if currencyESPEnabled and item:IsA("Model") then
                createLootESP(item, currencyESPs)
            end
        end)

        worldLoots.ChildRemoved:Connect(function(item)
            if item:IsA("Model") then
                local interactable = item:FindFirstChild("Interactable", true)
                if interactable then
                    removeTrackedESPByAdornee(interactable, currencyESPs)
                end
            end
        end)

        _G.DeadlyDeliveryCurrencyESPListener = true
    end
end

local function enableItemsESP()
    itemsESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then
        return
    end

    local loots = gameSystem:FindFirstChild("Loots")
    if not loots then
        return
    end

    local worldLoots = loots:FindFirstChild("World")
    if not worldLoots then
        return
    end

    for _, item in ipairs(worldLoots:GetChildren()) do
        if item:IsA("Tool") then
            createLootESP(item, itemsESPs)
        end
    end

    if not _G.DeadlyDeliveryItemsESPListener then
        worldLoots.ChildAdded:Connect(function(item)
            if itemsESPEnabled and item:IsA("Tool") then
                createLootESP(item, itemsESPs)
            end
        end)

        worldLoots.ChildRemoved:Connect(function(item)
            if item:IsA("Tool") then
                local folder = item:FindFirstChild("Folder")
                local interactable = folder and folder:FindFirstChild("Interactable")
                if interactable then
                    removeTrackedESPByAdornee(interactable, itemsESPs)
                end
            end
        end)

        _G.DeadlyDeliveryItemsESPListener = true
    end
end

local function enableMonstersESP()
    monstersESPEnabled = true
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then
        return
    end

    local monsters = gameSystem:FindFirstChild("Monsters")
    if not monsters then
        return
    end

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
    local gameSystem = workspace:FindFirstChild("GameSystem")
    if not gameSystem then
        return
    end

    local npcs = gameSystem:FindFirstChild("NPCModels")
    if not npcs then
        return
    end

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

local function applyWalkSpeed()
    local char = player.Character
    if not char then
        return
    end

    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end

    if walkSpeedConn then
        walkSpeedConn:Disconnect()
        walkSpeedConn = nil
    end

    if walkSpeedEnabled then
        local ws = getSavedWalkSpeed()
        playerWalkSpeed = ws
        humanoid.WalkSpeed = ws
        walkSpeedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if walkSpeedEnabled and humanoid.WalkSpeed ~= getSavedWalkSpeed() then
                humanoid.WalkSpeed = getSavedWalkSpeed()
            end
        end)
    else
        humanoid.WalkSpeed = 16
    end
end

do
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = getSavedWalkSpeed()
    end
end

CreateMenu("Deadly Delivery")

CreateGroup("Deadly Delivery", "Main")
CreateTab("Deadly Delivery", "Main", "Visuals")

CreateGroup("Deadly Delivery", "Player")
CreateTab("Deadly Delivery", "Player", "Player")

CreateLabel("Visuals", "ESP highlights Containers, Currency, Items, Monsters, and NPCs")

CreateInput("Visuals", "Loot ESP Min Value", tostring(getLootESPMinValue()), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if not value or value < 0 then
        notify("Invalid loot ESP min value", true)
        return
    end

    lootESPMinValue = value

    Config = Config or {}
    Config.Visuals = Config.Visuals or {}
    Config.Visuals["Loot ESP Min Value"] = tostring(value)
    loadedConfig = loadedConfig or {}
    loadedConfig.Visuals = loadedConfig.Visuals or {}
    loadedConfig.Visuals["Loot ESP Min Value"] = tostring(value)

    saveCurrentConfig()
    notify("Loot ESP min value set to " .. tostring(value))

    if itemsESPEnabled then
        disableItemsESP()
        enableItemsESP()
    end

    if currencyESPEnabled then
        disableCurrencyESP()
        enableCurrencyESP()
    end
end)

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

CreateInput("Player", "Walk Speed", tostring(getSavedWalkSpeed()), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if not value or value <= 0 then
        notify("Invalid walk speed", true)
        return
    end

    playerWalkSpeed = value

    Config = Config or {}
    Config.Player = Config.Player or {}
    Config.Player["Walk Speed"] = tostring(value)
    loadedConfig = loadedConfig or {}
    loadedConfig.Player = loadedConfig.Player or {}
    loadedConfig.Player["Walk Speed"] = tostring(value)

    saveCurrentConfig()

    if walkSpeedEnabled then
        applyWalkSpeed()
    end

    notify("Walk speed set to " .. tostring(value))
end)

CreateToggle("Player", "Walk Speed Enabled", function(state)
    walkSpeedEnabled = state.Value
    applyWalkSpeed()
end, walkSpeedEnabled)

CreateToggle("Player", "Fullbright", function(state)
    fullbrightEnabled = state.Value
    if fullbrightEnabled then
        applyFullbright()
    else
        restoreLighting()
    end
end, fullbrightEnabled)

player.CharacterAdded:Connect(function()
    task.wait(0.2)
    applyWalkSpeed()
    if fullbrightEnabled then
        applyFullbright()
    end
end)
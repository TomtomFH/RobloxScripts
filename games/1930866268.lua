-- Build A Boat For Treasure - Winter Place (https://www.roblox.com/games/1930866268/)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local placeStatusLabel = nil
local currentActionLabel = nil
local enemyCountLabel = nil
local autofarmEnabled = false
local autofarmThread = nil
local enemyThreads = {}

local universePlaces = {
    {Name = "Build A Boat For Treasure", PlaceId = 537413528},
    {Name = "The Test Place", PlaceId = 1930665568},
    {Name = "Inner Cloud", PlaceId = 1930863474},
    {Name = "Winter Place", PlaceId = 1930866268}
}

local function setPlaceStatus(text)
    if placeStatusLabel then
        placeStatusLabel.Text = "Status: " .. tostring(text)
    end
end

local function teleportToPlace(place)
    if not place then
        return
    end

    if game.PlaceId == place.PlaceId then
        setPlaceStatus("Already in " .. place.Name)
        return
    end

    setPlaceStatus("Teleporting to " .. place.Name)

    local success, err = pcall(function()
        TeleportService:Teleport(place.PlaceId, LocalPlayer)
    end)

    if not success then
        setPlaceStatus("Teleport failed: " .. tostring(err))
    end
end

local function setCurrentAction(text)
    if currentActionLabel then
        currentActionLabel.Text = "Current Action: " .. tostring(text)
    end
end

local function getCharacter()
    local character = LocalPlayer.Character
    if character and character.Parent then
        return character
    end

    return LocalPlayer.CharacterAdded:Wait()
end

local function getSnowball()
    local character = getCharacter()
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 2)
    local snowball = character and (character:FindFirstChild("Snowball") or character:WaitForChild("Snowball", 0.15))

    if not snowball and backpack then
        snowball = backpack:FindFirstChild("Snowball") or backpack:WaitForChild("Snowball", 0.5)
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if snowball and humanoid then
            humanoid:EquipTool(snowball)
            snowball = character:FindFirstChild("Snowball") or character:WaitForChild("Snowball", 0.5) or snowball
        end
    end

    character = LocalPlayer.Character
    return character and character:FindFirstChild("Snowball") or snowball
end

local function getEnemyPosition(enemy)
    if not enemy or not enemy.Parent then
        return nil
    end

    if enemy:IsA("Model") then
        local humanoidRootPart = enemy:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
            return humanoidRootPart.Position
        end

        local success, cframe = pcall(function()
            return enemy:GetPivot()
        end)

        if success then
            return cframe.Position
        end

        local part = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end

    if enemy:IsA("BasePart") then
        return enemy.Position
    end

    return nil
end

local function getEnemies()
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then
        return {}
    end

    local enemies = {}
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        if enemy:IsA("Model") and getEnemyPosition(enemy) then
            table.insert(enemies, enemy)
        end
    end

    return enemies
end

local function updateEnemyCount()
    if enemyCountLabel then
        enemyCountLabel.Text = "Enemies: " .. tostring(#getEnemies())
    end
end

local function throwSnowballAt(enemy)
    local position = getEnemyPosition(enemy)
    if not position then
        return false
    end

    local snowball = getSnowball()
    if not snowball then
        setCurrentAction("Waiting for Snowball")
        return false
    end

    local remote = snowball:FindFirstChild("ThrowSnowball") or snowball:WaitForChild("ThrowSnowball", 0.2)
    if not remote or not remote:IsA("RemoteFunction") then
        setCurrentAction("ThrowSnowball remote missing")
        return false
    end

    local handle = snowball:FindFirstChild("Handle") or snowball:WaitForChild("Handle", 0.2)
    if not handle or not handle:IsA("BasePart") then
        setCurrentAction("Snowball handle missing")
        return false
    end

    local startCFrame = handle.CFrame
    local targetCFrame = CFrame.new(position)
    local success = pcall(function()
        remote:InvokeServer(startCFrame, targetCFrame, 10000)
    end)

    return success
end

local function startEnemyThread(enemy)
    if enemyThreads[enemy] then
        return
    end

    enemyThreads[enemy] = task.spawn(function()
        while autofarmEnabled and enemy.Parent do
            throwSnowballAt(enemy)
            task.wait()
        end

        enemyThreads[enemy] = nil
    end)
end

local function runAutofarm()
    while autofarmEnabled do
        updateEnemyCount()

        local enemies = getEnemies()
        if #enemies == 0 then
            setCurrentAction("Waiting for enemies")
            task.wait(0.15)
            continue
        end

        setCurrentAction("Throwing snowballs")
        for _, enemy in ipairs(enemies) do
            if not autofarmEnabled then
                break
            end

            if enemy.Parent then
                startEnemyThread(enemy)
            end
        end

        task.wait()
    end

    table.clear(enemyThreads)
    setCurrentAction("Off")
    updateEnemyCount()
end

local function setAutofarmEnabled(enabled)
    autofarmEnabled = enabled

    if autofarmEnabled then
        setCurrentAction("Starting")

        if not autofarmThread then
            autofarmThread = task.spawn(function()
                runAutofarm()
                autofarmThread = nil
            end)
        end
    else
        setCurrentAction("Off")
    end
end

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Autofarm")
CreateTab("Build A Boat", "Main", "Places")

currentActionLabel = select(1, CreateValueLabel("Autofarm", "Current Action: Off"))
enemyCountLabel = select(1, CreateValueLabel("Autofarm", "Enemies: 0"))

CreateToggle("Autofarm", "Autofarm", function(state)
    setAutofarmEnabled(state.Value)
end, false)

placeStatusLabel = select(1, CreateValueLabel("Places", "Status: Ready"))

for _, place in ipairs(universePlaces) do
    local targetPlace = place
    local buttonText = targetPlace.Name
    if game.PlaceId == targetPlace.PlaceId then
        buttonText = buttonText .. " (Current)"
    end

    CreateButton("Places", buttonText, function()
        teleportToPlace(targetPlace)
    end)
end

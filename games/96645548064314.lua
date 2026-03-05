-- CATCH AND TAME (https://www.roblox.com/games/96645548064314/)

-- ============================================================
-- SETTINGS - Modify these to customize default behavior
-- ============================================================

-- Breeding Configuration
local crossBreedingPairs = {
    -- Cross-breeding pairs
    { "Red Panda", "Kitsune" },
    { "Red Panda", "Axolotl" },
    { "Lightning Dragon", "Cerberus" },
    { "Griffin", "Cosmic Griffin" },
    { "Hydra", "Cosmic Griffin" },
    { "Galaxy Kitsune", "Galaxy Axolotl" }
}

local selfBreedingPairs = {
    -- Self-breeding pairs (for when you have multiple of the same pet)
    { "Red Panda", "Red Panda" },
    { "Kitsune", "Kitsune" },
    { "Axolotl", "Axolotl" },
    { "Lightning Dragon", "Lightning Dragon" },
    { "Cosmic Griffin", "Cosmic Griffin" },
    { "Hydra", "Hydra" },
    { "Galaxy Kitsune", "Galaxy Kitsune" },
    { "Galaxy Axolotl", "Galaxy Axolotl" }
}

-- Catch Settings
local catchCps = 40  -- Progress updates per second during minigame
local minCatchRPS = 1000  -- Minimum RPS required to catch (0 = disabled)
local ignoreMinRPSForSecret = false  -- Catch Secret pets regardless of min RPS
local ignoreMinRPSForExclusive = false  -- Catch Exclusive pets regardless of min RPS
local ignoreMinRPSForMissing = false  -- Catch missing pets regardless of min RPS
local ignoreMinRPSForBestCustom = false  -- Catch Best Custom regardless of min RPS
local appliedThreshold = 1000  -- RPS threshold for "new best pet" warning

-- Auto-Catch Default States
local autoCatchBest = false  -- Auto-catch best overall pet
local autoCatchMythical = false  -- Auto-catch best Mythical+ pet
local autoCatchMissing = false  -- Auto-catch best missing pet
local autoCatchCustom = false  -- Auto-catch best custom filtered pet

-- Custom Pet Filters
local customPetFilters = {}  -- Format: {["PetName_MutationCombo"] = true}

-- Breeding Default States
local autoBreedEnabled = false  -- Auto-breed configured pairs
local selfBreedingEnabled = false  -- Allow pets to breed with themselves
local customBreedingEnabled = false  -- Enable custom breeding pairs

-- Auto Features Default States
local autoRemoveEggsEnabled = false  -- Auto-remove eggs from pen
local autoBuyFoodEnabled = false  -- Auto-buy food when available
local autoBuyMerchantEnabled = false  -- Auto-buy from traveling merchant
local merchantPurchaseDelay = 0.1  -- Delay between merchant purchases (seconds)

-- Auto Sell Default States
local autoSellLegendaryEggsEnabled = false  -- Auto-sell Legendary eggs
local autoSellMythicalEggsEnabled = false  -- Auto-sell Mythical eggs

-- Save Cycling Settings
local autoCycleSavesEnabled = false  -- Auto-cycle through save slots
local autoCollectPetCashEnabled = false  -- Collect pet cash before switching saves
local saveSlot1Time = 375  -- Time to stay on slot 1 (seconds)
local saveSlot2Time = 375  -- Time to stay on slot 2 (seconds)
local saveSlot3Time = 375  -- Time to stay on slot 3 (seconds)
local saveSlot4Time = 375  -- Time to stay on slot 4 (seconds)

-- ============================================================
-- END SETTINGS
-- ============================================================

local catchDelay = 1 / catchCps

-- ============================================================
-- LOG CAPTURE SYSTEM - Capture all prints to clipboard on Ctrl+C
-- ============================================================
local logBuffer = {}
local originalPrint = print

-- Override global print to capture output
print = function(...)
    local args = {...}
    local message = table.concat(args, " ")
    table.insert(logBuffer, os.date("[%H:%M:%S] ") .. message)
    originalPrint(...) -- Still call original print
end

-- Set up Ctrl+C to copy logs to clipboard
task.spawn(function()
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Check for Ctrl+C (KeyCode.C with LeftControl or RightControl)
        if input.KeyCode == Enum.KeyCode.C then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                local logText = table.concat(logBuffer, "\n")
                if setclipboard then
                    setclipboard(logText)
                    originalPrint("[Logger] Copied " .. #logBuffer .. " log entries to clipboard")
                else
                    originalPrint("[Logger] setclipboard not available in your executor")
                end
            end
        end
    end)
end)

print("[Logger] Log capture initialized - Press Ctrl+C to copy all logs to clipboard")

-- ============================================================
-- END LOG CAPTURE SYSTEM
-- ============================================================

local folders = {
    workspace.SkyIslandPets.Pets,
    workspace.RoamingPets.Pets,
    workspace.WaterIslandPets.Pets
}

local player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("knit"))
local FoodConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Food"))
local rarityGradientsFolder = nil

pcall(function()
    local uiFolder = ReplicatedStorage:WaitForChild("UI", 10)
    if uiFolder then
        rarityGradientsFolder = uiFolder:WaitForChild("RarityGradients", 10)
    end
end)

-- Load UI Library
local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

-- Load Discord Webhook Utility
local sendWebhook = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/utils/discord_webhook.lua", true))()

local function getConfigSetting(tabName, entryName)
    if type(GetConfigValue) == "function" then
        return GetConfigValue(tabName, entryName)
    end

    if Config and type(Config) == "table" and type(Config[tabName]) == "table" then
        return Config[tabName][entryName]
    end

    return nil
end

local function setConfigSetting(tabName, entryName, value)
    if type(SetConfigValue) == "function" then
        SetConfigValue(tabName, entryName, value)
        return
    end

    if not Config or type(Config) ~= "table" then
        Config = {}
    end

    if type(Config[tabName]) ~= "table" then
        Config[tabName] = {}
    end

    Config[tabName][entryName] = value
    SaveConfig()
end

-- Notification helper
local snackbar = nil
local function notify(message, isError)
    if not snackbar then
        local ok, controller = pcall(function()
            return Knit.GetController("SnackbarController")
        end)
        if ok then
            snackbar = controller
        end
    end
    
    if snackbar then
        pcall(function()
            if isError then
                snackbar:Error(message)
            else
                snackbar:Success(message)
            end
        end)
    end
end

-- Load pets config
local petsConfig = {}
local playerPetIndex = {}
local function loadPetsConfig()
    pcall(function()
        petsConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Pets"))
    end)
end

local function loadPlayerPetIndex()
    pcall(function()
        local getPlayerIndex = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("getPlayerIndex")
        playerPetIndex = getPlayerIndex:InvokeServer() or {}
    end)
end
task.spawn(loadPetsConfig)
loadPlayerPetIndex()

-- Refresh player pet index periodically
task.spawn(function()
    while true do
        task.wait(3)
        loadPlayerPetIndex()
    end
end)

-- Setup minigame auto-complete hook
local CurrentMinigameInstance = nil
task.spawn(function()
    local StarterPlayer = game:GetService("StarterPlayer")
    local lassoMinigameUI = StarterPlayer.StarterPlayerScripts.Controllers.UI.lassoUI.lassoMinigameUI
    local LassoMinigameModule = require(lassoMinigameUI)
    
    local OriginalStartMinigame = LassoMinigameModule.StartMinigame
    LassoMinigameModule.StartMinigame = function(self, difficulty, pet)
        local minigame = OriginalStartMinigame(self, difficulty, pet)
        CurrentMinigameInstance = minigame
        local minigamePet = pet

        task.spawn(function()
            local updateProgressRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateProgress")
            local progressPerClick = CurrentMinigameInstance.progressPerClick or 25
            local serverProgress = 0

            while CurrentMinigameInstance
                and CurrentMinigameInstance.minigameActive
                and minigamePet
                and minigamePet.Parent do
                if serverProgress < 100 then
                    serverProgress = math.clamp(serverProgress + progressPerClick, 0, 100)
                else
                    serverProgress = 100
                end

                CurrentMinigameInstance.progress = serverProgress

                if CurrentMinigameInstance.UpdateFillBar then
                    CurrentMinigameInstance:UpdateFillBar()
                end
                if CurrentMinigameInstance.UpdateCatchingEffects then
                    CurrentMinigameInstance:UpdateCatchingEffects()
                end

                if serverProgress >= 100 then
                    pcall(function()
                        updateProgressRemote:FireServer(100)
                    end)
                    task.wait(catchDelay)
                else
                    task.wait(0.01)
                end
            end
        end)

        return minigame
    end
end)

-- Create UI Menu
CreateMenu("Catch And Tame")
CreateGroup("Catch And Tame", "Main")
CreateTab("Catch And Tame", "Main", "Catching")
CreateTab("Catch And Tame", "Main", "Breeding")
CreateTab("Catch And Tame", "Main", "Auto Buy")
CreateTab("Catch And Tame", "Main", "Auto Sell")
CreateTab("Catch And Tame", "Main", "Pet Warning")
CreateTab("Catch And Tame", "Main", "Save Cycling")
CreateTab("Catch And Tame", "Main", "Menus")
CreateTab("Catch And Tame", "Main", "Feedback")

local function resolveUiRoot()
    local playerGui = player:WaitForChild("PlayerGui")

    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            local gui = hui:FindFirstChild("TomtomFHUI") or hui:WaitForChild("TomtomFHUI", 3)
            if gui then
                return gui
            end
        end
    end

    local coreGui = game:GetService("CoreGui")
    local coreUi = coreGui:FindFirstChild("TomtomFHUI") or coreGui:WaitForChild("TomtomFHUI", 3)
    if coreUi then
        return coreUi
    end

    return playerGui:WaitForChild("TomtomFHUI")
end

local uiRoot = resolveUiRoot()
local warningLabel = Instance.new("TextLabel")
warningLabel.Size = UDim2.new(0, 520, 0, 60)
warningLabel.Position = UDim2.new(0.5, -260, 0, 10)
warningLabel.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
warningLabel.TextWrapped = true
warningLabel.TextScaled = true
warningLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
warningLabel.Visible = false
warningLabel.ZIndex = 10
warningLabel.Parent = uiRoot

Instance.new("UICorner", warningLabel).CornerRadius = UDim.new(0, 8)

local infoLabel = CreateValueLabel("Catching", "Scanning...")

local cardsRow = CreateContainer("Catching", 330, true)

local function createPetCard(parent, titleText, titleColor, position)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(0.5, -5, 0, 160)
    card.Position = position
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    card.BorderSizePixel = 0
    card.AutoButtonColor = false
    card.Text = ""
    card.Parent = parent

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = titleColor
    title.TextSize = 16
    title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local image = Instance.new("ImageLabel", card)
    image.Size = UDim2.new(0, 60, 0, 60)
    image.Position = UDim2.new(0, 10, 0, 35)
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
    image.Parent = card

    Instance.new("UICorner", image).CornerRadius = UDim.new(0, 6)

    local info = Instance.new("TextLabel", card)
    info.Size = UDim2.new(0.65, -10, 0, 90)
    info.Position = UDim2.new(0, 80, 0, 35)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(255, 255, 255)
    info.TextWrapped = true
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    info.TextSize = 11
    info.Text = "No pet found"
    info.Parent = card

    local toggle = Instance.new("TextButton", card)
    toggle.Size = UDim2.new(1, -20, 0, 22)
    toggle.Position = UDim2.new(0, 10, 1, -30)
    toggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.TextSize = 13
    toggle.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    toggle.Text = "Auto Catch: OFF"
    toggle.Parent = card

    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

    return card, image, info, toggle
end

local bestCard, bestPetImage, bestPetInfo, bestPetAutoToggle = createPetCard(
    cardsRow,
    "Best Pet",
    Color3.fromRGB(255, 215, 0),
    UDim2.new(0, 0, 0, 0)
)
local mythicalCard, mythicalImage, mythicalInfo, mythicalAutoToggle = createPetCard(
    cardsRow,
    "Best Mythical+",
    Color3.fromRGB(200, 100, 255),
    UDim2.new(0.5, 5, 0, 0)
)
mythicalInfo.Text = "No Mythical+ pet found"

local missingCard, missingImage, missingInfo, missingAutoToggle = createPetCard(
    cardsRow,
    "Best Missing",
    Color3.fromRGB(100, 200, 255),
    UDim2.new(0, 0, 0, 165)
)
missingInfo.Text = "No missing pets found"

local customCard, customImage, customInfo, customAutoToggle = createPetCard(
    cardsRow,
    "Best Custom",
    Color3.fromRGB(255, 165, 0),
    UDim2.new(0.5, 5, 0, 165)
)
customInfo.Text = "No custom filters set"

-- Load auto-catch button states from config
local autoCatchTabName = "Catching"
local autoCatchBestConfigEntry = "Auto Catch Best"
local autoCatchMythicalConfigEntry = "Auto Catch Mythical"
local autoCatchMissingConfigEntry = "Auto Catch Missing"
local autoCatchCustomConfigEntry = "Auto Catch Custom"

-- Safely load config values (Config may not exist on first run)
do
    local savedBest = getConfigSetting(autoCatchTabName, autoCatchBestConfigEntry)
    if savedBest ~= nil then
        autoCatchBest = savedBest
    end

    local savedMythical = getConfigSetting(autoCatchTabName, autoCatchMythicalConfigEntry)
    if savedMythical ~= nil then
        autoCatchMythical = savedMythical
    end

    local savedMissing = getConfigSetting(autoCatchTabName, autoCatchMissingConfigEntry)
    if savedMissing ~= nil then
        autoCatchMissing = savedMissing
    end
    
    local savedCustom = getConfigSetting(autoCatchTabName, autoCatchCustomConfigEntry)
    if savedCustom ~= nil then
        autoCatchCustom = savedCustom
    end
    
    local savedFilters = getConfigSetting(autoCatchTabName, "Custom Pet Filters")
    if type(savedFilters) == "table" then
        customPetFilters = savedFilters
        
        -- Update custom card info display
        local filterCount = 0
        for _ in pairs(customPetFilters) do filterCount = filterCount + 1 end
        if filterCount > 0 then
            customInfo.Text = filterCount .. " filter(s) active"
        end
    end
end

-- Initialize all buttons to OFF state first
bestPetAutoToggle.Text = "Auto Catch: OFF"
bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
mythicalAutoToggle.Text = "Auto Catch: OFF"
mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
missingAutoToggle.Text = "Auto Catch: OFF"
missingAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
customAutoToggle.Text = "Auto Catch: OFF"
customAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)

-- Update button visuals based on loaded config
if autoCatchBest then
    bestPetAutoToggle.Text = "Auto Catch: ON"
    bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
end
if autoCatchMythical then
    mythicalAutoToggle.Text = "Auto Catch: ON"
    mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
end
if autoCatchMissing then
    missingAutoToggle.Text = "Auto Catch: ON"
    missingAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
end
if autoCatchCustom then
    customAutoToggle.Text = "Auto Catch: ON"
    customAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
end

-- Helper function to set pet image
local movingGradientNames = {
    Epic = true,
    Legendary = true,
    Gold = true,
    Exclusive = true,
    Mythical = true,
    Rainbow = true,
    Neon = true,
    Shiny = true,
    Secret = true,
    Godly = true,
    Glass = true,
    Charged = true,
    Cosmic = true,
    Admin = true,
    Snowy = true,
    Fractured = true
}

local iconGradientStates = {}

local function trimText(text)
    if type(text) ~= "string" then
        return nil
    end
    return text:match("^%s*(.-)%s*$")
end

local function colorAtTime(keypoints, t)
    if t <= 0 then
        return keypoints[1].Value
    end
    if t >= 1 then
        return keypoints[#keypoints].Value
    end

    for i = 1, #keypoints - 1 do
        local left = keypoints[i]
        local right = keypoints[i + 1]
        if left.Time <= t and t < right.Time then
            local alpha = (t - left.Time) / (right.Time - left.Time)
            return Color3.new(
                (right.Value.R - left.Value.R) * alpha + left.Value.R,
                (right.Value.G - left.Value.G) * alpha + left.Value.G,
                (right.Value.B - left.Value.B) * alpha + left.Value.B
            )
        end
    end

    return keypoints[1].Value
end

local function resolvePrimaryMutation(mutation, mutationList)
    local parsed = {}

    local function pushMutation(value)
        local cleaned = trimText(value)
        if cleaned and cleaned ~= "" and cleaned ~= "None" and cleaned ~= "Normal" then
            table.insert(parsed, cleaned)
        end
    end

    pushMutation(mutation)

    if type(mutationList) == "string" and mutationList ~= "" then
        for part in mutationList:gmatch("[^,]+") do
            pushMutation(part)
        end
    end

    if #parsed == 0 then
        return nil
    end

    for _, name in ipairs(parsed) do
        if name == "Cosmic" then
            return "Cosmic"
        end
    end
    for _, name in ipairs(parsed) do
        if name == "Charged" then
            return "Charged"
        end
    end

    return parsed[1]
end

local function clearIconGradient(imageLabel)
    local state = iconGradientStates[imageLabel]
    if state and state.connection then
        state.connection:Disconnect()
    end

    local host = state and state.host
    if host then
        for _, child in ipairs(host:GetChildren()) do
            if child:IsA("UIGradient") then
                child:Destroy()
            end
        end
        host.Visible = false
    end

    iconGradientStates[imageLabel] = nil
end

local function ensureGradientHost(imageLabel)
    local state = iconGradientStates[imageLabel]
    local host = state and state.host

    if not (host and host.Parent) then
        host = Instance.new("Frame")
        host.Name = "PetIconGradientHost"
        host.BackgroundColor3 = Color3.fromRGB(75, 75, 75)
        host.BorderSizePixel = 0
        host.ClipsDescendants = true
        host.Visible = false
        host.Parent = imageLabel.Parent
    end

    host.Size = imageLabel.Size
    host.Position = imageLabel.Position
    host.AnchorPoint = imageLabel.AnchorPoint
    host.ZIndex = math.max(0, imageLabel.ZIndex - 1)

    local imageCorner = imageLabel:FindFirstChildOfClass("UICorner")
    local hostCorner = host:FindFirstChildOfClass("UICorner")
    if imageCorner then
        if not hostCorner then
            hostCorner = Instance.new("UICorner")
            hostCorner.Parent = host
        end
        hostCorner.CornerRadius = imageCorner.CornerRadius
    end

    if not state then
        state = {}
        iconGradientStates[imageLabel] = state
    end
    state.host = host

    return host, state
end

local function applyPetIconGradient(imageLabel, rarity, mutation, mutationList)
    if not imageLabel then
        return
    end

    local host, state = ensureGradientHost(imageLabel)

    local gradientName = resolvePrimaryMutation(mutation, mutationList)
    if not gradientName then
        gradientName = rarity
    end

    if not gradientName or not rarityGradientsFolder or not host then
        if state.connection then
            state.connection:Disconnect()
            state.connection = nil
        end
        if state.gradient and state.gradient.Parent then
            state.gradient:Destroy()
        end
        state.gradient = nil
        state.gradientSignature = nil
        host.Visible = false
        return
    end

    local gradientTemplate = rarityGradientsFolder:FindFirstChild(gradientName)
    if not gradientTemplate then
        if state.connection then
            state.connection:Disconnect()
            state.connection = nil
        end
        if state.gradient and state.gradient.Parent then
            state.gradient:Destroy()
        end
        state.gradient = nil
        state.gradientSignature = nil
        host.Visible = false
        return
    end

    if state.gradientSignature == gradientName and state.gradient and state.gradient.Parent == host then
        host.Visible = true
        return
    end

    if state.connection then
        state.connection:Disconnect()
        state.connection = nil
    end
    if state.gradient and state.gradient.Parent then
        state.gradient:Destroy()
    end

    local gradient = gradientTemplate:Clone()
    gradient.Name = "PetIconGradient"
    gradient.Rotation = -90
    gradient.Parent = host
    host.Visible = true

    local shouldMove = movingGradientNames[gradientName] == true
    local spinSpeed = gradient:GetAttribute("SpinSpeed")
    if type(spinSpeed) ~= "number" then
        spinSpeed = 0
    end

    if not shouldMove and spinSpeed == 0 then
        state.gradient = gradient
        state.gradientSignature = gradientName
        return
    end

    local originalKeypoints = nil
    local slideSpeed = gradient:GetAttribute("SlideSpeed")
    if type(slideSpeed) ~= "number" then
        slideSpeed = 0.5
    end

    if shouldMove then
        originalKeypoints = table.clone(gradient.Color.Keypoints)
    end

    local elapsed = 0
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        if not gradient or not gradient.Parent then
            if connection then
                connection:Disconnect()
            end
            return
        end

        if shouldMove then
            elapsed = (elapsed + dt * slideSpeed) % 1
            local shifted = {
                ColorSequenceKeypoint.new(0, colorAtTime(originalKeypoints, elapsed)),
                ColorSequenceKeypoint.new(1, colorAtTime(originalKeypoints, elapsed))
            }

            for _, keypoint in ipairs(originalKeypoints) do
                table.insert(shifted, ColorSequenceKeypoint.new((elapsed - keypoint.Time) % 1, keypoint.Value))
            end

            table.sort(shifted, function(a, b)
                return a.Time < b.Time
            end)

            gradient.Color = ColorSequence.new(shifted)
        end

        if spinSpeed ~= 0 then
            gradient.Rotation = (gradient.Rotation + dt * spinSpeed) % 360
        end
    end)

    state.connection = connection
    state.gradient = gradient
    state.gradientSignature = gradientName
end

local function setPetImage(imageLabel, petName, rarity, mutation, mutationList)
    local imageId = petsConfig and petsConfig[petName] and petsConfig[petName].Image
    local renderSignature = table.concat({
        tostring(petName),
        tostring(rarity),
        tostring(mutation),
        tostring(mutationList),
        tostring(imageId)
    }, "|")

    local state = iconGradientStates[imageLabel]
    if state and state.renderSignature == renderSignature then
        return
    end

    applyPetIconGradient(imageLabel, rarity, mutation, mutationList)

    if imageId then
        imageLabel.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
        task.spawn(function()
            pcall(function()
                imageLabel.Image = "rbxthumb://type=Asset&id=" .. imageId .. "&w=420&h=420"
            end)
        end)
    else
        imageLabel.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
    end

    state = iconGradientStates[imageLabel] or {}
    state.renderSignature = renderSignature
    iconGradientStates[imageLabel] = state
end

local function clearPetImageRender(imageLabel)
    if not imageLabel then
        return
    end

    imageLabel.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
    clearIconGradient(imageLabel)
end

-- Helper function to get pet info display
local function getPetInfo(pet, rpsValue)
    local name = pet:GetAttribute("Name") or "Unknown"
    local strength = pet:GetAttribute("Strength") or 0
    local rarity = pet:GetAttribute("Rarity") or "Unknown"
    local sizeName = pet:GetAttribute("SizeName") or "Unknown"
    local mutations = pet:GetAttribute("MutationList") or "None"

    return name ..
        "\n💲 RPS: " .. rpsValue ..
        "\n💪 STR: " .. strength ..
        "\n⭐ Rarity: " .. rarity ..
        "\n📏 Size: " .. sizeName ..
        "\n🧬 Mutations: " .. mutations
end

-- Utility function to check if a pet with specific mutations has been discovered
local function isPetDiscovered(petName, petMutations)
    -- If pet name doesn't exist in index at all, it's undiscovered
    if not petName or not playerPetIndex[petName] then
        return false
    end
    
    local indexedPet = playerPetIndex[petName]
    
    -- If no mutations (Normal), just check if pet exists
    if not petMutations or petMutations == "None" then
        return indexedPet["Normal"] == true or next(indexedPet) ~= nil
    end
    
    -- Split mutation list and check if ALL mutations exist in index
    local mutations = {}
    for mutation in petMutations:gmatch("[^,]+") do
        table.insert(mutations, mutation:match("^%s*(.-)%s*$")) -- Trim whitespace
    end
    
    -- Check if all mutations in this combo have been discovered
    for _, mutation in ipairs(mutations) do
        if not indexedPet[mutation] then
            return false  -- This mutation combo is NOT discovered
        end
    end
    
    return true  -- All mutations in this combo are discovered
end

-- Variables for tracking pets
local bestPet = nil
local bestMythical = nil
local bestMissing = nil
local bestCustom = nil
local previousBestRPS = -math.huge
local warningActive = false
-- ============================================================
-- RUNTIME STATE - These track runtime state and should not be modified
-- ============================================================

-- Auto-catch loop state
local autoCatchMasterLoop = false
local catchLock = false

-- Auto features loop state
local autoBreedLoop = false
local autoRemoveEggsLoop = false
local customBreedingPairs = {}  -- Store custom breeding pairs

-- Load custom breeding pairs from config
do
    local savedPairs = getConfigSetting("Breeding", "CustomPairs")

    if type(savedPairs) == "table" then
        customBreedingPairs = savedPairs
    end
end
local autoSellLegendaryEggsLoop = false
local autoSellMythicalEggsLoop = false
local autoBuyFoodSetup = false
local autoBuyMerchantSetup = false

-- Auto-cycle saves state
local autoCycleSavesLoop = false
local currentSaveSlot = 0  -- 0 = unknown, will be set when cycling starts
local saveCycleStartTime = 0  -- Track when current cycle started
local currentCycleInterval = 0  -- Track the interval for the current cycle
local saveCycleInterruptToken = 0  -- Increment to interrupt current auto-cycle wait
local lastManualSwitchTime = 0  -- Track when last manual switch happened to prevent immediate retry

local function getSaveSlotTime(slot)
    local slotTime = tonumber(saveSlot1Time) or 375
    if slot == 2 then
        slotTime = tonumber(saveSlot2Time) or 375
    elseif slot == 3 then
        slotTime = tonumber(saveSlot3Time) or 375
    elseif slot == 4 then
        slotTime = tonumber(saveSlot4Time) or 375
    end
    return math.max(0, slotTime)
end

local function getNextValidSlot(currentSlot)
    -- Find next slot with time > 0
    local startSlot = currentSlot
    for i = 1, 4 do
        local nextSlot = (currentSlot % 4) + 1
        local slotTime = getSaveSlotTime(nextSlot)
        if slotTime > 0 then
            return nextSlot
        end
        currentSlot = nextSlot
        -- If we've checked all slots and none are valid, return nil
        if currentSlot == startSlot then
            return nil
        end
    end
    return nil
end

local function switchToSlot(slot, isAutoSwitch)
    if slot < 1 or slot > 4 then
        notify("Invalid slot number", true)
        return false
    end
    
    -- Don't switch if we're already on this slot (only for manual switches)
    if not isAutoSwitch and currentSaveSlot == slot then
        print("[SaveSwitch] Already on slot " .. slot .. ", skipping switch")
        return true
    end

    print("[SaveSwitch] Called with slot=" .. slot .. ", isAutoSwitch=" .. tostring(isAutoSwitch))

    local getSaveInfo = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("getSaveInfo")
    local collectAllPetCash = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("collectAllPetCash")

    if autoCollectPetCashEnabled then
        pcall(function()
            collectAllPetCash:FireServer()
        end)
    end

    if not isAutoSwitch then
        saveCycleInterruptToken = saveCycleInterruptToken + 1
        lastManualSwitchTime = tick()
        print("[SaveSwitch] Manual switch detected, setting cooldown timer")
    end

    local slotTime = getSaveSlotTime(slot)
    local args = { slot, true }
    local isAutoSwitchCopy = isAutoSwitch
    
    task.spawn(function()
        local success, err = pcall(function()
            local result1, result2 = getSaveInfo:InvokeServer(unpack(args))
            print("[SaveSwitch] Initial call - isAutoSwitch=" .. tostring(isAutoSwitchCopy) .. ", Result1: " .. tostring(result1) .. ", Result2: " .. tostring(result2))
            
            -- Check if the second return value is nil (cooldown) or a number (success)
            if result2 ~= nil then
                -- SUCCESS - Update timing variables
                print("[SaveSwitch] Switch successful on first try")
                saveCycleStartTime = tick()
                currentCycleInterval = slotTime
                currentSaveSlot = slot
                notify(string.format("Switched to save slot %d", slot))
                
            elseif result2 == nil and isAutoSwitchCopy then
                -- AUTO switch failed, retry
                print("[SaveSwitch] Cooldown detected on AUTO switch, retrying...")
                notify("Save switch on cooldown, retrying...", true)
                
                for retryCount = 1, 3 do
                    task.wait(1)
                    local retryResult1, retryResult2 = getSaveInfo:InvokeServer(unpack(args))
                    print("[SaveSwitch] Retry " .. retryCount .. " - Result1: " .. tostring(retryResult1) .. ", Result2: " .. tostring(retryResult2))
                    
                    if retryResult2 ~= nil then
                        -- RETRY SUCCESS - Update timing variables
                        print("[SaveSwitch] Retry succeeded on attempt " .. retryCount)
                        saveCycleStartTime = tick()
                        currentCycleInterval = slotTime
                        currentSaveSlot = slot
                        notify("Save switch succeeded on retry #" .. retryCount)
                        return
                    end
                end
                
                print("[SaveSwitch] All retries failed")
                notify("Failed to switch saves after retries", true)
                
            elseif result2 == nil and not isAutoSwitchCopy then
                -- MANUAL switch failed, no retry
                notify("Save switch failed: on cooldown", true)
                print("[SaveSwitch] MANUAL switch failed - cooldown (NO RETRY)")
            end
        end)
        
        if not success then
            print("[SaveSwitch] ERROR in remote call: " .. tostring(err))
        end
    end)

    return true
end

local function scanPets()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Find player's pen
    local playerPen
    for _, pen in pairs(workspace.PlayerPens:GetChildren()) do
        if pen:GetAttribute("Owner") == player.Name then
            playerPen = pen
            break
        end
    end

    local placedPets = playerPen and playerPen:FindFirstChild("Pets") and playerPen.Pets:GetChildren() or {}

    local bestPlacedPet, worstPlacedPet
    local bestPlacedRPS, worstPlacedRPS = -math.huge, math.huge
    local totalPlacedRPS = 0

    for _, pet in pairs(placedPets) do
        local rps = pet:GetAttribute("RPS")
        if rps then
            totalPlacedRPS = totalPlacedRPS + rps
            if rps > bestPlacedRPS then
                bestPlacedRPS = rps
                bestPlacedPet = pet
            end
            if rps < worstPlacedRPS then
                worstPlacedRPS = rps
                worstPlacedPet = pet
            end
        end
    end

    -- Reset previous highlights
    for _, pet in pairs(placedPets) do
        local h = pet:FindFirstChildOfClass("Highlight")
        if h then h.Enabled = false end
    end

    -- Apply highlights to best/worst
    if bestPlacedPet then
        local h = bestPlacedPet:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
        h.Name = "Highlight"
        h.Adornee = bestPlacedPet
        h.FillColor = Color3.fromRGB(0,255,0)
        h.Enabled = true
        h.Parent = bestPlacedPet
    end
    if worstPlacedPet then
        local h = worstPlacedPet:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
        h.Name = "Highlight"
        h.Adornee = worstPlacedPet
        h.FillColor = Color3.fromRGB(255,0,0)
        h.Enabled = true
        h.Parent = worstPlacedPet
    end

    -- Get earned text
    local earnedText = "0"
    if playerPen and playerPen:FindFirstChild("ClaimAllButton") then
        local claimButton = playerPen.ClaimAllButton
        if claimButton:FindFirstChild("Base") and claimButton.Base:FindFirstChild("BillboardGui") then
            local gui = claimButton.Base.BillboardGui
            if gui:FindFirstChild("Earned") then
                earnedText = gui.Earned.Text
            end
        end
    end

    -- Scan world pets for best overall and best mythical+
    local bestOverall, bestOverallRPS = nil, -math.huge
    local newBestMythical, bestMythicalRPS = nil, -math.huge
    local newBestMissing, bestMissingRPS = nil, -math.huge
    local newBestCustom, bestCustomRPS = nil, -math.huge
    local rarityPriority = { Secret = 3, Exclusive = 2, Mythical = 1 }

    for _, folder in pairs(folders) do
        for _, pet in pairs(folder:GetChildren()) do
            local rps = pet:GetAttribute("RPS")
            local rarity = pet:GetAttribute("Rarity")
            local petName = pet:GetAttribute("Name")
            if rps then
                if rps > bestOverallRPS then
                    bestOverallRPS = rps
                    bestOverall = pet
                end
                
                -- Check for Mythical+ (Secret, Exclusive, Mythical)
                local priority = rarityPriority[rarity] or 0
                if priority > 0 then
                    local currentPriority = rarityPriority[newBestMythical and newBestMythical:GetAttribute("Rarity")] or 0
                    if priority > currentPriority or (priority == currentPriority and rps > bestMythicalRPS) then
                        bestMythicalRPS = rps
                        newBestMythical = pet
                    end
                end
                
                -- Check for best missing (not discovered with specific mutations)
                if petName then
                    local petMutations = pet:GetAttribute("MutationList") or "None"
                    if not isPetDiscovered(petName, petMutations) then
                        if rps > bestMissingRPS then
                            bestMissingRPS = rps
                            newBestMissing = pet
                        end
                    end
                    
                    -- Check for best custom filtered pet
                    if petName then
                        local mutations = pet:GetAttribute("MutationList") or "None"
                        local filterKey
                        
                        if mutations == "None" then
                            filterKey = petName .. "_Normal"
                        else
                            -- Try exact match first
                            local mutList = mutations:gsub(", ", ",")
                            filterKey = petName .. "_" .. mutList
                            
                            -- If no exact match, try each individual mutation
                            if not customPetFilters[filterKey] then
                                for mutation in mutations:gmatch("[^,]+") do
                                    local singleMut = mutation:match("^%s*(.-)%s*$") -- Trim whitespace
                                    local singleKey = petName .. "_" .. singleMut
                                    if customPetFilters[singleKey] then
                                        filterKey = singleKey
                                        break
                                    end
                                end
                            end
                        end
                        
                        if customPetFilters[filterKey] and rps > bestCustomRPS then
                            bestCustomRPS = rps
                            newBestCustom = pet
                        end
                    end
                end
            end
        end
    end

    -- Check for new best overall pet
    if bestOverallRPS > previousBestRPS and bestOverallRPS >= appliedThreshold then
        local petName = bestOverall:GetAttribute("Name") or "Unknown"
        local rarity = bestOverall:GetAttribute("Rarity") or "Common"
        warningLabel.Text = "NEW BEST OVERALL SPAWNED!\nRPS: " .. bestOverallRPS
        warningLabel.Visible = true
        warningActive = true
        notify(string.format("New Best Pet! %s (%s) - RPS: %d", petName, rarity, bestOverallRPS))
        task.delay(3, function()
            if warningActive then
                warningLabel.Visible = false
                warningActive = false
            end
        end)
    end
    previousBestRPS = bestOverallRPS

    if infoLabel then
        infoLabel.Text = "Player Stats" ..
            "\nPlaced Pets - Best RPS: " .. (bestPlacedRPS ~= -math.huge and bestPlacedRPS or "None") ..
            " | Worst RPS: " .. (worstPlacedRPS ~= math.huge and worstPlacedRPS or "None") ..
            " | Total: " .. totalPlacedRPS .. " | Earned: " .. earnedText
    end

    -- Update best pet display
    bestPet = bestOverall
    if bestPet then
        if bestPetInfo then
            bestPetInfo.Text = getPetInfo(bestPet, bestOverallRPS)
        end
        if bestPetImage then
            setPetImage(
                bestPetImage,
                bestPet:GetAttribute("Name"),
                bestPet:GetAttribute("Rarity"),
                bestPet:GetAttribute("Mutation"),
                bestPet:GetAttribute("MutationList")
            )
        end
    else
        if bestPetInfo then
            bestPetInfo.Text = "No pet found"
        end
        if bestPetImage then
            clearPetImageRender(bestPetImage)
        end
    end
    -- Update best mythical+ display
    bestMythical = newBestMythical
    if bestMythical then
        if mythicalInfo then
            mythicalInfo.Text = getPetInfo(bestMythical, bestMythicalRPS)
        end
        if mythicalImage then
            setPetImage(
                mythicalImage,
                bestMythical:GetAttribute("Name"),
                bestMythical:GetAttribute("Rarity"),
                bestMythical:GetAttribute("Mutation"),
                bestMythical:GetAttribute("MutationList")
            )
        end
    else
        if mythicalInfo then
            mythicalInfo.Text = "No Mythical+ pet found"
        end
        if mythicalImage then
            clearPetImageRender(mythicalImage)
        end
    end

    -- Update best missing display
    bestMissing = newBestMissing
    if bestMissing then
        if missingInfo then
            missingInfo.Text = getPetInfo(bestMissing, bestMissingRPS)
        end
        if missingImage then
            setPetImage(
                missingImage,
                bestMissing:GetAttribute("Name"),
                bestMissing:GetAttribute("Rarity"),
                bestMissing:GetAttribute("Mutation"),
                bestMissing:GetAttribute("MutationList")
            )
        end
    else
        if missingInfo then
            missingInfo.Text = "No missing pets found"
        end
        if missingImage then
            clearPetImageRender(missingImage)
        end
    end
    
    -- Update best custom display
    bestCustom = newBestCustom
    if bestCustom then
        if customInfo then
            customInfo.Text = getPetInfo(bestCustom, bestCustomRPS)
        end
        if customImage then
            setPetImage(
                customImage,
                bestCustom:GetAttribute("Name"),
                bestCustom:GetAttribute("Rarity"),
                bestCustom:GetAttribute("Mutation"),
                bestCustom:GetAttribute("MutationList")
            )
        end
    else
        local filterCount = 0
        for _ in pairs(customPetFilters) do filterCount = filterCount + 1 end
        
        if customInfo then
            if filterCount == 0 then
                customInfo.Text = "No custom filters set"
            else
                customInfo.Text = filterCount .. " filter(s) active\nNo matching pets found"
            end
        end
        if customImage then
            clearPetImageRender(customImage)
        end
    end
end

-- Load ExternalProgressModifier in background
task.spawn(function()
    print("✓ Starting ExternalProgressModifier...")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local CurrentMinigameInstance = nil
    
    -- Get the Lasso Minigame module
    local StarterPlayer = game:GetService("StarterPlayer")
    local lassoMinigameUI = StarterPlayer.StarterPlayerScripts.Controllers.UI.lassoUI.lassoMinigameUI
    local LassoMinigameModule = require(lassoMinigameUI)
    
    -- Hook into the module to capture the current minigame instance
    local OriginalStartMinigame = LassoMinigameModule.StartMinigame
    LassoMinigameModule.StartMinigame = function(self, difficulty, pet)
        local minigame = OriginalStartMinigame(self, difficulty, pet)
        CurrentMinigameInstance = minigame
        print("✓ Minigame instance captured!")
        
        -- Run for EVERY minigame
        print("⏳ Starting progress modification for this minigame...")
        SimulateProgressGain()
        
        return minigame
    end
    
    local OriginalEndMinigame = LassoMinigameModule.EndMinigame
    LassoMinigameModule.EndMinigame = function(self, wasCaught)
        OriginalEndMinigame(self, wasCaught)
        CurrentMinigameInstance = nil
        print("✗ Minigame instance released")
    end
    
    local isSimulationActive = false
    
    function SimulateProgressGain()
        if isSimulationActive then
            print("✗ Progress simulation already running")
            return false
        end
        
        if not CurrentMinigameInstance then
            print("✗ No active minigame instance found.")
            return false
        end
        
        isSimulationActive = true
        print("✓ Directly adding progress at natural rate...")
        
        local minigame = CurrentMinigameInstance
        local progressPerClick = minigame.progressPerClick
        print(string.format("Progress per click: %.2f%%", progressPerClick))
        
        local task_spawn = task.spawn
        task_spawn(function()
            while isSimulationActive and minigame.minigameActive do
                if minigame.progress < 100 then
                    local newProgress = (minigame.progress or 0) + progressPerClick
                    minigame.progress = math.clamp(newProgress, 0, 100)
                else
                    minigame.progress = 100
                end
                
                minigame:UpdateFillBar()
                minigame:UpdateCatchingEffects()
                
                task.wait(catchDelay) -- CPS LIMITER FOR CATCHING
            end
            
            isSimulationActive = false
            print("✓ Minigame ended and pet is gone")
        end)
        
        return true
    end
    
    print("✓ Progress Modifier Loaded - Will modify EVERY minigame!")
end)

-- AutoBreed button handler
local function startAutoBreed()
    if autoBreedLoop then
        return
    end

    autoBreedLoop = true
    task.spawn(function()
        while autoBreedEnabled do
            local playerPen = nil
            for _, pen in pairs(workspace.PlayerPens:GetChildren()) do
                if pen:GetAttribute("Owner") == player.Name then
                    playerPen = pen
                    break
                end
            end

            if playerPen then
                local availablePets = {}
                local currentTime = os.time()

                for _, pet in pairs(playerPen.Pets:GetChildren()) do
                    local petName = pet:GetAttribute("Name")
                    local cooldownEnd = pet:GetAttribute("CooldownEnd")

                    if not (cooldownEnd and cooldownEnd > currentTime) then
                        table.insert(availablePets, {
                            pet = pet,
                            name = petName
                        })
                    end
                end

                local penCenter = playerPen:GetBoundingBox().Position
                local breedRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("breedRequest")
                local usedPets = {}

                -- Build combined breeding pairs list
                local allPairs = {}
                
                -- Add cross-breeding pairs
                for _, pair in pairs(crossBreedingPairs) do
                    table.insert(allPairs, pair)
                end
                
                -- Add self-breeding pairs if enabled
                if selfBreedingEnabled then
                    for _, pair in pairs(selfBreedingPairs) do
                        table.insert(allPairs, pair)
                    end
                end
                
                -- Add custom breeding pairs if enabled
                if customBreedingEnabled and customBreedingPairs then
                    for _, pair in pairs(customBreedingPairs) do
                        table.insert(allPairs, pair)
                    end
                end

                -- Breed all configured pairs
                for _, pair in pairs(allPairs) do
                    local pet1Name = pair[1]
                    local pet2Name = pair[2]
                    
                    for i, petData1 in pairs(availablePets) do
                        if not usedPets[i] and petData1.name == pet1Name then
                            for j, petData2 in pairs(availablePets) do
                                if i ~= j and not usedPets[j] and petData2.name == pet2Name then
                                    local args = {
                                        petData1.pet,
                                        petData2.pet,
                                        penCenter,
                                        penCenter
                                    }
                                    pcall(function()
                                        breedRemote:InvokeServer(unpack(args))
                                    end)
                                    usedPets[i] = true
                                    usedPets[j] = true
                                    task.wait(0.5)
                                    break
                                end
                            end
                        end
                    end
                end
            end

            task.wait(2)
        end
        autoBreedLoop = false
    end)
end

local function startAutoRemoveEggs()
    if autoRemoveEggsLoop then
        return
    end

    autoRemoveEggsLoop = true
    task.spawn(function()
        while autoRemoveEggsEnabled do
            local playerPen = nil
            for _, pen in pairs(workspace.PlayerPens:GetChildren()) do
                if pen:GetAttribute("Owner") == player.Name then
                    playerPen = pen
                    break
                end
            end

            if playerPen then
                local eggs = playerPen:FindFirstChild("Eggs")
                if eggs then
                    local eggList = eggs:GetChildren()
                    if #eggList > 0 then
                        local pickupRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("pickupRequest")

                        for i, egg in pairs(eggList) do
                            if not autoRemoveEggsEnabled then
                                break
                            end
                            local args = {
                                "Egg",
                                egg.Name,
                                egg
                            }

                            pcall(function()
                                pickupRemote:InvokeServer(unpack(args))
                            end)

                            task.wait(0.3)
                        end
                    end
                end
            end

            task.wait(1)
        end
        autoRemoveEggsLoop = false
    end)
end

local function getToolbarController()
    local ok, controller = pcall(function()
        return Knit.GetController("toolbarUI")
    end)
    if ok and controller then
        return controller
    end

    local StarterPlayer = game:GetService("StarterPlayer")
    local module = StarterPlayer.StarterPlayerScripts.Controllers.UI.toolbarUI
    local okRequire, required = pcall(require, module)
    if okRequire then
        return required
    end

    return nil
end

local function refreshInventoryUI()
    local toolbarUI = getToolbarController()
    if toolbarUI and toolbarUI.initializeInventory and toolbarUI.initializeInventory.forceCleanup then
        toolbarUI.initializeInventory.forceCleanup()
    end
end

local function autoSellEggsOnce(rarity, enabledVar)
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local getEggInventory = remotes:WaitForChild("getEggInventory")
    local sellEgg = remotes:WaitForChild("sellEgg")

    local maxAttempts = 5
    local totalSold = 0

    local function trySellEgg(guid)
        for attempt = 1, maxAttempts do
            local ok = sellEgg:InvokeServer(guid, false)
            if ok then
                return true
            end
            task.wait(0.15 * attempt)
        end
        return false
    end

    local didSellInPass = true
    while enabledVar and didSellInPass do
        local eggs = getEggInventory:InvokeServer()
        if type(eggs) ~= "table" then
            return
        end

        didSellInPass = false
        for guid, egg in pairs(eggs) do
            if not enabledVar then
                break
            end
            if egg and egg.rarity == rarity then
                local ok = trySellEgg(guid)
                if ok then
                    didSellInPass = true
                    totalSold = totalSold + 1
                end
                task.wait(0.2)
            end
        end

        if didSellInPass then
            task.wait(0.2)
            refreshInventoryUI()
        end
    end
    
    if totalSold > 0 then
        notify(string.format("Sold %d %s egg%s", totalSold, rarity, totalSold > 1 and "s" or ""))
    end
end

local function autoSellLegendaryEggsOnce()
    autoSellEggsOnce("Legendary", autoSellLegendaryEggsEnabled)
end

local function startAutoSellMythicalEggs()
    if autoSellMythicalEggsLoop then
        return
    end

    autoSellMythicalEggsLoop = true
    task.spawn(function()
        while autoSellMythicalEggsEnabled do
            autoSellEggsOnce("Mythical", autoSellMythicalEggsEnabled)
            task.wait(5)
        end
        autoSellMythicalEggsLoop = false
    end)
end

local function startAutoCycleSaves()
    if autoCycleSavesLoop then
        return
    end

    autoCycleSavesLoop = true
    task.spawn(function()
        while autoCycleSavesEnabled do
            local slot = currentSaveSlot
            if slot < 1 or slot > 4 then
                slot = 1
            end

            -- Check if we're still in cooldown from a manual switch
            if tick() - lastManualSwitchTime < 3 then
                print("[AutoCycle] Manual switch cooldown active, waiting...")
                task.wait(1)
            -- Check if there's an existing timer running
            elseif saveCycleStartTime > 0 and tick() < (saveCycleStartTime + currentCycleInterval) then
                -- Timer is still running, just wait it out
                local tokenAtCycleStart = saveCycleInterruptToken
                local cycleEnd = saveCycleStartTime + currentCycleInterval
                local remainingTime = cycleEnd - tick()
                
                print("[AutoCycle] Timer already running for slot " .. slot .. ", waiting " .. math.floor(remainingTime) .. " seconds")

                while autoCycleSavesEnabled and tick() < cycleEnd do
                    if saveCycleInterruptToken ~= tokenAtCycleStart then
                        print("[AutoCycle] Timer interrupted (token changed)")
                        break
                    end
                    task.wait(0.2)
                end

                if not autoCycleSavesEnabled then
                    break
                end

                -- Only move to next slot if timer wasn't interrupted
                if saveCycleInterruptToken == tokenAtCycleStart then
                    local nextSlot = getNextValidSlot(slot)
                    if nextSlot then
                        currentSaveSlot = nextSlot
                        print("[AutoCycle] Timer complete, moving to next slot: " .. currentSaveSlot)
                    else
                        print("[AutoCycle] No valid slots configured (all set to 0), disabling")
                        autoCycleSavesEnabled = false
                        notify("Auto cycle disabled: all slots set to 0", true)
                        break
                    end
                end
            else
                -- No timer running, start a new switch
                -- Move to next valid slot first
                local nextSlot = getNextValidSlot(slot)
                if not nextSlot then
                    print("[AutoCycle] No valid slots configured (all set to 0), disabling")
                    autoCycleSavesEnabled = false
                    notify("Auto cycle disabled: all slots set to 0", true)
                    break
                end
                
                print("[AutoCycle] Starting new auto-switch to slot " .. nextSlot)
                switchToSlot(nextSlot, true)
                
                -- Wait 10 seconds to give time for retries to complete and cooldown to expire
                print("[AutoCycle] Waiting 10 seconds for switch to process...")
                task.wait(10)
            end
        end
        autoCycleSavesLoop = false
    end)
end

local function startAutoSellLegendaryEggs()
    if autoSellLegendaryEggsLoop then
        return
    end

    autoSellLegendaryEggsLoop = true
    task.spawn(function()
        while autoSellLegendaryEggsEnabled do
            autoSellLegendaryEggsOnce()
            task.wait(5)
        end
        autoSellLegendaryEggsLoop = false
    end)
end

RunService.Heartbeat:Connect(function(dt)
    scanPets()
end)

local function setupAutoBuyFood()
    if autoBuyFoodSetup then
        return
    end

    autoBuyFoodSetup = true
    local foodService = Knit.GetService("FoodService")
    local currencyController = Knit.GetController("CurrencyController")
    local foodShopController = Knit.GetController("FoodShopController")

    local function buyFromStock(stockTable)
        if not autoBuyFoodEnabled or type(stockTable) ~= "table" then
            return
        end

        local cash = currencyController and currencyController.Cash or 0
        for itemName, stock in pairs(stockTable) do
            if stock > 0 then
                local config = FoodConfig[itemName]
                local price = config and config.Price or 0
                if price > 0 then
                    local maxAffordable = math.floor(cash / price)
                    local qty = math.min(stock, maxAffordable)
                    if qty > 0 then
                        foodService.BuyFood:Fire(itemName, qty)
                    end
                end
            end
        end
    end

    foodService.ReplicateStock:Connect(function(stockTable)
        buyFromStock(stockTable)
    end)

    task.spawn(function()
        pcall(function()
            if foodService.GetStock then
                local stock = foodService:GetStock()
                buyFromStock(stock)
            elseif foodService.RequestStock then
                foodService:RequestStock()
            end
        end)

        task.wait(1)
        if foodShopController and foodShopController.Stock then
            buyFromStock(foodShopController.Stock)
        end
    end)
end

local function setupAutoBuyMerchant()
    if autoBuyMerchantSetup then
        return
    end

    autoBuyMerchantSetup = true
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local requestMerchant = remotes:WaitForChild("RequestMerchant")
    local buyMerchant = remotes:WaitForChild("BuyMerchant")
    
    local purchasedSlots = {}  -- Track which slots we've bought from
    local isProcessing = false
    local lastRestockExpires = nil
    local lastProcessTime = 0

    requestMerchant.OnClientEvent:Connect(function(payload)
        if not autoBuyMerchantEnabled or not payload or not payload.Items then
            return
        end

        if payload.Expires and payload.Expires ~= lastRestockExpires then
            purchasedSlots = {}
            lastRestockExpires = payload.Expires
        end

        local now = tick()
        if isProcessing or (now - lastProcessTime) < 0.5 then
            return
        end
        lastProcessTime = now
        isProcessing = true

        task.spawn(function()
            for slotIndex, item in ipairs(payload.Items) do
                if not autoBuyMerchantEnabled then
                    break
                end
                -- Buy the full amount from each slot
                if item.Amount and item.Amount > 0 and not purchasedSlots[slotIndex] then
                    print(string.format("Buying from slot %d: %s (Amount: %d)", slotIndex, item.name, item.Amount))
                    purchasedSlots[slotIndex] = true
                    for i = 1, item.Amount do
                        if not autoBuyMerchantEnabled then
                            break
                        end
                        buyMerchant:FireServer(slotIndex, item.name)
                        task.wait(merchantPurchaseDelay)
                    end
                end
            end
            isProcessing = false
        end)
    end)

    requestMerchant:FireServer()
end

local function shouldCatchPet(pet)
    if not pet then return false end
    
    local petRPS = pet:GetAttribute("RPS") or 0
    local petRarity = pet:GetAttribute("Rarity") or "Common"
    
    -- Check if we should ignore minimum RPS for this rarity
    if ignoreMinRPSForSecret and petRarity == "Secret" then
        return true
    end
    if ignoreMinRPSForExclusive and petRarity == "Exclusive" then
        return true
    end
    
    -- Check minimum RPS requirement
    if petRPS >= minCatchRPS then
        return true
    end
    
    return false
end

local function shouldCatchMissingPet(pet)
    if not pet then return false end
    
    local petRPS = pet:GetAttribute("RPS") or 0
    
    -- If ignoring min RPS for missing, always catch
    if ignoreMinRPSForMissing then
        return true
    end
    
    -- Otherwise check minimum RPS requirement
    if petRPS >= minCatchRPS then
        return true
    end
    
    return false
end

local function catchPet(pet)
    if not pet or catchLock then
        return
    end

    catchLock = true
    task.spawn(function()
        local character = player.Character
        if not character then
            catchLock = false
            return
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            catchLock = false
            return
        end

        hrp.CFrame = pet:GetPivot() + Vector3.new(0,5,0)
        task.wait(0.3)

        local petPos = pet:GetPivot().Position
        local playerPos = hrp.Position
        local direction = (petPos - playerPos).Unit
        local throwArgs = { 0.9, direction }
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowLasso"):FireServer(unpack(throwArgs))
        task.wait(0.5)

        local petCFrame = pet:GetPivot()
        local minigameArgs = { pet, petCFrame }
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("minigameRequest"):InvokeServer(unpack(minigameArgs))
        task.wait(0.3)

        local StarterPlayer = game:GetService("StarterPlayer")
        local lassoMinigameHandler = require(StarterPlayer.StarterPlayerScripts.Controllers.Visuals.lassoController.lassoMinigameHandler)
        lassoMinigameHandler.Start(pet)

        catchLock = false
    end)
end

local function startAutoCatchMaster()
    if autoCatchMasterLoop then
        return
    end

    autoCatchMasterLoop = true
    task.spawn(function()
        while autoCatchBest or autoCatchMythical or autoCatchMissing or autoCatchCustom do
            -- Priority: Custom > Mythical+ > Missing > Best Overall
            if autoCatchCustom and bestCustom and (ignoreMinRPSForBestCustom or shouldCatchPet(bestCustom)) then
                catchPet(bestCustom)
                task.wait(1)
            elseif autoCatchMythical and bestMythical and shouldCatchPet(bestMythical) then
                catchPet(bestMythical)
                task.wait(1)
            elseif autoCatchMissing and bestMissing and shouldCatchMissingPet(bestMissing) then
                catchPet(bestMissing)
                task.wait(1)
            elseif autoCatchBest and bestPet and shouldCatchPet(bestPet) then
                catchPet(bestPet)
                task.wait(1)
            else
                task.wait(0.2)
            end
        end
        autoCatchMasterLoop = false
    end)
end

bestPetAutoToggle.MouseButton1Click:Connect(function()
    autoCatchBest = not autoCatchBest
    setConfigSetting(autoCatchTabName, autoCatchBestConfigEntry, autoCatchBest)
    if autoCatchBest then
        bestPetAutoToggle.Text = "Auto Catch: ON"
        bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
        if not autoCatchMasterLoop then
            startAutoCatchMaster()
        end
    else
        bestPetAutoToggle.Text = "Auto Catch: OFF"
        bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

mythicalAutoToggle.MouseButton1Click:Connect(function()
    autoCatchMythical = not autoCatchMythical
    setConfigSetting(autoCatchTabName, autoCatchMythicalConfigEntry, autoCatchMythical)
    if autoCatchMythical then
        mythicalAutoToggle.Text = "Auto Catch: ON"
        mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
        if not autoCatchMasterLoop then
            startAutoCatchMaster()
        end
    else
        mythicalAutoToggle.Text = "Auto Catch: OFF"
        mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

missingAutoToggle.MouseButton1Click:Connect(function()
    autoCatchMissing = not autoCatchMissing
    setConfigSetting(autoCatchTabName, autoCatchMissingConfigEntry, autoCatchMissing)
    if autoCatchMissing then
        missingAutoToggle.Text = "Auto Catch: ON"
        missingAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
        if not autoCatchMasterLoop then
            startAutoCatchMaster()
        end
    else
        missingAutoToggle.Text = "Auto Catch: OFF"
        missingAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

bestCard.MouseButton1Click:Connect(function()
    if bestPet then
        catchPet(bestPet)
    end
end)

mythicalCard.MouseButton1Click:Connect(function()
    if bestMythical then
        catchPet(bestMythical)
    end
end)

missingCard.MouseButton1Click:Connect(function()
    if bestMissing then
        catchPet(bestMissing)
    end
end)

customAutoToggle.MouseButton1Click:Connect(function()
    autoCatchCustom = not autoCatchCustom
    setConfigSetting(autoCatchTabName, autoCatchCustomConfigEntry, autoCatchCustom)
    if autoCatchCustom then
        customAutoToggle.Text = "Auto Catch: ON"
        customAutoToggle.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
        if not autoCatchMasterLoop then
            startAutoCatchMaster()
        end
    else
        customAutoToggle.Text = "Auto Catch: OFF"
        customAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

customCard.MouseButton1Click:Connect(function()
    if bestCustom then
        catchPet(bestCustom)
    end
end)

-- CREATE CATCHING SETTINGS UI

-- Create custom pet selector menu
local customSelectorMenu = Instance.new("Frame")
customSelectorMenu.Name = "CustomPetSelector"
customSelectorMenu.Size = UDim2.new(0, 700, 0, 550)
customSelectorMenu.Position = UDim2.new(0.5, -350, 0.5, -275)
customSelectorMenu.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
customSelectorMenu.BorderSizePixel = 0
customSelectorMenu.Visible = false
customSelectorMenu.ZIndex = 100
customSelectorMenu.Parent = uiRoot

Instance.new("UICorner", customSelectorMenu).CornerRadius = UDim.new(0, 12)

-- Add drag functionality with UIDragDetector
do
    local ok, dragDetector = pcall(function()
        return Instance.new("UIDragDetector")
    end)

    if ok and dragDetector then
        dragDetector.Parent = customSelectorMenu
        pcall(function()
            dragDetector.DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane
        end)
    end
end

-- Title
local selectorTitle = Instance.new("TextLabel", customSelectorMenu)
selectorTitle.Size = UDim2.new(1, -20, 0, 30)
selectorTitle.Position = UDim2.new(0, 10, 0, 5)
selectorTitle.BackgroundTransparency = 1
selectorTitle.Text = "Select Custom Pets/Mutations"
selectorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
selectorTitle.TextSize = 16
selectorTitle.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
selectorTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Search box
local searchBox = Instance.new("TextBox", customSelectorMenu)
searchBox.Size = UDim2.new(1, -20, 0, 35)
searchBox.Position = UDim2.new(0, 10, 0, 40)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.PlaceholderText = "Search pets or mutations..."
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBox.TextSize = 14
searchBox.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
searchBox.ClearTextOnFocus = false
searchBox.Text = ""

Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

-- Scroll frame for pet grid
local scrollFrame = Instance.new("ScrollingFrame", customSelectorMenu)
scrollFrame.Size = UDim2.new(1, -20, 1, -138)
scrollFrame.Position = UDim2.new(0, 10, 0, 85)
scrollFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8

Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 8)

local gridLayout = Instance.new("UIGridLayout", scrollFrame)
gridLayout.CellSize = UDim2.new(0, 100, 0, 120)
gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

local gridPadding = Instance.new("UIPadding", scrollFrame)
gridPadding.PaddingTop = UDim.new(0, 5)
gridPadding.PaddingLeft = UDim.new(0, 5)

-- Bottom buttons container
local buttonContainer = Instance.new("Frame", customSelectorMenu)
buttonContainer.Size = UDim2.new(1, -20, 0, 35)
buttonContainer.Position = UDim2.new(0, 10, 1, -45)
buttonContainer.BackgroundTransparency = 1

-- Clear All button
local clearAllButton = Instance.new("TextButton", buttonContainer)
clearAllButton.Size = UDim2.new(0, 140, 1, 0)
clearAllButton.Position = UDim2.new(0, 0, 0, 0)
clearAllButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
clearAllButton.Text = "Clear All"
clearAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
clearAllButton.TextSize = 15
clearAllButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

Instance.new("UICorner", clearAllButton).CornerRadius = UDim.new(0, 6)

-- Apply button
local applyButton = Instance.new("TextButton", buttonContainer)
applyButton.Size = UDim2.new(0, 140, 1, 0)
applyButton.Position = UDim2.new(1, -140, 0, 0)
applyButton.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
applyButton.Text = "Apply & Close"
applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
applyButton.TextSize = 15
applyButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

Instance.new("UICorner", applyButton).CornerRadius = UDim.new(0, 6)

-- Temporary selection state (not saved until Apply is clicked)
local tempCustomFilters = {}
local petEntries = {}
local pendingPetEntries = {}
local petGridBuildConn = nil
local petGridBuilt = false
local searchTermLower = ""

-- All possible mutation variants
local mutationVariants = {
    "Normal",
    "Albino",
    "Gold",
    "Rainbow",
    "Glass",
    "Neon",
    "Shiny"
}

-- Function to generate all mutation combinations for a pet
local function getMutationCombinations(petName)
    local combinations = {}
    
    -- Add all single mutations
    for _, mutation in ipairs(mutationVariants) do
        local key = petName .. "_" .. mutation
        table.insert(combinations, {
            key = key,
            display = mutation,
            petName = petName,
            mutations = mutation
        })
    end
    
    return combinations
end

local function runOnRenderStep(callback)
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if conn then
            conn:Disconnect()
            conn = nil
        end
        pcall(callback)
    end)
end

local function updateCanvasSize()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10)
end

local function setEntrySelected(entry, isSelected)
    if isSelected then
        entry.selectedFrame.BackgroundTransparency = 0
        entry.button.BackgroundColor3 = Color3.fromRGB(0, 90, 160)
    else
        entry.selectedFrame.BackgroundTransparency = 1
        entry.button.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    end
end

local function applySearchFilter(text)
    searchTermLower = text and text:lower() or ""

    for _, entry in ipairs(petEntries) do
        local matches = searchTermLower == ""
            or entry.petNameLower:find(searchTermLower, 1, true)
            or entry.mutationLower:find(searchTermLower, 1, true)
        entry.button.Visible = matches
    end

    runOnRenderStep(updateCanvasSize)
end

local function createPetEntry(entryData, layoutOrder)
    local button = Instance.new("TextButton", scrollFrame)
    button.Name = entryData.combo.key
    button.Size = UDim2.new(0, 100, 0, 120)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    button.Text = ""
    button.AutoButtonColor = false
    
    -- Set LayoutOrder for custom sorting
    button.LayoutOrder = layoutOrder or 0

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    local image = Instance.new("ImageLabel", button)
    image.Size = UDim2.new(0, 70, 0, 70)
    image.Position = UDim2.new(0.5, -35, 0, 5)
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
    Instance.new("UICorner", image).CornerRadius = UDim.new(0, 6)
    local petData = petsConfig and petsConfig[entryData.petName]
    local petRarity = petData and petData.Rarity or "Common"
    setPetImage(image, entryData.petName, petRarity, entryData.combo.mutations, entryData.combo.mutations)

    local nameLabel = Instance.new("TextLabel", button)
    nameLabel.Size = UDim2.new(1, -8, 0, 16)
    nameLabel.Position = UDim2.new(0, 4, 0, 78)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = entryData.petName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 10
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextScaled = true

    local mutationLabel = Instance.new("TextLabel", button)
    mutationLabel.Size = UDim2.new(1, -8, 0, 22)
    mutationLabel.Position = UDim2.new(0, 4, 0, 94)
    mutationLabel.BackgroundTransparency = 1
    mutationLabel.Text = entryData.combo.display
    mutationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    mutationLabel.TextSize = 11
    mutationLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
    mutationLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local selectedFrame = Instance.new("Frame", button)
    selectedFrame.Name = "SelectedFrame"
    selectedFrame.Size = UDim2.new(1, 0, 0, 45)
    selectedFrame.Position = UDim2.new(0, 0, 0, 75)
    selectedFrame.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
    selectedFrame.BackgroundTransparency = 1
    selectedFrame.BorderSizePixel = 0
    selectedFrame.ZIndex = button.ZIndex - 1
    Instance.new("UICorner", selectedFrame).CornerRadius = UDim.new(0, 6)

    local entry = {
        button = button,
        selectedFrame = selectedFrame,
        key = entryData.combo.key,
        petNameLower = entryData.petName:lower(),
        mutationLower = entryData.combo.mutations:lower()
    }

    setEntrySelected(entry, tempCustomFilters[entry.key] == true)

    button.MouseButton1Click:Connect(function()
        if tempCustomFilters[entry.key] then
            tempCustomFilters[entry.key] = nil
            setEntrySelected(entry, false)
        else
            tempCustomFilters[entry.key] = true
            setEntrySelected(entry, true)
        end
    end)

    table.insert(petEntries, entry)

    local matches = searchTermLower == ""
        or entry.petNameLower:find(searchTermLower, 1, true)
        or entry.mutationLower:find(searchTermLower, 1, true)
    button.Visible = matches
end

local function buildPetGridIncremental()
    if petGridBuilt then
        applySearchFilter(searchBox.Text)
        return
    end

    if petGridBuildConn then
        petGridBuildConn:Disconnect()
        petGridBuildConn = nil
    end

    pendingPetEntries = {}
    petEntries = {}

    for petName, _ in pairs(petsConfig) do
        local combinations = getMutationCombinations(petName)
        for _, combo in ipairs(combinations) do
            table.insert(pendingPetEntries, {
                petName = petName,
                combo = combo
            })
        end
    end

    table.sort(pendingPetEntries, function(a, b)
        -- Sort primarily by pet name
        if a.petName ~= b.petName then
            return a.petName < b.petName
        end
        -- Within same pet, sort by mutation order in mutationVariants
        local mutationIndexA = 999
        local mutationIndexB = 999
        for i, mutation in ipairs(mutationVariants) do
            if mutation == a.combo.mutations then mutationIndexA = i end
            if mutation == b.combo.mutations then mutationIndexB = i end
        end
        return mutationIndexA < mutationIndexB
    end)

    local nextIndex = 1
    local total = #pendingPetEntries
    local batchSize = 24
    local layoutOrderCounter = 0

    petGridBuildConn = RunService.RenderStepped:Connect(function()
        local count = 0
        while nextIndex <= total and count < batchSize do
            createPetEntry(pendingPetEntries[nextIndex], layoutOrderCounter)
            layoutOrderCounter = layoutOrderCounter + 1
            nextIndex = nextIndex + 1
            count = count + 1
        end

        updateCanvasSize()

        if nextIndex > total then
            petGridBuilt = true
            pendingPetEntries = {}
            if petGridBuildConn then
                petGridBuildConn:Disconnect()
                petGridBuildConn = nil
            end
        end
    end)
end

local function refreshSelectionVisuals()
    for _, entry in ipairs(petEntries) do
        setEntrySelected(entry, tempCustomFilters[entry.key] == true)
    end
end

-- Search box handler
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    applySearchFilter(searchBox.Text)
end)

-- Apply button handler
applyButton.MouseButton1Click:Connect(function()
    customPetFilters = {}
    for key, _ in pairs(tempCustomFilters) do
        customPetFilters[key] = true
    end
    
    setConfigSetting(autoCatchTabName, "Custom Pet Filters", customPetFilters)
    
    local count = 0
    for _ in pairs(customPetFilters) do count = count + 1 end
    
    notify("Applied " .. count .. " custom pet filters")

    task.defer(function()
        customSelectorMenu.Visible = false
        
        -- Update custom card info
        if count == 0 then
            customInfo.Text = "No custom filters set"
        else
            customInfo.Text = count .. " filter(s) active"
        end
    end)
end)

-- Clear All button handler
clearAllButton.MouseButton1Click:Connect(function()
    tempCustomFilters = {}
    customPetFilters = {}
    setConfigSetting(autoCatchTabName, "Custom Pet Filters", customPetFilters)
    notify("Cleared all selections")

    runOnRenderStep(function()
        refreshSelectionVisuals()
        customInfo.Text = "No custom filters set"
    end)
end)

-- Button to open custom selector
CreateButton("Catching", "Configure Custom Pets", function()
    -- Initialize temp filters from saved filters
    tempCustomFilters = {}
    for key, _ in pairs(customPetFilters) do
        tempCustomFilters[key] = true
    end
    
    runOnRenderStep(function()
        searchBox.Text = ""
        buildPetGridIncremental()
        applySearchFilter("")
        refreshSelectionVisuals()
        customSelectorMenu.Visible = true
    end)
end)

local minRPSLabel = CreateValueLabel("Catching", minCatchRPS == 0 and "Catch Minimum RPS: Disabled" or ("Catch Minimum RPS: " .. minCatchRPS))

local minCatchRPSInput = CreateInput("Catching", "Minimum RPS", tostring(minCatchRPS), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value then
        minCatchRPS = value
        if minCatchRPS == 0 then
            minRPSLabel.Text = "Catch Minimum RPS: Disabled"
        else
            minRPSLabel.Text = "Catch Minimum RPS: " .. minCatchRPS
        end
        notify("Minimum Catch RPS set to " .. (minCatchRPS == 0 and "disabled" or minCatchRPS))
    else
        notify("Invalid minimum RPS value", true)
    end
end)

CreateToggle("Catching", "Ignore Min RPS for Secret", function(state)
    ignoreMinRPSForSecret = state.Value
    if ignoreMinRPSForSecret then
        notify("Will catch Secret pets regardless of min RPS")
    else
        notify("Secret pets must meet minimum RPS")
    end
end, ignoreMinRPSForSecret)

CreateToggle("Catching", "Ignore Min RPS for Exclusive", function(state)
    ignoreMinRPSForExclusive = state.Value
    if ignoreMinRPSForExclusive then
        notify("Will catch Exclusive pets regardless of min RPS")
    else
        notify("Exclusive pets must meet minimum RPS")
    end
end, ignoreMinRPSForExclusive)

CreateToggle("Catching", "Ignore Min RPS for Missing", function(state)
    ignoreMinRPSForMissing = state.Value
    if ignoreMinRPSForMissing then
        notify("Will catch Missing pets regardless of min RPS")
    else
        notify("Missing pets must meet minimum RPS")
    end
end, ignoreMinRPSForMissing)

CreateToggle("Catching", "Ignore Min RPS for Best Custom", function(state)
    ignoreMinRPSForBestCustom = state.Value
    if ignoreMinRPSForBestCustom then
        notify("Will catch Best Custom pets regardless of min RPS")
    else
        notify("Best Custom pets must meet minimum RPS")
    end
end, ignoreMinRPSForBestCustom)

-- CREATE BREEDING TAB UI
CreateToggle("Breeding", "Auto Breed", function(state)
    autoBreedEnabled = state.Value
    if autoBreedEnabled then
        notify("Auto Breed enabled")
        startAutoBreed()
    else
        notify("Auto Breed disabled")
    end
end, autoBreedEnabled)

CreateToggle("Breeding", "Self Breeding Pairs", function(state)
    selfBreedingEnabled = state.Value
    if selfBreedingEnabled then
        notify("Self breeding enabled")
    else
        notify("Self breeding disabled")
    end
end, selfBreedingEnabled)

CreateToggle("Breeding", "Custom Breeding Pairs", function(state)
    customBreedingEnabled = state.Value
    if customBreedingEnabled then
        notify("Custom breeding enabled")
    else
        notify("Custom breeding disabled")
    end
end, customBreedingEnabled)

CreateToggle("Breeding", "Auto Remove Eggs", function(state)
    autoRemoveEggsEnabled = state.Value
    if autoRemoveEggsEnabled then
        notify("Auto Remove Eggs enabled")
        startAutoRemoveEggs()
    else
        notify("Auto Remove Eggs disabled")
    end
end, autoRemoveEggsEnabled)

CreateLabel("Breeding", "Custom Pairs")

-- Storage for custom pair button references (actual button instances)
local customPairButtons = {}

-- Function to save custom pairs to config
local function saveCustomPairs()
    setConfigSetting("Breeding", "CustomPairs", customBreedingPairs)
end

-- Function to rebuild all custom pair buttons
local function rebuildCustomPairButtons()
    -- Destroy all existing pair buttons
    for _, button in ipairs(customPairButtons) do
        if button and button.Parent then
            button:Destroy()
        end
    end
    customPairButtons = {}
    
    -- Recreate buttons for each pair
    for i, pair in ipairs(customBreedingPairs) do
        local pet1, pet2 = pair[1], pair[2]
        local buttonText = pet1 .. " ↔ " .. pet2
        
        -- Store button reference in a table that persists
        local buttonRef = {}
        
        -- Create button
        buttonRef.instance = CreateButton("Breeding", buttonText, function()
            -- Find and remove this specific pair by matching pet names
            for j = #customBreedingPairs, 1, -1 do
                local p = customBreedingPairs[j]
                if p[1] == pet1 and p[2] == pet2 then
                    table.remove(customBreedingPairs, j)
                    notify("Removed breeding pair: " .. pet1 .. " ↔ " .. pet2)
                    saveCustomPairs()
                    
                    -- Destroy the button using the reference
                    if buttonRef.instance then
                        buttonRef.instance.Parent = nil
                        buttonRef.instance:Destroy()
                    end
                    
                    -- Remove from tracking array
                    for k = #customPairButtons, 1, -1 do
                        if customPairButtons[k] == buttonRef.instance then
                            table.remove(customPairButtons, k)
                            break
                        end
                    end
                    
                    return
                end
            end
        end)
        
        -- Store the returned button instance
        if buttonRef.instance then
            table.insert(customPairButtons, buttonRef.instance)
        end
    end
end

CreateInput("Breeding", "Add Custom Pair", "Pet1, Pet2", "Add Pair", function(textBox)
    local text = textBox.Text
    local parts = {}
    for part in text:gmatch("[^,]+") do
        table.insert(parts, part:match("^%s*(.-)%s*$"))  -- Trim whitespace
    end
    
    if #parts == 2 and parts[1] ~= "" and parts[2] ~= "" then
        local pet1, pet2 = parts[1], parts[2]

        for _, existingPair in ipairs(customBreedingPairs) do
            if existingPair[1] == pet1 and existingPair[2] == pet2 then
                notify("Pair already exists: " .. pet1 .. " ↔ " .. pet2)
                return
            end
        end

        table.insert(customBreedingPairs, {pet1, pet2})
        notify("Added breeding pair: " .. pet1 .. " ↔ " .. pet2)
        textBox.Text = "Pet1, Pet2"  -- Reset input
        -- Save custom pairs to config and rebuild buttons
        saveCustomPairs()
        rebuildCustomPairButtons()
    else
        notify("Invalid format. Use: Pet1, Pet2", true)
    end
end)

-- Initialize custom pair buttons from loaded config
rebuildCustomPairButtons()

-- CREATE AUTO BUY TAB UI
CreateToggle("Auto Buy", "Food", function(state)
    autoBuyFoodEnabled = state.Value
    if autoBuyFoodEnabled then
        notify("Food auto-buy enabled")
    else
        notify("Food auto-buy disabled")
    end
    setupAutoBuyFood()
end, autoBuyFoodEnabled)

CreateToggle("Auto Buy", "Merchant", function(state)
    autoBuyMerchantEnabled = state.Value
    if autoBuyMerchantEnabled then
        notify("Merchant auto-buy enabled")
    else
        notify("Merchant auto-buy disabled")
    end
    setupAutoBuyMerchant()
end, autoBuyMerchantEnabled)

CreateToggle("Auto Sell", "Legendary Eggs", function(state)
    autoSellLegendaryEggsEnabled = state.Value
    if autoSellLegendaryEggsEnabled then
        notify("Legendary Eggs enabled")
        startAutoSellLegendaryEggs()
    else
        notify("Legendary Eggs disabled")
    end
end, autoSellLegendaryEggsEnabled)

CreateToggle("Auto Sell", "Mythical Eggs", function(state)
    autoSellMythicalEggsEnabled = state.Value
    if autoSellMythicalEggsEnabled then
        notify("Mythical Eggs enabled")
        startAutoSellMythicalEggs()
    else
        notify("Mythical Eggs disabled")
    end
end, autoSellMythicalEggsEnabled)

-- CREATE PET WARNING TAB UI
CreateLabel("Pet Warning", "RPS Threshold")

local appliedThresholdLabel = nil
local thresholdInput = CreateInput("Pet Warning", "Threshold Value", tostring(appliedThreshold), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value then
        appliedThreshold = value
        if appliedThresholdLabel then
            appliedThresholdLabel.Text = "Applied Threshold: " .. appliedThreshold
        end
        notify("RPS Threshold set to " .. appliedThreshold)
    else
        notify("Invalid threshold value", true)
    end
end)

appliedThresholdLabel = CreateValueLabel("Pet Warning", "Applied Threshold: " .. appliedThreshold)

-- Helper function to format seconds to human-readable time
local function formatSeconds(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    local parts = {}
    if hours > 0 then
        table.insert(parts, hours .. "h")
    end
    if minutes > 0 then
        table.insert(parts, minutes .. "m")
    end
    if secs > 0 or #parts == 0 then
        table.insert(parts, secs .. "s")
    end
    
    return table.concat(parts, " ")
end

-- Load saved slot times from config before creating UI elements
local savedSlot1Time = getConfigSetting("Save Cycling", "Slot 1 Time (seconds)")
if savedSlot1Time then
    saveSlot1Time = tonumber(savedSlot1Time) or saveSlot1Time
end

local savedSlot2Time = getConfigSetting("Save Cycling", "Slot 2 Time (seconds)")
if savedSlot2Time then
    saveSlot2Time = tonumber(savedSlot2Time) or saveSlot2Time
end

local savedSlot3Time = getConfigSetting("Save Cycling", "Slot 3 Time (seconds)")
if savedSlot3Time then
    saveSlot3Time = tonumber(savedSlot3Time) or saveSlot3Time
end

local savedSlot4Time = getConfigSetting("Save Cycling", "Slot 4 Time (seconds)")
if savedSlot4Time then
    saveSlot4Time = tonumber(savedSlot4Time) or saveSlot4Time
end

-- CREATE MISC TAB UI
CreateToggle("Save Cycling", "Auto Cycle Saves", function(state)
    autoCycleSavesEnabled = state.Value
    if autoCycleSavesEnabled then
        notify("Auto Cycle Saves enabled")
        startAutoCycleSaves()
    else
        notify("Auto Cycle Saves disabled")
    end
end, autoCycleSavesEnabled)

CreateToggle("Save Cycling", "Collect Pet Cash Before Switch", function(state)
    autoCollectPetCashEnabled = state.Value
    if autoCollectPetCashEnabled then
        notify("Will collect pet cash before switching saves")
    else
        notify("Pet cash collection before switch disabled")
    end
end, autoCollectPetCashEnabled)

local saveCycleStatusLabel = CreateValueLabel("Save Cycling", "Save slot: --, next slot: --, next cycle: --")

-- Update save cycle status every second
task.spawn(function()
    while true do
        task.wait(1)
        if autoCycleSavesEnabled and currentSaveSlot > 0 and saveCycleStartTime > 0 then
            local elapsed = tick() - saveCycleStartTime
            local remaining = math.max(0, currentCycleInterval - elapsed)
            local nextSlot = getNextValidSlot(currentSaveSlot)
            if nextSlot then
                saveCycleStatusLabel.Text = string.format(
                    "Save slot: %d, next slot: %d, next cycle: %s",
                    currentSaveSlot,
                    nextSlot,
                    formatSeconds(math.ceil(remaining))
                )
            else
                saveCycleStatusLabel.Text = "Save slot: " .. currentSaveSlot .. ", next slot: none (all 0)"
            end
        else
            saveCycleStatusLabel.Text = "Save slot: --, next slot: --, next cycle: --"
        end
    end
end)

CreateButton("Save Cycling", "Previous Slot", function()
    local baseSlot = currentSaveSlot
    if baseSlot < 1 or baseSlot > 4 then
        baseSlot = 1
    end
    local prevSlot = baseSlot - 1
    if prevSlot < 1 then
        prevSlot = 4
    end
    switchToSlot(prevSlot, false)
end)

CreateButton("Save Cycling", "Next Slot", function()
    local baseSlot = currentSaveSlot
    if baseSlot < 1 or baseSlot > 4 then
        baseSlot = 1
    end
    local nextSlot = baseSlot + 1
    if nextSlot > 4 then
        nextSlot = 1
    end
    switchToSlot(nextSlot, false)
end)

CreateLabel("Save Cycling", "Set time to 0 to skip that slot")

CreateInput("Save Cycling", "Slot 1 Time (seconds)", tostring(saveSlot1Time), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value >= 0 then
        saveSlot1Time = value
        if value == 0 then
            notify("Slot 1 will be skipped")
        else
            notify("Slot 1 time set to " .. formatSeconds(saveSlot1Time))
        end
    else
        notify("Invalid time value", true)
    end
end)

CreateInput("Save Cycling", "Slot 2 Time (seconds)", tostring(saveSlot2Time), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value >= 0 then
        saveSlot2Time = value
        if value == 0 then
            notify("Slot 2 will be skipped")
        else
            notify("Slot 2 time set to " .. formatSeconds(saveSlot2Time))
        end
    else
        notify("Invalid time value", true)
    end
end)

CreateInput("Save Cycling", "Slot 3 Time (seconds)", tostring(saveSlot3Time), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value >= 0 then
        saveSlot3Time = value
        if value == 0 then
            notify("Slot 3 will be skipped")
        else
            notify("Slot 3 time set to " .. formatSeconds(saveSlot3Time))
        end
    else
        notify("Invalid time value", true)
    end
end)

CreateInput("Save Cycling", "Slot 4 Time (seconds)", tostring(saveSlot4Time), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value >= 0 then
        saveSlot4Time = value
        if value == 0 then
            notify("Slot 4 will be skipped")
        else
            notify("Slot 4 time set to " .. formatSeconds(saveSlot4Time))
        end
    else
        notify("Invalid time value", true)
    end
end)

-- CREATE MENUS TAB UI
local function openMenu(menuName)
    local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
    local MenuController = Knit.GetController("MenuController")
    
    local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local menu = PlayerGui:WaitForChild(menuName)
    
    if menu and menu:FindFirstChild("Holder") then
        MenuController:OpenMenuFrame(menu, menu.Holder)
        notify(menuName .. " opened")
    else
        notify("Could not find " .. menuName, true)
    end
end

CreateButton("Menus", "Mutation Machine (Cupid Mutation)", function()
    openMenu("MutationMachine")
end)

CreateButton("Menus", "Merchant", function()
    openMenu("Merchant")
end)

-- CreateButton("Menus", "Close Current Menu", function()
--     local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
--     local MenuController = Knit.GetController("MenuController")
--     MenuController:CloseMenu()
--     notify("Menu closed")
-- end)

-- ============================================================
-- FEEDBACK TAB
-- ============================================================

CreateLabel("Feedback", "Send bug reports or suggestions to the developer")

CreateInput("Feedback", "Bug Report", "Describe the bug...", "Send Bug Report", function(textBox)
    local message = textBox.Text
    if message and message ~= "" and message ~= "Describe the bug..." then
        local success = sendWebhook("🐛 **Bug Report**\n" .. message)
        if success then
            notify("Bug report sent!")
            textBox.Text = "Describe the bug..."
        else
            notify("Failed to send bug report", true)
        end
    else
        notify("Please enter a bug description", true)
    end
end)

CreateInput("Feedback", "Suggestion", "Your suggestion...", "Send Suggestion", function(textBox)
    local message = textBox.Text
    if message and message ~= "" and message ~= "Your suggestion..." then
        local success = sendWebhook("💡 **Suggestion**\n" .. message)
        if success then
            notify("Suggestion sent!")
            textBox.Text = "Your suggestion..."
        else
            notify("Failed to send suggestion", true)
        end
    else
        notify("Please enter a suggestion", true)
    end
end)

-- Initialize auto features (only those enabled in settings)
if autoCatchBest or autoCatchMythical or autoCatchMissing or autoCatchCustom then
    startAutoCatchMaster()
end
if autoBreedEnabled then
    startAutoBreed()
end
if autoRemoveEggsEnabled then
    startAutoRemoveEggs()
end
if autoSellLegendaryEggsEnabled then
    startAutoSellLegendaryEggs()
end
if autoSellMythicalEggsEnabled then
    startAutoSellMythicalEggs()
end
if autoBuyFoodEnabled then
    setupAutoBuyFood()
end
if autoBuyMerchantEnabled then
    setupAutoBuyMerchant()
end
if autoCycleSavesEnabled then
    startAutoCycleSaves()
end

print("✓ Pet Scanner loaded with UI Library!")
-- CATCH AND TAME (https://www.roblox.com/games/96645548064314/)

-- ============================================================
-- SETTINGS - Modify these to customize default behavior
-- ============================================================

-- Breeding Configuration
local breedingPairs = {
    { "Axolotl", "Red Panda" },
    { "Red Panda", "Kitsune" },
    { "Galaxy Kitsune", "Galaxy Axolotl" },
    { "Galaxy Axolotl", "Galaxy Axolotl" },
    { "Lightning Dragon", "Cerberus" }
}

-- Catch Settings
local catchCps = 40  -- Progress updates per second during minigame
local minCatchRPS = 1000  -- Minimum RPS required to catch (0 = disabled)
local ignoreMinRPSForSecret = false  -- Catch Secret pets regardless of min RPS
local ignoreMinRPSForExclusive = false  -- Catch Exclusive pets regardless of min RPS
local ignoreMinRPSForMissing = false  -- Catch missing pets regardless of min RPS
local appliedThreshold = 1000  -- RPS threshold for "new best pet" warning

-- Auto-Catch Default States
local autoCatchBest = false  -- Auto-catch best overall pet
local autoCatchMythical = false  -- Auto-catch best Mythical+ pet
local autoCatchMissing = false  -- Auto-catch best missing pet

-- Auto Features Default States
local autoBreedEnabled = false  -- Auto-breed configured pairs
local autoRemoveEggsEnabled = false  -- Auto-remove eggs from pen
local autoBuyFoodEnabled = false  -- Auto-buy food when available
local autoBuyMerchantEnabled = false  -- Auto-buy from traveling merchant
local merchantPurchaseDelay = 0.1  -- Delay between merchant purchases (seconds)

-- Auto Sell Default States
local autoSellLegendaryEggsEnabled = false  -- Auto-sell Legendary eggs
local autoSellMythicalEggsEnabled = false  -- Auto-sell Mythical eggs

-- Save Cycling Settings
local autoCycleSavesEnabled = false  -- Auto-cycle through save slots
local saveCycleInterval = 375  -- Interval between save switches (seconds) - 6m 15s

-- ============================================================
-- END SETTINGS
-- ============================================================

local catchDelay = 1 / catchCps

local folders = {
    workspace.SkyIslandPets.Pets,
    workspace.RoamingPets.Pets
}

local player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("knit"))
local FoodConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Food"))

-- Load UI Library
local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

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
CreateTab("Catch And Tame", "Main", "Auto Features")
CreateTab("Catch And Tame", "Main", "Auto Sell")
CreateTab("Catch And Tame", "Main", "Pet Warning")
CreateTab("Catch And Tame", "Main", "Save Cycling")

local uiRoot = player.PlayerGui:WaitForChild("TomtomFHUI")
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
    image.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
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

-- Helper function to set pet image
local function setPetImage(imageLabel, petName)
    if petsConfig and petsConfig[petName] and petsConfig[petName].Image then
        local imageId = petsConfig[petName].Image
        imageLabel.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
        task.spawn(function()
            pcall(function()
                imageLabel.Image = "rbxthumb://type=Asset&id=" .. imageId .. "&w=420&h=420"
            end)
        end)
    end
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
local previousBestRPS = -math.huge
local warningActive = false
local appliedThreshold = 1000

-- Catch minimum RPS settings
local minCatchRPS = 1000
local ignoreMinRPSForSecret = true
local ignoreMinRPSForExclusive = true
local ignoreMinRPSForMissing = true

-- Toggle states
local autoCatchBest = false
local autoCatchMythical = true
local autoCatchMissing = true
local autoCatchMasterLoop = false
local catchLock = false
local autoBreedEnabled = true
local autoBreedLoop = false
local autoRemoveEggsEnabled = true
local autoRemoveEggsLoop = false
local autoSellLegendaryEggsEnabled = true
local autoSellLegendaryEggsLoop = false
local autoSellMythicalEggsEnabled = false
local autoSellMythicalEggsLoop = false
local autoBuyFoodEnabled = true
local autoBuyFoodSetup = false
local autoBuyMerchantEnabled = true
local autoBuyMerchantSetup = false
local merchantPurchaseDelay = 0.1

-- Auto-cycle saves settings
local autoCycleSavesEnabled = false
local autoCycleSavesLoop = false
local saveCycleInterval = 375  -- 6 min 15 sec in seconds
local currentSaveSlot = 0  -- 0 = unknown, will be set when cycling starts
local saveCycleStartTime = 0  -- Track when current cycle started
local currentCycleInterval = 0  -- Track the interval for the current cycle

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
            setPetImage(bestPetImage, bestPet:GetAttribute("Name"))
        end
    else
        if bestPetInfo then
            bestPetInfo.Text = "No pet found"
        end
        if bestPetImage then
            bestPetImage.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
        end
    end
    -- Update best mythical+ display
    bestMythical = newBestMythical
    if bestMythical then
        if mythicalInfo then
            mythicalInfo.Text = getPetInfo(bestMythical, bestMythicalRPS)
        end
        if mythicalImage then
            setPetImage(mythicalImage, bestMythical:GetAttribute("Name"))
        end
    else
        if mythicalInfo then
            mythicalInfo.Text = "No Mythical+ pet found"
        end
        if mythicalImage then
            mythicalImage.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
        end
    end

    -- Update best missing display
    bestMissing = newBestMissing
    if bestMissing then
        if missingInfo then
            missingInfo.Text = getPetInfo(bestMissing, bestMissingRPS)
        end
        if missingImage then
            setPetImage(missingImage, bestMissing:GetAttribute("Name"))
        end
    else
        if missingInfo then
            missingInfo.Text = "No missing pets found"
        end
        if missingImage then
            missingImage.Image = "rbxasset://textures/Ui/GuiImagePlaceholder.png"
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

                -- Breed all configured pairs
                for _, pair in pairs(breedingPairs) do
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
    print("[AutoSellEggs] Run cycle for " .. rarity)
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local getEggInventory = remotes:WaitForChild("getEggInventory")
    local sellEgg = remotes:WaitForChild("sellEgg")

    local maxAttempts = 5
    local totalSold = 0

    local function trySellEgg(guid)
        for attempt = 1, maxAttempts do
            local ok = sellEgg:InvokeServer(guid, false)
            if ok then
                print(string.format("[AutoSellEggs] Sold %s", tostring(guid)))
                return true
            end
            print(string.format("[AutoSellEggs] Retry %s attempt %d", tostring(guid), attempt))
            task.wait(0.15 * attempt)
        end
        return false
    end

    local didSellInPass = true
    while enabledVar and didSellInPass do
        print("[AutoSellEggs] Fetching inventory...")
        local eggs = getEggInventory:InvokeServer()
        if type(eggs) ~= "table" then
            print("[AutoSellEggs] Inventory fetch failed")
            return
        end

        didSellInPass = false
        for guid, egg in pairs(eggs) do
            if not enabledVar then
                break
            end
            if egg and egg.rarity == rarity then
                print(string.format("[AutoSellEggs] Selling %s | name=%s", tostring(guid), tostring(egg.eggName)))
                local ok = trySellEgg(guid)
                if ok then
                    didSellInPass = true
                    totalSold = totalSold + 1
                end
                task.wait(0.2)
            end
        end

        if didSellInPass then
            print("[AutoSellEggs] Refreshing inventory UI")
            task.wait(0.2)
            refreshInventoryUI()
        else
            print("[AutoSellEggs] No " .. rarity .. " eggs found")
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
        print("[AutoSellEggs] Mythical loop already running")
        return
    end

    autoSellMythicalEggsLoop = true
    task.spawn(function()
        print("[AutoSellEggs] Mythical loop started")
        while autoSellMythicalEggsEnabled do
            autoSellEggsOnce("Mythical", autoSellMythicalEggsEnabled)
            task.wait(5)
        end
        print("[AutoSellEggs] Mythical loop stopped")
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
            local getSaveInfo = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("getSaveInfo")
            
            for slot = 1, 4 do
                if not autoCycleSavesEnabled then
                    break
                end
                
                saveCycleStartTime = tick()  -- Mark cycle start
                currentCycleInterval = saveCycleInterval  -- Capture interval at cycle start
                local args = { slot, true }
                pcall(function()
                    getSaveInfo:InvokeServer(unpack(args))
                end)
                
                currentSaveSlot = slot
                notify(string.format("Switched to save slot %d", slot))
                task.wait(saveCycleInterval)
            end
        end
        autoCycleSavesLoop = false
    end)
end

local function startAutoSellLegendaryEggs()
    if autoSellLegendaryEggsLoop then
        print("[AutoSellEggs] Loop already running")
        return
    end

    autoSellLegendaryEggsLoop = true
    task.spawn(function()
        print("[AutoSellEggs] Loop started")
        while autoSellLegendaryEggsEnabled do
            autoSellLegendaryEggsOnce()
            task.wait(5)
        end
        print("[AutoSellEggs] Loop stopped")
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
        while autoCatchBest or autoCatchMythical or autoCatchMissing do
            -- Priority: Mythical+ > Missing > Best Overall
            if autoCatchMythical and bestMythical and shouldCatchPet(bestMythical) then
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
    if autoCatchBest then
        bestPetAutoToggle.Text = "Auto Catch: ON"
        bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
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
    if autoCatchMythical then
        mythicalAutoToggle.Text = "Auto Catch: ON"
        mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
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
    if autoCatchMissing then
        missingAutoToggle.Text = "Auto Catch: ON"
        missingAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
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

-- CREATE CATCHING SETTINGS UI
local minRPSLabel = CreateValueLabel("Catching", "Catch Minimum RPS: 1000")

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
end, true)

CreateToggle("Catching", "Ignore Min RPS for Exclusive", function(state)
    ignoreMinRPSForExclusive = state.Value
    if ignoreMinRPSForExclusive then
        notify("Will catch Exclusive pets regardless of min RPS")
    else
        notify("Exclusive pets must meet minimum RPS")
    end
end, true)

CreateToggle("Catching", "Ignore Min RPS for Missing", function(state)
    ignoreMinRPSForMissing = state.Value
    if ignoreMinRPSForMissing then
        notify("Will catch Missing pets regardless of min RPS")
    else
        notify("Missing pets must meet minimum RPS")
    end
end, true)

-- CREATE AUTO FEATURES TAB UI
CreateToggle("Auto Features", "AutoBreed", function(state)
    autoBreedEnabled = state.Value
    if autoBreedEnabled then
        notify("AutoBreed enabled")
        startAutoBreed()
    else
        notify("AutoBreed disabled")
    end
end, true)

CreateToggle("Auto Features", "AutoRemove Eggs", function(state)
    autoRemoveEggsEnabled = state.Value
    if autoRemoveEggsEnabled then
        notify("AutoRemove Eggs enabled")
        startAutoRemoveEggs()
    else
        notify("AutoRemove Eggs disabled")
    end
end, true)

CreateToggle("Auto Features", "AutoBuy Food", function(state)
    autoBuyFoodEnabled = state.Value
    if autoBuyFoodEnabled then
        notify("AutoBuy Food enabled")
    else
        notify("AutoBuy Food disabled")
    end
    setupAutoBuyFood()
end, true)

CreateToggle("Auto Features", "AutoBuy Merchant", function(state)
    autoBuyMerchantEnabled = state.Value
    if autoBuyMerchantEnabled then
        notify("AutoBuy Merchant enabled")
    else
        notify("AutoBuy Merchant disabled")
    end
    setupAutoBuyMerchant()
end, true)

CreateToggle("Auto Sell", "AutoSell Legendary Eggs", function(state)
    autoSellLegendaryEggsEnabled = state.Value
    if autoSellLegendaryEggsEnabled then
        notify("AutoSell Legendary Eggs enabled")
        startAutoSellLegendaryEggs()
    else
        notify("AutoSell Legendary Eggs disabled")
    end
end, true)

CreateToggle("Auto Sell", "AutoSell Mythical Eggs", function(state)
    autoSellMythicalEggsEnabled = state.Value
    if autoSellMythicalEggsEnabled then
        notify("AutoSell Mythical Eggs enabled")
        startAutoSellMythicalEggs()
    else
        notify("AutoSell Mythical Eggs disabled")
    end
end)

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

CreateButton("Pet Warning", "Close Menu", function()
    DestroyMenu("Catch And Tame")
end)

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

-- CREATE MISC TAB UI
local saveCycleIntervalLabel = CreateValueLabel("Save Cycling", "Save Cycle Interval: " .. formatSeconds(saveCycleInterval))

local saveCycleIntervalInput = CreateInput("Save Cycling", "Interval (seconds)", tostring(saveCycleInterval), "Apply", function(textBox)
    local value = tonumber(textBox.Text)
    if value and value > 0 then
        saveCycleInterval = value
        saveCycleIntervalLabel.Text = "Save Cycle Interval: " .. formatSeconds(saveCycleInterval)
        notify("Save cycle interval set to " .. formatSeconds(saveCycleInterval))
    else
        notify("Invalid interval value", true)
    end
end)

local saveCycleStatusLabel = CreateValueLabel("Save Cycling", "Save slot: --, next slot: --, next cycle: --")

-- Update save cycle status every second
task.spawn(function()
    while true do
        task.wait(1)
        if autoCycleSavesEnabled and currentSaveSlot > 0 and saveCycleStartTime > 0 then
            local elapsed = tick() - saveCycleStartTime
            local remaining = math.max(0, currentCycleInterval - elapsed)
            local nextSlot = (currentSaveSlot % 4) + 1
            saveCycleStatusLabel.Text = string.format(
                "Save slot: %d, next slot: %d, next cycle: %s",
                currentSaveSlot,
                nextSlot,
                formatSeconds(math.ceil(remaining))
            )
        else
            saveCycleStatusLabel.Text = "Save slot: --, next slot: --, next cycle: --"
        end
    end
end)

CreateToggle("Save Cycling", "Auto Cycle Saves", function(state)
    autoCycleSavesEnabled = state.Value
    if autoCycleSavesEnabled then
        notify("Auto Cycle Saves enabled")
        startAutoCycleSaves()
    else
        notify("Auto Cycle Saves disabled")
    end
end)

-- Initialize auto features
startAutoCatchMaster()
startAutoBreed()
startAutoRemoveEggs()
startAutoSellLegendaryEggs()
setupAutoBuyFood()
setupAutoBuyMerchant()

-- Update toggle button visuals for enabled features
mythicalAutoToggle.Text = "Auto Catch: ON"
mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
missingAutoToggle.Text = "Auto Catch: ON"
missingAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)

print("✓ Pet Scanner loaded with UI Library!")
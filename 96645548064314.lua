-- CATCH AND TAME (https://www.roblox.com/games/96645548064314/)

-- Define breeding pairs here
local breedingPairs = {
    { "Axolotl", "Red Panda" },
    { "Red Panda", "Kitsune" },
    { "Galaxy Kitsune", "Galaxy Axolotl" },
    { "Galaxy Axolotl", "Galaxy Axolotl" }
}

-- Catch CPS setting (progress updates per second)
local catchCps = 40
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
local function loadPetsConfig()
    pcall(function()
        petsConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Pets"))
    end)
end
task.spawn(loadPetsConfig)

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
CreateMenu("Pet Scanner")
CreateGroup("Pet Scanner", "Main")
CreateTab("Pet Scanner", "Main", "Catching")
CreateTab("Pet Scanner", "Main", "Auto Features")
CreateTab("Pet Scanner", "Main", "Pet Warning")

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

local cardsRow = CreateContainer("Catching", 150, true)

local function createPetCard(parent, titleText, titleColor, position)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(0.5, -5, 0, 140)
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
    info.Size = UDim2.new(0.65, -10, 0, 70)
    info.Position = UDim2.new(0, 80, 0, 35)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(255, 255, 255)
    info.TextWrapped = true
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    info.TextSize = 12
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
    local mutation = pet:GetAttribute("Mutation") or "None"

    return name ..
        "\n💲 RPS: " .. rpsValue ..
        "\n💪 STR: " .. strength ..
        "\n⭐ Rarity: " .. rarity ..
        "\n📏 Size: " .. sizeName ..
        "\n🧬 Mutation: " .. mutation
end

-- Variables for tracking pets
local bestPet = nil
local bestMythical = nil
local previousBestRPS = -math.huge
local warningActive = false
local appliedThreshold = 1000

-- Toggle states
local autoCatchBest = false
local autoCatchMythical = false
local autoCatchBestLoop = false
local autoCatchMythicalLoop = false
local catchLocks = {
    best = false,
    mythical = false
}
local autoBreedEnabled = false
local autoBreedLoop = false
local autoRemoveEggsEnabled = false
local autoRemoveEggsLoop = false
local autoSellLegendaryEggsEnabled = false
local autoSellLegendaryEggsLoop = false
local autoBuyFoodEnabled = true
local autoBuyFoodSetup = false
local autoBuyMerchantEnabled = true
local autoBuyMerchantSetup = false
local merchantPurchaseDelay = 0.1

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
    local rarityPriority = { Secret = 3, Exclusive = 2, Mythical = 1 }

    for _, folder in pairs(folders) do
        for _, pet in pairs(folder:GetChildren()) do
            local rps = pet:GetAttribute("RPS")
            local rarity = pet:GetAttribute("Rarity")
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

local function autoSellLegendaryEggsOnce()
    print("[AutoSellEggs] Run cycle")
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
    while autoSellLegendaryEggsEnabled and didSellInPass do
        print("[AutoSellEggs] Fetching inventory...")
        local eggs = getEggInventory:InvokeServer()
        if type(eggs) ~= "table" then
            print("[AutoSellEggs] Inventory fetch failed")
            return
        end

        didSellInPass = false
        for guid, egg in pairs(eggs) do
            if not autoSellLegendaryEggsEnabled then
                break
            end
            if egg and egg.rarity == "Legendary" then
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
            print("[AutoSellEggs] No Legendary eggs found")
        end
    end
    
    if totalSold > 0 then
        notify(string.format("Sold %d Legendary egg%s", totalSold, totalSold > 1 and "s" or ""))
    end
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

local function catchPet(pet, lockKey)
    if not pet or catchLocks[lockKey] then
        return
    end

    catchLocks[lockKey] = true
    task.spawn(function()
        local character = player.Character
        if not character then
            catchLocks[lockKey] = false
            return
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            catchLocks[lockKey] = false
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

        catchLocks[lockKey] = false
    end)
end

local function startAutoCatchBest()
    if autoCatchBestLoop then
        return
    end

    autoCatchBestLoop = true
    task.spawn(function()
        while autoCatchBest do
            if bestPet then
                catchPet(bestPet, "best")
            end
            task.wait(0.8)
        end
        autoCatchBestLoop = false
    end)
end

local function startAutoCatchMythical()
    if autoCatchMythicalLoop then
        return
    end

    autoCatchMythicalLoop = true
    task.spawn(function()
        while autoCatchMythical do
            if bestMythical then
                catchPet(bestMythical, "mythical")
            end
            task.wait(0.8)
        end
        autoCatchMythicalLoop = false
    end)
end

bestPetAutoToggle.MouseButton1Click:Connect(function()
    autoCatchBest = not autoCatchBest
    if autoCatchBest then
        bestPetAutoToggle.Text = "Auto Catch: ON"
        bestPetAutoToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
        startAutoCatchBest()
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
        startAutoCatchMythical()
    else
        mythicalAutoToggle.Text = "Auto Catch: OFF"
        mythicalAutoToggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

bestCard.MouseButton1Click:Connect(function()
    if bestPet then
        catchPet(bestPet, "best")
    end
end)

mythicalCard.MouseButton1Click:Connect(function()
    if bestMythical then
        catchPet(bestMythical, "mythical")
    end
end)

-- CREATE CATCHING TAB UI
CreateButton("Catching", "Catch Best Pet", function()
    if bestPet then
        catchPet(bestPet, "best")
    end
end)

CreateButton("Catching", "Catch Mythical+ Pet", function()
    if bestMythical then
        catchPet(bestMythical, "mythical")
    end
end)

-- CREATE AUTO FEATURES TAB UI
CreateToggle("Auto Features", "AutoBreed", function(state)
    autoBreedEnabled = state.Value
    if autoBreedEnabled then
        startAutoBreed()
    end
end)

CreateToggle("Auto Features", "AutoRemove Eggs", function(state)
    autoRemoveEggsEnabled = state.Value
    if autoRemoveEggsEnabled then
        startAutoRemoveEggs()
    end
end)

CreateToggle("Auto Features", "AutoBuy Food", function(state)
    autoBuyFoodEnabled = state.Value
    setupAutoBuyFood()
end)

CreateToggle("Auto Features", "AutoBuy Merchant", function(state)
    autoBuyMerchantEnabled = state.Value
    setupAutoBuyMerchant()
end)

CreateToggle("Auto Features", "AutoSell Legendary Eggs", function(state)
    autoSellLegendaryEggsEnabled = state.Value
    if autoSellLegendaryEggsEnabled then
        startAutoSellLegendaryEggs()
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
    DestroyMenu("Pet Scanner")
end)

-- Initialize auto features
setupAutoBuyFood()
setupAutoBuyMerchant()

print("✓ Pet Scanner loaded with UI Library!")
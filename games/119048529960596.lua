-- Restaurant Tycoon 3 - Boost, Menu, Staff, and Info helper
local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G
local RUNTIME_KEY = "__TomtomFHRestaurantTycoon3Runtime"
local previousRuntime = rawget(runtimeEnvironment, RUNTIME_KEY)
if type(previousRuntime) == "table" and type(previousRuntime.Cleanup) == "function" then
    pcall(previousRuntime.Cleanup)
end

local scriptRuntime = {
    Active = true,
    Connections = {},
    CleanupCallbacks = {},
    State = {
        RowCount = 0,
        InventoryReady = false,
        Status = "Starting",
    },
}

local function cleanupRuntime()
    if not scriptRuntime.Active then
        return
    end

    scriptRuntime.Active = false

    if type(scriptRuntime.ScanRestore) == "function" then
        pcall(scriptRuntime.ScanRestore)
        scriptRuntime.ScanRestore = nil
    end

    for index = #scriptRuntime.Connections, 1, -1 do
        local connection = scriptRuntime.Connections[index]
        pcall(function()
            connection:Disconnect()
        end)
        scriptRuntime.Connections[index] = nil
    end

    for index = #scriptRuntime.CleanupCallbacks, 1, -1 do
        pcall(scriptRuntime.CleanupCallbacks[index])
        scriptRuntime.CleanupCallbacks[index] = nil
    end

    if rawget(runtimeEnvironment, RUNTIME_KEY) == scriptRuntime then
        rawset(runtimeEnvironment, RUNTIME_KEY, nil)
    end
end

local function trackConnection(connection)
    if connection then
        table.insert(scriptRuntime.Connections, connection)
    end
    return connection
end

scriptRuntime.Cleanup = cleanupRuntime
rawset(runtimeEnvironment, RUNTIME_KEY, scriptRuntime)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local playerSource = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("Source")

local source = ReplicatedStorage:WaitForChild("Source")
local FoodData = require(source.Data.Food)
local IngredientData = require(source.Data.Food.IngredientData)
local CustomDishData = require(source.Data.Food.Custom.CustomDishData)
local CustomDishComboData = require(source.Data.Food.Custom.CustomDishComboData)
local FoodUtility = require(source.Utility.Food.FoodUtility)
local Interior = require(source.Enums.Interior)
local WorkerTypeData = require(source.Data.Restaurant.Workers.WorkerTypeData)
local Task = require(source.Enums.Restaurant.Task)
local CustomWorkerRole = require(source.Enums.Restaurant.Workers.CustomWorkerRole)
local CollectBillController = require(playerSource.Modules.Tasks.CollectBill)
local CustomDishMenu = require(playerSource.Systems.FoodMenu.CustomDishMenu)
local CustomDishCombos = require(
    playerSource.Systems.InterfaceController.CustomDishCreatorController.CustomDishCombos
)

local events = ReplicatedStorage:WaitForChild("Events")
local foodEvents = events:WaitForChild("Food")
local dataEvents = events:WaitForChild("Data")
local getMenuRemote = events.Restaurant.FoodMenu.GetMenu
local purchaseIngredientRemote = foodEvents.PurchaseIngredientRequested
local boostRemote = foodEvents.BoostRequested
local toppingPurchasedRemote = foodEvents.CustomDishToppingPurchased
local comboUnlockRemote = foodEvents.CustomDishComboUnlockRequested
local foodMenuStatusRemote = foodEvents.FoodMenuStatusRequested
local workerEvents = events.Restaurant.Workers
local upgradeWorkerRemote = workerEvents.UpgradeWorkerRequested
local rolesChangedRemote = workerEvents.RolesChanged

-- Fetch the first snapshot before constructing the protected UI tree. This lets
-- every initial dish card be created on the same privileged execution thread.
local initialTycoonValue = localPlayer:FindFirstChild("Tycoon")
local initialTycoon = initialTycoonValue
    and initialTycoonValue:IsA("ObjectValue")
    and initialTycoonValue.Value
local initialMenuSnapshot
if initialTycoon then
    local ok, initialMenu, initialCookbook, initialBoosted, initialSpecials, initialKidsMenu, _, initialSuperBoosted = pcall(function()
        return getMenuRemote:InvokeServer(initialTycoon)
    end)
    if ok then
        initialMenuSnapshot = {
            Menu = type(initialMenu) == "table" and initialMenu or {},
            Cookbook = type(initialCookbook) == "table" and initialCookbook or {},
            Boosted = type(initialBoosted) == "table" and initialBoosted or {},
            Specials = type(initialSpecials) == "table" and initialSpecials or {},
            KidsMenu = type(initialKidsMenu) == "table" and initialKidsMenu or {},
            SuperBoosted = type(initialSuperBoosted) == "table" and initialSuperBoosted or {},
        }
    end
end

rawset(runtimeEnvironment, "__TomtomFHUIForcePlayerGui", true)
local libraryOk, libraryError = pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua",
        true
    ))()
end)
rawset(runtimeEnvironment, "__TomtomFHUIForcePlayerGui", nil)
if not libraryOk then
    error(libraryError)
end

local MENU_NAME = "RT3 Helper"
local INFO_TAB_NAME = "Info"
local TAB_NAME = "Boost"
local STAND_TAB_NAME = "Stand"
local STAND_OWNERSHIP_CONFIG_TAB = "Stand Topping Ownership"
local STAND_COMBO_CONFIG_TAB = "Stand Combo Ownership"
local MENU_TAB_NAME = "Menu"
local STAFF_TAB_NAME = "Staff"
local AUTO_TAB_NAME = "Auto"

local COLORS = {
    Green = Color3.fromRGB(50, 205, 125),
    Yellow = Color3.fromRGB(255, 193, 7),
    Red = Color3.fromRGB(245, 76, 76),
    Blue = Color3.fromRGB(0, 170, 255),
    Text = Color3.fromRGB(245, 245, 247),
    Muted = Color3.fromRGB(170, 174, 184),
    Surface = Color3.fromRGB(18, 18, 21),
}

local LIMITED_INTERIORS = {
    [Interior.Bakery] = true,
    [Interior.FarmShop] = true,
}

local currentTycoon = initialTycoon
local currentMenu = initialMenuSnapshot and initialMenuSnapshot.Menu or {}
local cookbook = initialMenuSnapshot and initialMenuSnapshot.Cookbook or {}
local boostedFoods = initialMenuSnapshot and initialMenuSnapshot.Boosted or {}
local superBoostedFoods = initialMenuSnapshot and initialMenuSnapshot.SuperBoosted or {}
scriptRuntime.MenuData = {
    Specials = initialMenuSnapshot and initialMenuSnapshot.Specials or {},
    KidsMenu = initialMenuSnapshot and initialMenuSnapshot.KidsMenu or {},
}
local ingredientOwnership = {}
local ingredientInventoryReady = false
local forcedStockAll = false
local currentRestockId = -1
local limitedStock = {}
local menuRefreshBusy = false
local scanBusy = false
local renderQueued = false
local menuRevisionSignature
local actionBusy = {}
local rowControls = {}
local standActionBusy = {}
local standRowControls = {}
local knownUnlockedToppings = {}
local knownUnlockedCombos = {}
local statusLabel
local listFrame
local listLayout
local standStatusLabel
local standListFrame
local standListLayout
local menuStatusLabel
local menuCourseLabels = {}
local autoMenuEnabled = false
local expandedMenuPreset = false
local menuManageBusy = false
local menuManageQueued = false
local autoCollectTableCash = false
local processedBills = setmetatable({}, { __mode = "k" })
local staffSnapshot = {}
local staffByKey = {}
local staffTaskStates = {}
local staffRowControls = {}
local staffCategoryButtons = {}
local staffListFrame
local staffListLayout
local staffStatusLabel
local infoLabels = {}
local sessionStartedAt = os.clock()
local sessionStartCash = 0
local lastRecordedCash = 0
local grossSessionIncome = 0
local sessionSpending = 0
local updateAllStandRows
local rebuildStandRows

local function setStatus(text, color)
    scriptRuntime.State.Status = text
    if statusLabel then
        statusLabel.Text = text
        statusLabel.TextColor3 = color or COLORS.Muted
    end
end

local function findTycoon()
    local tycoonValue = localPlayer:FindFirstChild("Tycoon")
    if tycoonValue and tycoonValue:IsA("ObjectValue") and tycoonValue.Value then
        return tycoonValue.Value
    end

    local tycoons = workspace:FindFirstChild("Tycoons")
    if tycoons then
        for _, tycoon in ipairs(tycoons:GetChildren()) do
            local owner = tycoon:FindFirstChild("Player")
            if owner and owner:IsA("ObjectValue") and owner.Value == localPlayer then
                return tycoon
            end
        end
    end

    return nil
end

local function getOwner()
    local tycoon = currentTycoon or findTycoon()
    local ownerValue = tycoon and tycoon:FindFirstChild("Player")
    return ownerValue and ownerValue.Value or localPlayer
end

local function collectTableBill(bill)
    if not autoCollectTableCash
        or not scriptRuntime.Active
        or not bill
        or processedBills[bill]
        or bill.Name ~= "Bill"
        or bill:GetAttribute("Taken") == true
    then
        return
    end

    currentTycoon = findTycoon()
    if not currentTycoon or not bill:IsDescendantOf(currentTycoon) then
        return
    end

    local tableModel = bill.Parent
    if not tableModel then
        return
    end

    processedBills[bill] = true
    local ok = pcall(function()
        CollectBillController:ProcessTableInput(currentTycoon, tableModel)
    end)
    if not ok then
        processedBills[bill] = nil
    end
end

local function queueTableBillCollection(bill)
    task.defer(function()
        collectTableBill(bill)
    end)
end

local function collectOutstandingTableBills()
    if not autoCollectTableCash then
        return
    end
    for _, bill in ipairs(CollectionService:GetTagged("Bill")) do
        queueTableBillCollection(bill)
    end
end

trackConnection(CollectionService:GetInstanceAddedSignal("Bill"):Connect(queueTableBillCollection))

local autoRestaurantTasks = {}
scriptRuntime.AutoRestaurantTasks = autoRestaurantTasks
do
local FurnitureUtility = require(source.Utility.FurnitureUtility)
local CustomerState = require(source.Enums.Restaurant.Customer.CustomerState)
local Customers = require(playerSource.Systems.Restaurant.Customers)
local taskCompletedRemote = events.Restaurant.TaskCompleted
local autoCollectDishes = false
local autoTakeOrders = false
local autoSeatCustomers = false
local processedTrash = setmetatable({}, { __mode = "k" })
local boundTrash = setmetatable({}, { __mode = "k" })
local boundTables = setmetatable({}, { __mode = "k" })
local reservedTables = setmetatable({}, { __mode = "k" })
local processedOrders = {}
local waitingGroups = {}
local processWaitingGroups
local scanCustomerStates
local seatingBusy = false

local function getCustomerSpeechText(customer)
    for _, speechGui in ipairs(playerGui:GetChildren()) do
        if speechGui:IsA("BillboardGui")
            and speechGui.Name == "CustomerSpeechUI"
            and speechGui.Enabled
            and speechGui.Adornee
            and speechGui.Adornee:IsDescendantOf(customer)
        then
            local header = speechGui:FindFirstChild("Header", true)
            if header then
                return string.lower(header.Text)
            end
        end
    end
    return ""
end

local function isCurrentRestaurantTycoon(tycoon)
    local activeTycoon = findTycoon()
    return tycoon and activeTycoon and tycoon == activeTycoon
end

local function collectDishesFromTrash(trash)
    if not autoCollectDishes
        or not scriptRuntime.Active
        or processedTrash[trash]
        or not trash
        or not trash.Parent
        or trash:GetAttribute("Collectable") ~= true
    then
        return
    end

    local tycoon = findTycoon()
    if not tycoon or not trash:IsDescendantOf(tycoon) then
        return
    end
    local tableModel = trash.Parent
    if not tableModel:IsA("Model") or not FurnitureUtility:IsTable(tableModel.Name) then
        return
    end

    processedTrash[trash] = true
    taskCompletedRemote:FireServer({
        Name = Task.CollectDishes,
        FurnitureModel = tableModel,
        Tycoon = tycoon,
    })
    task.delay(0.75, function()
        if not scriptRuntime.Active or not trash.Parent then
            return
        end
        if trash:GetAttribute("Collectable") == true then
            processedTrash[trash] = nil
            collectDishesFromTrash(trash)
        end
    end)
end

local function bindTrash(trash)
    if boundTrash[trash] or not trash:IsA("Model") or trash.Name ~= "Trash" then
        return
    end
    boundTrash[trash] = true
    trackConnection(trash:GetAttributeChangedSignal("Collectable"):Connect(function()
        if trash:GetAttribute("Collectable") == true then
            collectDishesFromTrash(trash)
        else
            processedTrash[trash] = nil
        end
    end))
    collectDishesFromTrash(trash)
end

local function scanRestaurantTrash()
    local tycoon = findTycoon()
    if not tycoon then
        return
    end
    for _, descendant in ipairs(tycoon:GetDescendants()) do
        if descendant:IsA("Model") and descendant.Name == "Trash" then
            bindTrash(descendant)
        end
    end
end

local function getCustomerGroupFolder(tycoon, groupId)
    local customersFolder = tycoon and tycoon:FindFirstChild("ClientCustomers")
    return customersFolder and customersFolder:FindFirstChild(tostring(groupId))
end

local function getCustomerGroupSize(tycoon, groupId)
    local groupFolder = getCustomerGroupFolder(tycoon, groupId)
    if not groupFolder then
        return 0
    end
    local count = 0
    for _, child in ipairs(groupFolder:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
            count += 1
        end
    end
    return count
end

local function getRestaurantTablesAndCapacities(tycoon)
    local tables = {}
    local chairs = {}
    local items = tycoon and tycoon:FindFirstChild("Items")
    if not items then
        return tables, {}
    end

    for _, model in ipairs(items:GetDescendants()) do
        if model:IsA("Model") and model:GetAttribute("UID") ~= nil then
            if FurnitureUtility:IsTable(model.Name) then
                table.insert(tables, model)
            elseif FurnitureUtility:IsChair(model.Name) then
                table.insert(chairs, model)
            end
        end
    end

    local capacities = {}
    for _, tableModel in ipairs(tables) do
        capacities[tableModel] = 0
    end
    for _, chair in ipairs(chairs) do
        local chairPosition = chair:GetPivot().Position
        local nearestTable
        local nearestDistance
        for _, tableModel in ipairs(tables) do
            local offset = tableModel:GetPivot().Position - chairPosition
            local distance = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
            if not nearestDistance or distance < nearestDistance then
                nearestDistance = distance
                nearestTable = tableModel
            end
        end
        if nearestTable then
            capacities[nearestTable] += 1
        end
    end
    return tables, capacities
end

local function findAvailableTable(tycoon, groupSize)
    local tables, capacities = getRestaurantTablesAndCapacities(tycoon)
    local candidates = {}
    for _, tableModel in ipairs(tables) do
        local capacity = capacities[tableModel] or 0
        if tableModel:GetAttribute("InUse") ~= true
            and not reservedTables[tableModel]
            and capacity >= groupSize
        then
            table.insert(candidates, {
                Model = tableModel,
                Capacity = capacity,
                UID = tonumber(tableModel:GetAttribute("UID")) or math.huge,
            })
        end
    end
    table.sort(candidates, function(a, b)
        if a.Capacity ~= b.Capacity then
            return a.Capacity < b.Capacity
        end
        return a.UID < b.UID
    end)
    return candidates[1] and candidates[1].Model
end

local function queueCustomerGroupForTable(tycoon, groupId)
    if not autoSeatCustomers or not isCurrentRestaurantTycoon(tycoon) or groupId == nil then
        return
    end
    waitingGroups[tostring(groupId)] = {
        Tycoon = tycoon,
        GroupId = groupId,
    }
    task.defer(processWaitingGroups)
end

processWaitingGroups = function()
    if seatingBusy or not autoSeatCustomers or not scriptRuntime.Active then
        return
    end
    seatingBusy = true
    local keys = {}
    for key in pairs(waitingGroups) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local request = waitingGroups[key]
        if request and isCurrentRestaurantTycoon(request.Tycoon) then
            local groupFolder = getCustomerGroupFolder(request.Tycoon, request.GroupId)
            local groupSize = getCustomerGroupSize(request.Tycoon, request.GroupId)
            if not groupFolder or groupSize <= 0 then
                waitingGroups[key] = nil
            else
                local tableModel = findAvailableTable(request.Tycoon, groupSize)
                if tableModel then
                    waitingGroups[key] = nil
                    reservedTables[tableModel] = true
                    taskCompletedRemote:FireServer({
                        Name = Task.SendToTable,
                        GroupId = request.GroupId,
                        FurnitureModel = tableModel,
                        Tycoon = request.Tycoon,
                    })
                    task.delay(1.5, function()
                        if not scriptRuntime.Active or not tableModel.Parent then
                            return
                        end
                        if tableModel:GetAttribute("InUse") ~= true then
                            reservedTables[tableModel] = nil
                            if getCustomerGroupFolder(request.Tycoon, request.GroupId) then
                                queueCustomerGroupForTable(request.Tycoon, request.GroupId)
                            end
                        end
                    end)
                end
            end
        else
            waitingGroups[key] = nil
        end
    end
    seatingBusy = false
end

local function bindRestaurantTable(tableModel)
    if boundTables[tableModel]
        or not tableModel:IsA("Model")
        or not FurnitureUtility:IsTable(tableModel.Name)
    then
        return
    end
    boundTables[tableModel] = true
    trackConnection(tableModel:GetAttributeChangedSignal("InUse"):Connect(function()
        if tableModel:GetAttribute("InUse") == true then
            reservedTables[tableModel] = true
        else
            reservedTables[tableModel] = nil
            task.defer(processWaitingGroups)
        end
    end))
end

local function scanRestaurantTables()
    local tycoon = findTycoon()
    local items = tycoon and tycoon:FindFirstChild("Items")
    if not items then
        return
    end
    for _, descendant in ipairs(items:GetDescendants()) do
        if descendant:IsA("Model") and descendant:GetAttribute("UID") ~= nil
            and FurnitureUtility:IsTable(descendant.Name)
        then
            bindRestaurantTable(descendant)
        end
    end
end

local function takeCustomerOrder(tycoon, groupId, customerId)
    if not autoTakeOrders
        or not isCurrentRestaurantTycoon(tycoon)
        or groupId == nil
        or customerId == nil
    then
        return
    end
    local key = tostring(groupId) .. ":" .. tostring(customerId)
    if processedOrders[key] then
        return
    end
    processedOrders[key] = true
    taskCompletedRemote:FireServer({
        Name = Task.TakeOrder,
        GroupId = groupId,
        CustomerId = customerId,
        Tycoon = tycoon,
    })
    task.delay(0.35, function()
        processedOrders[key] = nil
        if not scriptRuntime.Active or not autoTakeOrders or not isCurrentRestaurantTycoon(tycoon) then
            return
        end
        scanCustomerStates()
    end)
end

scanCustomerStates = function()
    if not autoTakeOrders then
        return
    end
    local tycoon = findTycoon()
    if not tycoon then
        return
    end
    local customersFolder = tycoon:FindFirstChild("ClientCustomers")
    if not customersFolder then
        return
    end
    for _, speechGui in ipairs(playerGui:GetChildren()) do
        if speechGui:IsA("BillboardGui")
            and speechGui.Name == "CustomerSpeechUI"
            and speechGui.Enabled
        then
            local header = speechGui:FindFirstChild("Header", true)
            local adornee = speechGui.Adornee
            local customer = adornee and adornee:FindFirstAncestorWhichIsA("Model")
            local groupFolder = customer and customer.Parent
            local text = header and string.lower(header.Text) or ""
            local prompt = customer and customer:FindFirstChild("CustomerInteractPrompt", true)
            if customer
                and groupFolder
                and groupFolder.Parent == customersFolder
                and text:find("%a")
            then
                if text:find("table for", 1, true) then
                    queueCustomerGroupForTable(tycoon, groupFolder.Name)
                elseif prompt and not text:find("waiting for", 1, true) then
                    takeCustomerOrder(tycoon, groupFolder.Name, customer.Name)
                end
            end
        end
    end
end

local function processCustomerPrompt(prompt)
    if not prompt
        or not prompt.Parent
        or prompt.Name ~= "CustomerInteractPrompt"
        or (not autoTakeOrders and not autoSeatCustomers)
    then
        return
    end
    local tycoon = findTycoon()
    if not tycoon or not prompt:IsDescendantOf(tycoon) then
        return
    end
    local customer = prompt:FindFirstAncestorWhichIsA("Model")
    local groupFolder = customer and customer.Parent
    if not customer or not groupFolder or groupFolder.Parent ~= tycoon:FindFirstChild("ClientCustomers") then
        return
    end
    local groupId = groupFolder.Name
    local customerId = customer.Name
    local speechText = getCustomerSpeechText(customer)
    if speechText == "" then
        task.delay(0.05, processCustomerPrompt, prompt)
        task.delay(0.2, processCustomerPrompt, prompt)
        return
    elseif speechText:find("waiting for", 1, true) then
        return
    elseif not speechText:find("table for", 1, true) then
        takeCustomerOrder(tycoon, groupId, customerId)
    else
        queueCustomerGroupForTable(tycoon, groupId)
    end
end

local function scanCustomerPrompts()
    local tycoon = findTycoon()
    local customersFolder = tycoon and tycoon:FindFirstChild("ClientCustomers")
    if not customersFolder then
        return
    end
    for _, descendant in ipairs(customersFolder:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "CustomerInteractPrompt" then
            task.defer(processCustomerPrompt, descendant)
        end
    end
end

trackConnection(Customers.GroupStateChanged:Connect(function(tycoon, groupId, _oldState, newState)
    local key = tostring(groupId)
    if newState == CustomerState.Entered then
        queueCustomerGroupForTable(tycoon, groupId)
    else
        waitingGroups[key] = nil
    end
end))

trackConnection(Customers.CustomerStateChanged:Connect(function(
    tycoon,
    groupId,
    customerId,
    _oldState,
    newState
)
    local key = tostring(groupId) .. ":" .. tostring(customerId)
    if newState == CustomerState.Ordering then
        takeCustomerOrder(tycoon, groupId, customerId)
    else
        processedOrders[key] = nil
    end
end))

trackConnection(workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") and descendant.Name == "Trash" then
        task.defer(bindTrash, descendant)
    elseif descendant:IsA("ProximityPrompt") and descendant.Name == "CustomerInteractPrompt" then
        task.defer(processCustomerPrompt, descendant)
    elseif descendant:IsA("Model") and descendant:GetAttribute("UID") ~= nil then
        task.defer(bindRestaurantTable, descendant)
    end
end))

trackConnection(playerGui.ChildAdded:Connect(function(child)
    if child:IsA("BillboardGui") and child.Name == "CustomerSpeechUI" then
        task.delay(0.05, scanCustomerStates)
        task.delay(0.25, scanCustomerStates)
        task.delay(0.05, scanCustomerPrompts)
        task.delay(0.25, scanCustomerPrompts)
    end
end))

function autoRestaurantTasks:SetCollectDishes(enabled)
    autoCollectDishes = enabled == true
    scriptRuntime.State.AutoCollectDishes = autoCollectDishes
    if autoCollectDishes then
        scanRestaurantTrash()
    else
        table.clear(processedTrash)
    end
end

function autoRestaurantTasks:SetTakeOrders(enabled)
    autoTakeOrders = enabled == true
    scriptRuntime.State.AutoTakeOrders = autoTakeOrders
    if autoTakeOrders then
        scanCustomerStates()
        scanCustomerPrompts()
    else
        table.clear(processedOrders)
    end
end

function autoRestaurantTasks:SetSeatCustomers(enabled)
    autoSeatCustomers = enabled == true
    scriptRuntime.State.AutoSeatCustomers = autoSeatCustomers
    if autoSeatCustomers then
        scanRestaurantTables()
        scanCustomerPrompts()
        task.defer(processWaitingGroups)
    else
        table.clear(waitingGroups)
        table.clear(reservedTables)
    end
end

function autoRestaurantTasks:Refresh()
    table.clear(processedTrash)
    table.clear(processedOrders)
    table.clear(waitingGroups)
    table.clear(reservedTables)
    scanRestaurantTrash()
    scanRestaurantTables()
    scanCustomerStates()
    scanCustomerPrompts()
end
end

do
local GrabFoodSystem = require(playerSource.Systems.Restaurant.GrabFood)
local ServeFoodTask = require(playerSource.Modules.Tasks.ServeFood)
local UserInputService = game:GetService("UserInputService")
local autoServe = false
local servingBusy = false
local grabInFlight = setmetatable({}, { __mode = "k" })
local retryCounts = setmetatable({}, { __mode = "k" })
local serveRetryQueued = false
local mouseBehaviorBeforeServe
local scanReadyFood
local processHeldFood

local function restoreServeMouse()
    if mouseBehaviorBeforeServe then
        UserInputService.MouseBehavior = mouseBehaviorBeforeServe
    end
end

local function queueServeMouseRestore()
    restoreServeMouse()
    task.defer(restoreServeMouse)
    task.delay(0.05, restoreServeMouse)
    task.delay(0.2, restoreServeMouse)
    task.delay(0.6, restoreServeMouse)
end

local function getServingTycoon()
    local tycoon = findTycoon()
    if tycoon and tycoon:FindFirstChild("Objects") and tycoon.Objects:FindFirstChild("Food") then
        return tycoon
    end
end

local function getHeldFood()
    return type(GrabFoodSystem.Storage) == "table" and GrabFoodSystem.Storage or {}
end

local function findHeldFood(foodModel)
    for _, heldFood in ipairs(getHeldFood()) do
        if heldFood.Model == foodModel then
            return heldFood
        end
    end
end

local function invokeServe(methodName, ...)
    local method = ServeFoodTask[methodName]
    if type(method) ~= "function" then
        return false
    end
    local ok, served = pcall(method, ServeFoodTask, ...)
    return ok and served == true
end

local function serveOneHeldFood(tycoon)
    for _, heldFood in ipairs(getHeldFood()) do
        if heldFood.Tycoon == tycoon then
            if heldFood.TargetPlayerName then
                local targetPlayer = Players:FindFirstChild(heldFood.TargetPlayerName)
                if targetPlayer and invokeServe("CompleteForPlayer", tycoon, targetPlayer) then
                    return true
                end
            elseif heldFood.TargetCarId ~= nil then
                local carId = tostring(heldFood.TargetCarId)
                local carModel = tycoon:FindFirstChild(carId, true) or { Name = carId }
                if invokeServe("CompleteForCar", tycoon, carModel) then
                    return true
                end
            end
        end
    end

    local customersFolder = tycoon:FindFirstChild("ClientCustomers")
    if not customersFolder then
        return false
    end
    for _, groupFolder in ipairs(customersFolder:GetChildren()) do
        for _, customer in ipairs(groupFolder:GetChildren()) do
            if customer:IsA("Model")
                and invokeServe("CompleteForNPC", tycoon, groupFolder.Name, customer.Name)
            then
                return true
            end
        end
    end
    return false
end

local function attemptReadyFoodGrab(foodModel)
    if not autoServe
        or not scriptRuntime.Active
        or not foodModel
        or not foodModel.Parent
        or foodModel:GetAttribute("Taken") == true
        or grabInFlight[foodModel]
    then
        return
    end

    local tycoon = getServingTycoon()
    if not tycoon or not foodModel:IsDescendantOf(tycoon.Objects.Food) then
        return
    end
    if servingBusy or #getHeldFood() > 0 then
        return
    end

    grabInFlight[foodModel] = true
    task.spawn(function()
        local ok = pcall(function()
            GrabFoodSystem:AttemptGrab(tycoon, foodModel)
        end)
        queueServeMouseRestore()
        grabInFlight[foodModel] = nil

        if not scriptRuntime.Active or not autoServe then
            return
        end
        if ok and findHeldFood(foodModel) then
            retryCounts[foodModel] = nil
            task.defer(processHeldFood)
        elseif foodModel.Parent and foodModel:GetAttribute("Taken") ~= true then
            local attempt = (retryCounts[foodModel] or 0) + 1
            retryCounts[foodModel] = attempt
            if attempt <= 6 then
                task.delay(0.2, function()
                    attemptReadyFoodGrab(foodModel)
                end)
            end
        end
    end)
end

scanReadyFood = function()
    if not autoServe or not scriptRuntime.Active then
        return
    end
    local tycoon = getServingTycoon()
    if not tycoon then
        return
    end
    if servingBusy then
        return
    end
    if #getHeldFood() > 0 then
        task.defer(processHeldFood)
        return
    end

    for _, foodModel in ipairs(tycoon.Objects.Food:GetChildren()) do
        if foodModel:IsA("Model")
            and foodModel:GetAttribute("Taken") ~= true
            and not grabInFlight[foodModel]
        then
            attemptReadyFoodGrab(foodModel)
            break
        end
    end
end

processHeldFood = function()
    if servingBusy or not autoServe or not scriptRuntime.Active then
        return
    end
    local tycoon = getServingTycoon()
    if not tycoon then
        return
    end

    if #getHeldFood() == 0 then
        scanReadyFood()
        return
    end

    if serveOneHeldFood(tycoon) then
        servingBusy = true
        queueServeMouseRestore()
        task.delay(0.35, function()
            if not scriptRuntime.Active then
                return
            end
            servingBusy = false
            processHeldFood()
            scanReadyFood()
        end)
    elseif not serveRetryQueued then
        -- Keep the held dish in place. A customer or drive-through recipient
        -- may still be transitioning into the deliverable state; cancelling
        -- and re-grabbing here is what caused the visible dish shuffling.
        serveRetryQueued = true
        task.delay(0.5, function()
            serveRetryQueued = false
            if scriptRuntime.Active and autoServe then
                processHeldFood()
            end
        end)
    end
end

trackConnection(CollectionService:GetInstanceAddedSignal("Food"):Connect(function(foodModel)
    if autoServe then
        task.defer(attemptReadyFoodGrab, foodModel)
    end
end))

trackConnection(playerGui.ChildAdded:Connect(function(child)
    if autoServe and child:IsA("BillboardGui") and child.Name == "CustomerSpeechUI" then
        task.delay(0.05, processHeldFood)
        task.delay(0.25, processHeldFood)
    end
end))

trackConnection(events.Restaurant.GrabEnded.OnClientEvent:Connect(function(foodModel)
    if autoServe then
        servingBusy = false
        queueServeMouseRestore()
        task.defer(processHeldFood)
        task.defer(scanReadyFood)
    end
end))

if GrabFoodSystem.GrabbedFoodUpdated and type(GrabFoodSystem.GrabbedFoodUpdated.Connect) == "function" then
    trackConnection(GrabFoodSystem.GrabbedFoodUpdated:Connect(function()
        if autoServe then
            servingBusy = false
            task.defer(processHeldFood)
            task.defer(scanReadyFood)
        end
    end))
end

function autoRestaurantTasks:SetAutoServe(enabled)
    if enabled and not autoServe then
        mouseBehaviorBeforeServe = UserInputService.MouseBehavior
    end
    autoServe = enabled == true
    scriptRuntime.State.AutoServe = autoServe
    servingBusy = false
    serveRetryQueued = false
    if not autoServe and mouseBehaviorBeforeServe then
        UserInputService.MouseBehavior = mouseBehaviorBeforeServe
        mouseBehaviorBeforeServe = nil
    end
    table.clear(grabInFlight)
    table.clear(retryCounts)
    if autoServe then
        processHeldFood()
        scanReadyFood()
    end
end

local previousRefresh = autoRestaurantTasks.Refresh
function autoRestaurantTasks:Refresh()
    previousRefresh(self)
    servingBusy = false
    serveRetryQueued = false
    table.clear(grabInFlight)
    table.clear(retryCounts)
    if autoServe then
        processHeldFood()
        scanReadyFood()
    end
end

table.insert(scriptRuntime.CleanupCallbacks, function()
    autoServe = false
    servingBusy = false
    serveRetryQueued = false
    table.clear(grabInFlight)
    table.clear(retryCounts)
    if mouseBehaviorBeforeServe then
        UserInputService.MouseBehavior = mouseBehaviorBeforeServe
    end
end)
end

do
local CookReplication = require(source.Enums.Cook.CookReplication)
local WorkerReplication = require(source.Enums.Restaurant.Workers.WorkerReplication)
local Workers = require(playerSource.Systems.Restaurant.Workers)
local ControlsUtility = require(source.Utility.Input.ControlsUtility)
local CookUtility = require(source.Utility.Cook.CookUtility)
local CookSystem = require(playerSource.Systems.Cook)
local CookingCamera = require(playerSource.Systems.Cook.CookingCamera)
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local cookInputRemote = events.Cook.CookInputRequested
local chefCookInputRemote = events.Cook.ChefCookInputRequested
local cookUpdatedRemote = events.Cook.CookUpdated
local workerActionRemote = events.Restaurant.Workers.WorkerActionReplicated
local autoCook = false
local nativeCookConnections = {}
local playerCookActionQueued = false
local workerActionsQueued = {}
local autoStartBusy = false
local movementReleaseElapsed = 0
local normalWalkSpeed = 16
local mouseUnlockPending = false
local nativeCookMethods = {
    LockCharacterToModel = CookUtility.LockCharacterToModel,
    FaceCharacterToModel = CookUtility.FaceCharacterToModel,
    PlayerDirectedToEquipment = CookSystem.OnPlayerDirectedToEquipment,
    InteractionUpdated = CookSystem.OnInteractionUpdated,
}
local cookOverrides = {}

cookOverrides.LockCharacterToModel = function(self, worker, kitchenModel)
    if autoCook and worker == localPlayer then
        return
    end
    return nativeCookMethods.LockCharacterToModel(self, worker, kitchenModel)
end

cookOverrides.FaceCharacterToModel = function(self, worker, kitchenModel)
    if autoCook and worker == localPlayer then
        return
    end
    return nativeCookMethods.FaceCharacterToModel(self, worker, kitchenModel)
end

CookUtility.LockCharacterToModel = cookOverrides.LockCharacterToModel
CookUtility.FaceCharacterToModel = cookOverrides.FaceCharacterToModel

-- The native interaction handlers create the cooking UI, tween the player to
-- each workstation, anchor the root, and bind minigame input. Auto Cook sends
-- the corresponding Interact/CompleteTask requests itself, so keep only the
-- server-side progression while it is enabled.
CookSystem.OnPlayerDirectedToEquipment = function(self, kitchenModel, itemType, ...)
    if autoCook then
        self.CurrentKitchenModel = kitchenModel
        self.CurrentItemType = itemType
        return
    end
    return nativeCookMethods.PlayerDirectedToEquipment(self, kitchenModel, itemType, ...)
end

CookSystem.OnInteractionUpdated = function(self, ...)
    if autoCook then
        return
    end
    return nativeCookMethods.InteractionUpdated(self, ...)
end

-- A previous execution may have ended while the server still considered the
-- local player to be cooking. Cancel that stale session before any automation
-- can receive another equipment update and re-anchor or move the avatar.
pcall(function()
    if CookSystem:PlayerIsCooking() then
        CookSystem:RequestCancelCooking()
    end
end)

if type(getconnections) == "function" then
    local ok, connections = pcall(getconnections, cookUpdatedRemote.OnClientEvent)
    if ok and type(connections) == "table" then
        nativeCookConnections = connections
    end
end

local function setNativeCookControllerEnabled(enabled)
    for _, connection in ipairs(nativeCookConnections) do
        pcall(function()
            if enabled and type(connection.Enable) == "function" then
                connection:Enable()
            elseif not enabled and type(connection.Disable) == "function" then
                connection:Disable()
            end
        end)
    end
end

local function resetCookingMouseLock()
    if mouseUnlockPending then
        return
    end
    mouseUnlockPending = true
    local userGameSettings = UserSettings():GetService("UserGameSettings")
    pcall(function()
        userGameSettings.ControlMode = Enum.ControlMode.Classic
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    task.delay(0.1, function()
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        mouseUnlockPending = false
    end)
end

local function releasePlayerFromCooking(forceMouseUnlock)
    local character = localPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.WalkSpeed > 0 then
        normalWalkSpeed = humanoid.WalkSpeed
    end
    pcall(function()
        ControlsUtility:Enable()
    end)
    pcall(function()
        require(localPlayer.PlayerScripts.PlayerModule):GetControls():Enable()
    end)
    pcall(function()
        CookingCamera:Unlock()
    end)
    for _, actionName in ipairs({
        "MultiClick",
        "DirectionalPress",
        "MouseMovement",
        "MouseHold",
        "MouseSpin",
        "DeepFry",
    }) do
        pcall(function()
            ContextActionService:UnbindAction(actionName)
        end)
    end
    if rootPart then
        rootPart.Anchored = false
    end
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid.EvaluateStateMachine = true
        if humanoid.WalkSpeed <= 0 then
            humanoid.WalkSpeed = normalWalkSpeed
        end
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    if forceMouseUnlock or autoStartBusy then
        local wasMouseLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        if wasMouseLocked then
            resetCookingMouseLock()
        end
        local focusedTextBox = UserInputService:GetFocusedTextBox()
        if focusedTextBox then
            pcall(function()
                focusedTextBox:ReleaseFocus()
            end)
        end
        local camera = workspace.CurrentCamera
        if camera and humanoid then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end
        for _, path in ipairs({
            { "Cooking", "Frame", "CancelButton" },
            { "ScreenWidgets", "DeliveryCancel" },
        }) do
            local object = localPlayer:FindFirstChild("PlayerGui")
            for _, name in ipairs(path) do
                object = object and object:FindFirstChild(name)
            end
            if object and object:IsA("GuiButton") then
                object.Modal = false
            end
        end
    end
end

local function queueMovementRelease(forceMouseUnlock)
    local function release()
        releasePlayerFromCooking(forceMouseUnlock)
    end
    release()
    task.defer(release)
    task.delay(0.05, release)
    task.delay(0.2, release)
    task.delay(0.6, release)
    task.delay(1, release)
end

local function queuePlayerCookAction(action, ...)
    if not autoCook or playerCookActionQueued then
        return
    end
    local arguments = table.pack(...)
    playerCookActionQueued = true
    task.defer(function()
        playerCookActionQueued = false
        if not scriptRuntime.Active or not autoCook then
            return
        end
        cookInputRemote:FireServer(action, table.unpack(arguments, 1, arguments.n))
        releasePlayerFromCooking()
    end)
end

local function onPlayerCookUpdated(replicationType, ...)
    if not autoCook then
        return
    end
    local arguments = table.pack(...)
    if replicationType == CookReplication.Start then
        autoStartBusy = true
    elseif replicationType == CookReplication.DirectToEquipment then
        local kitchenModel = arguments[1]
        local itemType = arguments[2]
        if kitchenModel and itemType then
            queuePlayerCookAction(CookReplication.Interact, kitchenModel, itemType)
        end
    elseif replicationType == CookReplication.UpdateInteraction then
        local kitchenModel = arguments[2]
        local itemType = arguments[3]
        local interactionActive = arguments[4]
        if interactionActive and kitchenModel and itemType then
            queuePlayerCookAction(CookReplication.CompleteTask, kitchenModel, itemType)
        end
    elseif replicationType == CookReplication.Finish then
        autoStartBusy = false
    end
    queueMovementRelease(replicationType == CookReplication.Finish)
end

local function queueWorkerCookAction(workerType, workerName, action)
    if not workerType or not workerName or not autoCook then
        return
    end
    local key = tostring(workerType) .. ":" .. tostring(workerName) .. ":" .. tostring(action)
    if workerActionsQueued[key] then
        return
    end
    workerActionsQueued[key] = true
    task.defer(function()
        workerActionsQueued[key] = nil
        if scriptRuntime.Active and autoCook then
            chefCookInputRemote:FireServer(action, workerType, workerName)
        end
    end)
end

local function onWorkerActionReplicated(tycoon, workerAction, workerName, replicationType, ...)
    if not autoCook or workerAction ~= WorkerReplication.Cook then
        return
    end
    local activeTycoon = findTycoon()
    if not activeTycoon or tycoon ~= activeTycoon then
        return
    end
    local worker = Workers:GetClientWorkerByName(tycoon, workerName)
    local workerType = worker and worker.WorkerType
    if replicationType == CookReplication.DirectToEquipment then
        queueWorkerCookAction(workerType, workerName, CookReplication.Interact)
    elseif replicationType == CookReplication.UpdateInteraction then
        local arguments = table.pack(...)
        local interactionActive = arguments[3]
        if interactionActive ~= false then
            queueWorkerCookAction(workerType, workerName, CookReplication.CompleteTask)
        end
    end
end

trackConnection(cookUpdatedRemote.OnClientEvent:Connect(onPlayerCookUpdated))
trackConnection(workerActionRemote.OnClientEvent:Connect(onWorkerActionReplicated))
releasePlayerFromCooking()
trackConnection(RunService.Heartbeat:Connect(function(deltaTime)
    if not autoCook then
        return
    end
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if rootPart and rootPart.Anchored then
        rootPart.Anchored = false
    end
    if humanoid then
        humanoid.AutoRotate = true
        humanoid.PlatformStand = false
    end
    movementReleaseElapsed += deltaTime
    if movementReleaseElapsed >= 0.25 then
        movementReleaseElapsed = 0
        releasePlayerFromCooking()
    end
end))

function autoRestaurantTasks:SetAutoCook(enabled)
    local wasEnabled = autoCook
    autoCook = enabled == true
    scriptRuntime.State.AutoCook = autoCook
    table.clear(workerActionsQueued)
    playerCookActionQueued = false
    autoStartBusy = false
    movementReleaseElapsed = 0
    setNativeCookControllerEnabled(not autoCook)
    if autoCook then
        queueMovementRelease()
    else
        if wasEnabled or CookSystem:PlayerIsCooking() then
            pcall(function()
                CookSystem:RequestCancelCooking()
            end)
        end
        queueMovementRelease(true)
    end
end

local previousRefresh = autoRestaurantTasks.Refresh
function autoRestaurantTasks:Refresh()
    previousRefresh(self)
    table.clear(workerActionsQueued)
    playerCookActionQueued = false
    autoStartBusy = false
    if autoCook then
        setNativeCookControllerEnabled(false)
        queueMovementRelease()
    end
end

table.insert(scriptRuntime.CleanupCallbacks, function()
    if autoCook or CookSystem:PlayerIsCooking() then
        pcall(function()
            CookSystem:RequestCancelCooking()
        end)
    end
    autoCook = false
    table.clear(workerActionsQueued)
    setNativeCookControllerEnabled(true)
    queueMovementRelease(true)
    if CookUtility.LockCharacterToModel == cookOverrides.LockCharacterToModel then
        CookUtility.LockCharacterToModel = nativeCookMethods.LockCharacterToModel
    end
    if CookUtility.FaceCharacterToModel == cookOverrides.FaceCharacterToModel then
        CookUtility.FaceCharacterToModel = nativeCookMethods.FaceCharacterToModel
    end
    CookSystem.OnPlayerDirectedToEquipment = nativeCookMethods.PlayerDirectedToEquipment
    CookSystem.OnInteractionUpdated = nativeCookMethods.InteractionUpdated
end)
end

local function tableHas(dictionary, key)
    return dictionary[key] == true
        or dictionary[tostring(key)] == true
        or dictionary[tonumber(key)] == true
end

local function getDictionarySignature(dictionary)
    local keys = {}
    for key, value in pairs(dictionary) do
        if value == true then
            table.insert(keys, tostring(key))
        end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function getFoodInfo(foodKey)
    return FoodData[foodKey] or FoodData[tonumber(foodKey)] or FoodData[tostring(foodKey)]
end

local function getFoodName(foodKey)
    local food = getFoodInfo(foodKey)
    if food and food.Name then
        return food.Name
    end

    local ok, name = pcall(function()
        return FoodUtility:GetName(foodKey)
    end)
    return ok and name or ("Dish " .. tostring(foodKey))
end

local function getRequirements(foodKey)
    local ok, requirements = pcall(function()
        return FoodUtility:GetIngredients(foodKey)
    end)
    if ok and type(requirements) == "table" then
        return requirements
    end

    local food = getFoodInfo(foodKey)
    return food and food.Ingredients or {}
end

local function getCash()
    local cash = localPlayer:FindFirstChild("Cash")
    return cash and tonumber(cash.Value) or 0
end

local function formatMoney(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(value)
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return "$" .. formatted:gsub("^,", "")
end

local function rebuildLimitedStock()
    local restockId = math.floor(workspace:GetServerTimeNow() / 1200)
    if restockId == currentRestockId then
        return false
    end

    currentRestockId = restockId
    forcedStockAll = false
    limitedStock = {}

    local names = {}
    for ingredientName, data in pairs(IngredientData) do
        local interiors = type(data) == "table" and data.Interiors or nil
        if type(interiors) == "table"
            and (table.find(interiors, Interior.FarmShop) or table.find(interiors, Interior.Bakery)) then
            table.insert(names, ingredientName)
        end
    end
    table.sort(names)

    local random = Random.new(restockId)
    for _, ingredientName in ipairs(names) do
        local availability = tonumber(IngredientData[ingredientName].Availability) or 0
        limitedStock[ingredientName] = random:NextNumber() < availability
    end

    return true
end

local function isInteriorStocked(ingredientName, interiorName)
    if not LIMITED_INTERIORS[interiorName] then
        return true
    end
    if forcedStockAll then
        return true
    end
    return limitedStock[ingredientName] == true
end

local function findBestShop(ingredientName)
    local data = IngredientData[ingredientName]
    local interiors = data and data.Interiors
    if type(interiors) ~= "table" or #interiors == 0 or data.Enabled == false then
        return nil, nil, "not sold in an ingredient shop"
    end

    local bestInterior
    local bestPrice
    local hasStockedInterior = false

    for _, interiorName in ipairs(interiors) do
        if isInteriorStocked(ingredientName, interiorName) then
            hasStockedInterior = true
            local ok, price = pcall(function()
                return FoodUtility:GetIngredientPrice(ingredientName, interiorName)
            end)
            price = ok and tonumber(price) or tonumber(data.Price)
            if price and (not bestPrice or price < bestPrice) then
                bestInterior = interiorName
                bestPrice = price
            end
        end
    end

    if not hasStockedInterior then
        return nil, nil, "out of stock until the next restock"
    end
    if not bestInterior or not bestPrice then
        return nil, nil, "has no valid shop price"
    end

    return bestInterior, bestPrice
end

local function getDishState(foodKey)
    local requirements = getRequirements(foodKey)
    local missing = {}
    local ingredientParts = {}
    local totalCost = 0
    local unavailableReason
    local complete = true

    for ingredientName, requiredValue in pairs(requirements) do
        local required = math.max(0, tonumber(requiredValue) or 0)
        local owned = math.max(0, tonumber(ingredientOwnership[ingredientName]) or 0)
        local clampedOwned = math.min(owned, required)
        table.insert(ingredientParts, {
            Name = ingredientName,
            Text = string.format("%s %d/%d", ingredientName, clampedOwned, required),
        })

        if owned < required then
            complete = false
            local amount = required - owned
            local interiorName, price, reason = findBestShop(ingredientName)
            if not interiorName then
                unavailableReason = unavailableReason or (ingredientName .. " " .. reason)
            else
                totalCost = totalCost + price * amount
                table.insert(missing, {
                    Name = ingredientName,
                    Amount = amount,
                    Interior = interiorName,
                    UnitPrice = price,
                })
            end
        end
    end

    table.sort(ingredientParts, function(a, b)
        return a.Name < b.Name
    end)
    table.sort(missing, function(a, b)
        if a.UnitPrice == b.UnitPrice then
            return a.Name < b.Name
        end
        return a.UnitPrice < b.UnitPrice
    end)

    if not ingredientInventoryReady and next(requirements) ~= nil then
        return {
            Kind = "Red",
            Ingredients = ingredientParts,
            Missing = missing,
            Cost = totalCost,
            Detail = "Ingredient inventory not synced; press Refresh to read your fridge",
        }
    end

    if complete then
        return {
            Kind = "Green",
            Ingredients = ingredientParts,
            Missing = {},
            Cost = 0,
            Detail = "Ready - click to boost",
        }
    end

    if unavailableReason then
        return {
            Kind = "Red",
            Ingredients = ingredientParts,
            Missing = missing,
            Cost = totalCost,
            Detail = unavailableReason,
        }
    end

    if getCash() < totalCost then
        return {
            Kind = "Red",
            Ingredients = ingredientParts,
            Missing = missing,
            Cost = totalCost,
            Detail = string.format("Need %s; you have %s", formatMoney(totalCost), formatMoney(getCash())),
        }
    end

    return {
        Kind = "Yellow",
        Ingredients = ingredientParts,
        Missing = missing,
        Cost = totalCost,
        Detail = formatMoney(totalCost) .. " - click to buy missing ingredients",
    }
end

local function refreshListCanvas()
    if listFrame and listLayout then
        listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
    end
end

local function getIngredientSummary(state)
    local parts = {}
    for _, ingredient in ipairs(state.Ingredients) do
        table.insert(parts, ingredient.Text)
    end
    if #parts == 0 then
        return "No ingredients required"
    end
    return table.concat(parts, "  |  ")
end

local function updateRow(foodKey)
    local row = rowControls[foodKey]
    if not row then
        return
    end

    local state = getDishState(foodKey)
    local accent = COLORS[state.Kind]
    row.State = state
    row.Button.BackgroundColor3 = COLORS.Surface:Lerp(accent, 0.16)
    row.Stroke.Color = accent
    row.Status.TextColor3 = accent
    row.Status.Text = state.Detail
    row.Ingredients.Text = getIngredientSummary(state)
end

local STATE_SORT_ORDER = {
    Green = 1,
    Yellow = 2,
    Red = 3,
}

local function sortDishRowsByState()
    local visibleRows = {}
    for foodKey, row in pairs(rowControls) do
        if row.Button.Visible then
            table.insert(visibleRows, {
                Key = tostring(foodKey),
                Name = row.FoodName or getFoodName(foodKey),
                Row = row,
                Rank = STATE_SORT_ORDER[row.State and row.State.Kind] or 99,
            })
        end
    end

    table.sort(visibleRows, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank < b.Rank
        end
        if a.Name ~= b.Name then
            return a.Name < b.Name
        end
        return a.Key < b.Key
    end)

    for index, entry in ipairs(visibleRows) do
        entry.Row.Button.LayoutOrder = index
    end
end

local function updateAllRows()
    rebuildLimitedStock()
    for foodKey in pairs(rowControls) do
        updateRow(foodKey)
    end
    sortDishRowsByState()
    if updateAllStandRows then
        updateAllStandRows()
    end
end

local refreshServerMenu
local queueIngredientScan
local queueMenuManagement

local function setStandStatus(text, color)
    scriptRuntime.State.StandStatus = text
    if standStatusLabel then
        standStatusLabel.Text = text
        standStatusLabel.TextColor3 = color or COLORS.Muted
    end
end

local function getActiveStandTypes()
    local active = {}
    currentTycoon = currentTycoon or findTycoon()
    if currentTycoon then
        for _, descendant in ipairs(currentTycoon:GetDescendants()) do
            if descendant:HasTag("FoodStandPrompt") then
                local dishType = descendant:GetAttribute("CustomDishType")
                if dishType and CustomDishData[dishType] then
                    active[tostring(dishType)] = true
                end
            end
        end
    end
    return active
end

local function getToppingRowKey(dishType, toppingName)
    return tostring(dishType) .. "|" .. tostring(toppingName)
end

local function markToppingUnlocked(dishType, toppingName, persist)
    local rowKey = getToppingRowKey(dishType, toppingName)
    knownUnlockedToppings[rowKey] = true
    if persist and type(SetConfigValue) == "function" then
        SetConfigValue(STAND_OWNERSHIP_CONFIG_TAB, rowKey, true)
    end
end

local function mergeUnlockedToppings(dishType, ownership)
    if type(ownership) ~= "table" then
        return
    end
    for toppingName, unlocked in pairs(ownership) do
        if unlocked == true then
            markToppingUnlocked(dishType, toppingName, false)
        end
    end
end

local function refreshKnownToppingOwnership()
    currentTycoon = currentTycoon or findTycoon()
    if not currentTycoon then
        return
    end
    for dishType in pairs(CustomDishData) do
        local ok, ownership = pcall(function()
            return CustomDishMenu:GetUnlockedToppings(currentTycoon, dishType)
        end)
        if ok then
            mergeUnlockedToppings(dishType, ownership)
        end
    end
end

local function getComboRowKey(dishType, comboName)
    return "Combo|" .. tostring(dishType) .. "|" .. tostring(comboName)
end

local function markComboUnlocked(dishType, comboName, persist)
    local rowKey = getComboRowKey(dishType, comboName)
    knownUnlockedCombos[rowKey] = true
    if persist and type(SetConfigValue) == "function" then
        SetConfigValue(STAND_COMBO_CONFIG_TAB, rowKey, true)
    end
end

local function mergeUnlockedCombos(ownership)
    if type(ownership) ~= "table" then
        return
    end
    for dishType, combos in pairs(ownership) do
        if type(combos) == "table" then
            for comboName, unlocked in pairs(combos) do
                if unlocked ~= nil and unlocked ~= false then
                    markComboUnlocked(dishType, comboName, false)
                end
            end
        end
    end
end

local function refreshKnownComboOwnership()
    local ok, ownership = pcall(function()
        return CustomDishCombos:Get()
    end)
    if ok then
        mergeUnlockedCombos(ownership)
    end
end

local function comboIsUnlocked(dishType, comboName)
    local rowKey = getComboRowKey(dishType, comboName)
    if knownUnlockedCombos[rowKey]
        or (type(GetConfigValue) == "function"
            and GetConfigValue(STAND_COMBO_CONFIG_TAB, rowKey) == true)
    then
        knownUnlockedCombos[rowKey] = true
        return true
    end

    local ok, unlocked = pcall(function()
        return CustomDishCombos:Has(dishType, comboName)
    end)
    if ok and unlocked then
        markComboUnlocked(dishType, comboName, false)
        return true
    end
    return false
end

local function toppingIsUnlocked(dishType, toppingName)
    local rowKey = getToppingRowKey(dishType, toppingName)
    if knownUnlockedToppings[rowKey]
        or (type(GetConfigValue) == "function"
            and GetConfigValue(STAND_OWNERSHIP_CONFIG_TAB, rowKey) == true)
    then
        knownUnlockedToppings[rowKey] = true
        return true
    end

    currentTycoon = currentTycoon or findTycoon()
    if not currentTycoon then
        return false
    end
    local ok, unlocked = pcall(function()
        return CustomDishMenu:ToppingIsUnlocked(currentTycoon, dishType, toppingName)
    end)
    if ok and unlocked == true then
        markToppingUnlocked(dishType, toppingName, false)
        return true
    end
    return false
end

local function getToppingState(dishType, toppingName)
    local settings = CustomDishData[dishType]
    local topping = settings and settings.DataModule and settings.DataModule[toppingName]
    if not topping then
        return {
            Kind = "Red",
            Ingredients = {},
            Missing = {},
            Cost = 0,
            Detail = "Topping data is unavailable",
        }
    end

    local ingredientName = topping.IngredientRequired
    local required = math.max(0, tonumber(topping.AmountRequired) or 0)
    local owned = math.max(0, tonumber(ingredientOwnership[ingredientName]) or 0)
    local ingredientData = ingredientName and IngredientData[ingredientName]
    local displayName = ingredientData and ingredientData.DisplayName or tostring(ingredientName or "Unknown")
    local ingredients = {{
        Name = ingredientName,
        Text = string.format("%s %d/%d", displayName, math.min(owned, required), required),
    }}

    if not ingredientName or required <= 0 then
        return {
            Kind = "Red",
            Ingredients = ingredients,
            Missing = {},
            Cost = 0,
            Detail = "This topping has no ingredient unlock cost",
        }
    end

    if not ingredientInventoryReady then
        return {
            Kind = "Red",
            Ingredients = ingredients,
            Missing = {},
            Cost = 0,
            Detail = "Ingredient inventory not synced; press Refresh",
        }
    end

    if owned >= required then
        return {
            Kind = "Green",
            Ingredients = ingredients,
            Missing = {},
            Cost = 0,
            Detail = "Ready - click to unlock",
        }
    end

    local amount = required - owned
    local interiorName, unitPrice, reason = findBestShop(ingredientName)
    if not interiorName then
        return {
            Kind = "Red",
            Ingredients = ingredients,
            Missing = {},
            Cost = 0,
            Detail = displayName .. " " .. tostring(reason),
        }
    end

    local cost = unitPrice * amount
    local missing = {{
        Name = ingredientName,
        Amount = amount,
        Interior = interiorName,
        UnitPrice = unitPrice,
    }}
    if getCash() < cost then
        return {
            Kind = "Red",
            Ingredients = ingredients,
            Missing = missing,
            Cost = cost,
            Detail = string.format("Need %s; you have %s", formatMoney(cost), formatMoney(getCash())),
        }
    end

    return {
        Kind = "Yellow",
        Ingredients = ingredients,
        Missing = missing,
        Cost = cost,
        Detail = formatMoney(cost) .. " - click to buy missing ingredients",
    }
end

local function getComboState(dishType, comboName)
    local combo = CustomDishComboData[dishType] and CustomDishComboData[dishType][comboName]
    if not combo then
        return {
            Kind = "Red",
            Ingredients = {},
            Missing = {},
            Cost = 0,
            Detail = "Combo recipe data is unavailable",
        }
    end

    local requirements = {}
    local missingNames = {}
    for toppingName, amount in pairs(combo.Toppings or {}) do
        local toppingData = CustomDishData[dishType]
            and CustomDishData[dishType].DataModule
            and CustomDishData[dishType].DataModule[toppingName]
        local displayName = toppingData and toppingData.DisplayName or tostring(toppingName)
        local owned = toppingIsUnlocked(dishType, toppingName)
        table.insert(requirements, {
            Name = displayName,
            Text = string.format("%s %dx %s", owned and "Owned" or "Missing", amount, displayName),
        })
        if not owned then
            table.insert(missingNames, displayName)
        end
    end
    table.sort(requirements, function(a, b)
        return a.Name < b.Name
    end)
    table.sort(missingNames)

    if #missingNames == 0 then
        return {
            Kind = "Green",
            Ingredients = requirements,
            Missing = {},
            Cost = 0,
            Detail = "All toppings owned - click to unlock combo",
        }
    end

    return {
        Kind = "Red",
        Ingredients = requirements,
        Missing = missingNames,
        Cost = 0,
        Detail = "Missing toppings: " .. table.concat(missingNames, ", "),
    }
end

local function updateStandRow(rowKey)
    local row = standRowControls[rowKey]
    if not row then
        return
    end
    local state
    if row.EntryType == "Combo" then
        state = getComboState(row.DishType, row.ComboName)
    else
        state = getToppingState(row.DishType, row.ToppingName)
    end
    local accent = COLORS[state.Kind]
    row.State = state
    row.Button.BackgroundColor3 = COLORS.Surface:Lerp(accent, 0.16)
    row.Stroke.Color = accent
    row.Status.TextColor3 = accent
    row.Status.Text = state.Detail
    row.Ingredients.Text = getIngredientSummary(state)
end

local function sortStandRowsByState()
    local visibleRows = {}
    for rowKey, row in pairs(standRowControls) do
        if row.Button.Visible then
            table.insert(visibleRows, {
                Key = rowKey,
                Name = row.DisplayName,
                Row = row,
                Rank = STATE_SORT_ORDER[row.State and row.State.Kind] or 99,
            })
        end
    end
    table.sort(visibleRows, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank < b.Rank
        end
        if a.Name ~= b.Name then
            return a.Name < b.Name
        end
        return a.Key < b.Key
    end)
    for index, entry in ipairs(visibleRows) do
        entry.Row.Button.LayoutOrder = index
    end
end

updateAllStandRows = function()
    for rowKey, row in pairs(standRowControls) do
        if row.Button.Visible then
            updateStandRow(rowKey)
        end
    end
    sortStandRowsByState()
end

local function handleToppingClick(rowKey)
    if standActionBusy[rowKey] or not scriptRuntime.Active then
        return
    end
    local row = standRowControls[rowKey]
    if not row then
        return
    end
    local state = row.State
    if not state then
        state = row.EntryType == "Combo"
            and getComboState(row.DishType, row.ComboName)
            or getToppingState(row.DishType, row.ToppingName)
    end
    if state.Kind == "Red" then
        if row.EntryType ~= "Combo" and not ingredientInventoryReady and queueIngredientScan then
            queueIngredientScan(true)
        else
            setStandStatus(row.DisplayName .. ": " .. state.Detail, COLORS.Red)
        end
        return
    end

    currentTycoon = findTycoon()
    if not currentTycoon then
        setStandStatus("Load your restaurant before using Stand", COLORS.Red)
        return
    end

    standActionBusy[rowKey] = true
    if state.Kind == "Green" then
        setStandStatus("Unlocking " .. row.DisplayName .. "...", COLORS.Green)
        local sent = pcall(function()
            if row.EntryType == "Combo" then
                comboUnlockRemote:FireServer(row.DishType, row.ComboName)
            else
                toppingPurchasedRemote:FireServer(currentTycoon, row.DishType, row.ToppingName)
            end
        end)
        if sent then
            if row.EntryType == "Combo" then
                markComboUnlocked(row.DishType, row.ComboName, true)
            else
                markToppingUnlocked(row.DishType, row.ToppingName, true)
            end
            rebuildStandRows()
        else
            setStandStatus("Could not send the unlock request", COLORS.Red)
        end
        task.delay(1.1, rebuildStandRows)
    else
        setStandStatus("Buying ingredients for " .. row.DisplayName .. "...", COLORS.Yellow)
        for _, ingredient in ipairs(state.Missing) do
            for _ = 1, ingredient.Amount do
                purchaseIngredientRemote:FireServer(currentTycoon, ingredient.Name, ingredient.Interior)
            end
        end
        task.delay(0.35, updateAllStandRows)
        task.delay(1.1, updateAllStandRows)
    end
    task.delay(0.3, function()
        standActionBusy[rowKey] = nil
    end)
end

local function createStandRow(entry)
    local button = Instance.new("TextButton")
    button.Name = entry.EntryType .. "_" .. entry.DishType .. "_"
        .. tostring(entry.ToppingName or entry.ComboName)
    button.Size = UDim2.new(1, -8, 0, 88)
    button.BackgroundColor3 = COLORS.Surface
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.25
    stroke.Parent = button

    local icon = Instance.new("ImageLabel")
    icon.Name = "ToppingIcon"
    icon.Size = UDim2.fromOffset(64, 64)
    icon.Position = UDim2.fromOffset(10, 12)
    icon.BackgroundColor3 = Color3.fromRGB(29, 30, 36)
    icon.BorderSizePixel = 0
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = entry.Image or entry.Data.Image or ""
    icon.Parent = button
    Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 7)
    if entry.EntryType == "Combo" then
        local comboBadge = Instance.new("TextLabel")
        comboBadge.Name = "ComboBadge"
        comboBadge.Size = UDim2.new(1, 0, 0, 18)
        comboBadge.Position = UDim2.new(0, 0, 1, -18)
        comboBadge.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
        comboBadge.BackgroundTransparency = 0.12
        comboBadge.BorderSizePixel = 0
        comboBadge.Text = "COMBO"
        comboBadge.TextColor3 = Color3.new(1, 1, 1)
        comboBadge.TextSize = 10
        comboBadge.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
        comboBadge.Parent = icon
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ToppingName"
    nameLabel.Size = UDim2.new(1, -98, 0, 23)
    nameLabel.Position = UDim2.fromOffset(86, 7)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = entry.DisplayName
    nameLabel.TextColor3 = COLORS.Text
    nameLabel.TextSize = 16
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
    nameLabel.Parent = button

    local ingredientsLabel = Instance.new("TextLabel")
    ingredientsLabel.Name = "Ingredients"
    ingredientsLabel.Size = UDim2.new(1, -98, 0, 32)
    ingredientsLabel.Position = UDim2.fromOffset(86, 29)
    ingredientsLabel.BackgroundTransparency = 1
    ingredientsLabel.Text = "Loading ingredient..."
    ingredientsLabel.TextColor3 = COLORS.Muted
    ingredientsLabel.TextSize = 12
    ingredientsLabel.TextWrapped = true
    ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
    ingredientsLabel.TextYAlignment = Enum.TextYAlignment.Top
    ingredientsLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
    ingredientsLabel.Parent = button

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -98, 0, 20)
    status.Position = UDim2.fromOffset(86, 64)
    status.BackgroundTransparency = 1
    status.Text = "Checking..."
    status.TextColor3 = COLORS.Muted
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
    status.Parent = button

    standRowControls[entry.Key] = {
        Button = button,
        Stroke = stroke,
        Ingredients = ingredientsLabel,
        Status = status,
        EntryType = entry.EntryType,
        DishType = entry.DishType,
        ToppingName = entry.ToppingName,
        ComboName = entry.ComboName,
        DisplayName = entry.DisplayName,
    }
    button.Parent = standListFrame
    trackConnection(button.MouseButton1Click:Connect(function()
        task.spawn(handleToppingClick, entry.Key)
    end))
    updateStandRow(entry.Key)
end

rebuildStandRows = function()
    if not standListFrame or not scriptRuntime.Active then
        return
    end
    for _, row in pairs(standRowControls) do
        row.Button.Visible = false
    end

    currentTycoon = findTycoon()
    if not currentTycoon then
        setStandStatus("Load your restaurant, then press Refresh", COLORS.Red)
        return
    end

    refreshKnownToppingOwnership()
    refreshKnownComboOwnership()
    local activeTypes = getActiveStandTypes()
    local entries = {}
    local toppingCount = 0
    local comboCount = 0
    for dishType in pairs(activeTypes) do
        local settings = CustomDishData[dishType]
        for toppingName, toppingData in pairs(settings and settings.DataModule or {}) do
            if type(toppingData) == "table"
                and toppingData.Locked == true
                and not toppingIsUnlocked(dishType, toppingName)
            then
                toppingCount += 1
                local toppingDisplay = toppingData.DisplayName or tostring(toppingName)
                table.insert(entries, {
                    Key = getToppingRowKey(dishType, toppingName),
                    EntryType = "Topping",
                    DishType = dishType,
                    ToppingName = toppingName,
                    DisplayName = dishType .. " - " .. toppingDisplay,
                    Data = toppingData,
                })
            end
        end

        for comboName, comboData in pairs(CustomDishComboData[dishType] or {}) do
            if not comboIsUnlocked(dishType, comboName) then
                comboCount += 1
                local comboImage
                for toppingName in pairs(comboData.Toppings or {}) do
                    local toppingData = settings
                        and settings.DataModule
                        and settings.DataModule[toppingName]
                    if toppingData and toppingData.Image then
                        comboImage = toppingData.Image
                        break
                    end
                end
                table.insert(entries, {
                    Key = getComboRowKey(dishType, comboName),
                    EntryType = "Combo",
                    DishType = dishType,
                    ComboName = comboName,
                    DisplayName = dishType .. " Combo - "
                        .. tostring(comboData.DisplayName or comboData.Name or comboName),
                    Data = comboData,
                    Image = comboImage,
                })
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.DisplayName < b.DisplayName
    end)

    for _, entry in ipairs(entries) do
        local row = standRowControls[entry.Key]
        if row then
            row.Button.Visible = true
            updateStandRow(entry.Key)
        else
            createStandRow(entry)
        end
    end
    sortStandRowsByState()
    scriptRuntime.State.StandRowCount = #entries
    scriptRuntime.State.StandToppingCount = toppingCount
    scriptRuntime.State.StandComboCount = comboCount

    if next(activeTypes) == nil then
        setStandStatus("Place a food stand in your restaurant, then press Refresh", COLORS.Yellow)
    elseif #entries == 0 then
        setStandStatus("Every topping and combo for your placed food stands is unlocked", COLORS.Green)
    elseif ingredientInventoryReady then
        setStandStatus(string.format(
            "%d locked toppings, %d locked combos - inventory synced",
            toppingCount,
            comboCount
        ), COLORS.Green)
    else
        setStandStatus(string.format(
            "%d locked toppings, %d locked combos - syncing ingredients...",
            toppingCount,
            comboCount
        ), COLORS.Yellow)
    end

    if standListLayout then
        task.defer(function()
            standListFrame.CanvasSize = UDim2.new(0, 0, 0, standListLayout.AbsoluteContentSize.Y + 8)
        end)
    end
end

local MANAGED_MENU_COURSES = { "Starter", "Main", "Dessert" }
local MANAGED_MENU_COURSE_NAMES = {
    Starter = "Starter",
    Main = "Main",
    Dessert = "Dessert",
}
local SINGLE_MENU_LIMITS = { Starter = 1, Main = 1, Dessert = 1 }
local EXPANDED_MENU_LIMITS = { Starter = 10, Main = 20, Dessert = 10 }

local function getCurrentMenuSet()
    local result = {}
    for _, dishes in pairs(currentMenu) do
        if type(dishes) == "table" then
            for _, foodKey in pairs(dishes) do
                result[tostring(foodKey)] = true
            end
        end
    end
    return result
end

local function getBestMenuDishes()
    local rankedByCourse = {}
    for _, course in ipairs(MANAGED_MENU_COURSES) do
        rankedByCourse[course] = {}
    end
    for foodKey, owned in pairs(cookbook) do
        if owned == true then
            local normalizedKey = tostring(foodKey)
            local food = getFoodInfo(normalizedKey)
            local course = food and tostring(food.Course) or nil
            if food and MANAGED_MENU_COURSE_NAMES[course] and food.ShowInMenu ~= false then
                local boosted = tableHas(boostedFoods, normalizedKey)
                local superBoosted = tableHas(superBoostedFoods, normalizedKey)
                local ok, price = pcall(function()
                    return FoodUtility:GetPrice(normalizedKey, boosted, nil, nil, superBoosted)
                end)
                price = ok and tonumber(price) or nil
                if price then
                    table.insert(rankedByCourse[course], {
                        Key = normalizedKey,
                        Name = getFoodName(normalizedKey),
                        Price = price,
                    })
                end
            end
        end
    end

    local limits = expandedMenuPreset and EXPANDED_MENU_LIMITS or SINGLE_MENU_LIMITS
    for _, course in ipairs(MANAGED_MENU_COURSES) do
        local dishes = rankedByCourse[course]
        table.sort(dishes, function(a, b)
            if a.Price ~= b.Price then
                return a.Price > b.Price
            end
            if a.Name ~= b.Name then
                return a.Name < b.Name
            end
            return a.Key < b.Key
        end)
        while #dishes > limits[course] do
            table.remove(dishes)
        end
    end
    return rankedByCourse
end

local function setMenuStatus(text, color)
    scriptRuntime.State.MenuStatus = text
    if menuStatusLabel then
        menuStatusLabel.Text = text
        menuStatusLabel.TextColor3 = color or COLORS.Muted
    end
end

local function updateMenuSummary(bestByCourse)
    bestByCourse = bestByCourse or getBestMenuDishes()
    local targetState = {}
    for _, course in ipairs(MANAGED_MENU_COURSES) do
        local selected = bestByCourse[course] or {}
        local best = selected[1]
        local label = menuCourseLabels[course]
        if best then
            targetState[course] = selected
            if label then
                if expandedMenuPreset then
                    label.Text = string.format(
                        "%s: %d/%d selected; best %s (%s)",
                        course,
                        #selected,
                        EXPANDED_MENU_LIMITS[course],
                        best.Name,
                        formatMoney(best.Price)
                    )
                else
                    label.Text = string.format("%s: %s (%s)", course, best.Name, formatMoney(best.Price))
                end
                label.TextColor3 = COLORS.Green
            end
        elseif label then
            label.Text = course .. ": No owned dish available"
            label.TextColor3 = COLORS.Red
        end
    end
    scriptRuntime.State.MenuTargets = targetState
    return bestByCourse
end

local function setOptimisticManagedMenu(bestByCourse)
    local nextMenu = {}
    for _, course in ipairs(MANAGED_MENU_COURSES) do
        nextMenu[course] = {}
        for _, dish in ipairs(bestByCourse[course] or {}) do
            table.insert(nextMenu[course], dish.Key)
        end
    end
    currentMenu = nextMenu
end

local function manageBestMenu()
    if not autoMenuEnabled or menuManageBusy or not scriptRuntime.Active then
        return
    end

    currentTycoon = findTycoon()
    if not currentTycoon then
        setMenuStatus("Load your restaurant before managing its menu", COLORS.Red)
        return
    end

    local bestByCourse = updateMenuSummary()
    local desired = {}
    for _, course in ipairs(MANAGED_MENU_COURSES) do
        for _, dish in ipairs(bestByCourse[course] or {}) do
            desired[dish.Key] = true
        end
    end

    local current = getCurrentMenuSet()
    local removals = {}
    local kidsRemovals = {}
    local specialRemovals = {}
    local additions = {}
    for foodKey in pairs(current) do
        if not desired[foodKey] then
            table.insert(removals, foodKey)
        end
    end
    for foodKey in pairs(desired) do
        if not current[foodKey] then
            table.insert(additions, foodKey)
        end
    end
    for _, dishes in pairs(scriptRuntime.MenuData.KidsMenu) do
        if type(dishes) == "table" then
            for _, foodKey in pairs(dishes) do
                table.insert(kidsRemovals, tostring(foodKey))
            end
        end
    end
    for specialKey, details in pairs(scriptRuntime.MenuData.Specials) do
        if type(details) == "table" and details.OnMenuStatus ~= false then
            table.insert(specialRemovals, tostring(specialKey))
        end
    end
    table.sort(removals)
    table.sort(kidsRemovals)
    table.sort(specialRemovals)
    table.sort(additions)

    if #removals == 0 and #kidsRemovals == 0 and #specialRemovals == 0 and #additions == 0 then
        setMenuStatus(
            expandedMenuPreset
                and "Menu is optimized for the 10/20/10 preset"
                or "Menu is optimized: one best starter, main, and dessert",
            COLORS.Green
        )
        return
    end

    menuManageBusy = true
    setMenuStatus(string.format(
        "Updating menu: %d normal, %d kids, %d special removal%s; %d addition%s...",
        #removals,
        #kidsRemovals,
        #specialRemovals,
        (#removals + #kidsRemovals + #specialRemovals) == 1 and "" or "s",
        #additions,
        #additions == 1 and "" or "s"
    ), COLORS.Blue)

    -- This is the same endpoint used by the game's own menu button. Removals
    -- are sent first so each category has room before its best dish is added.
    for _, foodKey in ipairs(removals) do
        foodMenuStatusRemote:FireServer(currentTycoon, foodKey, false, false)
    end
    for _, foodKey in ipairs(kidsRemovals) do
        foodMenuStatusRemote:FireServer(currentTycoon, foodKey, false, true)
    end
    for _, specialKey in ipairs(specialRemovals) do
        foodEvents.SpecialFoodMenuStatusRequested:FireServer(currentTycoon, specialKey, false)
        if scriptRuntime.MenuData.Specials[specialKey] then
            scriptRuntime.MenuData.Specials[specialKey].OnMenuStatus = false
        end
    end
    for _, foodKey in ipairs(additions) do
        foodMenuStatusRemote:FireServer(currentTycoon, foodKey, true, false)
    end

    setOptimisticManagedMenu(bestByCourse)
    scriptRuntime.MenuData.KidsMenu = { Starter = {}, Main = {}, Dessert = {} }
    task.delay(0.8, function()
        menuManageBusy = false
        if scriptRuntime.Active and refreshServerMenu then
            refreshServerMenu(false)
        end
    end)
end

queueMenuManagement = function(delaySeconds)
    updateMenuSummary()
    if not autoMenuEnabled or menuManageQueued or not scriptRuntime.Active then
        return
    end
    menuManageQueued = true
    task.delay(delaySeconds or 0.05, function()
        menuManageQueued = false
        if not scriptRuntime.Active or not autoMenuEnabled then
            return
        end
        if menuManageBusy then
            queueMenuManagement(0.25)
            return
        end
        manageBestMenu()
    end)
end

local STAFF_TYPE_ORDER = {
    Barista = 1,
    DriveThruOperator = 2,
    Chef = 3,
    Waiter = 4,
    Driver = 5,
}
local STAFF_TYPE_NAMES = {
    Waiter = "Servers",
    Chef = "Chefs",
    Barista = "Baristas",
    DriveThruOperator = "Operators",
    Driver = "Drivers",
}
local STAFF_TYPES = { "Waiter", "Chef", "Barista", "DriveThruOperator", "Driver" }

local function getStaffKey(worker)
    return tostring(worker.WorkerType) .. ":" .. tostring(worker.Id)
end

local function getWorkerRoleKeys(worker)
    local workerType = worker.WorkerType
    local level = tonumber(worker.Level) or 1
    if workerType == "Waiter" then
        return {
            Task.SendToTable,
            Task.TakeOrder,
            Task.Serve,
            Task.CollectDishes,
            CustomWorkerRole.DrinksTasks,
            CustomWorkerRole.Floor1,
            CustomWorkerRole.Floor2,
            CustomWorkerRole.Floor3,
        }
    elseif workerType == "Chef" then
        return {
            Task.Cook,
            CustomWorkerRole.DrinksTasks,
            CustomWorkerRole.Floor1,
            CustomWorkerRole.Floor2,
            CustomWorkerRole.Floor3,
        }
    elseif workerType == "Barista" then
        return {
            Task.Cook,
            Task.Serve,
            CustomWorkerRole.Floor1,
            CustomWorkerRole.Floor2,
            CustomWorkerRole.Floor3,
        }
    elseif workerType == "DriveThruOperator" then
        local roles = { Task.Serve, Task.TakeDriveThruOrder }
        if level >= 4 then
            table.insert(roles, Task.CollectDriveThruBill)
        end
        return roles
    elseif workerType == "Driver" then
        return { Task.TakeDeliveryOrder, Task.DeliverOrder }
    end
    return {}
end

local function getTaskStateFromRoleData(worker)
    local roles = getWorkerRoleKeys(worker)
    local roleData = worker.RoleData
    if type(roleData) ~= "table" or #roles == 0 then
        return true
    end

    local enabledCount = 0
    for _, role in ipairs(roles) do
        if roleData[role] == nil or roleData[role] == true then
            enabledCount += 1
        end
    end
    if enabledCount == #roles then
        return true
    elseif enabledCount == 0 then
        return false
    end
    return "Mixed"
end

local function normalizeWorkerList(value)
    local workers = {}
    local seen = {}
    local function collect(candidate, depth)
        if type(candidate) ~= "table" or depth > 3 then
            return
        end
        if candidate.WorkerType ~= nil and candidate.Id ~= nil then
            local worker = {
                WorkerType = tostring(candidate.WorkerType),
                Id = candidate.Id,
                Level = math.clamp(tonumber(candidate.Level) or 1, 1, 5),
                DisplayName = candidate.DisplayName,
                IsSuperWorker = candidate.IsSuperWorker == true,
                RoleData = candidate.RoleData,
            }
            local key = getStaffKey(worker)
            if not seen[key] then
                seen[key] = true
                table.insert(workers, worker)
            end
            return
        end
        for _, nested in pairs(candidate) do
            if type(nested) == "table" then
                collect(nested, depth + 1)
            end
        end
    end
    collect(value, 0)
    return workers
end

local function scanStaffCards()
    local staffGui = playerGui:FindFirstChild("StaffMenu")
    if not staffGui then
        return {}
    end

    local workers = {}
    for _, frame in ipairs(staffGui:GetDescendants()) do
        if frame:HasTag("WorkerFrame") and frame:GetAttribute("Purchased") == true then
            local workerType = frame:GetAttribute("WorkerType")
            local workerId = frame:GetAttribute("Index")
            if workerType and workerId ~= nil then
                local level = 1
                for _, descendant in ipairs(frame:GetDescendants()) do
                    if descendant:IsA("TextLabel") then
                        local parsed = tonumber(descendant.Text:match("Lv%s*(%d+)"))
                        if parsed then
                            level = parsed
                            break
                        end
                    end
                end
                local title = frame:FindFirstChild("Title", true)
                table.insert(workers, {
                    WorkerType = tostring(workerType),
                    Id = workerId,
                    Level = math.clamp(level, 1, 5),
                    DisplayName = title and title.Text or nil,
                })
            end
        end
    end
    return workers
end

local function getStaffSignature(workers)
    local parts = {}
    for _, worker in ipairs(workers) do
        table.insert(parts, table.concat({
            getStaffKey(worker),
            tostring(worker.Level),
            tostring(worker.DisplayName or ""),
            tostring(staffTaskStates[getStaffKey(worker)]),
        }, ":"))
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local lastStaffSignature = ""
local updateStaffRows

local function setStaffSnapshot(workers, hasRoleData)
    if #workers == 0 then
        return false
    end
    staffSnapshot = workers
    staffByKey = {}
    for _, worker in ipairs(staffSnapshot) do
        local key = getStaffKey(worker)
        staffByKey[key] = worker
        if hasRoleData and type(worker.RoleData) == "table" then
            staffTaskStates[key] = getTaskStateFromRoleData(worker)
        elseif staffTaskStates[key] == nil then
            -- The game's default for absent role entries is enabled.
            staffTaskStates[key] = true
        end
    end
    local signature = getStaffSignature(staffSnapshot)
    if signature ~= lastStaffSignature then
        lastStaffSignature = signature
        if updateStaffRows then
            updateStaffRows()
        end
    end
    return true
end

local function makeRoleState(worker, enabled)
    local roles = {}
    for _, role in ipairs(getWorkerRoleKeys(worker)) do
        roles[role] = enabled
    end
    return roles
end

local function setWorkerTasks(worker, enabled)
    currentTycoon = findTycoon()
    if not currentTycoon then
        return
    end
    rolesChangedRemote:FireServer(
        currentTycoon,
        worker.WorkerType,
        worker.Id,
        makeRoleState(worker, enabled)
    )
    staffTaskStates[getStaffKey(worker)] = enabled
end

local function setCategoryTasks(workerType, enabled)
    for _, worker in ipairs(staffSnapshot) do
        if worker.WorkerType == workerType then
            setWorkerTasks(worker, enabled)
        end
    end
    if updateStaffRows then
        updateStaffRows()
    end
end

local function getCategoryState(workerType)
    local count = 0
    local enabled = 0
    for _, worker in ipairs(staffSnapshot) do
        if worker.WorkerType == workerType then
            count += 1
            if staffTaskStates[getStaffKey(worker)] == true then
                enabled += 1
            end
        end
    end
    if count == 0 then
        return "Empty"
    elseif enabled == count then
        return true
    elseif enabled == 0 then
        return false
    end
    return "Mixed"
end

local function styleTaskButton(button, state, prefix)
    if state == true then
        button.BackgroundColor3 = Color3.fromRGB(38, 150, 92)
        button.Text = prefix .. "Enabled"
    elseif state == false then
        button.BackgroundColor3 = Color3.fromRGB(175, 55, 55)
        button.Text = prefix .. "Disabled"
    elseif state == "Empty" then
        button.BackgroundColor3 = Color3.fromRGB(65, 67, 75)
        button.Text = prefix .. "None"
    else
        button.BackgroundColor3 = Color3.fromRGB(190, 135, 35)
        button.Text = prefix .. "Mixed"
    end
end

local function createStaffRow(worker)
    local key = getStaffKey(worker)
    local frame = Instance.new("Frame")
    frame.Name = "Staff_" .. key
    frame.Size = UDim2.new(1, -8, 0, 68)
    frame.BackgroundColor3 = COLORS.Surface
    frame.BorderSizePixel = 0
    frame.Parent = staffListFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "WorkerName"
    nameLabel.Size = UDim2.new(1, -290, 0, 24)
    nameLabel.Position = UDim2.fromOffset(14, 9)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = COLORS.Text
    nameLabel.TextSize = 15
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
    nameLabel.Parent = frame

    local detailLabel = Instance.new("TextLabel")
    detailLabel.Name = "WorkerDetails"
    detailLabel.Size = UDim2.new(1, -290, 0, 22)
    detailLabel.Position = UDim2.fromOffset(14, 36)
    detailLabel.BackgroundTransparency = 1
    detailLabel.TextColor3 = COLORS.Muted
    detailLabel.TextSize = 12
    detailLabel.TextXAlignment = Enum.TextXAlignment.Left
    detailLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
    detailLabel.Parent = frame

    local upgradeButton = Instance.new("TextButton")
    upgradeButton.Name = "Upgrade"
    upgradeButton.Size = UDim2.fromOffset(130, 38)
    upgradeButton.Position = UDim2.new(1, -274, 0, 15)
    upgradeButton.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
    upgradeButton.BorderSizePixel = 0
    upgradeButton.TextColor3 = Color3.new(1, 1, 1)
    upgradeButton.TextSize = 12
    upgradeButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
    upgradeButton.Parent = frame
    Instance.new("UICorner", upgradeButton).CornerRadius = UDim.new(0, 7)

    local taskButton = Instance.new("TextButton")
    taskButton.Name = "Tasks"
    taskButton.Size = UDim2.fromOffset(130, 38)
    taskButton.Position = UDim2.new(1, -138, 0, 15)
    taskButton.BorderSizePixel = 0
    taskButton.TextColor3 = Color3.new(1, 1, 1)
    taskButton.TextSize = 12
    taskButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
    taskButton.Parent = frame
    Instance.new("UICorner", taskButton).CornerRadius = UDim.new(0, 7)

    staffRowControls[key] = {
        Frame = frame,
        Name = nameLabel,
        Details = detailLabel,
        Upgrade = upgradeButton,
        Tasks = taskButton,
    }

    trackConnection(upgradeButton.MouseButton1Click:Connect(function()
        local current = staffByKey[key]
        if not current or current.Level >= 5 or current.IsSuperWorker then
            return
        end
        currentTycoon = findTycoon()
        if currentTycoon then
            upgradeWorkerRemote:FireServer(currentTycoon, current.WorkerType, current.Id)
        end
    end))

    trackConnection(taskButton.MouseButton1Click:Connect(function()
        local current = staffByKey[key]
        if not current then
            return
        end
        setWorkerTasks(current, staffTaskStates[key] ~= true)
        updateStaffRows()
    end))
    return staffRowControls[key]
end

updateStaffRows = function()
    if not staffListFrame then
        return
    end
    for _, row in pairs(staffRowControls) do
        row.Frame.Visible = false
    end

    table.sort(staffSnapshot, function(a, b)
        if a.Level ~= b.Level then
            return a.Level < b.Level
        end
        local aOrder = STAFF_TYPE_ORDER[a.WorkerType] or 99
        local bOrder = STAFF_TYPE_ORDER[b.WorkerType] or 99
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end
        return tostring(a.Id) < tostring(b.Id)
    end)

    for index, worker in ipairs(staffSnapshot) do
        local key = getStaffKey(worker)
        local row = staffRowControls[key] or createStaffRow(worker)
        local typeData = WorkerTypeData[worker.WorkerType] or {}
        local typeName = typeData.DisplayName or worker.WorkerType
        local displayName = worker.DisplayName
        if not displayName or displayName == "" then
            displayName = typeName .. " #" .. tostring(worker.Id)
        end
        row.Frame.Visible = true
        row.Frame.LayoutOrder = index
        row.Name.Text = displayName
        row.Details.Text = string.format("Level %d %s", worker.Level, typeName)
        row.Upgrade.Visible = worker.Level < 5 and not worker.IsSuperWorker
        if row.Upgrade.Visible then
            local cost = typeData.UpgradeCosts and typeData.UpgradeCosts[worker.Level]
            row.Upgrade.Text = cost and ("Upgrade " .. formatMoney(cost)) or "Upgrade"
        end
        styleTaskButton(row.Tasks, staffTaskStates[key], "Tasks: ")
    end

    for workerType, button in pairs(staffCategoryButtons) do
        styleTaskButton(button, getCategoryState(workerType), (STAFF_TYPE_NAMES[workerType] or workerType) .. ": ")
    end

    scriptRuntime.State.StaffCount = #staffSnapshot
    if staffStatusLabel then
        staffStatusLabel.Text = string.format("%d staff - lowest levels shown first", #staffSnapshot)
        staffStatusLabel.TextColor3 = #staffSnapshot > 0 and COLORS.Green or COLORS.Yellow
    end
    if staffListLayout then
        task.defer(function()
            staffListFrame.CanvasSize = UDim2.new(0, 0, 0, staffListLayout.AbsoluteContentSize.Y + 8)
        end)
    end
end

local function refreshStaffSnapshot()
    local workers = scanStaffCards()
    if #workers > 0 then
        setStaffSnapshot(workers, false)
    elseif staffStatusLabel then
        staffStatusLabel.Text = "Staff data is not loaded yet; open the game's Staff menu once"
        staffStatusLabel.TextColor3 = COLORS.Yellow
    end
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function formatSignedMoney(value)
    local prefix = value >= 0 and "+" or "-"
    return prefix .. formatMoney(math.abs(value))
end

local function getCurrentMenuStats()
    local count = 0
    local totalValue = 0
    for _, dishes in pairs(currentMenu) do
        if type(dishes) == "table" then
            for _, foodKey in pairs(dishes) do
                count += 1
                local key = tostring(foodKey)
                local ok, price = pcall(function()
                    return FoodUtility:GetPrice(
                        key,
                        tableHas(boostedFoods, key),
                        nil,
                        nil,
                        tableHas(superBoostedFoods, key)
                    )
                end)
                if ok then
                    totalValue += tonumber(price) or 0
                end
            end
        end
    end
    return count, totalValue
end

local function updateInfoStats()
    local elapsed = math.max(1, os.clock() - sessionStartedAt)
    local cash = getCash()
    local diamondsValue = localPlayer:FindFirstChild("Diamonds")
    local diamonds = diamondsValue and tonumber(diamondsValue.Value) or 0
    local net = cash - sessionStartCash
    local menuCount, menuValue = getCurrentMenuStats()

    if infoLabels.Currencies then
        infoLabels.Currencies.Text = string.format("Cash: %s  |  Diamonds: %d", formatMoney(cash), diamonds)
        infoLabels.Session.Text = string.format("Session: %s", formatDuration(elapsed))
        infoLabels.Income.Text = string.format(
            "Gross income: %s  |  %s/h",
            formatMoney(grossSessionIncome),
            formatMoney(grossSessionIncome * 3600 / elapsed)
        )
        infoLabels.Net.Text = string.format(
            "Net: %s (%s/h)  |  Spending: %s",
            formatSignedMoney(net),
            formatSignedMoney(net * 3600 / elapsed),
            formatMoney(sessionSpending)
        )
        infoLabels.Restaurant.Text = string.format(
            "Staff: %d  |  Menu dishes: %d  |  Combined dish value: %s",
            #staffSnapshot,
            menuCount,
            formatMoney(menuValue)
        )
    end
end

local function scheduleServerRefresh(delaySeconds)
    task.delay(delaySeconds or 0.4, function()
        if scriptRuntime.Active and refreshServerMenu then
            refreshServerMenu(false)
        end
    end)
end

local function handleDishClick(foodKey)
    if actionBusy[foodKey] or not scriptRuntime.Active then
        return
    end

    local row = rowControls[foodKey]
    local state = row and row.State or getDishState(foodKey)

    if state.Kind == "Red" then
        if not ingredientInventoryReady and queueIngredientScan then
            queueIngredientScan(true)
        else
            setStatus(getFoodName(foodKey) .. ": " .. state.Detail, COLORS.Red)
        end
        return
    end

    currentTycoon = findTycoon()
    if not currentTycoon then
        setStatus("Load your restaurant before using Boost", COLORS.Red)
        return
    end

    actionBusy[foodKey] = true

    if state.Kind == "Green" then
        setStatus("Boosting " .. getFoodName(foodKey) .. "...", COLORS.Green)
        local ok, errorMessage = pcall(function()
            boostRemote:FireServer(currentTycoon, tostring(foodKey))
        end)
        if not ok then
            setStatus("Boost failed: " .. tostring(errorMessage), COLORS.Red)
        end
        scheduleServerRefresh(0.35)
        scheduleServerRefresh(1.2)
    else
        setStatus("Buying ingredients for " .. getFoodName(foodKey) .. "...", COLORS.Yellow)
        for _, ingredient in ipairs(state.Missing) do
            for _ = 1, ingredient.Amount do
                purchaseIngredientRemote:FireServer(currentTycoon, ingredient.Name, ingredient.Interior)
            end
        end
        scheduleServerRefresh(0.45)
        scheduleServerRefresh(1.3)
    end

    task.delay(0.3, function()
        actionBusy[foodKey] = nil
    end)
end

local function createDishRow(foodKey, layoutOrder)
    local foodName = getFoodName(foodKey)
    local button = Instance.new("TextButton")
    button.Name = "Dish_" .. tostring(foodKey)
    button.LayoutOrder = layoutOrder
    button.Size = UDim2.new(1, -8, 0, 88)
    button.BackgroundColor3 = COLORS.Surface
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.25
    stroke.Parent = button

    local icon = Instance.new("ImageLabel")
    icon.Name = "DishIcon"
    icon.Size = UDim2.fromOffset(64, 64)
    icon.Position = UDim2.fromOffset(10, 12)
    icon.BackgroundColor3 = Color3.fromRGB(29, 30, 36)
    icon.BorderSizePixel = 0
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = button
    Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 7)
    pcall(function()
        FoodUtility:SetImage(icon, foodKey)
    end)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "DishName"
    nameLabel.Size = UDim2.new(1, -98, 0, 23)
    nameLabel.Position = UDim2.fromOffset(86, 7)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = foodName
    nameLabel.TextColor3 = COLORS.Text
    nameLabel.TextSize = 16
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = Font.new(
        "rbxasset://fonts/families/Roboto.json",
        Enum.FontWeight.Bold,
        Enum.FontStyle.Normal
    )
    nameLabel.Parent = button

    local ingredientsLabel = Instance.new("TextLabel")
    ingredientsLabel.Name = "Ingredients"
    ingredientsLabel.Size = UDim2.new(1, -98, 0, 32)
    ingredientsLabel.Position = UDim2.fromOffset(86, 29)
    ingredientsLabel.BackgroundTransparency = 1
    ingredientsLabel.Text = "Loading ingredients..."
    ingredientsLabel.TextColor3 = COLORS.Muted
    ingredientsLabel.TextSize = 12
    ingredientsLabel.TextWrapped = true
    ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
    ingredientsLabel.TextYAlignment = Enum.TextYAlignment.Top
    ingredientsLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
    ingredientsLabel.Parent = button

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -98, 0, 20)
    status.Position = UDim2.fromOffset(86, 64)
    status.BackgroundTransparency = 1
    status.Text = "Checking..."
    status.TextColor3 = COLORS.Muted
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.FontFace = Font.new(
        "rbxasset://fonts/families/Roboto.json",
        Enum.FontWeight.Medium,
        Enum.FontStyle.Normal
    )
    status.Parent = button

    rowControls[foodKey] = {
        Button = button,
        Stroke = stroke,
        Ingredients = ingredientsLabel,
        Status = status,
        FoodName = foodName,
    }

    -- Build the complete card before parenting it into an executor-protected UI root.
    button.Parent = listFrame

    button.MouseButton1Click:Connect(function()
        task.spawn(handleDishClick, foodKey)
    end)

    updateRow(foodKey)
end

local function rebuildDishRows()
    if not listFrame then
        return
    end

    for _, row in pairs(rowControls) do
        row.Button.Visible = false
    end

    local dishes = {}
    for foodKey, owned in pairs(cookbook) do
        if owned == true and not tableHas(boostedFoods, foodKey) and not tableHas(superBoostedFoods, foodKey) then
            table.insert(dishes, {
                Key = tostring(foodKey),
                Name = getFoodName(foodKey),
            })
        end
    end
    table.sort(dishes, function(a, b)
        if a.Name == b.Name then
            return a.Key < b.Key
        end
        return a.Name < b.Name
    end)

    local firstRowError
    for index, dish in ipairs(dishes) do
        local existing = rowControls[dish.Key]
        if existing then
            existing.Button.LayoutOrder = index
            existing.Button.Visible = true
            updateRow(dish.Key)
        else
            local ok, errorMessage = xpcall(function()
                createDishRow(dish.Key, index)
            end, function(message)
                return debug.traceback(tostring(message), 2)
            end)
            if not ok then
                firstRowError = firstRowError or (dish.Name .. ": " .. tostring(errorMessage))
            end
        end
    end
    sortDishRowsByState()

    local renderedCount = 0
    for _, row in pairs(rowControls) do
        if row.Button.Visible then
            renderedCount = renderedCount + 1
        end
    end
    scriptRuntime.State.RowCount = renderedCount
    scriptRuntime.State.LastError = firstRowError
    if firstRowError then
        setStatus("Some dishes could not be rendered; press Refresh", COLORS.Red)
    elseif #dishes == 0 then
        setStatus("Every owned dish is already boosted", COLORS.Green)
    elseif ingredientInventoryReady then
        setStatus(string.format("%d unboosted dishes - inventory synced", #dishes), COLORS.Green)
    else
        setStatus(string.format("%d unboosted dishes - syncing ingredients...", #dishes), COLORS.Yellow)
    end

    task.defer(refreshListCanvas)
end

local function queueRender(rebuild)
    if renderQueued then
        return
    end
    renderQueued = true
    task.defer(function()
        renderQueued = false
        if not scriptRuntime.Active then
            return
        end
        if rebuild then
            rebuildDishRows()
        else
            updateAllRows()
        end
    end)
end

refreshServerMenu = function(announce)
    if menuRefreshBusy or not scriptRuntime.Active then
        return false
    end

    currentTycoon = findTycoon()
    if not currentTycoon then
        if announce then
            setStatus("Load your restaurant, then press Refresh", COLORS.Red)
        end
        return false
    end

    menuRefreshBusy = true
    if announce then
        setStatus("Refreshing dishes...", COLORS.Blue)
    end

    local ok, newMenu, newCookbook, newBoosted, newSpecials, newKidsMenu, _, newSuperBoosted = pcall(function()
        return getMenuRemote:InvokeServer(currentTycoon)
    end)
    menuRefreshBusy = false

    if not ok then
        setStatus("Menu refresh failed: " .. tostring(newMenu), COLORS.Red)
        return false
    end

    currentMenu = type(newMenu) == "table" and newMenu or {}
    local nextCookbook = type(newCookbook) == "table" and newCookbook or {}
    local nextBoosted = type(newBoosted) == "table" and newBoosted or {}
    scriptRuntime.MenuData.Specials = type(newSpecials) == "table" and newSpecials or {}
    scriptRuntime.MenuData.KidsMenu = type(newKidsMenu) == "table" and newKidsMenu or {}
    local nextSuperBoosted = type(newSuperBoosted) == "table" and newSuperBoosted or {}
    local nextSignature = table.concat({
        getDictionarySignature(nextCookbook),
        getDictionarySignature(nextBoosted),
        getDictionarySignature(nextSuperBoosted),
    }, "|")

    cookbook = nextCookbook
    boostedFoods = nextBoosted
    superBoostedFoods = nextSuperBoosted

    if nextSignature ~= menuRevisionSignature then
        menuRevisionSignature = nextSignature
        rebuildDishRows()
    else
        updateAllRows()
        if announce then
            setStatus(string.format("%d unboosted dishes - data refreshed", scriptRuntime.State.RowCount), COLORS.Green)
        end
    end
    queueMenuManagement()
    updateInfoStats()
    return true
end

local function scanIngredientInventory()
    if scanBusy or not scriptRuntime.Active then
        return false
    end
    scanBusy = true
    setStatus("Syncing ingredient inventory...", COLORS.Blue)
    setStandStatus("Syncing ingredient inventory...", COLORS.Blue)

    local ok, succeeded, failureMessage = xpcall(function()
        currentTycoon = findTycoon()
        local prompt = currentTycoon and currentTycoon:FindFirstChild("FridgePrompt", true)
        local ingredientGui = playerGui:FindFirstChild("IngredientShopMenu")
        local frame = ingredientGui and ingredientGui:FindFirstChild("Frame")
        local shop = frame and frame:FindFirstChild("Content") and frame.Content:FindFirstChild("Shop")
        if not prompt or not ingredientGui or not frame or not shop then
            return false, "Place a fridge in your restaurant, then press Refresh"
        end

        local function readRows()
            local ownership = {}
            local count = 0
            for _, item in ipairs(shop:GetChildren()) do
                if item:HasTag("IngredientShopMenuItem") then
                    count = count + 1
                    local ingredientName = item:GetAttribute("IngredientName") or item.Name
                    local quantityLabel = item:FindFirstChild("Quantity")
                    local quantityText = quantityLabel and quantityLabel.Text or "0"
                    local amount = tonumber((quantityText:gsub("[^%d%-]", ""))) or 0
                    ownership[ingredientName] = math.max(0, amount)
                end
            end
            return count, ownership
        end

        local count, ownership = readRows()
        local alreadyOpen = ingredientGui.Enabled
            and frame.Visible
            and frame.Position.Y.Scale < 1
        if alreadyOpen and frame.Header.Text == "Fridge" and count >= 20 then
            ingredientOwnership = ownership
            ingredientInventoryReady = true
            scriptRuntime.State.InventoryReady = true
            return true
        elseif alreadyOpen then
            return false, "Close the ingredient shop, then press Refresh"
        end

        local saved = {
            Enabled = ingredientGui.Enabled,
            FrameVisible = frame.Visible,
            FramePosition = frame.Position,
            PromptEnabled = prompt.Enabled,
            Restored = false,
        }
        local forcePosition = true
        local changingPosition = false
        local positionConnection

        local function restore()
            if saved.Restored then
                return
            end
            saved.Restored = true
            forcePosition = false
            if positionConnection then
                positionConnection:Disconnect()
                positionConnection = nil
            end
            if frame and frame.Parent then
                frame.Position = saved.FramePosition
                frame.Visible = saved.FrameVisible
            end
            if ingredientGui and ingredientGui.Parent then
                ingredientGui.Enabled = saved.Enabled
            end
            if prompt and prompt.Parent then
                prompt.Enabled = saved.PromptEnabled
            end
        end

        scriptRuntime.ScanRestore = restore
        positionConnection = frame:GetPropertyChangedSignal("Position"):Connect(function()
            if forcePosition and not changingPosition then
                changingPosition = true
                frame.Position = UDim2.fromScale(-3, -3)
                changingPosition = false
            end
        end)
        frame.Position = UDim2.fromScale(-3, -3)
        prompt.Enabled = true

        local fired, fireError = pcall(fireproximityprompt, prompt)
        if not fired then
            restore()
            scriptRuntime.ScanRestore = nil
            return false, "Could not open the fridge: " .. tostring(fireError)
        end

        local deadline = os.clock() + 1.75
        repeat
            task.wait(0.05)
            count, ownership = readRows()
        until (frame.Header.Text == "Fridge" and count >= 20)
            or os.clock() >= deadline
            or not scriptRuntime.Active

        if frame.Header.Text ~= "Fridge" or count < 20 then
            restore()
            scriptRuntime.ScanRestore = nil
            return false, "The fridge could not open; stop cooking and press Refresh"
        end

        -- Load() creates the 25 rows first; the original controller fills their
        -- quantities from its PlayerData cache on the Opened signal just after.
        task.wait(0.25)
        count, ownership = readRows()
        ingredientOwnership = ownership
        ingredientInventoryReady = true
        scriptRuntime.State.InventoryReady = true

        -- The same prompt toggles the game's original fridge interface closed.
        pcall(fireproximityprompt, prompt)
        task.wait(0.45)
        restore()
        scriptRuntime.ScanRestore = nil
        return true
    end, function(errorMessage)
        return debug.traceback(tostring(errorMessage), 2)
    end)

    if type(scriptRuntime.ScanRestore) == "function" then
        pcall(scriptRuntime.ScanRestore)
        scriptRuntime.ScanRestore = nil
    end

    scanBusy = false
    if not ok then
        setStatus("Ingredient sync failed: " .. tostring(succeeded), COLORS.Red)
        setStandStatus("Ingredient sync failed: " .. tostring(succeeded), COLORS.Red)
        return false
    end

    if succeeded then
        setStatus("Ingredient inventory synced", COLORS.Green)
        updateAllRows()
        rebuildStandRows()
    else
        setStatus(tostring(failureMessage or "Ingredient sync failed; press Refresh"), COLORS.Red)
        setStandStatus(tostring(failureMessage or "Ingredient sync failed; press Refresh"), COLORS.Red)
    end
    return succeeded
end

queueIngredientScan = function(force)
    if scanBusy or not scriptRuntime.Active then
        return
    end
    if ingredientInventoryReady and not force then
        return
    end

    task.spawn(function()
        scanIngredientInventory()
    end)
end

local function applyPlayerDataUpdate(player, dataStoreType, updates)
    local owner = getOwner()
    if player ~= localPlayer and player ~= owner then
        return
    end
    if type(updates) ~= "table" then
        return
    end

    local rebuild = false
    local update = false
    local menuChanged = false
    local standChanged = false
    for _, entry in pairs(updates) do
        if type(entry) == "table" then
            local key = entry[1]
            local value = entry[2]
            if key == "Ingredients" and type(value) == "table" then
                ingredientOwnership = value
                ingredientInventoryReady = true
                scriptRuntime.State.InventoryReady = true
                update = true
            elseif key == "BoostedFoods" and type(value) == "table" then
                boostedFoods = value
                rebuild = true
                menuChanged = true
            elseif key == "SuperBoostedFoods" and type(value) == "table" then
                superBoostedFoods = value
                rebuild = true
                menuChanged = true
            elseif key == "Cookbook" and type(value) == "table" then
                cookbook = value
                rebuild = true
                menuChanged = true
            elseif key == "Menu" and type(value) == "table" then
                currentMenu = value
                menuChanged = true
            elseif key == "KidsMenu" and type(value) == "table" then
                scriptRuntime.MenuData.KidsMenu = value
                menuChanged = true
            elseif key == "CustomDishes" and type(value) == "table" then
                scriptRuntime.MenuData.Specials = value
                menuChanged = true
            elseif key == "Workers" and type(value) == "table" then
                setStaffSnapshot(normalizeWorkerList(value), true)
            elseif tostring(key) == "CustomDishToppingsUnlocked" then
                if type(value) == "table" then
                    for dishType, ownership in pairs(value) do
                        mergeUnlockedToppings(dishType, ownership)
                    end
                end
                standChanged = true
            elseif tostring(key) == "CustomDishCombosUnlocked" then
                mergeUnlockedCombos(value)
                standChanged = true
            elseif key == "DidBuyRestockProduct" then
                forcedStockAll = value == true
                update = true
            elseif key == "Cash" then
                update = true
            end
        end
    end

    if rebuild then
        queueRender(true)
    elseif update then
        queueRender(false)
    end
    if menuChanged then
        queueMenuManagement(0.1)
    end
    if standChanged then
        rebuildStandRows()
    end
end

local function initializeInterface()
CreateMenu(MENU_NAME)
CreateGroup(MENU_NAME, "Main")
CreateTab(MENU_NAME, "Main", INFO_TAB_NAME)
CreateTab(MENU_NAME, "Main", TAB_NAME)
CreateTab(MENU_NAME, "Main", STAND_TAB_NAME)
CreateTab(MENU_NAME, "Main", MENU_TAB_NAME)
CreateTab(MENU_NAME, "Main", STAFF_TAB_NAME)
CreateTab(MENU_NAME, "Main", AUTO_TAB_NAME)

sessionStartCash = getCash()
lastRecordedCash = sessionStartCash
infoLabels.Currencies = select(1, CreateValueLabel(INFO_TAB_NAME, "Cash: Loading..."))
infoLabels.Session = select(1, CreateValueLabel(INFO_TAB_NAME, "Session: 00:00:00"))
infoLabels.Income = select(1, CreateValueLabel(INFO_TAB_NAME, "Gross income: Loading..."))
infoLabels.Net = select(1, CreateValueLabel(INFO_TAB_NAME, "Net: Loading..."))
infoLabels.Restaurant = select(1, CreateValueLabel(INFO_TAB_NAME, "Restaurant: Loading..."))

menuStatusLabel = select(1, CreateValueLabel(MENU_TAB_NAME, "Automatic menu management is off"))
for _, course in ipairs(MANAGED_MENU_COURSES) do
    menuCourseLabels[course] = select(1, CreateValueLabel(
        MENU_TAB_NAME,
        course .. ": Checking owned dishes..."
    ))
end
CreateToggle(MENU_TAB_NAME, "Use Expanded Preset (10/20/10)", function(state)
    expandedMenuPreset = state.Value
    scriptRuntime.State.ExpandedMenuPreset = expandedMenuPreset
    updateMenuSummary()
    if autoMenuEnabled then
        setMenuStatus("Applying the selected menu preset...", COLORS.Blue)
        queueMenuManagement(0)
    end
end, false, COLORS.Blue)
CreateToggle(MENU_TAB_NAME, "Auto Manage Best Menu", function(state)
    autoMenuEnabled = state.Value
    scriptRuntime.State.AutoMenuEnabled = autoMenuEnabled
    if autoMenuEnabled then
        setMenuStatus("Checking and optimizing menu...", COLORS.Blue)
        queueMenuManagement(0)
    else
        setMenuStatus("Automatic menu management is off", COLORS.Muted)
    end
end, false, COLORS.Green)
scriptRuntime.State.AutoMenuEnabled = autoMenuEnabled
scriptRuntime.State.ExpandedMenuPreset = expandedMenuPreset
updateMenuSummary()

CreateToggle(AUTO_TAB_NAME, "Auto Collect Table Cash", function(state)
    autoCollectTableCash = state.Value
    scriptRuntime.State.AutoCollectTableCash = autoCollectTableCash
    if autoCollectTableCash then
        collectOutstandingTableBills()
    end
end, false, COLORS.Green)
scriptRuntime.State.AutoCollectTableCash = autoCollectTableCash

CreateToggle(AUTO_TAB_NAME, "Auto Collect Dishes", function(state)
    autoRestaurantTasks:SetCollectDishes(state.Value)
end, false, COLORS.Green)

CreateToggle(AUTO_TAB_NAME, "Auto Cook", function(state)
    autoRestaurantTasks:SetAutoCook(state.Value)
end, false, COLORS.Yellow)

CreateToggle(AUTO_TAB_NAME, "Auto Serve", function(state)
    autoRestaurantTasks:SetAutoServe(state.Value)
end, false, COLORS.Green)

CreateToggle(AUTO_TAB_NAME, "Auto Take Orders", function(state)
    autoRestaurantTasks:SetTakeOrders(state.Value)
end, false, COLORS.Blue)

CreateToggle(AUTO_TAB_NAME, "Auto Seat Customers", function(state)
    autoRestaurantTasks:SetSeatCustomers(state.Value)
end, false, COLORS.Blue)

local staffContainer = CreateContainer(STAFF_TAB_NAME, 370, true)

staffStatusLabel = Instance.new("TextLabel")
staffStatusLabel.Name = "StaffStatus"
staffStatusLabel.Size = UDim2.new(1, 0, 0, 28)
staffStatusLabel.BackgroundColor3 = COLORS.Surface
staffStatusLabel.BorderSizePixel = 0
staffStatusLabel.Text = "Reading staff..."
staffStatusLabel.TextColor3 = COLORS.Muted
staffStatusLabel.TextSize = 12
staffStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
staffStatusLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
staffStatusLabel.Parent = staffContainer
Instance.new("UICorner", staffStatusLabel).CornerRadius = UDim.new(0, 7)
local staffStatusPadding = Instance.new("UIPadding", staffStatusLabel)
staffStatusPadding.PaddingLeft = UDim.new(0, 10)

local categoryBar = Instance.new("Frame")
categoryBar.Name = "CategoryButtons"
categoryBar.Size = UDim2.new(1, 0, 0, 42)
categoryBar.Position = UDim2.fromOffset(0, 34)
categoryBar.BackgroundTransparency = 1
categoryBar.Parent = staffContainer

local categoryLayout = Instance.new("UIListLayout", categoryBar)
categoryLayout.FillDirection = Enum.FillDirection.Horizontal
categoryLayout.Padding = UDim.new(0, 6)
categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder

for index, workerType in ipairs(STAFF_TYPES) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = workerType
    categoryButton.LayoutOrder = index
    categoryButton.Size = UDim2.new(0.2, -5, 0, 38)
    categoryButton.BackgroundColor3 = Color3.fromRGB(65, 67, 75)
    categoryButton.BorderSizePixel = 0
    categoryButton.Text = (STAFF_TYPE_NAMES[workerType] or workerType) .. ": None"
    categoryButton.TextColor3 = Color3.new(1, 1, 1)
    categoryButton.TextSize = 10
    categoryButton.TextWrapped = true
    categoryButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
    categoryButton.Parent = categoryBar
    Instance.new("UICorner", categoryButton).CornerRadius = UDim.new(0, 7)
    staffCategoryButtons[workerType] = categoryButton

    trackConnection(categoryButton.MouseButton1Click:Connect(function()
        local categoryState = getCategoryState(workerType)
        if categoryState ~= "Empty" then
            setCategoryTasks(workerType, categoryState ~= true)
        end
    end))
end

staffListFrame = Instance.new("ScrollingFrame")
staffListFrame.Name = "StaffList"
staffListFrame.Size = UDim2.new(1, 0, 1, -82)
staffListFrame.Position = UDim2.fromOffset(0, 82)
staffListFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
staffListFrame.BackgroundTransparency = 0.15
staffListFrame.BorderSizePixel = 0
staffListFrame.ScrollBarThickness = 6
staffListFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200)
staffListFrame.CanvasSize = UDim2.new()
staffListFrame.Parent = staffContainer
Instance.new("UICorner", staffListFrame).CornerRadius = UDim.new(0, 8)

local staffListPadding = Instance.new("UIPadding", staffListFrame)
staffListPadding.PaddingTop = UDim.new(0, 4)
staffListPadding.PaddingLeft = UDim.new(0, 4)

staffListLayout = Instance.new("UIListLayout", staffListFrame)
staffListLayout.Padding = UDim.new(0, 6)
staffListLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackConnection(staffListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    staffListFrame.CanvasSize = UDim2.new(0, 0, 0, staffListLayout.AbsoluteContentSize.Y + 8)
end))
refreshStaffSnapshot()
updateInfoStats()

local container = CreateContainer(TAB_NAME, 370, true)

statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -128, 0, 34)
statusLabel.Position = UDim2.fromOffset(0, 0)
statusLabel.BackgroundColor3 = COLORS.Surface
statusLabel.BorderSizePixel = 0
statusLabel.Text = "Loading dishes..."
statusLabel.TextColor3 = COLORS.Muted
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
statusLabel.Parent = container
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 7)
local statusPadding = Instance.new("UIPadding", statusLabel)
statusPadding.PaddingLeft = UDim.new(0, 12)

local refreshButton = Instance.new("TextButton")
refreshButton.Name = "Refresh"
refreshButton.Size = UDim2.fromOffset(118, 34)
refreshButton.Position = UDim2.new(1, -118, 0, 0)
refreshButton.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
refreshButton.BorderSizePixel = 0
refreshButton.Text = "Refresh"
refreshButton.TextColor3 = Color3.new(1, 1, 1)
refreshButton.TextSize = 13
refreshButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
refreshButton.Parent = container
Instance.new("UICorner", refreshButton).CornerRadius = UDim.new(0, 7)

local legend = Instance.new("TextLabel")
legend.Name = "Legend"
legend.Size = UDim2.new(1, 0, 0, 24)
legend.Position = UDim2.fromOffset(0, 40)
legend.BackgroundTransparency = 1
legend.RichText = true
legend.Text = '<font color="#32CD7D">Green: ready to boost</font>   '
    .. '<font color="#FFC107">Yellow: affordable + in stock</font>   '
    .. '<font color="#F54C4C">Red: unavailable</font>'
legend.TextColor3 = COLORS.Muted
legend.TextSize = 12
legend.TextXAlignment = Enum.TextXAlignment.Left
legend.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
legend.Parent = container

listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "DishList"
listFrame.Size = UDim2.new(1, 0, 1, -68)
listFrame.Position = UDim2.fromOffset(0, 68)
listFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
listFrame.BackgroundTransparency = 0.15
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200)
listFrame.CanvasSize = UDim2.new()
listFrame.Parent = container
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)

local listPadding = Instance.new("UIPadding", listFrame)
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingLeft = UDim.new(0, 4)

listLayout = Instance.new("UIListLayout", listFrame)
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackConnection(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshListCanvas))

local standContainer = CreateContainer(STAND_TAB_NAME, 370, true)

standStatusLabel = Instance.new("TextLabel")
standStatusLabel.Name = "StandStatus"
standStatusLabel.Size = UDim2.new(1, -128, 0, 34)
standStatusLabel.BackgroundColor3 = COLORS.Surface
standStatusLabel.BorderSizePixel = 0
standStatusLabel.Text = "Loading food-stand toppings and combos..."
standStatusLabel.TextColor3 = COLORS.Muted
standStatusLabel.TextSize = 13
standStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
standStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
standStatusLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
standStatusLabel.Parent = standContainer
Instance.new("UICorner", standStatusLabel).CornerRadius = UDim.new(0, 7)
local standStatusPadding = Instance.new("UIPadding", standStatusLabel)
standStatusPadding.PaddingLeft = UDim.new(0, 12)

local standRefreshButton = Instance.new("TextButton")
standRefreshButton.Name = "Refresh"
standRefreshButton.Size = UDim2.fromOffset(118, 34)
standRefreshButton.Position = UDim2.new(1, -118, 0, 0)
standRefreshButton.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
standRefreshButton.BorderSizePixel = 0
standRefreshButton.Text = "Refresh"
standRefreshButton.TextColor3 = Color3.new(1, 1, 1)
standRefreshButton.TextSize = 13
standRefreshButton.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
standRefreshButton.Parent = standContainer
Instance.new("UICorner", standRefreshButton).CornerRadius = UDim.new(0, 7)

local standLegend = Instance.new("TextLabel")
standLegend.Name = "Legend"
standLegend.Size = UDim2.new(1, 0, 0, 24)
standLegend.Position = UDim2.fromOffset(0, 40)
standLegend.BackgroundTransparency = 1
standLegend.RichText = true
standLegend.Text = '<font color="#32CD7D">Green: ready to unlock</font>   '
    .. '<font color="#FFC107">Yellow: affordable + in stock</font>   '
    .. '<font color="#F54C4C">Red: unavailable</font>'
standLegend.TextColor3 = COLORS.Muted
standLegend.TextSize = 12
standLegend.TextXAlignment = Enum.TextXAlignment.Left
standLegend.FontFace = Font.new("rbxasset://fonts/families/Roboto.json")
standLegend.Parent = standContainer

standListFrame = Instance.new("ScrollingFrame")
standListFrame.Name = "ToppingList"
standListFrame.Size = UDim2.new(1, 0, 1, -68)
standListFrame.Position = UDim2.fromOffset(0, 68)
standListFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
standListFrame.BackgroundTransparency = 0.15
standListFrame.BorderSizePixel = 0
standListFrame.ScrollBarThickness = 6
standListFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200)
standListFrame.CanvasSize = UDim2.new()
standListFrame.Parent = standContainer
Instance.new("UICorner", standListFrame).CornerRadius = UDim.new(0, 8)

local standListPadding = Instance.new("UIPadding", standListFrame)
standListPadding.PaddingTop = UDim.new(0, 4)
standListPadding.PaddingLeft = UDim.new(0, 4)

standListLayout = Instance.new("UIListLayout", standListFrame)
standListLayout.Padding = UDim.new(0, 6)
standListLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackConnection(standListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    standListFrame.CanvasSize = UDim2.new(0, 0, 0, standListLayout.AbsoluteContentSize.Y + 8)
end))

trackConnection(standRefreshButton.MouseButton1Click:Connect(function()
    rebuildStandRows()
    setStandStatus("Syncing ingredient inventory...", COLORS.Blue)
    queueIngredientScan(true)
end))

trackConnection(refreshButton.MouseButton1Click:Connect(function()
    task.spawn(function()
        if refreshServerMenu(true) then
            ingredientInventoryReady = false
            scriptRuntime.State.InventoryReady = false
            table.clear(ingredientOwnership)
            updateAllRows()
            queueIngredientScan(true)
        end
    end)
end))

trackConnection(dataEvents.PlayerDataUpdated.OnClientEvent:Connect(applyPlayerDataUpdate))

trackConnection(foodEvents.RestockAllShops.OnClientEvent:Connect(function()
    forcedStockAll = true
    updateAllRows()
end))

local cashValue = localPlayer:FindFirstChild("Cash")
if cashValue and cashValue:IsA("ValueBase") then
    trackConnection(cashValue.Changed:Connect(function()
        local currentCash = getCash()
        local change = currentCash - lastRecordedCash
        if change > 0 then
            grossSessionIncome += change
        elseif change < 0 then
            sessionSpending += -change
        end
        lastRecordedCash = currentCash
        queueRender(false)
        updateInfoStats()
    end))
end

local diamondsValue = localPlayer:FindFirstChild("Diamonds")
if diamondsValue and diamondsValue:IsA("ValueBase") then
    trackConnection(diamondsValue.Changed:Connect(updateInfoStats))
end

local tycoonValue = localPlayer:FindFirstChild("Tycoon")
if tycoonValue and tycoonValue:IsA("ObjectValue") then
    trackConnection(tycoonValue.Changed:Connect(function()
        currentTycoon = findTycoon()
        currentMenu = {}
        staffSnapshot = {}
        staffByKey = {}
        lastStaffSignature = ""
        ingredientInventoryReady = false
        scriptRuntime.State.InventoryReady = false
        table.clear(ingredientOwnership)
        task.spawn(function()
            if refreshServerMenu(true) then
                queueIngredientScan(true)
            end
            refreshStaffSnapshot()
            rebuildStandRows()
            collectOutstandingTableBills()
            autoRestaurantTasks:Refresh()
            updateInfoStats()
        end)
    end))
end

-- Build the initial cards on the executor's privileged thread. Later refreshes
-- reuse these instances, so boost and purchase updates do not churn the UI.
rebuildLimitedStock()
rebuildStandRows()
if initialMenuSnapshot then
    menuRevisionSignature = table.concat({
        getDictionarySignature(cookbook),
        getDictionarySignature(boostedFoods),
        getDictionarySignature(superBoostedFoods),
    }, "|")
    rebuildDishRows()
    setStatus("Press Refresh to sync ingredient amounts", COLORS.Blue)
    setStandStatus("Press Refresh to sync ingredient amounts", COLORS.Blue)
else
    setStatus("Load your restaurant and run the script again", COLORS.Red)
end

task.spawn(function()
    while scriptRuntime.Active do
        task.wait(1)
        if rebuildLimitedStock() then
            updateAllRows()
        end
        refreshStaffSnapshot()
        updateInfoStats()
    end
end)

task.spawn(function()
    while scriptRuntime.Active do
        task.wait(10)
        if scriptRuntime.Active then
            refreshServerMenu(false)
        end
    end
end)
end

initializeInterface()

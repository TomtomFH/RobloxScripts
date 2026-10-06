-- The Elemental Tree ~ Rewritten
local runtimeEnvironment = type(getgenv) == "function" and getgenv() or _G
local RUNTIME_KEY = "__TomtomFHElementalTreeRuntime"
local previousRuntime = rawget(runtimeEnvironment, RUNTIME_KEY)
if type(previousRuntime) == "table" and type(previousRuntime.Cleanup) == "function" then
    pcall(previousRuntime.Cleanup)
end

local scriptRuntime = {
    Active = true,
    Connections = {},
    CleanupCallbacks = {},
}

local function cleanupRuntime()
    if not scriptRuntime.Active then
        return
    end
    scriptRuntime.Active = false

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
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local Stats = require(ReplicatedStorage:WaitForChild("Stats"))
local GammaNum = require(ReplicatedStorage:WaitForChild("GammaNum"))
local updateUIRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Remotes"):WaitForChild("UpdateUI")

local upgradesFolder = workspace:WaitForChild("Upgrades")
local buyablesFolder = workspace:WaitForChild("Buyables")
local resetsFolder = workspace:WaitForChild("Resets")

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local MENU_NAME = "Elemental Tree"
local RESET_THRESHOLD_CONFIG = {
    Hydrogen = {
        Default = 1.5,
        CalcName = "GetHydrogen",
        Direction = "Below",
        InputLabel = "Hydrogen Reset Below (x/s)",
    },
    Beryllium = {
        Default = 1.25,
        CalcName = "GetHydrogen",
        Direction = "Below",
        InputLabel = "Beryllium Reset Below Hydrogen (x/s)",
    },
    Boron = {
        Default = 1.25,
        CalcName = "GetHydrogen",
        Direction = "Below",
        InputLabel = "Boron Reset Below Hydrogen (x/s)",
    },
    Carbon = {
        Default = 1.25,
        CalcName = "GetHydrogen",
        Direction = "Below",
        InputLabel = "Carbon Reset Below Hydrogen (x/s)",
    },
}
local PARALLEL_RESET_CURRENCIES = {"Beryllium", "Boron", "Carbon"}
local parallelResetCurrencyLookup = {
    Beryllium = true,
    Boron = true,
    Carbon = true,
}
local parallelRootUpgradeLookup = {
    ["1"] = true,
    ["2"] = true,
    ["7"] = true,
}
local resetThresholds = {}
for currency, config in pairs(RESET_THRESHOLD_CONFIG) do
    resetThresholds[currency] = config.Default
end
local CURRENCY_ORDER = {
    "Hydrogen",
    "Helium",
    "Lithium",
    "Beryllium",
    "Boron",
    "Carbon",
    "Nitrogen",
    "Oxygen",
    "Fluorine",
    "Neon",
    "Sodium",
    "Magnesium",
}

local CATEGORY_ROOTS = {
    Upgrades = upgradesFolder,
    Buyables = buyablesFolder,
    Resets = resetsFolder,
}

local categoryByRoot = {
    [upgradesFolder] = "Upgrades",
    [buyablesFolder] = "Buyables",
    [resetsFolder] = "Resets",
}

local configCache = setmetatable({}, {__mode = "k"})
local predecessorMap = setmetatable({}, {__mode = "k"})
local purchaseDepthCache = setmetatable({}, {__mode = "k"})
local nextPurchaseAttempt = setmetatable({}, {__mode = "k"})
local purchaseAttemptCurrencyPath = setmetatable({}, {__mode = "k"})
local modelCache = {}
local infoRows = {}
local autoStates = {
    Buyables = false,
    Obby = false,
}
local currencyAutoStates = {}
scriptRuntime.CurrencyAutoStates = currencyAutoStates
local obbyOriginalStates = {}
local obbyNextTouch = setmetatable({}, {__mode = "k"})
local obbyReturnCFrame = nil
local obbyHighestCheckpoint = nil
local resetCurrencyPaths = {}
local resetCurrencyPrevious = {}
local resetCurrencyDecreasing = {}
local resetAutomationCurrencies = {}
local purchaseDecreaseIgnoreUntil = {}
local autoStatusLabel = nil
local actionStatusLabel = nil
local latestResetMetrics = {}
local statsSynchronized = false
local statsRevision = 0
local renderedStatsRevision = -1
local AUTOMATION_RETRY_INTERVAL = 1
local queueAutomationPass = nil
local automationPassQueued = false
local automationRetryScheduled = false

local function collectChangedPurchaseCurrencies(previousStats, liveStats)
    local changed = {}

    for _, category in ipairs({"Upgrades", "Buyables"}) do
        local previousCategory = previousStats[category] or {}
        local liveCategory = liveStats[category] or {}
        for currencyName, liveEntries in pairs(liveCategory) do
            local previousEntries = previousCategory[currencyName] or {}
            if type(liveEntries) == "table" then
                for id, liveEntry in pairs(liveEntries) do
                    if type(liveEntry) == "table" then
                        local previousEntry = previousEntries[id]
                        local currencyPath = liveEntry.Currency and liveEntry.Currency.Value
                        if type(currencyPath) == "string" then
                            if category == "Upgrades" then
                                local wasBought = previousEntry and previousEntry.Bought
                                    and previousEntry.Bought.Value == true
                                local isBought = liveEntry.Bought and liveEntry.Bought.Value == true
                                if isBought and not wasBought then
                                    changed[currencyPath] = true
                                end
                            else
                                local previousLevel = previousEntry and previousEntry.Level
                                    and previousEntry.Level.Value
                                local liveLevel = liveEntry.Level and liveEntry.Level.Value
                                if previousLevel ~= nil and liveLevel ~= nil then
                                    local compared, increased = pcall(GammaNum.gt, liveLevel, previousLevel)
                                    if compared and increased then
                                        changed[currencyPath] = true
                                    end
                                end

                                local wasMaxed = previousEntry and previousEntry.Maxed
                                    and previousEntry.Maxed.Value == true
                                local isMaxed = liveEntry.Maxed and liveEntry.Maxed.Value == true
                                if isMaxed and not wasMaxed then
                                    changed[currencyPath] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return changed
end

local function updateResetCurrencyTrends(liveStats)
    local changedPurchaseCurrencies = statsSynchronized
        and collectChangedPurchaseCurrencies(Stats, liveStats) or {}
    local now = os.clock()

    for path in pairs(resetCurrencyPaths) do
        local success, node = pcall(GammaNum.unpackPath, path, liveStats)
        local amount = success and type(node) == "table" and node.Value or nil
        if amount ~= nil then
            local previous = resetCurrencyPrevious[path]
            if previous ~= nil then
                local compared, isLower = pcall(GammaNum.lt, amount, previous)
                local purchaseDrop = changedPurchaseCurrencies[path] == true
                    or now < (purchaseDecreaseIgnoreUntil[path] or 0)
                resetCurrencyDecreasing[path] = compared and isLower == true and not purchaseDrop
            else
                resetCurrencyDecreasing[path] = false
            end
            resetCurrencyPrevious[path] = amount
        else
            resetCurrencyDecreasing[path] = false
        end
    end

    return changedPurchaseCurrencies
end

local function synchronizeStats(compressedStats, _, calcValues)
    if not scriptRuntime.Active then
        return
    end

    local success, liveStats = pcall(GammaNum.DecompressTable, compressedStats)
    if not success or type(liveStats) ~= "table" or type(liveStats.Elements) ~= "table" then
        return
    end

    if type(calcValues) == "table" then
        for currency, config in pairs(RESET_THRESHOLD_CONFIG) do
            local value = calcValues[config.CalcName]
            if value ~= nil then
                latestResetMetrics[currency] = value
            end
        end
    end

    local changedPurchaseCurrencies = updateResetCurrencyTrends(liveStats)

    -- Executor ModuleScript requires have a separate cache from the game's LocalScripts.
    -- Keep the executor-side table identity, since purchase Config modules close over it,
    -- but replace its contents with every authoritative UpdateUI snapshot from the server.
    for key in pairs(Stats) do
        if liveStats[key] == nil then
            Stats[key] = nil
        end
    end
    for key, value in pairs(liveStats) do
        Stats[key] = value
    end

    statsSynchronized = true
    statsRevision += 1

    -- A confirmed purchase can unlock every later button in the same chain. Those
    -- buttons may already have a retry reservation from the optimistic batch, so
    -- release the reservations now instead of making the new valid state wait a
    -- full retry interval.
    if next(changedPurchaseCurrencies) ~= nil then
        for model in pairs(nextPurchaseAttempt) do
            if changedPurchaseCurrencies[purchaseAttemptCurrencyPath[model]] then
                nextPurchaseAttempt[model] = nil
                purchaseAttemptCurrencyPath[model] = nil
            end
        end
    end

    -- Purchases are driven directly by the authoritative server update instead of
    -- waiting for a rendered-frame polling pass.
    if queueAutomationPass then
        queueAutomationPass()
    end
end

trackConnection(updateUIRemote.OnClientEvent:Connect(synchronizeStats))

local function stripRichText(text)
    text = tostring(text or "")
    text = text:gsub("<br%s*/?>", " ")
    text = text:gsub("<.->", "")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or text
end

local function shortNumber(value)
    local success, result = pcall(GammaNum.Short, value)
    if success then
        return tostring(result)
    end
    return "?"
end

local function gammaAtLeast(left, right)
    local success, result = pcall(GammaNum.gte, left, right)
    return success and result == true
end

local function gammaLess(left, right)
    local success, result = pcall(GammaNum.lt, left, right)
    return success and result == true
end

local function getConfig(model)
    local cached = configCache[model]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local configModule = model and model:FindFirstChild("Config")
    if not configModule or not configModule:IsA("ModuleScript") then
        configCache[model] = false
        return nil
    end

    local success, config = pcall(require, configModule)
    if not success or type(config) ~= "table" then
        configCache[model] = false
        return nil
    end

    configCache[model] = config
    return config
end

local function getCategory(model)
    local current = model
    while current and current.Parent ~= workspace do
        current = current.Parent
    end
    return current and categoryByRoot[current] or nil
end

local function getCurrencyName(model, category)
    if category == "Resets" then
        return model.Name
    end
    return model.Parent and model.Parent.Name or "Unknown"
end

local function getCurrencyFromPath(path)
    if type(path) ~= "string" then
        return nil
    end
    return path:match("^Elements%.([^%.]+)$")
end

local function getResetAutomationCurrency(model)
    if not model then
        return nil
    end
    if model.Name == "Helium" then
        return "Hydrogen"
    end
    if model.Name == "Lithium" then
        return "Helium"
    end
    return model.Name
end

local function getStatEntry(model, category)
    if not statsSynchronized then
        return nil
    end
    if category == "Upgrades" or category == "Buyables" then
        local categoryStats = Stats[category]
        local currencyStats = categoryStats and categoryStats[model.Parent.Name]
        return currencyStats and currencyStats[model.Name] or nil
    end
    return nil
end

local function getPathNode(path)
    if not statsSynchronized or type(path) ~= "string" then
        return nil
    end

    local success, node = pcall(GammaNum.unpackPath, path, Stats)
    if success then
        return node
    end
    return nil
end

local function valueOf(field)
    if type(field) == "table" and field.Value ~= nil then
        return field.Value
    end
    return field
end

local function isParallelResetSelectable(currency)
    local element = Stats.Elements and Stats.Elements[currency]
    if not element then
        return false
    end
    return not (element.Locked and element.Locked.Value == true)
end

local function sourceIsComplete(model)
    local category = getCategory(model)
    if category == "Upgrades" then
        local entry = getStatEntry(model, category)
        return entry and entry.Bought and entry.Bought.Value == true or false
    end

    if category == "Buyables" then
        local entry = getStatEntry(model, category)
        if not entry then
            return false
        end

        local config = getConfig(model)
        if config and config.NextType == 1 then
            if entry.Bought and entry.Bought.Value == true then
                return true
            end

            local level = entry.Level and valueOf(entry.Level.Value)
            return level ~= nil and gammaAtLeast(level, 1)
        end

        return entry.Maxed and entry.Maxed.Value == true or false
    end

    if category == "Resets" then
        local config = getConfig(model)
        local layer = config and getPathNode(config.LayerCurrency)
        if not layer then
            return false
        end

        if layer.Prestiged and layer.Prestiged.Value == true then
            return true
        end

        if layer.Prestiged then
            return false
        end

        if layer.Unlocked then
            return layer.Unlocked.Value == true
        end

        local layerValue = valueOf(layer.Value)
        return layerValue ~= nil and gammaAtLeast(layerValue, 1)
    end

    return false
end

local function buildPurchaseGraph()
    for _, root in pairs(CATEGORY_ROOTS) do
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("ModuleScript") and descendant.Name == "Config" then
                local owner = descendant.Parent
                local config = getConfig(owner)
                if config and type(config.Next) == "table" then
                    for _, nextModel in pairs(config.Next) do
                        if typeof(nextModel) == "Instance" then
                            predecessorMap[nextModel] = predecessorMap[nextModel] or {}
                            table.insert(predecessorMap[nextModel], owner)
                        end
                    end
                end
                if root == resetsFolder and config and type(config.CurrencyReq) == "string" then
                    resetCurrencyPaths[config.CurrencyReq] = true
                    local automationCurrency = getResetAutomationCurrency(owner)
                    if automationCurrency then
                        resetAutomationCurrencies[automationCurrency] = true
                    end
                end

                local purchaseUI = owner:FindFirstChild("UI")
                if purchaseUI and purchaseUI:IsA("SurfaceGui") then
                    trackConnection(purchaseUI:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if purchaseUI.Enabled and scriptRuntime.Active then
                            -- The physical button becoming enabled is the earliest local
                            -- indication that a predecessor was accepted by the server.
                            nextPurchaseAttempt[owner] = nil
                            purchaseAttemptCurrencyPath[owner] = nil
                            if queueAutomationPass then
                                queueAutomationPass()
                            end
                        end
                    end))
                end
            end
        end
    end

    purchaseDepthCache = setmetatable({}, {__mode = "k"})
end

local function getPurchaseDepth(model, visiting)
    local cached = purchaseDepthCache[model]
    if cached ~= nil then
        return cached
    end

    visiting = visiting or {}
    if visiting[model] then
        return 0
    end
    visiting[model] = true

    local depth = 0
    for _, predecessor in ipairs(predecessorMap[model] or {}) do
        depth = math.max(depth, getPurchaseDepth(predecessor, visiting) + 1)
    end

    visiting[model] = nil
    purchaseDepthCache[model] = depth
    return depth
end

local function requirementsMet(model)
    local predecessors = predecessorMap[model]
    if not predecessors or #predecessors == 0 then
        return false
    end

    for _, predecessor in ipairs(predecessors) do
        if sourceIsComplete(predecessor) then
            return true
        end
    end
    return false
end

local function isRootPurchase(model)
    return model.Parent == upgradesFolder:FindFirstChild("Hydrogen") and model.Name == "1"
end

local function purchaseRequirementsMet(model)
    if isRootPurchase(model) then
        return true
    end

    local currency = model.Parent and model.Parent.Name
    if parallelResetCurrencyLookup[currency] and isParallelResetSelectable(currency)
        and parallelRootUpgradeLookup[model.Name] then
        local element = Stats.Elements and Stats.Elements[currency]
        if element and ((element.Prestiged and element.Prestiged.Value == true)
            or (element.Unlocked and element.Unlocked.Value == true)) then
            return true
        end
    end

    return requirementsMet(model)
end

local function buyableRequirementsMet(model)
    local predecessors = predecessorMap[model]
    if predecessors and #predecessors > 0 then
        return requirementsMet(model)
    end

    local currency = model.Parent and model.Parent.Name
    local element = currency and Stats.Elements and Stats.Elements[currency]
    if not element then
        return false
    end

    if element.Locked and valueOf(element.Locked.Value) == true then
        return false
    end
    if element.Unlocked and valueOf(element.Unlocked.Value) ~= true then
        return false
    end

    return true
end

local function getModelTitle(model, currency)
    local ui = model:FindFirstChild("UI")
    local title = ui and ui:FindFirstChild("Title", true)
    if title and title:IsA("TextLabel") then
        local clean = stripRichText(title.Text)
        if clean ~= "" then
            return clean
        end
    end
    return string.format("%s #%s", currency, model.Name)
end

local function getUpgradeCandidate(model, bypassRequirements)
    local currency = model.Parent and model.Parent.Name or "Unknown"
    if parallelResetCurrencyLookup[currency] and not isParallelResetSelectable(currency) then
        return nil
    end

    local element = Stats.Elements and Stats.Elements[currency]
    if bypassRequirements and element and element.Unlocked
        and valueOf(element.Unlocked.Value) ~= true then
        return nil
    end

    local entry = getStatEntry(model, "Upgrades")
    if not entry or not entry.Bought or entry.Bought.Value == true then
        return nil
    end
    if not bypassRequirements and not purchaseRequirementsMet(model) then
        return nil
    end

    local currencyField = entry.Currency and entry.Currency.Value
    local currencyNode = getPathNode(currencyField)
    local cost = entry.Cost and entry.Cost.Value
    local amount = currencyNode and valueOf(currencyNode.Value)
    if cost == nil or amount == nil then
        return nil
    end

    return {
        Category = "Upgrades",
        Model = model,
        Currency = currency,
        CurrencyPath = currencyField,
        Title = getModelTitle(model, currency),
        Cost = cost,
        Amount = amount,
        Affordable = gammaAtLeast(amount, cost),
        BypassRequirements = bypassRequirements == true,
    }
end

local function getBuyableCandidate(model)
    local entry = getStatEntry(model, "Buyables")
    if not entry or not entry.Maxed or entry.Maxed.Value == true then
        return nil
    end
    if not buyableRequirementsMet(model) then
        return nil
    end

    local cost = entry.Cost and entry.Cost.Value

    local currencyPath = entry.Currency and entry.Currency.Value
    local currencyNode = getPathNode(currencyPath)
    local amount = currencyNode and valueOf(currencyNode.Value)
    if cost == nil or amount == nil then
        return nil
    end

    local currency = model.Parent.Name
    return {
        Category = "Buyables",
        Model = model,
        Currency = currency,
        CurrencyPath = currencyPath,
        Title = getModelTitle(model, currency),
        Cost = cost,
        Amount = amount,
        Affordable = gammaAtLeast(amount, cost),
    }
end

local function getResetCandidate(model)
    local config = getConfig(model)
    if not config or type(config.CurrencyReq) ~= "string" or config.ReqToReset == nil then
        return nil
    end

    local sourceCurrency = getCurrencyFromPath(config.CurrencyReq)
    local automationCurrency = getResetAutomationCurrency(model)
    if parallelResetCurrencyLookup[automationCurrency]
        and not isParallelResetSelectable(automationCurrency) then
        return nil
    end

    local thresholdConfig = automationCurrency and RESET_THRESHOLD_CONFIG[automationCurrency]
    if thresholdConfig then
        local metric = latestResetMetrics[automationCurrency]
        local threshold = resetThresholds[automationCurrency]
        if metric == nil or threshold == nil then
            return nil
        end

        if thresholdConfig.Direction == "Below" then
            if not gammaLess(metric, threshold) then
                return nil
            end
        elseif not gammaAtLeast(metric, threshold) then
            return nil
        end
    elseif resetCurrencyDecreasing[config.CurrencyReq] ~= true then
        return nil
    end

    if type(config.ReqToUnlockLine) == "function" then
        local success, unlocked = pcall(config.ReqToUnlockLine)
        if not success or not unlocked then
            return nil
        end
    end

    local layer = getPathNode(config.LayerCurrency)
    if config.OneTime and layer and layer.Prestiged and layer.Prestiged.Value == true then
        return nil
    end

    local currencyNode = getPathNode(config.CurrencyReq)
    local amount = currencyNode and valueOf(currencyNode.Value)
    if amount == nil then
        return nil
    end

    return {
        Category = "Resets",
        Model = model,
        Currency = model.Name,
        SourceCurrency = sourceCurrency,
        AutomationCurrency = automationCurrency,
        CurrencyPath = config.CurrencyReq,
        Title = "Reset for " .. model.Name,
        Cost = config.ReqToReset,
        Amount = amount,
        Affordable = gammaAtLeast(amount, config.ReqToReset),
    }
end

local function getCandidate(model, category, bypassRequirements)
    if category == "Upgrades" then
        return getUpgradeCandidate(model, bypassRequirements)
    elseif category == "Buyables" then
        return getBuyableCandidate(model)
    elseif category == "Resets" then
        return getResetCandidate(model)
    end
    return nil
end

local function getModels(category, currencyFilter)
    local root = CATEGORY_ROOTS[category]
    local models = {}
    if not root then
        return models
    end

    local cacheKey = currencyFilter or "*"
    modelCache[category] = modelCache[category] or {}
    local cached = modelCache[category][cacheKey]
    if cached then
        return cached
    end

    if category == "Resets" then
        for _, model in ipairs(root:GetChildren()) do
            if model:FindFirstChild("Config") then
                table.insert(models, model)
            end
        end
    else
        local currencies = currencyFilter and {currencyFilter} or CURRENCY_ORDER
        for _, currency in ipairs(currencies) do
            local folder = root:FindFirstChild(currency)
            if folder then
                for _, model in ipairs(folder:GetChildren()) do
                    if model:FindFirstChild("Config") then
                        table.insert(models, model)
                    end
                end
            end
        end
    end

    table.sort(models, function(left, right)
        local leftCurrency = getCurrencyName(left, category)
        local rightCurrency = getCurrencyName(right, category)
        if leftCurrency == rightCurrency then
            return (tonumber(left.Name) or math.huge) < (tonumber(right.Name) or math.huge)
        end

        local leftOrder = table.find(CURRENCY_ORDER, leftCurrency) or math.huge
        local rightOrder = table.find(CURRENCY_ORDER, rightCurrency) or math.huge
        return leftOrder < rightOrder
    end)

    modelCache[category][cacheKey] = models
    return models
end

local function getCheapestUpgrade(currency)
    local folder = upgradesFolder:FindFirstChild(currency)
    if not folder then
        return nil
    end

    local cheapest = nil
    for _, model in ipairs(folder:GetChildren()) do
        if model:FindFirstChild("Config") then
            local candidate = getUpgradeCandidate(model)
            if candidate and (not cheapest or gammaLess(candidate.Cost, cheapest.Cost)) then
                cheapest = candidate
            end
        end
    end
    return cheapest
end

local function allUpgradesBought(currency)
    if not statsSynchronized then
        return false
    end
    local currencyStats = Stats.Upgrades and Stats.Upgrades[currency]
    if not currencyStats then
        return false
    end

    local found = false
    for _, entry in pairs(currencyStats) do
        if type(entry) == "table" and entry.Bought then
            found = true
            if entry.Bought.Value ~= true then
                return false
            end
        end
    end
    return found
end

local function findClickDetector(model)
    return model:FindFirstChildWhichIsA("ClickDetector", true)
end

local function reserveCandidateAttempt(candidate)
    local model = candidate and candidate.Model
    if not model or not model.Parent then
        return false
    end

    local now = os.clock()
    if now < (nextPurchaseAttempt[model] or 0) then
        return false
    end

    nextPurchaseAttempt[model] = now + AUTOMATION_RETRY_INTERVAL
    purchaseAttemptCurrencyPath[model] = candidate.CurrencyPath
    return true
end

local function activateCandidate(candidate, source)
    if not candidate or not candidate.Model or not candidate.Model.Parent then
        return false, "That button is no longer available."
    end

    local fresh = getCandidate(candidate.Model, candidate.Category, candidate.BypassRequirements)
    if not fresh then
        return false, "Its requirements are not currently met."
    end
    if not fresh.Affordable then
        return false, string.format(
            "Need %s %s; you have %s.",
            shortNumber(fresh.Cost),
            fresh.Currency,
            shortNumber(fresh.Amount)
        )
    end

    local detector = findClickDetector(fresh.Model)
    if not detector or type(fireclickdetector) ~= "function" then
        return false, "The button's ClickDetector cannot be activated by this executor."
    end

    local success, err = pcall(fireclickdetector, detector, 0)
    if not success then
        return false, tostring(err)
    end

    if type(fresh.CurrencyPath) == "string" then
        purchaseDecreaseIgnoreUntil[fresh.CurrencyPath] = os.clock() + 0.75
    end

    local prefix = source == "Auto" and "Auto: " or ""
    return true, prefix .. fresh.Title
end

local function updateInfoRows()
    if not statsSynchronized then
        for _, currency in ipairs(CURRENCY_ORDER) do
            local row = infoRows[currency]
            if row then
                row.Candidate = nil
                row.Label.Text = string.format("<b>%s</b>: Waiting for live server data...", currency)
            end
        end
        return
    end

    for _, currency in ipairs(CURRENCY_ORDER) do
        local row = infoRows[currency]
        if row then
            local candidate = getCheapestUpgrade(currency)
            row.Candidate = candidate
            local resetText = ""
            local thresholdConfig = RESET_THRESHOLD_CONFIG[currency]
            if thresholdConfig then
                local metric = latestResetMetrics[currency]
                local metricText = metric and shortNumber(metric) or "waiting"
                local thresholdText = tostring(resetThresholds[currency])
                resetText = string.format(
                    "\nHydrogen gain: x%s/s | Auto reset below x%s/s",
                    metricText,
                    thresholdText
                )
                if parallelResetCurrencyLookup[currency]
                    and not isParallelResetSelectable(currency) then
                    resetText ..= "\n<font color=\"#f97066\">Branch locked until the active branch's #7 upgrade is bought</font>"
                end
            end

            if candidate then
                local stateText
                if candidate.Affordable then
                    stateText = "<font color=\"#32d583\">Affordable now</font>"
                else
                    stateText = "<font color=\"#fdb022\">Not enough currency</font>"
                end

                row.Label.Text = string.format(
                    "<b>%s</b>: %s\nCost: %s | Have: %s | %s",
                    currency,
                    candidate.Title,
                    shortNumber(candidate.Cost),
                    shortNumber(candidate.Amount),
                    stateText
                )
                row.Label.Text ..= resetText
            else
                local complete = allUpgradesBought(currency)
                row.Label.Text = complete
                    and string.format("<b>%s</b>: <font color=\"#32d583\">All upgrades bought</font>", currency)
                    or string.format("<b>%s</b>: Locked by an earlier requirement", currency)
                row.Label.Text ..= resetText
            end
        end
    end
end

local function getLowestEnabledParallelResetCurrency()
    local lowestCurrency = nil
    local lowestAmount = nil

    for _, currency in ipairs(PARALLEL_RESET_CURRENCIES) do
        local state = currencyAutoStates[currency]
        local element = Stats.Elements and Stats.Elements[currency]
        local amount = element and valueOf(element.Value)
        if state and state.Resets and isParallelResetSelectable(currency) and amount ~= nil
            and (lowestAmount == nil or gammaLess(amount, lowestAmount)) then
            lowestCurrency = currency
            lowestAmount = amount
        end
    end

    return lowestCurrency
end

local function getAffordableCandidates(category, currencyFilter, enabledStateName, bypassRequirements)
    local candidates = {}
    local parallelPriority = category == "Resets" and enabledStateName
        and getLowestEnabledParallelResetCurrency() or nil
    for _, model in ipairs(getModels(category, currencyFilter)) do
        local candidate = getCandidate(model, category, bypassRequirements)
        local candidateCurrency = candidate and (category == "Resets"
            and candidate.AutomationCurrency or candidate.Currency)
        local currencyState = candidateCurrency and currencyAutoStates[candidateCurrency]
        local hasParallelPriority = not parallelResetCurrencyLookup[candidateCurrency]
            or not enabledStateName or candidateCurrency == parallelPriority
        if candidate and candidate.Affordable
            and (not currencyFilter or candidateCurrency == currencyFilter)
            and (not enabledStateName or currencyState and currencyState[enabledStateName])
            and hasParallelPriority then
            table.insert(candidates, candidate)
        end
    end

    table.sort(candidates, function(left, right)
        local leftDepth = getPurchaseDepth(left.Model)
        local rightDepth = getPurchaseDepth(right.Model)
        if leftDepth ~= rightDepth then
            return leftDepth < rightDepth
        end

        local leftNumber = tonumber(left.Model.Name)
        local rightNumber = tonumber(right.Model.Name)
        if leftNumber and rightNumber and leftNumber ~= rightNumber then
            return leftNumber < rightNumber
        end
        return left.Model.Name < right.Model.Name
    end)
    return candidates
end

local function runAutoCategory(category, currencyFilter, enabledStateName, bypassRequirements)
    if not scriptRuntime.Active then
        return false
    end

    local candidates = getAffordableCandidates(
        category,
        currencyFilter,
        enabledStateName,
        bypassRequirements
    )
    if #candidates == 0 then
        return false
    end

    local attempted = 0
    local lastMessage = nil
    local queuedCandidates = {}
    for _, candidate in ipairs(candidates) do
        if reserveCandidateAttempt(candidate) then
            attempted += 1
            lastMessage = "Auto: " .. candidate.Title
            table.insert(queuedCandidates, candidate)
        end
    end


    if #queuedCandidates > 0 then
        -- Keep independent currencies/categories threaded, but submit a single
        -- dependency chain in strict order. This lets the server accept #1, #2,
        -- #3, etc. back-to-back instead of receiving children before parents.
        task.spawn(function()
            for _, queuedCandidate in ipairs(queuedCandidates) do
                if not scriptRuntime.Active then
                    return
                end
                activateCandidate(queuedCandidate, "Auto")
            end
        end)
    end

    if attempted > 0 and autoStatusLabel then
        local categoryName = currencyFilter and (currencyFilter .. " " .. category) or category
        autoStatusLabel.Text = string.format(
            "Last batch: <font color=\"#32d583\">%d %s button%s</font> | %s",
            attempted,
            categoryName,
            attempted == 1 and "" or "s",
            stripRichText(lastMessage)
        )
    end
    return attempted > 0
end

local function scheduleAutomationRetry()
    if automationRetryScheduled or not scriptRuntime.Active then
        return
    end

    automationRetryScheduled = true
    task.delay(AUTOMATION_RETRY_INTERVAL, function()
        automationRetryScheduled = false
        if scriptRuntime.Active and queueAutomationPass then
            queueAutomationPass()
        end
    end)
end

local function runAutomationPass()
    if not scriptRuntime.Active or not statsSynchronized then
        return
    end

    local attempted = false
    local anyResetAutomation = false
    for _, currency in ipairs(CURRENCY_ORDER) do
        local state = currencyAutoStates[currency]
        if state then
            if state.Upgrades then
                attempted = runAutoCategory("Upgrades", currency, nil, true) or attempted
            end
            anyResetAutomation = anyResetAutomation or state.Resets
        end
    end

    if anyResetAutomation then
        attempted = runAutoCategory("Resets", nil, "Resets") or attempted
    end

    if autoStates.Buyables then
        attempted = runAutoCategory("Buyables") or attempted
    end

    if attempted then
        scheduleAutomationRetry()
    end
end


queueAutomationPass = function()
    if automationPassQueued or not scriptRuntime.Active then
        return
    end

    automationPassQueued = true
    task.spawn(function()
        automationPassQueued = false
        if scriptRuntime.Active then
            runAutomationPass()
        end
    end)
end

local function getObbyCheckpoints()
    local other = workspace:FindFirstChild("Other")
    local infiniteObby = other and other:FindFirstChild("InfiniteObby")
    return infiniteObby and infiniteObby:FindFirstChild("Checkpoints") or nil
end

local function rememberAndRemoveCheckpointVisuals(part, state)
    for _, child in ipairs(part:GetDescendants()) do
        if (child:IsA("Decal") or child:IsA("Texture")) and not state.HiddenVisualLookup[child] then
            state.HiddenVisualLookup[child] = true
            table.insert(state.HiddenVisuals, {
                Instance = child,
                Parent = child.Parent,
            })
            child.Parent = nil
        end
    end
end

local function applyAutoObbyToCheckpoint(part, root, moveToPlayer)
    local state = obbyOriginalStates[part]
    if not state then
        state = {
            CanCollide = part.CanCollide,
            CanQuery = part.CanQuery,
            Transparency = part.Transparency,
            CFrame = part.CFrame,
            HiddenVisuals = {},
            HiddenVisualLookup = setmetatable({}, {__mode = "k"}),
        }
        obbyOriginalStates[part] = state
    end

    part.CanCollide = false
    part.CanQuery = true
    part.Transparency = 1
    rememberAndRemoveCheckpointVisuals(part, state)
    if moveToPlayer then
        part.CFrame = root.CFrame
    end

    local now = os.clock()
    if type(firetouchinterest) == "function" and now >= (obbyNextTouch[part] or 0) then
        obbyNextTouch[part] = now + 0.1
        pcall(function()
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end)
    end
end

local function runAutoObby()
    if not scriptRuntime.Active then
        return
    end

    local checkpoints = getObbyCheckpoints()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not checkpoints or not root then
        return
    end

    if not obbyReturnCFrame then
        obbyReturnCFrame = root.CFrame
    end

    local highestCheckpoint = nil
    local highestNumber = -math.huge
    for _, checkpoint in ipairs(checkpoints:GetChildren()) do
        local checkpointNumber = checkpoint:IsA("BasePart") and tonumber(checkpoint.Name) or nil
        if checkpointNumber and checkpointNumber ~= 0 and checkpointNumber > highestNumber then
            highestNumber = checkpointNumber
            highestCheckpoint = checkpoint
        end
    end

    if highestCheckpoint and highestCheckpoint ~= obbyHighestCheckpoint then
        obbyHighestCheckpoint = highestCheckpoint
        root.CFrame = highestCheckpoint.CFrame + Vector3.new(
            0,
            highestCheckpoint.Size.Y * 0.5 + root.Size.Y * 0.5 + 0.25,
            0
        )
    elseif not highestCheckpoint then
        obbyHighestCheckpoint = nil
    end

    for _, checkpoint in ipairs(checkpoints:GetChildren()) do
        local checkpointNumber = checkpoint:IsA("BasePart") and tonumber(checkpoint.Name) or nil
        if checkpointNumber and checkpointNumber ~= 0 then
            applyAutoObbyToCheckpoint(checkpoint, root, checkpoint ~= highestCheckpoint)
        end
    end
end

local function restoreAutoObby()
    for part, state in pairs(obbyOriginalStates) do
        pcall(function()
            part.CanCollide = state.CanCollide
            part.CanQuery = state.CanQuery
            part.Transparency = state.Transparency
            part.CFrame = state.CFrame
        end)

        for _, visual in ipairs(state.HiddenVisuals) do
            local instance = visual.Instance
            local parent = visual.Parent
            if instance and instance.Parent == nil and parent and parent.Parent then
                pcall(function()
                    instance.Parent = parent
                end)
            end
        end
    end

    table.clear(obbyOriginalStates)
    table.clear(obbyNextTouch)

    local returnCFrame = obbyReturnCFrame
    obbyReturnCFrame = nil
    obbyHighestCheckpoint = nil
    if returnCFrame then
        local character = localPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = returnCFrame
        end
    end
end

table.insert(scriptRuntime.CleanupCallbacks, function()
    autoStates.Buyables = false
    autoStates.Obby = false
    for _, state in pairs(currencyAutoStates) do
        state.Upgrades = false
        state.Resets = false
    end
    restoreAutoObby()
end)

buildPurchaseGraph()

CreateMenu(MENU_NAME)
CreateGroup(MENU_NAME, "Main")
CreateTab(MENU_NAME, "Main", "Info")
CreateTab(MENU_NAME, "Main", "Auto")

actionStatusLabel = select(1, CreateValueLabel(
    "Info",
    statsSynchronized and "Status: Live server data synchronized" or "Status: Waiting for live server data"
))
CreateLabel("Info", "Each currency can buy every affordable eligible upgrade independently")

for _, currency in ipairs(CURRENCY_ORDER) do
    local currentCurrency = currency
    local label = select(1, CreateValueLabel("Info", currentCurrency .. ": Loading..."))
    local upgradeToggleLabel = "Auto " .. currentCurrency .. " Upgrades"
    local resetToggleLabel = "Auto " .. currentCurrency .. " Reset"
    currencyAutoStates[currentCurrency] = {
        Upgrades = GetConfigValue("Info", upgradeToggleLabel) == true,
        Resets = GetConfigValue("Info", resetToggleLabel) == true,
    }

    CreateToggle("Info", upgradeToggleLabel, function(state)
        currencyAutoStates[currentCurrency].Upgrades = state.Value
        queueAutomationPass()
    end, currencyAutoStates[currentCurrency].Upgrades)

    if resetAutomationCurrencies[currentCurrency] then
        CreateToggle("Info", resetToggleLabel, function(state)
            currencyAutoStates[currentCurrency].Resets = state.Value
            queueAutomationPass()
        end, currencyAutoStates[currentCurrency].Resets)
    else
        currencyAutoStates[currentCurrency].Resets = false
    end

    local thresholdConfig = RESET_THRESHOLD_CONFIG[currentCurrency]
    if thresholdConfig then
        local inputLabel = thresholdConfig.InputLabel
        local thresholdInput = CreateInput(
            "Info",
            inputLabel,
            tostring(resetThresholds[currentCurrency]),
            "Set",
            function(textBox)
                local value = tonumber(textBox.Text)
                if value and value > 0 and value < math.huge then
                    resetThresholds[currentCurrency] = value
                end
                textBox.Text = tostring(resetThresholds[currentCurrency])
                SetConfigValue("Info", inputLabel, textBox.Text)
                updateInfoRows()
                queueAutomationPass()
            end
        )

        local savedThreshold = thresholdInput and tonumber(thresholdInput.Text)
        if savedThreshold and savedThreshold > 0 and savedThreshold < math.huge then
            resetThresholds[currentCurrency] = savedThreshold
        elseif thresholdInput then
            thresholdInput.Text = tostring(resetThresholds[currentCurrency])
            SetConfigValue("Info", inputLabel, thresholdInput.Text)
        end
    end

    infoRows[currentCurrency] = {
        Label = label,
        Candidate = nil,
    }
end

CreateLabel("Auto", "Global Buyables plus Auto Obby; currency upgrades and resets are in Info")
autoStatusLabel = select(1, CreateValueLabel("Auto", "Last batch: None"))

CreateToggle("Auto", "Auto Buyables", function(state)
    autoStates.Buyables = state.Value
    queueAutomationPass()
end, false)

CreateToggle("Auto", "Auto Obby", function(state)
    autoStates.Obby = state.Value
    if state.Value then
        runAutoObby()
    else
        restoreAutoObby()
    end
end, false)

updateInfoRows()
queueAutomationPass()

trackConnection(RunService.RenderStepped:Connect(function()
    if not scriptRuntime.Active then
        return
    end

    if statsSynchronized and actionStatusLabel
        and string.find(actionStatusLabel.Text, "Waiting for live server data", 1, true) then
        actionStatusLabel.Text = "Status: <font color=\"#32d583\">Live server data synchronized</font>"
    end

    if renderedStatsRevision ~= statsRevision then
        renderedStatsRevision = statsRevision
        updateInfoRows()
    end

    if autoStates.Obby then
        runAutoObby()
    end
end))

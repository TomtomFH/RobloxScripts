-- The Elemental Tree ~ Rewritten

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Stats = require(ReplicatedStorage:WaitForChild("Stats"))
local GammaNum = require(ReplicatedStorage:WaitForChild("GammaNum"))
local updateUIRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Remotes"):WaitForChild("UpdateUI")

local upgradesFolder = workspace:WaitForChild("Upgrades")
local buyablesFolder = workspace:WaitForChild("Buyables")
local resetsFolder = workspace:WaitForChild("Resets")

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local MENU_NAME = "Elemental Tree"
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
local nextPurchaseAttempt = setmetatable({}, {__mode = "k"})
local infoRows = {}
local autoStates = {
    Upgrades = false,
    Buyables = false,
    Resets = false,
}
local autoStatusLabel = nil
local actionStatusLabel = nil
local statsSynchronized = false
local statsRevision = 0
local renderedStatsRevision = -1

local function synchronizeStats(compressedStats)
    local success, liveStats = pcall(GammaNum.DecompressTable, compressedStats)
    if not success or type(liveStats) ~= "table" or type(liveStats.Elements) ~= "table" then
        return
    end

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
end

updateUIRemote.OnClientEvent:Connect(synchronizeStats)

local function notify(title, message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 4,
        })
    end)
end

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

local function sourceIsComplete(model)
    local category = getCategory(model)
    if category == "Upgrades" then
        local entry = getStatEntry(model, category)
        return entry and entry.Bought and entry.Bought.Value == true or false
    end

    if category == "Buyables" then
        local entry = getStatEntry(model, category)
        return entry and entry.Maxed and entry.Maxed.Value == true or false
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
            end
        end
    end
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
    return requirementsMet(model)
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

local function getUpgradeCandidate(model)
    local entry = getStatEntry(model, "Upgrades")
    if not entry or not entry.Bought or entry.Bought.Value == true then
        return nil
    end
    if not purchaseRequirementsMet(model) then
        return nil
    end

    local currencyField = entry.Currency and entry.Currency.Value
    local currencyNode = getPathNode(currencyField)
    local cost = entry.Cost and entry.Cost.Value
    local amount = currencyNode and valueOf(currencyNode.Value)
    if cost == nil or amount == nil then
        return nil
    end

    local currency = model.Parent.Name
    return {
        Category = "Upgrades",
        Model = model,
        Currency = currency,
        Title = getModelTitle(model, currency),
        Cost = cost,
        Amount = amount,
        Affordable = gammaAtLeast(amount, cost),
    }
end

local function getBuyableCandidate(model)
    local entry = getStatEntry(model, "Buyables")
    if not entry or not entry.Maxed or entry.Maxed.Value == true then
        return nil
    end
    if not purchaseRequirementsMet(model) then
        return nil
    end

    local cost = entry.Cost and entry.Cost.Value

    local currencyNode = entry.Currency and getPathNode(entry.Currency.Value)
    local amount = currencyNode and valueOf(currencyNode.Value)
    if cost == nil or amount == nil then
        return nil
    end

    local currency = model.Parent.Name
    return {
        Category = "Buyables",
        Model = model,
        Currency = currency,
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
        Title = "Reset for " .. model.Name,
        Cost = config.ReqToReset,
        Amount = amount,
        Affordable = gammaAtLeast(amount, config.ReqToReset),
    }
end

local function getCandidate(model, category)
    if category == "Upgrades" then
        return getUpgradeCandidate(model)
    elseif category == "Buyables" then
        return getBuyableCandidate(model)
    elseif category == "Resets" then
        return getResetCandidate(model)
    end
    return nil
end

local function getModels(category)
    local root = CATEGORY_ROOTS[category]
    local models = {}
    if not root then
        return models
    end

    if category == "Resets" then
        for _, model in ipairs(root:GetChildren()) do
            if model:FindFirstChild("Config") then
                table.insert(models, model)
            end
        end
    else
        for _, currency in ipairs(CURRENCY_ORDER) do
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

local function activateCandidate(candidate, source)
    if not candidate or not candidate.Model or not candidate.Model.Parent then
        return false, "That button is no longer available."
    end

    local fresh = getCandidate(candidate.Model, candidate.Category)
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

    local now = os.clock()
    if now < (nextPurchaseAttempt[fresh.Model] or 0) then
        return false, "Purchase is already being attempted."
    end

    local detector = findClickDetector(fresh.Model)
    if not detector or type(fireclickdetector) ~= "function" then
        return false, "The button's ClickDetector cannot be activated by this executor."
    end

    nextPurchaseAttempt[fresh.Model] = now + 0.075
    local success, err = pcall(fireclickdetector, detector, 0)
    if not success then
        return false, tostring(err)
    end

    local prefix = source == "Auto" and "Auto: " or ""
    return true, prefix .. fresh.Title
end

local function setActionStatus(message, good)
    if actionStatusLabel then
        local color = good and "#32d583" or "#f97066"
        actionStatusLabel.Text = string.format("Status: <font color=\"%s\">%s</font>", color, stripRichText(message))
    end
end

local function updateInfoRows()
    if not statsSynchronized then
        for _, currency in ipairs(CURRENCY_ORDER) do
            local row = infoRows[currency]
            if row then
                row.Candidate = nil
                row.Label.Text = string.format("<b>%s</b>: Waiting for live server data...", currency)
                row.ButtonLabel.Text = "Waiting for synchronization"
                row.ButtonLabel.TextColor3 = Color3.fromRGB(145, 145, 155)
            end
        end
        return
    end

    for _, currency in ipairs(CURRENCY_ORDER) do
        local row = infoRows[currency]
        if row then
            local candidate = getCheapestUpgrade(currency)
            row.Candidate = candidate

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
                row.ButtonLabel.Text = candidate.Affordable
                    and ("Buy now: " .. candidate.Title)
                    or ("Buy when affordable: " .. candidate.Title)
                row.ButtonLabel.TextColor3 = candidate.Affordable
                    and Color3.fromRGB(50, 213, 131)
                    or Color3.fromRGB(255, 255, 255)
            else
                local complete = allUpgradesBought(currency)
                row.Label.Text = complete
                    and string.format("<b>%s</b>: <font color=\"#32d583\">All upgrades bought</font>", currency)
                    or string.format("<b>%s</b>: Locked by an earlier requirement", currency)
                row.ButtonLabel.Text = complete and "Complete" or "No eligible upgrade yet"
                row.ButtonLabel.TextColor3 = Color3.fromRGB(145, 145, 155)
            end
        end
    end
end

local function getAffordableCandidates(category)
    local candidates = {}
    for _, model in ipairs(getModels(category)) do
        local candidate = getCandidate(model, category)
        if candidate and candidate.Affordable then
            table.insert(candidates, candidate)
        end
    end
    return candidates
end

local function runAutoCategory(category)
    local candidates = getAffordableCandidates(category)
    if #candidates == 0 then
        return false
    end

    local attempted = 0
    local lastMessage = nil
    for _, candidate in ipairs(candidates) do
        local success, message = activateCandidate(candidate, "Auto")
        if success then
            attempted += 1
            lastMessage = message
        end
    end

    if attempted > 0 and autoStatusLabel then
        autoStatusLabel.Text = string.format(
            "Last batch: <font color=\"#32d583\">%d %s button%s</font> | %s",
            attempted,
            category,
            attempted == 1 and "" or "s",
            stripRichText(lastMessage)
        )
    end
    return attempted > 0
end

buildPurchaseGraph()

CreateMenu(MENU_NAME)
CreateGroup(MENU_NAME, "Main")
CreateTab(MENU_NAME, "Main", "Info")
CreateTab(MENU_NAME, "Main", "Auto")

actionStatusLabel = select(1, CreateValueLabel(
    "Info",
    statsSynchronized and "Status: Live server data synchronized" or "Status: Waiting for live server data"
))
CreateLabel("Info", "Cheapest eligible upgrade for every currency")

for _, currency in ipairs(CURRENCY_ORDER) do
    local currentCurrency = currency
    local label = select(1, CreateValueLabel("Info", currentCurrency .. ": Loading..."))
    local button = CreateButton("Info", "Buy next " .. currentCurrency .. " upgrade", function()
        local row = infoRows[currentCurrency]
        local candidate = row and getCheapestUpgrade(currentCurrency) or nil
        if not candidate then
            local message = allUpgradesBought(currentCurrency)
                and (currentCurrency .. " is complete.")
                or (currentCurrency .. " has no eligible upgrade yet.")
            setActionStatus(message, false)
            notify("Elemental Tree", message)
            return
        end

        local success, message = activateCandidate(candidate, "Manual")
        setActionStatus(message, success)
        if not success then
            notify("Purchase unavailable", message)
        end
        task.wait(0.15)
        updateInfoRows()
    end)
    local buttonLabel = button and button:FindFirstChildWhichIsA("TextLabel")
    infoRows[currentCurrency] = {
        Label = label,
        Button = button,
        ButtonLabel = buttonLabel,
        Candidate = nil,
    }
end

CreateLabel("Auto", "Each category buys only buttons whose prerequisites and currency requirements are met")
autoStatusLabel = select(1, CreateValueLabel("Auto", "Last batch: None"))

CreateToggle("Auto", "Auto Upgrades", function(state)
    autoStates.Upgrades = state.Value
end, false)

CreateToggle("Auto", "Auto Buyables", function(state)
    autoStates.Buyables = state.Value
end, false)

CreateToggle("Auto", "Auto Resets", function(state)
    autoStates.Resets = state.Value
end, false)

updateInfoRows()

RunService.RenderStepped:Connect(function()
    if statsSynchronized and actionStatusLabel
        and string.find(actionStatusLabel.Text, "Waiting for live server data", 1, true) then
        actionStatusLabel.Text = "Status: <font color=\"#32d583\">Live server data synchronized</font>"
    end

    if renderedStatsRevision ~= statsRevision then
        renderedStatsRevision = statsRevision
        updateInfoRows()
    end

    for _, category in ipairs({"Upgrades", "Buyables", "Resets"}) do
        if autoStates[category] then
            runAutoCategory(category)
        end
    end
end)

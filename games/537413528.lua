-- Build A Boat For Treasure (https://www.roblox.com/games/537413528/)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local boatStages = Workspace:WaitForChild("BoatStages", 30)
local stageInfo = boatStages and boatStages:WaitForChild("StageInfo", 30)
local normalStages = boatStages and boatStages:WaitForChild("NormalStages", 30)
local otherData = LocalPlayer:WaitForChild("OtherData", 30)
local playerData = LocalPlayer:WaitForChild("Data", 30)

local stageRows = {}
local stageConnections = {}
local summaryLabel = nil
local sessionRewardsLabel = nil
local totalRewardsLabel = nil
local currentActionLabel = nil
local chestReadyLabel = nil
local autofarmEnabled = false
local farmThread = nil
local floatObjects = {}
local noClipConnection = nil
local noClipCharacter = nil
local originalCollisionStates = {}
local sessionStartGold = 0
local sessionStartGoldBlocks = 0

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(stageConnections, connection)
    return connection
end

local function getValueObjectValue(parent, childName, fallback)
    local valueObject = parent and parent:FindFirstChild(childName)
    if valueObject and valueObject:IsA("ValueBase") then
        return valueObject.Value
    end

    return fallback
end

local function getStageFolder(slotIndex)
    return stageInfo and stageInfo:FindFirstChild("Stage" .. tostring(slotIndex))
end

local function getVisitedStageName(stageIndex)
    local valueObject = otherData and otherData:FindFirstChild("Stage" .. tostring(stageIndex))
    if valueObject and valueObject:IsA("ValueBase") then
        return tostring(valueObject.Value or "")
    end

    return ""
end

local function hasVisitedStage(stageName)
    stageName = tostring(stageName or "")
    if stageName == "" then
        return false
    end

    for stageIndex = 1, 9 do
        if getVisitedStageName(stageIndex) == stageName then
            return true
        end
    end

    return false
end

local function getStageData(slotIndex)
    local folder = getStageFolder(slotIndex)
    if not folder then
        return {
            Slot = slotIndex,
            StageNum = slotIndex,
            StageName = "",
            Loaded = false,
            Visited = false
        }
    end

    local stageNum = tonumber(getValueObjectValue(folder, "StageNum", slotIndex)) or slotIndex
    local stageName = tostring(getValueObjectValue(folder, "StageName", "") or "")
    local loaded = stageName ~= ""

    return {
        Slot = slotIndex,
        StageNum = stageNum,
        StageName = stageName,
        Loaded = loaded,
        Visited = loaded and hasVisitedStage(stageName)
    }
end

local function formatStageRow(data)
    if not data.Loaded then
        return string.format("Stage%d: Empty", data.Slot)
    end

    local visitedText = data.Visited and "Visited" or "Not visited"
    return string.format("Stage%d: %s  |  #%d  |  %s", data.Slot, data.StageName, data.StageNum, visitedText)
end

local function updateStageList()
    local loadedCount = 0
    local visitedCount = 0

    for slotIndex = 1, 9 do
        local data = getStageData(slotIndex)
        local label = stageRows[slotIndex]

        if data.Loaded then
            loadedCount += 1
        end

        if data.Visited then
            visitedCount += 1
        end

        if label then
            label.Text = formatStageRow(data)
            label.TextColor3 = data.Loaded and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 145)
        end
    end

    if summaryLabel then
        summaryLabel.Text = string.format("Loaded stages: %d/9  |  Visited current route: %d", loadedCount, visitedCount)
    end
end

local function bindValue(folder, childName)
    local valueObject = folder and folder:FindFirstChild(childName)
    if valueObject and valueObject:IsA("ValueBase") then
        connect(valueObject:GetPropertyChangedSignal("Value"), updateStageList)
    end
end

local function bindStageFolder(folder)
    if not folder or not folder:IsA("Folder") then
        return
    end

    bindValue(folder, "StageNum")
    bindValue(folder, "StageName")

    connect(folder.ChildAdded, function(child)
        if child.Name == "StageNum" or child.Name == "StageName" then
            bindValue(folder, child.Name)
            updateStageList()
        end
    end)

    connect(folder.ChildRemoved, function(child)
        if child.Name == "StageNum" or child.Name == "StageName" then
            updateStageList()
        end
    end)
end

local function bindOtherData()
    if not otherData then
        return
    end

    for stageIndex = 1, 9 do
        bindValue(otherData, "Stage" .. tostring(stageIndex))
    end

    connect(otherData.ChildAdded, function(child)
        if child.Name:match("^Stage%d+$") then
            bindValue(otherData, child.Name)
            updateStageList()
        end
    end)

    connect(otherData.ChildRemoved, function(child)
        if child.Name:match("^Stage%d+$") then
            updateStageList()
        end
    end)
end

local function getPlayerStatValue(statName)
    local valueObject = playerData and playerData:FindFirstChild(statName)
    if valueObject and valueObject:IsA("ValueBase") then
        return tonumber(valueObject.Value) or 0
    end

    return 0
end

local function updateRewardLabels()
    local gold = getPlayerStatValue("Gold")
    local goldBlocks = getPlayerStatValue("GoldBlock")
    local sessionGold = math.max(0, gold - sessionStartGold)
    local sessionGoldBlocks = math.max(0, goldBlocks - sessionStartGoldBlocks)

    if sessionRewardsLabel then
        sessionRewardsLabel.Text = string.format("Session: +%d Gold Blocks | +%d Gold", sessionGoldBlocks, sessionGold)
    end

    if totalRewardsLabel then
        totalRewardsLabel.Text = string.format("Total: %d Gold Blocks | %d Gold", goldBlocks, gold)
    end
end

local function bindPlayerDataValue(childName)
    local valueObject = playerData and playerData:FindFirstChild(childName)
    if valueObject and valueObject:IsA("ValueBase") then
        connect(valueObject:GetPropertyChangedSignal("Value"), updateRewardLabels)
    end
end

local function bindPlayerData()
    if not playerData then
        return
    end

    bindPlayerDataValue("Gold")
    bindPlayerDataValue("GoldBlock")

    connect(playerData.ChildAdded, function(child)
        if child.Name == "Gold" or child.Name == "GoldBlock" then
            bindPlayerDataValue(child.Name)
            updateRewardLabels()
        end
    end)

    connect(playerData.ChildRemoved, function(child)
        if child.Name == "Gold" or child.Name == "GoldBlock" then
            updateRewardLabels()
        end
    end)
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getCharacterRoot()
    local character = getCharacter()
    return character and character:WaitForChild("HumanoidRootPart", 10)
end

local function getValueBasePosition(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    return nil
end

local function getCaveDarknessPosition(caveIndex)
    local caveStage = normalStages and normalStages:FindFirstChild("CaveStage" .. tostring(caveIndex))
    local darknessPart = caveStage and caveStage:FindFirstChild("DarknessPart")
    return getValueBasePosition(darknessPart)
end

local function getStageFarmPosition(slotIndex)
    local firstCavePosition = getCaveDarknessPosition(math.max(slotIndex, 1))
    local secondCavePosition = getCaveDarknessPosition(math.max(slotIndex + 1, 2))

    if not firstCavePosition or not secondCavePosition then
        return nil
    end

    return (firstCavePosition + secondCavePosition) * 0.5
end

local function getGoldenChestTriggerPosition()
    local theEnd = normalStages and normalStages:FindFirstChild("TheEnd")
    local goldenChest = theEnd and theEnd:FindFirstChild("GoldenChest")
    local trigger = goldenChest and goldenChest:FindFirstChild("Trigger")
    return getValueBasePosition(trigger)
end

local function getGoldenChestTrigger()
    local theEnd = normalStages and normalStages:FindFirstChild("TheEnd")
    local goldenChest = theEnd and theEnd:FindFirstChild("GoldenChest")
    return goldenChest and goldenChest:FindFirstChild("Trigger")
end

local function applyNoClipToCharacter(character)
    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            if originalCollisionStates[descendant] == nil then
                originalCollisionStates[descendant] = descendant.CanCollide
            end

            descendant.CanCollide = false
        end
    end
end

local function stopNoClip()
    if noClipConnection then
        noClipConnection:Disconnect()
        noClipConnection = nil
    end

    for part, originalCanCollide in pairs(originalCollisionStates) do
        if part and part.Parent then
            part.CanCollide = originalCanCollide
        end
    end

    table.clear(originalCollisionStates)
    noClipCharacter = nil
end

local function startNoClip(character)
    if not character then
        return
    end

    if noClipCharacter ~= character then
        stopNoClip()
        noClipCharacter = character
    end

    applyNoClipToCharacter(character)

    if noClipConnection then
        return
    end

    noClipConnection = RunService.Stepped:Connect(function()
        if not noClipCharacter or not noClipCharacter.Parent then
            stopNoClip()
            return
        end

        applyNoClipToCharacter(noClipCharacter)
    end)
end

local function clearFloatObjects()
    for _, object in ipairs(floatObjects) do
        if object and object.Parent then
            object:Destroy()
        end
    end

    table.clear(floatObjects)
    stopNoClip()
end

local function applyFloating(root)
    if not root then
        return
    end

    if #floatObjects > 0 and floatObjects[1] and floatObjects[1].Parent == root then
        startNoClip(root.Parent)
        return
    end

    clearFloatObjects()
    startNoClip(root.Parent)

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "TomtomFHFloatVelocity"
    bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    bodyVelocity.P = 100000
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "TomtomFHFloatGyro"
    bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
    bodyGyro.P = 100000
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    table.insert(floatObjects, bodyVelocity)
    table.insert(floatObjects, bodyGyro)
end

local function hoverAtPosition(position)
    local root = getCharacterRoot()
    if root and position then
        applyFloating(root)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(position)
    end
end

local function getLoadedStageData()
    local stages = {}

    for slotIndex = 1, 9 do
        local data = getStageData(slotIndex)
        if data.Loaded then
            table.insert(stages, data)
        end
    end

    return stages
end

local function getFirstUnvisitedStage()
    for _, data in ipairs(getLoadedStageData()) do
        if not data.Visited then
            return data
        end
    end

    return nil
end

local function getUnvisitedStageData()
    local stages = {}

    for _, data in ipairs(getLoadedStageData()) do
        if not data.Visited then
            table.insert(stages, data)
        end
    end

    return stages
end

local function areAllLoadedStagesVisited()
    local loadedStages = getLoadedStageData()
    if #loadedStages == 0 then
        return false
    end

    for _, data in ipairs(loadedStages) do
        if not data.Visited then
            return false
        end
    end

    return true
end

local function hasAnyLoadedStageVisited()
    for _, data in ipairs(getLoadedStageData()) do
        if data.Visited then
            return true
        end
    end

    return false
end

local function isFarmLoopEnabled()
    return autofarmEnabled
end

local function isChestReady()
    local trigger = getGoldenChestTrigger()
    return trigger and trigger:FindFirstChild("TouchInterest") ~= nil
end

local function fireClaimGoldRemote()
    local remote = Workspace:FindFirstChild("ClaimRiverResultsGold")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    end
end

local function resetCharacter()
    clearFloatObjects()

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Health = 0
    else
        character:BreakJoints()
    end
end

local function claimRewardsAndReset()
    fireClaimGoldRemote()
    task.wait(0.05)
    resetCharacter()
end

local function setCurrentAction(text)
    if currentActionLabel then
        currentActionLabel.Text = "Current Action: " .. tostring(text)
    end
end

local function updateChestReadyLabel()
    if not chestReadyLabel then
        return
    end

    chestReadyLabel.Text = "Chest Ready: " .. (isChestReady() and "Yes" or "No")
end

local function waitForNextFarmOpportunity()
    while autofarmEnabled and not getFirstUnvisitedStage() and not (isChestReady() and hasAnyLoadedStageVisited()) do
        updateChestReadyLabel()
        setCurrentAction("Waiting")
        clearFloatObjects()
        task.wait(0.1)
    end
end

local function visitStageUntilClaimedOrTimeout(data)
    setCurrentAction("Visiting " .. data.StageName)
    local endTime = os.clock() + 5

    while autofarmEnabled and os.clock() < endTime do
        updateChestReadyLabel()

        if isChestReady() and hasAnyLoadedStageVisited() then
            return true
        end

        data = getStageData(data.Slot)
        if not data.Loaded then
            break
        end

        if data.Visited then
            return false
        end

        local position = getStageFarmPosition(data.StageNum)
        if position then
            hoverAtPosition(position)
        else
            setCurrentAction("Waiting for Stage" .. tostring(data.StageNum))
        end

        task.wait(0.05)
    end

    if autofarmEnabled and data.Loaded and not data.Visited then
        setCurrentAction("Skipping " .. data.StageName)
    end

    return false
end

local function claimGoldChestAndStages()
    local position = getGoldenChestTriggerPosition()
    if not position then
        setCurrentAction("Chest trigger not found")
        task.wait(0.5)
        return
    end

    setCurrentAction("Claiming gold chest")
    local startedAt = os.clock()

    while autofarmEnabled and isChestReady() and os.clock() - startedAt < 2 do
        hoverAtPosition(position)
        task.wait(0.05)
    end

    updateChestReadyLabel()
    clearFloatObjects()

    if areAllLoadedStagesVisited() then
        setCurrentAction("Claiming stage rewards")
        claimRewardsAndReset()
        task.wait(0.25)
        return
    end

    waitForNextFarmOpportunity()
end

local function claimStageRewards()
    setCurrentAction("Claiming stage rewards")
    claimRewardsAndReset()
    task.wait(0.25)
    waitForNextFarmOpportunity()
end

local function runFarmLoop()
    while isFarmLoopEnabled() do
        updateChestReadyLabel()

        if isChestReady() and hasAnyLoadedStageVisited() then
            claimGoldChestAndStages()
        elseif getFirstUnvisitedStage() then
            local interruptedForChest = false

            for _, data in ipairs(getUnvisitedStageData()) do
                if not autofarmEnabled then
                    break
                end

                if isChestReady() and hasAnyLoadedStageVisited() then
                    interruptedForChest = true
                    break
                end

                data = getStageData(data.Slot)
                if not data.Loaded then
                    continue
                end

                if data.Visited then
                    continue
                end

                if visitStageUntilClaimedOrTimeout(data) then
                    interruptedForChest = true
                    break
                end
            end

            if interruptedForChest then
                task.wait()
            end
        elseif areAllLoadedStagesVisited() then
            claimStageRewards()
        else
            setCurrentAction("Waiting")
            clearFloatObjects()
            local waitUntil = os.clock() + 0.35
            while autofarmEnabled and os.clock() < waitUntil do
                updateChestReadyLabel()
                task.wait(0.05)
            end
        end
    end

    clearFloatObjects()
    setCurrentAction("Off")
    updateChestReadyLabel()
end

local function startFarmLoop()
    if farmThread then
        return
    end

    farmThread = task.spawn(function()
        runFarmLoop()
        farmThread = nil
    end)
end

local function setAutofarmEnabled(enabled)
    autofarmEnabled = enabled

    if autofarmEnabled then
        setCurrentAction("Starting")
        updateChestReadyLabel()
        startFarmLoop()
    else
        clearFloatObjects()
        setCurrentAction("Off")
        updateChestReadyLabel()
    end
end

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Stages")
CreateTab("Build A Boat", "Main", "Autofarm")

summaryLabel = select(1, CreateValueLabel("Stages", "Loaded stages: 0/9  |  Visited current route: 0"))

for slotIndex = 1, 9 do
    stageRows[slotIndex] = select(1, CreateValueLabel("Stages", "Stage" .. tostring(slotIndex) .. ": Waiting..."))
end

if stageInfo then
    for slotIndex = 1, 9 do
        local folder = getStageFolder(slotIndex)
        if folder then
            bindStageFolder(folder)
        end
    end

    connect(stageInfo.ChildAdded, function(child)
        bindStageFolder(child)
        updateStageList()
    end)

    connect(stageInfo.ChildRemoved, updateStageList)
else
    if summaryLabel then
        summaryLabel.Text = "workspace.BoatStages.StageInfo not found"
    end
end

bindOtherData()
updateStageList()

sessionStartGold = getPlayerStatValue("Gold")
sessionStartGoldBlocks = getPlayerStatValue("GoldBlock")
sessionRewardsLabel = select(1, CreateValueLabel("Autofarm", "Session: +0 Gold Blocks | +0 Gold"))
totalRewardsLabel = select(1, CreateValueLabel("Autofarm", "Total: 0 Gold Blocks | 0 Gold"))
bindPlayerData()
updateRewardLabels()

currentActionLabel = select(1, CreateValueLabel("Autofarm", "Current Action: Off"))
chestReadyLabel = select(1, CreateValueLabel("Autofarm", "Chest Ready: No"))
updateChestReadyLabel()

CreateToggle("Autofarm", "Autofarm", function(state)
    setAutofarmEnabled(state.Value)
end, autofarmEnabled)

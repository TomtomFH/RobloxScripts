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

local stageRows = {}
local stageConnections = {}
local summaryLabel = nil
local farmStatusLabel = nil
local visitStagesEnabled = false
local claimGoldBlockEnabled = false
local chestSkipEnabled = false
local farmThread = nil
local floatObjects = {}
local noClipConnection = nil
local noClipCharacter = nil
local originalCollisionStates = {}
local ignoredStageNames = {}
local chestSkipLastClaimAt = -math.huge
local CHEST_SKIP_COOLDOWN = 17.15

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

local function getFallbackStageName(slotIndex)
    if slotIndex == 0 then
        return "Stage0"
    end

    return ""
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

    for stageIndex = 0, 9 do
        if getVisitedStageName(stageIndex) == stageName then
            return true
        end
    end

    return false
end

local function getStageData(slotIndex)
    local folder = getStageFolder(slotIndex)
    if not folder then
        local fallbackStageName = getFallbackStageName(slotIndex)
        local loaded = fallbackStageName ~= ""

        return {
            Slot = slotIndex,
            StageNum = 0,
            StageName = fallbackStageName,
            Loaded = loaded,
            Visited = loaded and hasVisitedStage(fallbackStageName)
        }
    end

    local stageNum = tonumber(getValueObjectValue(folder, "StageNum", 0)) or 0
    local stageName = tostring(getValueObjectValue(folder, "StageName", getFallbackStageName(slotIndex)) or "")
    if stageName == "" then
        stageName = getFallbackStageName(slotIndex)
    end

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

    for slotIndex = 0, 9 do
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
        summaryLabel.Text = string.format("Loaded stages: %d/10  |  Visited current route: %d", loadedCount, visitedCount)
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

    for stageIndex = 0, 9 do
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

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getCharacterRoot()
    local character = getCharacter()
    return character and character:WaitForChild("HumanoidRootPart", 10)
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
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

    if slotIndex == 0 then
        firstCavePosition = getCaveDarknessPosition(1)
        secondCavePosition = getCaveDarknessPosition(2)

        if not firstCavePosition or not secondCavePosition then
            return nil
        end

        return firstCavePosition - ((secondCavePosition - firstCavePosition) * 0.5)
    end

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

    for slotIndex = 0, 9 do
        local data = getStageData(slotIndex)
        if data.Loaded then
            table.insert(stages, data)
        end
    end

    return stages
end

local function getFirstUnvisitedStage()
    for _, data in ipairs(getLoadedStageData()) do
        if not data.Visited and not ignoredStageNames[data.StageName] then
            return data
        end
    end

    return nil
end

local function areAllLoadedStagesVisited()
    local loadedStages = getLoadedStageData()
    if #loadedStages == 0 then
        return false
    end

    for _, data in ipairs(loadedStages) do
        if not data.Visited and not ignoredStageNames[data.StageName] then
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
    return visitStagesEnabled or claimGoldBlockEnabled or chestSkipEnabled
end

local function isChestSkipReady()
    return os.clock() - chestSkipLastClaimAt >= CHEST_SKIP_COOLDOWN
end

local function waitForRespawnAfterReset(startCharacter)
    while isFarmLoopEnabled() and LocalPlayer.Character == startCharacter do
        local humanoid = getHumanoid(startCharacter)
        if not startCharacter.Parent or (humanoid and humanoid.Health <= 0) then
            break
        end

        task.wait(0.15)
    end

    clearFloatObjects()

    if isFarmLoopEnabled() then
        if LocalPlayer.Character == startCharacter then
            LocalPlayer.CharacterAdded:Wait()
        end

        getCharacterRoot()
    end
end

local function fireClaimGoldRemote()
    local remote = Workspace:FindFirstChild("ClaimRiverResultsGold")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    end
end

local function resetCharacter()
    local character = LocalPlayer.Character
    local humanoid = getHumanoid(character)

    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
    end
end

local function waitForStagesToVisit()
    while isFarmLoopEnabled() and not getFirstUnvisitedStage() do
        task.wait(0.25)
    end

    table.clear(ignoredStageNames)
end

local function setFarmStatus(text)
    if farmStatusLabel then
        farmStatusLabel.Text = tostring(text)
    end
end

local function visitStage(data)
    setFarmStatus("Visit Stages: " .. data.StageName)
    local startedAt = os.clock()

    while visitStagesEnabled or chestSkipEnabled do
        if chestSkipEnabled and isChestSkipReady() and hasAnyLoadedStageVisited() then
            break
        end

        data = getStageData(data.Slot)
        if not data.Loaded or data.Visited then
            break
        end

        if os.clock() - startedAt >= 5 then
            ignoredStageNames[data.StageName] = true
            setFarmStatus("Visit Stages: Ignored " .. data.StageName)
            clearFloatObjects()
            break
        end

        local position = getStageFarmPosition(data.StageNum)
        if position then
            hoverAtPosition(position)
        else
            setFarmStatus("Visit Stages: Waiting for Stage" .. tostring(data.StageNum))
        end

        task.wait(0.2)
    end
end

local function claimGoldBlock()
    local position = getGoldenChestTriggerPosition()
    if not position then
        setFarmStatus("Claim Gold Block: Trigger not found")
        task.wait(0.5)
        return
    end

    local startCharacter = getCharacter()
    setFarmStatus("Claim Gold Block: Waiting for reset")

    while claimGoldBlockEnabled and LocalPlayer.Character == startCharacter do
        local humanoid = getHumanoid(startCharacter)
        if not startCharacter.Parent or (humanoid and humanoid.Health <= 0) then
            break
        end

        hoverAtPosition(position)
        task.wait(0.2)
    end

    waitForRespawnAfterReset(startCharacter)

    if claimGoldBlockEnabled then
        setFarmStatus("Claim Gold Block: Claiming")
        fireClaimGoldRemote()
        waitForStagesToVisit()
    end
end

local function claimGoldBlockChestSkip()
    local position = getGoldenChestTriggerPosition()
    if not position then
        setFarmStatus("Chest Skip: Trigger not found")
        task.wait(0.5)
        return
    end

    local startCharacter = getCharacter()
    setFarmStatus("Chest Skip: Claiming chest")

    while chestSkipEnabled and LocalPlayer.Character == startCharacter do
        local humanoid = getHumanoid(startCharacter)
        if not startCharacter.Parent or (humanoid and humanoid.Health <= 0) then
            break
        end

        hoverAtPosition(position)
        task.wait(0.1)
    end

    if not chestSkipEnabled then
        clearFloatObjects()
        return
    end

    chestSkipLastClaimAt = os.clock()
    clearFloatObjects()

    setFarmStatus("Chest Skip: Claiming stages")
    fireClaimGoldRemote()

    if chestSkipEnabled and LocalPlayer.Character == startCharacter then
        resetCharacter()
    end

    waitForRespawnAfterReset(startCharacter)
    table.clear(ignoredStageNames)
end

local function runFarmLoop()
    while isFarmLoopEnabled() do
        local unvisitedStage = getFirstUnvisitedStage()

        if chestSkipEnabled and isChestSkipReady() and hasAnyLoadedStageVisited() then
            claimGoldBlockChestSkip()
        elseif (visitStagesEnabled or chestSkipEnabled) and unvisitedStage then
            visitStage(unvisitedStage)
        elseif claimGoldBlockEnabled and areAllLoadedStagesVisited() then
            claimGoldBlock()
        else
            setFarmStatus("Visit Stages: Waiting")
            clearFloatObjects()
            task.wait(0.35)
        end
    end

    clearFloatObjects()
    setFarmStatus("Farm: Off")
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

local function setVisitStagesEnabled(enabled)
    visitStagesEnabled = enabled

    if isFarmLoopEnabled() then
        startFarmLoop()
    else
        clearFloatObjects()
        setFarmStatus("Farm: Off")
    end
end

local function setClaimGoldBlockEnabled(enabled)
    claimGoldBlockEnabled = enabled

    if isFarmLoopEnabled() then
        startFarmLoop()
    else
        clearFloatObjects()
        setFarmStatus("Farm: Off")
    end
end

local function setChestSkipEnabled(enabled)
    chestSkipEnabled = enabled

    if chestSkipEnabled and chestSkipLastClaimAt == -math.huge then
        chestSkipLastClaimAt = os.clock() - CHEST_SKIP_COOLDOWN
    end

    if isFarmLoopEnabled() then
        startFarmLoop()
    else
        clearFloatObjects()
        setFarmStatus("Farm: Off")
    end
end

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Stages")
CreateTab("Build A Boat", "Main", "Toggles")

summaryLabel = select(1, CreateValueLabel("Stages", "Loaded stages: 0/10  |  Visited current route: 0"))

for slotIndex = 0, 9 do
    stageRows[slotIndex] = select(1, CreateValueLabel("Stages", "Stage" .. tostring(slotIndex) .. ": Waiting..."))
end

if stageInfo then
    for slotIndex = 0, 9 do
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

farmStatusLabel = select(1, CreateValueLabel("Toggles", "Farm: Off"))

CreateToggle("Toggles", "Visit Stages", function(state)
    setVisitStagesEnabled(state.Value)
end, visitStagesEnabled)

CreateToggle("Toggles", "Claim Gold Block", function(state)
    setClaimGoldBlockEnabled(state.Value)
end, claimGoldBlockEnabled)

CreateToggle("Toggles", "Chest Skip (Testing)", function(state)
    setChestSkipEnabled(state.Value)
end, chestSkipEnabled)

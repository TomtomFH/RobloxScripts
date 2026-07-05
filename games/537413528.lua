-- Build A Boat For Treasure (https://www.roblox.com/games/537413528/)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
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
local currentActionLabel = nil
local chestTimerLabel = nil
local autofarmEnabled = false
local farmThread = nil
local floatObjects = {}
local noClipConnection = nil
local noClipCharacter = nil
local originalCollisionStates = {}
local ignoredStageNames = {}
local lastChestClaimAt = -math.huge
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

local function getGoldenChest()
    local theEnd = normalStages and normalStages:FindFirstChild("TheEnd")
    return theEnd and theEnd:FindFirstChild("GoldenChest")
end

local function isChestClaimSequenceActive()
    local goldenChest = getGoldenChest()
    local tempPrizes = goldenChest and goldenChest:FindFirstChild("DisplayPrizesTemp")
    if tempPrizes and #tempPrizes:GetChildren() > 0 then
        return true
    end

    if math.abs(Lighting.ClockTime - 3.7) <= 0.25 and Lighting.FogEnd <= 150 and Lighting.FogStart >= 15 then
        return true
    end

    local camera = Workspace.CurrentCamera
    if camera and camera.FieldOfView <= 61 and Lighting.FogEnd <= 150 then
        return true
    end

    return false
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

local function getChestTimerRemaining()
    return math.max(0, CHEST_SKIP_COOLDOWN - (os.clock() - lastChestClaimAt))
end

local function isChestReady()
    return getChestTimerRemaining() <= 0
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

local function setCurrentAction(text)
    if currentActionLabel then
        currentActionLabel.Text = "Current Action: " .. tostring(text)
    end
end

local function updateChestTimerLabel()
    if not chestTimerLabel then
        return
    end

    if lastChestClaimAt == -math.huge then
        chestTimerLabel.Text = "Chest Timer: Ready"
        return
    end

    local remaining = getChestTimerRemaining()
    if remaining <= 0 then
        chestTimerLabel.Text = "Chest Timer: Ready"
    else
        chestTimerLabel.Text = string.format("Chest Timer: %.1fs", remaining)
    end
end

local function visitStage(data)
    setCurrentAction("Visiting " .. data.StageName)
    local startedAt = os.clock()

    while autofarmEnabled do
        updateChestTimerLabel()

        if isChestReady() and hasAnyLoadedStageVisited() then
            break
        end

        data = getStageData(data.Slot)
        if not data.Loaded or data.Visited then
            break
        end

        if os.clock() - startedAt >= 5 then
            ignoredStageNames[data.StageName] = true
            setCurrentAction("Ignored " .. data.StageName)
            clearFloatObjects()
            break
        end

        local position = getStageFarmPosition(data.StageNum)
        if position then
            hoverAtPosition(position)
        else
            setCurrentAction("Waiting for Stage" .. tostring(data.StageNum))
        end

        task.wait(0.2)
    end
end

local function claimGoldBlockForAutofarm()
    local position = getGoldenChestTriggerPosition()
    if not position then
        setCurrentAction("Chest trigger not found")
        task.wait(0.5)
        return
    end

    local startCharacter = getCharacter()
    setCurrentAction("Claiming gold chest")
    local sawInactiveSequence = not isChestClaimSequenceActive()
    local sequenceDetected = false

    while autofarmEnabled and LocalPlayer.Character == startCharacter do
        local humanoid = getHumanoid(startCharacter)
        if not startCharacter.Parent or (humanoid and humanoid.Health <= 0) then
            break
        end

        hoverAtPosition(position)

        local sequenceActive = isChestClaimSequenceActive()
        if not sequenceActive then
            sawInactiveSequence = true
        elseif sawInactiveSequence then
            sequenceDetected = true
            break
        end

        task.wait(0.05)
    end

    if not autofarmEnabled or not sequenceDetected then
        clearFloatObjects()
        return
    end

    lastChestClaimAt = os.clock()
    updateChestTimerLabel()
    clearFloatObjects()

    setCurrentAction("Claiming stage rewards")
    fireClaimGoldRemote()

    if autofarmEnabled and LocalPlayer.Character == startCharacter then
        resetCharacter()
    end

    waitForRespawnAfterReset(startCharacter)
    table.clear(ignoredStageNames)
end

local function runFarmLoop()
    while isFarmLoopEnabled() do
        updateChestTimerLabel()
        local unvisitedStage = getFirstUnvisitedStage()

        if isChestReady() and hasAnyLoadedStageVisited() then
            claimGoldBlockForAutofarm()
        elseif unvisitedStage then
            visitStage(unvisitedStage)
        else
            setCurrentAction("Waiting")
            clearFloatObjects()
            local waitUntil = os.clock() + 0.35
            while autofarmEnabled and os.clock() < waitUntil do
                updateChestTimerLabel()
                task.wait(0.05)
            end
        end
    end

    clearFloatObjects()
    setCurrentAction("Off")
    updateChestTimerLabel()
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
        if lastChestClaimAt == -math.huge then
            lastChestClaimAt = os.clock() - CHEST_SKIP_COOLDOWN
        end

        setCurrentAction("Starting")
        updateChestTimerLabel()
        startFarmLoop()
    else
        clearFloatObjects()
        setCurrentAction("Off")
        updateChestTimerLabel()
    end
end

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Stages")
CreateTab("Build A Boat", "Main", "Autofarm")

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

currentActionLabel = select(1, CreateValueLabel("Autofarm", "Current Action: Off"))
chestTimerLabel = select(1, CreateValueLabel("Autofarm", "Chest Timer: Ready"))
updateChestTimerLabel()

CreateToggle("Autofarm", "Autofarm", function(state)
    setAutofarmEnabled(state.Value)
end, autofarmEnabled)

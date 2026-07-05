-- Build A Boat For Treasure (https://www.roblox.com/games/537413528/)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local boatStages = Workspace:WaitForChild("BoatStages", 30)
local stageInfo = boatStages and boatStages:WaitForChild("StageInfo", 30)
local normalStages = boatStages and boatStages:WaitForChild("NormalStages", 30)
local otherStages = boatStages and boatStages:WaitForChild("OtherStages", 30)
local otherData = LocalPlayer:WaitForChild("OtherData", 30)

local stageRows = {}
local stageConnections = {}
local summaryLabel = nil
local autofarmStatusLabel = nil
local autofarmEnabled = false
local autofarmThread = nil
local farmReferencePosition = nil

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

local function getCharacterRoot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getInstanceCenter(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        local ok, cframe = pcall(function()
            return instance:GetBoundingBox()
        end)

        if ok and cframe then
            return cframe.Position
        end
    end

    local minPosition = Vector3.new(math.huge, math.huge, math.huge)
    local maxPosition = Vector3.new(-math.huge, -math.huge, -math.huge)
    local foundPart = false

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local position = descendant.Position
            local halfSize = descendant.Size * 0.5

            minPosition = Vector3.new(
                math.min(minPosition.X, position.X - halfSize.X),
                math.min(minPosition.Y, position.Y - halfSize.Y),
                math.min(minPosition.Z, position.Z - halfSize.Z)
            )

            maxPosition = Vector3.new(
                math.max(maxPosition.X, position.X + halfSize.X),
                math.max(maxPosition.Y, position.Y + halfSize.Y),
                math.max(maxPosition.Z, position.Z + halfSize.Z)
            )

            foundPart = true
        end
    end

    if foundPart then
        return (minPosition + maxPosition) * 0.5
    end

    return nil
end

local function getFarmReferencePosition()
    if farmReferencePosition then
        return farmReferencePosition
    end

    local caveStage = normalStages and normalStages:WaitForChild("CaveStage1", 30)
    local darknessPart = caveStage and caveStage:WaitForChild("DarknessPart", 30)
    farmReferencePosition = getInstanceCenter(darknessPart)

    return farmReferencePosition
end

local function getStageTarget(slotIndex, stageName)
    if slotIndex == 0 then
        return normalStages and normalStages:FindFirstChild("ForestStage")
    end

    if not stageName or stageName == "" then
        return nil
    end

    return otherStages and otherStages:FindFirstChild(stageName)
end

local function getStageFarmPosition(slotIndex, stageName)
    local referencePosition = getFarmReferencePosition()
    local targetStage = getStageTarget(slotIndex, stageName)
    local stageCenter = getInstanceCenter(targetStage)

    if not referencePosition or not stageCenter then
        return nil
    end

    return Vector3.new(referencePosition.X, referencePosition.Y, stageCenter.Z)
end

local function setAutofarmStatus(text)
    if autofarmStatusLabel then
        autofarmStatusLabel.Text = tostring(text)
    end
end

local function teleportToPosition(position)
    local root = getCharacterRoot()
    if root and position then
        root.CFrame = CFrame.new(position)
    end
end

local function runAutofarm()
    setAutofarmStatus("Autofarm: Running")

    while autofarmEnabled do
        local didWork = false

        for slotIndex = 0, 9 do
            if not autofarmEnabled then
                break
            end

            local data = getStageData(slotIndex)
            if data.Loaded and not data.Visited then
                didWork = true
                setAutofarmStatus("Autofarm: " .. data.StageName)

                while autofarmEnabled do
                    data = getStageData(slotIndex)
                    if not data.Loaded or data.Visited then
                        break
                    end

                    local position = getStageFarmPosition(slotIndex, data.StageName)
                    if position then
                        teleportToPosition(position)
                    else
                        setAutofarmStatus("Autofarm: Waiting for " .. data.StageName)
                    end

                    task.wait(0.35)
                end
            end
        end

        if autofarmEnabled and not didWork then
            setAutofarmStatus("Autofarm: Waiting for unvisited stage")
            task.wait(0.5)
        end
    end

    setAutofarmStatus("Autofarm: Off")
end

local function setAutofarmEnabled(enabled)
    autofarmEnabled = enabled

    if autofarmEnabled then
        if autofarmThread then
            return
        end

        autofarmThread = task.spawn(function()
            runAutofarm()
            autofarmThread = nil
        end)
    else
        setAutofarmStatus("Autofarm: Off")
    end
end

getFarmReferencePosition()

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

autofarmStatusLabel = select(1, CreateValueLabel("Toggles", "Autofarm: Off"))

CreateToggle("Toggles", "Autofarm", function(state)
    setAutofarmEnabled(state.Value)
end, autofarmEnabled)

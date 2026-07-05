-- Build A Boat For Treasure (https://www.roblox.com/games/537413528/)

local Workspace = game:GetService("Workspace")

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local stageInfo = Workspace:WaitForChild("BoatStages", 30)
stageInfo = stageInfo and stageInfo:WaitForChild("StageInfo", 30)

local stageRows = {}
local stageConnections = {}
local visitedStages = {}
local summaryLabel = nil

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

local function getStageData(slotIndex)
    local folder = getStageFolder(slotIndex)
    if not folder then
        return {
            Slot = slotIndex,
            StageNum = 0,
            StageName = "",
            Loaded = false,
            Visited = false
        }
    end

    local stageNum = tonumber(getValueObjectValue(folder, "StageNum", 0)) or 0
    local stageName = tostring(getValueObjectValue(folder, "StageName", "") or "")
    local loaded = stageName ~= ""
    local visitedKey = stageNum .. ":" .. stageName

    if loaded then
        visitedStages[visitedKey] = true
    end

    return {
        Slot = slotIndex,
        StageNum = stageNum,
        StageName = stageName,
        Loaded = loaded,
        Visited = loaded and visitedStages[visitedKey] == true
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
        summaryLabel.Text = string.format("Loaded stages: %d/9  |  Visited this session: %d", loadedCount, visitedCount)
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

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Stages")

summaryLabel = select(1, CreateValueLabel("Stages", "Loaded stages: 0/9  |  Visited this session: 0"))

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

updateStageList()

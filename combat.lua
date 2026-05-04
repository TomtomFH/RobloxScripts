local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local boxesEnabled = false
local boxStyle = "2D"
local healthBarEnabled = false
local healthLabelEnabled = false
local useTeamColorEnabled = false
local boxGui = nil
local boxConnection = nil
local boxFrames2D = {}
local boxAdornments3D = {}
local playerInfoOverlays = {}
local box3DEdgeThickness = 0.1
local boxColor = Color3.fromRGB(255, 255, 255)

local function getBoxColor(player)
    if useTeamColorEnabled and player.Team then
        return player.TeamColor.Color
    end

    return boxColor
end

local function resolveUiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end

    local okCoreGui, coreGui = pcall(function()
        return CoreGui
    end)
    if okCoreGui and coreGui then
        return coreGui
    end

    return localPlayer:WaitForChild("PlayerGui")
end

local function getOrCreateBoxGui()
    if boxGui and boxGui.Parent then
        return boxGui
    end

    local parent = resolveUiParent()
    local existing = parent:FindFirstChild("TomtomFHBoxes")
    if existing then
        existing:Destroy()
    end

    boxGui = Instance.new("ScreenGui")
    boxGui.Name = "TomtomFHBoxes"
    boxGui.DisplayOrder = 999998
    boxGui.IgnoreGuiInset = true
    boxGui.ResetOnSpawn = false
    boxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    boxGui.Parent = parent

    return boxGui
end

local function create2DBox(player)
    if boxFrames2D[player] then
        return boxFrames2D[player]
    end

    local frame = Instance.new("Frame")
    frame.Name = player.Name .. "_2DBox"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 10
    frame.Parent = getOrCreateBoxGui()

    local stroke = Instance.new("UIStroke")
    stroke.Color = boxColor
    stroke.Thickness = 2
    stroke.Transparency = 0
    stroke.Parent = frame

    boxFrames2D[player] = frame
    return frame
end

local function remove2DBox(player)
    local frame = boxFrames2D[player]
    if frame then
        frame:Destroy()
        boxFrames2D[player] = nil
    end
end

local function create3DBox(player)
    if boxAdornments3D[player] then
        return boxAdornments3D[player]
    end

    local edges = {}
    local parent = getOrCreateBoxGui()

    for index = 1, 12 do
        local edge = Instance.new("BoxHandleAdornment")
        edge.Name = player.Name .. "_3DBoxEdge_" .. tostring(index)
        edge.AlwaysOnTop = true
        edge.Color3 = boxColor
        edge.Transparency = 0
        edge.ZIndex = 10
        edge.Visible = false
        edge.Parent = parent

        edges[index] = edge
    end

    boxAdornments3D[player] = edges
    return edges
end

local function remove3DBox(player)
    local edges = boxAdornments3D[player]
    if edges then
        for _, edge in ipairs(edges) do
            edge:Destroy()
        end
        boxAdornments3D[player] = nil
    end
end

local function createPlayerInfoOverlay(player)
    if playerInfoOverlays[player] then
        return playerInfoOverlays[player]
    end

    local parent = getOrCreateBoxGui()

    local healthBar = Instance.new("Frame")
    healthBar.Name = player.Name .. "_HealthBar"
    healthBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    healthBar.BorderSizePixel = 0
    healthBar.Visible = false
    healthBar.ZIndex = 11
    healthBar.Parent = parent

    local healthFill = Instance.new("Frame")
    healthFill.Name = "Fill"
    healthFill.AnchorPoint = Vector2.new(0, 1)
    healthFill.BackgroundColor3 = Color3.fromRGB(255, 35, 35)
    healthFill.BorderSizePixel = 0
    healthFill.Position = UDim2.fromScale(0, 1)
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.ZIndex = 12
    healthFill.Parent = healthBar

    local healthStroke = Instance.new("UIStroke")
    healthStroke.Color = Color3.fromRGB(0, 0, 0)
    healthStroke.Thickness = 1
    healthStroke.Parent = healthBar

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = player.Name .. "_Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.BorderSizePixel = 0
    nameLabel.Size = UDim2.fromOffset(150, 18)
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    nameLabel.Visible = false
    nameLabel.ZIndex = 11
    nameLabel.Parent = parent

    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = Color3.fromRGB(0, 0, 0)
    nameStroke.Thickness = 1.5
    nameStroke.Parent = nameLabel

    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = player.Name .. "_HealthLabel"
    healthLabel.BackgroundTransparency = 1
    healthLabel.BorderSizePixel = 0
    healthLabel.Size = UDim2.fromOffset(150, 18)
    healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthLabel.TextSize = 12
    healthLabel.TextXAlignment = Enum.TextXAlignment.Left
    healthLabel.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    healthLabel.Visible = false
    healthLabel.ZIndex = 11
    healthLabel.Parent = parent

    local labelStroke = Instance.new("UIStroke")
    labelStroke.Color = Color3.fromRGB(0, 0, 0)
    labelStroke.Thickness = 1.5
    labelStroke.Parent = healthLabel

    local overlay = {
        HealthBar = healthBar,
        HealthFill = healthFill,
        NameLabel = nameLabel,
        HealthLabel = healthLabel
    }

    playerInfoOverlays[player] = overlay
    return overlay
end

local function hidePlayerInfoOverlay(player)
    local overlay = playerInfoOverlays[player]
    if not overlay then
        return
    end

    overlay.HealthBar.Visible = false
    overlay.NameLabel.Visible = false
    overlay.HealthLabel.Visible = false
end

local function removePlayerInfoOverlay(player)
    local overlay = playerInfoOverlays[player]
    if not overlay then
        return
    end

    overlay.HealthBar:Destroy()
    overlay.NameLabel:Destroy()
    overlay.HealthLabel:Destroy()
    playerInfoOverlays[player] = nil
end

local function clear2DBoxes()
    for player in pairs(boxFrames2D) do
        remove2DBox(player)
    end
end

local function clear3DBoxes()
    for player in pairs(boxAdornments3D) do
        remove3DBox(player)
    end
end

local function clearAllBoxes()
    clear2DBoxes()
    clear3DBoxes()

    for player in pairs(playerInfoOverlays) do
        removePlayerInfoOverlay(player)
    end
end

local function getCharacterBounds(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    local ok, boxCFrame, boxSize = pcall(function()
        return character:GetBoundingBox()
    end)
    if not ok then
        return nil
    end

    return boxCFrame, boxSize
end

local function getCharacterCorners(character)
    local boxCFrame, boxSize = getCharacterBounds(character)
    if not boxCFrame or not boxSize then
        return nil
    end

    local corners = {}
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                corners[#corners + 1] =
                    boxCFrame.Position
                    + boxCFrame.RightVector * boxSize.X * 0.5 * x
                    + boxCFrame.UpVector * boxSize.Y * 0.5 * y
                    + boxCFrame.LookVector * boxSize.Z * 0.5 * z
            end
        end
    end

    return corners
end

local function getScreenBounds(corners)
    camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local onScreen = false

    for _, corner in ipairs(corners) do
        local viewportPoint, visible = camera:WorldToViewportPoint(corner)
        if visible then
            onScreen = true
        end

        minX = math.min(minX, viewportPoint.X)
        minY = math.min(minY, viewportPoint.Y)
        maxX = math.max(maxX, viewportPoint.X)
        maxY = math.max(maxY, viewportPoint.Y)
    end

    if not onScreen or maxX <= minX or maxY <= minY then
        return nil
    end

    return minX, minY, maxX, maxY
end

local function getHealthInfo(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.MaxHealth <= 0 then
        return 0, 0, 0
    end

    local health = math.max(0, humanoid.Health)
    local maxHealth = math.max(1, humanoid.MaxHealth)
    local percent = math.clamp(health / maxHealth, 0, 1)

    return health, maxHealth, percent
end

local function getHealthColor(healthPercent)
    if healthPercent > 0.75 then
        return Color3.fromRGB(40, 220, 80)
    elseif healthPercent > 0.5 then
        return Color3.fromRGB(255, 220, 45)
    elseif healthPercent > 0.25 then
        return Color3.fromRGB(255, 135, 35)
    end

    return Color3.fromRGB(255, 35, 35)
end

local function updatePlayerInfoOverlay(player, minX, minY, maxX, maxY)
    local overlay = createPlayerInfoOverlay(player)
    local health, _, healthPercent = getHealthInfo(player.Character)
    local boxHeight = maxY - minY
    local infoX = maxX + 14
    local healthBarX = maxX + 6

    overlay.NameLabel.Text = player.Name
    overlay.NameLabel.Position = UDim2.fromOffset(infoX, minY)
    overlay.NameLabel.Visible = true

    overlay.HealthBar.Position = UDim2.fromOffset(healthBarX, minY)
    overlay.HealthBar.Size = UDim2.fromOffset(4, boxHeight)
    overlay.HealthBar.Visible = healthBarEnabled
    overlay.HealthFill.BackgroundColor3 = getHealthColor(healthPercent)
    overlay.HealthFill.Size = UDim2.fromScale(1, healthPercent)

    overlay.HealthLabel.Text = string.format("%d HP (%d%%)", math.floor(health + 0.5), math.floor((healthPercent * 100) + 0.5))
    overlay.HealthLabel.Position = UDim2.fromOffset(infoX, minY + 17)
    overlay.HealthLabel.Visible = healthLabelEnabled
end

local function update2DBox(player)
    local frame = create2DBox(player)
    local corners = getCharacterCorners(player.Character)

    if not corners then
        frame.Visible = false
        hidePlayerInfoOverlay(player)
        return
    end

    local minX, minY, maxX, maxY = getScreenBounds(corners)
    if not minX then
        frame.Visible = false
        hidePlayerInfoOverlay(player)
        return
    end

    frame.Position = UDim2.fromOffset(minX, minY)
    frame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
    frame.Visible = true

    local stroke = frame:FindFirstChildWhichIsA("UIStroke")
    if stroke then
        stroke.Color = getBoxColor(player)
    end

    updatePlayerInfoOverlay(player, minX, minY, maxX, maxY)
end

local function update3DBox(player)
    local edges = create3DBox(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local boxCFrame, boxSize = getCharacterBounds(character)

    if not root or not boxCFrame or not boxSize then
        for _, edge in ipairs(edges) do
            edge.Visible = false
        end
        hidePlayerInfoOverlay(player)
        return
    end

    local thickness = box3DEdgeThickness
    local halfX = boxSize.X * 0.5
    local halfY = boxSize.Y * 0.5
    local halfZ = boxSize.Z * 0.5
    local edgeIndex = 1

    local function setEdge(axis, offset)
        local edge = edges[edgeIndex]
        edgeIndex = edgeIndex + 1

        if axis == "X" then
            edge.Size = Vector3.new(boxSize.X, thickness, thickness)
        elseif axis == "Y" then
            edge.Size = Vector3.new(thickness, boxSize.Y, thickness)
        else
            edge.Size = Vector3.new(thickness, thickness, boxSize.Z)
        end

        edge.Adornee = root
        edge.Color3 = getBoxColor(player)
        edge.CFrame = root.CFrame:ToObjectSpace(boxCFrame * CFrame.new(offset))
        edge.Visible = true
    end

    setEdge("X", Vector3.new(0, halfY, halfZ))
    setEdge("X", Vector3.new(0, halfY, -halfZ))
    setEdge("X", Vector3.new(0, -halfY, halfZ))
    setEdge("X", Vector3.new(0, -halfY, -halfZ))

    setEdge("Y", Vector3.new(halfX, 0, halfZ))
    setEdge("Y", Vector3.new(halfX, 0, -halfZ))
    setEdge("Y", Vector3.new(-halfX, 0, halfZ))
    setEdge("Y", Vector3.new(-halfX, 0, -halfZ))

    setEdge("Z", Vector3.new(halfX, halfY, 0))
    setEdge("Z", Vector3.new(halfX, -halfY, 0))
    setEdge("Z", Vector3.new(-halfX, halfY, 0))
    setEdge("Z", Vector3.new(-halfX, -halfY, 0))

    local corners = getCharacterCorners(character)
    local minX, minY, maxX, maxY
    if corners then
        minX, minY, maxX, maxY = getScreenBounds(corners)
    end

    if minX then
        updatePlayerInfoOverlay(player, minX, minY, maxX, maxY)
    else
        hidePlayerInfoOverlay(player)
    end
end

local function updateBoxes()
    if boxStyle == "2D" then
        clear3DBoxes()
    elseif boxStyle == "3D" then
        clear2DBoxes()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if boxStyle == "3D" then
                update3DBox(player)
            else
                update2DBox(player)
            end
        end
    end

    for player in pairs(boxFrames2D) do
        if player.Parent ~= Players then
            remove2DBox(player)
        end
    end

    for player in pairs(boxAdornments3D) do
        if player.Parent ~= Players then
            remove3DBox(player)
        end
    end

    for player in pairs(playerInfoOverlays) do
        if player.Parent ~= Players then
            removePlayerInfoOverlay(player)
        end
    end
end

local function enableBoxes()
    if boxesEnabled then
        return
    end

    boxesEnabled = true
    getOrCreateBoxGui()
    updateBoxes()

    boxConnection = RunService.RenderStepped:Connect(function()
        updateBoxes()
    end)
end

local function disableBoxes()
    boxesEnabled = false

    if boxConnection then
        boxConnection:Disconnect()
        boxConnection = nil
    end

    clearAllBoxes()
end

local function setBoxStyle(style)
    boxStyle = style == "3D" and "3D" or "2D"
    clearAllBoxes()

    if boxesEnabled then
        updateBoxes()
    end
end

local function setHealthBarEnabled(enabled)
    healthBarEnabled = enabled

    if boxesEnabled then
        updateBoxes()
    else
        for player in pairs(playerInfoOverlays) do
            hidePlayerInfoOverlay(player)
        end
    end
end

local function setHealthLabelEnabled(enabled)
    healthLabelEnabled = enabled

    if boxesEnabled then
        updateBoxes()
    else
        for player in pairs(playerInfoOverlays) do
            hidePlayerInfoOverlay(player)
        end
    end
end

local function setUseTeamColorEnabled(enabled)
    useTeamColorEnabled = enabled

    if boxesEnabled then
        updateBoxes()
    end
end

Players.PlayerRemoving:Connect(function(player)
    remove2DBox(player)
    remove3DBox(player)
    removePlayerInfoOverlay(player)
end)

CreateMenu("Combat")
CreateGroup("Combat", "Main")
CreateTab("Combat", "Main", "Visuals")

CreateDropdown("Visuals", "Box Style", {"2D", "3D"}, function(value)
    setBoxStyle(value)
end, boxStyle)

CreateToggle("Visuals", "Boxes", function(state)
    if state.Value then
        enableBoxes()
    else
        disableBoxes()
    end
end, boxesEnabled)

CreateToggle("Visuals", "Health Bar", function(state)
    setHealthBarEnabled(state.Value)
end, healthBarEnabled)

CreateToggle("Visuals", "Health Label", function(state)
    setHealthLabelEnabled(state.Value)
end, healthLabelEnabled)

CreateToggle("Visuals", "Use Team Color", function(state)
    setUseTeamColorEnabled(state.Value)
end, useTeamColorEnabled)

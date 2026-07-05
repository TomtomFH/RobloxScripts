local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local boxesEnabled = false
local boxStyle = "2D"
local healthBarEnabled = false
local healthLabelEnabled = false
local useTeamColorEnabled = false
local tracersEnabled = false
local outlinesEnabled = false
local tracerStartPosition = "Bottom"
local ignoreTeammatesEnabled = false
local aimbotEnabled = false
local aimbotAimPart = "Head"
local aimbotTeamCheckEnabled = true
local aimbotWallCheckEnabled = true
local rightMouseHeld = false
local aimbotConnection = nil
local boxGui = nil
local boxConnection = nil
local boxFrames2D = {}
local boxAdornments3D = {}
local playerInfoOverlays = {}
local tracerLines = {}
local characterOutlines = {}
local box3DEdgeThickness = 0.1
local boxColor = Color3.fromRGB(255, 255, 255)

local function getBoxColor(player)
    if useTeamColorEnabled and player.Team then
        return player.TeamColor.Color
    end

    return boxColor
end

local function isTeammate(player)
    return localPlayer.Team ~= nil and player.Team == localPlayer.Team
end

local function shouldDrawEspForPlayer(player)
    return player ~= localPlayer and player.Parent == Players and not (ignoreTeammatesEnabled and isTeammate(player))
end

local function shouldAimAtPlayer(player)
    return player ~= localPlayer and player.Parent == Players and not (aimbotTeamCheckEnabled and isTeammate(player))
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

local function createTracerLine(player)
    if tracerLines[player] then
        return tracerLines[player]
    end

    local line = Instance.new("Frame")
    line.Name = player.Name .. "_Tracer"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = boxColor
    line.BorderSizePixel = 0
    line.Visible = false
    line.ZIndex = 9
    line.Parent = getOrCreateBoxGui()

    tracerLines[player] = line
    return line
end

local function removeTracerLine(player)
    local line = tracerLines[player]
    if line then
        line:Destroy()
        tracerLines[player] = nil
    end
end

local function clearTracers()
    for player in pairs(tracerLines) do
        removeTracerLine(player)
    end
end

local function createCharacterOutline(player, character)
    local existingHighlight = characterOutlines[player]
    if existingHighlight and existingHighlight.Parent then
        existingHighlight.Parent = character
        existingHighlight.Adornee = character
        return existingHighlight
    elseif existingHighlight then
        characterOutlines[player] = nil
    end

    local existingCharacterHighlight = character:FindFirstChild(player.Name .. "_Outline")
    if existingCharacterHighlight and existingCharacterHighlight:IsA("Highlight") then
        characterOutlines[player] = existingCharacterHighlight
        return characterOutlines[player]
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name .. "_Outline"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 1
    highlight.OutlineColor = boxColor
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Adornee = character
    highlight.Parent = character

    characterOutlines[player] = highlight
    return highlight
end

local function removeCharacterOutline(player)
    local highlight = characterOutlines[player]
    if highlight then
        highlight:Destroy()
        characterOutlines[player] = nil
    end
end

local function clearCharacterOutlines()
    for player in pairs(characterOutlines) do
        removeCharacterOutline(player)
    end
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

local function clearAllEsp()
    clearAllBoxes()
    clearTracers()
    clearCharacterOutlines()
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

local function getTracerStartPoint()
    camera = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(0, 0)
    local x = viewportSize.X * 0.5

    if tracerStartPosition == "Top" then
        return Vector2.new(x, 0)
    elseif tracerStartPosition == "Center" then
        return Vector2.new(x, viewportSize.Y * 0.5)
    end

    return Vector2.new(x, viewportSize.Y)
end

local function updateTracerLine(player, minX, minY, maxX, maxY)
    if not tracersEnabled or not minX then
        local existingLine = tracerLines[player]
        if existingLine then
            existingLine.Visible = false
        end
        return
    end

    local line = createTracerLine(player)

    local startPoint = getTracerStartPoint()
    local targetPoint = Vector2.new((minX + maxX) * 0.5, maxY)
    local difference = targetPoint - startPoint
    local distance = difference.Magnitude

    if distance <= 0 then
        line.Visible = false
        return
    end

    line.Position = UDim2.fromOffset((startPoint.X + targetPoint.X) * 0.5, (startPoint.Y + targetPoint.Y) * 0.5)
    line.Size = UDim2.fromOffset(distance, 2)
    line.Rotation = math.deg(math.atan2(difference.Y, difference.X))
    line.BackgroundColor3 = getBoxColor(player)
    line.Visible = true
end

local function updateCharacterOutline(player)
    if not outlinesEnabled then
        local existingHighlight = characterOutlines[player]
        if existingHighlight then
            existingHighlight.Enabled = false
        end
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not character or not humanoid or humanoid.Health <= 0 then
        local highlight = characterOutlines[player]
        if highlight then
            highlight.Enabled = false
        end
        return
    end

    local highlight = createCharacterOutline(player, character)
    if not highlight then
        return
    end

    if highlight.Adornee ~= character then
        highlight.Adornee = character
    end

    if highlight.Parent ~= character then
        highlight.Parent = character
    end

    if not character.Parent then
        highlight.Enabled = false
        return
    end

    highlight.OutlineColor = getBoxColor(player)
    highlight.Enabled = true
end

local function update2DBox(player)
    local frame = boxesEnabled and create2DBox(player) or boxFrames2D[player]
    local corners = getCharacterCorners(player.Character)

    if not corners then
        if frame then
            frame.Visible = false
        end
        hidePlayerInfoOverlay(player)
        updateTracerLine(player)
        return
    end

    local minX, minY, maxX, maxY = getScreenBounds(corners)
    if not minX then
        if frame then
            frame.Visible = false
        end
        hidePlayerInfoOverlay(player)
        updateTracerLine(player)
        return
    end

    if boxesEnabled then
        frame.Position = UDim2.fromOffset(minX, minY)
        frame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
        frame.Visible = true

        local stroke = frame:FindFirstChildWhichIsA("UIStroke")
        if stroke then
            stroke.Color = getBoxColor(player)
        end
    else
        if frame then
            frame.Visible = false
        end
    end

    if boxesEnabled then
        updatePlayerInfoOverlay(player, minX, minY, maxX, maxY)
    else
        hidePlayerInfoOverlay(player)
    end

    updateTracerLine(player, minX, minY, maxX, maxY)
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
        updateTracerLine(player)
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

    if boxesEnabled then
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
    else
        for _, edge in ipairs(edges) do
            edge.Visible = false
        end
    end

    local corners = getCharacterCorners(character)
    local minX, minY, maxX, maxY
    if corners then
        minX, minY, maxX, maxY = getScreenBounds(corners)
    end

    if minX and boxesEnabled then
        updatePlayerInfoOverlay(player, minX, minY, maxX, maxY)
    else
        hidePlayerInfoOverlay(player)
    end

    updateTracerLine(player, minX, minY, maxX, maxY)
end

local function updateBoxes()
    if boxesEnabled and boxStyle == "2D" then
        clear3DBoxes()
    elseif boxesEnabled and boxStyle == "3D" then
        clear2DBoxes()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if shouldDrawEspForPlayer(player) then
            updateCharacterOutline(player)

            if boxesEnabled or tracersEnabled then
                if boxesEnabled and boxStyle == "3D" then
                    update3DBox(player)
                else
                    update2DBox(player)
                end
            end
        else
            remove2DBox(player)
            remove3DBox(player)
            removePlayerInfoOverlay(player)
            removeTracerLine(player)
            removeCharacterOutline(player)
        end
    end

    for player in pairs(boxFrames2D) do
        if not shouldDrawEspForPlayer(player) then
            remove2DBox(player)
        end
    end

    for player in pairs(boxAdornments3D) do
        if not shouldDrawEspForPlayer(player) then
            remove3DBox(player)
        end
    end

    for player in pairs(playerInfoOverlays) do
        if not shouldDrawEspForPlayer(player) then
            removePlayerInfoOverlay(player)
        end
    end

    for player in pairs(tracerLines) do
        if not shouldDrawEspForPlayer(player) then
            removeTracerLine(player)
        end
    end

    for player in pairs(characterOutlines) do
        if not shouldDrawEspForPlayer(player) then
            removeCharacterOutline(player)
        end
    end
end

local function startVisualsLoop()
    if boxConnection then
        return
    end

    getOrCreateBoxGui()
    updateBoxes()

    boxConnection = RunService.RenderStepped:Connect(function()
        updateBoxes()
    end)
end

local function stopVisualsLoopIfIdle()
    if boxesEnabled or tracersEnabled or outlinesEnabled then
        return
    end

    if boxConnection then
        boxConnection:Disconnect()
        boxConnection = nil
    end
end

local function enableBoxes()
    if boxesEnabled then
        return
    end

    boxesEnabled = true
    startVisualsLoop()
end

local function disableBoxes()
    boxesEnabled = false

    clearAllBoxes()
    stopVisualsLoopIfIdle()
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

    if boxesEnabled or tracersEnabled or outlinesEnabled then
        updateBoxes()
    end
end

local function setTracersEnabled(enabled)
    tracersEnabled = enabled

    if tracersEnabled then
        startVisualsLoop()
    else
        clearTracers()
        stopVisualsLoopIfIdle()
    end
end

local function setOutlinesEnabled(enabled)
    outlinesEnabled = enabled

    if outlinesEnabled then
        startVisualsLoop()
    else
        clearCharacterOutlines()
        stopVisualsLoopIfIdle()
    end
end

local function setTracerStartPosition(position)
    if position == "Top" or position == "Center" or position == "Bottom" then
        tracerStartPosition = position
    else
        tracerStartPosition = "Bottom"
    end

    if tracersEnabled then
        updateBoxes()
    end
end

local function setIgnoreTeammatesEnabled(enabled)
    ignoreTeammatesEnabled = enabled

    if boxesEnabled or tracersEnabled or outlinesEnabled then
        updateBoxes()
    else
        clearAllEsp()
    end
end

local function getAimPart(character)
    if not character then
        return nil
    end

    if aimbotAimPart == "Head" then
        return character:FindFirstChild("Head")
    end

    return character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function hasAimbotLineOfSight(targetPart, targetCharacter)
    if not aimbotWallCheckEnabled then
        return true
    end

    camera = workspace.CurrentCamera
    if not camera or not targetPart or not targetCharacter then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {localPlayer.Character}
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, raycastParams)
    return not result or result.Instance:IsDescendantOf(targetCharacter)
end

local function getClosestAimTarget()
    camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local mousePosition = UserInputService:GetMouseLocation()
    local closestPart = nil
    local closestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if shouldAimAtPlayer(player) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local aimPart = getAimPart(character)

            if humanoid and humanoid.Health > 0 and aimPart and hasAimbotLineOfSight(aimPart, character) then
                local viewportPoint, visible = camera:WorldToViewportPoint(aimPart.Position)
                if visible and viewportPoint.Z > 0 then
                    local screenPosition = Vector2.new(viewportPoint.X, viewportPoint.Y)
                    local distance = (screenPosition - mousePosition).Magnitude

                    if distance < closestDistance then
                        closestDistance = distance
                        closestPart = aimPart
                    end
                end
            end
        end
    end

    return closestPart
end

local function updateAimbot()
    if not aimbotEnabled or not rightMouseHeld then
        return
    end

    camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local targetPart = getClosestAimTarget()
    if targetPart then
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
    end
end

local function startAimbotLoop()
    if aimbotConnection then
        return
    end

    aimbotConnection = RunService.RenderStepped:Connect(function()
        updateAimbot()
    end)
end

local function stopAimbotLoop()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
end

local function setAimbotAimPart(partName)
    if partName == "Head" or partName == "Torso" then
        aimbotAimPart = partName
    else
        aimbotAimPart = "Head"
    end
end

local function setAimbotEnabled(enabled)
    aimbotEnabled = enabled

    if aimbotEnabled then
        startAimbotLoop()
    else
        stopAimbotLoop()
    end
end

local function setAimbotTeamCheckEnabled(enabled)
    aimbotTeamCheckEnabled = enabled
end

local function setAimbotWallCheckEnabled(enabled)
    aimbotWallCheckEnabled = enabled
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightMouseHeld = false
    end
end)

Players.PlayerRemoving:Connect(function(player)
    remove2DBox(player)
    remove3DBox(player)
    removePlayerInfoOverlay(player)
    removeTracerLine(player)
    removeCharacterOutline(player)
end)

CreateMenu("Combat")
CreateGroup("Combat", "Main")
CreateTab("Combat", "Main", "Visuals")
CreateTab("Combat", "Main", "Aimbot")

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

CreateToggle("Visuals", "Tracers", function(state)
    setTracersEnabled(state.Value)
end, tracersEnabled)

CreateToggle("Visuals", "Outline", function(state)
    setOutlinesEnabled(state.Value)
end, outlinesEnabled)

CreateDropdown("Visuals", "Tracer Start", {"Top", "Center", "Bottom"}, function(value)
    setTracerStartPosition(value)
end, tracerStartPosition)

CreateToggle("Visuals", "Health Bar", function(state)
    setHealthBarEnabled(state.Value)
end, healthBarEnabled)

CreateToggle("Visuals", "Health Label", function(state)
    setHealthLabelEnabled(state.Value)
end, healthLabelEnabled)

CreateToggle("Visuals", "Use Team Color", function(state)
    setUseTeamColorEnabled(state.Value)
end, useTeamColorEnabled)

CreateToggle("Visuals", "Ignore Teammates", function(state)
    setIgnoreTeammatesEnabled(state.Value)
end, ignoreTeammatesEnabled)

CreateDropdown("Aimbot", "Aim Part", {"Head", "Torso"}, function(value)
    setAimbotAimPart(value)
end, aimbotAimPart)

CreateToggle("Aimbot", "Aimbot", function(state)
    setAimbotEnabled(state.Value)
end, aimbotEnabled)

CreateToggle("Aimbot", "Team Check", function(state)
    setAimbotTeamCheckEnabled(state.Value)
end, aimbotTeamCheckEnabled)

CreateToggle("Aimbot", "Wall Check", function(state)
    setAimbotWallCheckEnabled(state.Value)
end, aimbotWallCheckEnabled)

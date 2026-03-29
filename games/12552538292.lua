-- PRESSURE (https://www.roblox.com/games/12552538292/)
-- PART: Hadal Blacksite

-- Visual Node Path: inlined below (previously loaded remotely)

local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local gameplayFolder = workspace:WaitForChild("GameplayFolder", 60)
local roomsFolder = gameplayFolder:WaitForChild("Rooms", 60)
local monstersFolder = gameplayFolder:WaitForChild("Monsters", 60)

local player = players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()

-- BEGIN Inlined Node Visualizer
local do_node_visualizer = true
local nodeRoomDrawn = {}
local nodeInterRoomBeams = {}
local nodeRoomParts = {}
local nodeOriginalTransparency = {}
local nodeVisualizerEnabled = false

local function node_getConnections(part)
    local folder = part and part:FindFirstChild("Connections")
    if not folder then return {} end
    local t = {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("ObjectValue") and obj.Value then
            table.insert(t, obj.Value)
        end
    end
    return t
end

local function node_buildPath(startNode, endNode)
    if not startNode or not endNode then return nil end
    local queue = {startNode}
    local visited = {[startNode] = true}
    local parent = {}
    local found = false
    while #queue > 0 do
        local current = table.remove(queue, 1)
        if current == endNode then found = true; break end
        for _, nxt in ipairs(node_getConnections(current)) do
            if nxt and not visited[nxt] then
                visited[nxt] = true
                parent[nxt] = current
                table.insert(queue, nxt)
            end
        end
    end
    if not found then return nil end
    local path = {}
    local n = endNode
    while n do
        table.insert(path, 1, n)
        n = parent[n]
    end
    return path
end

local function node_drawPath(path, room)
    if not path then return end
    nodeRoomDrawn[room] = nodeRoomDrawn[room] or {}
    for _, part in ipairs(path) do
        if part and part:IsA("BasePart") then
            if nodeOriginalTransparency[part] == nil then
                nodeOriginalTransparency[part] = part.Transparency
            end
            part.Transparency = 0
            if room then
                nodeRoomParts[room] = nodeRoomParts[room] or {}
                nodeRoomParts[room][part] = true
            end
        end
    end
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local att0 = Instance.new("Attachment")
            att0.Parent = a
            local att1 = Instance.new("Attachment")
            att1.Parent = b
            local beam = Instance.new("Beam")
            beam.Attachment0 = att0
            beam.Attachment1 = att1
            beam.FaceCamera = true
            beam.Width0 = 0.2
            beam.Width1 = 0.2
            beam.Parent = a
            table.insert(nodeRoomDrawn[room], att0)
            table.insert(nodeRoomDrawn[room], att1)
            table.insert(nodeRoomDrawn[room], beam)
        end
    end
end

local function node_clearRoomDrawings(room)
    local list = nodeRoomDrawn[room]
    if list then
        for _, inst in ipairs(list) do
            if inst and inst.Parent then pcall(function() inst:Destroy() end) end
        end
        nodeRoomDrawn[room] = nil
    end
    if nodeInterRoomBeams[room] then
        for _, b in ipairs(nodeInterRoomBeams[room]) do
            if b and b.Parent then pcall(function() b:Destroy() end) end
        end
        nodeInterRoomBeams[room] = nil
    end
    if nodeRoomParts[room] then
        for part,_ in pairs(nodeRoomParts[room]) do
            if part then
                if nodeOriginalTransparency[part] ~= nil then
                    pcall(function() part.Transparency = nodeOriginalTransparency[part] end)
                    nodeOriginalTransparency[part] = nil
                else
                    pcall(function() part.Transparency = 1 end)
                end
            end
        end
        nodeRoomParts[room] = nil
    end
end

local function node_getClosestExitNode(entrance, nodesFolder)
    if not nodesFolder then return nil end
    local closestExit = nil
    local closestDistance = math.huge
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") and node.Name:match("Exit") then
            local ok, dist = pcall(function() return (node.Position - entrance.Position).Magnitude end)
            if ok and dist and dist < closestDistance then
                closestDistance = dist
                closestExit = node
            end
        end
    end
    return closestExit
end

local function node_validateAndFixNodeConnections(room)
    task.spawn(function()
        while true do
            local nodesFolder = room:FindFirstChild("EntityNodes")
            if nodesFolder then
                for _, node in ipairs(nodesFolder:GetChildren()) do
                    if node and node:IsA("BasePart") then
                        local conFolder = node:FindFirstChild("Connections")
                        if not conFolder then
                            conFolder = Instance.new("Folder")
                            conFolder.Name = "Connections"
                            conFolder.Parent = node
                        end
                        local prevExists = conFolder:FindFirstChild("Previous") and conFolder.Previous:IsA("ObjectValue") and conFolder.Previous.Value ~= nil
                        local nextExists = conFolder:FindFirstChild("Next") and conFolder.Next:IsA("ObjectValue") and conFolder.Next.Value ~= nil
                        if not conFolder:FindFirstChild("Previous") then
                            local prev = Instance.new("ObjectValue") prev.Name = "Previous" prev.Parent = conFolder
                        end
                        if not conFolder:FindFirstChild("Next") then
                            local next = Instance.new("ObjectValue") next.Name = "Next" next.Parent = conFolder
                        end
                        if not prevExists then
                            local allNodes = nodesFolder:GetChildren()
                            local closestPrev, closestDist = nil, math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local ok, dist = pcall(function() return (node.Position - other.Position).Magnitude end)
                                    if ok and dist and dist < closestDist then closestDist = dist; closestPrev = other end
                                end
                            end
                            if closestPrev then pcall(function() conFolder.Previous.Value = closestPrev end) end
                        end
                        if not nextExists then
                            local allNodes = nodesFolder:GetChildren()
                            local closestNext, closestDist = nil, math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local ok, dist = pcall(function() return (node.Position - other.Position).Magnitude end)
                                    if ok and dist and dist < closestDist then closestDist = dist; closestNext = other end
                                end
                            end
                            if closestNext then pcall(function() conFolder.Next.Value = closestNext end) end
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

local function node_drawRoomNodeConnections(room)
    if not nodeVisualizerEnabled then node_clearRoomDrawings(room); return end
    node_clearRoomDrawings(room)
    local nodesFolder = room and room:FindFirstChild("EntityNodes")
    if not nodesFolder then return end
    nodeRoomDrawn[room] = nodeRoomDrawn[room] or {}
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") then
            local conFolder = node:FindFirstChild("Connections")
            if conFolder then
                for _, child in ipairs(conFolder:GetChildren()) do
                    if child.Name:match("^Previous") and child:IsA("ObjectValue") and child.Value and child.Value:IsA("BasePart") then
                        local a, b = node, child.Value
                        -- record original transparency before changing
                        if nodeOriginalTransparency[a] == nil then nodeOriginalTransparency[a] = a.Transparency end
                        if nodeOriginalTransparency[b] == nil then nodeOriginalTransparency[b] = b.Transparency end
                        nodeRoomParts[room] = nodeRoomParts[room] or {}
                        nodeRoomParts[room][a] = true
                        nodeRoomParts[room][b] = true
                        a.Transparency = 0
                        b.Transparency = 0
                        local att0 = Instance.new("Attachment") att0.Parent = a
                        local att1 = Instance.new("Attachment") att1.Parent = b
                        local beam = Instance.new("Beam") beam.Attachment0 = att0 beam.Attachment1 = att1 beam.FaceCamera = true beam.Width0 = 0.2 beam.Width1 = 0.2 beam.Parent = a
                        table.insert(nodeRoomDrawn[room], att0)
                        table.insert(nodeRoomDrawn[room], att1)
                        table.insert(nodeRoomDrawn[room], beam)
                    end
                end
            end
        end
    end
    local entrance = nodesFolder:FindFirstChild("Entrance")
    if entrance then
        local closestExit = node_getClosestExitNode(entrance, nodesFolder)
        if closestExit then
            local path = node_buildPath(entrance, closestExit)
            if path then node_drawPath(path, room) end
        end
    end
end

local function node_connectRoomInternal(room)
    task.spawn(function()
        while true do
            local nodes = room:FindFirstChild("EntityNodes")
            if nodes then
                if nodeVisualizerEnabled then node_drawRoomNodeConnections(room) end
                break
            end
            task.wait(0.2)
        end
    end)
end

local function node_connectRoomToPrevious(room)
    task.spawn(function()
        while true do
            local entrancesFolder = room:FindFirstChild("Entrances")
            if entrancesFolder then
                if not nodeVisualizerEnabled then
                    if nodeInterRoomBeams[room] then
                        for _, b in ipairs(nodeInterRoomBeams[room]) do if b and b.Parent then pcall(function() b:Destroy() end) end end
                        nodeInterRoomBeams[room] = nil
                    end
                    break
                end
                if nodeInterRoomBeams[room] then
                    for _, beam in ipairs(nodeInterRoomBeams[room]) do if beam and beam.Parent then beam:Destroy() end end
                end
                nodeInterRoomBeams[room] = {}
                local connectedAny = false
                for _, door in ipairs(entrancesFolder:GetChildren()) do
                    local exitRef = door:FindFirstChild("Exit")
                    local enterRef = door:FindFirstChild("Enter")
                    if exitRef and exitRef.Value and enterRef and enterRef.Value then
                        local prevRoom = exitRef.Value
                        local prevNodes = prevRoom:FindFirstChild("EntityNodes")
                        local currNodes = room:FindFirstChild("EntityNodes")
                        if prevNodes and currNodes then
                            local currEntrance = currNodes:FindFirstChild("Entrance")
                            if currEntrance then
                                local prevExit = node_getClosestExitNode(currEntrance, prevNodes)
                                if prevExit and prevExit:IsA("BasePart") and currEntrance:IsA("BasePart") then
                                    local att0 = Instance.new("Attachment") att0.Parent = prevExit
                                    local att1 = Instance.new("Attachment") att1.Parent = currEntrance
                                    local beam = Instance.new("Beam") beam.Attachment0 = att0 beam.Attachment1 = att1 beam.FaceCamera = true beam.Width0 = 0.2 beam.Width1 = 0.2 beam.Parent = prevExit
                                    prevExit.Transparency = 0
                                    currEntrance.Transparency = 0
                                    table.insert(nodeInterRoomBeams[room], beam)
                                    connectedAny = true
                                end
                            end
                        end
                    end
                end
                if connectedAny then break end
            end
            task.wait(0.2)
        end
    end)
end

local function node_setupNodeListener(room)
    task.spawn(function()
        while true do
            local nodes = room:FindFirstChild("EntityNodes")
            if nodes then
                nodes.ChildAdded:Connect(function()
                    node_drawRoomNodeConnections(room)
                    node_connectRoomToPrevious(room)
                end)
                nodes.ChildRemoved:Connect(function()
                    node_drawRoomNodeConnections(room)
                    node_connectRoomToPrevious(room)
                end)
                break
            end
            task.wait(0.2)
        end
    end)
end

local function node_setupRoom(room)
    node_connectRoomInternal(room)
    node_connectRoomToPrevious(room)
    node_setupNodeListener(room)
    node_validateAndFixNodeConnections(room)
end

for _, room in ipairs(roomsFolder:GetChildren()) do node_setupRoom(room) end
roomsFolder.ChildAdded:Connect(function(room) node_setupRoom(room) end)

local function enableVisualizer()
    nodeVisualizerEnabled = true
    for _, room in ipairs(roomsFolder:GetChildren()) do
        node_drawRoomNodeConnections(room)
        node_connectRoomToPrevious(room)
    end
end

local function disableVisualizer()
    nodeVisualizerEnabled = false
    for _, room in ipairs(roomsFolder:GetChildren()) do node_clearRoomDrawings(room) end
end

-- expose for compatibility
_G = _G or {}
_G.NodeVisualizerEnable = enableVisualizer
_G.NodeVisualizerDisable = disableVisualizer
-- END Inlined Node Visualizer

-- Feature manager state and registries
local featureState = {
    ESP = false,
    Tracers = false,
    Fullbright = false,
    NodeVisualizer = false,
    DoorHandling = false,
    ItemESP = false,
    Notifications = false,
    MonsterVisuals = false,
    ForceHidePopups = false,
    DisableEyefestation = false,
    AutoCrouchEvent = false,
}

local activeESPs = {}
local activeTracers = {}
-- Store thread for AutoCrouchEvent
local autoCrouchThread = nil

local function startAutoCrouchEvent()
    if autoCrouchThread then return end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("CrouchEvent")
    autoCrouchThread = task.spawn(function()
        while featureState.AutoCrouchEvent do
            pcall(function()
                remote:FireServer(true)
            end)
            task.wait(0.5)
            pcall(function()
                remote:FireServer(false)
            end)
            task.wait(0.5)
        end
        autoCrouchThread = nil
    end)
end

local function stopAutoCrouchEvent()
    featureState.AutoCrouchEvent = false
    -- thread will exit on next loop
end
-- Store connections for Eyefestation disabling
local eyefestationConns = {}

local function setEyefestationActiveFalse(eyefestation)
    local active = eyefestation:WaitForChild("Active")
    if active and active:IsA("BoolValue") then
        active.Value = false
        -- Listen for changes and force off
        local conn = active:GetPropertyChangedSignal("Value"):Connect(function()
            if featureState.DisableEyefestation then
                active.Value = false
            end
        end)
        table.insert(eyefestationConns, conn)
    end
end

local function scanAndDisableAllEyefestation()
    -- Disconnect previous
    for _,conn in ipairs(eyefestationConns) do pcall(function() conn:Disconnect() end) end
    eyefestationConns = {}
    -- Find all Eyefestation descendants in workspace
    for _, obj in ipairs(workspace.GameplayFolder.Rooms:GetDescendants()) do
        if obj.Name == "Eyefestation" and obj:IsA("Model") then
            setEyefestationActiveFalse(obj)
        end
    end
end

local function setupEyefestationListener()
    -- Listen for new Eyefestation folders
    local conn = workspace.GameplayFolder.Rooms.DescendantAdded:Connect(function(obj)
        if featureState.DisableEyefestation and obj.Name == "Eyefestation" and obj:IsA("Model") then
            setEyefestationActiveFalse(obj)
        end
    end)
    table.insert(eyefestationConns, conn)
end

local function cleanupEyefestationConns()
    for _,conn in ipairs(eyefestationConns) do pcall(function() conn:Disconnect() end) end
    eyefestationConns = {}
end

-- Store connection for cleanup
local popupsConn = nil

local function setPopupsVisibleFalse()
    local main = playerGui:WaitForChild("Main")
    if not main then return end
    local popups = main:WaitForChild("Popups")
    if not popups then return end
    popups.Visible = false
    if popupsConn then pcall(function() popupsConn:Disconnect() end) popupsConn = nil end
    popupsConn = popups:GetPropertyChangedSignal("Visible"):Connect(function()
        if featureState.ForceHidePopups then
            popups.Visible = false
        end
    end)
end

local function cleanupPopupsConn()
    if popupsConn then pcall(function() popupsConn:Disconnect() end) popupsConn = nil end
    local main = playerGui:WaitForChild("Main")
    if not main then return end
    local popups = main:WaitForChild("Popups")
    if not popups then return end
    popups.Visible = true
end

-- store original lighting so we can restore when toggled off
local originalLighting = {
    Brightness = lighting.Brightness,
    ClockTime = lighting.ClockTime,
    FogEnd = lighting.FogEnd,
    GlobalShadows = lighting.GlobalShadows,
    OutdoorAmbient = lighting.OutdoorAmbient,
}

local function applyFullbright()
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function restoreLighting()
    lighting.Brightness = originalLighting.Brightness
    lighting.ClockTime = originalLighting.ClockTime
    lighting.FogEnd = originalLighting.FogEnd
    lighting.GlobalShadows = originalLighting.GlobalShadows
    lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

-- Load UI Library
loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

-- FULLBRIGHT
-- Fullbright is off by default; use UI toggle to enable

local function splitCamelCase(name)
    return name:gsub("(%l)(%u)", "%1 %2")
end

local function CreateNotification(text, color, duration)
    if not featureState.Notifications then return end
    duration = duration or 2.5
    color = color or Color3.fromRGB(255, 0, 0)

    local gui = Instance.new("ScreenGui")
    gui.Name = "NotificationGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 120)
    label.Position = UDim2.new(0, 0, 0.3, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = text
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextTransparency = 1
    label.Parent = gui

    local fadeIn = tweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 0, TextStrokeTransparency = 0.5})
    fadeIn:Play()

    fadeIn.Completed:Connect(function()
        task.delay(duration, function()
            local fadeOut = tweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1})
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                gui:Destroy()
            end)
        end)
    end)
end

local function createESP(target, color, customName)
    local b = Instance.new("BillboardGui")
    b.Name = "ESPBillboard"
    b.Adornee = target
    b.AlwaysOnTop = true
    b.Size = UDim2.new(0, 100, 0, 100)
    b.Parent = target

    local f = Instance.new("Frame")
    f.Parent = b
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color or Color3.new(1, 1, 1)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(0, 10, 0, 10)

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = f

    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.5, 0.5, 0.5))
    g.Rotation = 90
    g.Parent = f

    local s = Instance.new("UIStroke")
    s.Thickness = 2.5
    s.Parent = f

    local l = Instance.new("TextLabel")
    l.Parent = b
    l.AnchorPoint = Vector2.new(0, 0.5)
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 0, 0.5, 24)
    l.Size = UDim2.new(1, 0, 0.2, 0)
    l.Text = customName or splitCamelCase(target.Name)
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.TextScaled = true

    local ls = Instance.new("UIStroke")
    ls.Thickness = 2.5
    ls.Parent = l

    -- register for cleanup
    activeESPs[b] = true
    -- optional ESP type attribute is set by callers via fourth argument (backwards compatible)
    -- note: some calls may update attribute after creation
    return b
end

local function clearESPsOfType(espType)
    for inst,_ in pairs(activeESPs) do
        if inst and inst.Parent then
            local t = inst:GetAttribute("ESPType")
            if t == espType then
                pcall(function() inst:Destroy() end)
                activeESPs[inst] = nil
            end
        end
    end
end

local function createTracer(target, color, espType)
    local function getTargetPosition(obj)
        if obj:IsA("Model") then
            if obj.PrimaryPart then
                return obj.PrimaryPart.Position
            else
                return obj:GetPivot().Position
            end
        elseif obj:IsA("BasePart") then
            return obj.Position
        end
        return nil
    end

    -- tracer creation is controlled by callers; do not early-return here

    if not Drawing then
        warn("Drawing API not available; tracers disabled")
        return nil, nil
    end

    local tracer = Drawing.new("Line")
    tracer.Color = color
    tracer.Thickness = 2
    tracer.Visible = true

    local connection
    connection = runService.RenderStepped:Connect(function()
        local targetPos = getTargetPosition(target)
        if targetPos then
            local viewportPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
            if viewportPos.Z > 0 then
                local screenCenter = Vector2.new(
                    workspace.CurrentCamera.ViewportSize.X / 2,
                    (workspace.CurrentCamera.ViewportSize.Y / 2) + 30
                )
                tracer.From = screenCenter
                tracer.To = Vector2.new(viewportPos.X, viewportPos.Y)
                tracer.Visible = true
            else
                tracer.Visible = false
            end
        end
    end)

    local ancestryConn
    ancestryConn = target.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if tracer then
                pcall(function() tracer:Remove() end)
                activeTracers[tracer] = nil
            end
            if connection then
                pcall(function() connection:Disconnect() end)
            end
            if ancestryConn then ancestryConn:Disconnect() end
        end
    end)

    -- register tracer for toggle cleanup (store as table with type)
    if tracer then
        activeTracers[tracer] = { conn = connection, type = espType }
    end

    return tracer, connection
end

-- DISABLE SHARKS (figure out how to do this :pensive:)
local function handleShark(shark)
    local eyefest = shark:WaitForChild("Eyefestation")
    if not eyefest then
        return
    end
    local active = eyefest:WaitForChild("Active")
    if active then
        active.Value = false
    end
end

local function handleDoor(door)
    -- Track door continuously; only create/cleanup ESP/tracer based on DoorHandling state
    local exitRef = door:FindFirstChild("Exit")
    local prevEntrances = nil
    if exitRef and exitRef.Value then
        local prevRoom = exitRef.Value
        prevEntrances = prevRoom:FindFirstChild("Entrances")
    end

    -- helper to pick a BasePart on which to attach visuals
    local function pickVisualTarget()
        if door:IsA("BasePart") then return door end
        if door:IsA("Model") then return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart") end
        return door:FindFirstChild("ProxyPart") or door:FindFirstChild("Part") or door:FindFirstChildWhichIsA("BasePart")
    end

    local created = false
    local createdObjects = {}
    local createdTracerConn = nil

    local function cleanupCreated()
        if createdObjects.esp and createdObjects.esp.Destroy then pcall(function() createdObjects.esp:Destroy() end) end
        if createdObjects.tracer then pcall(function() createdObjects.tracer:Remove() end) end
        if createdTracerConn then pcall(function() createdTracerConn:Disconnect() end) end
        created = false
    end

    local function createVisuals()
        if created or not featureState.DoorHandling then return end
        local visualTarget = pickVisualTarget()
        if not visualTarget then return end
        local esp = createESP(visualTarget, Color3.fromRGB(0, 0, 255), "Door")
        if esp and esp.SetAttribute then pcall(function() esp:SetAttribute("ESPType", "Door") end) end
        local tracer, conn = nil, nil
        tracer, conn = createTracer(visualTarget, Color3.fromRGB(0, 0, 255), "Door")
        createdObjects.esp = esp
        createdObjects.tracer = tracer
        createdTracerConn = conn
        created = true

        -- now attach a watcher to this door's OpenValue so when it opens visuals are removed
        local openValue = door:FindFirstChild("OpenValue") or door:WaitForChild("OpenValue", 5)
        if openValue then
            if openValue.Value == true then
                cleanupCreated()
                return
            end
            openValue:GetPropertyChangedSignal("Value"):Connect(function()
                if openValue.Value == true then
                    cleanupCreated()
                end
            end)
        end
    end

    -- If previous entrances exist and any are already open, mark ready to create
    local prevHasOpen = false
    if prevEntrances then
        for _, pd in ipairs(prevEntrances:GetChildren()) do
            local pv = pd:FindFirstChild("OpenValue")
            if pv and pv:IsA("BoolValue") and pv.Value == true then
                prevHasOpen = true
                break
            end
        end
    end
    if prevHasOpen then
        createVisuals()
        return
    end

    -- Otherwise, listen for any previous entrance opening
    local listeners = {}
    if prevEntrances then
        for _, pd in ipairs(prevEntrances:GetChildren()) do
            local pv = pd:FindFirstChild("OpenValue")
            if pv and pv:IsA("BoolValue") then
                local conn = pv:GetPropertyChangedSignal("Value"):Connect(function()
                    if pv.Value == true then
                        -- create visuals and clear listeners
                        createVisuals()
                        for _, c in ipairs(listeners) do pcall(function() c:Disconnect() end) end
                    end
                end)
                table.insert(listeners, conn)
            end
        end
    else
        -- no previous room information available -> mark ready to create immediately
        createVisuals()
    end
end

local function processEntrance(door)
    task.spawn(function()
        handleDoor(door)
    end)
end

local function detectItem(v)
    if v:WaitForChild("ProxyPart", 5) then
        local interactionType = v:GetAttribute("InteractionType")

        if interactionType == "CurrencyBase" then
            local amount = tonumber(v:GetAttribute("Amount"))
            local name = "$" .. amount
            local color

            if amount < 25 then
                color = Color3.fromRGB(0, 100, 0)
            elseif amount < 50 then
                color = Color3.fromRGB(255, 150, 0)
            elseif amount < 100 then
                color = Color3.fromRGB(255, 255, 100)
            elseif amount < 500 then
                color = Color3.fromRGB(255, 255, 100)
            else
                color = Color3.fromRGB(255, 0, 255)
            end

            if featureState.ItemESP then
                local b = createESP(v, color, name)
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        elseif interactionType == "KeyCard" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Keycard")
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        elseif interactionType == "PasswordPaper" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Password")
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        elseif interactionType == "InnerKeyCard" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Purple Keycard")
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        elseif interactionType == "ItemBase" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(150, 255, 100))
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        elseif interactionType == "Battery" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(125, 100, 50), "Battery")
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        else
            if featureState.ItemESP then
                local b = createESP(v)
                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Item") end) end
            end
        end
    end
end

local function handleSpawn(spawn)
    for _,v in ipairs(spawn:GetChildren()) do
        detectItem(v)
    end
    spawn.ChildAdded:Connect(function(v)
        detectItem(v)
    end)
end

local function handleSpawnLocation(spawnLocation)
    for _,v in ipairs(spawnLocation:GetChildren()) do
        handleSpawn(v)
    end
    spawnLocation.ChildAdded:Connect(function(v)
        handleSpawn(v)
    end)
end

local function handleRoom(room)
    local entrancesFolder = room:WaitForChild("Entrances")
    for _, door in ipairs(entrancesFolder:GetChildren()) do
        processEntrance(door)
    end
    entrancesFolder.ChildAdded:Connect(function(child)
        processEntrance(child)
    end)
    for _,v in ipairs(room:GetDescendants()) do
        if v.Name == "SpawnLocations" and v:IsA("Folder") then
            handleSpawnLocation(v)
        end
    end
    room.DescendantAdded:Connect(function(v)
        if v.Name == "SpawnLocations" and v:IsA("Folder") then
            handleSpawnLocation(v)
        end
    end)
end

for _, room in ipairs(roomsFolder:GetChildren()) do
    task.spawn(function()
        handleRoom(room)
    end)
end

roomsFolder.ChildAdded:Connect(function(newRoom)
    task.spawn(function()
        handleRoom(newRoom)
    end)
end)

local workspaceTargetList = {
    { Name = "Angler", Color = Color3.fromRGB(255, 0, 0), Label = "Angler" },
    { Name = "RidgeAngler", Color = Color3.fromRGB(255, 0, 0), Label = "Angler" },
    { Name = "Pinkie", Color = Color3.fromRGB(255, 0, 0), Label = "Pinkie" },
    { Name = "RidgePinkie", Color = Color3.fromRGB(255, 0, 0), Label = "Pinkie" },
    { Name = "Chainsmoker", Color = Color3.fromRGB(255, 0, 0), Label = "Chainsmoker" },
    { Name = "RidgeChainsmoker", Color = Color3.fromRGB(255, 0, 0), Label = "Chainsmoker" },
    { Name = "Froger", Color = Color3.fromRGB(255, 0, 0), Label = "Froger" },
    { Name = "RidgeFroger", Color = Color3.fromRGB(255, 0, 0), Label = "Froger" },
    { Name = "Blitz", Color = Color3.fromRGB(255, 0, 0), Label = "Blitz" },
    { Name = "RidgeBlitz", Color = Color3.fromRGB(255, 0, 0), Label = "Blitz" },
    { Name = "Pandemonium", Color = Color3.fromRGB(255, 0, 0), Label = "Pandemonium", remove = true },
    { Name = "RidgePandemonium", Color = Color3.fromRGB(255, 0, 0), Label = "Pandemonium", remove = true },
    { Name = "A60", Color = Color3.fromRGB(255, 0, 0), Label = "A60" },
    { Name = "RidgeA60", Color = Color3.fromRGB(255, 0, 0), Label = "A60" },
    { Name = "Pipsqueak", Color = Color3.fromRGB(255, 0, 0), Label = "Pipsqueak", remove = true },
    { Name = "Parasite", Color = Color3.fromRGB(255, 0, 0), Label = "Parasite"},
    { Name = "Mirage", Color = Color3.fromRGB(255, 0, 0), Label = "Mirage", CustomLabel = "Keep fucking moving dumbass" },
    { Name = "RidgeMirage", Color = Color3.fromRGB(255, 0, 0), Label = "Mirage", CustomLabel = "Keep fucking moving dumbass"  },
    { Name = "Harbinger", Color = Color3.fromRGB(255, 0, 0), Label = "Harbinger", CustomLabel = "ur cooked. give up" },
    { Name = "RidgeHarbinger", Color = Color3.fromRGB(255, 0, 0), Label = "Harbinger", CustomLabel = "ur cooked. give up" },
    { Name = "Anglemonium", Color = Color3.fromRGB(255, 0, 0), Label = "Anglemonium", remove = true },
    { Name = "Pinkimonium", Color = Color3.fromRGB(255, 0, 0), Label = "Pinkimonium", remove = true },
    { Name = "Frogermonium", Color = Color3.fromRGB(255, 0, 0), Label = "Frogermonium", remove = true },
    { Name = "Pandesmoker", Color = Color3.fromRGB(255, 0, 0), Label = "Pandesmoker", remove = true },
    { Name = "Blitzemonium", Color = Color3.fromRGB(255, 0, 0), Label = "Blitzemonium", remove = true },
    { Name = "Bleach", Color = Color3.fromRGB(255, 0, 0), Label = "Bleach" },
    { Name = "A200", Color = Color3.fromRGB(255, 0, 0), Label = "A200" },
    { Name = "WitchingHour", Color = Color3.fromRGB(255, 0, 0), Label = "WitchingHour", remove = true },
}

local function normalizeName(str)
    return str:lower():gsub("%s+", "")
end

local function findTarget(target, childName, callback)
    task.spawn(function()
        local found = childName and target:WaitForChild(childName, 1) or target
        callback(found)
    end)
end

workspace.ChildAdded:Connect(function(child)
    task.spawn(function()
        if not (child:IsA("BasePart") or child:IsA("Model")) then return end
        for _, target in ipairs(workspaceTargetList) do
            if normalizeName(child.Name) == normalizeName(target.Name) then
                local txt = target.CustomLabel or target.Label
                CreateNotification(txt, target.Color, 2.5)
                if target.remove then
                    child:Destroy()
                    return
                end
                findTarget(child, target.ChildName, function(targetchild)
                    if targetchild then
                        if featureState.MonsterVisuals then
                            local b = createESP(targetchild, target.Color, target.Label)
                            if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Monster") end) end
                            -- Monster visuals include tracers
                            createTracer(targetchild, target.Color, "Monster")
                        end
                    end
                end)
                return
            end
        end
    end)
end)

-- TODO: fix existing items not getting an esp

-- Cleanup / toggle helpers
local function clearAllESPs()
    for inst,_ in pairs(activeESPs) do
        if inst and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
        activeESPs[inst] = nil
    end
end

local function clearAllTracers(filterType)
    for tracer, info in pairs(activeTracers) do
        if info == nil then
            activeTracers[tracer] = nil
        else
            local t = info.type
            if not filterType or t == filterType then
                if tracer then pcall(function() tracer:Remove() end) end
                if info.conn then pcall(function() info.conn:Disconnect() end) end
                activeTracers[tracer] = nil
            end
        end
    end
end

local function refreshVisuals()
    -- recreate visuals for existing workspace targets and room doors
    for _, child in ipairs(workspace:GetDescendants()) do
        if not (child:IsA("BasePart") or child:IsA("Model")) then
            -- skip non-visual items
        else
            for _, target in ipairs(workspaceTargetList) do
                if normalizeName(child.Name) == normalizeName(target.Name) then
                    if target.remove then break end
                    findTarget(child, target.ChildName, function(targetchild)
                        if targetchild then
                            if featureState.MonsterVisuals then
                                local b = createESP(targetchild, target.Color, target.Label)
                                if b and b.SetAttribute then pcall(function() b:SetAttribute("ESPType", "Monster") end) end
                                createTracer(targetchild, target.Color, "Monster")
                            end
                        end
                    end)
                    break
                end
            end
        end
    end

    for _, room in ipairs(roomsFolder:GetChildren()) do
        local entrances = room:FindFirstChild("Entrances")
        if entrances then
            for _, door in ipairs(entrances:GetChildren()) do
                if featureState.DoorHandling then processEntrance(door) end
            end
        end
    end
end

local function scanExistingItemsInRooms()
    -- iterate rooms and spawn locations to find existing items and apply ESP/tracer
    for _, room in ipairs(roomsFolder:GetChildren()) do
        for _, desc in ipairs(room:GetDescendants()) do
            if desc.Name == "SpawnLocations" and desc:IsA("Folder") then
                for _, spawn in ipairs(desc:GetChildren()) do
                    for _, item in ipairs(spawn:GetChildren()) do
                        task.spawn(function()
                            pcall(function() detectItem(item) end)
                        end)
                    end
                end
            end
        end
    end
end

local function setFeature(name, enabled)
    featureState[name] = enabled
    if name == "ItemESP" then
        if not enabled then
            clearESPsOfType("Item")
        else
            -- show existing items immediately
            scanExistingItemsInRooms()
        end
    elseif name == "AutoCrouchEvent" then
        if enabled then
            featureState.AutoCrouchEvent = true
            startAutoCrouchEvent()
        else
            stopAutoCrouchEvent()
        end
    elseif name == "DisableEyefestation" then
        if enabled then
            scanAndDisableAllEyefestation()
            setupEyefestationListener()
        else
            cleanupEyefestationConns()
        end
    elseif name == "ForceHidePopups" then
        if enabled then
            setPopupsVisibleFalse()
        else
            cleanupPopupsConn()
        end
    elseif name == "DoorHandling" then
        if not enabled then
            clearESPsOfType("Door")
            clearAllTracers("Door")
        else
            -- process existing doors
            for _, room in ipairs(roomsFolder:GetChildren()) do
                local entrances = room:FindFirstChild("Entrances")
                if entrances then
                    for _, door in ipairs(entrances:GetChildren()) do
                        processEntrance(door)
                    end
                end
            end
        end
    elseif name == "MonsterVisuals" then
        if not enabled then
            clearESPsOfType("Monster")
            clearAllTracers("Monster")
        else
            -- show existing monsters
            refreshVisuals()
        end
    elseif name == "Fullbright" then
        if enabled then applyFullbright() else restoreLighting() end
    elseif name == "NodeVisualizer" then
        if enabled then
            if enableVisualizer then enableVisualizer() end
        else
            if disableVisualizer then disableVisualizer() end
        end
    end
end

-- ============================================================
-- UI (Lib.lua)
-- ============================================================
CreateMenu("Pressure")
CreateGroup("Pressure", "Main")
CreateTab("Pressure", "Main", "Visuals")
CreateTab("Pressure", "Main", "World")

CreateLabel("Visuals", "Monster, item and door visuals")
CreateToggle("Visuals", "Monster Visuals", function(state)
    setFeature("MonsterVisuals", state.Value)
end, false)

CreateToggle("Visuals", "Item ESP", function(state)
    setFeature("ItemESP", state.Value)
end, false)

CreateToggle("Visuals", "Door Visuals", function(state)
    setFeature("DoorHandling", state.Value)
end, false)

CreateToggle("Visuals", "Force Hide Popups", function(state)
    setFeature("ForceHidePopups", state.Value)
end, false)

CreateLabel("World", "Environment and utility features")
CreateToggle("World", "Fullbright", function(state)
    setFeature("Fullbright", state.Value)
end, false)

CreateToggle("World", "Node Visualizer", function(state)
    setFeature("NodeVisualizer", state.Value)
end, false)

CreateToggle("World", "Notifications", function(state)
    setFeature("Notifications", state.Value)
end, false)

CreateToggle("World", "Disable Eyefestation", function(state)
    setFeature("DisableEyefestation", state.Value)
end, false)

CreateToggle("World", "Auto Crouch Event", function(state)
    setFeature("AutoCrouchEvent", state.Value)
end, false)

local roomsFolder = workspace.GameplayFolder.Rooms
local drawnConnections = {}
local roomDrawn = {}
local interRoomBeams = {}

local function getConnections(part)
    local folder = part and part:FindFirstChild("Connections")
    if not folder then return {} end
    local connections = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name:match("^Previous") and child:IsA("ObjectValue") and child.Value then
            table.insert(connections, child.Value)
        end
    end
    return connections
end

local function buildPath(startNode, endNode)
    if not startNode or not endNode then return nil end
    local queue = {startNode}
    local visited = {[startNode] = true}
    local parent = {}
    local found = false
    while #queue > 0 do
        local current = table.remove(queue, 1)
        if current == endNode then
            found = true
            break
        end
        for _, nxt in ipairs(getConnections(current)) do
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

local function drawPath(path)
    if not path then return end
    for _, part in ipairs(path) do
        if part and part:IsA("BasePart") then
            part.Transparency = 0
        end
    end
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        if a:IsA("BasePart") and b:IsA("BasePart") then
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
        end
    end
end

local function clearRoomDrawings(room)
    local list = roomDrawn[room]
    if not list then return end
    for _, inst in ipairs(list) do
        if inst and inst.Parent then
            inst:Destroy()
        end
    end
    roomDrawn[room] = nil
end

local function getClosestExitNode(entrance, nodesFolder)
    local closestExit = nil
    local closestDistance = math.huge
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") and node.Name:match("Exit") then
            local distance = (node.Position - entrance.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestExit = node
            end
        end
    end
    return closestExit
end

local function validateAndFixNodeConnections(room)
    spawn(function()
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
                            local prev = Instance.new("ObjectValue")
                            prev.Name = "Previous"
                            prev.Parent = conFolder
                        end
                        if not conFolder:FindFirstChild("Next") then
                            local next = Instance.new("ObjectValue")
                            next.Name = "Next"
                            next.Parent = conFolder
                        end
                        
                        if not prevExists then
                            local allNodes = nodesFolder:GetChildren()
                            local closestPrev = nil
                            local closestDist = math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local dist = (node.Position - other.Position).Magnitude
                                    if dist < closestDist then
                                        closestDist = dist
                                        closestPrev = other
                                    end
                                end
                            end
                            if closestPrev then
                                conFolder.Previous.Value = closestPrev
                            end
                        end
                        
                        if not nextExists then
                            local allNodes = nodesFolder:GetChildren()
                            local closestNext = nil
                            local closestDist = math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local dist = (node.Position - other.Position).Magnitude
                                    if dist < closestDist then
                                        closestDist = dist
                                        closestNext = other
                                    end
                                end
                            end
                            if closestNext then
                                conFolder.Next.Value = closestNext
                            end
                        end
                    end
                end
            end
            wait(2)
        end
    end)
end

local function drawRoomNodeConnections(room)
    clearRoomDrawings(room)
    local nodesFolder = room and room:FindFirstChild("EntityNodes")
    if not nodesFolder then return end
    roomDrawn[room] = roomDrawn[room] or {}
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") then
            local conFolder = node:FindFirstChild("Connections")
            if conFolder then
                -- Connect to all Previous connections
                for _, child in ipairs(conFolder:GetChildren()) do
                    if child.Name:match("^Previous") and child:IsA("ObjectValue") and child.Value and child.Value:IsA("BasePart") then
                        local a, b = node, child.Value
                        -- create attachments and beam between node and its Previous
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
                        a.Transparency = 0
                        b.Transparency = 0
                        table.insert(roomDrawn[room], att0)
                        table.insert(roomDrawn[room], att1)
                        table.insert(roomDrawn[room], beam)
                    end
                end
            end
        end
    end
   local nodes = nodesFolder
    local entrance = nodes:FindFirstChild("Entrance")
    if entrance then
        local closestExit = getClosestExitNode(entrance, nodesFolder)
        if closestExit then
            local path = buildPath(entrance, closestExit)
            if path then
                drawPath(path)
            end
        end
    end
end

local function safeWaitForChild(parent, name, timeout)
    local child = parent:FindFirstChild(name)
    if child then return child end
    return parent:WaitForChild(name, timeout or 10)
end

local function connectRoomInternal(room)
    spawn(function()
        while true do
            local nodes = room:FindFirstChild("EntityNodes")
            if nodes then
                drawRoomNodeConnections(room)
                break
            end
            wait(0.2)
        end
    end)
end

local function connectRoomToPrevious(room)
    spawn(function()
        while true do
            local entrancesFolder = room:FindFirstChild("Entrances")
            if entrancesFolder then
                if interRoomBeams[room] then
                    for _, beam in ipairs(interRoomBeams[room]) do
                        if beam and beam.Parent then
                            beam:Destroy()
                        end
                    end
                end
                interRoomBeams[room] = {}
                
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
                                local prevExit = getClosestExitNode(currEntrance, prevNodes)
                                if prevExit then
                                    if prevExit:IsA("BasePart") and currEntrance:IsA("BasePart") then
                                        local att0 = Instance.new("Attachment")
                                        att0.Parent = prevExit
                                        local att1 = Instance.new("Attachment")
                                        att1.Parent = currEntrance
                                        local beam = Instance.new("Beam")
                                        beam.Attachment0 = att0
                                        beam.Attachment1 = att1
                                        beam.FaceCamera = true
                                        beam.Width0 = 0.2
                                        beam.Width1 = 0.2
                                        beam.Parent = prevExit
                                        prevExit.Transparency = 0
                                        currEntrance.Transparency = 0
                                        table.insert(interRoomBeams[room], beam)
                                        connectedAny = true
                                    end
                                end
                            end
                        end
                    end
                end
                if connectedAny then break end
            end
            wait(0.2)
        end
    end)
end

local function setupNodeListener(room)
    spawn(function()
        while true do
            local nodes = room:FindFirstChild("EntityNodes")
            if nodes then
                nodes.ChildAdded:Connect(function()
                    drawRoomNodeConnections(room)
                    connectRoomToPrevious(room)
                end)
                nodes.ChildRemoved:Connect(function()
                    drawRoomNodeConnections(room)
                    connectRoomToPrevious(room)
                end)
                break
            end
            wait(0.2)
        end
    end)
end

local function setupRoom(room)
    connectRoomInternal(room)
    connectRoomToPrevious(room)
    setupNodeListener(room)
    validateAndFixNodeConnections(room)
end

for _, room in ipairs(roomsFolder:GetChildren()) do
    setupRoom(room)
end

roomsFolder.ChildAdded:Connect(function(room)
    setupRoom(room)
end)

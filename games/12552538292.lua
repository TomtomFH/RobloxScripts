-- PRESSURE (https://www.roblox.com/games/12552538292/)
-- PART: Hadal Blacksite

local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local gameplayFolder = workspace:WaitForChild("GameplayFolder", 60)
local roomsFolder = gameplayFolder:WaitForChild("Rooms", 60)

local player = players.LocalPlayer

local function isEndlessFirewallMode()
    local allowedRooms = {
        Start = true,
        FirewallStart = true,
        FirewallEnd = true,
        FirewallElevator = true
    }

    local deadline = os.clock() + 5
    repeat
        local hasUnexpectedRoom = false
        local hasAllowedRoom = false

        for _, room in ipairs(roomsFolder:GetChildren()) do
            if allowedRooms[room.Name] then
                hasAllowedRoom = true
            else
                hasUnexpectedRoom = true
                break
            end
        end

        if not hasUnexpectedRoom and hasAllowedRoom then
            return true
        end

        if hasUnexpectedRoom then
            return false
        end

        task.wait(0.1)
    until os.clock() >= deadline

    return false
end

if isEndlessFirewallMode() then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

    local firewallRoomLabel = nil
    local firewallActualRoomLabel = nil
    local firewallStatusLabel = nil

    local firewallState = {
        enabled = false,
        chaseRooms = nil,
        pendingRooms = {},
        roomConnections = {},
        roomOpenValues = {},
        mainConnections = {},
        doorLoopId = 0,
        phaseLoopId = 0,
        currentTargetRoom = nil,
        currentTargetRoomNumber = nil,
        firewallRoomNumber = nil,
        chaseReady = false,
        platformsReady = false,
        lastKeycardAttempt = 0,
        lastElevatorKeyAttempt = 0,
        elevatorKeyStarted = false
    }

    local FIREWALL_PLATFORM_NAME = "EntranceExitPlatform"
    local FIREWALL_PLATFORM_THICKNESS = 1
    local FIREWALL_PLATFORM_TRANSPARENCY = 0.5
    local FIREWALL_HEIGHT_FRACTION_DOWN = 0.7
    local FIREWALL_REBUILD_DELAY = 0.15
    local FIREWALL_TELEPORT_WAIT_TIMEOUT = 5
    local FIREWALL_TELEPORT_DISTANCE_FROM_DOOR = 8
    local FIREWALL_TELEPORT_HEIGHT_OFFSET = 4
    local FIREWALL_TELEPORT_SIDE = -1
    local FIREWALL_WALK_SPEED = 24
    local FIREWALL_WALK_THROUGH_DISTANCE = 18
    local FIREWALL_RETRY_DELAY = 0.25
    local FIREWALL_MAX_ROOMS_AHEAD = 10
    local FIREWALL_PROMPT_DISTANCE = 5

    local function firewallSetStatus(text)
        if firewallStatusLabel then
            firewallStatusLabel.Text = "Status: " .. tostring(text)
        end
    end

    local function firewallGetChaseRooms()
        local elevator = roomsFolder:FindFirstChild("FirewallElevator") or roomsFolder:WaitForChild("FirewallElevator", 10)
        if not elevator then
            return roomsFolder
        end

        return elevator:FindFirstChild("ChaseRooms") or elevator:WaitForChild("ChaseRooms", 10)
    end

    local function firewallGetRoomNumber(room)
        return tonumber(room and room:GetAttribute("RoomNumber"))
    end

    local function firewallGetLatestRoomNumber()
        local latestRoomNumber = nil

        if firewallState.chaseRooms then
            for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
                local roomNumber = firewallGetRoomNumber(room)
                if roomNumber and (not latestRoomNumber or roomNumber > latestRoomNumber) then
                    latestRoomNumber = roomNumber
                end
            end
        end

        return latestRoomNumber
    end

    local function firewallUpdateRoomLabel()
        local latestRoomNumber = firewallGetLatestRoomNumber()
        if firewallRoomLabel then
            firewallRoomLabel.Text = latestRoomNumber and ("Current Room: " .. tostring(latestRoomNumber)) or "Current Room: None"
        end
    end

    local function firewallGetModelPosition(model)
        if not model or not model.Parent then
            return nil
        end

        local ok, cf = pcall(function()
            return model:GetBoundingBox()
        end)

        return ok and cf.Position or nil
    end

    local function firewallGetRoomCenter(room)
        if not room then
            return nil
        end

        local ok, cf = pcall(function()
            return room:GetBoundingBox()
        end)

        return ok and cf.Position or nil
    end

    local function firewallGetClosestRoomNumberToPosition(position)
        if not position or not firewallState.chaseRooms then
            return nil
        end

        local closestRoomNumber = nil
        local closestDistance = math.huge

        for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
            local roomNumber = firewallGetRoomNumber(room)
            local center = firewallGetRoomCenter(room)

            if roomNumber and center then
                local distance = (center - position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestRoomNumber = roomNumber
                end
            end
        end

        return closestRoomNumber
    end

    local function firewallUpdateActualRoom()
        local firewallModel = workspace:FindFirstChild("Firewall")
        local roomNumber = firewallGetClosestRoomNumberToPosition(firewallGetModelPosition(firewallModel))

        firewallState.firewallRoomNumber = roomNumber
        if firewallActualRoomLabel then
            firewallActualRoomLabel.Text = roomNumber and ("Firewall Room: " .. tostring(roomNumber)) or "Firewall Room: Unknown"
        end

        return roomNumber
    end

    local function firewallIsTooFarAhead(roomNumber)
        local firewallRoomNumber = firewallUpdateActualRoom()
        return roomNumber and firewallRoomNumber and roomNumber - firewallRoomNumber > FIREWALL_MAX_ROOMS_AHEAD
    end

    local function firewallFindEntranceOpenValue(room)
        local entrances = room and room:FindFirstChild("Entrances")
        if not entrances then
            return nil
        end

        local openValue = entrances:FindFirstChild("OpenValue", true)
        if openValue and openValue:IsA("ValueBase") then
            return openValue
        end

        return nil
    end

    local function firewallGetFirstPart(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= FIREWALL_PLATFORM_NAME then
                return obj
            end
        end

        return nil
    end

    local function firewallGetHeightPoint(part)
        local topCenter = part.Position + part.CFrame.UpVector * (part.Size.Y / 2)
        return topCenter - part.CFrame.UpVector * (part.Size.Y * FIREWALL_HEIGHT_FRACTION_DOWN)
    end

    local function firewallGetRoomWidthAlongPath(room, startPos, endPos)
        local pathDir = endPos - startPos
        if pathDir.Magnitude <= 0 then
            return 10
        end

        pathDir = pathDir.Unit
        local rightDir = pathDir:Cross(Vector3.yAxis)
        rightDir = rightDir.Magnitude < 0.01 and Vector3.xAxis or rightDir.Unit

        local minDot = math.huge
        local maxDot = -math.huge

        for _, obj in ipairs(room:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= FIREWALL_PLATFORM_NAME then
                local cf = obj.CFrame
                local halfSize = obj.Size / 2

                for x = -1, 1, 2 do
                    for y = -1, 1, 2 do
                        for z = -1, 1, 2 do
                            local corner = cf.Position
                                + cf.RightVector * halfSize.X * x
                                + cf.UpVector * halfSize.Y * y
                                + cf.LookVector * halfSize.Z * z
                            local dot = corner:Dot(rightDir)
                            minDot = math.min(minDot, dot)
                            maxDot = math.max(maxDot, dot)
                        end
                    end
                end
            end
        end

        return minDot == math.huge and 10 or (maxDot - minDot)
    end

    local function firewallCreatePlatformForRoom(room)
        if not firewallState.enabled or not firewallState.platformsReady or not firewallState.chaseRooms or not room:IsDescendantOf(firewallState.chaseRooms) then
            return
        end

        local entrances = room:FindFirstChild("Entrances")
        local exits = room:FindFirstChild("Exits") or room:FindFirstChild("Exists")
        if not entrances or not exits then
            return
        end

        local entrancePart = firewallGetFirstPart(entrances)
        local exitPart = firewallGetFirstPart(exits)
        if not entrancePart or not exitPart then
            return
        end

        local oldPlatform = room:FindFirstChild(FIREWALL_PLATFORM_NAME)
        if oldPlatform then
            oldPlatform:Destroy()
        end

        local startPos = firewallGetHeightPoint(entrancePart)
        local endPos = firewallGetHeightPoint(exitPart)
        local length = (endPos - startPos).Magnitude
        if length <= 0 then
            return
        end

        local topCenter = (startPos + endPos) / 2
        local width = firewallGetRoomWidthAlongPath(room, startPos, endPos)
        local platformTopCF = CFrame.lookAt(topCenter, endPos, Vector3.yAxis)
        local platformCenter = topCenter - platformTopCF.UpVector * (FIREWALL_PLATFORM_THICKNESS / 2)

        local platform = Instance.new("Part")
        platform.Name = FIREWALL_PLATFORM_NAME
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = true
        platform.CanQuery = true
        platform.Transparency = FIREWALL_PLATFORM_TRANSPARENCY
        platform.Size = Vector3.new(width, FIREWALL_PLATFORM_THICKNESS, length)
        platform.CFrame = CFrame.lookAt(platformCenter, platformCenter + platformTopCF.LookVector, platformTopCF.UpVector)
        platform.Material = Enum.Material.SmoothPlastic
        platform.Color = Color3.fromRGB(80, 80, 80)
        platform.Parent = room
    end

    local function firewallQueueCreatePlatform(room)
        if not firewallState.platformsReady then
            return
        end

        if firewallState.pendingRooms[room] then
            return
        end

        firewallState.pendingRooms[room] = true
        task.delay(FIREWALL_REBUILD_DELAY, function()
            firewallState.pendingRooms[room] = nil
            if firewallState.enabled and room and room.Parent == firewallState.chaseRooms then
                firewallCreatePlatformForRoom(room)
            end
        end)
    end

    local function firewallDisconnectRoom(room)
        local connections = firewallState.roomConnections[room]
        if connections then
            for _, connection in pairs(connections) do
                if connection then
                    connection:Disconnect()
                end
            end
        end

        firewallState.roomConnections[room] = nil
        firewallState.pendingRooms[room] = nil
        firewallState.roomOpenValues[room] = nil
    end

    local function firewallRefreshRoomLabels()
        firewallUpdateRoomLabel()
        firewallUpdateActualRoom()
    end

    local function firewallGetDoorPartFromOpenValue(openValue)
        if not openValue then
            return nil
        end

        local door = openValue.Parent
        if not door then
            return nil
        end

        if door:IsA("BasePart") then
            return door
        end

        if door:IsA("Model") then
            return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
        end

        return door:FindFirstChildWhichIsA("BasePart", true)
    end

    local function firewallGetTeleportPartForRoom(room)
        local doorPart = firewallGetDoorPartFromOpenValue(firewallFindEntranceOpenValue(room))
        if doorPart then
            return doorPart
        end

        local entrances = room and room:FindFirstChild("Entrances")
        return entrances and firewallGetFirstPart(entrances) or nil
    end

    local function firewallGetLatestEntranceNotOpenRoom()
        local bestRoom = nil
        local bestRoomNumber = nil

        for room, openValue in pairs(firewallState.roomOpenValues) do
            if firewallState.chaseRooms and room:IsDescendantOf(firewallState.chaseRooms) and openValue and openValue.Parent then
                local roomNumber = firewallGetRoomNumber(room)
                if roomNumber and openValue.Value ~= true and (not bestRoomNumber or roomNumber > bestRoomNumber) then
                    bestRoom = room
                    bestRoomNumber = roomNumber
                end
            end
        end

        return bestRoom, bestRoomNumber
    end

    local function firewallTrackEntranceOpenValue(room)
        local openValue = firewallFindEntranceOpenValue(room)
        if not openValue or firewallState.roomOpenValues[room] == openValue then
            return
        end

        firewallState.roomOpenValues[room] = openValue
        local connections = firewallState.roomConnections[room]
        if connections then
            if connections.openValueChanged then
                connections.openValueChanged:Disconnect()
            end

            connections.openValueChanged = openValue:GetPropertyChangedSignal("Value"):Connect(function()
                firewallUpdateRoomLabel()
            end)
        end
    end

    local function firewallGetCharacter()
        local character = player.Character or player.CharacterAdded:Wait()
        local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        return character, root, humanoid
    end

    local function firewallWalkThroughDoor(character, root, humanoid, doorPart)
        if not character or not root or not humanoid or not doorPart then
            return
        end

        local walkDirection = doorPart.Position - root.Position
        if walkDirection.Magnitude <= 0 then
            return
        end

        walkDirection = walkDirection.Unit
        local walkTarget = doorPart.Position + walkDirection * FIREWALL_WALK_THROUGH_DISTANCE
        local oldWalkSpeed = humanoid.WalkSpeed
        local oldAutoRotate = humanoid.AutoRotate

        humanoid.WalkSpeed = FIREWALL_WALK_SPEED
        humanoid.AutoRotate = false

        local remaining = walkTarget - root.Position
        if remaining.Magnitude > 1 then
            local currentDirection = remaining.Unit
            root.CFrame = CFrame.lookAt(root.Position, root.Position + currentDirection)
            root.AssemblyLinearVelocity = currentDirection * FIREWALL_WALK_SPEED
            humanoid:Move(currentDirection, false)

            local deltaTime = runService.Heartbeat:Wait()
            root.CFrame = root.CFrame + currentDirection * FIREWALL_WALK_SPEED * deltaTime
        end

        if humanoid.Parent then
            humanoid.WalkSpeed = oldWalkSpeed
            humanoid.AutoRotate = oldAutoRotate
        end
    end

    local function firewallTeleportToPartAndWalk(teleportPart)
        if not teleportPart then
            return
        end

        local character, root, humanoid = firewallGetCharacter()
        if not character or not root or not humanoid then
            return
        end

        local doorBase = teleportPart.Position - teleportPart.CFrame.UpVector * (teleportPart.Size.Y / 2)
        local teleportPosition = doorBase
            + Vector3.yAxis * FIREWALL_TELEPORT_HEIGHT_OFFSET
            + teleportPart.CFrame.LookVector * FIREWALL_TELEPORT_DISTANCE_FROM_DOOR * FIREWALL_TELEPORT_SIDE

        character:PivotTo(CFrame.lookAt(teleportPosition, teleportPart.Position))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        firewallWalkThroughDoor(character, root, humanoid, teleportPart)
    end

    local function firewallTeleportAndWalk(room)
        firewallTeleportToPartAndWalk(firewallGetTeleportPartForRoom(room))
    end

    local function firewallQueueAllPlatforms()
        if not firewallState.chaseRooms then
            return
        end

        for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
            firewallQueueCreatePlatform(room)
        end
    end

    local function firewallGetStartRoom()
        return roomsFolder:FindFirstChild("Start")
    end

    local function firewallGetFirewallStartRoom()
        return roomsFolder:FindFirstChild("FirewallStart")
    end

    local function firewallGetFirewallStartDoor()
        local firewallStart = firewallGetFirewallStartRoom()
        local entrances = firewallStart and firewallStart:FindFirstChild("Entrances")
        return entrances and entrances:FindFirstChild("NormalDoor") or nil
    end

    local function firewallGetStartPasswordPaper()
        local startRoom = firewallGetStartRoom()
        local interactables = startRoom and startRoom:FindFirstChild("Interactables")
        local drawer = interactables and interactables:FindFirstChild("1SmallDrawer")
        local spawnLocations = drawer and drawer:FindFirstChild("SpawnLocations")
        local spawnKeycard = spawnLocations and spawnLocations:FindFirstChild("SpawnKeycard")
        return spawnKeycard and spawnKeycard:FindFirstChild("PasswordPaper") or nil
    end

    local function firewallGetStartKeycard()
        local startRoom = firewallGetStartRoom()
        local interactables = startRoom and startRoom:FindFirstChild("Interactables")
        local drawer = interactables and interactables:FindFirstChild("1SmallDrawer")
        local spawnLocations = drawer and drawer:FindFirstChild("SpawnLocations")
        local spawnKeycard = spawnLocations and spawnLocations:FindFirstChild("SpawnKeycard")
        return spawnKeycard and spawnKeycard:FindFirstChild("NormalKeyCard") or nil
    end

    local function firewallReadPasswordPaperCode(passwordPaper)
        local codeObject = passwordPaper and passwordPaper:FindFirstChild("Code")
        local surfaceGui = codeObject and codeObject:FindFirstChild("SurfaceGui")
        local textLabel = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
        local text = textLabel and textLabel:IsA("TextLabel") and textLabel.Text or nil

        return type(text) == "string" and text ~= "" and text or nil
    end

    local function firewallGetInventory()
        local playerFolder = player:FindFirstChild("PlayerFolder")
        return playerFolder and playerFolder:FindFirstChild("Inventory") or nil
    end

    local function firewallHasNormalKeycard()
        local inventory = firewallGetInventory()
        local keycard = inventory and inventory:FindFirstChild("NormalKeyCard")
        return keycard and keycard:IsA("NumberValue") or false
    end

    local function firewallGetDoorOpenValue(door)
        local openValue = door and door:FindFirstChild("OpenValue")
        return openValue and openValue:IsA("ValueBase") and openValue or nil
    end

    local function firewallGetDoorPrompt(door)
        local lock = door and door:FindFirstChild("Lock")
        local main = lock and lock:FindFirstChild("Main")
        return main and main:FindFirstChild("ProximityPrompt") or nil
    end

    local function firewallGetKeycardPrompt(keycard)
        local proxyPart = keycard and keycard:FindFirstChild("ProxyPart")
        return proxyPart and proxyPart:FindFirstChild("ProximityPrompt") or nil
    end

    local function firewallGetElevatorKeyPrompt()
        local elevator = workspace:FindFirstChild("Elevator")
        local elevatorKey = elevator and elevator:FindFirstChild("ElevatorKey")
        local highlight = elevatorKey and elevatorKey:FindFirstChild("Highlight")
        return highlight and highlight:FindFirstChild("ProximityPrompt") or nil
    end

    local function firewallGetDoorRemote(door)
        return door and door:FindFirstChild("RemoteFunction", true) or nil
    end

    local function firewallTeleportToPart(part)
        if not part then
            return
        end

        local character, root = firewallGetCharacter()
        if not character or not root then
            return
        end

        local position = part.Position + Vector3.yAxis * FIREWALL_TELEPORT_HEIGHT_OFFSET
        character:PivotTo(CFrame.lookAt(position, part.Position))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local function firewallTeleportInFrontOfPart(part, sideMultiplier)
        if not part then
            return
        end

        local character, root = firewallGetCharacter()
        if not character or not root then
            return
        end

        local targetPosition = part.Position
        local side = sideMultiplier or -1
        local offsetDirection = part.CFrame.LookVector * side
        if offsetDirection.Magnitude <= 0 then
            offsetDirection = Vector3.zAxis * side
        end

        local position = targetPosition + offsetDirection.Unit * FIREWALL_PROMPT_DISTANCE + Vector3.yAxis * FIREWALL_TELEPORT_HEIGHT_OFFSET
        local lookTarget = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
        character:PivotTo(CFrame.lookAt(position, lookTarget))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local function firewallGetPromptPart(prompt)
        local parent = prompt and prompt.Parent
        if parent and parent:IsA("BasePart") then
            return parent
        end

        return parent and parent:FindFirstChildWhichIsA("BasePart", true) or nil
    end

    local function firewallTriggerPrompt(prompt)
        if not prompt then
            return
        end

        pcall(function()
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
            task.wait()
            prompt:InputHoldEnd()
        end)
    end

    local function firewallEnterDoorCode(door, code)
        local remote = firewallGetDoorRemote(door)
        if not remote or not code then
            return
        end

        pcall(function()
            local current = ""
            for i = 1, #code do
                current = current .. string.sub(code, i, i)
                remote:InvokeServer(current)
                task.wait(0.05)
            end
        end)
    end

    local firewallRetargetDoorLoop

    local function firewallStartPhaseLoop()
        firewallState.phaseLoopId += 1
        local loopId = firewallState.phaseLoopId

        task.spawn(function()
            while firewallState.enabled and firewallState.phaseLoopId == loopId do
                local startRoom = firewallGetStartRoom()
                if startRoom and startRoom:FindFirstChild("EntrySubmarine") then
                    firewallState.chaseReady = false
                    firewallSetStatus("Loading, waiting for submarine")
                    task.wait(0.25)
                    continue
                end

                local startDoor = firewallGetFirewallStartDoor()
                local startDoorOpenValue = firewallGetDoorOpenValue(startDoor)
                if startRoom and not startDoorOpenValue then
                    firewallState.chaseReady = false
                    firewallSetStatus("Waiting for start door")
                    task.wait(0.25)
                    continue
                end

                if startRoom and startDoorOpenValue and startDoorOpenValue.Value == false then
                    firewallState.chaseReady = false
                    firewallState.platformsReady = false
                    local passwordPaper = firewallGetStartPasswordPaper()

                    if passwordPaper then
                        local code = firewallReadPasswordPaperCode(passwordPaper)
                        local doorPart = firewallGetDoorPartFromOpenValue(startDoorOpenValue)
                        firewallSetStatus(code and "Opening start door" or "Reading start code")
                        firewallTeleportInFrontOfPart(doorPart)
                        firewallEnterDoorCode(startDoor, code)
                    elseif firewallHasNormalKeycard() then
                        local prompt = firewallGetDoorPrompt(startDoor)
                        firewallSetStatus("Using start keycard")
                        firewallTeleportInFrontOfPart(firewallGetPromptPart(prompt) or firewallGetDoorPartFromOpenValue(startDoorOpenValue))
                        firewallTriggerPrompt(prompt)
                    else
                        local keycard = firewallGetStartKeycard()
                        if keycard then
                            firewallSetStatus("Getting start keycard")
                            if os.clock() - firewallState.lastKeycardAttempt >= 1 then
                                firewallState.lastKeycardAttempt = os.clock()
                                local prompt = firewallGetKeycardPrompt(keycard)
                                firewallTeleportInFrontOfPart(firewallGetPromptPart(prompt) or keycard:FindFirstChildWhichIsA("BasePart", true))
                                firewallTriggerPrompt(prompt)
                            end
                        else
                            firewallSetStatus("Waiting for start item")
                        end
                    end

                    task.wait(FIREWALL_RETRY_DELAY)
                    continue
                end

                if startRoom and startDoorOpenValue and startDoorOpenValue.Value == true then
                    local elevator = workspace:FindFirstChild("Elevator")
                    local elevatorKeyPrompt = firewallGetElevatorKeyPrompt()

                    if not elevator then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallState.elevatorKeyStarted = false
                        firewallSetStatus("Waiting for elevator")
                        task.wait(0.25)
                        continue
                    end

                    if elevatorKeyPrompt then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallState.elevatorKeyStarted = true
                        firewallSetStatus("Using elevator key")

                        if os.clock() - firewallState.lastElevatorKeyAttempt >= 1 then
                            firewallState.lastElevatorKeyAttempt = os.clock()
                            firewallTeleportInFrontOfPart(firewallGetPromptPart(elevatorKeyPrompt), 1)
                            firewallTriggerPrompt(elevatorKeyPrompt)
                        end

                        task.wait(FIREWALL_RETRY_DELAY)
                        continue
                    end

                    if not firewallState.elevatorKeyStarted then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallSetStatus("Waiting for elevator key")
                        task.wait(0.25)
                        continue
                    end
                end

                if not firewallState.chaseReady then
                    firewallState.chaseReady = true
                    firewallState.platformsReady = true
                    firewallSetStatus("Running")
                    firewallQueueAllPlatforms()
                    firewallRetargetDoorLoop()
                end

                firewallRefreshRoomLabels()
                task.wait(0.25)
            end
        end)
    end

    local function firewallStartDoorLoop(room, roomNumber)
        firewallState.doorLoopId += 1
        local loopId = firewallState.doorLoopId
        firewallState.currentTargetRoom = room
        firewallState.currentTargetRoomNumber = roomNumber

        task.spawn(function()
            while firewallState.enabled and firewallState.doorLoopId == loopId and room and room.Parent == firewallState.chaseRooms do
                if not firewallState.chaseReady then
                    task.wait(FIREWALL_RETRY_DELAY)
                    continue
                end

                local latestRoom, latestRoomNumber = firewallGetLatestEntranceNotOpenRoom()
                if latestRoom ~= room or latestRoomNumber ~= roomNumber then
                    break
                end

                if firewallIsTooFarAhead(roomNumber) then
                    firewallSetStatus("Paused, waiting for firewall")
                    task.wait(FIREWALL_RETRY_DELAY)
                    continue
                end

                firewallSetStatus("Entering room " .. tostring(roomNumber))
                firewallTeleportAndWalk(room)
                task.wait(FIREWALL_RETRY_DELAY)
            end
        end)
    end

    function firewallRetargetDoorLoop()
        if not firewallState.chaseReady then
            return
        end

        local room, roomNumber = firewallGetLatestEntranceNotOpenRoom()
        if not room or not roomNumber then
            return
        end

        if room == firewallState.currentTargetRoom and roomNumber == firewallState.currentTargetRoomNumber then
            return
        end

        firewallStartDoorLoop(room, roomNumber)
    end

    local function firewallWaitForRoomReady(room, timeout)
        local startTime = os.clock()
        while firewallState.enabled and room and room.Parent == firewallState.chaseRooms and os.clock() - startTime < timeout do
            if firewallGetRoomNumber(room) and firewallFindEntranceOpenValue(room) then
                return true
            end

            task.wait(0.1)
        end

        return false
    end

    local function firewallWatchRoom(room)
        if firewallState.roomConnections[room] then
            return
        end

        local connections = {}
        firewallState.roomConnections[room] = connections

        connections.attributeChanged = room:GetAttributeChangedSignal("RoomNumber"):Connect(function()
            firewallRefreshRoomLabels()
            firewallRetargetDoorLoop()
        end)

        connections.childAdded = room.ChildAdded:Connect(function(child)
            if child.Name == "Entrances" or child.Name == "Exits" or child.Name == "Exists" then
                firewallQueueCreatePlatform(room)
                firewallTrackEntranceOpenValue(room)
                firewallRetargetDoorLoop()
            end
        end)

        connections.descendantAdded = room.DescendantAdded:Connect(function(obj)
            if obj.Name == FIREWALL_PLATFORM_NAME then
                return
            end

            if obj.Name == "OpenValue" then
                firewallTrackEntranceOpenValue(room)
                firewallRetargetDoorLoop()
            end

            if obj:IsA("BasePart") or obj.Name == "Entrances" or obj.Name == "Exits" or obj.Name == "Exists" then
                firewallQueueCreatePlatform(room)
            end
        end)

        firewallQueueCreatePlatform(room)
        firewallTrackEntranceOpenValue(room)
        firewallRefreshRoomLabels()
    end

    local function firewallDisable()
        firewallState.enabled = false
        firewallState.doorLoopId += 1
        firewallState.phaseLoopId += 1
        firewallState.chaseReady = false
        firewallState.platformsReady = false
        firewallState.elevatorKeyStarted = false

        for _, connection in ipairs(firewallState.mainConnections) do
            connection:Disconnect()
        end
        table.clear(firewallState.mainConnections)

        for room in pairs(firewallState.roomConnections) do
            firewallDisconnectRoom(room)
        end

        if firewallState.chaseRooms then
            for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
                local platform = room:FindFirstChild(FIREWALL_PLATFORM_NAME)
                if platform then
                    platform:Destroy()
                end
            end
        end

        firewallState.currentTargetRoom = nil
        firewallState.currentTargetRoomNumber = nil
        firewallState.firewallRoomNumber = nil
        firewallSetStatus("Off")
        firewallRefreshRoomLabels()
    end

    local function firewallEnable()
        if firewallState.enabled then
            return
        end

        local chaseRooms = firewallGetChaseRooms()
        if not chaseRooms then
            firewallSetStatus("ChaseRooms not found")
            return
        end

        firewallState.enabled = true
        firewallState.chaseRooms = chaseRooms
        firewallState.chaseReady = false
        firewallState.platformsReady = false
        firewallState.elevatorKeyStarted = false
        firewallSetStatus("Starting")

        for _, room in ipairs(chaseRooms:GetChildren()) do
            firewallWatchRoom(room)
        end

        firewallRefreshRoomLabels()
        firewallStartPhaseLoop()

        firewallState.mainConnections[#firewallState.mainConnections + 1] = chaseRooms.ChildAdded:Connect(function(room)
            if not firewallState.enabled then
                return
            end

            firewallWatchRoom(room)
            task.spawn(function()
                firewallWaitForRoomReady(room, FIREWALL_TELEPORT_WAIT_TIMEOUT)
                if firewallState.enabled and room and room.Parent == chaseRooms then
                    firewallTrackEntranceOpenValue(room)
                    firewallQueueCreatePlatform(room)
                    task.wait(FIREWALL_REBUILD_DELAY)
                    firewallRefreshRoomLabels()
                    firewallRetargetDoorLoop()
                end
            end)
        end)

        firewallState.mainConnections[#firewallState.mainConnections + 1] = chaseRooms.ChildRemoved:Connect(function(room)
            firewallDisconnectRoom(room)
            firewallRefreshRoomLabels()
            firewallRetargetDoorLoop()
        end)

        firewallState.mainConnections[#firewallState.mainConnections + 1] = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Firewall" then
                task.defer(firewallRefreshRoomLabels)
            end
        end)
    end

    CreateMenu("Pressure")
    CreateGroup("Pressure", "Main")
    CreateTab("Pressure", "Main", "Firewall")

    CreateLabel("Firewall", "Endless Firewall helper")
    firewallRoomLabel = CreateValueLabel("Firewall", "Current Room: None")
    firewallActualRoomLabel = CreateValueLabel("Firewall", "Firewall Room: Unknown")
    firewallStatusLabel = CreateValueLabel("Firewall", "Status: Off")
    CreateToggle("Firewall", "Endless Firewall Helper", function(state)
        if state.Value then
            firewallEnable()
        else
            firewallDisable()
        end
    end, true)

    return
end

local monstersFolder = gameplayFolder:WaitForChild("Monsters", 60)
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
    if not folder then
        return {}
    end
    local t = {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("ObjectValue") and obj.Value then
            table.insert(t, obj.Value)
        end
    end
    return t
end

local function node_buildPath(startNode, endNode)
    if not startNode or not endNode then
        return nil
    end
    local queue = {startNode}
    local visited = {
        [startNode] = true
    }
    local parent = {}
    local found = false
    while #queue > 0 do
        local current = table.remove(queue, 1)
        if current == endNode then
            found = true;
            break
        end
        for _, nxt in ipairs(node_getConnections(current)) do
            if nxt and not visited[nxt] then
                visited[nxt] = true
                parent[nxt] = current
                table.insert(queue, nxt)
            end
        end
    end
    if not found then
        return nil
    end
    local path = {}
    local n = endNode
    while n do
        table.insert(path, 1, n)
        n = parent[n]
    end
    return path
end

local function node_drawPath(path, room)
    if not path then
        return
    end
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
            if inst and inst.Parent then
                pcall(function()
                    inst:Destroy()
                end)
            end
        end
        nodeRoomDrawn[room] = nil
    end
    if nodeInterRoomBeams[room] then
        for _, b in ipairs(nodeInterRoomBeams[room]) do
            if b and b.Parent then
                pcall(function()
                    b:Destroy()
                end)
            end
        end
        nodeInterRoomBeams[room] = nil
    end
    if nodeRoomParts[room] then
        for part, _ in pairs(nodeRoomParts[room]) do
            if part then
                if nodeOriginalTransparency[part] ~= nil then
                    pcall(function()
                        part.Transparency = nodeOriginalTransparency[part]
                    end)
                    nodeOriginalTransparency[part] = nil
                else
                    pcall(function()
                        part.Transparency = 1
                    end)
                end
            end
        end
        nodeRoomParts[room] = nil
    end
end

local function node_getClosestExitNode(entrance, nodesFolder)
    if not nodesFolder then
        return nil
    end
    local closestExit = nil
    local closestDistance = math.huge
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") and node.Name:match("Exit") then
            local ok, dist = pcall(function()
                return (node.Position - entrance.Position).Magnitude
            end)
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
        while room and room.Parent do
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
                        local prevExists = conFolder:FindFirstChild("Previous") and
                                               conFolder.Previous:IsA("ObjectValue") and conFolder.Previous.Value ~= nil
                        local nextExists = conFolder:FindFirstChild("Next") and conFolder.Next:IsA("ObjectValue") and
                                               conFolder.Next.Value ~= nil
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
                            local closestPrev, closestDist = nil, math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local ok, dist = pcall(function()
                                        return (node.Position - other.Position).Magnitude
                                    end)
                                    if ok and dist and dist < closestDist then
                                        closestDist = dist;
                                        closestPrev = other
                                    end
                                end
                            end
                            if closestPrev then
                                pcall(function()
                                    conFolder.Previous.Value = closestPrev
                                end)
                            end
                        end
                        if not nextExists then
                            local allNodes = nodesFolder:GetChildren()
                            local closestNext, closestDist = nil, math.huge
                            for _, other in ipairs(allNodes) do
                                if other ~= node and other:IsA("BasePart") then
                                    local ok, dist = pcall(function()
                                        return (node.Position - other.Position).Magnitude
                                    end)
                                    if ok and dist and dist < closestDist then
                                        closestDist = dist;
                                        closestNext = other
                                    end
                                end
                            end
                            if closestNext then
                                pcall(function()
                                    conFolder.Next.Value = closestNext
                                end)
                            end
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

local function node_drawRoomNodeConnections(room)
    if not nodeVisualizerEnabled then
        node_clearRoomDrawings(room);
        return
    end
    node_clearRoomDrawings(room)
    local nodesFolder = room and room:FindFirstChild("EntityNodes")
    if not nodesFolder then
        return
    end
    nodeRoomDrawn[room] = nodeRoomDrawn[room] or {}
    for _, node in ipairs(nodesFolder:GetChildren()) do
        if node and node:IsA("BasePart") then
            local conFolder = node:FindFirstChild("Connections")
            if conFolder then
                for _, child in ipairs(conFolder:GetChildren()) do
                    if child.Name:match("^Previous") and child:IsA("ObjectValue") and child.Value and
                        child.Value:IsA("BasePart") then
                        local a, b = node, child.Value
                        -- record original transparency before changing
                        if nodeOriginalTransparency[a] == nil then
                            nodeOriginalTransparency[a] = a.Transparency
                        end
                        if nodeOriginalTransparency[b] == nil then
                            nodeOriginalTransparency[b] = b.Transparency
                        end
                        nodeRoomParts[room] = nodeRoomParts[room] or {}
                        nodeRoomParts[room][a] = true
                        nodeRoomParts[room][b] = true
                        a.Transparency = 0
                        b.Transparency = 0
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
        end
    end
    local entrance = nodesFolder:FindFirstChild("Entrance")
    if entrance then
        local closestExit = node_getClosestExitNode(entrance, nodesFolder)
        if closestExit then
            local path = node_buildPath(entrance, closestExit)
            if path then
                node_drawPath(path, room)
            end
        end
    end
end

local function node_connectRoomInternal(room)
    task.spawn(function()
        while true do
            local nodes = room:FindFirstChild("EntityNodes")
            if nodes then
                if nodeVisualizerEnabled then
                    node_drawRoomNodeConnections(room)
                end
                break
            end
            task.wait(0.2)
        end
    end)
end

local function node_connectRoomToPrevious(room)
    task.spawn(function()
        while true do
            local entrancesFolder = room:WaitForChild("Entrances", 5)
            if not entrancesFolder then
                return
            end
            if not nodeVisualizerEnabled then
                if nodeInterRoomBeams[room] then
                    for _, b in ipairs(nodeInterRoomBeams[room]) do
                        if b and b.Parent then
                            pcall(function()
                                b:Destroy()
                            end)
                        end
                    end
                    nodeInterRoomBeams[room] = nil
                end
                break
            end
            if nodeInterRoomBeams[room] then
                for _, beam in ipairs(nodeInterRoomBeams[room]) do
                    if beam and beam.Parent then
                        beam:Destroy()
                    end
                end
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
                                table.insert(nodeInterRoomBeams[room], beam)
                                connectedAny = true
                            end
                        end
                    end
                end
            end
            if connectedAny then
                break
            end
            task.wait(0.2)
        end
    end)
end

local function node_setupNodeListener(room)
    task.spawn(function()
        while true do
            local nodes = room:WaitForChild("EntityNodes", 5)
            if not nodes then
                return
            end
            nodes.ChildAdded:Connect(function()
                node_drawRoomNodeConnections(room)
                node_connectRoomToPrevious(room)
            end)
            nodes.ChildRemoved:Connect(function()
                node_drawRoomNodeConnections(room)
                node_connectRoomToPrevious(room)
            end)
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

for _, room in ipairs(roomsFolder:GetChildren()) do
    node_setupRoom(room)
end
roomsFolder.ChildAdded:Connect(function(room)
    node_setupRoom(room)
end)

local function enableVisualizer()
    nodeVisualizerEnabled = true
    for _, room in ipairs(roomsFolder:GetChildren()) do
        node_drawRoomNodeConnections(room)
        node_connectRoomToPrevious(room)
    end
end

local function disableVisualizer()
    nodeVisualizerEnabled = false
    for _, room in ipairs(roomsFolder:GetChildren()) do
        node_clearRoomDrawings(room)
    end
end

-- expose for compatibility
_G = _G or {}
_G.NodeVisualizerEnable = enableVisualizer
_G.NodeVisualizerDisable = disableVisualizer
-- END Inlined Node Visualizer

-- Feature manager state and registries
local featureState = {
    Fullbright = false,
    NodeVisualizer = false,
    ItemESP = false,
    Notifications = false,
    MonsterVisuals = false,
    ForceHidePopups = false,
    DisableEyefestation = false,
    AutoCrouchEvent = false,
    RemoveAtmosphere = false
}

local activeESPs = {}
local activeTracers = {}
local atmosphereConn = nil
local playerFogConn = nil
local playerFogDescConn = nil
local playerFogLoopId = 0

local function destroyFogLikeObject(obj)
    if not obj then
        return
    end

    if obj:IsA("Atmosphere") then
        pcall(function()
            obj:Destroy()
        end)
        return
    end

    if obj.Name == "FogParticle" then
        pcall(function()
            obj:Destroy()
        end)
        return
    end
end

local function removeFogParticle()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end

    local fog = hrp:FindFirstChild("FogParticle")
    if fog then
        pcall(function()
            fog:Destroy()
        end)
    end

    for _, inst in ipairs(hrp:GetChildren()) do
        if inst.Name == "FogParticle" then
            pcall(function()
                inst:Destroy()
            end)
        end
    end

    for _, inst in ipairs(hrp:GetDescendants()) do
        if inst.Name == "FogParticle" then
            pcall(function()
                inst:Destroy()
            end)
        end
    end
end

local function removeAllAtmospheres()
    for _, inst in ipairs(lighting:GetChildren()) do
        if inst:IsA("Atmosphere") then
            pcall(function()
                inst:Destroy()
            end)
        end
    end

    removeFogParticle()
end

local function bindPlayerFogListener()
    local hrp = char and char:WaitForChild("HumanoidRootPart", 10)
    if not hrp then
        return
    end

    if playerFogConn then
        pcall(function()
            playerFogConn:Disconnect()
        end)
        playerFogConn = nil
    end

    if playerFogDescConn then
        pcall(function()
            playerFogDescConn:Disconnect()
        end)
        playerFogDescConn = nil
    end

    removeFogParticle()

    playerFogConn = hrp.ChildAdded:Connect(function(child)
        if featureState.RemoveAtmosphere and child.Name == "FogParticle" then
            pcall(function()
                child:Destroy()
            end)
        end
    end)

    playerFogDescConn = hrp.DescendantAdded:Connect(function(desc)
        if featureState.RemoveAtmosphere and desc.Name == "FogParticle" then
            pcall(function()
                desc:Destroy()
            end)
        end
    end)

    playerFogLoopId = playerFogLoopId + 1
    local loopId = playerFogLoopId

    task.spawn(function()
        while featureState.RemoveAtmosphere and char and char.Parent and loopId == playerFogLoopId do
            removeFogParticle()
            task.wait(0.1)
        end
    end)
end

local function setupAtmosphereListener()
    if atmosphereConn then
        pcall(function()
            atmosphereConn:Disconnect()
        end)
        atmosphereConn = nil
    end

    atmosphereConn = lighting.ChildAdded:Connect(function(child)
        if featureState.RemoveAtmosphere and child:IsA("Atmosphere") then
            pcall(function()
                child:Destroy()
            end)
        end
    end)

    bindPlayerFogListener()
end

local function cleanupAtmosphereListener()
    playerFogLoopId = playerFogLoopId + 1

    if atmosphereConn then
        pcall(function()
            atmosphereConn:Disconnect()
        end)
        atmosphereConn = nil
    end

    if playerFogConn then
        pcall(function()
            playerFogConn:Disconnect()
        end)
        playerFogConn = nil
    end

    if playerFogDescConn then
        pcall(function()
            playerFogDescConn:Disconnect()
        end)
        playerFogDescConn = nil
    end
end

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
    if featureState.RemoveAtmosphere and hrp then
        setupAtmosphereListener()
        removeAllAtmospheres()
    end
end)

local autoCrouchThread = nil

local function startAutoCrouchEvent()
    if autoCrouchThread then
        return
    end
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

local scanAndDisableAllEyefestation
local setupEyefestationListener
local cleanupEyefestationConns

do
    local activeConnections = {}
    local watchedRooms = {}
    local roomsFolderConnection = nil

    local function hookActive(active)
        if not active or not active:IsA("BoolValue") or active.Name ~= "Active" then
            return
        end

        if activeConnections[active] then
            return
        end

        if featureState.DisableEyefestation then
            active.Value = false
        end

        activeConnections[active] = active:GetPropertyChangedSignal("Value"):Connect(function()
            if featureState.DisableEyefestation then
                active.Value = false
            end
        end)

        active.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local conn = activeConnections[active]
                if conn then
                    conn:Disconnect()
                    activeConnections[active] = nil
                end
            end
        end)
    end

    local function watchEyefestation(eyefestation)
        if not eyefestation or eyefestation.Name ~= "Eyefestation" then
            return
        end

        local active = eyefestation:FindFirstChild("Active") or eyefestation:WaitForChild("Active", 5)
        if active then
            hookActive(active)
        end

        eyefestation.ChildAdded:Connect(function(child)
            if child.Name == "Active" and child:IsA("BoolValue") then
                hookActive(child)
            end
        end)
    end

    local function watchSpawn(spawn)
        if not spawn or spawn.Name ~= "EyefestationSpawn" then
            return
        end

        local eyefestation = spawn:FindFirstChild("Eyefestation") or spawn:WaitForChild("Eyefestation", 5)
        if eyefestation then
            watchEyefestation(eyefestation)
        end

        spawn.ChildAdded:Connect(function(child)
            if child.Name == "Eyefestation" then
                watchEyefestation(child)
            end
        end)
    end

    local function watchInteractables(interactables)
        if not interactables or interactables.Name ~= "Interactables" then
            return
        end

        local spawn = interactables:FindFirstChild("EyefestationSpawn") or interactables:WaitForChild("EyefestationSpawn", 5)
        if spawn then
            watchSpawn(spawn)
        end

        interactables.ChildAdded:Connect(function(child)
            if child.Name == "EyefestationSpawn" then
                watchSpawn(child)
            end
        end)
    end

    local function watchRoom(room)
        if not room or not room:IsA("Model") or watchedRooms[room] then
            return
        end

        watchedRooms[room] = true

        task.spawn(function()
            local interactables = room:FindFirstChild("Interactables") or room:WaitForChild("Interactables", 5)
            if interactables then
                watchInteractables(interactables)
            end
        end)

        room.ChildAdded:Connect(function(child)
            if child.Name == "Interactables" then
                watchInteractables(child)
            end
        end)

        room.AncestryChanged:Connect(function(_, parent)
            if not parent then
                watchedRooms[room] = nil
            end
        end)
    end

    setupEyefestationListener = function()
        if roomsFolderConnection then
            return
        end

        for _, room in ipairs(roomsFolder:GetChildren()) do
            watchRoom(room)
        end

        roomsFolderConnection = roomsFolder.ChildAdded:Connect(function(room)
            watchRoom(room)
        end)
    end

    scanAndDisableAllEyefestation = function()
        for active in pairs(activeConnections) do
            if active and active.Parent and active:IsA("BoolValue") then
                active.Value = false
            end
        end
    end

    cleanupEyefestationConns = function()
    end

    setupEyefestationListener()
end

local popupsConn = nil

local function setPopupsVisibleFalse()
    local main = playerGui:FindFirstChild("Main") or playerGui:WaitForChild("Main", 5)
    if not main then
        return
    end
    local popups = main:FindFirstChild("Popups") or main:WaitForChild("Popups", 5)
    if not popups then
        return
    end
    popups.Visible = false
    if popupsConn then
        pcall(function()
            popupsConn:Disconnect()
        end)
        popupsConn = nil
    end
    popupsConn = popups:GetPropertyChangedSignal("Visible"):Connect(function()
        if featureState.ForceHidePopups then
            popups.Visible = false
        end
    end)
end

local function cleanupPopupsConn()
    if popupsConn then
        pcall(function()
            popupsConn:Disconnect()
        end)
        popupsConn = nil
    end
    local main = playerGui:WaitForChild("Main")
    if not main then
        return
    end
    local popups = main:WaitForChild("Popups")
    if not popups then
        return
    end
    popups.Visible = true
end

-- store original lighting so we can restore when toggled off
local originalLighting = nil

local function applyFullbright()
    if not originalLighting then
        originalLighting = {
            Brightness = lighting.Brightness,
            ClockTime = lighting.ClockTime,
            FogEnd = lighting.FogEnd,
            GlobalShadows = lighting.GlobalShadows,
            OutdoorAmbient = lighting.OutdoorAmbient,
        }
    end
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

local function restoreLighting()
    if not originalLighting then return end
    lighting.Brightness = originalLighting.Brightness
    lighting.ClockTime = originalLighting.ClockTime
    lighting.FogEnd = originalLighting.FogEnd
    lighting.GlobalShadows = originalLighting.GlobalShadows
    lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    originalLighting = nil
end

-- Load UI Library
loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

-- FULLBRIGHT
-- Fullbright is off by default; use UI toggle to enable

local function splitCamelCase(name)
    return name:gsub("(%l)(%u)", "%1 %2")
end

local function CreateNotification(text, color, duration, bypassPerms)
    if not featureState.Notifications and not bypassPerms then
        return
    end
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

    local fadeIn = tweenService:Create(label, TweenInfo.new(0.25), {
        TextTransparency = 0,
        TextStrokeTransparency = 0.5
    })
    fadeIn:Play()

    fadeIn.Completed:Connect(function()
        task.delay(duration, function()
            local fadeOut = tweenService:Create(label, TweenInfo.new(0.5), {
                TextTransparency = 1,
                TextStrokeTransparency = 1
            })
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                gui:Destroy()
            end)
        end)
    end)
end

local function createESP(target, color, customName)
    if not target then
        return nil
    end

    local adornee = target
    if target:IsA("Model") then
        adornee = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    end

    if not adornee or not adornee:IsA("BasePart") then
        return nil
    end

    local b = Instance.new("BillboardGui")
    b.Name = "ESPBillboard"
    b.Adornee = adornee
    b.AlwaysOnTop = true
    b.Size = UDim2.new(0, 100, 0, 100)
    b.Parent = adornee

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

    activeESPs[b] = true
    return b
end

local function clearESPsOfType(espType)
    for inst, _ in pairs(activeESPs) do
        local remove = false
        if not inst or not inst.Parent then
            remove = true
        else
            local t = inst:GetAttribute("ESPType")
            if t == espType then
                pcall(function()
                    inst:Destroy()
                end)
                remove = true
            end
        end
        if remove then
            activeESPs[inst] = nil
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
            if onScreen and viewportPos.Z > 0 then
                local screenCenter = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2,
                    (workspace.CurrentCamera.ViewportSize.Y / 2) + 30)
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
                pcall(function()
                    tracer:Remove()
                end)
                activeTracers[tracer] = nil
            end
            if connection then
                pcall(function()
                    connection:Disconnect()
                end)
            end
            if ancestryConn then
                ancestryConn:Disconnect()
            end
        end
    end)

    -- register tracer for toggle cleanup (store as table with type)
    if tracer then
        activeTracers[tracer] = {
            conn = connection,
            type = espType
        }
    end

    return tracer, connection
end

local function handleDoor(door)
    if door:GetAttribute("VisualHandlerBound") then
        return
    end
    door:SetAttribute("VisualHandlerBound", true)
    -- Track door continuously; only create/cleanup ESP/tracer based on DoorHandling state
    local exitRef = door:FindFirstChild("Exit")
    local prevEntrances = nil
    if exitRef and exitRef.Value then
        local prevRoom = exitRef.Value
        prevEntrances = prevRoom:FindFirstChild("Entrances")
    end

    -- helper to pick a BasePart on which to attach visuals
    local function pickVisualTarget()
        if door:IsA("BasePart") then
            return door
        end
        if door:IsA("Model") then
            return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart")
        end
        return door:FindFirstChild("ProxyPart") or door:FindFirstChild("Part") or
                   door:FindFirstChildWhichIsA("BasePart")
    end

    local created = false
    local createdObjects = {}
    local createdTracerConn = nil
    local openConn

    local function cleanupCreated()
        if openConn then
            pcall(function()
                openConn:Disconnect()
            end)
            openConn = nil
        end
        if createdObjects.esp and createdObjects.esp.Destroy then
            pcall(function()
                createdObjects.esp:Destroy()
            end)
        end
        if createdObjects.tracer then
            pcall(function()
                createdObjects.tracer:Remove()
            end)
        end
        if createdTracerConn then
            pcall(function()
                createdTracerConn:Disconnect()
            end)
        end
        created = false
    end

    local function createVisuals()
        if created or not featureState.DoorHandling then
            return
        end
        local visualTarget = pickVisualTarget()
        if not visualTarget then
            return
        end
        local esp = createESP(visualTarget, Color3.fromRGB(0, 0, 255), "Door")
        if esp and esp.SetAttribute then
            pcall(function()
                esp:SetAttribute("ESPType", "Door")
            end)
        end
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
            openConn = openValue:GetPropertyChangedSignal("Value"):Connect(function()
                if openValue.Value == true then
                    if openConn then
                        pcall(function()
                            openConn:Disconnect()
                        end)
                        openConn = nil
                    end
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
                        for _, c in ipairs(listeners) do
                            pcall(function()
                                c:Disconnect()
                            end)
                        end
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
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        elseif interactionType == "KeyCard" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Keycard")
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        elseif interactionType == "PasswordPaper" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Password")
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        elseif interactionType == "InnerKeyCard" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(0, 150, 200), "Purple Keycard")
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        elseif interactionType == "ItemBase" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(150, 255, 100))
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        elseif interactionType == "Battery" then
            if featureState.ItemESP then
                local b = createESP(v, Color3.fromRGB(125, 100, 50), "Battery")
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        else
            if featureState.ItemESP then
                local b = createESP(v)
                if b and b.SetAttribute then
                    pcall(function()
                        b:SetAttribute("ESPType", "Item")
                    end)
                end
            end
        end
    end
end

local function handleSpawn(spawn)
    for _, v in ipairs(spawn:GetChildren()) do
        detectItem(v)
    end
    spawn.ChildAdded:Connect(function(v)
        detectItem(v)
    end)
end

local function handleSpawnLocation(spawnLocation)
    for _, v in ipairs(spawnLocation:GetChildren()) do
        handleSpawn(v)
    end
    spawnLocation.ChildAdded:Connect(function(v)
        handleSpawn(v)
    end)
end

local function handleRoom(room)
    for _, v in ipairs(room:GetDescendants()) do
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

local workspaceTargetList = {{
    Name = "Angler",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Angler"
}, {
    Name = "RidgeAngler",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Angler"
}, {
    Name = "Pinkie",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pinkie"
}, {
    Name = "RidgePinkie",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pinkie"
}, {
    Name = "Chainsmoker",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Chainsmoker"
}, {
    Name = "RidgeChainsmoker",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Chainsmoker"
}, {
    Name = "Froger",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Froger"
}, {
    Name = "RidgeFroger",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Froger"
}, {
    Name = "Blitz",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Blitz"
}, {
    Name = "RidgeBlitz",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Blitz"
}, {
    Name = "Pandemonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pandemonium",
    remove = true
}, {
    Name = "RidgePandemonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pandemonium",
    remove = true
}, {
    Name = "A60",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "A60"
}, {
    Name = "RidgeA60",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "A60"
}, {
    Name = "Pipsqueak",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pipsqueak",
    remove = true
}, {
    Name = "Parasite",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Parasite"
}, {
    Name = "Mirage",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Mirage",
    CustomLabel = "Keep fucking moving dumbass"
}, {
    Name = "RidgeMirage",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Mirage",
    CustomLabel = "Keep fucking moving dumbass"
}, {
    Name = "Harbinger",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Harbinger",
    CustomLabel = "ur cooked. give up"
}, {
    Name = "RidgeHarbinger",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Harbinger",
    CustomLabel = "ur cooked. give up"
}, {
    Name = "Anglemonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Anglemonium",
    remove = true
}, {
    Name = "Pinkimonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pinkimonium",
    remove = true
}, {
    Name = "Frogermonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Frogermonium",
    remove = true
}, {
    Name = "Pandesmoker",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Pandesmoker",
    remove = true
}, {
    Name = "Blitzemonium",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Blitzemonium",
    remove = true
}, {
    Name = "Bleach",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "Bleach"
}, {
    Name = "A200",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "A200"
}, {
    Name = "WitchingHour",
    Color = Color3.fromRGB(255, 0, 0),
    Label = "WitchingHour",
    remove = true
}}

local function normalizeName(str)
    return tostring(str):lower():gsub("%s+", "")
end

local function findTarget(target, childName, callback)
    task.spawn(function()
        local found = childName and target:WaitForChild(childName, 1) or target
        if found and (found:IsA("BasePart") or found:IsA("Model")) then
            callback(found)
        end
    end)
end

workspace.ChildAdded:Connect(function(child)
    task.spawn(function()
        if not (child:IsA("BasePart") or child:IsA("Model")) then
            return
        end
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
                            if b and b.SetAttribute then
                                pcall(function()
                                    b:SetAttribute("ESPType", "Monster")
                                end)
                            end
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
    for inst, _ in pairs(activeESPs) do
        if inst and inst.Parent then
            pcall(function()
                inst:Destroy()
            end)
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
                if tracer then
                    pcall(function()
                        tracer:Remove()
                    end)
                end
                if info.conn then
                    pcall(function()
                        info.conn:Disconnect()
                    end)
                end
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
                    if target.remove then
                        break
                    end
                    findTarget(child, target.ChildName, function(targetchild)
                        if targetchild then
                            if featureState.MonsterVisuals then
                                local b = createESP(targetchild, target.Color, target.Label)
                                if b and b.SetAttribute then
                                    pcall(function()
                                        b:SetAttribute("ESPType", "Monster")
                                    end)
                                end
                                createTracer(targetchild, target.Color, "Monster")
                            end
                        end
                    end)
                    break
                end
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
                            pcall(function()
                                detectItem(item)
                            end)
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
    elseif name == "RemoveAtmosphere" then
        if enabled then
            removeAllAtmospheres()
            setupAtmosphereListener()
        else
            cleanupAtmosphereListener()
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
        else
            cleanupEyefestationConns()
        end
    elseif name == "ForceHidePopups" then
        if enabled then
            setPopupsVisibleFalse()
        else
            cleanupPopupsConn()
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
        if enabled then
            applyFullbright()
        else
            restoreLighting()
        end
    elseif name == "NodeVisualizer" then
        if enabled then
            if enableVisualizer then
                enableVisualizer()
            end
        else
            if disableVisualizer then
                disableVisualizer()
            end
        end
    end
end


local firewallRoomLabel
local firewallStatusLabel

local firewallState = {
    enabled = false,
    chaseRooms = nil,
    pendingRooms = {},
    roomConnections = {},
    roomOpenValues = {},
    mainConnections = {},
    latestEntranceNotOpenRoom = nil,
    latestEntranceNotOpenRoomNumber = nil,
    lastTeleportedRoom = nil,
    lastTeleportedRoomNumber = nil
}

local FIREWALL_PLATFORM_NAME = "EntranceExitPlatform"
local FIREWALL_PLATFORM_THICKNESS = 1
local FIREWALL_PLATFORM_TRANSPARENCY = 0.5
local FIREWALL_HEIGHT_FRACTION_DOWN = 0.7
local FIREWALL_REBUILD_DELAY = 0.15
local FIREWALL_TELEPORT_WAIT_TIMEOUT = 5
local FIREWALL_TELEPORT_DISTANCE_FROM_DOOR = 8
local FIREWALL_TELEPORT_HEIGHT_OFFSET = 4
local FIREWALL_TELEPORT_SIDE = -1
local FIREWALL_WALK_START_DELAY = 0.15
local FIREWALL_WALK_DURATION = 2.5
local FIREWALL_WALK_SPEED = 22
local FIREWALL_WALK_THROUGH_DISTANCE = 16
local FIREWALL_DELETE_ROOMS_BEHIND = 10

local function firewallSetStatus(text)
    if firewallStatusLabel then
        firewallStatusLabel.Text = "Status: " .. tostring(text)
    end
end

local function firewallGetChaseRooms()
    local elevator = roomsFolder:FindFirstChild("FirewallElevator") or roomsFolder:WaitForChild("FirewallElevator", 5)
    if not elevator then
        return nil
    end

    return elevator:FindFirstChild("ChaseRooms") or elevator:WaitForChild("ChaseRooms", 5)
end

local function firewallGetRoomNumber(room)
    return tonumber(room and room:GetAttribute("RoomNumber"))
end

local function firewallSetCurrentRoomLabel()
    local latestRoomNumber = nil

    if firewallState.chaseRooms then
        for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
            local roomNumber = firewallGetRoomNumber(room)
            if roomNumber and (not latestRoomNumber or roomNumber > latestRoomNumber) then
                latestRoomNumber = roomNumber
            end
        end
    end

    if firewallRoomLabel then
        firewallRoomLabel.Text = latestRoomNumber and ("Current Room: " .. tostring(latestRoomNumber)) or "Current Room: None"
    end
end

local function firewallDeleteRoomClutter(room)
end

local function firewallFindEntranceOpenValue(room)
    local entrances = room:FindFirstChild("Entrances")
    if not entrances then
        return nil
    end

    local openValue = entrances:FindFirstChild("OpenValue", true)
    if openValue and openValue:IsA("ValueBase") then
        return openValue
    end

    return nil
end

local function firewallRebuildLatestEntranceNotOpenRoom()
    local bestRoom = nil
    local bestRoomNumber = nil

    for room, openValue in pairs(firewallState.roomOpenValues) do
        if firewallState.chaseRooms and room:IsDescendantOf(firewallState.chaseRooms) and openValue and openValue.Parent then
            local roomNumber = firewallGetRoomNumber(room)
            if roomNumber and openValue.Value ~= true and (not bestRoomNumber or roomNumber > bestRoomNumber) then
                bestRoom = room
                bestRoomNumber = roomNumber
            end
        end
    end

    firewallState.latestEntranceNotOpenRoom = bestRoom
    firewallState.latestEntranceNotOpenRoomNumber = bestRoomNumber
    firewallSetCurrentRoomLabel()
end

local function firewallDisconnectRoom(room)
    local connections = firewallState.roomConnections[room]
    if connections then
        for _, connection in pairs(connections) do
            if connection then
                connection:Disconnect()
            end
        end
        firewallState.roomConnections[room] = nil
    end

    firewallState.pendingRooms[room] = nil
    firewallState.roomOpenValues[room] = nil
end

local function firewallCleanupOldRooms()
    firewallSetCurrentRoomLabel()
end

local function firewallTrackEntranceOpenValue(room)
    local openValue = firewallFindEntranceOpenValue(room)
    if not openValue or firewallState.roomOpenValues[room] == openValue then
        return
    end

    firewallState.roomOpenValues[room] = openValue
    local connections = firewallState.roomConnections[room]
    if connections then
        if connections.openValueChanged then
            connections.openValueChanged:Disconnect()
        end

        connections.openValueChanged = openValue:GetPropertyChangedSignal("Value"):Connect(firewallRebuildLatestEntranceNotOpenRoom)
    end

    firewallRebuildLatestEntranceNotOpenRoom()
end

local function firewallGetFirstPart(container)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= FIREWALL_PLATFORM_NAME then
            return obj
        end
    end

    return nil
end

local function firewallGetHeightPoint(part)
    local topCenter = part.Position + part.CFrame.UpVector * (part.Size.Y / 2)
    return topCenter - part.CFrame.UpVector * (part.Size.Y * FIREWALL_HEIGHT_FRACTION_DOWN)
end

local function firewallGetRoomWidthAlongPath(room, startPos, endPos)
    local pathDir = endPos - startPos
    if pathDir.Magnitude <= 0 then
        return 10
    end

    pathDir = pathDir.Unit
    local rightDir = pathDir:Cross(Vector3.yAxis)
    rightDir = rightDir.Magnitude < 0.01 and Vector3.xAxis or rightDir.Unit

    local minDot = math.huge
    local maxDot = -math.huge

    for _, obj in ipairs(room:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= FIREWALL_PLATFORM_NAME then
            local cf = obj.CFrame
            local halfSize = obj.Size / 2

            for x = -1, 1, 2 do
                for y = -1, 1, 2 do
                    for z = -1, 1, 2 do
                        local corner = cf.Position
                            + cf.RightVector * halfSize.X * x
                            + cf.UpVector * halfSize.Y * y
                            + cf.LookVector * halfSize.Z * z
                        local dot = corner:Dot(rightDir)
                        minDot = math.min(minDot, dot)
                        maxDot = math.max(maxDot, dot)
                    end
                end
            end
        end
    end

    return minDot == math.huge and 10 or (maxDot - minDot)
end

local function firewallCreatePlatformForRoom(room)
    if not firewallState.enabled or not firewallState.chaseRooms or not room:IsDescendantOf(firewallState.chaseRooms) then
        return
    end

    firewallDeleteRoomClutter(room)
    firewallTrackEntranceOpenValue(room)

    local entrances = room:FindFirstChild("Entrances")
    local exits = room:FindFirstChild("Exits") or room:FindFirstChild("Exists")
    if not entrances or not exits then
        return
    end

    local entrancePart = firewallGetFirstPart(entrances)
    local exitPart = firewallGetFirstPart(exits)
    if not entrancePart or not exitPart then
        return
    end

    local oldPlatform = room:FindFirstChild(FIREWALL_PLATFORM_NAME)
    if oldPlatform then
        oldPlatform:Destroy()
    end

    local startPos = firewallGetHeightPoint(entrancePart)
    local endPos = firewallGetHeightPoint(exitPart)
    local direction = endPos - startPos
    local length = direction.Magnitude
    if length <= 0 then
        return
    end

    local topCenter = (startPos + endPos) / 2
    local width = firewallGetRoomWidthAlongPath(room, startPos, endPos)
    local platformTopCF = CFrame.lookAt(topCenter, endPos, Vector3.yAxis)
    local platformCenter = topCenter - platformTopCF.UpVector * (FIREWALL_PLATFORM_THICKNESS / 2)

    local platform = Instance.new("Part")
    platform.Name = FIREWALL_PLATFORM_NAME
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanTouch = true
    platform.CanQuery = true
    platform.Transparency = FIREWALL_PLATFORM_TRANSPARENCY
    platform.Size = Vector3.new(width, FIREWALL_PLATFORM_THICKNESS, length)
    platform.CFrame = CFrame.lookAt(platformCenter, platformCenter + platformTopCF.LookVector, platformTopCF.UpVector)
    platform.Material = Enum.Material.SmoothPlastic
    platform.Color = Color3.fromRGB(80, 80, 80)
    platform.Parent = room
end

local function firewallQueueCreatePlatform(room)
    if firewallState.pendingRooms[room] then
        return
    end

    firewallState.pendingRooms[room] = true
    task.delay(FIREWALL_REBUILD_DELAY, function()
        firewallState.pendingRooms[room] = nil
        if firewallState.enabled and room and room.Parent == firewallState.chaseRooms then
            firewallCreatePlatformForRoom(room)
            firewallCleanupOldRooms()
        end
    end)
end

local function firewallGetDoorPartFromOpenValue(openValue)
    if not openValue then
        return nil
    end

    local door = openValue.Parent
    if not door then
        return nil
    end

    if door:IsA("BasePart") then
        return door
    end

    if door:IsA("Model") then
        return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
    end

    return door:FindFirstChildWhichIsA("BasePart", true)
end

local function firewallGetTeleportPartForRoom(room)
    local doorPart = firewallGetDoorPartFromOpenValue(firewallFindEntranceOpenValue(room))
    if doorPart then
        return doorPart
    end

    local entrances = room:FindFirstChild("Entrances")
    return entrances and firewallGetFirstPart(entrances) or nil
end

local function firewallGetCharacter()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    return character, root, humanoid
end

local function firewallWalkIntoDoor(character, root, humanoid, doorPart)
    task.delay(FIREWALL_WALK_START_DELAY, function()
        if not character.Parent or not root.Parent or not humanoid.Parent or not doorPart.Parent then
            return
        end

        local oldWalkSpeed = humanoid.WalkSpeed
        local oldAutoRotate = humanoid.AutoRotate
        local walkDirection = doorPart.Position - root.Position
        if walkDirection.Magnitude <= 0 then
            return
        end

        walkDirection = walkDirection.Unit
        local walkTarget = doorPart.Position + walkDirection * FIREWALL_WALK_THROUGH_DISTANCE
        humanoid.WalkSpeed = FIREWALL_WALK_SPEED
        humanoid.AutoRotate = false

        local startTime = os.clock()
        while firewallState.enabled and os.clock() - startTime < FIREWALL_WALK_DURATION do
            if not character.Parent or not root.Parent or not humanoid.Parent then
                break
            end

            local remaining = walkTarget - root.Position
            if remaining.Magnitude <= 1 then
                break
            end

            local currentDirection = remaining.Unit
            root.CFrame = CFrame.lookAt(root.Position, root.Position + currentDirection)
            root.AssemblyLinearVelocity = currentDirection * FIREWALL_WALK_SPEED
            humanoid:Move(currentDirection, false)

            local deltaTime = runService.Heartbeat:Wait()
            root.CFrame = root.CFrame + currentDirection * FIREWALL_WALK_SPEED * deltaTime
        end

        if humanoid.Parent then
            humanoid:Move(Vector3.zero, false)
            humanoid.WalkSpeed = oldWalkSpeed
            humanoid.AutoRotate = oldAutoRotate
        end
    end)
end

local function firewallTeleportLocalPlayerToRoomDoor(room)
    local teleportPart = firewallGetTeleportPartForRoom(room)
    if not teleportPart then
        return
    end

    local character, root, humanoid = firewallGetCharacter()
    if not character or not root or not humanoid then
        return
    end

    local doorBase = teleportPart.Position - teleportPart.CFrame.UpVector * (teleportPart.Size.Y / 2)
    local teleportPosition = doorBase
        + Vector3.yAxis * FIREWALL_TELEPORT_HEIGHT_OFFSET
        + teleportPart.CFrame.LookVector * FIREWALL_TELEPORT_DISTANCE_FROM_DOOR * FIREWALL_TELEPORT_SIDE

    character:PivotTo(CFrame.lookAt(teleportPosition, teleportPart.Position))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    firewallWalkIntoDoor(character, root, humanoid, teleportPart)
end

local function firewallTeleportToLatestEntranceNotOpenRoom()
    firewallRebuildLatestEntranceNotOpenRoom()
    local room = firewallState.latestEntranceNotOpenRoom
    local roomNumber = firewallState.latestEntranceNotOpenRoomNumber
    if not room or not roomNumber then
        return
    end

    if room == firewallState.lastTeleportedRoom and roomNumber == firewallState.lastTeleportedRoomNumber then
        return
    end

    firewallState.lastTeleportedRoom = room
    firewallState.lastTeleportedRoomNumber = roomNumber
    firewallTeleportLocalPlayerToRoomDoor(room)
end

local function firewallWaitForRoomReady(room, timeout)
    local startTime = os.clock()
    while firewallState.enabled and room and room.Parent == firewallState.chaseRooms and os.clock() - startTime < timeout do
        if firewallGetRoomNumber(room) and firewallFindEntranceOpenValue(room) then
            return true
        end
        task.wait(0.1)
    end

    return false
end

local function firewallWatchRoom(room)
    if firewallState.roomConnections[room] then
        return
    end

    firewallDeleteRoomClutter(room)
    local connections = {}
    firewallState.roomConnections[room] = connections

    connections.attributeChanged = room:GetAttributeChangedSignal("RoomNumber"):Connect(function()
        firewallRebuildLatestEntranceNotOpenRoom()
        firewallCleanupOldRooms()
    end)

    connections.childAdded = room.ChildAdded:Connect(function(child)
        if child.Name == "Entrances" or child.Name == "Exits" or child.Name == "Exists" then
            firewallQueueCreatePlatform(room)
            firewallTrackEntranceOpenValue(room)
        end
    end)

    connections.descendantAdded = room.DescendantAdded:Connect(function(obj)
        if obj.Name == FIREWALL_PLATFORM_NAME then
            return
        end

        if obj.Name == "OpenValue" then
            firewallTrackEntranceOpenValue(room)
        end

        if obj:IsA("BasePart") or obj.Name == "Entrances" or obj.Name == "Exits" or obj.Name == "Exists" then
            firewallQueueCreatePlatform(room)
        end
    end)

    firewallQueueCreatePlatform(room)
    firewallTrackEntranceOpenValue(room)
    firewallRebuildLatestEntranceNotOpenRoom()
end

local function firewallDisable()
    firewallState.enabled = false

    for _, connection in ipairs(firewallState.mainConnections) do
        connection:Disconnect()
    end
    table.clear(firewallState.mainConnections)

    for room in pairs(firewallState.roomConnections) do
        firewallDisconnectRoom(room)
    end

    if firewallState.chaseRooms then
        for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
            local platform = room:FindFirstChild(FIREWALL_PLATFORM_NAME)
            if platform then
                platform:Destroy()
            end
        end
    end

    firewallState.latestEntranceNotOpenRoom = nil
    firewallState.latestEntranceNotOpenRoomNumber = nil
    firewallState.lastTeleportedRoom = nil
    firewallState.lastTeleportedRoomNumber = nil
    firewallSetStatus("Off")
    firewallSetCurrentRoomLabel()
end

local function firewallEnable()
    if firewallState.enabled then
        return
    end

    local chaseRooms = firewallGetChaseRooms()
    if not chaseRooms then
        firewallSetStatus("ChaseRooms not found")
        return
    end

    firewallState.enabled = true
    firewallState.chaseRooms = chaseRooms
    firewallSetStatus("Running")

    for _, room in ipairs(chaseRooms:GetChildren()) do
        firewallWatchRoom(room)
    end

    firewallCleanupOldRooms()

    firewallState.mainConnections[#firewallState.mainConnections + 1] = chaseRooms.ChildAdded:Connect(function(room)
        if not firewallState.enabled then
            return
        end

        firewallWatchRoom(room)
        task.spawn(function()
            firewallWaitForRoomReady(room, FIREWALL_TELEPORT_WAIT_TIMEOUT)
            if firewallState.enabled and room and room.Parent == chaseRooms then
                firewallTrackEntranceOpenValue(room)
                firewallQueueCreatePlatform(room)
                task.wait(FIREWALL_REBUILD_DELAY)
                firewallCleanupOldRooms()
                firewallTeleportToLatestEntranceNotOpenRoom()
            end
        end)
    end)

    firewallState.mainConnections[#firewallState.mainConnections + 1] = chaseRooms.ChildRemoved:Connect(function(room)
        firewallDisconnectRoom(room)
        firewallRebuildLatestEntranceNotOpenRoom()
        firewallCleanupOldRooms()
    end)
end

local latestRoomLabel
local latestDoorLabel
local codeLabel

local doorTracker = {
    running = false,
    passwordEnabled = false,
    autoEnterCodeEnabled = false,
    roomConnections = {},
    mainConnections = {},
    roomState = {},
    refreshQueued = false,
    currentLastRoom = nil,
    currentLastDoor = nil,
    highlight = nil,
    autoEnterConnection = nil,
    hookedDoor = nil
}

local function doorDisconnectList(list)
    for i = #list, 1, -1 do
        list[i]:Disconnect()
        list[i] = nil
    end
end

local function doorGetRooms()
    local rooms = {}
    for _, child in ipairs(roomsFolder:GetChildren()) do
        if child:IsA("Model") then
            rooms[#rooms + 1] = child
        end
    end
    return rooms
end

local function doorCleanupHighlight()
    local existing = CoreGui:FindFirstChild("LatestDoorHighlight")
    if existing then
        existing:Destroy()
    end
end

local function doorEnsureHighlight()
    if doorTracker.highlight and doorTracker.highlight.Parent then
        return doorTracker.highlight
    end

    doorCleanupHighlight()

    local highlight = Instance.new("Highlight")
    highlight.Name = "LatestDoorHighlight"
    highlight.FillColor = Color3.fromRGB(0, 120, 255)
    highlight.OutlineColor = Color3.fromRGB(0, 120, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = CoreGui

    doorTracker.highlight = highlight
    return highlight
end

local function doorGetEntrances(room)
    return room and room:FindFirstChild("Entrances") or nil
end

local function doorComputeDoorModel(room)
    local entrances = doorGetEntrances(room)
    if not entrances then
        return nil
    end

    for _, child in ipairs(entrances:GetChildren()) do
        if child:IsA("Model") then
            local exitValue = child:FindFirstChild("Exit")
            if exitValue and exitValue:IsA("ObjectValue") then
                return child
            end
        end
    end

    return nil
end

local function doorUpdateRoomState(room)
    local state = doorTracker.roomState[room]
    if not state then
        state = {}
        doorTracker.roomState[room] = state
    end

    local doorModel = doorComputeDoorModel(room)
    state.doorModel = doorModel

    if doorModel then
        local exitValue = doorModel:FindFirstChild("Exit")
        if exitValue and exitValue:IsA("ObjectValue") then
            state.previousRoom = exitValue.Value
            return
        end
    end

    state.previousRoom = nil
end

local function doorGetOrderedRooms()
    local rooms = doorGetRooms()
    local roomSet = {}

    for _, room in ipairs(rooms) do
        roomSet[room] = true
        if not doorTracker.roomState[room] then
            doorUpdateRoomState(room)
        end
    end

    local firstRoom = nil

    for _, room in ipairs(rooms) do
        local state = doorTracker.roomState[room]
        local previousRoom = state and state.previousRoom

        if not roomSet[previousRoom] then
            firstRoom = room
            break
        end
    end

    if not firstRoom then
        return {}
    end

    local orderedRooms = {}
    local used = {}
    local currentRoom = firstRoom

    while currentRoom and not used[currentRoom] do
        orderedRooms[#orderedRooms + 1] = currentRoom
        used[currentRoom] = true

        local nextRoom = nil

        for _, room in ipairs(rooms) do
            if not used[room] then
                local state = doorTracker.roomState[room]
                if state and state.previousRoom == currentRoom then
                    nextRoom = room
                    break
                end
            end
        end

        currentRoom = nextRoom
    end

    return orderedRooms
end

local function doorGetCodeText()
    if not doorTracker.passwordEnabled then
        return "No Code"
    end

    local door = doorTracker.currentLastDoor
    if not door then
        return "No Code"
    end

    local locked = door:GetAttribute("Locked")
    if not locked then
        return "No Code"
    end

    local exitValue = door:FindFirstChild("Exit")
    if not exitValue or not exitValue:IsA("ObjectValue") then
        return "No Code"
    end

    local codeRoom = exitValue.Value
    if not codeRoom then
        return "No Code"
    end

    local passwordPaper = codeRoom:FindFirstChild("PasswordPaper", true)
    if not passwordPaper then
        return "No Code"
    end

    local codeObject = passwordPaper:FindFirstChild("Code")
    if not codeObject then
        return "No Code"
    end

    local surfaceGui = codeObject:FindFirstChild("SurfaceGui")
    if not surfaceGui then
        return "No Code"
    end

    local textLabel = surfaceGui:FindFirstChild("TextLabel")
    if not textLabel or not textLabel:IsA("TextLabel") then
        return "No Code"
    end

    local text = textLabel.Text
    if type(text) ~= "string" or text == "" then
        return "No Code"
    end

    return text
end

local function doorSetLabels()
    if latestRoomLabel then
        if doorTracker.currentLastRoom then
            latestRoomLabel.Text = "Latest Room: " .. doorTracker.currentLastRoom.Name
        else
            latestRoomLabel.Text = "Latest Room: None"
        end
    end

    if latestDoorLabel then
        if doorTracker.currentLastDoor then
            latestDoorLabel.Text = "Latest Door: " .. doorTracker.currentLastDoor.Name
        else
            latestDoorLabel.Text = "Latest Door: None"
        end
    end

    if codeLabel then
        codeLabel.Text = "Code: " .. doorGetCodeText()
    end
end

local function doorDisconnectAutoEnter()
    if doorTracker.autoEnterConnection then
        doorTracker.autoEnterConnection:Disconnect()
        doorTracker.autoEnterConnection = nil
    end

    doorTracker.hookedDoor = nil
end

local function doorGetPrompt(door)
    local prompt = door and door:FindFirstChild("ProximityPrompt", true)
    if prompt and prompt:IsA("ProximityPrompt") then
        return prompt
    end
    return nil
end

local function doorGetRemote(door)
    return door and door:FindFirstChild("RemoteFunction", true) or nil
end

local function doorSetupAutoEnterForCurrentDoor()
    doorDisconnectAutoEnter()

    if not doorTracker.autoEnterCodeEnabled then
        return
    end

    local door = doorTracker.currentLastDoor
    if not door then
        return
    end

    local locked = door:GetAttribute("Locked")
    if not locked then
        return
    end

    local code = doorGetCodeText()
    if code == "No Code" then
        return
    end

    local prompt = doorGetPrompt(door)
    local remote = doorGetRemote(door)

    if not prompt or not remote then
        return
    end

    doorTracker.hookedDoor = door
    doorTracker.autoEnterConnection = prompt.PromptShown:Connect(function()
        local latestCode = doorGetCodeText()
        if latestCode == "No Code" then
            return
        end

        pcall(function()
            local current = ""
            for i = 1, #latestCode do
                current = current .. string.sub(latestCode, i, i)
                remote:InvokeServer(current)
                task.wait(0.05)
            end
        end)
    end)
end

local function doorUpdateTrackedLastDoor()
    local orderedRooms = doorGetOrderedRooms()
    doorTracker.currentLastRoom = orderedRooms[#orderedRooms]

    if doorTracker.currentLastRoom then
        local state = doorTracker.roomState[doorTracker.currentLastRoom]
        doorTracker.currentLastDoor = state and state.doorModel or nil
    else
        doorTracker.currentLastDoor = nil
    end

    local highlight = doorEnsureHighlight()

    if doorTracker.currentLastDoor then
        highlight.Adornee = doorTracker.currentLastDoor
        highlight.Enabled = true
    else
        highlight.Adornee = nil
        highlight.Enabled = false
    end

    doorSetLabels()
    doorSetupAutoEnterForCurrentDoor()
end

local function doorQueueRefresh()
    if not doorTracker.running or doorTracker.refreshQueued then
        return
    end

    doorTracker.refreshQueued = true

    task.defer(function()
        doorTracker.refreshQueued = false
        if doorTracker.running then
            doorUpdateTrackedLastDoor()
        end
    end)
end

local function doorRemoveRoomState(room)
    doorTracker.roomState[room] = nil
end

local function doorDisconnectRoomConnections(room)
    local connections = doorTracker.roomConnections[room]
    if connections then
        doorDisconnectList(connections)
        doorTracker.roomConnections[room] = nil
    end
    doorRemoveRoomState(room)
end

local function doorOnRoomStructureChanged(room)
    if not doorTracker.running or not room.Parent then
        return
    end

    doorUpdateRoomState(room)
    doorQueueRefresh()
end

local function doorWatchRoom(room)
    if not room:IsA("Model") then
        return
    end

    if doorTracker.roomConnections[room] then
        return
    end

    doorUpdateRoomState(room)

    local connections = {}
    doorTracker.roomConnections[room] = connections

    connections[#connections + 1] = room.AncestryChanged:Connect(function(_, parent)
        if not parent then
            doorDisconnectRoomConnections(room)
            doorQueueRefresh()
        end
    end)

    connections[#connections + 1] = room.DescendantAdded:Connect(function(descendant)
        local entrances = doorGetEntrances(room)
        if not entrances then
            return
        end

        if descendant.Parent == entrances then
            doorOnRoomStructureChanged(room)
            return
        end

        if descendant:IsA("ObjectValue") and descendant.Name == "Exit" and descendant.Parent and descendant.Parent.Parent == entrances then
            doorOnRoomStructureChanged(room)
            return
        end

        if doorTracker.passwordEnabled or doorTracker.autoEnterCodeEnabled then
            if descendant.Name == "PasswordPaper" or descendant.Name == "TextLabel" or descendant.Name == "Code" or descendant.Name == "ProximityPrompt" or descendant.Name == "RemoteFunction" then
                doorQueueRefresh()
            end
        end
    end)

    connections[#connections + 1] = room.DescendantRemoving:Connect(function(descendant)
        local entrances = doorGetEntrances(room)
        if not entrances then
            return
        end

        if descendant.Parent == entrances then
            doorOnRoomStructureChanged(room)
            return
        end

        if descendant:IsA("ObjectValue") and descendant.Name == "Exit" and descendant.Parent and descendant.Parent.Parent == entrances then
            doorOnRoomStructureChanged(room)
            return
        end

        if doorTracker.passwordEnabled or doorTracker.autoEnterCodeEnabled then
            if descendant.Name == "PasswordPaper" or descendant.Name == "TextLabel" or descendant.Name == "Code" or descendant.Name == "ProximityPrompt" or descendant.Name == "RemoteFunction" then
                doorQueueRefresh()
            end
        end
    end)

    local entrances = doorGetEntrances(room)
    if entrances then
        connections[#connections + 1] = entrances.ChildAdded:Connect(function()
            doorOnRoomStructureChanged(room)
        end)

        connections[#connections + 1] = entrances.ChildRemoved:Connect(function()
            doorOnRoomStructureChanged(room)
        end)
    end
end

local function doorStopTracker()
    doorTracker.running = false
    doorTracker.refreshQueued = false

    doorDisconnectAutoEnter()

    for room in pairs(doorTracker.roomConnections) do
        doorDisconnectRoomConnections(room)
    end

    doorDisconnectList(doorTracker.mainConnections)

    if doorTracker.highlight then
        doorTracker.highlight.Adornee = nil
        doorTracker.highlight.Enabled = false
    end

    doorTracker.currentLastRoom = nil
    doorTracker.currentLastDoor = nil
    doorSetLabels()
end

local function doorStartTracker()
    if doorTracker.running then
        return
    end

    doorTracker.running = true
    doorEnsureHighlight()

    for _, room in ipairs(doorGetRooms()) do
        doorWatchRoom(room)
    end

    doorTracker.mainConnections[#doorTracker.mainConnections + 1] = roomsFolder.ChildAdded:Connect(function(room)
        if not doorTracker.running then
            return
        end
        if room:IsA("Model") then
            doorWatchRoom(room)
            doorQueueRefresh()
        end
    end)

    doorTracker.mainConnections[#doorTracker.mainConnections + 1] = roomsFolder.ChildRemoved:Connect(function(room)
        if not doorTracker.running then
            return
        end
        if room:IsA("Model") then
            doorDisconnectRoomConnections(room)
            doorQueueRefresh()
        end
    end)

    doorUpdateTrackedLastDoor()
end

local function onPlayerAdded(player)
    local health = player:WaitForChild("PlayerFolder"):WaitForChild("Health")
    health:GetPropertyChangedSignal("Value"):Connect(function()
        if health.Value <= 0 then
            CreateNotification(player.DisplayName .. " sold", Color3.fromRGB(255, 0, 0), 2.5, true)
        end
    end)
end

for _, player in players:GetChildren() do
	onPlayerAdded(player)
end

players.PlayerAdded:Connect(onPlayerAdded)

-- ============================================================
-- UI (Lib.lua)
-- ============================================================
CreateMenu("Pressure")
CreateGroup("Pressure", "Main")
CreateTab("Pressure", "Main", "Visuals")
CreateTab("Pressure", "Main", "World")
CreateTab("Pressure", "Main", "Doors")

CreateLabel("Visuals", "Monster, item and door visuals")
CreateToggle("Visuals", "Monster Visuals", function(state)
    setFeature("MonsterVisuals", state.Value)
end, false)

CreateToggle("Visuals", "Item ESP", function(state)
    setFeature("ItemESP", state.Value)
end, false)

CreateToggle("Visuals", "Force Hide Popups", function(state)
    setFeature("ForceHidePopups", state.Value)
end, false)

CreateLabel("World", "Environment and utility features")

CreateLabel("Doors", "Latest door tracking")
latestRoomLabel = CreateValueLabel("Doors", "Latest Room: None")
latestDoorLabel = CreateValueLabel("Doors", "Latest Door: None")
codeLabel = CreateValueLabel("Doors", "Code: No Code")
CreateToggle("Doors", "Track Latest Door", function(state)
    if state.Value then
        doorStartTracker()
    else
        doorStopTracker()
    end
end, true)
CreateToggle("Doors", "Get Password", function(state)
    doorTracker.passwordEnabled = state.Value
    if doorTracker.running then
        doorUpdateTrackedLastDoor()
    else
        doorSetLabels()
    end
end, false)
CreateToggle("Doors", "Auto Enter Code", function(state)
    doorTracker.autoEnterCodeEnabled = state.Value
    doorSetupAutoEnterForCurrentDoor()
end, false)

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

CreateToggle("World", "Remove Fog", function(state)
    setFeature("RemoveAtmosphere", state.Value)
end, false)

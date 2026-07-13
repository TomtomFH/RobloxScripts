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
local playerGui = player:WaitForChild("PlayerGui")

local CHAT_NOTIFICATION_USERNAME = "PressureAnyPercent"
local chatNotificationHookedScrollViews = {}
local chatNotificationProcessedRows = {}
local chatNotificationHookedLabels = {}
local chatNotificationCoreGuiHooked = false

local function chatNotificationStripRichText(text)
    text = text or ""
    text = text:gsub("<br%s*/>", "\n")
    text = text:gsub("<[^>]->", "")
    return text
end

local function chatNotificationTrim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function chatNotificationExtractSender(senderText)
    local sender = chatNotificationTrim(senderText)

    while sender:match("^%[[^%]]+%]%s*") do
        sender = chatNotificationTrim(sender:gsub("^%[[^%]]+%]%s*", "", 1))
    end

    return sender:match("([^%s]+)$") or sender
end

local function chatNotificationRemoveLeadingTags(text)
    local withoutTags = text or ""
    while withoutTags:match("^%s*%[[^%]]+%]%s*") do
        withoutTags = withoutTags:gsub("^%s*%[[^%]]+%]%s*", "", 1)
    end

    return chatNotificationTrim(withoutTags)
end

local function CreateChatNotification(text, color, duration)
    duration = duration or 4
    color = color or Color3.fromRGB(255, 255, 255)

    local gui = Instance.new("ScreenGui")
    gui.Name = "ChatNotificationGui"
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

local function chatNotificationGetScrollView()
    local ok, result = pcall(function()
        return CoreGui
            :WaitForChild("ExperienceChat", 5)
            :WaitForChild("appLayout", 5)
            :WaitForChild("chatWindow", 5)
            :WaitForChild("contentFrame", 5)
            :WaitForChild("scrollingView", 5)
            :WaitForChild("bottomLockedScrollView", 5)
            :WaitForChild("scrollView", 5)
    end)

    return ok and result or nil
end

local function chatNotificationParseMessage(bodyText)
    local cleanBody = chatNotificationStripRichText(bodyText)
    local fromName, message = cleanBody:match("^%s*%[From%s+([^%]]+)%]%s+.-:%s*(.*)$")
    if not fromName then
        local withoutTags = chatNotificationRemoveLeadingTags(cleanBody)
        fromName, message = withoutTags:match("^%s*(%S+)%s*:%s*(.*)$")
    end

    local sender = chatNotificationExtractSender(fromName)

    if sender ~= CHAT_NOTIFICATION_USERNAME then
        return nil
    end

    message = chatNotificationTrim(message)
    if message:sub(1, 1) ~= "-" then
        return nil
    end

    local notificationText = chatNotificationTrim(message:sub(2))
    return notificationText ~= "" and notificationText or message
end

local function chatNotificationFindMessageRow(bodyTextLabel)
    local current = bodyTextLabel
    while current and current.Parent do
        if chatNotificationHookedScrollViews[current.Parent] then
            return current
        end

        current = current.Parent
    end

    local textMessage = bodyTextLabel:FindFirstAncestor("TextMessage")
    if textMessage and textMessage.Parent then
        return textMessage.Parent
    end

    return bodyTextLabel
end

local function chatNotificationHideMessage(bodyTextLabel, row)
    local target = row or chatNotificationFindMessageRow(bodyTextLabel)
    if not target or not target.Parent then
        return
    end

    if target:IsA("GuiObject") then
        target.Visible = false
        return
    end

    for _, descendant in ipairs(target:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            descendant.Visible = false
        end
    end
end

local function chatNotificationProcessBodyTextLabel(bodyTextLabel, row)
    if not bodyTextLabel or not bodyTextLabel:IsA("TextLabel") then
        return
    end

    if chatNotificationHookedLabels[bodyTextLabel] then
        return
    end

    chatNotificationHookedLabels[bodyTextLabel] = true

    local function processText()
        local notificationText = chatNotificationParseMessage(bodyTextLabel.Text)
        if notificationText then
            CreateChatNotification(notificationText, Color3.fromRGB(255, 0, 0), 2.5)
            chatNotificationHideMessage(bodyTextLabel, row)
        end
    end

    processText()
    bodyTextLabel:GetPropertyChangedSignal("Text"):Connect(processText)
end

local function chatNotificationWaitForBodyText(row)
    for _ = 1, 20 do
        local textMessage = row:FindFirstChild("TextMessage", true)
        if textMessage then
            local bodyTextLabel = textMessage:FindFirstChild("BodyText", true)
            if bodyTextLabel then
                return bodyTextLabel
            end
        end

        task.wait(0.05)
    end

    return nil
end

local function chatNotificationProcessRow(row)
    if chatNotificationProcessedRows[row] then
        return
    end

    chatNotificationProcessedRows[row] = true
    task.spawn(function()
        local bodyTextLabel = chatNotificationWaitForBodyText(row)
        if bodyTextLabel then
            chatNotificationProcessBodyTextLabel(bodyTextLabel, row)
        end
    end)
end

local function chatNotificationHookMessageList(scrollView)
    if not scrollView or chatNotificationHookedScrollViews[scrollView] then
        return
    end

    chatNotificationHookedScrollViews[scrollView] = true
    for _, row in ipairs(scrollView:GetChildren()) do
        chatNotificationProcessRow(row)
    end

    scrollView.ChildAdded:Connect(chatNotificationProcessRow)
end

local function chatNotificationHookCoreGuiFallback()
    if chatNotificationCoreGuiHooked then
        return
    end

    chatNotificationCoreGuiHooked = true

    for _, descendant in ipairs(CoreGui:GetDescendants()) do
        if descendant.Name == "BodyText" and descendant:IsA("TextLabel") then
            chatNotificationProcessBodyTextLabel(descendant)
        end
    end

    CoreGui.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "BodyText" and descendant:IsA("TextLabel") then
            chatNotificationProcessBodyTextLabel(descendant)
        end
    end)
end

task.spawn(function()
    chatNotificationHookCoreGuiFallback()

    while task.wait(1) do
        local scrollView = chatNotificationGetScrollView()
        if scrollView then
            chatNotificationHookMessageList(scrollView)
        end
    end
end)

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
    local firewallMouseAimLabel = nil

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
        currentRoomNumber = nil,
        firewallRoomNumber = nil,
        chaseReady = false,
        platformsReady = false,
        lastKeycardAttempt = 0,
        lastElevatorKeyAttempt = 0,
        elevatorKeyStarted = false,
        chaseTeleportUsed = false,
        mouseAimId = 0,
        lastMouseAimDebug = 0
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
    local FIREWALL_WALK_DURATION = 1.25
    local FIREWALL_RETRY_DELAY = 1.5
    local FIREWALL_MAX_ROOMS_AHEAD = 10
    local FIREWALL_PROMPT_DISTANCE = 5
    local FIREWALL_ELEVATOR_KEY_DISTANCE = 3
    local FIREWALL_PROMPT_HEIGHT_OFFSET = 2.5
    local FIREWALL_PROMPT_EYE_HEIGHT = 1.5
    local FIREWALL_MOUSE_AIM_DURATION = 0.8
    local FIREWALL_MOUSE_AIM_SCALE = 0.35
    local FIREWALL_MOUSE_AIM_DEADZONE = 8
    local FIREWALL_MOUSE_AIM_BIND_NAME = "TomtomFirewallPromptMouseAim"
    local FIREWALL_MOUSE_AIM_PRIORITY = 300
    local FIREWALL_DOOR_LOOK_DURATION = 0.25
    local FIREWALL_CHASE_DRY_RUN = false
    local FIREWALL_TELEPORT_GLIDE_TIME = 5
    local FIREWALL_TELEPORT_DROP_HEIGHT = 3

    local function firewallSetStatus(text)
        if firewallStatusLabel then
            firewallStatusLabel.Text = "Status: " .. tostring(text)
        end
    end

    local function firewallSetMouseAimDebug(text, force)
        if not firewallMouseAimLabel then
            return
        end

        local now = os.clock()
        if not force and now - firewallState.lastMouseAimDebug < 0.15 then
            return
        end

        firewallState.lastMouseAimDebug = now
        firewallMouseAimLabel.Text = "Mouse Aim: " .. tostring(text)
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

    local function firewallGetModelPosition(model)
        if not model or not model.Parent then
            return nil
        end

        local ok, cf = pcall(function()
            return model:GetBoundingBox()
        end)

        return ok and cf.Position or nil
    end

    local function firewallGetFirstPart(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= FIREWALL_PLATFORM_NAME then
                return obj
            end
        end

        return nil
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

    local function firewallGetRoomBounds(room)
        if not room then
            return nil, nil
        end

        local ok, cf, size = pcall(function()
            return room:GetBoundingBox()
        end)

        if not ok then
            return nil, nil
        end

        return cf, size
    end

    local function firewallPointInsideRoomBounds(room, position, margin)
        local cf, size = firewallGetRoomBounds(room)
        if not cf or not size or not position then
            return false
        end

        margin = margin or 3
        local localPosition = cf:PointToObjectSpace(position)
        return math.abs(localPosition.X) <= (size.X / 2) + margin
            and math.abs(localPosition.Y) <= (size.Y / 2) + margin
            and math.abs(localPosition.Z) <= (size.Z / 2) + margin
    end

    local function firewallGetRoomPathParts(room)
        local entrances = room and room:FindFirstChild("Entrances")
        local exits = room and (room:FindFirstChild("Exits") or room:FindFirstChild("Exists"))
        return entrances and firewallGetFirstPart(entrances) or nil, exits and firewallGetFirstPart(exits) or nil
    end

    local function firewallGetRoomPositionScore(room, position)
        if not room or not position then
            return nil
        end

        local entrancePart, exitPart = firewallGetRoomPathParts(room)
        if entrancePart and exitPart then
            local startPosition = entrancePart.Position
            local endPosition = exitPart.Position
            local path = endPosition - startPosition
            local pathLengthSquared = path:Dot(path)

            if pathLengthSquared > 0.01 then
                local t = math.clamp((position - startPosition):Dot(path) / pathLengthSquared, 0, 1)
                local closest = startPosition + path * t
                local lateral = Vector3.new(position.X - closest.X, 0, position.Z - closest.Z).Magnitude
                local vertical = math.abs(position.Y - closest.Y)
                local outsidePenalty = 0

                if t <= 0 or t >= 1 then
                    local rawT = (position - startPosition):Dot(path) / pathLengthSquared
                    outsidePenalty = math.abs(rawT - t) * math.sqrt(pathLengthSquared)
                end

                local score = lateral + vertical * 0.25 + outsidePenalty * 2
                if firewallPointInsideRoomBounds(room, position, 4) then
                    score -= 100
                end

                return score
            end
        end

        local center = firewallGetRoomCenter(room)
        if center then
            local score = (center - position).Magnitude
            if firewallPointInsideRoomBounds(room, position, 4) then
                score -= 100
            end

            return score
        end

        return nil
    end

    local function firewallGetClosestRoomNumberToPosition(position)
        if not position or not firewallState.chaseRooms then
            return nil
        end

        local closestRoomNumber = nil
        local closestScore = math.huge
        local containedRoomNumber = nil
        local containedScore = math.huge

        for _, room in ipairs(firewallState.chaseRooms:GetChildren()) do
            local roomNumber = firewallGetRoomNumber(room)
            local score = firewallGetRoomPositionScore(room, position)

            if roomNumber and score and score < closestScore then
                closestScore = score
                closestRoomNumber = roomNumber
            end

            if roomNumber and score and firewallPointInsideRoomBounds(room, position, 2) and score < containedScore then
                containedScore = score
                containedRoomNumber = roomNumber
            end
        end

        return containedRoomNumber or closestRoomNumber
    end

    local function firewallGetCharacterRootPosition()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return root and root.Position or nil
    end

    local function firewallUpdateRoomLabel()
        local roomNumber = firewallGetClosestRoomNumberToPosition(firewallGetCharacterRootPosition())

        firewallState.currentRoomNumber = roomNumber
        if firewallRoomLabel then
            firewallRoomLabel.Text = roomNumber and ("Current Room: " .. tostring(roomNumber)) or "Current Room: Unknown"
        end

        return roomNumber
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

    local firewallRetargetDoorLoop

    local function firewallIsRoomBehindCurrent(roomNumber)
        local currentRoomNumber = firewallState.currentRoomNumber or firewallUpdateRoomLabel()
        return currentRoomNumber and roomNumber and roomNumber < currentRoomNumber
    end

    local function firewallGetLatestEntranceNotOpenRoom()
        local bestRoom = nil
        local bestRoomNumber = nil
        local currentRoomNumber = firewallState.currentRoomNumber or firewallUpdateRoomLabel()

        for room, openValue in pairs(firewallState.roomOpenValues) do
            if firewallState.chaseRooms and room:IsDescendantOf(firewallState.chaseRooms) and openValue and openValue.Parent then
                local roomNumber = firewallGetRoomNumber(room)
                local teleportPart = firewallGetTeleportPartForRoom(room)
                local isBehindCurrent = currentRoomNumber and roomNumber and roomNumber < currentRoomNumber
                if roomNumber and not isBehindCurrent and teleportPart and openValue.Value ~= true and (not bestRoomNumber or roomNumber > bestRoomNumber) then
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
                task.defer(function()
                    if firewallRetargetDoorLoop then
                        firewallRetargetDoorLoop()
                    end
                end)
            end)
        end
    end

    local function firewallGetCharacter()
        local character = player.Character or player.CharacterAdded:Wait()
        local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        return character, root, humanoid
    end

    local firewallMouseAimAtPosition

    local function firewallWalkThroughDoor(character, root, humanoid, doorPart, throughDistance)
        if not character or not root or not humanoid or not doorPart then
            return
        end

        local startOffset = Vector3.new(doorPart.Position.X - root.Position.X, 0, doorPart.Position.Z - root.Position.Z)
        if startOffset.Magnitude <= 0 then
            return
        end

        local walkDirection = startOffset.Unit
        local walkDistance = throughDistance or startOffset.Magnitude
        local flatDoorPosition = Vector3.new(doorPart.Position.X, root.Position.Y, doorPart.Position.Z)
        local walkTarget = flatDoorPosition + walkDirection * walkDistance
        local oldWalkSpeed = humanoid.WalkSpeed
        local oldAutoRotate = humanoid.AutoRotate

        humanoid.WalkSpeed = FIREWALL_WALK_SPEED
        humanoid.AutoRotate = false

        local startTime = os.clock()
        if firewallMouseAimAtPosition then
            task.spawn(firewallMouseAimAtPosition, flatDoorPosition, FIREWALL_WALK_DURATION)
        end

        while firewallState.enabled and os.clock() - startTime < FIREWALL_WALK_DURATION do
            if not character.Parent or not root.Parent or not humanoid.Parent then
                break
            end

            local remaining = walkTarget - root.Position
            if remaining.Magnitude <= 1 then
                break
            end

            local flatRemaining = Vector3.new(remaining.X, 0, remaining.Z)
            if flatRemaining.Magnitude <= 0 then
                break
            end

            local currentDirection = flatRemaining.Unit
            root.CFrame = CFrame.lookAt(root.Position, root.Position + currentDirection)
            root.AssemblyLinearVelocity = currentDirection * FIREWALL_WALK_SPEED
            root.AssemblyAngularVelocity = Vector3.zero
            humanoid:Move(currentDirection, false)

            local deltaTime = runService.Heartbeat:Wait()
            root.CFrame = root.CFrame + currentDirection * FIREWALL_WALK_SPEED * deltaTime
        end

        if humanoid.Parent then
            humanoid:Move(Vector3.zero, false)
            humanoid.WalkSpeed = oldWalkSpeed
            humanoid.AutoRotate = oldAutoRotate
        end

        if root.Parent then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local function firewallGetDoorApproachDirection(teleportPart, useRightVector)
        local vector = useRightVector and teleportPart.CFrame.RightVector or teleportPart.CFrame.LookVector
        local direction = Vector3.new(vector.X, 0, vector.Z)
        if direction.Magnitude <= 0 then
            direction = Vector3.zAxis
        end

        return direction.Unit * FIREWALL_TELEPORT_SIDE
    end

    local function firewallTeleportToPartAndWalk(teleportPart, useRightVector)
        if not teleportPart then
            return
        end

        local character, root, humanoid = firewallGetCharacter()
        if not character or not root or not humanoid then
            return
        end

        local doorBase = teleportPart.Position - teleportPart.CFrame.UpVector * (teleportPart.Size.Y / 2)
        local approachDirection = firewallGetDoorApproachDirection(teleportPart, useRightVector)
        local teleportPosition = doorBase
            + Vector3.yAxis * FIREWALL_TELEPORT_HEIGHT_OFFSET
            + approachDirection * FIREWALL_TELEPORT_DISTANCE_FROM_DOOR

        local lookTarget = Vector3.new(teleportPart.Position.X, teleportPosition.Y, teleportPart.Position.Z)
        local targetCFrame = CFrame.lookAt(teleportPosition, lookTarget)
        character:PivotTo(targetCFrame)
        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if firewallMouseAimAtPosition then
            task.spawn(firewallMouseAimAtPosition, lookTarget, FIREWALL_MOUSE_AIM_DURATION)
        end
        firewallWalkThroughDoor(character, root, humanoid, teleportPart, FIREWALL_TELEPORT_DISTANCE_FROM_DOOR)
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

    local function firewallGetFirewallElevatorRoom()
        return roomsFolder:FindFirstChild("FirewallElevator")
    end

    local function firewallGetFirewallEndRoom()
        return roomsFolder:FindFirstChild("FirewallEnd")
    end

    local function firewallGetPartFromInstance(instance)
        if not instance then
            return nil
        end

        if instance:IsA("BasePart") then
            return instance
        end

        if instance:IsA("Model") then
            return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
        end

        return instance:FindFirstChildWhichIsA("BasePart", true)
    end

    local function firewallGetInteractableDoor(room, doorName)
        local interactables = room and room:FindFirstChild("Interactables")
        return interactables and interactables:FindFirstChild(doorName) or nil
    end

    local function firewallGetInteractableDoorInfo(room, doorName)
        local door = firewallGetInteractableDoor(room, doorName)
        local part = firewallGetPartFromInstance(door)
        local openValue = door and door:FindFirstChild("OpenValue")
        return door, part, openValue and openValue:IsA("BoolValue") and openValue or nil
    end

    local function firewallGetStartInteractableDoorInfo()
        return firewallGetInteractableDoorInfo(firewallGetFirewallStartRoom(), "NormalDoor")
    end

    local function firewallGetElevatorBigDoorInfo()
        return firewallGetInteractableDoorInfo(firewallGetFirewallElevatorRoom(), "BigDoor")
    end

    local function firewallGetTutorialTeleportTrigger()
        local elevatorRoom = firewallGetFirewallElevatorRoom()
        local chaseRooms = elevatorRoom and elevatorRoom:FindFirstChild("ChaseRooms")
        local tutorialStart = chaseRooms and chaseRooms:FindFirstChild("1FirewallTutorialStart")
        local triggers = tutorialStart and tutorialStart:FindFirstChild("Triggers")
        local teleport = triggers and triggers:FindFirstChild("Teleport")
        return teleport and teleport:IsA("BasePart") and teleport or nil
    end

    local function firewallGetWouldEnterText()
        local room, roomNumber = firewallGetLatestEntranceNotOpenRoom()
        if not room or not roomNumber then
            return "Would enter: no closed chase door found"
        end

        local teleportPart = firewallGetTeleportPartForRoom(room)
        local positionText = teleportPart and string.format(
            " @ %.1f, %.1f, %.1f",
            teleportPart.Position.X,
            teleportPart.Position.Y,
            teleportPart.Position.Z
        ) or ""

        return "Would enter room " .. tostring(roomNumber) .. positionText
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

    local function firewallStopMouseAim()
        pcall(function()
            runService:UnbindFromRenderStep(FIREWALL_MOUSE_AIM_BIND_NAME)
        end)
    end

    local function firewallSendMouseMove(dx, dy)
        if type(mousemoverel) ~= "function" then
            firewallSetMouseAimDebug("mousemoverel missing", true)
            return false
        end

        mousemoverel(dx, dy)
        firewallSetMouseAimDebug(string.format("move dx=%.1f dy=%.1f", dx, dy))
        return true
    end

    local function firewallMouseAimStep(targetPosition)
        local camera = workspace.CurrentCamera
        if not camera or not targetPosition then
            firewallSetMouseAimDebug(not camera and "no camera" or "no target", true)
            return false
        end

        local viewportPoint, visible = camera:WorldToViewportPoint(targetPosition)
        local dx, dy

        if visible and viewportPoint.Z > 0 then
            local center = camera.ViewportSize / 2
            local delta = Vector2.new(viewportPoint.X - center.X, viewportPoint.Y - center.Y)
            if math.abs(delta.X) <= FIREWALL_MOUSE_AIM_DEADZONE and math.abs(delta.Y) <= FIREWALL_MOUSE_AIM_DEADZONE then
                firewallSetMouseAimDebug(string.format("deadzone dx=%.1f dy=%.1f", delta.X, delta.Y))
                return true
            end

            dx = delta.X * FIREWALL_MOUSE_AIM_SCALE
            dy = delta.Y * FIREWALL_MOUSE_AIM_SCALE
        else
            local direction = targetPosition - camera.CFrame.Position
            if direction.Magnitude <= 0 then
                firewallSetMouseAimDebug("target overlaps camera", true)
                return false
            end

            local localDirection = camera.CFrame:VectorToObjectSpace(direction.Unit)
            local yaw = math.atan2(localDirection.X, -localDirection.Z)
            local flat = math.sqrt(localDirection.X * localDirection.X + localDirection.Z * localDirection.Z)
            local pitch = math.atan2(localDirection.Y, flat)

            dx = math.deg(yaw) * 8
            dy = -math.deg(pitch) * 8
        end

        return firewallSendMouseMove(math.clamp(dx, -250, 250), math.clamp(dy, -250, 250))
    end

    firewallMouseAimAtPosition = function(targetPosition, duration)
        if type(mousemoverel) ~= "function" then
            firewallSetMouseAimDebug("mousemoverel missing", true)
            return
        end

        if not targetPosition then
            firewallSetMouseAimDebug("start missing target", true)
            return
        end

        firewallState.mouseAimId += 1
        local aimId = firewallState.mouseAimId

        pcall(function()
            game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.LockCenter
        end)

        firewallStopMouseAim()
        firewallSetMouseAimDebug("started", true)
        runService:BindToRenderStep(FIREWALL_MOUSE_AIM_BIND_NAME, FIREWALL_MOUSE_AIM_PRIORITY, function()
            firewallMouseAimStep(targetPosition)
        end)

        local startTime = os.clock()
        while firewallState.mouseAimId == aimId and os.clock() - startTime < (duration or FIREWALL_MOUSE_AIM_DURATION) do
            runService.RenderStepped:Wait()
        end

        if firewallState.mouseAimId == aimId then
            firewallStopMouseAim()
            firewallSetMouseAimDebug("stopped", true)
        end
    end

    local function firewallTeleportToPart(part)
        if not part then
            return
        end

        local character, root = firewallGetCharacter()
        if not character or not root then
            return
        end

        local position = part.Position
        local lookDirection = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
        if lookDirection.Magnitude <= 0 then
            lookDirection = Vector3.zAxis
        end

        character:PivotTo(CFrame.lookAt(position, position + lookDirection.Unit))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local function firewallGlideFromDoorToTeleport(doorPart, teleportPart)
        if not doorPart or not teleportPart then
            return
        end

        firewallTeleportToPartAndWalk(doorPart, true)
        task.wait(0.15)

        local character, root, humanoid = firewallGetCharacter()
        if not character or not root then
            return
        end

        local lookDirection = Vector3.new(teleportPart.CFrame.LookVector.X, 0, teleportPart.CFrame.LookVector.Z)
        if lookDirection.Magnitude <= 0 then
            lookDirection = Vector3.zAxis
        end

        local glidePosition = Vector3.new(teleportPart.Position.X, root.Position.Y, teleportPart.Position.Z)
        local glideCFrame = CFrame.lookAt(glidePosition, glidePosition + lookDirection.Unit)
        local oldAutoRotate = humanoid and humanoid.AutoRotate or nil
        if humanoid then
            humanoid.AutoRotate = false
        end

        local velocityConnection = runService.Heartbeat:Connect(function()
            if root and root.Parent then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        local tween = tweenService:Create(root, TweenInfo.new(FIREWALL_TELEPORT_GLIDE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            CFrame = glideCFrame
        })
        tween:Play()
        tween.Completed:Wait()

        if velocityConnection then
            velocityConnection:Disconnect()
        end

        if root and root.Parent then
            local dropPosition = teleportPart.Position + Vector3.yAxis * FIREWALL_TELEPORT_DROP_HEIGHT
            root.CFrame = CFrame.lookAt(dropPosition, dropPosition + lookDirection.Unit)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        if humanoid and oldAutoRotate ~= nil then
            task.delay(0.5, function()
                if humanoid.Parent then
                    humanoid.AutoRotate = oldAutoRotate
                end
            end)
        end
    end

    local function firewallGetTargetContainer(part)
        if not part then
            return nil
        end

        local container = part:FindFirstAncestorOfClass("Model") or part.Parent
        if container == workspace then
            return part
        end

        return container or part
    end

    local function firewallRayHitsTarget(hit, targetPart)
        if not hit or not hit.Instance then
            return true
        end

        if hit.Instance == targetPart then
            return true
        end

        local targetContainer = firewallGetTargetContainer(targetPart)
        return targetContainer and hit.Instance:IsDescendantOf(targetContainer) or false
    end

    local function firewallHasLineOfSight(fromPosition, targetPosition, targetPart, character)
        local direction = targetPosition - fromPosition
        if direction.Magnitude <= 0 then
            return false
        end

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = character and { character } or {}
        raycastParams.IgnoreWater = true

        local hit = workspace:Raycast(fromPosition, direction, raycastParams)
        return firewallRayHitsTarget(hit, targetPart)
    end

    local function firewallAddDirectionCandidate(candidates, direction)
        if direction.Magnitude <= 0.05 then
            return
        end

        table.insert(candidates, Vector3.new(direction.X, 0, direction.Z).Unit)
    end

    local function firewallGetVisiblePromptPosition(part, character, root, sideMultiplier, distance, heightOffset, useRightVector)
        local targetPosition = part.Position
        local promptDistance = distance or FIREWALL_PROMPT_DISTANCE
        local promptHeight = heightOffset or FIREWALL_PROMPT_HEIGHT_OFFSET
        local side = sideMultiplier or -1
        local lookVector = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
        local rightVector = Vector3.new(part.CFrame.RightVector.X, 0, part.CFrame.RightVector.Z)
        local primaryVector = useRightVector and rightVector or lookVector
        local secondaryVector = useRightVector and lookVector or rightVector
        local rootOffset = root and Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z) or Vector3.zero
        local candidates = {}

        firewallAddDirectionCandidate(candidates, primaryVector * side)
        firewallAddDirectionCandidate(candidates, rootOffset)
        firewallAddDirectionCandidate(candidates, primaryVector * -side)
        firewallAddDirectionCandidate(candidates, secondaryVector)
        firewallAddDirectionCandidate(candidates, secondaryVector * -1)
        firewallAddDirectionCandidate(candidates, (primaryVector * side) + secondaryVector)
        firewallAddDirectionCandidate(candidates, (primaryVector * side) - secondaryVector)
        firewallAddDirectionCandidate(candidates, (primaryVector * -side) + secondaryVector)
        firewallAddDirectionCandidate(candidates, (primaryVector * -side) - secondaryVector)
        firewallAddDirectionCandidate(candidates, Vector3.xAxis)
        firewallAddDirectionCandidate(candidates, -Vector3.xAxis)
        firewallAddDirectionCandidate(candidates, Vector3.zAxis)
        firewallAddDirectionCandidate(candidates, -Vector3.zAxis)

        local bestPosition = nil
        for _, direction in ipairs(candidates) do
            local position = targetPosition + direction * promptDistance + Vector3.yAxis * promptHeight
            local eyePosition = position + Vector3.yAxis * FIREWALL_PROMPT_EYE_HEIGHT

            if firewallHasLineOfSight(eyePosition, targetPosition, part, character) then
                return position
            end

            bestPosition = bestPosition or position
        end

        return bestPosition or (targetPosition + Vector3.zAxis * promptDistance + Vector3.yAxis * promptHeight)
    end

    local function firewallTeleportInFrontOfPart(part, sideMultiplier, distance, heightOffset, useRightVector)
        if not part then
            return
        end

        local character, root, humanoid = firewallGetCharacter()
        if not character or not root then
            return
        end

        local targetPosition = part.Position
        local position = firewallGetVisiblePromptPosition(part, character, root, sideMultiplier, distance, heightOffset, useRightVector)
        local lookTarget = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
        local targetCFrame = CFrame.lookAt(position, lookTarget)

        if humanoid then
            humanoid.AutoRotate = false
        end

        character:PivotTo(targetCFrame)
        root.CFrame = targetCFrame
        firewallMouseAimAtPosition(targetPosition, FIREWALL_MOUSE_AIM_DURATION)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        if humanoid then
            task.delay(0.8, function()
                if humanoid.Parent then
                    humanoid.AutoRotate = true
                end
            end)
        end
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
            runService.RenderStepped:Wait()
            runService.RenderStepped:Wait()
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
    local firewallRefreshChaseRooms
    local firewallWaitForClosedChaseDoor

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
                        firewallTeleportInFrontOfPart(doorPart, -1, nil, nil, true)
                        firewallEnterDoorCode(startDoor, code)
                    elseif firewallHasNormalKeycard() then
                        local prompt = firewallGetDoorPrompt(startDoor)
                        firewallSetStatus("Using start keycard")
                        firewallTeleportInFrontOfPart(firewallGetPromptPart(prompt) or firewallGetDoorPartFromOpenValue(startDoorOpenValue), -1, nil, nil, true)
                        firewallTriggerPrompt(prompt)
                    else
                        local keycard = firewallGetStartKeycard()
                        if keycard then
                            firewallSetStatus("Getting start keycard")
                            if os.clock() - firewallState.lastKeycardAttempt >= 1 then
                                firewallState.lastKeycardAttempt = os.clock()
                                local prompt = firewallGetKeycardPrompt(keycard)
                                firewallTeleportInFrontOfPart(firewallGetPromptPart(prompt) or keycard:FindFirstChildWhichIsA("BasePart", true), -1)
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
                    local _, startInteractableDoorPart, startInteractableDoorOpenValue = firewallGetStartInteractableDoorInfo()
                    if not startInteractableDoorOpenValue then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallSetStatus("Waiting for start firewall door")
                        task.wait(0.25)
                        continue
                    end

                    if startInteractableDoorOpenValue.Value ~= true then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        if not startInteractableDoorPart then
                            firewallSetStatus("Waiting for start firewall door part")
                            task.wait(0.25)
                            continue
                        end

                        firewallSetStatus("Entering start firewall door")
                        firewallTeleportToPartAndWalk(startInteractableDoorPart, true)
                        task.wait(FIREWALL_RETRY_DELAY)
                        continue
                    end

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
                            firewallTeleportInFrontOfPart(firewallGetPromptPart(elevatorKeyPrompt), 1, FIREWALL_ELEVATOR_KEY_DISTANCE)
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

                local firewallElevatorRoom = firewallGetFirewallElevatorRoom()
                local firewallEndRoom = firewallGetFirewallEndRoom()

                if not startRoom and (not firewallElevatorRoom or not firewallEndRoom) then
                    firewallState.chaseReady = false
                    firewallState.platformsReady = false
                    firewallSetStatus("Waiting for chase rooms")
                    task.wait(0.25)
                    continue
                end

                if not startRoom and firewallElevatorRoom and firewallEndRoom then
                    local firewallModel = workspace:FindFirstChild("Firewall")

                    if not firewallModel then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false

                        local _, bigDoorPart, bigDoorOpenValue = firewallGetElevatorBigDoorInfo()
                        if not bigDoorOpenValue then
                            firewallSetStatus("Waiting for elevator big door")
                            task.wait(0.25)
                            continue
                        end

                        if bigDoorOpenValue.Value ~= true then
                            if not bigDoorPart then
                                firewallSetStatus("Waiting for elevator big door part")
                                task.wait(0.25)
                                continue
                            end

                            firewallSetStatus("Entering elevator big door")
                            firewallTeleportToPartAndWalk(bigDoorPart, true)
                            task.wait(FIREWALL_RETRY_DELAY)
                            continue
                        end

                        if not bigDoorPart then
                            firewallSetStatus("Waiting for elevator big door part")
                            task.wait(0.25)
                            continue
                        end

                        local teleportTrigger = firewallGetTutorialTeleportTrigger()

                        if teleportTrigger and not firewallState.chaseTeleportUsed then
                            firewallState.chaseTeleportUsed = true
                            firewallSetStatus("Entering firewall chase")
                            firewallGlideFromDoorToTeleport(bigDoorPart, teleportTrigger)
                        elseif teleportTrigger then
                            firewallSetStatus("Waiting for firewall")
                        else
                            firewallSetStatus("Waiting for chase teleport")
                        end

                        task.wait(FIREWALL_RETRY_DELAY)
                        continue
                    end

                    firewallRefreshChaseRooms()

                    if FIREWALL_CHASE_DRY_RUN then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallState.doorLoopId += 1
                        firewallSetStatus(firewallGetWouldEnterText())
                        firewallRefreshRoomLabels()
                        task.wait(0.25)
                        continue
                    end

                    if not firewallState.chaseReady then
                        if not firewallWaitForClosedChaseDoor(FIREWALL_TELEPORT_WAIT_TIMEOUT) then
                            firewallState.chaseReady = false
                            firewallState.platformsReady = false
                            firewallSetStatus("Waiting for chase doors")
                            firewallRefreshRoomLabels()
                            task.wait(0.25)
                            continue
                        end

                        firewallState.chaseReady = true
                        firewallState.platformsReady = true
                        firewallSetStatus("Running")
                        firewallQueueAllPlatforms()
                        firewallRetargetDoorLoop()
                    end

                    firewallRefreshRoomLabels()
                    if firewallState.chaseReady and firewallRetargetDoorLoop then
                        firewallRetargetDoorLoop()
                    end
                    task.wait(0.25)
                    continue
                end

                if not firewallState.chaseReady then
                    if not firewallWaitForClosedChaseDoor(FIREWALL_TELEPORT_WAIT_TIMEOUT) then
                        firewallState.chaseReady = false
                        firewallState.platformsReady = false
                        firewallSetStatus("Waiting for chase doors")
                        firewallRefreshRoomLabels()
                        task.wait(0.25)
                        continue
                    end

                    firewallState.chaseReady = true
                    firewallState.platformsReady = true
                    firewallSetStatus("Running")
                    firewallQueueAllPlatforms()
                    firewallRetargetDoorLoop()
                end

                firewallRefreshRoomLabels()
                if firewallState.chaseReady and firewallRetargetDoorLoop then
                    firewallRetargetDoorLoop()
                end
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

                if firewallIsRoomBehindCurrent(roomNumber) then
                    break
                end

                if firewallIsTooFarAhead(roomNumber) then
                    firewallSetStatus("Paused, waiting for firewall")
                    task.wait(FIREWALL_RETRY_DELAY)
                    continue
                end

                local teleportPart = firewallGetTeleportPartForRoom(room)
                if not teleportPart then
                    firewallSetStatus("Waiting for room " .. tostring(roomNumber) .. " door")
                    firewallRefreshChaseRooms()
                    task.wait(FIREWALL_RETRY_DELAY)
                    continue
                end

                if FIREWALL_CHASE_DRY_RUN then
                    local positionText = teleportPart and string.format(
                        " @ %.1f, %.1f, %.1f",
                        teleportPart.Position.X,
                        teleportPart.Position.Y,
                        teleportPart.Position.Z
                    ) or ""
                    firewallSetStatus("Would enter room " .. tostring(roomNumber) .. positionText)
                else
                    firewallSetStatus("Entering room " .. tostring(roomNumber))
                    firewallTeleportToPartAndWalk(teleportPart)
                end

                task.wait(FIREWALL_RETRY_DELAY)
            end

            if firewallState.enabled and firewallState.doorLoopId == loopId and firewallState.chaseReady then
                firewallState.currentTargetRoom = nil
                firewallState.currentTargetRoomNumber = nil
                task.defer(function()
                    if firewallRetargetDoorLoop then
                        firewallRetargetDoorLoop()
                    end
                end)
            end
        end)
    end

    firewallRetargetDoorLoop = function()
        if not firewallState.chaseReady then
            return
        end

        local room, roomNumber = firewallGetLatestEntranceNotOpenRoom()
        if not room or not roomNumber then
            firewallSetStatus("Scanning chase doors")
            firewallRefreshChaseRooms()
            return
        end

        if room == firewallState.currentTargetRoom and roomNumber == firewallState.currentTargetRoomNumber then
            return
        end

        firewallStartDoorLoop(room, roomNumber)
    end

    local firewallWatchRoom

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

    firewallRefreshChaseRooms = function()
        local chaseRooms = firewallGetChaseRooms()
        if not chaseRooms then
            return false
        end

        if firewallState.chaseRooms ~= chaseRooms then
            for room in pairs(firewallState.roomConnections) do
                firewallDisconnectRoom(room)
            end

            firewallState.chaseRooms = chaseRooms
            firewallState.currentTargetRoom = nil
            firewallState.currentTargetRoomNumber = nil
        end

        for _, room in ipairs(chaseRooms:GetChildren()) do
            firewallWatchRoom(room)
            firewallTrackEntranceOpenValue(room)
        end

        firewallRefreshRoomLabels()
        return true
    end

    local function firewallHasClosedChaseDoor()
        local room, roomNumber = firewallGetLatestEntranceNotOpenRoom()
        return room ~= nil and roomNumber ~= nil
    end

    firewallWaitForClosedChaseDoor = function(timeout)
        local startTime = os.clock()
        repeat
            firewallRefreshChaseRooms()

            if firewallHasClosedChaseDoor() then
                return true
            end

            firewallSetStatus("Scanning chase doors")
            task.wait(0.15)
        until not firewallState.enabled or os.clock() - startTime >= timeout

        return firewallHasClosedChaseDoor()
    end

    firewallWatchRoom = function(room)
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
        firewallState.chaseTeleportUsed = false

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
        firewallState.chaseTeleportUsed = false
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
    firewallMouseAimLabel = CreateValueLabel("Firewall", "Mouse Aim: Idle")
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
    RemoveLopee = false,
    AutoCrouchEvent = false,
    RemoveAtmosphere = false
}

local activeESPs = {}
local activeTracers = {}
local createESP
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
    local attributeConnections = {}
    local watchedRooms = {}
    local roomsFolderConnections = {}
    local pendingLiveInspections = setmetatable({}, { __mode = "k" })
    local eyefestationESPs = setmetatable({}, { __mode = "k" })

    local function isEyefestationName(name)
        return string.find(string.lower(name or ""), "eyefestation", 1, true) ~= nil
    end

    local function hookActive(active)
        if not active or not active:IsA("BoolValue") or active.Name ~= "Active" then
            return
        end

        if featureState.DisableEyefestation and active.Value ~= false then
            active.Value = false
        end

        if activeConnections[active] then
            return
        end

        activeConnections[active] = active:GetPropertyChangedSignal("Value"):Connect(function()
            if featureState.DisableEyefestation and active.Value ~= false then
                active.Value = false

                task.defer(function()
                    if featureState.DisableEyefestation and active.Parent and active.Value ~= false then
                        active.Value = false
                    end
                end)
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

    local function isExactEyefestationActive(active)
        if not active:IsA("BoolValue") or active.Name ~= "Active" then
            return false
        end

        local parent = active.Parent
        local grandparent = parent and parent.Parent

        return (parent ~= nil and parent.Name == "Eyefestation")
            or (grandparent ~= nil and grandparent.Name == "Eyefestation")
    end

    local function hookActiveAttribute(target)
        if not target or attributeConnections[target] then
            return
        end

        if featureState.DisableEyefestation and target:GetAttribute("Active") ~= nil then
            target:SetAttribute("Active", false)
        end

        attributeConnections[target] = target:GetAttributeChangedSignal("Active"):Connect(function()
            if featureState.DisableEyefestation and target:GetAttribute("Active") ~= false then
                target:SetAttribute("Active", false)
            end
        end)

        target.AncestryChanged:Connect(function(_, parent)
            if not parent then
                local connection = attributeConnections[target]
                if connection then
                    connection:Disconnect()
                    attributeConnections[target] = nil
                end
            end
        end)
    end

    local function findEyefestationAncestor(instance, room)
        local current = instance.Parent

        while current do
            if isEyefestationName(current.Name) then
                return current
            end
            if current == room then
                break
            end
            current = current.Parent
        end

        return nil
    end

    local function removeEyefestation(eyefestation)
        if not featureState.DisableEyefestation
            or not eyefestation
            or eyefestation.Name ~= "Eyefestation"
            or not eyefestation.Parent
        then
            return false
        end

        local parent = eyefestation.Parent
        local existing = eyefestationESPs[parent]

        if createESP and (not existing or not existing.Parent) then
            local billboard = createESP(parent, Color3.fromRGB(255, 0, 0), "Eyefestation")
            if billboard then
                billboard:SetAttribute("ESPType", "Monster")
                eyefestationESPs[parent] = billboard
            end
        end

        eyefestation:Destroy()
        return true
    end

    local function inspectRoomDescendant(room, descendant)
        if isEyefestationName(descendant.Name) then
            local eyefestation = descendant.Name == "Eyefestation"
                and descendant
                or descendant:FindFirstChild("Eyefestation", true)

            if eyefestation and removeEyefestation(eyefestation) then
                return
            end
        end

        if isExactEyefestationActive(descendant) then
            hookActive(descendant)
        elseif isEyefestationName(descendant.Name) then
            hookActiveAttribute(descendant)

            local active = descendant:FindFirstChild("Active", true)
            if active and active:IsA("BoolValue") then
                hookActive(active)
            end
        elseif descendant:IsA("BoolValue") and descendant.Name == "Active" then
            if findEyefestationAncestor(descendant, room) then
                hookActive(descendant)
            end
        end
    end

    local function scheduleLiveInspection(room, descendant)
        local relevant = descendant.Name == "Active" or isEyefestationName(descendant.Name)
        if not relevant then
            return
        end

        inspectRoomDescendant(room, descendant)

        if not descendant.Parent then
            return
        end

        if descendant:IsA("BoolValue")
            and descendant.Name == "Active"
            and activeConnections[descendant]
        then
            return
        end

        if isEyefestationName(descendant.Name) then
            local active = descendant:FindFirstChild("Active", true)
            if active and activeConnections[active] then
                return
            end
        end

        if pendingLiveInspections[descendant] then
            return
        end

        pendingLiveInspections[descendant] = true

        task.spawn(function()
            for _ = 1, 40 do
                if not descendant.Parent then
                    break
                end

                inspectRoomDescendant(room, descendant)

                if descendant:IsA("BoolValue") and descendant.Name == "Active" then
                    if activeConnections[descendant] then
                        break
                    end
                elseif isEyefestationName(descendant.Name) then
                    local active = descendant:FindFirstChild("Active", true)
                    if active and activeConnections[active] then
                        break
                    end
                end

                task.wait(0.05)
            end

            pendingLiveInspections[descendant] = nil
        end)
    end

    local function unwatchRoom(room)
        local record = watchedRooms[room]
        watchedRooms[room] = nil

        if not record then
            return
        end

        for _, connection in ipairs(record.connections) do
            connection:Disconnect()
        end

        for active, connection in pairs(activeConnections) do
            if active:IsDescendantOf(room) then
                connection:Disconnect()
                activeConnections[active] = nil
            end
        end

        for target, connection in pairs(attributeConnections) do
            if target == room or target:IsDescendantOf(room) then
                connection:Disconnect()
                attributeConnections[target] = nil
            end
        end
    end

    local function watchRoom(room)
        if not room or watchedRooms[room] then
            return
        end

        local record = { connections = {} }
        watchedRooms[room] = record

        record.connections[#record.connections + 1] = room.DescendantAdded:Connect(function(descendant)
            scheduleLiveInspection(room, descendant)
        end)

        local existingEyefestation = room:FindFirstChild("Eyefestation", true)
        if existingEyefestation then
            inspectRoomDescendant(room, existingEyefestation)
        end

        local existingSpawn = room:FindFirstChild("EyefestationSpawn", true)
        if existingSpawn then
            inspectRoomDescendant(room, existingSpawn)
        end

        task.spawn(function()
            local queue = { room }
            local index = 1
            local processedCount = 0

            while index <= #queue and room.Parent do
                local parent = queue[index]
                index = index + 1

                for _, child in ipairs(parent:GetChildren()) do
                    inspectRoomDescendant(room, child)
                    table.insert(queue, child)
                    processedCount = processedCount + 1

                    if processedCount % 100 == 0 then
                        task.wait()
                    end
                end
            end
        end)

        record.connections[#record.connections + 1] = room.AncestryChanged:Connect(function(_, parent)
            if not parent then
                unwatchRoom(room)
            end
        end)
    end

    setupEyefestationListener = function()
        if #roomsFolderConnections > 0 then
            return
        end

        for _, room in ipairs(roomsFolder:GetChildren()) do
            watchRoom(room)
        end

        roomsFolderConnections[#roomsFolderConnections + 1] = roomsFolder.ChildAdded:Connect(function(room)
            watchRoom(room)
        end)

        roomsFolderConnections[#roomsFolderConnections + 1] = roomsFolder.ChildRemoved:Connect(function(room)
            unwatchRoom(room)
        end)

        roomsFolderConnections[#roomsFolderConnections + 1] = roomsFolder.DescendantAdded:Connect(function(descendant)
            scheduleLiveInspection(roomsFolder, descendant)
        end)

        roomsFolderConnections[#roomsFolderConnections + 1] = workspace.DescendantAdded:Connect(function(descendant)
            if descendant.Name ~= "Active" and not isEyefestationName(descendant.Name) then
                return
            end

            scheduleLiveInspection(workspace, descendant)
        end)

        roomsFolderConnections[#roomsFolderConnections + 1] = runService.Stepped:Connect(function()
            if not featureState.DisableEyefestation then
                return
            end

            for active in pairs(activeConnections) do
                if active.Parent and active.Value ~= false then
                    active.Value = false
                end
            end
        end)

        roomsFolderConnections[#roomsFolderConnections + 1] = runService.Heartbeat:Connect(function()
            if not featureState.DisableEyefestation then
                return
            end

            for active in pairs(activeConnections) do
                if active.Parent and active.Value then
                    active.Value = false
                end
            end

            for target in pairs(attributeConnections) do
                if target.Parent and target:GetAttribute("Active") == true then
                    target:SetAttribute("Active", false)
                end
            end
        end)
    end

    scanAndDisableAllEyefestation = function()
        for _, descendant in ipairs(roomsFolder:GetDescendants()) do
            if isExactEyefestationActive(descendant) then
                hookActive(descendant)
            else
                inspectRoomDescendant(roomsFolder, descendant)
            end
        end

        for active in pairs(activeConnections) do
            if active and active.Parent and active:IsA("BoolValue") then
                active.Value = false
            end
        end

        for target in pairs(attributeConnections) do
            if target and target.Parent and target:GetAttribute("Active") ~= nil then
                target:SetAttribute("Active", false)
            end
        end

        for _, room in ipairs(roomsFolder:GetChildren()) do
            local eyefestation = room:FindFirstChild("Eyefestation", true)
            if eyefestation then
                inspectRoomDescendant(room, eyefestation)
            end

            local spawn = room:FindFirstChild("EyefestationSpawn", true)
            if spawn then
                inspectRoomDescendant(room, spawn)
            end
        end
    end

    cleanupEyefestationConns = function()
        for active, connection in pairs(activeConnections) do
            if not active.Parent then
                connection:Disconnect()
                activeConnections[active] = nil
            end
        end

        for target, connection in pairs(attributeConnections) do
            if not target.Parent then
                connection:Disconnect()
                attributeConnections[target] = nil
            end
        end
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

createESP = function(target, color, customName)
    if not target then
        return nil
    end

    local adornee = target
    if target:IsA("Model") then
        adornee = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
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
    b.Destroying:Connect(function()
        activeESPs[b] = nil
    end)
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

local trackedItemNames = {}
local trackedItemESPs = setmetatable({}, { __mode = "k" })
local itemRoomConnections = {}

local function addTrackedNames(names)
    for _, name in ipairs(names) do
        trackedItemNames[name] = true
    end
end

addTrackedNames({
    "AltBattery1", "AltBattery2", "AltBattery3", "DefaultBattery1", "DefaultBattery2",
    "DefaultBattery3", "RoomsBattery", "Neostyk1", "Neostyk2", "Neostyk3",
    "BigFlashBeacon", "Defib", "Lantern", "Blueprint", "Caps", "DoorsGold1",
    "DoorsGold2", "DoorsGold3", "GOLDDD", "HypnoCoin", "Regret", "Studs",
    "SuperCredits", "DrawerLandmine", "Landmine", "Relic", "BeaconGun", "Blacklight", "Book",
    "CaptainsCompass", "Chainsaw", "CodeBreacher", "Currency50", "Decoder",
    "DwellerPiece", "eFlashlightHighGrade", "Flamethrower", "FlashBeacon",
    "FlashBeaconHighGrade", "Flashlight", "Gravelight", "Gummylight", "HealthBoost",
    "Medkit", "Notebook", "PanicButton", "RemoteC4", "Scanner", "SmallLantern",
    "Splorglight", "SPRINT", "StunBaton", "ThePrototype", "ToolGun", "WindupLight",
    "InnerKeyCard", "NormalKeyCard", "PasswordPaper", "RidgeKeyCard",
    "RedeemerRevolver", "ShopBlacklight", "ShopBook", "ShopCodeBreacher", "ShopDefib",
    "ShopDwellerPiece", "ShopFlashBeacon", "ShopFlashlight", "ShopGravelight",
    "ShopGummylight", "ShopHealthBoost", "ShopLantern", "ShopMedkit", "ShopSPRINT",
    "ShopWindupLight", "BlueToyRemote", "CrateBlacklight", "CrateBook",
    "CrateCodeBreacher", "CrateDefib", "CrateFlashBeacon", "CrateFlashlight",
    "CrateGravelight", "CrateGummylight", "CrateHealthBoost", "CrateLantern",
    "CrateMedkit", "CrateWindupLight", "DoubleSprint", "BiggerStatue", "DiVine",
    "MeatWallDweller", "NoGood", "Rebarb", "RottenWallDweller", "Searchlights",
    "Statue", "Styx", "TheInvisibleMan", "Tripwire", "Turret", "WallDweller", "LeftPage"
})

local function addNumberedItems(prefix, numbers)
    for _, number in ipairs(numbers) do
        trackedItemNames[prefix .. number] = true
    end
end

local oneToSeven = { 1, 2, 3, 4, 5, 6, 7 }
local oneToEight = { 1, 2, 3, 4, 5, 6, 7, 8 }
local oneToTen = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local oneToTwelve = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local fifteenVariants = { 1, 2, 3, 4, 5, 6, 7, 9, 10 }

addNumberedItems("Currency5-", oneToSeven)
addNumberedItems("Currency10-", oneToEight)
addNumberedItems("Currency15-", fifteenVariants)
addNumberedItems("Currency25-", oneToTwelve)
addNumberedItems("Currency50-", oneToEight)
addNumberedItems("Currency100-", oneToTen)
addNumberedItems("Currency200-", oneToSeven)
addNumberedItems("UCurrency5-", oneToSeven)
addNumberedItems("UCurrency10-", oneToEight)
addNumberedItems("UCurrency15-", fifteenVariants)
addNumberedItems("UCurrency25-", oneToTwelve)
addNumberedItems("UCurrency50-", oneToEight)

local dangerItemNames = {
    DrawerLandmine = "Landmine",
    Landmine = "Landmine",
    RedeemerRevolver = "Revolver",
    BiggerStatue = "Bigger Statue",
    DiVine = "DiVine",
    MeatWallDweller = "Meat Wall Dweller",
    NoGood = "NoGood",
    Rebarb = "Rebarb",
    RottenWallDweller = "Rotten Wall Dweller",
    Searchlights = "Searchlights",
    Statue = "Statue",
    Styx = "Styx",
    TheInvisibleMan = "The Invisible Man",
    Tripwire = "Tripwire",
    Turret = "Turret",
    WallDweller = "Wall Dweller"
}

local batteryItemNames = {
    AltBattery1 = true,
    AltBattery2 = true,
    AltBattery3 = true,
    DefaultBattery1 = true,
    DefaultBattery2 = true,
    DefaultBattery3 = true,
    RoomsBattery = true,
    Neostyk1 = true,
    Neostyk2 = true,
    Neostyk3 = true
}

local function getCurrencyAmount(item)
    local amount = tonumber(item:GetAttribute("Amount"))
    if amount then
        return amount
    end

    return tonumber(item.Name:match("^U?Currency(%d+)%-"))
end

local function getItemVisual(item)
    local interactionType = item:GetAttribute("InteractionType")

    if dangerItemNames[item.Name] then
        return Color3.fromRGB(255, 0, 0), dangerItemNames[item.Name]
    elseif item.Name == "LeftPage" then
        return Color3.fromRGB(0, 255, 255), "Document"
    end

    local amount = getCurrencyAmount(item)
    if interactionType == "CurrencyBase" or amount then
        amount = amount or 0

        if amount < 25 then
            return Color3.fromRGB(0, 100, 0), "$" .. amount
        elseif amount < 50 then
            return Color3.fromRGB(255, 150, 0), "$" .. amount
        elseif amount < 500 then
            return Color3.fromRGB(255, 255, 100), "$" .. amount
        end

        return Color3.fromRGB(255, 0, 255), "$" .. amount
    end

    if item.Name == "PasswordPaper" or interactionType == "PasswordPaper" then
        return Color3.fromRGB(0, 150, 200), "Password"
    elseif item.Name == "InnerKeyCard" or interactionType == "InnerKeyCard" then
        return Color3.fromRGB(0, 150, 200), "Purple Keycard"
    elseif item.Name == "NormalKeyCard" or item.Name == "RidgeKeyCard" or interactionType == "KeyCard" then
        return Color3.fromRGB(0, 150, 200), "Keycard"
    elseif batteryItemNames[item.Name] or interactionType == "Battery" then
        return Color3.fromRGB(125, 100, 50), "Battery"
    elseif interactionType == "ItemBase" then
        return Color3.fromRGB(150, 255, 100), nil
    end

    return nil, nil
end

local function detectItem(item)
    if not (item:IsA("Model") or item:IsA("BasePart")) or not trackedItemNames[item.Name] then
        return
    end

    local function createItemESP()
        local existing = trackedItemESPs[item]
        if existing and existing.Parent then
            return true
        end

        local hasVisualPart = item:IsA("BasePart")
            or item.PrimaryPart
            or item:FindFirstChildWhichIsA("BasePart", true)

        if not hasVisualPart then
            return false
        end

        local color, label = getItemVisual(item)
        local billboard = createESP(item, color, label)

        if billboard then
            billboard:SetAttribute("ESPType", "Item")
            trackedItemESPs[item] = billboard
            return true
        end

        return false
    end

    if featureState.ItemESP and dangerItemNames[item.Name] and createItemESP() then
        return
    end

    task.spawn(function()
        for _ = 1, 20 do
            if not item.Parent or not featureState.ItemESP then
                return
            end

            if createItemESP() then
                return
            end

            task.wait(0.1)
        end
    end)
end

local function scanRoomItems(room)
    task.spawn(function()
        local queue = { room }
        local index = 1
        local processedCount = 0
        local regularItems = {}

        while index <= #queue and room.Parent do
            local parent = queue[index]
            index = index + 1

            for _, child in ipairs(parent:GetChildren()) do
                if (child:IsA("Model") or child:IsA("BasePart")) and trackedItemNames[child.Name] then
                    if dangerItemNames[child.Name] then
                        detectItem(child)
                    else
                        table.insert(regularItems, child)
                    end
                end

                table.insert(queue, child)
                processedCount = processedCount + 1

                if processedCount % 100 == 0 then
                    task.wait()
                end
            end
        end

        for itemIndex, item in ipairs(regularItems) do
            if not room.Parent then
                return
            end

            detectItem(item)

            if itemIndex % 50 == 0 then
                task.wait()
            end
        end
    end)
end

local function handleRoom(room)
    if itemRoomConnections[room] then
        return
    end

    scanRoomItems(room)

    itemRoomConnections[room] = room.DescendantAdded:Connect(function(descendant)
        detectItem(descendant)
    end)
end

local function unhandleRoom(room)
    local connection = itemRoomConnections[room]
    itemRoomConnections[room] = nil

    if connection then
        connection:Disconnect()
    end
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

roomsFolder.ChildRemoved:Connect(unhandleRoom)

monstersFolder = gameplayFolder:FindFirstChild("Monsters") or monstersFolder
if monstersFolder then
    task.spawn(function()
        handleRoom(monstersFolder)
    end)
end

gameplayFolder.ChildAdded:Connect(function(child)
    if child.Name == "Monsters" then
        monstersFolder = child
        task.spawn(function()
            handleRoom(child)
        end)
    end
end)

gameplayFolder.ChildRemoved:Connect(function(child)
    if child == monstersFolder or child.Name == "Monsters" then
        unhandleRoom(child)
        if child == monstersFolder then
            monstersFolder = nil
        end
    end
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

local workspaceTargetsByName = {}
local removableWorkspaceTargets = {}
for _, target in ipairs(workspaceTargetList) do
    local normalizedName = normalizeName(target.Name)
    workspaceTargetsByName[normalizedName] = target

    if target.remove then
        removableWorkspaceTargets[normalizedName] = true
    end
end

local function findTarget(target, childName, callback)
    task.spawn(function()
        local found = childName and target:WaitForChild(childName, 1) or target
        if found and (found:IsA("BasePart") or found:IsA("Model")) then
            callback(found)
        end
    end)
end

local function processWorkspaceTarget(child)
    if not (child:IsA("BasePart") or child:IsA("Model")) then
        return
    end

    local normalizedName = normalizeName(child.Name)
    local target = workspaceTargetsByName[normalizedName]

    if not target and string.find(normalizedName, "walldweller", 1, true) then
        target = {
            Color = Color3.fromRGB(255, 0, 0),
            Label = splitCamelCase(child.Name)
        }
    end

    if not target then
        return
    end

    task.spawn(function()
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
    end)
end

workspace.ChildAdded:Connect(processWorkspaceTarget)

task.spawn(function()
    local processedCount = 0

    for _, object in ipairs(workspace:GetDescendants()) do
        if object.Parent
            and (object:IsA("BasePart") or object:IsA("Model"))
            and removableWorkspaceTargets[normalizeName(object.Name)]
        then
            object:Destroy()
        end

        processedCount += 1
        if processedCount % 200 == 0 then
            task.wait()
        end
    end
end)

local monsterTargetFolderConnection = nil

local function hookMonsterTargetFolder(folder)
    if monsterTargetFolderConnection then
        monsterTargetFolderConnection:Disconnect()
        monsterTargetFolderConnection = nil
    end

    if folder then
        monsterTargetFolderConnection = folder.DescendantAdded:Connect(processWorkspaceTarget)
    end
end

hookMonsterTargetFolder(monstersFolder)

gameplayFolder.ChildAdded:Connect(function(child)
    if child.Name == "Monsters" then
        hookMonsterTargetFolder(child)
    end
end)

gameplayFolder.ChildRemoved:Connect(function(child)
    if child.Name == "Monsters" then
        hookMonsterTargetFolder(nil)
    end
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
    for _, room in ipairs(roomsFolder:GetChildren()) do
        scanRoomItems(room)
    end

    if monstersFolder and monstersFolder.Parent then
        scanRoomItems(monstersFolder)
    end
end

local lopeeConnections = {}
local lopeeLoopId = 0

local function isLopeeObject(object)
    return object.Name == "Lopee"
        or object.Name == "LopeeGlitch"
        or object.Name == "LopeePart"
end

local function removeLopeeObject(object)
    if featureState.RemoveLopee and object and object.Parent and isLopeeObject(object) then
        object:Destroy()
    end
end

local function stopRemoveLopee()
    lopeeLoopId += 1

    for index = #lopeeConnections, 1, -1 do
        lopeeConnections[index]:Disconnect()
        lopeeConnections[index] = nil
    end
end

local function startRemoveLopee()
    stopRemoveLopee()
    runService:UnbindFromRenderStep("Lopee")

    task.spawn(function()
        local processedCount = 0
        for _, object in ipairs(workspace:GetDescendants()) do
            removeLopeeObject(object)
            processedCount += 1

            if processedCount % 200 == 0 then
                task.wait()
            end
        end
    end)

    for _, object in ipairs(playerGui:GetChildren()) do
        if object.Name == "Pixel" then
            object:Destroy()
        end
    end

    lopeeConnections[#lopeeConnections + 1] = workspace.DescendantAdded:Connect(removeLopeeObject)
    lopeeConnections[#lopeeConnections + 1] = playerGui.ChildAdded:Connect(function(object)
        if featureState.RemoveLopee and object.Name == "Pixel" then
            object:Destroy()
        end
    end)

    lopeeLoopId += 1
    local loopId = lopeeLoopId
    task.spawn(function()
        while featureState.RemoveLopee and lopeeLoopId == loopId do
            runService:UnbindFromRenderStep("Lopee")
            task.wait(0.25)
        end
    end)
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
    elseif name == "RemoveLopee" then
        if enabled then
            startRemoveLopee()
        else
            stopRemoveLopee()
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
local autoDoorLabel

local doorTracker = {
    running = false,
    passwordEnabled = false,
    autoEnterCodeEnabled = false,
    autoDoorEnabled = false,
    autoDoorLoopId = 0,
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

local DOOR_AUTO_RETRY_DELAY = 1.5
local DOOR_TELEPORT_DISTANCE = 8
local DOOR_TELEPORT_HEIGHT_OFFSET = 4
local DOOR_WALK_SPEED = 24
local DOOR_WALK_DURATION = 1.25

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

local function doorGetPart(instance)
    if not instance then
        return nil
    end

    if instance:IsA("BasePart") then
        return instance
    end

    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
    end

    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function doorGetCharacter()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
    return character, root, humanoid
end

local function doorSetAutoStatus(text)
    if autoDoorLabel then
        autoDoorLabel.Text = "Auto Door: " .. tostring(text)
    end
end

local function doorWalkThrough(character, root, humanoid, doorPart)
    if not character or not root or not humanoid or not doorPart then
        return
    end

    local startOffset = Vector3.new(doorPart.Position.X - root.Position.X, 0, doorPart.Position.Z - root.Position.Z)
    if startOffset.Magnitude <= 0 then
        return
    end

    local walkDirection = startOffset.Unit
    local flatDoorPosition = Vector3.new(doorPart.Position.X, root.Position.Y, doorPart.Position.Z)
    local walkTarget = flatDoorPosition + walkDirection * DOOR_TELEPORT_DISTANCE
    local oldWalkSpeed = humanoid.WalkSpeed
    local oldAutoRotate = humanoid.AutoRotate

    humanoid.WalkSpeed = DOOR_WALK_SPEED
    humanoid.AutoRotate = false

    local startTime = os.clock()
    while doorTracker.autoDoorEnabled and os.clock() - startTime < DOOR_WALK_DURATION do
        if not character.Parent or not root.Parent or not humanoid.Parent or not doorPart.Parent then
            break
        end

        local remaining = walkTarget - root.Position
        if remaining.Magnitude <= 1 then
            break
        end

        local flatRemaining = Vector3.new(remaining.X, 0, remaining.Z)
        if flatRemaining.Magnitude <= 0 then
            break
        end

        local currentDirection = flatRemaining.Unit
        root.CFrame = CFrame.lookAt(root.Position, root.Position + currentDirection)
        root.AssemblyLinearVelocity = currentDirection * DOOR_WALK_SPEED
        root.AssemblyAngularVelocity = Vector3.zero
        humanoid:Move(currentDirection, false)

        local deltaTime = runService.Heartbeat:Wait()
        root.CFrame = root.CFrame + currentDirection * DOOR_WALK_SPEED * deltaTime
    end

    if humanoid.Parent then
        humanoid:Move(Vector3.zero, false)
        humanoid.WalkSpeed = oldWalkSpeed
        humanoid.AutoRotate = oldAutoRotate
    end

    if root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function doorTeleportAndWalk(door)
    local doorPart = doorGetPart(door)
    if not doorPart then
        return false
    end

    local character, root, humanoid = doorGetCharacter()
    if not character or not root or not humanoid then
        return false
    end

    local lookDirection = Vector3.new(doorPart.CFrame.RightVector.X, 0, doorPart.CFrame.RightVector.Z)
    if lookDirection.Magnitude <= 0 then
        lookDirection = Vector3.zAxis
    end

    local doorBase = doorPart.Position - doorPart.CFrame.UpVector * (doorPart.Size.Y / 2)
    local teleportPosition = doorBase
        + Vector3.yAxis * DOOR_TELEPORT_HEIGHT_OFFSET
        - lookDirection.Unit * DOOR_TELEPORT_DISTANCE
    local lookTarget = Vector3.new(doorPart.Position.X, teleportPosition.Y, doorPart.Position.Z)
    local targetCFrame = CFrame.lookAt(teleportPosition, lookTarget)

    character:PivotTo(targetCFrame)
    root.CFrame = targetCFrame
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    doorWalkThrough(character, root, humanoid, doorPart)
    return true
end

local function doorEnterCode(door)
    local code = doorGetCodeText()
    if code == "No Code" then
        return false
    end

    local remote = doorGetRemote(door)
    if not remote then
        return false
    end

    pcall(function()
        local current = ""
        for i = 1, #code do
            current = current .. string.sub(code, i, i)
            remote:InvokeServer(current)
            task.wait(0.05)
        end
    end)

    return true
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

local doorStopAutoDoor

local function doorStopTracker()
    if doorTracker.autoDoorEnabled then
        doorStopAutoDoor()
    end

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

doorStopAutoDoor = function()
    doorTracker.autoDoorEnabled = false
    doorTracker.autoDoorLoopId += 1
    doorSetAutoStatus("Off")
end

local function doorStartAutoDoor()
    if doorTracker.autoDoorEnabled then
        return
    end

    doorTracker.autoDoorEnabled = true
    doorTracker.autoDoorLoopId += 1
    local loopId = doorTracker.autoDoorLoopId

    doorTracker.passwordEnabled = true
    doorStartTracker()
    doorSetAutoStatus("Starting")

    task.spawn(function()
        while doorTracker.autoDoorEnabled and doorTracker.autoDoorLoopId == loopId do
            doorUpdateTrackedLastDoor()

            local door = doorTracker.currentLastDoor
            if not door then
                doorSetAutoStatus("Waiting for door")
                task.wait(DOOR_AUTO_RETRY_DELAY)
                continue
            end

            local codeEntered = false
            if door:GetAttribute("Locked") then
                doorSetAutoStatus("Entering code")
                codeEntered = doorEnterCode(door)
            end

            doorSetAutoStatus(codeEntered and "Opening code door" or "Entering latest door")
            if not doorTeleportAndWalk(door) then
                doorSetAutoStatus("Waiting for door part")
            end

            task.wait(DOOR_AUTO_RETRY_DELAY)
        end
    end)
end

local generatorAutoState = {
    enabled = false,
    hookedGenerators = {},
    roomConnections = {},
    activeLoops = {},
    warningGuis = {},
    mainConnections = {},
    pendingGenerators = setmetatable({}, { __mode = "k" }),
    scanId = 0
}

local GENERATOR_SUCCESS_INTERVAL = 0.31

local function generatorHideWarning(generator)
    local gui = generatorAutoState.warningGuis[generator]
    generatorAutoState.warningGuis[generator] = nil

    if gui and gui.Parent then
        gui:Destroy()
    end
end

local function generatorShowWarning(generator)
    generatorHideWarning(generator)

    local gui = Instance.new("ScreenGui")
    gui.Name = "GeneratorWarningGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 120)
    label.Position = UDim2.new(0, 0, 0.3, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = "DONT CLICK, BANNABLE"
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextTransparency = 1
    label.Parent = gui

    generatorAutoState.warningGuis[generator] = gui

    tweenService:Create(label, TweenInfo.new(0.25), {
        TextTransparency = 0,
        TextStrokeTransparency = 0.5
    }):Play()
end

local function generatorDisconnectList(connections)
    for i = #connections, 1, -1 do
        local connection = connections[i]
        if connection then
            connection:Disconnect()
        end

        connections[i] = nil
    end
end

local function generatorGetParts(generator)
    if not generator then
        return nil
    end

    local remoteEvent = generator:FindFirstChild("RemoteEvent")
    local remoteFunction = generator:FindFirstChild("RemoteFunction")
    local fixed = generator:FindFirstChild("Fixed")
    local proxyPart = generator:FindFirstChild("ProxyPart")
    local prompt = proxyPart and proxyPart:FindFirstChildWhichIsA("ProximityPrompt")

    if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
        return nil
    end

    if not remoteFunction or not remoteFunction:IsA("RemoteFunction") then
        return nil
    end

    if not fixed then
        return nil
    end

    if not prompt then
        return nil
    end

    return remoteEvent, prompt
end

local function generatorStopLoop(generator)
    generatorAutoState.activeLoops[generator] = nil
    generatorHideWarning(generator)
end

local function generatorHideESP(generator)
    local record = generatorAutoState.hookedGenerators[generator]
    local billboard = record and record.esp or nil

    if record then
        record.esp = nil
    end

    if billboard and billboard.Parent then
        billboard:Destroy()
    end
end

local function generatorUpdateESP(generator, prompt)
    local record = generatorAutoState.hookedGenerators[generator]
    if not record then
        return
    end

    if not prompt.Enabled then
        generatorHideESP(generator)
        return
    end

    if record.esp and record.esp.Parent then
        return
    end

    local proxyPart = prompt.Parent
    local billboard = createESP(proxyPart, Color3.fromRGB(255, 245, 180), "Generator")
    if billboard then
        billboard:SetAttribute("ESPType", "Generator")
        record.esp = billboard
    end
end

local function generatorStartLoop(generator, prompt)
    if generatorAutoState.activeLoops[generator] then
        return
    end

    local remoteEvent = generator:FindFirstChild("RemoteEvent")
    if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
        return
    end

    local token = {}
    generatorAutoState.activeLoops[generator] = token
    generatorShowWarning(generator)

    task.spawn(function()
        task.wait(0.1)

        while generatorAutoState.enabled
            and generatorAutoState.activeLoops[generator] == token
            and prompt.Parent
            and prompt.Enabled == false
        do
            pcall(function()
                remoteEvent:FireServer(true)
            end)
            task.wait(GENERATOR_SUCCESS_INTERVAL)
        end

        if generatorAutoState.activeLoops[generator] == token then
            generatorAutoState.activeLoops[generator] = nil
            generatorHideWarning(generator)
        end
    end)
end

local function generatorUpdatePrompt(generator, prompt)
    generatorUpdateESP(generator, prompt)

    if prompt.Enabled == false then
        generatorStartLoop(generator, prompt)
    else
        generatorStopLoop(generator)
    end
end

local function generatorUnhook(generator)
    local record = generatorAutoState.hookedGenerators[generator]

    if record then
        generatorHideESP(generator)
        generatorDisconnectList(record.connections)
    end

    generatorAutoState.hookedGenerators[generator] = nil
    generatorStopLoop(generator)
end

local function generatorHookGenerator(generator)
    if not generatorAutoState.enabled or generatorAutoState.hookedGenerators[generator] then
        return
    end

    local remoteEvent, prompt = generatorGetParts(generator)
    if not remoteEvent then
        return
    end

    local record = {
        prompt = prompt,
        esp = nil,
        connections = {}
    }
    generatorAutoState.hookedGenerators[generator] = record

    record.connections[#record.connections + 1] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        generatorUpdatePrompt(generator, prompt)
    end)

    record.connections[#record.connections + 1] = remoteEvent.OnClientEvent:Connect(function()
        generatorHideESP(generator)
        generatorStopLoop(generator)
    end)

    record.connections[#record.connections + 1] = prompt.Destroying:Connect(function()
        generatorUnhook(generator)
    end)

    record.connections[#record.connections + 1] = generator.Destroying:Connect(function()
        generatorUnhook(generator)
    end)

    generatorUpdatePrompt(generator, prompt)
end

local function generatorDetect(descendant)
    if not generatorAutoState.enabled then
        return
    end

    local generator = nil

    if descendant.Name == "Generator" then
        generator = descendant
    elseif descendant.Name == "ProxyPart" then
        generator = descendant.Parent
    elseif descendant:IsA("ProximityPrompt") and descendant.Parent and descendant.Parent.Name == "ProxyPart" then
        generator = descendant.Parent.Parent
    elseif descendant.Name == "RemoteEvent"
        or descendant.Name == "RemoteFunction"
        or descendant.Name == "Fixed"
    then
        generator = descendant.Parent
    end

    if not generator
        or generatorAutoState.hookedGenerators[generator]
        or generatorAutoState.pendingGenerators[generator]
    then
        return
    end

    generatorAutoState.pendingGenerators[generator] = true

    task.spawn(function()
        for _ = 1, 20 do
            if not generatorAutoState.enabled or not generator.Parent then
                generatorAutoState.pendingGenerators[generator] = nil
                return
            end

            generatorHookGenerator(generator)
            if generatorAutoState.hookedGenerators[generator] then
                generatorAutoState.pendingGenerators[generator] = nil
                return
            end

            task.wait(0.1)
        end

        generatorAutoState.pendingGenerators[generator] = nil
    end)
end

local function generatorUnwatchRoom(room)
    local connection = generatorAutoState.roomConnections[room]
    generatorAutoState.roomConnections[room] = nil

    if connection then
        connection:Disconnect()
    end

    for generator in pairs(generatorAutoState.hookedGenerators) do
        if generator:IsDescendantOf(room) then
            generatorUnhook(generator)
        end
    end
end

local function generatorWatchRoom(room)
    if not generatorAutoState.enabled or generatorAutoState.roomConnections[room] then
        return
    end

    generatorAutoState.roomConnections[room] = room.DescendantAdded:Connect(generatorDetect)

    local scanId = generatorAutoState.scanId
    task.spawn(function()
        local queue = { room }
        local index = 1
        local processedCount = 0

        while generatorAutoState.enabled
            and generatorAutoState.scanId == scanId
            and index <= #queue
            and room.Parent
        do
            local parent = queue[index]
            index = index + 1

            for _, child in ipairs(parent:GetChildren()) do
                generatorDetect(child)
                table.insert(queue, child)
                processedCount = processedCount + 1

                if processedCount % 100 == 0 then
                    task.wait()
                end
            end
        end
    end)
end

local function generatorStopAllLoops()
    local generators = {}
    for generator in pairs(generatorAutoState.activeLoops) do
        table.insert(generators, generator)
    end

    for _, generator in ipairs(generators) do
        generatorStopLoop(generator)
    end
end

local function generatorStartAuto()
    if generatorAutoState.enabled then
        return
    end

    generatorAutoState.enabled = true
    generatorAutoState.scanId += 1

    for _, room in ipairs(roomsFolder:GetChildren()) do
        generatorWatchRoom(room)
    end

    generatorAutoState.mainConnections[#generatorAutoState.mainConnections + 1] = roomsFolder.ChildAdded:Connect(function(room)
        generatorWatchRoom(room)
    end)

    generatorAutoState.mainConnections[#generatorAutoState.mainConnections + 1] = roomsFolder.ChildRemoved:Connect(function(room)
        generatorUnwatchRoom(room)
    end)

    generatorAutoState.mainConnections[#generatorAutoState.mainConnections + 1] = player.CharacterRemoving:Connect(function()
        generatorStopAllLoops()
    end)
end

local function generatorStopAuto()
    generatorAutoState.enabled = false
    generatorAutoState.scanId += 1
    generatorDisconnectList(generatorAutoState.mainConnections)

    local rooms = {}
    for room in pairs(generatorAutoState.roomConnections) do
        table.insert(rooms, room)
    end
    for _, room in ipairs(rooms) do
        generatorUnwatchRoom(room)
    end

    local generators = {}
    for generator in pairs(generatorAutoState.hookedGenerators) do
        table.insert(generators, generator)
    end
    for _, generator in ipairs(generators) do
        generatorUnhook(generator)
    end

    generatorStopAllLoops()
    table.clear(generatorAutoState.pendingGenerators)
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
autoDoorLabel = CreateValueLabel("Doors", "Auto Door: Off")
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
CreateToggle("Doors", "Auto Latest Door", function(state)
    if state.Value then
        doorStartAutoDoor()
    else
        doorStopAutoDoor()
    end
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

CreateToggle("World", "Remove Lopee", function(state)
    setFeature("RemoveLopee", state.Value)
end, false)

CreateToggle("World", "Auto Crouch Event", function(state)
    setFeature("AutoCrouchEvent", state.Value)
end, false)

CreateToggle("World", "Auto Generator", function(state)
    if state.Value then
        generatorStartAuto()
    else
        generatorStopAuto()
    end
end, false)

CreateToggle("World", "Remove Fog", function(state)
    setFeature("RemoveAtmosphere", state.Value)
end, false)

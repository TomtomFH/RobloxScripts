-- PRESSURE (https://www.roblox.com/games/12411473842/)
-- PART: Lobby

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Load UI library
loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local function notify(message)
    pcall(function()
        print("[Pressure Lobby] " .. tostring(message))
    end)
end

local teleRoot = Workspace:FindFirstChild("TeleportersV2") or Workspace:WaitForChild("TeleportersV2", 15)
local eventsFolder = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events", 10)
local exitEvent = eventsFolder and (eventsFolder:FindFirstChild("ExitMatch") or eventsFolder:WaitForChild("ExitMatch", 10))

local uiConnections = {}
local teleporterConnections = {}
local enabled = false

local selectedPlayerName = ""
if type(GetConfigValue) == "function" then
    local savedName = GetConfigValue("Teleporter", "Target Player")
    if type(savedName) == "string" then
        selectedPlayerName = savedName
    end
end

local function connectSet(set, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(set, connection)
    return connection
end

local function cleanup(set)
    for _, connection in ipairs(set) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(set)
end

local function getSelectedPlayer()
    local query = tostring(selectedPlayerName or "")
    if query == "" then
        return nil
    end

    local lowerQuery = query:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == lowerQuery or player.DisplayName:lower() == lowerQuery then
            return player
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(lowerQuery, 1, true) or player.DisplayName:lower():find(lowerQuery, 1, true) then
            return player
        end
    end

    return nil
end

local function tryEnterTeleporter(teleporter)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local mainPart = teleporter and teleporter:FindFirstChild("Main")
    if hrp and mainPart and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, mainPart, 1)
            firetouchinterest(hrp, mainPart, 0)
        end)
    end
end

local function bindTeleporter(teleporter)
    local main = teleporter:FindFirstChild("Main") or teleporter:WaitForChild("Main", 5)
    local billboardGui = main and (main:FindFirstChild("BillboardGui") or main:WaitForChild("BillboardGui", 5))
    local frame = billboardGui and (billboardGui:FindFirstChild("Hosted") or billboardGui:WaitForChild("Hosted", 5))
    local slots = frame and (frame:FindFirstChild("Frame") or frame:WaitForChild("Frame", 5))
    if not slots then
        return
    end

    connectSet(teleporterConnections, slots.ChildAdded, function(child)
        if not enabled then
            return
        end

        local targetPlayer = getSelectedPlayer()
        if targetPlayer and child.Name == targetPlayer.Name then
            tryEnterTeleporter(teleporter)
        end
    end)

    connectSet(teleporterConnections, slots.ChildRemoved, function(child)
        if not enabled then
            return
        end

        local targetPlayer = getSelectedPlayer()
        if targetPlayer and child.Name == targetPlayer.Name and exitEvent then
            pcall(function()
                exitEvent:FireServer()
            end)
        end
    end)
end

local function bindTeleporters()
    cleanup(teleporterConnections)

    if not teleRoot then
        notify("Teleporters folder not found")
        return
    end

    for _, teleporter in ipairs(teleRoot:GetChildren()) do
        bindTeleporter(teleporter)
    end

    connectSet(teleporterConnections, teleRoot.ChildAdded, function(child)
        bindTeleporter(child)
    end)
end

local function setEnabled(state)
    enabled = state
    if enabled then
        bindTeleporters()
        notify("Auto follow enabled")
    else
        cleanup(teleporterConnections)
        notify("Auto follow disabled")
    end
end

connectSet(uiConnections, Players.PlayerRemoving, function(player)
    local target = getSelectedPlayer()
    if target and player == target then
        notify("Target player left: " .. player.Name)
    end
end)

-- Lib UI
CreateMenu("Pressure Lobby")
CreateGroup("Pressure Lobby", "Main")
CreateTab("Pressure Lobby", "Main", "Teleporter")

CreateLabel("Teleporter", "Track one player and auto join/leave their teleporter")

CreateInput("Teleporter", "Target Player", selectedPlayerName, "Set", function(textBox)
    selectedPlayerName = tostring(textBox.Text or "")

    local target = getSelectedPlayer()
    if target then
        notify("Target set to " .. target.DisplayName .. " (@" .. target.Name .. ")")
    elseif selectedPlayerName ~= "" then
        notify("Target saved (not currently found): " .. selectedPlayerName)
    else
        notify("Target cleared")
    end
end)

CreateToggle("Teleporter", "Auto Follow Target", function(state)
    setEnabled(state.Value)
end, false)

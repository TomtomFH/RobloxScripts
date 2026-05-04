local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local boxesEnabled = false
local boxStyle = "2D"
local boxGui = nil
local boxConnection = nil
local boxFrames2D = {}
local boxAdornments3D = {}

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
    stroke.Color = Color3.fromRGB(0, 170, 255)
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

    local box = Instance.new("BoxHandleAdornment")
    box.Name = player.Name .. "_3DBox"
    box.AlwaysOnTop = true
    box.Color3 = Color3.fromRGB(0, 170, 255)
    box.Transparency = 0.65
    box.ZIndex = 10
    box.Parent = getOrCreateBoxGui()

    boxAdornments3D[player] = box
    return box
end

local function remove3DBox(player)
    local box = boxAdornments3D[player]
    if box then
        box:Destroy()
        boxAdornments3D[player] = nil
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

local function update2DBox(player)
    local frame = create2DBox(player)
    local corners = getCharacterCorners(player.Character)

    if not corners then
        frame.Visible = false
        return
    end

    camera = workspace.CurrentCamera
    if not camera then
        frame.Visible = false
        return
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
        frame.Visible = false
        return
    end

    frame.Position = UDim2.fromOffset(minX, minY)
    frame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
    frame.Visible = true
end

local function update3DBox(player)
    local box = create3DBox(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local boxCFrame, boxSize = getCharacterBounds(character)

    if not root or not boxCFrame or not boxSize then
        box.Visible = false
        return
    end

    box.Adornee = root
    box.CFrame = root.CFrame:ToObjectSpace(boxCFrame)
    box.Size = boxSize
    box.Visible = true
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

Players.PlayerRemoving:Connect(function(player)
    remove2DBox(player)
    remove3DBox(player)
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

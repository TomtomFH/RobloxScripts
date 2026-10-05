-- Elemental Dungeons dungeon place. Only mobs currently streamed to the client can be shown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local normalColor = Color3.fromRGB(235, 240, 255)
local closestColor = Color3.fromRGB(255, 190, 45)
local espEnabled = false
local espConnection = nil
local espGui = nil
local overlays = {}
local teleportEnabled = false
local teleportGeneration = 0
local potionPickupEnabled = false
local potionPickupGeneration = 0
local potionNextAttempt = setmetatable({}, {__mode = "k"})
local pendingPotionCount = nil
local pendingPotionTime = 0
local chestPickupEnabled = false
local chestPickupGeneration = 0
local chestPromptShownConnection = nil
local chestNextAttempt = setmetatable({}, {__mode = "k"})
local activeChestPrompt = nil
local chestInteractionBusy = false
local elementReplicaConnection = nil
local elementReplicaRawConnection = nil
local elementReplica = nil
local elementReplicaController = nil
local elementEquipBusy = false
local elementUiScanRunning = false
local elementUiScanGeneration = 0
local elementListFrame = nil
local elementSearchBox = nil
local elementStatusLabel = nil
local ownedElements = {}
local infiniteCloudDungeon = workspace:FindFirstChild("Map")
infiniteCloudDungeon = infiniteCloudDungeon and infiniteCloudDungeon:FindFirstChild("InfiniteCloudDungeon")
local asInfEnabled = false
local asInfConnection = nil
local asInfNoclipConnection = nil
local asInfBodyPosition = nil
local asInfRoot = nil
local asInfDodgeTarget = nil
local asInfDesiredPosition = Vector3.new(-5570, 360, 815)
local asInfLastDecision = 0
local asInfNoclipParts = setmetatable({}, {__mode = "k"})
local asInfHazardMotion = setmetatable({}, {__mode = "k"})
local galacticDestructionEnabled = false
local galacticDestructionGeneration = 0
local galacticDestructionTarget = nil
local galacticDestructionKeyHeld = false
local galacticCameraBound = false
local galacticCameraVisibleCFrame = nil
local galacticCameraVisibleFocus = nil
local galacticCameraPostSimulationConnection = nil
local galacticCameraRestoreBindName = "ElementalGalacticCameraRestore"
local galacticCameraCaptureBindName = "ElementalGalacticCameraCapture"
local autoTargetAbilitiesEnabled = false
local autoTargetAbilitiesGeneration = 0
local autoTargetAbilityTarget = nil
local autoTargetAbilityProfile = nil
local autoTargetAbilityCursor = 0
local autoTargetAbilityCooldowns = {}
local autoTargetAbilityNextAttempts = {}
local autoTargetAbilityAwaitingCooldown = {}
local autoTargetAbilityController = nil
local autoTargetAbilityControllerTool = nil
local autoTargetAbilityControllerLastSearch = 0
local autoTargetAbilityInput = nil
local autoTargetCameraBound = false
local autoTargetCameraVisibleCFrame = nil
local autoTargetCameraVisibleFocus = nil
local autoTargetCameraPostSimulationConnection = nil
local autoTargetCameraRestoreBindName = "ElementalAbilityCameraRestore"
local autoTargetCameraCaptureBindName = "ElementalAbilityCameraCapture"
local antiFreezeEnabled = false
local antiFreezeConnection = nil
local teleportDistance = 250
local teleportDistanceLabel = "Teleport Distance (studs)"
local teleportToggleLabel = "Teleport to Distant Mob"
local asInfHomePosition = Vector3.new(-5570, 360, 815)
local asInfHeight = asInfHomePosition.Y
local asInfTriggerClearance = 18
local asInfSafeClearance = 12
local asInfRootMargin = 4
local componentEnabled = {
    Box = true,
    Outline = true,
    Tracer = true,
    TracerClosestOnly = false,
    Name = true,
    HealthBar = true,
    Distance = true,
}
local bodyPartNames = {
    Head = true,
    Torso = true,
    UpperTorso = true,
    LowerTorso = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}

local environment = type(getgenv) == "function" and getgenv() or _G
if type(environment.__ElementalDungeonsMobEspStop) == "function" then
    pcall(environment.__ElementalDungeonsMobEspStop)
end
elementReplica = environment.__ElementalDungeonsPlayerReplica
elementReplicaController = environment.__ElementalDungeonsReplicaController

-- Subscribe before loading the UI library so an early execution can capture
-- PlayerData when the game's own controller requests it. Never request the
-- one-shot data stream here, because doing so can starve the real controller.
pcall(function()
    elementReplicaController = elementReplicaController
        or require(game:GetService("ReplicatedStorage").ReplicatedStorage.ClientModules
            .ReplicaService.ReplicaController)
    environment.__ElementalDungeonsReplicaController = elementReplicaController
    for _, replica in pairs(elementReplicaController._replicas or {}) do
        if replica.Class == "PlayerData" then
            elementReplica = replica
            environment.__ElementalDungeonsPlayerReplica = replica
            break
        end
    end
    if not elementReplica then
        elementReplicaConnection = elementReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
            elementReplica = replica
            environment.__ElementalDungeonsPlayerReplica = replica
            local refresh = environment.__ElementalDungeonsApplyPlayerData
            if type(refresh) == "function" then
                task.defer(refresh, replica)
            end
        end)
    end
end)

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local function parseTeleportDistance(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    local distance = tonumber(value)
    if distance and distance > 50 and distance < math.huge then
        return distance
    end
    return nil
end

local savedTeleportDistance = GetConfigValue("Misc", teleportDistanceLabel)
if savedTeleportDistance ~= nil then
    teleportDistance = parseTeleportDistance(savedTeleportDistance) or teleportDistance
    SetConfigValue("Misc", teleportDistanceLabel, tostring(teleportDistance))
end

if GetConfigValue("Misc", teleportToggleLabel) == nil then
    local previousToggle = GetConfigValue("Misc", "Teleport to Distant Mob (>500 studs)")
    if type(previousToggle) == "boolean" then
        SetConfigValue("Misc", teleportToggleLabel, previousToggle)
    end
end

-- The UI library does not call toggle callbacks for a saved false value.
for component, label in pairs({
    Box = "Box",
    Outline = "Outline",
    Tracer = "Tracer",
    TracerClosestOnly = "Tracer: Closest Only",
    Name = "Name and Level",
    HealthBar = "Health Bar",
    Distance = "Distance",
}) do
    local saved = GetConfigValue("Mob ESP", label)
    if type(saved) == "boolean" then
        componentEnabled[component] = saved
    end
end

local function resolveGuiParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end

    local ok, parent = pcall(function()
        return CoreGui
    end)
    if ok and parent then
        return parent
    end

    return localPlayer:WaitForChild("PlayerGui")
end

local function getOrCreateGui()
    if espGui and espGui.Parent then
        return espGui
    end

    local parent = resolveGuiParent()
    local previous = parent:FindFirstChild("TomtomFHElementalMobESP")
    if previous then
        previous:Destroy()
    end

    espGui = Instance.new("ScreenGui")
    espGui.Name = "TomtomFHElementalMobESP"
    espGui.IgnoreGuiInset = true
    espGui.ResetOnSpawn = false
    espGui.DisplayOrder = 999998
    espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    espGui.Parent = parent
    return espGui
end

local function createLabel(name, zIndex)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = UDim2.fromOffset(240, 18)
    label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    label.TextSize = 14
    label.TextColor3 = normalColor
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.15
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = zIndex
    label.Visible = false
    label.Parent = getOrCreateGui()
    return label
end

local function createOverlay(model)
    local parent = getOrCreateGui()

    local box = Instance.new("Frame")
    box.Name = "MobBox"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.ZIndex = 10
    box.Visible = false
    box.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Color = normalColor
    stroke.Thickness = 2
    stroke.Parent = box

    local healthBar = Instance.new("Frame")
    healthBar.Name = "MobHealthBar"
    healthBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    healthBar.BorderSizePixel = 0
    healthBar.ZIndex = 11
    healthBar.Visible = false
    healthBar.Parent = parent

    local healthStroke = Instance.new("UIStroke")
    healthStroke.Color = Color3.new(0, 0, 0)
    healthStroke.Thickness = 1
    healthStroke.Parent = healthBar

    local healthFill = Instance.new("Frame")
    healthFill.Name = "Fill"
    healthFill.BackgroundColor3 = Color3.fromRGB(40, 220, 80)
    healthFill.BorderSizePixel = 0
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.ZIndex = 12
    healthFill.Parent = healthBar

    local tracer = Instance.new("Frame")
    tracer.Name = "MobTracer"
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.BackgroundColor3 = normalColor
    tracer.BorderSizePixel = 0
    tracer.ZIndex = 8
    tracer.Visible = false
    tracer.Parent = parent

    local previousHighlight = model:FindFirstChild("TomtomFHElementalMobOutline")
    if previousHighlight then
        previousHighlight:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "TomtomFHElementalMobOutline"
    highlight.Adornee = model
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = normalColor
    highlight.Enabled = false
    highlight.Parent = model

    local overlay = {
        Box = box,
        Stroke = stroke,
        HealthBar = healthBar,
        HealthFill = healthFill,
        Name = createLabel("MobName", 13),
        Distance = createLabel("MobDistance", 13),
        Tracer = tracer,
        Highlight = highlight,
    }
    overlays[model] = overlay
    return overlay
end

local function hideScreenOverlay(overlay)
    overlay.Box.Visible = false
    overlay.HealthBar.Visible = false
    overlay.Name.Visible = false
    overlay.Distance.Visible = false
    overlay.Tracer.Visible = false
end

local function hideOverlay(overlay)
    hideScreenOverlay(overlay)
    overlay.Highlight.Enabled = false
end

local function removeOverlay(model)
    local overlay = overlays[model]
    if not overlay then
        return
    end

    for _, instance in pairs(overlay) do
        instance:Destroy()
    end
    overlays[model] = nil
end

local function getScreenBounds(camera, model, root)
    local rootPoint = camera:WorldToViewportPoint(root.Position)
    if rootPoint.Z <= 0 then
        return nil
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local pointsInFront = 0
    for _, part in ipairs(model:GetChildren()) do
        -- Only the rig's direct body parts count; accessories, effects, and HitPart do not.
        if part:IsA("BasePart") and bodyPartNames[part.Name] then
            local partCFrame, partSize = part.CFrame, part.Size
            for x = -1, 1, 2 do
                for y = -1, 1, 2 do
                    for z = -1, 1, 2 do
                        local corner = partCFrame.Position
                            + partCFrame.RightVector * partSize.X * 0.5 * x
                            + partCFrame.UpVector * partSize.Y * 0.5 * y
                            + partCFrame.LookVector * partSize.Z * 0.5 * z
                        local point = camera:WorldToViewportPoint(corner)
                        if point.Z > 0 then
                            pointsInFront = pointsInFront + 1
                            minX = math.min(minX, point.X)
                            minY = math.min(minY, point.Y)
                            maxX = math.max(maxX, point.X)
                            maxY = math.max(maxY, point.Y)
                        end
                    end
                end
            end
        end
    end

    local viewport = camera.ViewportSize
    if pointsInFront == 0 or maxX < 0 or minX > viewport.X or maxY < 0 or minY > viewport.Y then
        return nil
    end

    minX = math.clamp(minX, 0, viewport.X)
    minY = math.clamp(minY, 0, viewport.Y)
    maxX = math.clamp(maxX, 0, viewport.X)
    maxY = math.clamp(maxY, 0, viewport.Y)
    if maxX - minX < 3 or maxY - minY < 3 then
        return nil
    end

    return minX, minY, maxX, maxY
end

local function getHealthColor(percent)
    if percent > 0.75 then
        return Color3.fromRGB(40, 220, 80)
    elseif percent > 0.5 then
        return Color3.fromRGB(255, 220, 45)
    elseif percent > 0.25 then
        return Color3.fromRGB(255, 135, 35)
    end
    return Color3.fromRGB(255, 35, 35)
end

local function updateOverlay(camera, model, humanoid, root, distance, isClosest)
    local overlay = overlays[model] or createOverlay(model)
    local color = isClosest and closestColor or normalColor
    overlay.Highlight.OutlineColor = color
    overlay.Highlight.Enabled = componentEnabled.Outline

    if not (componentEnabled.Box or componentEnabled.HealthBar or componentEnabled.Name
        or componentEnabled.Distance or componentEnabled.Tracer) then
        hideScreenOverlay(overlay)
        return
    end

    local minX, minY, maxX, maxY = getScreenBounds(camera, model, root)
    if not minX then
        hideScreenOverlay(overlay)
        return
    end

    local width = maxX - minX
    local centerX = (minX + maxX) * 0.5
    overlay.Box.Position = UDim2.fromOffset(minX, minY)
    overlay.Box.Size = UDim2.fromOffset(width, maxY - minY)
    overlay.Stroke.Color = color
    overlay.Box.Visible = componentEnabled.Box

    local displayName = humanoid.DisplayName
    if not displayName:match("^%[Lv%.%s*%d+%]") then
        displayName = model.Name
    end
    overlay.Name.Text = displayName
    overlay.Name.TextColor3 = color
    overlay.Name.AnchorPoint = Vector2.new(0.5, 1)
    overlay.Name.Position = UDim2.fromOffset(centerX, minY - 3)
    overlay.Name.Visible = componentEnabled.Name

    local healthPercent = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    overlay.HealthBar.Position = UDim2.fromOffset(minX, maxY + 4)
    overlay.HealthBar.Size = UDim2.fromOffset(width, 5)
    overlay.HealthFill.Size = UDim2.fromScale(healthPercent, 1)
    overlay.HealthFill.BackgroundColor3 = getHealthColor(healthPercent)
    overlay.HealthBar.Visible = componentEnabled.HealthBar

    overlay.Distance.Text = string.format("%.0f studs", distance)
    overlay.Distance.TextColor3 = color
    overlay.Distance.Position = UDim2.fromOffset(centerX, maxY + 11)
    overlay.Distance.Visible = componentEnabled.Distance

    local startPoint = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
    local targetPoint = Vector2.new(centerX, maxY)
    local difference = targetPoint - startPoint
    local length = difference.Magnitude
    overlay.Tracer.BackgroundColor3 = color
    overlay.Tracer.Visible = componentEnabled.Tracer
        and (not componentEnabled.TracerClosestOnly or isClosest)
        and length > 1
    if overlay.Tracer.Visible then
        overlay.Tracer.Position = UDim2.fromOffset((startPoint.X + targetPoint.X) * 0.5, (startPoint.Y + targetPoint.Y) * 0.5)
        overlay.Tracer.Size = UDim2.fromOffset(length, 2)
        overlay.Tracer.Rotation = math.deg(math.atan2(difference.Y, difference.X))
    end
end

local function getMobTargets(mobs, origin)
    local valid = {}
    local closestModel = nil
    local closestDistance = math.huge

    for _, model in ipairs(mobs:GetChildren()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
                local distance = (root.Position - origin).Magnitude
                valid[model] = {humanoid = humanoid, root = root, distance = distance}
                if distance < closestDistance then
                    closestDistance = distance
                    closestModel = model
                end
            end
        end
    end

    return valid, closestModel, closestDistance
end

local targetedAbilityProfileRows = {
    {"Bow", "Firework Bow", "Charged Shot", 0, 1350, 1, 0.12, false, "Bow.Firework Bow.ChargedShot", 0},
    {"Bow", "Firework Bow", "Finale", 2, 1350, 12.5, 0.12, false, "Bow.Firework Bow.Finale", 0},
    {"Bow", "Normal Wooden Bow", "Charged Shot", 0, 1350, 0.8, 0.12, false, "Bow.Normal Wooden Bow.ChargedShot", 0},
    {"Bow", "Watergun", "Water Blast", 0, 260, 0.75, 5.85, true, "Bow.Watergun.ChargedShot", 0},
    {"Bow", "Watergun LE", "Charged Shot", 0, 260, 2.6, 20.35, true, "Bow.Watergun LE.ChargedShot", 0},
    {"Bow", "Watergun LE", "Hydro Beam", 4, 60, 20, 0.12, false, "Bow.Watergun LE.Hypershot", 0},
    {"Bow", "Wooden Bow", "Charged Shot", 0, 1350, 0.8, 0.12, false, "Bow.Wooden Bow.ChargedShot", 0},
    {"Bow", "Wooden Bow", "Arrow Rain", 2, 1350, 10, 0.12, false, "Bow.Wooden Bow.ArrowRain", 0},
    {"Elements", "Air", "Air Punch", 1, 350, 4, 0.12, false, "Elements.Air.AirPalm", 0},
    {"Elements", "Air", "Shurikens", 2, 350, 10, 0.12, false, "Elements.Air.Shurikens", 3.9},
    {"Elements", "Angel", "Barrage of Light", 3, 500, 8, 8.35, true, "Elements.Angel.AwakenedMoves.BarrageOfLight", 0},
    {"Elements", "Angel", "Angelic Plunge", 4, 100, 4, 0.12, false, "Elements.Angel.AwakenedMoves.AngelicPlunge", 0},
    {"Elements", "Angel", "Lux", 4, 350, 12, 5.35, true, "Elements.Angel.Lux", 0},
    {"Elements", "Astra", "Aether Wand", 0, 250, 0.25, 0.12, false, "Elements.Astra.AetherWand", 0},
    {"Elements", "Astra", "Asterism", 1, 400, 3, 0.12, false, "Elements.Astra.Asterism", 0},
    {"Elements", "Astra", "Shooting Star", 2, 600, 6, 12.35, true, "Elements.Astra.ShootingStar", 0},
    {"Elements", "Astra", "Guiding Light", 3, 450, 8, 0.12, false, "Elements.Astra.GuidingLight", 0},
    {"Elements", "Astra", "Deliverance", 5, 500, 12, 0.12, false, "Elements.Astra.Deliverance", 0},
    {"Elements", "BootlegPhantom", "Paper Punch", 1, 350, 1.5, 0.12, false, "Elements.BootlegPhantom.AirPalm", 0},
    {"Elements", "BootlegPhantom", "Paper Shurikens", 2, 350, 1, 0.12, false, "Elements.BootlegPhantom.Shurikens", 3.9},
    {"Elements", "BootlegSolar", "Blazing Sunlar", 1, 350, 5, 0.12, false, "Elements.BootlegSolar.BlazingSunlar", 0},
    {"Elements", "BootlegSolar", "Sunlar Drive", 2, 600, 10, 12.35, true, "Elements.BootlegSolar.SunlarDrive", 0},
    {"Elements", "BootlegSolar", "Orbital Sunlar", 3, 350, 5, 0.12, false, "Elements.BootlegSolar.OrbitingSunlar", 2.85},
    {"Elements", "BootlegSolar", "Sunlar Nova", 5, 300, 15, 0.12, false, "Elements.BootlegSolar.SunlarNova", 0},
    {"Elements", "Bunny", "Divekick", 0, 300, 0.6, 0.12, false, "Elements.Bunny.Eggkick", 0},
    {"Elements", "Bunny", "Egg-Fist Blast", 2, 350, 7, 0.12, false, "Elements.Bunny.EggFistBlast", 0},
    {"Elements", "Bunny", "Eggsplosive Missles", 4, 600, 8, 8.35, true, "Elements.Bunny.EggsplosiveMissles", 0},
    {"Elements", "Bunny", "Eggsplosion Enigma", 5, 50, 4, 0.12, false, "Elements.Bunny.EggsplosionEnigma", 0},
    {"Elements", "Darkness", "Void Crush", 1, 500, 5, 0.12, false, "Elements.Darkness.VoidCrush", 0},
    {"Elements", "Darkness", "Nova", 2, 500, 8, 0.12, false, "Elements.Darkness.Nova", 0},
    {"Elements", "Darkness", "Nightfall Rupture", 4, 500, 4, 0.12, false, "Elements.Darkness.NightFallRupture", 0},
    {"Elements", "Darkness", "GhoulStorm Mines", 5, 500, 11, 8.35, true, "Elements.Darkness.GhoulStormMines", 0},
    {"Elements", "Dragon", "Draconic Fury [M1]", 0, 600, 9, 0.12, false, "Elements.Dragon.AwakenedMoves.DraconicFury", 0},
    {"Elements", "Dragon", "Flamethrower", 1, 500, 2, 2.35, false, "Elements.Dragon.AwakenedMoves.Flamethrower", 0},
    {"Elements", "Dragon", "Dragon's Horns", 2, 350, 7, 0.12, false, "Elements.Dragon.DragonsHorn", 0},
    {"Elements", "Dragon", "Roar", 2, 600, 5, 5.35, false, "Elements.Dragon.AwakenedMoves.Roar", 0},
    {"Elements", "Dragon", "Acidic Spit", 3, 350, 12, 0.12, false, "Elements.Dragon.AcidicSpit", 0},
    {"Elements", "Dragon", "Fire Blast", 3, 600, 5, 0.12, false, "Elements.Dragon.AwakenedMoves.Fire Blast", 0},
    {"Elements", "Dragon", "Dragon's Eye", 4, 500, 12, 0.12, false, "Elements.Dragon.DragonsEye", 0},
    {"Elements", "Dragon", "Fireball Shower", 4, 1000, 8, 8.35, true, "Elements.Dragon.AwakenedMoves.Fireball Shower", 0},
    {"Elements", "Dragon", "Draconic Eruption", 5, 500, 18, 8.35, true, "Elements.Dragon.DraconicEruption", 0},
    {"Elements", "Earth", "Ground Stomp", 1, 350, 9, 0.12, false, "Elements.Earth.GroundStomp", 0},
    {"Elements", "Earth", "Earth Attack", 2, 500, 8, 0.12, false, "Elements.Earth.EarthAttack", 2.9},
    {"Elements", "Earth", "Earth Dragon", 3, 500, 6, 0.12, false, "Elements.Earth.EarthDragon", 0},
    {"Elements", "Fire", "Fireball", 1, 350, 4, 0.12, false, "Elements.Fire.Fireball", 0},
    {"Elements", "Fire", "Inferno Rounds", 3, 350, 10, 8.35, true, "Elements.Fire.InfernoRounds", 0},
    {"Elements", "Galaxy", "Galactic Blast", 1, 350, 5, 0.12, false, "Elements.Galaxy.GalacticBlast", 0},
    {"Elements", "Galaxy", "Neutron Star", 1, 500, 8, 0.12, false, "Elements.Galaxy.AwakenedMoves.NeutronStar", 0},
    {"Elements", "Galaxy", "Dimensional Phase", 2, 600, 8, 12.35, true, "Elements.Galaxy.DimensionalPhase", 0},
    {"Elements", "Galaxy", "Galactic Destruction", 3, 500, 8, 10.35, true, "Elements.Galaxy.GalacticDestruction", 0},
    {"Elements", "Galaxy", "Gamma Burst", 3, 265, 10, 0.12, false, "Elements.Galaxy.AwakenedMoves.GammaBurst", 0},
    {"Elements", "Galaxy", "Quasar", 4, 220, 10, 0.12, false, "Elements.Galaxy.AwakenedMoves.Quasar", 0},
    {"Elements", "Galaxy", "Starfall", 5, 280, 15, 0.12, false, "Elements.Galaxy.AwakenedMoves.Starfall", 0},
    {"Elements", "Gravity", "Gravity Push", 1, 50, 5, 0.12, false, "Elements.Gravity.Push", 0},
    {"Elements", "Gravity", "Singularity", 1, 500, 5, 0.12, false, "Elements.Gravity.AwakenedMoves.Singularity", 0},
    {"Elements", "Gravity", "Meteor", 2, 350, 4, 0.12, false, "Elements.Gravity.Meteor", 0},
    {"Elements", "Gravity", "Gravity Pull", 3, 50, 5, 0.12, false, "Elements.Gravity.Pull", 0},
    {"Elements", "Gravity", "Gravity Well", 3, 300, 12, 8.35, true, "Elements.Gravity.AwakenedMoves.GravityWell", 0},
    {"Elements", "Gravity", "10x Domain", 4, 300, 14, 8.35, false, "Elements.Gravity.AwakenedMoves.TenXDomain", 0},
    {"Elements", "Gravity", "Planet Destroyer", 5, 450, 18, 0.12, false, "Elements.Gravity.AwakenedMoves.PlanetDestroyer", 0},
    {"Elements", "Gravity", "Planetary Barrage", 5, 400, 10, 8.35, true, "Elements.Gravity.MeteorBarrage", 0},
    {"Elements", "Ice", "Ice Barrage", 1, 350, 8, 0.12, false, "Elements.Ice.IceBarrage", 2.9},
    {"Elements", "Ice", "Ice Shurikens", 2, 350, 10, 8.35, true, "Elements.Ice.IceShurikens", 0},
    {"Elements", "Ice", "Frozen Domain", 4, 350, 13, 0.12, false, "Elements.Ice.FrozenDomain", 0},
    {"Elements", "Ice", "Absolute Zero", 5, 500, 16, 0.12, false, "Elements.Ice.AbsoluteZero", 0},
    {"Elements", "Infinity", "Collapsing Blue", 2, 350, 5, 0.12, false, "Elements.Infinity.CollapsingBlue", 0},
    {"Elements", "Infinity", "Maximum Red Output", 3, 500, 7, 0.12, false, "Elements.Infinity.MaximumRedOutput", 0},
    {"Elements", "Infinity", "Hollow Purple", 5, 250, 10, 0.12, false, "Elements.Infinity.HollowPurple", 0},
    {"Elements", "Kitsune", "Claw Slash [M1]", 0, 500, 1, 0.12, false, "Elements.Kitsune.ClawSlash", 0},
    {"Elements", "Kitsune", "Fox Bomb", 1, 2000, 6, 0.12, false, "Elements.Kitsune.FoxBomb", 0},
    {"Elements", "Kitsune", "Claw Spin", 2, 500, 5, 10.35, true, "Elements.Kitsune.ClawSpin", 0},
    {"Elements", "Kitsune", "Fox Shock", 4, 5000, 8, 0.12, false, "Elements.Kitsune.FoxShock", 0},
    {"Elements", "Krampus", "Candy Cane Slash [M1]", 0, 250, 0.15, 0.12, false, "Elements.Krampus.CandyCaneSlash", 0},
    {"Elements", "Krampus", "Peppermint Revenge", 1, 450, 5, 0.12, false, "Elements.Krampus.PeppermintRevenge", 0},
    {"Elements", "Krampus", "Glacial Shuriken Storm", 2, 450, 9, 0.12, false, "Elements.Krampus.GlacialShurikenStorm", 2.85},
    {"Elements", "Lava", "Lava Strike", 1, 600, 5, 0.12, false, "Elements.Lava.LavaStrike", 0},
    {"Elements", "Lava", "Magma Phase", 3, 100, 5, 0.12, false, "Elements.Lava.MagmaPhase", 0},
    {"Elements", "Lava", "Lava Rain", 4, 350, 8, 3.35, true, "Elements.Lava.LavaRain", 0},
    {"Elements", "Light", "Light Shot", 1, 150, 4, 0.12, false, "Elements.Light.LightShot", 0},
    {"Elements", "Light", "Light Kick", 2, 100, 6, 0.12, false, "Elements.Light.LightKick", 0},
    {"Elements", "Light", "Light Ray", 3, 300, 10, 6.35, true, "Elements.Light.LightRay", 0},
    {"Elements", "Light", "Light Barrage", 5, 300, 12, 8.35, true, "Elements.Light.LightBarrage", 0},
    {"Elements", "Lightning", "Raging Thunderstorm", 1, 500, 4, 0.12, false, "Elements.Lightning.AwakenedMoves.RagingThunderstorm", 0},
    {"Elements", "Lightning", "Thunderstrike", 1, 150, 6, 0.12, false, "Elements.Lightning.Thunderstrike", 0},
    {"Elements", "Lightning", "Lightning Dash", 2, 120, 7, 0.12, false, "Elements.Lightning.LightningDash", 0},
    {"Elements", "Lightning", "Piercing Lightning", 2, 400, 5, 1.85, true, "Elements.Lightning.AwakenedMoves.PiercingLightning", 0},
    {"Elements", "Lightning", "Lightning Chain", 3, 125, 10, 0.12, false, "Elements.Lightning.LightningChain", 0},
    {"Elements", "Lightning", "Thunderclap Drive", 3, 200, 6, 0.12, false, "Elements.Lightning.AwakenedMoves.ThunderclapDrive", 0},
    {"Elements", "Lightning", "Lightning Fury", 4, 350, 12, 8.35, true, "Elements.Lightning.LightningFury", 0},
    {"Elements", "Lightning", "Smite", 4, 500, 8, 8.35, true, "Elements.Lightning.AwakenedMoves.Smite", 0},
    {"Elements", "Lightning", "Thunderous Nova", 5, 350, 12, 0.12, false, "Elements.Lightning.ThunderousNova", 0},
    {"Elements", "Lunar", "Crescent Slash", 0, 500, 0.1, 0.12, false, "Elements.Lunar.CrescentSlash", 0},
    {"Elements", "Lunar", "Yue", 2, 300, 8, 0.12, false, "Elements.Lunar.Yue", 0},
    {"Elements", "Mech", "Laser Beam [M1]", 0, 500, 0.6, 0.12, false, "Elements.Mech.M1", 0},
    {"Elements", "Mech", "Afterburner Blast", 4, 500, 6, 17.85, true, "Elements.Mech.AfterburnerBlast", 0},
    {"Elements", "Moonlar", "Crescent Slash", 0, 375, 0.6, 0.12, false, "Elements.Moonlar.CrescentSlash", 0},
    {"Elements", "Moonlar", "Yue", 2, 300, 8, 0.12, false, "Elements.Moonlar.Yue", 0},
    {"Elements", "Nature", "Nature Beam [M1]", 0, 150, 2, 0.12, false, "Elements.Nature.M1", 0},
    {"Elements", "Nature", "Tornado", 1, 350, 8, 0.12, false, "Elements.Nature.Tornado", 0},
    {"Elements", "Nature", "Nature Arrow", 2, 200, 6, 0.12, false, "Elements.Nature.NatureArrow", 0},
    {"Elements", "Nature", "Nature Missle", 3, 600, 12, 8.35, true, "Elements.Nature.NatureMissle", 0},
    {"Elements", "Nature", "Nature's Fury", 4, 600, 14, 0.12, false, "Elements.Nature.NatureFury", 0},
    {"Elements", "Nightmare", "Shadow Grip", 1, 450, 4, 0.12, false, "Elements.Nightmare.ShadowGrip", 0},
    {"Elements", "Nightmare", "Terror Pulse", 3, 350, 8, 0.12, false, "Elements.Nightmare.TerrorPulse", 0},
    {"Elements", "Phantom", "Hand Slap [M1]", 0, 600, 1, 0.12, false, "Elements.Phantom.M1", 0},
    {"Elements", "Phantom", "Flick", 1, 350, 3, 0.12, false, "Elements.Phantom.Flick", 0},
    {"Elements", "Phantom", "Smash", 2, 150, 6, 0.12, false, "Elements.Phantom.Smash", 0},
    {"Elements", "Phantom", "Barrage", 3, 350, 12, 0.12, false, "Elements.Phantom.Barrage", 6.35},
    {"Elements", "Psychic", "Psychic Blast", 1, 350, 0.1, 0.12, false, "Elements.Psychic.PsychicBlast", 0},
    {"Elements", "Psychic", "Psychic Projectile", 2, 450, 0.1, 0.12, false, "Elements.Psychic.PsychicProjectile", 0},
    {"Elements", "Psychic", "Psychic Crush", 3, 350, 0.1, 0.12, false, "Elements.Psychic.PsychicCrush", 0},
    {"Elements", "Psychic", "Telekinesis", 5, 400, 0.1, 0.12, false, "Elements.Psychic.Telekinesis", 2.85},
    {"Elements", "Reaper", "Soul Steal", 1, 500, 5, 0.12, false, "Elements.Reaper.AwakenedMoves.Soul Steal", 0},
    {"Elements", "Reaper", "Spirit Burst", 3, 200, 8, 0.12, false, "Elements.Reaper.AwakenedMoves.Spirit Burst", 0},
    {"Elements", "Sand", "Sand Blast", 1, 350, 5, 0.12, false, "Elements.Sand.SandBlast", 0},
    {"Elements", "Sand", "Sand Tornado", 2, 350, 9, 0.12, false, "Elements.Sand.SandTornado", 0},
    {"Elements", "Smoke", "Smoke Projectile", 1, 350, 4, 0.12, false, "Elements.Smoke.SmokeProjectile", 0},
    {"Elements", "Smoke", "Smoke Rain", 3, 500, 12, 8.35, true, "Elements.Smoke.SmokeRain", 0},
    {"Elements", "Smoke", "Smoke Bomb", 4, 400, 13, 0.12, false, "Elements.Smoke.SmokeBomb", 0},
    {"Elements", "Smoke", "Smoke Missile", 5, 600, 18, 8.35, true, "Elements.Smoke.SmokeMissile", 0},
    {"Elements", "Solar", "Blazing Blast", 1, 350, 5, 0.12, false, "Elements.Solar.BlazingBlast", 0},
    {"Elements", "Solar", "Orbital Burst", 3, 350, 5, 0.12, false, "Elements.Solar.OrbitingFlames", 2.85},
    {"Elements", "Solar", "Solar Nova", 5, 300, 15, 0.12, false, "Elements.Solar.SunNova", 0},
    {"Elements", "Time", "Temporal Seam", 0, 500, 1.75, 0.12, false, "Elements.Time.TemporalSeam", 0},
    {"Elements", "Time", "Temporal Tear", 0, 500, 2, 0.12, false, "Elements.Time.TemporalTear", 0},
    {"Elements", "Time", "Flash Forward", 3, 600, 6, 0.12, false, "Elements.Time.FlashForward", 0},
    {"Elements", "Time", "Timeline Destruction", 3, 500, 6, 0.12, false, "Elements.Time.TimelineDestruction", 0},
    {"Elements", "Time", "Collapsing Rift", 4, 500, 15, 0.12, false, "Elements.Time.CollapsingRift", 0},
    {"Elements", "Water", "Roaring Wave", 1, 600, 6, 0.12, false, "Elements.Water.RoaringWave", 0},
    {"Elements", "Water", "Water Barrage", 3, 500, 16, 8.35, true, "Elements.Water.WaterBarrage", 0},
    {"Sword", "Abyssal Trident", "Abyssal Grapple", 2, 100, 2, 0.12, false, "Sword.Abyssal Trident.Throw", 0},
    {"Sword", "Ascended Lightning Katana", "Plasma Slash", 2, 350, 2, 0.12, false, "Sword.Ascended Lightning Katana.PlasmaRay", 0},
    {"Sword", "Conqueror's Blade", "Wind Dragon Force", 2, 600, 10, 8.35, true, "Sword.Conqueror's Blade.WindDragonForce", 0},
    {"Sword", "Conqueror's BladeTL", "Wind Dragon Force", 2, 600, 8, 8.35, true, "Sword.Conqueror's BladeTL.WindDragonForce", 0},
    {"Sword", "Conqueror's BladeTL", "Wind Slash", 3, 300, 6, 0.12, false, "Sword.Conqueror's BladeTL.WindSlash", 2.85},
    {"Sword", "Conqueror's BladeTL LE", "Wind Dragon Force", 2, 600, 6, 6.35, true, "Sword.Conqueror's BladeTL LE.WindDragonForce", 0},
    {"Sword", "Conqueror's BladeTL LE", "Wind Slash", 3, 300, 1.7, 0.12, false, "Sword.Conqueror's BladeTL LE.WindSlash", 2.85},
    {"Sword", "DevElemental", "Elemental Shurikens", 4, 350, 14, 0.12, false, "Sword.DevElemental", 2.85},
    {"Sword", "Elemental", "Elemental Shurikens", 4, 350, 14, 0.12, false, "Sword.Elemental", 2.85},
    {"Sword", "Fusion", "Elemental Shurikens", 4, 350, 14, 0.12, false, "Sword.Fusion", 2.85},
    {"Sword", "GlitchedStaff", "Homing Bolt", 0, 350, 1, 0.12, false, "Sword.GlitchedStaff", 0},
    {"Sword", "Lightning Katana", "Plasma Slash", 2, 350, 2, 0.12, false, "Sword.Lightning Katana.PlasmaRay", 0},
    {"Sword", "Poseidon's Trident", "Trident Grapple", 2, 100, 8, 0.12, false, "Sword.Poseidon's Trident.Throw", 0},
    {"Sword", "Rhitta", "Blazing Rain", 3, 300, 22, 0.12, false, "Sword.Rhitta.BlazingRain", 0},
    {"Sword", "Rhitta", "Maximum Nova", 4, 300, 30, 4.05, false, "Sword.Rhitta.MaximumNova", 0},
    {"Sword", "SeriousStaff", "Sunlar Bolt", 0, 375, 1, 0.12, false, "Sword.SeriousStaff.SeriousSwing", 0},
    {"Sword", "SeriousStaff", "WE are Wumpus", 3, 600, 10, 12.35, true, "Sword.SeriousStaff.SeriousDrive", 0},
    {"Sword", "ViltronStaff", "Homing Bolt", 0, 300, 1, 0.12, false, "Sword.ViltronStaff", 0},
    {"Sword", "Voidblade", "Ember Fireball", 4, 350, 14, 0.12, false, "Sword.Voidblade", 2.85},
    {"Sword", "WilbertStaff", "Sunlar Bolt", 0, 900, 1, 0.12, false, "Sword.WilbertStaff.SeriousSwing", 0},
    {"Sword", "WilbertStaff", "Lar", 5, 1500, 10, 0.12, false, "Sword.WilbertStaff.AngryDms", 0},
}

local targetedAbilityProfiles = {}
local targetedAbilityProfilesByOwner = {}
for _, row in ipairs(targetedAbilityProfileRows) do
    local profile = {
        category = row[1],
        owner = row[2],
        title = row[3],
        keybind = row[4],
        range = row[5],
        cooldown = row[6],
        hold = row[7],
        continuous = row[8],
        id = row[9],
        trackAfterRelease = row[10] or 0,
    }
    table.insert(targetedAbilityProfiles, profile)
    local ownerKey = profile.category .. "|" .. profile.owner
    targetedAbilityProfilesByOwner[ownerKey] = targetedAbilityProfilesByOwner[ownerKey] or {}
    table.insert(targetedAbilityProfilesByOwner[ownerKey], profile)
end

local galacticDestructionRange = 500
local galacticDestructionDuration = 10.35
local galacticDestructionCooldown = 8.15
local galacticAimDirections = {
    Vector3.new(1, 0, 0),
    Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1),
    Vector3.new(0, 0, -1),
    Vector3.new(1, 1, 0).Unit,
    Vector3.new(-1, 1, 0).Unit,
    Vector3.new(0, 1, 1).Unit,
    Vector3.new(0, 1, -1).Unit,
    Vector3.new(0, 1, 0),
    Vector3.new(0, -1, 0),
}

local function getClosestGalacticTarget()
    local character = localPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local mobs = workspace:FindFirstChild("Mobs")
    if not localRoot or not humanoid or humanoid.Health <= 0 or not mobs then
        return nil
    end

    local valid, closestModel, closestDistance = getMobTargets(mobs, localRoot.Position)
    local target = closestModel and valid[closestModel]
    if not target or closestDistance > galacticDestructionRange then
        return nil
    end

    return {
        model = closestModel,
        root = target.root,
        humanoid = target.humanoid,
        localRoot = localRoot,
    }
end

local function isGalacticDestructionEquipped()
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    local moveset = playerGui and playerGui:FindFirstChild("Moveset")
    if not moveset then
        return false
    end

    for _, descendant in ipairs(moveset:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
            and descendant.Visible and descendant.Text == "Galactic Destruction" then
            return true
        end
    end
    return false
end

local function isGalaxyElementHeld()
    local character = localPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    return tool ~= nil and tool:GetAttribute("Type") == "Elements"
        and tool:GetAttribute("UUID") == "Galaxy"
end

local function isLocalGalacticDestructionActive()
    local character = localPlayer.Character
    local effects = workspace:FindFirstChild("Effects")
    if not character or not effects then
        return false
    end

    for _, effect in ipairs(effects:GetChildren()) do
        if effect.Name == "GalacticBeam" then
            for _, descendant in ipairs(effect:GetDescendants()) do
                if descendant:IsA("WeldConstraint") and descendant.Part1
                    and descendant.Part1:IsDescendantOf(character) then
                    return true
                end
            end
        end
    end
    return false
end

local function isValidGalacticTarget(target)
    local mobs = workspace:FindFirstChild("Mobs")
    return target and mobs and target.model.Parent == mobs
        and target.root.Parent == target.model
        and target.humanoid.Parent == target.model
        and target.humanoid.Health > 0
        and target.localRoot.Parent == localPlayer.Character
        and (target.root.Position - target.localRoot.Position).Magnitude <= galacticDestructionRange
end

local function buildGalacticMouseData(target)
    if not isValidGalacticTarget(target) then
        return nil
    end

    local targetPosition = target.root.Position
    local effects = workspace:FindFirstChild("Effects")
    local filter = {localPlayer.Character}
    if effects then
        table.insert(filter, effects)
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = filter

    -- The server still performs its own raycast and clamps the endpoint to
    -- the move's 500-stud range. Starting a short ray around the selected mob
    -- keeps unrelated map geometry out of that ray without changing the map.
    local originDistance = math.max(12, target.root.Size.Magnitude * 0.5 + 6)
    local bestOrigin = nil
    local bestDirection = nil
    local bestPosition = nil
    local bestError = math.huge
    for _, offsetDirection in ipairs(galacticAimDirections) do
        local origin = targetPosition + offsetDirection * originDistance
        local direction = (targetPosition - origin).Unit
        local result = workspace:Raycast(origin, direction * galacticDestructionRange, raycastParams)
        local position = result and result.Position
            or origin + direction * galacticDestructionRange
        local errorDistance = (position - targetPosition).Magnitude
        if errorDistance < bestError then
            bestError = errorDistance
            bestOrigin = origin
            bestDirection = direction
            bestPosition = position
        end
    end

    if not bestOrigin then
        return nil
    end
    return {
        Origin = bestOrigin,
        Direction = bestDirection,
        Position = bestPosition,
        CharacterPosition = target.localRoot.Position,
    }
end

local function applyGalacticHiddenCameraAim()
    local camera = workspace.CurrentCamera
    local target = galacticDestructionTarget
    local mouseData = buildGalacticMouseData(target)
    if not camera or not mouseData or not isValidGalacticTarget(target) then
        return
    end

    -- DeviceController samples the real camera after simulation. Rotate that
    -- temporary, non-rendered state so the ray through the user's current
    -- cursor position points at the mob. The visible camera is restored before
    -- the next frame is rendered.
    local mousePosition = UserInputService:GetMouseLocation()
    camera.CFrame = CFrame.new(mouseData.Origin)
    local unrotatedRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
    local localDirection = camera.CFrame:VectorToObjectSpace(unrotatedRay.Direction).Unit
    local desiredDirection = (target.root.Position - mouseData.Origin).Unit
    local desiredLook = CFrame.lookAt(Vector3.zero, desiredDirection).Rotation
    local localLook = CFrame.lookAt(Vector3.zero, localDirection).Rotation
    camera.CFrame = CFrame.new(mouseData.Origin) * desiredLook * localLook:Inverse()
    camera.Focus = CFrame.new(target.root.Position)
end

local function startGalacticCameraAim()
    if galacticCameraBound then
        return true
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end
    galacticCameraVisibleCFrame = camera.CFrame
    galacticCameraVisibleFocus = camera.Focus
    pcall(function()
        RunService:UnbindFromRenderStep(galacticCameraRestoreBindName)
        RunService:UnbindFromRenderStep(galacticCameraCaptureBindName)
    end)
    local restoreOk = pcall(function()
        RunService:BindToRenderStep(
            galacticCameraRestoreBindName,
            -- PlayerModule derives WASD direction at Input priority. Restore
            -- the visible camera before that calculation so hidden ability
            -- aiming cannot rotate the player's movement controls.
            Enum.RenderPriority.Input.Value - 1,
            function()
                local currentCamera = workspace.CurrentCamera
                if currentCamera and galacticCameraVisibleCFrame and galacticCameraVisibleFocus then
                    currentCamera.CFrame = galacticCameraVisibleCFrame
                    currentCamera.Focus = galacticCameraVisibleFocus
                end
            end
        )
    end)
    local captureOk = pcall(function()
        RunService:BindToRenderStep(
            galacticCameraCaptureBindName,
            Enum.RenderPriority.Camera.Value + 2,
            function()
                local currentCamera = workspace.CurrentCamera
                if currentCamera then
                    galacticCameraVisibleCFrame = currentCamera.CFrame
                    galacticCameraVisibleFocus = currentCamera.Focus
                end
            end
        )
    end)
    if not restoreOk or not captureOk then
        pcall(function()
            RunService:UnbindFromRenderStep(galacticCameraRestoreBindName)
            RunService:UnbindFromRenderStep(galacticCameraCaptureBindName)
        end)
        galacticCameraVisibleCFrame = nil
        galacticCameraVisibleFocus = nil
        return false
    end

    galacticCameraPostSimulationConnection = RunService.PostSimulation:Connect(function()
        if galacticDestructionEnabled and galacticDestructionTarget then
            applyGalacticHiddenCameraAim()
        end
    end)
    galacticCameraBound = true
    return true
end

local function stopGalacticCameraAim()
    if galacticCameraPostSimulationConnection then
        galacticCameraPostSimulationConnection:Disconnect()
        galacticCameraPostSimulationConnection = nil
    end
    if galacticCameraBound then
        pcall(function()
            RunService:UnbindFromRenderStep(galacticCameraRestoreBindName)
            RunService:UnbindFromRenderStep(galacticCameraCaptureBindName)
        end)
    end
    galacticCameraBound = false

    local camera = workspace.CurrentCamera
    if camera and galacticCameraVisibleCFrame and galacticCameraVisibleFocus then
        camera.CFrame = galacticCameraVisibleCFrame
        camera.Focus = galacticCameraVisibleFocus
    end
    galacticCameraVisibleCFrame = nil
    galacticCameraVisibleFocus = nil
end

local function setGalacticDestructionKeyHeld(held)
    if galacticDestructionKeyHeld == held then
        return
    end
    galacticDestructionKeyHeld = held
    pcall(function()
        VirtualInputManager:SendKeyEvent(held, Enum.KeyCode.C, false, game)
    end)
end

local function applyAntiFreeze()
    if not antiFreezeEnabled then
        return
    end

    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    -- CharacterController:LockCharacter creates this default-named,
    -- infinite-force constraint for held and aimed abilities. Disabling it
    -- preserves normal movement while the game's own cleanup still owns it.
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("AlignPosition") and child.Name == "AlignPosition"
            and child.MaxForce == math.huge then
            child.Enabled = false
        end
    end
end

local function setAntiFreezeEnabled(enabled)
    antiFreezeEnabled = enabled
    if antiFreezeConnection then
        antiFreezeConnection:Disconnect()
        antiFreezeConnection = nil
    end

    if not antiFreezeEnabled then
        return
    end
    applyAntiFreeze()
    antiFreezeConnection = RunService.Stepped:Connect(function()
        if antiFreezeEnabled then
            applyAntiFreeze()
        end
    end)
end

local function setGalacticDestructionEnabled(enabled)
    galacticDestructionEnabled = enabled
    galacticDestructionGeneration = galacticDestructionGeneration + 1
    local generation = galacticDestructionGeneration

    if not galacticDestructionEnabled then
        galacticDestructionTarget = nil
        setGalacticDestructionKeyHeld(false)
        stopGalacticCameraAim()
        return
    end

    task.spawn(function()
        while galacticDestructionEnabled and generation == galacticDestructionGeneration do
            local target = getClosestGalacticTarget()
            local textBoxFocused = UserInputService:GetFocusedTextBox() ~= nil
            if target and not textBoxFocused and isGalaxyElementHeld()
                and isGalacticDestructionEquipped() then
                galacticDestructionTarget = target
                local castStarted = startGalacticCameraAim()
                if castStarted then
                    RunService.PostSimulation:Wait()
                    castStarted = galacticDestructionEnabled
                        and generation == galacticDestructionGeneration
                        and isValidGalacticTarget(galacticDestructionTarget)
                        and isGalaxyElementHeld()
                end

                if castStarted then
                    local pressedAt = os.clock()
                    setGalacticDestructionKeyHeld(true)
                    local activationDeadline = pressedAt + 0.8
                    while galacticDestructionEnabled and generation == galacticDestructionGeneration
                        and os.clock() < activationDeadline
                        and not isLocalGalacticDestructionActive() do
                        applyAntiFreeze()
                        RunService.RenderStepped:Wait()
                    end
                    castStarted = isLocalGalacticDestructionActive()
                    local finishAt = pressedAt + galacticDestructionDuration

                    while castStarted and galacticDestructionEnabled
                        and generation == galacticDestructionGeneration
                        and os.clock() < finishAt do
                        local nextTarget = getClosestGalacticTarget()
                        galacticDestructionTarget = nextTarget
                        applyAntiFreeze()
                        RunService.Heartbeat:Wait()
                    end
                end

                setGalacticDestructionKeyHeld(false)
                stopGalacticCameraAim()
                galacticDestructionTarget = nil
                local readyAt = castStarted and os.clock() + galacticDestructionCooldown or os.clock()
                repeat
                    task.wait(0.1)
                until not galacticDestructionEnabled
                    or generation ~= galacticDestructionGeneration
                    or os.clock() >= readyAt
            else
                galacticDestructionTarget = nil
                setGalacticDestructionKeyHeld(false)
                stopGalacticCameraAim()
                task.wait(0.1)
            end
        end

        setGalacticDestructionKeyHeld(false)
        if generation == galacticDestructionGeneration then
            galacticDestructionTarget = nil
            stopGalacticCameraAim()
        end
    end)
end

local autoTargetKeybinds = {
    [1] = Enum.KeyCode.F,
    [2] = Enum.KeyCode.R,
    [3] = Enum.KeyCode.C,
    [4] = Enum.KeyCode.V,
    [5] = Enum.KeyCode.G,
}

local function getHeldCombatTool()
    local character = localPlayer.Character
    return character and character:FindFirstChildOfClass("Tool")
end

local function getHeldProfileOwner(tool)
    if not tool then
        return nil, nil
    end
    if tool:GetAttribute("Type") == "Elements" then
        local owner = tool:GetAttribute("UUID")
        if type(owner) == "string" then
            return "Elements", owner
        end
        return nil, nil
    end
    if tool:GetAttribute("Type") ~= "Weapons" then
        return nil, nil
    end

    for _, category in ipairs({"Sword", "Bow"}) do
        if targetedAbilityProfilesByOwner[category .. "|" .. tool.Name] then
            return category, tool.Name
        end
    end
    return nil, nil
end

local function getVisibleAbilityTitles()
    local result = {}
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    local moveset = playerGui and playerGui:FindFirstChild("Moveset")
    if not moveset then
        return result
    end

    local function isRendered(guiObject)
        local current = guiObject
        while current and current ~= moveset do
            if current:IsA("GuiObject") and not current.Visible then
                return false
            end
            current = current.Parent
        end
        return current == moveset
    end

    for _, descendant in ipairs(moveset:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
            and descendant.Text ~= "" and isRendered(descendant) then
            result[descendant.Text] = true
        end
    end
    return result
end

local function getEquippedTargetedProfiles()
    local tool = getHeldCombatTool()
    local category, owner = getHeldProfileOwner(tool)
    if not category or not owner then
        return {}, tool
    end

    local visibleTitles = getVisibleAbilityTitles()
    local available = {}
    for _, profile in ipairs(targetedAbilityProfilesByOwner[category .. "|" .. owner] or {}) do
        -- Primary attacks are not shown in the moveset. Slotted abilities must
        -- be visible so base and awakened forms never fire each other's moves.
        if profile.keybind == 0 or visibleTitles[profile.title] then
            table.insert(available, profile)
        end
    end
    return available, tool
end

local function getClosestAbilityTarget(range)
    local character = localPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local mobs = workspace:FindFirstChild("Mobs")
    if not localRoot or not humanoid or humanoid.Health <= 0 or not mobs then
        return nil
    end

    local valid, closestModel, closestDistance = getMobTargets(mobs, localRoot.Position)
    local target = closestModel and valid[closestModel]
    if not target or closestDistance > range then
        return nil
    end
    return {
        model = closestModel,
        root = target.root,
        humanoid = target.humanoid,
        localRoot = localRoot,
    }
end

local function isValidAbilityTarget(target, range)
    local mobs = workspace:FindFirstChild("Mobs")
    return target and mobs and target.model.Parent == mobs
        and target.root.Parent == target.model
        and target.humanoid.Parent == target.model
        and target.humanoid.Health > 0
        and target.localRoot.Parent == localPlayer.Character
        and (target.root.Position - target.localRoot.Position).Magnitude <= range
end

local function buildAutoTargetMouseData(target, range)
    if not isValidAbilityTarget(target, range) then
        return nil
    end

    local targetPosition = target.root.Position
    local effects = workspace:FindFirstChild("Effects")
    local filter = {localPlayer.Character}
    if effects then
        table.insert(filter, effects)
    end
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = filter

    -- Put the unrendered mouse ray close to the requested landing point. This
    -- makes target-position abilities accurate even when map geometry lies
    -- between the visible camera and the mob.
    local rayLength = math.max(range, 20)
    local originDistance = math.min(rayLength * 0.5, math.max(12, target.root.Size.Magnitude * 0.5 + 6))
    local bestOrigin = nil
    local bestPosition = nil
    local bestError = math.huge
    for _, offsetDirection in ipairs(galacticAimDirections) do
        local origin = targetPosition + offsetDirection * originDistance
        local direction = (targetPosition - origin).Unit
        local result = workspace:Raycast(origin, direction * rayLength, raycastParams)
        local position = result and result.Position or origin + direction * rayLength
        local errorDistance = (position - targetPosition).Magnitude
        if errorDistance < bestError then
            bestError = errorDistance
            bestOrigin = origin
            bestPosition = position
        end
    end
    if not bestOrigin then
        return nil
    end
    return {
        Origin = bestOrigin,
        Position = bestPosition,
        CharacterPosition = target.localRoot.Position,
    }
end

local function applyAutoTargetHiddenCameraAim()
    local camera = workspace.CurrentCamera
    local profile = autoTargetAbilityProfile
    local target = autoTargetAbilityTarget
    local mouseData = profile and buildAutoTargetMouseData(target, profile.range)
    if not camera or not profile or not mouseData or not isValidAbilityTarget(target, profile.range) then
        return
    end

    local mousePosition = UserInputService:GetMouseLocation()
    camera.CFrame = CFrame.new(mouseData.Origin)
    local unrotatedRay = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
    local localDirection = camera.CFrame:VectorToObjectSpace(unrotatedRay.Direction).Unit
    local desiredDirection = (target.root.Position - mouseData.Origin).Unit
    local desiredLook = CFrame.lookAt(Vector3.zero, desiredDirection).Rotation
    local localLook = CFrame.lookAt(Vector3.zero, localDirection).Rotation
    camera.CFrame = CFrame.new(mouseData.Origin) * desiredLook * localLook:Inverse()
    camera.Focus = CFrame.new(target.root.Position)
end

local function startAutoTargetCameraAim()
    if autoTargetCameraBound then
        return true
    end
    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    autoTargetCameraVisibleCFrame = camera.CFrame
    autoTargetCameraVisibleFocus = camera.Focus
    pcall(function()
        RunService:UnbindFromRenderStep(autoTargetCameraRestoreBindName)
        RunService:UnbindFromRenderStep(autoTargetCameraCaptureBindName)
    end)
    local restoreOk = pcall(function()
        RunService:BindToRenderStep(autoTargetCameraRestoreBindName, Enum.RenderPriority.Input.Value - 1, function()
            local currentCamera = workspace.CurrentCamera
            if currentCamera and autoTargetCameraVisibleCFrame and autoTargetCameraVisibleFocus then
                currentCamera.CFrame = autoTargetCameraVisibleCFrame
                currentCamera.Focus = autoTargetCameraVisibleFocus
            end
        end)
    end)
    local captureOk = pcall(function()
        RunService:BindToRenderStep(autoTargetCameraCaptureBindName, Enum.RenderPriority.Camera.Value + 2, function()
            local currentCamera = workspace.CurrentCamera
            if currentCamera then
                autoTargetCameraVisibleCFrame = currentCamera.CFrame
                autoTargetCameraVisibleFocus = currentCamera.Focus
            end
        end)
    end)
    if not restoreOk or not captureOk then
        pcall(function()
            RunService:UnbindFromRenderStep(autoTargetCameraRestoreBindName)
            RunService:UnbindFromRenderStep(autoTargetCameraCaptureBindName)
        end)
        autoTargetCameraVisibleCFrame = nil
        autoTargetCameraVisibleFocus = nil
        return false
    end

    autoTargetCameraPostSimulationConnection = RunService.PostSimulation:Connect(function()
        if autoTargetAbilitiesEnabled and autoTargetAbilityTarget and autoTargetAbilityProfile then
            applyAutoTargetHiddenCameraAim()
        end
    end)
    autoTargetCameraBound = true
    return true
end

local function stopAutoTargetCameraAim()
    if autoTargetCameraPostSimulationConnection then
        autoTargetCameraPostSimulationConnection:Disconnect()
        autoTargetCameraPostSimulationConnection = nil
    end
    if autoTargetCameraBound then
        pcall(function()
            RunService:UnbindFromRenderStep(autoTargetCameraRestoreBindName)
            RunService:UnbindFromRenderStep(autoTargetCameraCaptureBindName)
        end)
    end
    autoTargetCameraBound = false

    local camera = workspace.CurrentCamera
    if camera and autoTargetCameraVisibleCFrame and autoTargetCameraVisibleFocus then
        camera.CFrame = autoTargetCameraVisibleCFrame
        camera.Focus = autoTargetCameraVisibleFocus
    end
    autoTargetCameraVisibleCFrame = nil
    autoTargetCameraVisibleFocus = nil
end

local function releaseAutoTargetInput()
    local input = autoTargetAbilityInput
    if not input then
        return
    end
    pcall(function()
        if input.keybind == 0 then
            VirtualInputManager:SendMouseButtonEvent(input.x, input.y, 0, false, game, 0)
        else
            VirtualInputManager:SendKeyEvent(false, autoTargetKeybinds[input.keybind], false, game)
        end
    end)
    autoTargetAbilityInput = nil
end

local function pressAutoTargetInput(profile)
    releaseAutoTargetInput()
    if profile.keybind == 0 then
        local mousePosition = UserInputService:GetMouseLocation()
        autoTargetAbilityInput = {keybind = 0, x = mousePosition.X, y = mousePosition.Y}
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(mousePosition.X, mousePosition.Y, 0, true, game, 0)
        end)
        return
    end

    local keyCode = autoTargetKeybinds[profile.keybind]
    if not keyCode then
        return
    end
    autoTargetAbilityInput = {keybind = profile.keybind}
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    end)
end

local function isProfileStillHeld(profile)
    local category, owner = getHeldProfileOwner(getHeldCombatTool())
    return category == profile.category and owner == profile.owner
end

local function getAutoTargetToolController(tool)
    if not tool then
        autoTargetAbilityController = nil
        autoTargetAbilityControllerTool = nil
        autoTargetAbilityControllerLastSearch = 0
        return nil
    end

    if autoTargetAbilityControllerTool ~= tool then
        autoTargetAbilityController = nil
        autoTargetAbilityControllerTool = tool
        autoTargetAbilityControllerLastSearch = 0
    end

    if autoTargetAbilityController
        and rawget(autoTargetAbilityController, "Tool") == tool
        and type(rawget(autoTargetAbilityController, "Abilities")) == "table"
        and type(rawget(autoTargetAbilityController, "AbilitiesInCooldown")) == "table"
        and type(rawget(autoTargetAbilityController, "AbilityCooldownsBySlot")) == "table" then
        return autoTargetAbilityController
    end

    local now = os.clock()
    if now - autoTargetAbilityControllerLastSearch < 0.5 then
        return nil
    end
    autoTargetAbilityControllerLastSearch = now

    -- ToolTemplate keeps the exact server-synchronized cooldown end-times in
    -- its per-tool client object. Reading that object avoids guessing from the
    -- base cooldown, which is wrong after perks, variants, and reductions.
    if type(getgc) ~= "function" then
        return nil
    end

    local success, objects = pcall(getgc, true)
    if not success or type(objects) ~= "table" then
        success, objects = pcall(getgc)
    end
    if not success or type(objects) ~= "table" then
        return nil
    end

    for _, object in pairs(objects) do
        if type(object) == "table"
            and rawget(object, "Tool") == tool
            and type(rawget(object, "Abilities")) == "table"
            and type(rawget(object, "UsingAbilities")) == "table"
            and type(rawget(object, "AbilitiesInCooldown")) == "table"
            and type(rawget(object, "AbilityCooldownsBySlot")) == "table" then
            autoTargetAbilityController = object
            return object
        end
    end

    return nil
end

local function getAutoTargetAbilityModule(controller, profile)
    local titleMatch = nil
    local abilities = controller and rawget(controller, "Abilities")
    if type(abilities) ~= "table" then
        return nil
    end

    for abilityModule, ability in pairs(abilities) do
        local data = type(ability) == "table" and rawget(ability, "Data") or nil
        if typeof(abilityModule) == "Instance" and type(data) == "table" then
            local fullName = abilityModule:GetFullName()
            if string.sub(fullName, -#profile.id) == profile.id then
                return abilityModule
            end
            if data.Title == profile.title and data.Keybind == profile.keybind then
                titleMatch = titleMatch or abilityModule
            end
        end
    end

    return titleMatch
end

local function getLiveAutoTargetCooldown(profile, tool)
    local controller = getAutoTargetToolController(tool)
    local abilityModule = getAutoTargetAbilityModule(controller, profile)
    if not controller or not abilityModule then
        return false, false
    end

    local serverNow = workspace:GetServerTimeNow()
    local abilityEnd = tonumber(rawget(controller.AbilitiesInCooldown, abilityModule)) or 0
    local slotEnd = tonumber(rawget(controller.AbilityCooldownsBySlot, profile.keybind)) or 0
    local beingUsed = rawget(controller.UsingAbilities, abilityModule) ~= nil
    return true, not beingUsed and serverNow >= abilityEnd and serverNow >= slotEnd
end

local function getNextAutoTargetCast()
    local profiles = getEquippedTargetedProfiles()
    local count = #profiles
    if count == 0 then
        return nil, nil
    end

    local now = os.clock()
    local tool = getHeldCombatTool()
    for offset = 1, count do
        local index = ((autoTargetAbilityCursor + offset - 1) % count) + 1
        local profile = profiles[index]
        if now >= (autoTargetAbilityNextAttempts[profile.id] or 0) then
            local hasLiveCooldown, liveReady = getLiveAutoTargetCooldown(profile, tool)
            local awaitingUntil = autoTargetAbilityAwaitingCooldown[profile.id]
            if awaitingUntil then
                if hasLiveCooldown and not liveReady then
                    -- The server acknowledged the cast and supplied its real
                    -- cooldown. From now on, wait only for that exact end-time.
                    autoTargetAbilityAwaitingCooldown[profile.id] = nil
                elseif now < awaitingUntil then
                    continue
                else
                    -- No cooldown arrived, so the input was most likely
                    -- rejected. Allow a quick retry without inventing a timer.
                    autoTargetAbilityAwaitingCooldown[profile.id] = nil
                end
            end
            local ready = hasLiveCooldown and liveReady
                or not hasLiveCooldown and now >= (autoTargetAbilityCooldowns[profile.id] or 0)
            if not ready then
                continue
            end
            local target = getClosestAbilityTarget(profile.range)
            if target then
                autoTargetAbilityCursor = index
                return profile, target
            end
        end
    end
    return nil, nil
end

local function getAutoTargetTeleportRange()
    if not autoTargetAbilitiesEnabled then
        return nil
    end
    local profiles = getEquippedTargetedProfiles()
    local result = nil
    for _, profile in ipairs(profiles) do
        result = math.max(result or 0, profile.range)
    end
    return result
end

local function setAutoTargetAbilitiesEnabled(enabled)
    autoTargetAbilitiesEnabled = enabled
    autoTargetAbilitiesGeneration = autoTargetAbilitiesGeneration + 1
    local generation = autoTargetAbilitiesGeneration

    if not enabled then
        releaseAutoTargetInput()
        autoTargetAbilityTarget = nil
        autoTargetAbilityProfile = nil
        stopAutoTargetCameraAim()
        return
    end

    task.spawn(function()
        while autoTargetAbilitiesEnabled and generation == autoTargetAbilitiesGeneration do
            if UserInputService:GetFocusedTextBox() then
                task.wait(0.1)
                continue
            end

            local profile, target = getNextAutoTargetCast()
            if not profile or not target then
                task.wait(0.05)
                continue
            end

            autoTargetAbilityProfile = profile
            autoTargetAbilityTarget = target
            local castStarted = startAutoTargetCameraAim()
            if castStarted then
                RunService.PostSimulation:Wait()
                castStarted = autoTargetAbilitiesEnabled
                    and generation == autoTargetAbilitiesGeneration
                    and isProfileStillHeld(profile)
                    and isValidAbilityTarget(autoTargetAbilityTarget, profile.range)
            end

            if castStarted then
                local pressedAt = os.clock()
                pressAutoTargetInput(profile)
                local finishAt = os.clock() + math.max(profile.hold, 0.12)
                repeat
                    autoTargetAbilityTarget = getClosestAbilityTarget(profile.range)
                    applyAntiFreeze()
                    RunService.Heartbeat:Wait()
                until not autoTargetAbilitiesEnabled
                    or generation ~= autoTargetAbilitiesGeneration
                    or not isProfileStillHeld(profile)
                    or os.clock() >= finishAt

                releaseAutoTargetInput()
                local releasedAt = os.clock()
                autoTargetAbilityNextAttempts[profile.id] = releasedAt + 0.04
                local hasLiveCooldown = getLiveAutoTargetCooldown(profile, getHeldCombatTool())
                if hasLiveCooldown then
                    -- Once the server replies, its exact end-time is used. If
                    -- the press was rejected, retry shortly instead of falsely
                    -- starting another complete local cooldown.
                    autoTargetAbilityCooldowns[profile.id] = nil
                    autoTargetAbilityAwaitingCooldown[profile.id] = releasedAt
                        + math.clamp(profile.cooldown * 0.5, 0.08, 0.45)
                else
                    -- Fallback for executors without getgc: instant abilities
                    -- start cooling at press; held abilities start on release.
                    local cooldownStartedAt = profile.hold > 0.15 and releasedAt or pressedAt
                    autoTargetAbilityCooldowns[profile.id] = cooldownStartedAt + math.max(profile.cooldown, 0.1)
                    autoTargetAbilityAwaitingCooldown[profile.id] = nil
                end
                local trackUntil = os.clock() + math.max(profile.trackAfterRelease or 0, 0)
                while autoTargetAbilitiesEnabled
                    and generation == autoTargetAbilitiesGeneration
                    and isProfileStillHeld(profile)
                    and os.clock() < trackUntil do
                    -- Some one-press abilities keep sampling mouse data after
                    -- activation (for example Phantom Barrage). Keep the
                    -- unrendered aim on the closest live mob for that window.
                    autoTargetAbilityTarget = getClosestAbilityTarget(profile.range)
                    applyAntiFreeze()
                    RunService.Heartbeat:Wait()
                end
                RunService.PostSimulation:Wait()
            end

            releaseAutoTargetInput()
            autoTargetAbilityTarget = nil
            autoTargetAbilityProfile = nil
            stopAutoTargetCameraAim()
            task.wait(0.04)
        end

        releaseAutoTargetInput()
        if generation == autoTargetAbilitiesGeneration then
            autoTargetAbilityTarget = nil
            autoTargetAbilityProfile = nil
            stopAutoTargetCameraAim()
        end
    end)
end

local function updateEsp()
    local camera = workspace.CurrentCamera
    local mobs = workspace:FindFirstChild("Mobs")
    if not camera or not mobs then
        for _, overlay in pairs(overlays) do
            hideOverlay(overlay)
        end
        return
    end

    local character = localPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    local origin = localRoot and localRoot.Position or camera.CFrame.Position
    local valid, closestModel = getMobTargets(mobs, origin)

    for model, data in pairs(valid) do
        updateOverlay(camera, model, data.humanoid, data.root, data.distance, model == closestModel)
    end

    for model in pairs(overlays) do
        if not valid[model] then
            removeOverlay(model)
        end
    end
end

local function stopEsp()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end

    for model in pairs(overlays) do
        removeOverlay(model)
    end
    if espGui then
        espGui:Destroy()
        espGui = nil
    end
end

local function setEspEnabled(enabled)
    espEnabled = enabled
    if espEnabled and not espConnection then
        getOrCreateGui()
        updateEsp()
        espConnection = RunService.RenderStepped:Connect(updateEsp)
    elseif not espEnabled then
        stopEsp()
    end
end

local function getASInfHazardKind(part)
    if not part:IsA("BasePart") then
        return nil
    end

    local lowerName = string.lower(part.Name)
    if lowerName == "warning" then
        return "Warning"
    end
    if string.find(lowerName, "damage", 1, true)
        or string.find(lowerName, "explosion", 1, true) then
        return "Damage"
    end
    return nil
end

local function getASInfHazardVelocity(part, now)
    local motion = asInfHazardMotion[part]
    local position = part.Position
    local reported = part.AssemblyLinearVelocity
    local observed = Vector3.zero

    if motion then
        local elapsed = now - motion.time
        if elapsed > 0.005 and elapsed < 0.5 then
            observed = (position - motion.position) / elapsed
        end
    else
        motion = {}
        asInfHazardMotion[part] = motion
    end

    local velocity = reported.Magnitude >= observed.Magnitude and reported or observed
    if velocity.Magnitude > 350 then
        velocity = velocity.Unit * 350
    end
    if motion.velocity then
        velocity = motion.velocity:Lerp(velocity, 0.55)
    end

    motion.position = position
    motion.time = now
    motion.velocity = velocity
    return velocity
end

local function getASInfHazards(referencePosition)
    local effects = workspace:FindFirstChild("Effects")
    if not effects then
        return {}
    end

    local now = os.clock()
    local hazards = {}
    for _, descendant in ipairs(effects:GetDescendants()) do
        local kind = getASInfHazardKind(descendant)
        if kind then
            local velocity = getASInfHazardVelocity(descendant, now)
            local position = descendant.Position
            local range = descendant.Size.Magnitude * 0.5
                + velocity.Magnitude * 1.2 + 180
            local referenceDistance = Vector2.new(
                position.X - referencePosition.X,
                position.Z - referencePosition.Z
            ).Magnitude
            local homeDistance = Vector2.new(
                position.X - asInfHomePosition.X,
                position.Z - asInfHomePosition.Z
            ).Magnitude
            if math.min(referenceDistance, homeDistance) <= range then
                table.insert(hazards, {
                    part = descendant,
                    kind = kind,
                    velocity = velocity,
                })
            end
        end
    end
    return hazards
end

local function getASInfProjectedHalfSize(cframe, size)
    local halfSize = size * 0.5
    local right = cframe.RightVector
    local up = cframe.UpVector
    local look = cframe.LookVector
    return Vector2.new(
        math.abs(right.X) * halfSize.X
            + math.abs(up.X) * halfSize.Y
            + math.abs(look.X) * halfSize.Z,
        math.abs(right.Z) * halfSize.X
            + math.abs(up.Z) * halfSize.Y
            + math.abs(look.Z) * halfSize.Z
    )
end

local function getASInfHazardClearance(point, hazard, predictionTime)
    local part = hazard.part
    if not part.Parent then
        return math.huge
    end

    local predictedCFrame = part.CFrame + hazard.velocity * predictionTime
    -- Use the full part size projected onto the fixed X/Z movement plane.
    -- This includes every axis of rotated, tilted, or vertical parts instead
    -- of treating their center point as the danger area.
    local halfSize = getASInfProjectedHalfSize(predictedCFrame, part.Size)
    local outsideX = math.abs(point.X - predictedCFrame.Position.X) - halfSize.X
    local outsideZ = math.abs(point.Z - predictedCFrame.Position.Z) - halfSize.Y
    local clearance
    if outsideX <= 0 and outsideZ <= 0 then
        clearance = math.max(outsideX, outsideZ)
    else
        clearance = Vector2.new(math.max(0, outsideX), math.max(0, outsideZ)).Magnitude
    end
    return clearance - asInfRootMargin
end

local asInfPredictionTimes = {0, 0.25, 0.55, 0.9}
local function getASInfFutureClearance(point, hazards)
    local minimum = math.huge
    for _, hazard in ipairs(hazards) do
        for _, predictionTime in ipairs(asInfPredictionTimes) do
            minimum = math.min(
                minimum,
                getASInfHazardClearance(point, hazard, predictionTime)
            )
        end
    end
    return minimum
end

local function getASInfRouteClearance(fromPoint, toPoint, hazards)
    local minimum = math.huge
    local horizontalDistance = Vector2.new(
        toPoint.X - fromPoint.X,
        toPoint.Z - fromPoint.Z
    ).Magnitude
    local travelTime = math.clamp(horizontalDistance / 80, 0.15, 1)
    -- Step zero is the character's unavoidable current position. Excluding it
    -- lets an escape route score better as it moves away from an active hitbox.
    for step = 1, 6 do
        local alpha = step / 6
        local point = fromPoint:Lerp(toPoint, alpha)
        local predictionTime = travelTime * alpha
        for _, hazard in ipairs(hazards) do
            minimum = math.min(
                minimum,
                getASInfHazardClearance(point, hazard, predictionTime)
            )
        end
    end
    return minimum
end

local function chooseASInfPosition(rootPosition, hazards)
    local current = Vector3.new(rootPosition.X, asInfHeight, rootPosition.Z)
    if #hazards == 0 then
        asInfDodgeTarget = nil
        return asInfHomePosition
    end

    local homeClearance = getASInfFutureClearance(asInfHomePosition, hazards)
    local currentClearance = getASInfFutureClearance(current, hazards)
    local routeHomeClearance = getASInfRouteClearance(current, asInfHomePosition, hazards)
    if math.min(homeClearance, currentClearance, routeHomeClearance) > asInfTriggerClearance then
        asInfDodgeTarget = nil
        return asInfHomePosition
    end

    local candidates = {current}
    if asInfDodgeTarget then
        table.insert(candidates, asInfDodgeTarget)
    end
    for _, radius in ipairs({24, 36, 52, 70, 90}) do
        for index = 0, 23 do
            local angle = index * math.pi * 2 / 24
            table.insert(candidates, asInfHomePosition + Vector3.new(
                math.cos(angle) * radius,
                0,
                math.sin(angle) * radius
            ))
        end
    end

    local bestPoint = current
    local bestClearance = -math.huge
    local bestScore = -math.huge
    for _, candidate in ipairs(candidates) do
        local futureClearance = getASInfFutureClearance(candidate, hazards)
        local routeClearance = getASInfRouteClearance(current, candidate, hazards)
        local clearance = futureClearance
        if currentClearance >= asInfSafeClearance or routeClearance < currentClearance then
            clearance = math.min(clearance, routeClearance)
        end
        local distanceFromHome = Vector2.new(
            candidate.X - asInfHomePosition.X,
            candidate.Z - asInfHomePosition.Z
        ).Magnitude
        local distanceFromCurrent = Vector2.new(
            candidate.X - current.X,
            candidate.Z - current.Z
        ).Magnitude
        local score = math.min(clearance, 80) * 10
            - distanceFromHome * 0.08
            - distanceFromCurrent * 0.02
        if clearance >= asInfSafeClearance then
            score = score + 1000
        end
        if asInfDodgeTarget and (candidate - asInfDodgeTarget).Magnitude < 1 then
            score = score + 8
        end

        if score > bestScore then
            bestScore = score
            bestClearance = clearance
            bestPoint = candidate
        end
    end

    if asInfDodgeTarget then
        local existingClearance = getASInfFutureClearance(asInfDodgeTarget, hazards)
        local existingRouteClearance = getASInfRouteClearance(current, asInfDodgeTarget, hazards)
        if currentClearance >= asInfSafeClearance or existingRouteClearance < currentClearance then
            existingClearance = math.min(existingClearance, existingRouteClearance)
        end
        if existingClearance >= asInfSafeClearance and existingClearance >= bestClearance - 4 then
            bestPoint = asInfDodgeTarget
        end
    end

    asInfDodgeTarget = Vector3.new(bestPoint.X, asInfHeight, bestPoint.Z)
    return asInfDodgeTarget
end

local function restoreASInfNoclip()
    for part in pairs(asInfNoclipParts) do
        if part.Parent and part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    asInfNoclipParts = setmetatable({}, {__mode = "k"})
end

local function updateASInfNoclip()
    local character = localPlayer.Character
    if not character then
        return
    end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.CanCollide then
            asInfNoclipParts[descendant] = true
            descendant.CanCollide = false
        end
    end
end

local function clearASInfMover()
    if asInfBodyPosition then
        asInfBodyPosition:Destroy()
        asInfBodyPosition = nil
    end
    if asInfRoot and asInfRoot.Parent then
        asInfRoot.Anchored = false
    end
    asInfRoot = nil
end

local function ensureASInfMover(root)
    if asInfRoot == root and asInfBodyPosition and asInfBodyPosition.Parent == root then
        return asInfBodyPosition
    end

    clearASInfMover()
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end

    root.Anchored = false
    local bodyPosition = Instance.new("BodyPosition")
    bodyPosition.Name = "ASInfPositionForce"
    bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPosition.P = 40000
    bodyPosition.D = 2500
    bodyPosition.Position = asInfHomePosition
    bodyPosition.Parent = root
    asInfRoot = root
    asInfBodyPosition = bodyPosition
    return bodyPosition
end

local function updateASInfPosition()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        clearASInfMover()
        return
    end

    local mover = ensureASInfMover(root)
    root.Anchored = false
    local currentPosition = root.Position
    if math.abs(currentPosition.Y - asInfHeight) > 0.01 then
        root.CFrame = CFrame.new(currentPosition.X, asInfHeight, currentPosition.Z)
            * root.CFrame.Rotation
    end
    local velocity = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local now = os.clock()
    if now - asInfLastDecision >= 0.05 then
        asInfLastDecision = now
        asInfDesiredPosition = chooseASInfPosition(root.Position, getASInfHazards(root.Position))
    end
    mover.Position = asInfDesiredPosition
end

local function setASInfEnabled(enabled)
    asInfEnabled = enabled and infiniteCloudDungeon ~= nil
    if asInfConnection then
        asInfConnection:Disconnect()
        asInfConnection = nil
    end
    if asInfNoclipConnection then
        asInfNoclipConnection:Disconnect()
        asInfNoclipConnection = nil
    end

    if not asInfEnabled then
        asInfDodgeTarget = nil
        asInfDesiredPosition = asInfHomePosition
        asInfLastDecision = 0
        clearASInfMover()
        restoreASInfNoclip()
        return
    end

    updateASInfNoclip()
    asInfDesiredPosition = asInfHomePosition
    asInfLastDecision = 0
    updateASInfPosition()
    asInfConnection = RunService.Heartbeat:Connect(function()
        if asInfEnabled then
            updateASInfPosition()
        end
    end)
    asInfNoclipConnection = RunService.Stepped:Connect(function()
        if asInfEnabled then
            updateASInfNoclip()
        end
    end)
end

local function tryTeleportToDistantMob()
    local character = localPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local mobs = workspace:FindFirstChild("Mobs")
    if not localRoot or not humanoid or humanoid.Health <= 0 or not mobs then
        return
    end

    local valid, closestModel, closestDistance = getMobTargets(mobs, localRoot.Position)
    local activeTeleportDistance = teleportDistance
    local abilityRange = getAutoTargetTeleportRange()
    if abilityRange then
        activeTeleportDistance = abilityRange
    elseif isGalaxyElementHeld() and isGalacticDestructionEquipped() then
        activeTeleportDistance = galacticDestructionRange
    end
    if closestDistance <= activeTeleportDistance or not closestModel then
        return
    end

    local target = valid[closestModel]
    if not teleportEnabled or character ~= localPlayer.Character or closestModel.Parent ~= mobs
        or target.root.Parent ~= closestModel or target.humanoid.Health <= 0 then
        return
    end

    local destination = target.root.Position + Vector3.new(0, 50, 0)
    localRoot.CFrame = CFrame.new(destination) * localRoot.CFrame.Rotation
end

local function setTeleportEnabled(enabled)
    teleportEnabled = enabled
    teleportGeneration = teleportGeneration + 1
    if not enabled then
        return
    end

    local generation = teleportGeneration
    task.spawn(function()
        while teleportEnabled and generation == teleportGeneration do
            tryTeleportToDistantMob()
            task.wait(0.25)
        end
    end)
end

local function getPotionCount()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    local main = playerGui and playerGui:FindFirstChild("Main")
    local playerBar = main and main:FindFirstChild("PlayerBar")
    local barMain = playerBar and playerBar:FindFirstChild("Main")
    local potionBar = barMain and barMain:FindFirstChild("PotionBar")
    if potionBar and not potionBar.Visible then
        -- The game hides this bar at zero, leaving its Amount text at a stale value.
        return 0, 3
    end
    local amount = potionBar and potionBar:FindFirstChild("Amount")
    if not amount or not amount:IsA("TextLabel") then
        return nil
    end

    local countText, capacityText = amount.Text:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
    local count, capacity = tonumber(countText), tonumber(capacityText)
    if not count or not capacity or capacity <= 0 then
        return nil
    end
    return count, capacity
end

local function tryCollectHealthPotion()
    if type(fireproximityprompt) ~= "function" then
        return
    end

    local count, capacity = getPotionCount()
    if not count or count >= math.min(capacity, 3) then
        return
    end

    local now = os.clock()
    if pendingPotionCount ~= nil then
        if count == pendingPotionCount and now - pendingPotionTime < 3 then
            return
        end
        pendingPotionCount = nil
    end

    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    local drops = camera and camera:FindFirstChild("Drops")
    if not root or not humanoid or humanoid.Health <= 0 or not drops then
        return
    end

    local closestPrompt = nil
    local closestDrop = nil
    local closestDistance = math.huge
    for _, drop in ipairs(drops:GetChildren()) do
        if drop:IsA("Model") and drop:FindFirstChild("Potion")
            and (potionNextAttempt[drop] or 0) <= now then
            local center = drop:FindFirstChild("Center")
            local prompt = center and center:FindFirstChildOfClass("ProximityPrompt")
            if center and center:IsA("BasePart") and prompt and prompt.Enabled
                and prompt.ObjectText == "Pickup Health Potion" then
                local distance = (center.Position - root.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestPrompt = prompt
                    closestDrop = drop
                end
            end
        end
    end

    if closestPrompt then
        potionNextAttempt[closestDrop] = now + 10
        local ok, err = pcall(fireproximityprompt, closestPrompt)
        if ok then
            pendingPotionCount = count
            pendingPotionTime = now
        else
            warn("[Elemental Dungeons] Health potion pickup failed: " .. tostring(err))
        end
    end
end

local function setPotionPickupEnabled(enabled)
    potionPickupEnabled = enabled
    potionPickupGeneration = potionPickupGeneration + 1
    pendingPotionCount = nil
    if not enabled then
        return
    end

    if type(fireproximityprompt) ~= "function" then
        warn("[Elemental Dungeons] Auto health potion pickup requires fireproximityprompt")
        return
    end

    local generation = potionPickupGeneration
    task.spawn(function()
        while potionPickupEnabled and generation == potionPickupGeneration do
            tryCollectHealthPotion()
            task.wait(0.5)
        end
    end)
end

local function findNearestLootChest(maxDistance, respectCooldown)
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return nil
    end

    local now = os.clock()
    local closestChest = nil
    local closestPrompt = nil
    local closestDistance = math.huge
    for _, chest in ipairs(workspace:GetChildren()) do
        if chest:IsA("Model") and chest.Name == "MobLootChest"
            and (not respectCooldown or (chestNextAttempt[chest] or 0) <= now) then
            local part = chest:FindFirstChild("Root")
            local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
            if part and part:IsA("BasePart") and prompt and prompt.Enabled
                and prompt.ObjectText == "Loot Chest" then
                local distance = (part.Position - root.Position).Magnitude
                if distance <= (maxDistance or math.max(0, prompt.MaxActivationDistance - 1))
                    and distance < closestDistance then
                    closestChest = chest
                    closestPrompt = prompt
                    closestDistance = distance
                end
            end
        end
    end

    return closestChest, closestPrompt, closestDistance
end

local function interactWithLootChest(prompt)
    if chestInteractionBusy then
        return false, "another chest interaction is running"
    end
    if not prompt or not prompt.Parent then
        return false, "chest prompt is gone"
    end

    chestInteractionBusy = true
    activeChestPrompt = prompt
    local originalHoldDuration = prompt.HoldDuration
    local ok, err = pcall(function()
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end)
    if prompt.Parent then
        pcall(function()
            prompt.HoldDuration = originalHoldDuration
        end)
    end
    if not ok then
        pcall(function()
            prompt:InputHoldEnd()
        end)
    end
    if activeChestPrompt == prompt then
        activeChestPrompt = nil
    end
    chestInteractionBusy = false
    return ok, err
end

local function getLootChestForPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled
        or prompt.ObjectText ~= "Loot Chest" then
        return nil
    end

    local part = prompt.Parent
    local chest = part and part.Parent
    if not part or not part:IsA("BasePart") or part.Name ~= "Root"
        or not chest or not chest:IsA("Model") or chest.Name ~= "MobLootChest"
        or chest.Parent ~= workspace then
        return nil
    end
    return chest, part
end

local function tryAutoOpenLootChest(prompt, generation)
    if not chestPickupEnabled or generation ~= chestPickupGeneration then
        return
    end

    while chestInteractionBusy and chestPickupEnabled and generation == chestPickupGeneration do
        task.wait(0.05)
    end
    if not chestPickupEnabled or generation ~= chestPickupGeneration then
        return
    end

    local chest, part = getLootChestForPrompt(prompt)
    if not chest then
        return
    end
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root or (part.Position - root.Position).Magnitude > prompt.MaxActivationDistance + 0.5 then
        return
    end

    local now = os.clock()
    if (chestNextAttempt[chest] or 0) > now then
        return
    end
    chestNextAttempt[chest] = now + 10
    local ok, err = interactWithLootChest(prompt)
    if not ok then
        warn("[Elemental Dungeons] Loot chest interaction failed: " .. tostring(err))
    end
end

local function setChestPickupEnabled(enabled)
    chestPickupEnabled = enabled
    chestPickupGeneration = chestPickupGeneration + 1
    if chestPromptShownConnection then
        chestPromptShownConnection:Disconnect()
        chestPromptShownConnection = nil
    end
    if not enabled then
        if activeChestPrompt then
            pcall(function()
                activeChestPrompt:InputHoldEnd()
            end)
            activeChestPrompt = nil
        end
        return
    end

    local generation = chestPickupGeneration
    chestPromptShownConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
        task.spawn(tryAutoOpenLootChest, prompt, generation)
    end)

    -- A prompt may already be visible when the toggle is switched on.
    local _, nearbyPrompt = findNearestLootChest(nil, true)
    if nearbyPrompt then
        task.spawn(tryAutoOpenLootChest, nearbyPrompt, generation)
    end
end

local function setElementStatus(message)
    if elementStatusLabel and elementStatusLabel.Parent then
        elementStatusLabel.Text = message
    end
end

local function createElementGui(className, parent, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function orbThumbnail(image)
    local assetId = type(image) == "string" and image:match("id=(%d+)")
    if not assetId and type(image) == "string" then
        assetId = image:match("rbxassetid://(%d+)")
    end
    return assetId and ("rbxthumb://type=Asset&id=" .. assetId .. "&w=150&h=150") or image
end

local function equipOwnedElement(entry, variant)
    if elementEquipBusy then
        return
    end
    local name = entry.name
    elementEquipBusy = true
    setElementStatus("Equipping " .. name .. (variant and (" / " .. variant) or "") .. "...")
    task.spawn(function()
        local ok, result = pcall(function()
            local services = game:GetService("ReplicatedStorage").ReplicatedStorage.Packages.Knit.Services
            local remotes = services.InventoryService.RF
            local remoteVariant = variant == "Normal" and nil or variant
            if variant then
                local changed = remotes.SetPurchasedElementVariant:InvokeServer(name, remoteVariant)
                if changed ~= true then
                    error("the game did not accept this variant")
                end
            end
            local swapName = variant and name or (entry.swapName or name)
            local swapVariant = entry.selectedVariant
            if variant then
                swapVariant = remoteVariant
            end
            local swapped = remotes.SwapElement:InvokeServer(swapName, swapVariant)
            if swapped ~= true then
                error("the game did not accept this element")
            end
        end)
        if ok then
            if variant then
                entry.selectedVariant = variant == "Normal" and nil or variant
            end
            setElementStatus("Equipped " .. name .. (variant and (" / " .. variant) or ""))
        else
            setElementStatus("Equip failed: " .. tostring(result))
        end
        elementEquipBusy = false
    end)
end

local function renderOwnedElements()
    if not elementListFrame or not elementListFrame.Parent then
        return
    end
    for _, child in ipairs(elementListFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    local query = elementSearchBox and string.lower(elementSearchBox.Text) or ""
    local visibleCount = 0
    for _, entry in ipairs(ownedElements) do
        if type(entry) == "table" and type(entry.name) == "string"
            and type(entry.variants) == "table" then
            local matches = query == "" or string.find(string.lower(entry.name), query, 1, true) ~= nil
            if not matches then
                for _, variant in ipairs(entry.variants) do
                    if string.find(string.lower(variant), query, 1, true) then
                        matches = true
                        break
                    end
                end
            end
            if matches then
                visibleCount = visibleCount + 1
                local rows = math.max(1, math.ceil(#entry.variants / 3))
                local height = math.max(89, 14 + rows * 27)
                local card = createElementGui("Frame", elementListFrame, {
                    Name = entry.name,
                    Size = UDim2.fromOffset(510, height),
                    BackgroundColor3 = Color3.fromRGB(27, 31, 38),
                    BorderSizePixel = 0,
                    LayoutOrder = visibleCount,
                })
                createElementGui("UICorner", card, {CornerRadius = UDim.new(0, 7)})
                local equipButton = createElementGui("TextButton", card, {
                    Name = "EquipElement",
                    Position = UDim2.fromOffset(8, 8),
                    Size = UDim2.fromOffset(172, height - 16),
                    BackgroundColor3 = Color3.fromRGB(35, 42, 52),
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = true,
                })
                createElementGui("UICorner", equipButton, {CornerRadius = UDim.new(0, 6)})
                createElementGui("ImageLabel", equipButton, {
                    Name = "Orb",
                    Position = UDim2.fromOffset(5, 5),
                    Size = UDim2.fromOffset(62, 62),
                    BackgroundTransparency = 1,
                    Image = orbThumbnail(entry.image) or "",
                    ScaleType = Enum.ScaleType.Fit,
                })
                createElementGui("TextLabel", equipButton, {
                    Position = UDim2.fromOffset(70, 9),
                    Size = UDim2.fromOffset(98, 27),
                    BackgroundTransparency = 1,
                    Text = entry.name,
                    TextColor3 = Color3.fromRGB(245, 247, 255),
                    Font = Enum.Font.GothamBold,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })
                createElementGui("TextLabel", equipButton, {
                    Position = UDim2.fromOffset(70, 36),
                    Size = UDim2.fromOffset(98, 20),
                    BackgroundTransparency = 1,
                    Text = "Equip element",
                    TextColor3 = Color3.fromRGB(134, 182, 215),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                equipButton.Activated:Connect(function()
                    equipOwnedElement(entry)
                end)

                for index, variant in ipairs(entry.variants) do
                    local column = (index - 1) % 3
                    local row = math.floor((index - 1) / 3)
                    local variantButton = createElementGui("TextButton", card, {
                        Name = variant,
                        Position = UDim2.fromOffset(188 + column * 105, 10 + row * 27),
                        Size = UDim2.fromOffset(99, 23),
                        BackgroundColor3 = query ~= "" and string.find(string.lower(variant), query, 1, true)
                            and Color3.fromRGB(26, 115, 171) or Color3.fromRGB(42, 57, 71),
                        BorderSizePixel = 0,
                        Text = variant,
                        TextColor3 = Color3.fromRGB(239, 246, 255),
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                    })
                    createElementGui("UICorner", variantButton, {CornerRadius = UDim.new(0, 5)})
                    variantButton.Activated:Connect(function()
                        equipOwnedElement(entry, variant)
                    end)
                end
            end
        end
    end

    if visibleCount == 0 then
        createElementGui("TextLabel", elementListFrame, {
            Size = UDim2.fromOffset(510, 45),
            BackgroundTransparency = 1,
            Text = #ownedElements == 0 and "No element data loaded. Use Scan elements."
                or "No elements or variants match your search.",
            TextColor3 = Color3.fromRGB(170, 179, 193),
            Font = Enum.Font.Gotham,
            TextSize = 13,
        })
    end
end

local function readOwnedElementsFromReplica(replica)
    local data = replica and replica.Data
    local main = type(data) == "table" and data.Main
    local miscItems = type(main) == "table" and main.MiscItems
    local items = type(main) == "table" and main.Items
    local purchased = type(miscItems) == "table" and miscItems.PurchasedElements
    local elementData = type(items) == "table" and items.Elements
    if type(purchased) ~= "table" or type(elementData) ~= "table" then
        return nil, "PlayerData is missing its element tables"
    end

    local ok, elementsModule = pcall(function()
        return require(game:GetService("ReplicatedStorage").ReplicatedStorage.SharedModules.ElementsModule)
    end)
    if not ok or type(elementsModule) ~= "table" then
        elementsModule = {}
    end

    local byName = {}
    for purchasedName, purchasedInfo in pairs(purchased) do
        if type(purchasedName) == "string" and purchasedInfo then
            local permanentPrefix = "Permanent "
            local permanent = purchasedName:sub(1, #permanentPrefix) == permanentPrefix
            local name = permanent and purchasedName:sub(#permanentPrefix + 1) or purchasedName
            local existing = byName[name]
            if not existing or (existing.permanent and not permanent) then
                local variants = {}
                local unlocked = type(elementData[name]) == "table" and elementData[name].UnlockedVariants
                local unlockedNames = {}
                if type(unlocked) == "table" then
                    for variant, enabled in pairs(unlocked) do
                        if enabled and variant ~= "None" then
                            table.insert(unlockedNames, tostring(variant))
                        end
                    end
                end
                table.sort(unlockedNames)
                if #unlockedNames > 0 then
                    table.insert(variants, "Normal")
                    for _, variant in ipairs(unlockedNames) do
                        table.insert(variants, variant)
                    end
                end

                local staticData = elementsModule[name]
                byName[name] = {
                    name = name,
                    image = type(staticData) == "table" and staticData.Icon or "",
                    variants = variants,
                    swapName = purchasedName,
                    permanent = permanent,
                    selectedVariant = type(purchasedInfo) == "table"
                        and (purchasedInfo.Variant or (purchasedInfo.Corrupted and "Corrupted")) or nil,
                }
            end
        end
    end

    local result = {}
    for _, entry in pairs(byName) do
        table.insert(result, entry)
    end
    table.sort(result, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return result
end

local function applyDirectElementReplica(replica)
    local result, err = readOwnedElementsFromReplica(replica)
    if not result then
        setElementStatus("Direct data failed: " .. tostring(err))
        return false
    end
    elementReplica = replica
    ownedElements = result
    renderOwnedElements()
    setElementStatus(tostring(#ownedElements) .. " owned elements loaded from PlayerData")
    return true
end

local function isElementUiScanActive(generation)
    return elementUiScanRunning and generation == elementUiScanGeneration
end

local function waitForElementUiScan(generation, timeout, predicate)
    local deadline = os.clock() + timeout
    repeat
        if not isElementUiScanActive(generation) then
            return false
        end
        local ok, result = pcall(predicate)
        if ok and result then
            return true
        end
        RunService.Heartbeat:Wait()
    until os.clock() >= deadline
    return false
end

local function activateElementUiButton(button, generation, scrollingFrame)
    if not button or not button.Parent or not button:IsA("GuiButton") then
        return false
    end

    if scrollingFrame then
        local current = scrollingFrame.CanvasPosition
        local targetY = current.Y + button.AbsolutePosition.Y - scrollingFrame.AbsolutePosition.Y
            - (scrollingFrame.AbsoluteSize.Y - button.AbsoluteSize.Y) * 0.5
        scrollingFrame.CanvasPosition = Vector2.new(current.X, math.max(0, targetY))
    end
    RunService.RenderStepped:Wait()
    RunService.RenderStepped:Wait()

    if not isElementUiScanActive(generation) or not button.Visible or button.AbsoluteSize.X < 2
        or button.AbsoluteSize.Y < 2 then
        return false
    end

    local previousSelectedObject = GuiService.SelectedObject
    local previousSelectable = button.Selectable
    local keyDown = false
    local ok = pcall(function()
        button.Selectable = true
        GuiService.SelectedObject = button
        RunService.RenderStepped:Wait()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        keyDown = true
        task.wait(0.04)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        keyDown = false
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
    end)
    if keyDown then
        pcall(function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
    end
    pcall(function()
        button.Selectable = previousSelectable
        if previousSelectedObject and previousSelectedObject.Parent
            and previousSelectedObject:IsDescendantOf(localPlayer.PlayerGui) then
            GuiService.SelectedObject = previousSelectedObject
        else
            GuiService.SelectedObject = nil
        end
    end)
    return ok
end

local function startElementUiScan()
    if elementUiScanRunning then
        setElementStatus("Element scan is already running")
        return
    end

    elementUiScanGeneration = elementUiScanGeneration + 1
    local generation = elementUiScanGeneration
    elementUiScanRunning = true
    setElementStatus("Starting UI navigation scan...")

    task.spawn(function()
        local elementsGui = nil
        local main = nil
        local originalMainVisible = false
        local originalGuiEnabled = true
        local originalDisplayOrder = 0
        local finalStatus = nil

        local ok, err = xpcall(function()
            local playerGui = localPlayer:WaitForChild("PlayerGui")
            elementsGui = playerGui:FindFirstChild("Elements")
            main = elementsGui and elementsGui:FindFirstChild("Main")
            local godFrame = main and main:FindFirstChild("GodFrame")
            local frontFrame = godFrame and godFrame:FindFirstChild("FrontFrame")
            local information = frontFrame and frontFrame:FindFirstChild("Information")
            local scrollingFrame = information and information:FindFirstChild("ScrollingFrame")
            local elementFrame = godFrame and godFrame:FindFirstChild("ElementFrame")
            if not elementsGui or not main or not scrollingFrame or not elementFrame then
                error("Elemental Collection UI was not found")
            end

            local okModule, elementsModule = pcall(function()
                return require(game:GetService("ReplicatedStorage").ReplicatedStorage.SharedModules.ElementsModule)
            end)
            if not okModule or type(elementsModule) ~= "table" then
                error("ElementsModule could not be read")
            end

            originalMainVisible = main.Visible
            originalGuiEnabled = elementsGui.Enabled
            originalDisplayOrder = elementsGui.DisplayOrder
            elementsGui.Enabled = true
            elementsGui.DisplayOrder = 1000000

            if main.Visible then
                main.Visible = false
                RunService.Heartbeat:Wait()
            end
            main.Visible = true

            local function isDiscoveredElementButton(button, name)
                local staticData = elementsModule[name]
                local nameLabel = button and button:FindFirstChild("ElementName")
                return button and button:IsA("GuiButton") and type(staticData) == "table"
                    and nameLabel and nameLabel:IsA("TextLabel") and nameLabel.Text == staticData.Name
            end

            local function getElementButton(name)
                local button = scrollingFrame:FindFirstChild(name)
                return isDiscoveredElementButton(button, name) and button or nil
            end

            if not waitForElementUiScan(generation, 4, function()
                for _, child in ipairs(scrollingFrame:GetChildren()) do
                    if isDiscoveredElementButton(child, child.Name) then
                        return child.AbsoluteSize.X > 1 and child.AbsoluteSize.Y > 1
                    end
                end
                return false
            end) then
                error("the collection did not finish loading")
            end

            local elementNames = {}
            for _, child in ipairs(scrollingFrame:GetChildren()) do
                if isDiscoveredElementButton(child, child.Name) then
                    table.insert(elementNames, child.Name)
                end
            end
            table.sort(elementNames, function(a, b)
                local buttonA = getElementButton(a)
                local buttonB = getElementButton(b)
                local orderA = buttonA and buttonA.LayoutOrder or 99
                local orderB = buttonB and buttonB.LayoutOrder or 99
                return orderA == orderB and string.lower(a) < string.lower(b) or orderA < orderB
            end)

            local scannedElements = {}
            local expectedOwnedColor = Color3.fromRGB(62, 255, 126)
            for index, elementName in ipairs(elementNames) do
                if not isElementUiScanActive(generation) then
                    error("scan cancelled")
                end
                setElementStatus(string.format("Scanning: %d/%d (%s)", index, #elementNames, elementName))

                local elementButton = getElementButton(elementName)
                if not activateElementUiButton(elementButton, generation, scrollingFrame) then
                    error("could not activate " .. elementName)
                end

                local elementNameLabel = elementFrame:FindFirstChild("ElementName")
                local equipButton = elementFrame:FindFirstChild("Frame")
                equipButton = equipButton and equipButton:FindFirstChild("Equip")
                local function detailsLoaded()
                    local staticData = elementsModule[elementName]
                    return elementNameLabel and staticData and elementNameLabel.Text == staticData.Name
                        and equipButton and equipButton.Visible
                end
                local loadedDetails = waitForElementUiScan(generation, 0.65, detailsLoaded)
                if not loadedDetails and activateElementUiButton(elementButton, generation, scrollingFrame) then
                    loadedDetails = waitForElementUiScan(generation, 1.25, detailsLoaded)
                end
                if not loadedDetails then
                    error("the details for " .. elementName .. " did not load")
                end

                local color = equipButton.BackgroundColor3
                local colorDifference = math.abs(color.R - expectedOwnedColor.R)
                    + math.abs(color.G - expectedOwnedColor.G)
                    + math.abs(color.B - expectedOwnedColor.B)
                if colorDifference < 0.08 then
                    local extras = elementFrame:FindFirstChild("Extras")
                    local selectedVariantLabel = extras and extras:FindFirstChild("isCorrupted")
                    local selectedVariant = selectedVariantLabel and selectedVariantLabel.Visible
                        and selectedVariantLabel.Text ~= "" and selectedVariantLabel.Text or nil
                    local permanentLabel = extras and extras:FindFirstChild("isPermOrb")
                    local permanent = permanentLabel and permanentLabel.Visible or false
                    local variants = {}

                    local frame = elementFrame:FindFirstChild("Frame")
                    local variantsButton = frame and frame:FindFirstChild("Variants")
                    if variantsButton and variantsButton.Visible then
                        local variantsTitle = variantsButton:FindFirstChild("TextLabel")
                        local function variantsOpened()
                            return variantsTitle and variantsTitle.Text == "Moves"
                        end
                        local openedVariants = activateElementUiButton(variantsButton, generation)
                            and waitForElementUiScan(generation, 0.65, variantsOpened)
                        if not openedVariants and activateElementUiButton(variantsButton, generation) then
                            openedVariants = waitForElementUiScan(generation, 1.25, variantsOpened)
                        end
                        if openedVariants then
                            local buttonsFrame = elementFrame:FindFirstChild("ButtonsFrame")
                            local buttonContainer = buttonsFrame and buttonsFrame:FindFirstChild("ButtonContainer")
                            if buttonContainer then
                                for _, variantButton in ipairs(buttonContainer:GetChildren()) do
                                    local variantName = variantButton:IsA("GuiButton")
                                        and variantButton:FindFirstChild("EquippedMoveName", true)
                                    local text = variantName and variantName.Text
                                    if variantName and variantButton.Visible and type(text) == "string" and text ~= "" then
                                        table.insert(variants, text)
                                    end
                                end
                            end
                        end
                    end

                    local uniqueVariants = {}
                    local hasVariant = {}
                    if table.find(variants, "Normal") then
                        table.insert(uniqueVariants, "Normal")
                        hasVariant.Normal = true
                    end
                    table.sort(variants, function(a, b)
                        return string.lower(a) < string.lower(b)
                    end)
                    for _, variant in ipairs(variants) do
                        if not hasVariant[variant] then
                            hasVariant[variant] = true
                            table.insert(uniqueVariants, variant)
                        end
                    end

                    local staticData = elementsModule[elementName]
                    table.insert(scannedElements, {
                        name = elementName,
                        image = type(staticData) == "table" and staticData.Icon or "",
                        variants = uniqueVariants,
                        swapName = permanent and ("Permanent " .. elementName) or elementName,
                        permanent = permanent,
                        selectedVariant = selectedVariant,
                    })
                end

                local backButton = elementFrame:FindFirstChild("Back")
                local function collectionReturned()
                    return getElementButton(elementName) ~= nil
                end
                local returned = activateElementUiButton(backButton, generation)
                    and waitForElementUiScan(generation, 0.65, collectionReturned)
                if not returned and activateElementUiButton(backButton, generation) then
                    returned = waitForElementUiScan(generation, 1.25, collectionReturned)
                end
                if not returned then
                    error("the collection did not return after " .. elementName)
                end
                task.wait(0.025)
            end

            if #scannedElements == 0 then
                error("no owned elements were detected")
            end
            table.sort(scannedElements, function(a, b)
                return string.lower(a.name) < string.lower(b.name)
            end)
            ownedElements = scannedElements
            renderOwnedElements()
            finalStatus = tostring(#ownedElements) .. " owned elements loaded by UI navigation"
        end, function(message)
            return tostring(message)
        end)

        if main and main.Parent then
            pcall(function()
                main.Visible = false
            end)
        end
        if elementsGui and elementsGui.Parent then
            pcall(function()
                elementsGui.DisplayOrder = originalDisplayOrder
                elementsGui.Enabled = originalGuiEnabled
                main.Visible = originalMainVisible
            end)
        end
        if generation == elementUiScanGeneration then
            elementUiScanRunning = false
            if ok then
                setElementStatus(finalStatus or "Element scan complete")
            else
                setElementStatus("Scan failed: " .. tostring(err))
            end
        end
    end)
end

environment.__ElementalDungeonsApplyPlayerData = applyDirectElementReplica

local function connectDirectElementData()
    setElementStatus("Connecting to PlayerData...")
    if type(elementReplicaController) ~= "table" then
        setElementStatus("Direct PlayerData is unavailable")
        return
    end

    if elementReplica and applyDirectElementReplica(elementReplica) then
        if not elementReplicaRawConnection and type(elementReplica.ListenToRaw) == "function" then
            elementReplicaRawConnection = elementReplica:ListenToRaw(function()
                task.defer(applyDirectElementReplica, elementReplica)
            end)
        end
        return
    end

    if not elementReplicaConnection then
        elementReplicaConnection = elementReplicaController.ReplicaOfClassCreated("PlayerData", function(replica)
            elementReplica = replica
            applyDirectElementReplica(replica)
            if replica and type(replica.ListenToRaw) == "function" then
                elementReplicaRawConnection = replica:ListenToRaw(function()
                    task.defer(applyDirectElementReplica, replica)
                end)
            end
        end)
    end
    setElementStatus("PlayerData unavailable here; use Scan elements")
end

environment.__ElementalDungeonsMobEspStop = function()
    espEnabled = false
    elementUiScanGeneration = elementUiScanGeneration + 1
    elementUiScanRunning = false
    if elementReplicaConnection then
        pcall(function()
            elementReplicaConnection:Disconnect()
        end)
        elementReplicaConnection = nil
    end
    if elementReplicaRawConnection then
        pcall(function()
            elementReplicaRawConnection:Disconnect()
        end)
        elementReplicaRawConnection = nil
    end
    stopEsp()
    setTeleportEnabled(false)
    setPotionPickupEnabled(false)
    setChestPickupEnabled(false)
    setGalacticDestructionEnabled(false)
    setAutoTargetAbilitiesEnabled(false)
    setAntiFreezeEnabled(false)
    setASInfEnabled(false)
    environment.__ElementalDungeonsApplyPlayerData = nil
    environment.__ElementalDungeonsMobEspStop = nil
end

local menuName = "Elemental"
CreateMenu(menuName)
CreateGroup(menuName, "Dungeon")
CreateTab(menuName, "Dungeon", "Mob ESP")
CreateTab(menuName, "Dungeon", "Misc")
if infiniteCloudDungeon then
    CreateTab(menuName, "Dungeon", "AS Inf")
end
CreateGroup(menuName, "Lobby")
CreateTab(menuName, "Lobby", "Owned Elements")

-- The hosted UI library can size a group before its final tab receives its
-- height. Correct the two groups locally so this script also works with that version.
task.defer(function()
    RunService.Heartbeat:Wait()
    local parent = resolveGuiParent()
    local ui = parent and parent:FindFirstChild("TomtomFHUI")
    local background = ui and ui:FindFirstChild("Background")
    local sidebar = background and background:FindFirstChild("SideBar")
    if not sidebar then
        return
    end

    for order, groupName in ipairs({"Dungeon", "Lobby"}) do
        local group = sidebar:FindFirstChild(groupName)
        if group and group:IsA("GuiObject") then
            local height = 0
            for _, child in ipairs(group:GetChildren()) do
                if child:IsA("GuiObject") then
                    height = height + child.Size.Y.Offset
                end
            end
            group.LayoutOrder = order
            group.Size = UDim2.new(0, 170, 0, math.max(25, height))
        end
    end
end)

CreateToggle("Mob ESP", "Mob ESP", function(state)
    setEspEnabled(state.Value)
end, espEnabled)

CreateToggle("Mob ESP", "Box", function(state)
    componentEnabled.Box = state.Value
end, componentEnabled.Box)

CreateToggle("Mob ESP", "Outline", function(state)
    componentEnabled.Outline = state.Value
end, componentEnabled.Outline)

CreateToggle("Mob ESP", "Tracer", function(state)
    componentEnabled.Tracer = state.Value
end, componentEnabled.Tracer)

CreateToggle("Mob ESP", "Tracer: Closest Only", function(state)
    componentEnabled.TracerClosestOnly = state.Value
end, componentEnabled.TracerClosestOnly)

CreateToggle("Mob ESP", "Name and Level", function(state)
    componentEnabled.Name = state.Value
end, componentEnabled.Name)

CreateToggle("Mob ESP", "Health Bar", function(state)
    componentEnabled.HealthBar = state.Value
end, componentEnabled.HealthBar)

CreateToggle("Mob ESP", "Distance", function(state)
    componentEnabled.Distance = state.Value
end, componentEnabled.Distance)

CreateToggle("Misc", teleportToggleLabel, function(state)
    setTeleportEnabled(state.Value)
end, teleportEnabled)

CreateInput("Misc", teleportDistanceLabel, tostring(teleportDistance), "Set", function(textBox)
    teleportDistance = parseTeleportDistance(textBox.Text) or teleportDistance
    textBox.Text = tostring(teleportDistance)
    SetConfigValue("Misc", teleportDistanceLabel, textBox.Text)
end)

CreateToggle("Misc", "Auto Health Potion Pickup", function(state)
    setPotionPickupEnabled(state.Value)
end, potionPickupEnabled)

CreateToggle("Misc", "Auto Loot Chests (Nearby)", function(state)
    setChestPickupEnabled(state.Value)
end, chestPickupEnabled)

CreateToggle("Misc", "Auto Target Abilities", function(state)
    setAutoTargetAbilitiesEnabled(state.Value)
end, autoTargetAbilitiesEnabled)

CreateToggle("Misc", "Anti Freeze", function(state)
    setAntiFreezeEnabled(state.Value)
end, antiFreezeEnabled)

if infiniteCloudDungeon then
    CreateToggle("AS Inf", "Auto Dodge + Position", function(state)
        setASInfEnabled(state.Value)
    end, asInfEnabled)
end

local elementContainer = CreateContainer("Owned Elements", 345)
elementContainer.Size = UDim2.fromOffset(530, 345)

elementSearchBox = createElementGui("TextBox", elementContainer, {
    Name = "ElementSearch",
    Position = UDim2.fromOffset(10, 10),
    Size = UDim2.fromOffset(350, 32),
    BackgroundColor3 = Color3.fromRGB(31, 35, 43),
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Search element or variant...",
    PlaceholderColor3 = Color3.fromRGB(140, 150, 165),
    TextColor3 = Color3.fromRGB(245, 247, 255),
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
})
createElementGui("UICorner", elementSearchBox, {CornerRadius = UDim.new(0, 6)})
createElementGui("UIPadding", elementSearchBox, {PaddingLeft = UDim.new(0, 9)})

local refreshButton = createElementGui("TextButton", elementContainer, {
    Name = "ElementScan",
    Position = UDim2.fromOffset(370, 10),
    Size = UDim2.fromOffset(150, 32),
    BackgroundColor3 = Color3.fromRGB(0, 115, 200),
    BorderSizePixel = 0,
    Text = "Scan elements",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
})
createElementGui("UICorner", refreshButton, {CornerRadius = UDim.new(0, 6)})

elementStatusLabel = createElementGui("TextLabel", elementContainer, {
    Name = "ElementStatus",
    Position = UDim2.fromOffset(10, 47),
    Size = UDim2.fromOffset(510, 25),
    BackgroundTransparency = 1,
    Text = "Connecting directly to PlayerData...",
    TextColor3 = Color3.fromRGB(165, 180, 195),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

elementListFrame = createElementGui("ScrollingFrame", elementContainer, {
    Name = "ElementList",
    Position = UDim2.fromOffset(10, 77),
    Size = UDim2.fromOffset(515, 258),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local elementListLayout = createElementGui("UIListLayout", elementListFrame, {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
elementListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if elementListFrame and elementListFrame.Parent then
        elementListFrame.CanvasSize = UDim2.fromOffset(0, elementListLayout.AbsoluteContentSize.Y + 4)
    end
end)
elementSearchBox:GetPropertyChangedSignal("Text"):Connect(renderOwnedElements)
refreshButton.Activated:Connect(startElementUiScan)
renderOwnedElements()
task.defer(connectDirectElementData)

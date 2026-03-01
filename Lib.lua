local LibName = "TomtomFHUI"

for _,v in game.Players.LocalPlayer.PlayerGui:GetChildren() do
    if v.Name == LibName then
        v:Destroy()
    end
end

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Config System
local ConfigFileName = "TomtomFHUI_" .. tostring(game.PlaceId) .. ".json"
Config = {}

-- Check if filesystem is available
local hasFileSystem = type(isfolder) == "function" and type(makefolder) == "function" and 
                      type(isfile) == "function" and type(readfile) == "function" and 
                      type(writefile) == "function"

local function ensureConfigTable()
    if type(Config) ~= "table" then
        Config = {}
    end
    return Config
end

local function ensureTabConfig(tabName)
    local config = ensureConfigTable()
    if type(config[tabName]) ~= "table" then
        config[tabName] = {}
    end
    return config[tabName]
end

function GetConfigValue(tabName, entryName)
    local config = ensureConfigTable()

    if type(config[tabName]) == "table" and config[tabName][entryName] ~= nil then
        return config[tabName][entryName]
    end

    return nil
end

function SetConfigValue(tabName, entryName, value)
    local tabConfig = ensureTabConfig(tabName)
    tabConfig[entryName] = value

    return SaveConfig()
end

local function isArrayTable(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

local function getSortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function encodePrettyJson(value, indent)
    local valueType = type(value)

    if valueType == "nil" then
        return "null"
    end

    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return HttpService:JSONEncode(value)
    end

    if valueType ~= "table" then
        return "null"
    end

    local nextIndent = indent .. "  "

    if isArrayTable(value) then
        if #value == 0 then
            return "[]"
        end

        local items = {}
        for index = 1, #value do
            table.insert(items, nextIndent .. encodePrettyJson(value[index], nextIndent))
        end

        return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
    end

    local keys = getSortedKeys(value)
    if #keys == 0 then
        return "{}"
    end

    local properties = {}
    for _, key in ipairs(keys) do
        local keyJson = HttpService:JSONEncode(tostring(key))
        local valueJson = encodePrettyJson(value[key], nextIndent)
        table.insert(properties, nextIndent .. keyJson .. ": " .. valueJson)
    end

    return "{\n" .. table.concat(properties, ",\n") .. "\n" .. indent .. "}"
end

local function LoadConfig()
    if not hasFileSystem then
        return false
    end
    
    local success, result = pcall(function()
        if not isfolder("TomtomFHUI") then
            makefolder("TomtomFHUI")
        end
        
        local filePath = "TomtomFHUI/" .. ConfigFileName
        if isfile(filePath) then
            local data = readfile(filePath)
            local decoded = HttpService:JSONDecode(data)
            return decoded
        end
        return nil
    end)
    
    if success and result then
        Config = result
        return true
    end
    return false
end

function SaveConfig()
    if not hasFileSystem then
        return false
    end
    
    local success = pcall(function()
        if not isfolder("TomtomFHUI") then
            makefolder("TomtomFHUI")
        end
        
        local filePath = "TomtomFHUI/" .. ConfigFileName
        local data = encodePrettyJson(Config, "")
        writefile(filePath, data)
    end)
    return success
end

-- Load config on library load
LoadConfig()

local isVisible = true
local Groups = {}
local Tabs = {}
local Menus = {}
local Sidebars = {}
local PageLayouts = {}
local TabButtons = {}  -- Store tab buttons for highlighting
local TabHighlights = {}  -- Store highlight frames for each menu
local SetActiveTabHandlers = {}  -- Store active tab update handlers per menu
local CurrentPageConnections = {}  -- Track CurrentPage listeners per menu

function CreateMenu(menuName)
    local UI = Instance.new("ScreenGui", game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
    UI.Name = LibName
    UI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Function to reset all hover states in the UI
    local function resetAllHoverStates()
        local function resetElementHoverState(element)
            -- Reset button colors to their default state
            if element:IsA("TextButton") then
                local originalColor = element:GetAttribute("OriginalBackgroundColor")
                if originalColor then
                    element.BackgroundColor3 = originalColor
                else
                    element.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
                end
            end
            
            -- Recursively reset children
            for _, child in ipairs(element:GetChildren()) do
                resetElementHoverState(child)
            end
        end
        
        resetElementHoverState(Background)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
    
        if input.KeyCode == Enum.KeyCode.LeftControl then
            isVisible = not isVisible
            UI.Enabled = isVisible
            
            -- Reset hover states when visibility changes
            if not isVisible or isVisible then
                task.defer(resetAllHoverStates)
            end
        end
    end)

    local Background = Instance.new("CanvasGroup", UI)
    Background.BorderSizePixel = 0
    Background.BackgroundColor3 = Color3.fromRGB(26, 26, 31)
    Background.Size = UDim2.new(0, 750, 0, 450)
    Background.Position = UDim2.new(0.5, -375, 0.5, -225)
    Background.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Background.Name = "Background"
    Background.BackgroundTransparency = 0.2

    local MainTitle = Instance.new("TextLabel", Background)
    MainTitle.BorderSizePixel = 0
    MainTitle.TextSize = 25
    MainTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MainTitle.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    MainTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainTitle.BackgroundTransparency = 1
    MainTitle.Size = UDim2.new(0, 130, 0, 50)
    MainTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
    MainTitle.Text = menuName
    MainTitle.Name = menuName
    MainTitle.Position = UDim2.new(0, 20, 0, 0)

    local UIDragDetector = Instance.new("UIDragDetector", Background)

    local UICorner1 = Instance.new("UICorner", Background)

    local UIStroke1 = Instance.new("UIStroke", Background)
    UIStroke1.Thickness = 2
    UIStroke1.Color = Color3.fromRGB(46, 46, 46)

    local Pages = Instance.new("Frame", Background)
    Pages.BorderSizePixel = 0
    Pages.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    Pages.ClipsDescendants = true
    Pages.Size = UDim2.new(0, 580, 0, 450)
    Pages.Position = UDim2.new(0, 170, 0, 0)
    Pages.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Pages.Name = "Pages"

    local UIPageLayout = Instance.new("UIPageLayout", Pages)
    UIPageLayout.EasingStyle = Enum.EasingStyle.Circular
    UIPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIPageLayout.TweenTime = 0.5

    local SideBar = Instance.new("ScrollingFrame", Background)
    SideBar.ScrollingDirection = Enum.ScrollingDirection.Y
    SideBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    SideBar.ScrollBarThickness = 5
    SideBar.ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200)
    SideBar.BorderSizePixel = 0
    SideBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SideBar.Size = UDim2.new(0, 170, 0, 400)
    SideBar.Position = UDim2.new(0, 0, 0, 50)
    SideBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
    SideBar.Name = "SideBar"
    SideBar.BackgroundTransparency = 1
    SideBar.ClipsDescendants = true

    -- Create highlight frame for tab selection (parented to Background, not SideBar)
    local TabHighlight = Instance.new("Frame", Background)
    TabHighlight.Name = "TabHighlight"
    TabHighlight.Size = UDim2.new(0, 170, 0, 25)
    TabHighlight.Position = UDim2.new(0, 0, 0, 50)
    TabHighlight.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
    TabHighlight.BackgroundTransparency = 0.85
    TabHighlight.BorderSizePixel = 0
    TabHighlight.ZIndex = 0
    TabHighlight.Visible = false
    Instance.new("UICorner", TabHighlight).CornerRadius = UDim.new(0, 6)

    local UIListLayout2 = Instance.new("UIListLayout", SideBar)
    UIListLayout2.Padding = UDim.new(0, 15)
    UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder

    local function updateCanvasSize()
        local totalHeight = 0
        for _, child in ipairs(SideBar:GetChildren()) do
            if child:IsA("GuiObject") then
                totalHeight = totalHeight + child.Size.Y.Offset + UIListLayout2.Padding.Offset
            end
        end
        SideBar.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    SideBar.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("Size"):Connect(updateCanvasSize)
        end
        updateCanvasSize()
    end)
    
    for _, child in ipairs(SideBar:GetChildren()) do
        if child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("Size"):Connect(updateCanvasSize)
        end
    end
    
    updateCanvasSize()    

    Sidebars[menuName] = SideBar
    Menus[menuName] = Pages
    PageLayouts[menuName] = UIPageLayout
    TabButtons[menuName] = {}  -- Initialize tab buttons storage for this menu
    TabHighlights[menuName] = TabHighlight  -- Store highlight frame reference
end

function CreateGroup(menuName, groupName)
    local sidebar = Sidebars[menuName]
    if not sidebar then return end
    
    local group = Instance.new("Frame", sidebar)
    group.BorderSizePixel = 0
    group.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    group.Size = UDim2.new(0, 170, 0, 80)
    group.BackgroundTransparency = 1
    group.Name = groupName

    local title = Instance.new("TextLabel", group)
    title.BorderSizePixel = 0
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    title.TextColor3 = Color3.fromRGB(151, 151, 151)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0, 125, 0, 25)
    title.Text = groupName
    title.Position = UDim2.new(0, 10, 0, 0)

    local layout = Instance.new("UIListLayout", group)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function updateGroupSize()
        local totalHeight = -10
        for _, child in ipairs(group:GetChildren()) do
            if child:IsA("GuiObject") then
                totalHeight = totalHeight + child.Size.Y.Offset + layout.Padding.Offset
            end
        end
        group.Size = UDim2.new(0, 170, 0, totalHeight)
    end
    
    group.ChildAdded:Connect(updateGroupSize)
    
    updateGroupSize()

    Groups[groupName] = group
end

function CreateTab(menuName, groupName, tabName)
    local pageLayout = PageLayouts[menuName]
    local menu = Menus[menuName]
    local group = Groups[groupName]
    local highlight = TabHighlights[menuName]
    if not group and menu and pageLayout then return end

    local button = Instance.new("TextButton", group)
    button.BorderSizePixel = 0
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.TextSize = 15
    button.BackgroundTransparency = 1
    button.Size = UDim2.new(0, 100, 0, 25)
    button.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    button.Text = tabName
    button.Name = tabName
    button.ZIndex = 2
    button.AutoButtonColor = false  -- Disable automatic hover effects

    -- Manual hover state handling for tab buttons
    button.MouseEnter:Connect(function()
        if isVisible then
            TweenService:Create(button, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(100, 180, 255)}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if button.TextColor3 ~= Color3.fromRGB(0, 170, 255) then  -- Don't reset if it's the active tab
            TweenService:Create(button, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        end
    end)

    local page = Instance.new("Frame", menu)
    page.BorderSizePixel = 0
    page.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
    page.Size = UDim2.new(0, 580, 0, 450)
    page.Name = tabName

    local title = Instance.new("TextLabel", page)
    title.BorderSizePixel = 0
    title.TextSize = 25
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0, 540, 0, 50)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    title.Text = tabName

    local tab = Instance.new("ScrollingFrame", page)
    tab.ScrollingDirection = Enum.ScrollingDirection.Y
    tab.BorderSizePixel = 0
    tab.CanvasSize = UDim2.new(0, 0, 0, 0)
    tab.Size = UDim2.new(0, 540, 0, 380)
    tab.Position = UDim2.new(0, 20, 0, 50)
    tab.ScrollBarThickness = 5
    tab.ScrollBarImageColor3 = Color3.fromRGB(0, 115, 200)
    tab.BackgroundTransparency = 1
    tab.Name = tabName

    local layout = Instance.new("UIListLayout", tab)
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function updateTabCanvasSize()
        local totalHeight = 0
        for _, child in ipairs(tab:GetChildren()) do
            if child:IsA("GuiObject") then
                totalHeight = totalHeight + child.Size.Y.Offset + layout.Padding.Offset
            end
        end
        tab.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    tab.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("Size"):Connect(updateTabCanvasSize)
        end
        updateTabCanvasSize()
    end)
    
    for _, child in ipairs(tab:GetChildren()) do
        if child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("Size"):Connect(updateTabCanvasSize)
        end
    end
    
    updateTabCanvasSize()    

    -- Store button reference for highlighting
    table.insert(TabButtons[menuName], button)
    
    -- Function to update all tab button highlights
    local function setActiveTab(activeButton)
        if not highlight then return end
        
        -- Wait a frame for layout to update
        task.wait()
        
        -- Get absolute positions
        local backgroundPos = activeButton.Parent.Parent.Parent.AbsolutePosition.Y  -- Background's Y position
        local buttonPos = activeButton.AbsolutePosition.Y  -- Button's absolute Y position
        
        -- Calculate position relative to Background
        local relativeY = buttonPos - backgroundPos
        
        -- Show highlight if hidden
        if not highlight.Visible then
            highlight.Visible = true
            highlight.Position = UDim2.new(0, 0, 0, relativeY)
        end
        
        -- Tween highlight to the active button position
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local tween = TweenService:Create(highlight, tweenInfo, {
            Position = UDim2.new(0, 0, 0, relativeY)
        })
        tween:Play()
        
        -- Update text colors
        for _, btn in ipairs(TabButtons[menuName]) do
            if btn == activeButton then
                btn.TextColor3 = Color3.fromRGB(0, 170, 255)
            else
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end

    SetActiveTabHandlers[menuName] = setActiveTab

    if not CurrentPageConnections[menuName] then
        CurrentPageConnections[menuName] = pageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(function()
            local currentPage = pageLayout.CurrentPage
            local activeHandler = SetActiveTabHandlers[menuName]
            if not currentPage or not activeHandler then return end

            for _, btn in ipairs(TabButtons[menuName]) do
                if btn.Name == currentPage.Name then
                    activeHandler(btn)
                    break
                end
            end
        end)
    end

    button.MouseButton1Click:Connect(function()
        pageLayout:JumpTo(page)
        setActiveTab(button)
    end)
    
    -- If this is the first tab, make it active by default
    if #TabButtons[menuName] == 1 then
        task.defer(function()
            task.wait(0.1)  -- Wait a bit longer for layout
            setActiveTab(button)
        end)
    end

    Tabs[tabName] = tab
end

function CreateToggle(tabName, toggleText, actionFunction, initialState)
    local tab = Tabs[tabName]
    if not tab then return end

    -- Check config for saved state
    local savedState = GetConfigValue(tabName, toggleText)
    if savedState ~= nil then
        initialState = savedState
    end

    local button = Instance.new("TextButton", tab)
    button.BorderSizePixel = 0
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 15
    button.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    button.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    button.Size = UDim2.new(0, 550, 0, 50)
    button.Text = ""
    button.Name = toggleText
    button.Selectable = false
    button.AutoButtonColor = false  -- Disable automatic hover effects

    Instance.new("UICorner", button)

    local text = Instance.new("TextLabel", button)
    text.BorderSizePixel = 0
    text.TextSize = 15
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(0, 500, 0, 35)
    text.Position = UDim2.new(0, 20, 0, 7)
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    text.Text = toggleText

    local indicator = Instance.new("Frame", button)
    indicator.Size = UDim2.new(0, 15, 0, 15)
    indicator.Position = UDim2.new(0, 475, 0, 17)
    indicator.BackgroundColor3 = Color3.fromRGB(116, 116, 116)
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    local bg = Instance.new("Frame", button)
    bg.Size = UDim2.new(0, 40, 0, 15)
    bg.Position = UDim2.new(0, 475, 0, 17)
    bg.BackgroundColor3 = Color3.fromRGB(116, 116, 116)
    bg.BackgroundTransparency = 0.8
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local state = Instance.new("BoolValue", button)
    state.Name = "State"
    state.Value = initialState or false

    if savedState == nil then
        SetConfigValue(tabName, toggleText, state.Value)
    end

    local function updateVisuals()
        local color = state.Value and Color3.fromRGB(0, 115, 200) or Color3.fromRGB(116, 116, 116)
        local pos = state.Value and UDim2.new(0, 500, 0, 17) or UDim2.new(0, 475, 0, 17)
        TweenService:Create(indicator, TweenInfo.new(0.25), {Position = pos, BackgroundColor3 = color}):Play()
        TweenService:Create(bg, TweenInfo.new(0.25), {BackgroundColor3 = color}):Play()
    end

    if state.Value then
        updateVisuals()
        task.spawn(function()
            actionFunction(state, button)
        end)
    end

    -- Manual hover state handling
    button.MouseEnter:Connect(function()
        if isVisible then
            TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(18, 18, 21)}):Play()
    end)

    button.MouseButton1Click:Connect(function()
        state.Value = not state.Value
        updateVisuals()
        
        -- Save to config
        SetConfigValue(tabName, toggleText, state.Value)
    
        task.spawn(function()
            actionFunction(state, button)
        end)
    end)    
end

function CreateButton(tabName, buttonText, actionFunction)
    local tab = Tabs[tabName]
    if not tab then return end
    local button = Instance.new("TextButton", tab)
	button.Active = false
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 15
	button.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	button.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	button.Selectable = false
	button.Size = UDim2.new(0, 550, 0, 50)
	button.Name = buttonText
	button.BorderColor3 = Color3.fromRGB(0, 0, 0)
	button.Text = ""
	button.AutoButtonColor = false  -- Disable automatic hover effects

	local corner = Instance.new("UICorner", button)

	local label = Instance.new("TextLabel", button)
	label.TextWrapped = true
	label.BorderSizePixel = 0
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 500, 0, 35)
	label.BorderColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = buttonText
	label.Name = buttonText
	label.Position = UDim2.new(0, 20, 0, 7)

	-- Manual hover state handling
	button.MouseEnter:Connect(function()
		if isVisible then
			TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 40)}):Play()
		end
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(18, 18, 21)}):Play()
	end)

	button.MouseButton1Click:Connect(function()
        task.spawn(function()
            actionFunction()
        end)
	end)
	
	return button
end

function CreateLabel(tabName, labelText)
    local tab = Tabs[tabName]
    if not tab then return end
    local frame = Instance.new("Frame", tab)
	frame.Active = false
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	frame.Selectable = false
	frame.Size = UDim2.new(0, 550, 0, 50)
	frame.Name = labelText
	frame.BorderColor3 = Color3.fromRGB(0, 0, 0)

	local corner = Instance.new("UICorner", frame)

	local label = Instance.new("TextLabel", frame)
	label.TextWrapped = true
	label.BorderSizePixel = 0
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 500, 0, 35)
	label.BorderColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = labelText
	label.Name = labelText
	label.Position = UDim2.new(0, 20, 0, 7)
end

function CreateValueLabel(tabName, labelText)
    local tab = Tabs[tabName]
    if not tab then return end

    local frame = Instance.new("Frame", tab)
    frame.Active = false
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    frame.Selectable = false
    frame.Size = UDim2.new(0, 550, 0, 50)
    frame.Name = labelText
    frame.BorderColor3 = Color3.fromRGB(0, 0, 0)

    Instance.new("UICorner", frame)

    local label = Instance.new("TextLabel", frame)
    label.TextWrapped = true
    label.BorderSizePixel = 0
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 500, 0, 35)
    label.BorderColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = labelText
    label.Name = labelText
    label.Position = UDim2.new(0, 20, 0, 7)

    return label, frame
end

function CreateContainer(tabName, height, transparent)
    local tab = Tabs[tabName]
    if not tab then return end

    local frame = Instance.new("Frame", tab)
    frame.Active = false
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    frame.BackgroundTransparency = transparent and 1 or 0
    frame.Selectable = false
    frame.Size = UDim2.new(0, 550, 0, height or 50)
    frame.BorderColor3 = Color3.fromRGB(0, 0, 0)

    Instance.new("UICorner", frame)

    return frame
end

function CreateInput(tabName, labelText, defaultText, buttonText, actionFunction)
    local tab = Tabs[tabName]
    if not tab then return end

    -- Check config for saved value
    local savedText = GetConfigValue(tabName, labelText)
    if savedText ~= nil then
        defaultText = savedText
    end

    -- Auto-save default value if no saved config exists
    if savedText == nil and defaultText ~= nil then
        SetConfigValue(tabName, labelText, defaultText)
    end

    local frame = Instance.new("Frame", tab)
    frame.Active = false
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    frame.Selectable = false
    frame.Size = UDim2.new(0, 550, 0, 50)
    frame.BorderColor3 = Color3.fromRGB(0, 0, 0)

    Instance.new("UICorner", frame)

    local label = Instance.new("TextLabel", frame)
    label.BorderSizePixel = 0
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 200, 0, 35)
    label.Position = UDim2.new(0, 20, 0, 7)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    label.Text = labelText

    local textBox = Instance.new("TextBox", frame)
    textBox.BorderSizePixel = 0
    textBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    textBox.TextSize = 15
    textBox.Size = UDim2.new(0, 140, 0, 32)
    textBox.Position = UDim2.new(0, 220, 0, 9)
    textBox.Text = defaultText or ""
    textBox.ClearTextOnFocus = false

    Instance.new("UICorner", textBox)

    local button = Instance.new("TextButton", frame)
    button.BorderSizePixel = 0
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 15
    button.BackgroundColor3 = Color3.fromRGB(0, 115, 200)
    button.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    button.Size = UDim2.new(0, 120, 0, 32)
    button.Position = UDim2.new(0, 370, 0, 9)
    button.Text = buttonText or "Apply"
    button.AutoButtonColor = false  -- Disable automatic hover effects

    Instance.new("UICorner", button)

    -- Manual hover state handling for input button
    button.MouseEnter:Connect(function()
        if isVisible then
            TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 140, 230)}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 115, 200)}):Play()
    end)

    button.MouseButton1Click:Connect(function()
        -- Save to config
        SetConfigValue(tabName, labelText, textBox.Text)
        
        task.spawn(function()
            actionFunction(textBox, button, frame)
        end)
    end)
    
    return textBox, button, frame
end

function DestroyMenu(menuName)
    local menuGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild(LibName)
    if menuGui then
        menuGui:Destroy()
    end
    Menus[menuName] = nil
    Sidebars[menuName] = nil
    PageLayouts[menuName] = nil
    TabButtons[menuName] = nil
    TabHighlights[menuName] = nil
    SetActiveTabHandlers[menuName] = nil
    if CurrentPageConnections[menuName] then
        CurrentPageConnections[menuName]:Disconnect()
        CurrentPageConnections[menuName] = nil
    end
end

--[[

TomtomFH UI Library Documentation

FEATURES:
- Automatic config saving per game (saves toggle states and input values)
- Config files stored as: workspace/TomtomFHUI/TomtomFHUI_{PlaceId}.json
- Settings load automatically on script restart
- Press Left Ctrl to toggle UI visibility

USAGE:

Menu:
CreateMenu("Menu Name")

Group:
CreateGroup("Menu Name", "Group Text")

Tab:
CreateTab("Menu Name", "Group Text", "Tab Name")

Toggle (with automatic config saving):
CreateToggle("Tab Name", "Toggle Text", function(state)
    if state.Value then
        print("Toggle Enabled")
    else
        print("Toggle Disabled")
    end
end, false)  -- false = initial state (optional, defaults to false)

Button:
CreateButton("Tab Name", "Button Text", function()
    print("Button Activated")
end)

Input (with automatic config saving):
CreateInput("Tab Name", "Label Text", "Default Value", "Button Text", function(textBox, button, frame)
    local value = textBox.Text
    print("Input value:", value)
end)

Label:
CreateLabel("Tab Name", "Label Text")

Value Label (for displaying dynamic values):
CreateValueLabel("Tab Name", "Initial Text")

Container:
CreateContainer("Tab Name")

Destroy Menu:
DestroyMenu("Menu Name")

]]--

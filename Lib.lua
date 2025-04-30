local LibName = "TomtomFHUI"

for _,v in game.Players.LocalPlayer.PlayerGui:GetChildren() do
    if v.Name == LibName then
        v:Destroy()
    end
end

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local isVisible = true
local Groups = {}
local Tabs = {}
local Menus = {}
local Sidebars = {}
local PageLayouts = {}

local function CreateMenu(menuName)
    local UI = Instance.new("ScreenGui", game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
    UI.Name = LibName
    UI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
    
        if input.KeyCode == Enum.KeyCode.LeftControl then
            isVisible = not isVisible
            UI.Enabled = isVisible
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
    
    tab.ChildAdded:Connect(updateTabCanvasSize)
    
    updateTabCanvasSize()    

    button.MouseButton1Click:Connect(function()
        pageLayout:JumpTo(page)
    end)

    Tabs[tabName] = tab
end

function CreateToggle(tabName, toggleText, actionFunction)
    local tab = Tabs[tabName]
    if not tab then return end

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

    button.MouseButton1Click:Connect(function()
        state.Value = not state.Value
        local color = state.Value and Color3.fromRGB(0, 115, 200) or Color3.fromRGB(116, 116, 116)
        local pos = state.Value and UDim2.new(0, 500, 0, 17) or UDim2.new(0, 475, 0, 17)

        TweenService:Create(indicator, TweenInfo.new(0.25), {Position = pos, BackgroundColor3 = color}):Play()
        TweenService:Create(bg, TweenInfo.new(0.25), {BackgroundColor3 = color}):Play()
    end)

    task.spawn(function()
        while true do
            if state.Value then
                actionFunction()
            end
            task.wait()
        end
    end)
end

local function CreateButton(tabName, buttonText, actionFunction)
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
	button.LayoutOrder = order

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

	button.MouseButton1Click:Connect(function()
        task.spawn(function()
            actionFunction()
        end)
	end)
end

local function CreateLabel(tabName, labelText)
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
	frame.LayoutOrder = order

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

local function DestroyMenu(menuName)
    local menuGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild(LibName)
    if menuGui then
        menuGui:Destroy()
    end
    Menus[menuName] = nil
    Sidebars[menuName] = nil
    PageLayouts[menuName] = nil
end

--[[

Menu:
CreateMenu("Menu Name")

Group:
CreateGroup("Menu Name", "Group Text")

Tab:
CreateTab("Menu Name", "Group Text", "Tab Name")

Toggle:
CreateToggle("Tab Name", "Toggle Text", function()
    print("Toggle function")
end)

Button:
CreateButton("Tab Name", "Button Text", function()
    print("Button function")
end)

Label:
CreateLabel("Tab Name", "Label Text")

Destroy Menu:
DestroyMenu("Menu Name")

]]--

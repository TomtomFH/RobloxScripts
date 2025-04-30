-- local workspace = game:GetService("Workspace")
-- local Players = game:GetService("Players")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local MoneyFolder = workspace:WaitForChild("CollectibleMoney")
-- local Money = {}
-- local player = Players.LocalPlayer
-- local character = player.Character or player.CharacterAdded:Wait()
-- local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
-- local stopScript = false

-- local screenGui = Instance.new("ScreenGui")
-- screenGui.Parent = player:WaitForChild("PlayerGui")

-- local backgroundFrame = Instance.new("Frame", screenGui)
-- backgroundFrame.Size = UDim2.new(0, 215, 0, 75)
-- backgroundFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 31)
-- backgroundFrame.BackgroundTransparency = 0
-- backgroundFrame.Position = UDim2.new(0, 0, 0, 0)

-- local uiCorner1 = Instance.new("UICorner", backgroundFrame)

-- local drag = Instance.new("UIDragDetector", backgroundFrame)

-- local statusLabel = Instance.new("TextLabel", backgroundFrame)
-- statusLabel.Size = UDim2.new(0, 200, 0, 25)
-- statusLabel.Position = UDim2.new(0.5, -100, 0, 5)
-- statusLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
-- statusLabel.TextColor3 = Color3.new(1, 1, 1)
-- statusLabel.Text = "Initializing..."

-- local uiCorner2 = Instance.new("UICorner", statusLabel)

-- local startButton = Instance.new("TextButton", backgroundFrame)
-- startButton.Size = UDim2.new(0, 50, 0, 25)
-- startButton.Position = UDim2.new(0.2, -25, 0, 40)
-- startButton.BackgroundColor3 = Color3.fromRGB(45, 130, 185)
-- startButton.TextColor3 = Color3.new(0, 0, 0)
-- startButton.Text = "Start"

-- local uiCorner3 = Instance.new("UICorner", startButton)

-- local pauseButton = Instance.new("TextButton", backgroundFrame)
-- pauseButton.Size = UDim2.new(0, 50, 0, 25)
-- pauseButton.Position = UDim2.new(0.5, -25, 0, 40)
-- pauseButton.BackgroundColor3 = Color3.fromRGB(45, 130, 185)
-- pauseButton.TextColor3 = Color3.new(0, 0, 0)
-- pauseButton.Text = "Pause"

-- local uiCorner4 = Instance.new("UICorner", pauseButton)

-- local stopButton = Instance.new("TextButton", backgroundFrame)
-- stopButton.Size = UDim2.new(0, 50, 0, 25)
-- stopButton.Position = UDim2.new(0.8, -25, 0, 40)
-- stopButton.BackgroundColor3 = Color3.fromRGB(45, 130, 185)
-- stopButton.TextColor3 = Color3.new(0, 0, 0)
-- stopButton.Text = "Stop"

-- local uiCorner5 = Instance.new("UICorner", stopButton)

-- for _, subDir in MoneyFolder:GetChildren() do
-- 	for _, part in subDir:GetChildren() do
-- 		table.insert(Money, part)
-- 	end
-- end

-- local function WithMoney(callback)
-- 	for _, part in ipairs(Money) do
-- 		callback(part)
-- 	end
-- end

-- local function HideName()
-- 	ReplicatedStorage:WaitForChild("Hide&ShowNameTag"):FireServer("HideAll")
-- end

-- local function farmMoney()
-- 	task.spawn(function()
-- 		while not stopScript do
-- 			if not screenGui.Parent then break end
-- 			statusLabel.Text = "Waiting for money..."
-- 			HideName()
-- 			for _, part in ipairs(Money) do
-- 				if stopScript then break end
-- 				if part:GetAttribute("Spawned") == true then
-- 					statusLabel.Text = "Collecting money..."
-- 					if stopScript then break end
-- 					humanoidRootPart.CFrame = part.CFrame * CFrame.new(0, 3, 0)
-- 					task.wait(0.1)
-- 				end
-- 			end
-- 			task.wait(0.1)
-- 		end
-- 	end)
-- end

-- statusLabel.Text = "Ready"

-- startButton.MouseButton1Click:Connect(function()
-- 	stopScript = false
-- 	farmMoney()
-- end)

-- pauseButton.MouseButton1Click:Connect(function()
-- 	stopScript = true
-- 	wait()
-- 	statusLabel.Text = "Paused"
-- end)

-- stopButton.MouseButton1Click:Connect(function()
-- 	stopScript = true
-- 	screenGui:Destroy()
-- end)

-- Load the script from the URL and execute it
local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/main.lua", true))()

-- Now you can call the functions defined in the script
CreateMenu("My Custom Menu")
CreateGroup("My Custom Menu", "Group 1")
CreateTab("My Custom Menu", "Group 1", "Tab 1")
CreateToggle("Tab 1", "Enable Feature", function()
    print("Feature Enabled")
end)
CreateButton("Tab 1", "Click Me", function()
    print("Button Clicked!")
end)
CreateLabel("Tab 1", "This is a label!")

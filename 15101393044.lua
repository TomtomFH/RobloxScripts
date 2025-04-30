local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MoneyFolder = workspace:WaitForChild("CollectibleMoney")
local Money = {}
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local function HideName()
	ReplicatedStorage:WaitForChild("Hide&ShowNameTag"):FireServer("HideAll")
end

for _, subDir in MoneyFolder:GetChildren() do
	for _, part in subDir:GetChildren() do
		table.insert(Money, part)
	end
end

CreateMenu("DTI")
CreateGroup("DTI", "Main")
CreateTab("DTI", "Main", "Farming")
CreateButton("Farming", "Hide Name", function()
    HideName()
end)
CreateToggle("Farming", "Auto Hide Name", function()
    HideName()
    task.wait(1)
end)
CreateToggle("Farming", "Auto Collect Money", function()
    for _, part in ipairs(Money) do
        if part:GetAttribute("Spawned") == true then
            humanoidRootPart.CFrame = part.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.1)
        end
    end
    task.wait(0.1)
end)
-- Egg Incremental (https://www.roblox.com/games/137034315542002/)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

CreateMenu("EI")
CreateGroup("EI", "Main")
CreateTab("EI", "Main", "Farming")
CreateToggle("Farming", "Auto Infinite Farm Range", function(state)
    while state.Value do
        workspace.TomtomFHYT1.Default.Size = Vector3.new(3, 2048, 2048)
        task.wait(1)
    end
end)
CreateToggle("Farming", "Auto Bring Buttons", function(state)
    while state.Value do
        for _,v in workspace.Upgrades.Buttons:GetChildren() do
            if v:FindFirstChild("Button") then
                v.Button.CanCollide = false
                v.Button.CFrame = character.HumanoidRootPart.CFrame
            end
        end
        task.wait(1)
    end
end)
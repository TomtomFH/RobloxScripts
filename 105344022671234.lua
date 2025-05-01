-- Ultimate Tree Incremental (https://www.roblox.com/games/105344022671234/)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local UiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

CreateMenu("UTI")
CreateGroup("UTI", "Main")
CreateTab("UTI", "Main", "Farming")
CreateToggle("Farming", "Auto Infinite Farm Range", function(state)
    while state.Value do
        character.Detector.Size = Vector3.new(1, 2048, 2048)
        character.Detector.Circle.Enabled = false
        task.wait(1)
    end
end)
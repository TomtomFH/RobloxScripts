-- Diagnostic script to inspect playerPetIndex structure
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getPlayerIndex = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("getPlayerIndex")

local playerPetIndex = getPlayerIndex:InvokeServer() or {}

local function tableToString(tbl, indent)
    indent = indent or 0
    local result = {}
    local indentStr = string.rep("  ", indent)
    
    for key, value in pairs(tbl) do
        if type(value) == "table" then
            table.insert(result, indentStr .. tostring(key) .. " = {")
            table.insert(result, tableToString(value, indent + 1))
            table.insert(result, indentStr .. "}")
        else
            table.insert(result, indentStr .. tostring(key) .. " = " .. tostring(value))
        end
    end
    
    return table.concat(result, "\n")
end

local output = "=== PLAYER PET INDEX STRUCTURE ===\n\n" .. tableToString(playerPetIndex)

-- Copy to clipboard
local UserInput = game:GetService("UserInputService")
local Connection
Connection = UserInput.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.C and UserInput:IsKeyDown(Enum.KeyCode.LeftControl) then
        Connection:Disconnect()
        setclipboard(output)
        print("✓ Index structure copied to clipboard!")
    end
end)

print(output)
print("\n[Press Ctrl+C to copy to clipboard]")

-- Build A Boat For Treasure - Inner Cloud (https://www.roblox.com/games/1930863474/)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

loadstring(game:HttpGet("https://raw.githubusercontent.com/TomtomFH/RobloxScripts/refs/heads/main/Lib.lua", true))()

local placeStatusLabel = nil

local universePlaces = {
    {Name = "Build A Boat For Treasure", PlaceId = 537413528},
    {Name = "The Test Place", PlaceId = 1930665568},
    {Name = "Inner Cloud", PlaceId = 1930863474},
    {Name = "Winter Place", PlaceId = 1930866268}
}

local function setPlaceStatus(text)
    if placeStatusLabel then
        placeStatusLabel.Text = "Status: " .. tostring(text)
    end
end

local function teleportToPlace(place)
    if not place then
        return
    end

    if game.PlaceId == place.PlaceId then
        setPlaceStatus("Already in " .. place.Name)
        return
    end

    setPlaceStatus("Teleporting to " .. place.Name)

    local success, err = pcall(function()
        TeleportService:Teleport(place.PlaceId, LocalPlayer)
    end)

    if not success then
        setPlaceStatus("Teleport failed: " .. tostring(err))
    end
end

CreateMenu("Build A Boat")
CreateGroup("Build A Boat", "Main")
CreateTab("Build A Boat", "Main", "Places")

placeStatusLabel = select(1, CreateValueLabel("Places", "Status: Ready"))

for _, place in ipairs(universePlaces) do
    local targetPlace = place
    local buttonText = targetPlace.Name
    if game.PlaceId == targetPlace.PlaceId then
        buttonText = buttonText .. " (Current)"
    end

    CreateButton("Places", buttonText, function()
        teleportToPlace(targetPlace)
    end)
end

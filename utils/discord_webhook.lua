-- Discord Webhook Utility
-- Returns a function that sends messages to Discord webhook
-- Usage: local sendWebhook = loadstring(game:HttpGet(url))()
--        sendWebhook("Your message here")

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local webhookUrl = "https://discord.com/api/webhooks/1478531198237151389/5CHSMltBahXHrTnDR3WyuFIUlVblKSgfRV0egIJC1XeAVc-KaRxKZbI_8g2s4xmt0xt7"

return function(message)
    local LocalPlayer = Players.LocalPlayer
    
    -- Try to get the actual image URL from Roblox API
    local avatarUrl = nil
    local userId = LocalPlayer.UserId
    
    local success, result = pcall(function()
        local apiUrl = "https://thumbnails.roblox.com/v1/users/avatar?userIds=" .. userId .. "&size=150x150&format=Png&isCircular=false"
        local response = request({
            Url = apiUrl,
            Method = "GET"
        })
        return HttpService:JSONDecode(response.Body)
    end)
    
    if success and result and result.data and result.data[1] then
        avatarUrl = result.data[1].imageUrl
    else
        avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=150&height=150&format=png"
    end
    
    local displayName = LocalPlayer.DisplayName .. " (" .. LocalPlayer.Name .. ")"
    
    local data = {
        username = "RobloxScripts",
        embeds = {{
            author = {
                name = displayName,
                icon_url = avatarUrl
            },
            description = message
        }}
    }
    
    local webhookSuccess, webhookResponse = pcall(function()
        return request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not webhookSuccess then
        warn("Failed to send webhook:", webhookResponse)
    end
    
    return webhookSuccess
end

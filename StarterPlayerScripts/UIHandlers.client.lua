local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local buyUpgrade = remotes:WaitForChild("BuyUpgrade")
local equipBee = remotes:WaitForChild("EquipBee")
local unlockZone = remotes:WaitForChild("UnlockZone")
local syncState = remotes:WaitForChild("SyncState")

local state = {
    ownedBees = {},
    equippedBees = {},
    hiveCapacity = 1,
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BeeForestUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size = UDim2.fromOffset(260, 36)
coinsLabel.Position = UDim2.fromOffset(12, 12)
coinsLabel.BackgroundColor3 = Color3.fromRGB(30, 65, 38)
coinsLabel.TextColor3 = Color3.new(1, 1, 1)
coinsLabel.TextScaled = true
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = screenGui

local zoneLabel = Instance.new("TextLabel")
zoneLabel.Size = UDim2.fromOffset(260, 32)
zoneLabel.Position = UDim2.fromOffset(12, 52)
zoneLabel.BackgroundColor3 = Color3.fromRGB(43, 83, 53)
zoneLabel.TextColor3 = Color3.new(1, 1, 1)
zoneLabel.TextScaled = true
zoneLabel.Text = "Zone: 1"
zoneLabel.Parent = screenGui

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Size = UDim2.fromOffset(420, 32)
feedbackLabel.Position = UDim2.fromOffset(12, 88)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.TextColor3 = Color3.new(1, 1, 1)
feedbackLabel.TextXAlignment = Enum.TextXAlignment.Left
feedbackLabel.Text = ""
feedbackLabel.Parent = screenGui

local function makeButton(text, y)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(200, 34)
    button.Position = UDim2.fromOffset(12, y)
    button.BackgroundColor3 = Color3.fromRGB(226, 194, 88)
    button.TextColor3 = Color3.fromRGB(35, 35, 35)
    button.TextScaled = true
    button.Text = text
    button.Parent = screenGui
    return button
end

local unlockZoneButton = makeButton("Unlock Next Zone", 120)
local equipBasicButton = makeButton("Equip Basic Pollinator", 160)
local equipSpeedButton = makeButton("Equip Speedster", 200)
local equipBoosterButton = makeButton("Equip Booster", 240)

local upgradeButtons = {
    MoreFlowers = makeButton("Upgrade MoreFlowers", 292),
    SoilQuality = makeButton("Upgrade SoilQuality", 332),
    HiveCapacity = makeButton("Upgrade HiveCapacity", 372),
    PollenBoost = makeButton("Upgrade PollenBoost", 412),
}

local function tryEquipBee(beeId)
    local equipped = table.clone(state.equippedBees)
    local exists = false

    for _, candidate in ipairs(equipped) do
        if candidate == beeId then
            exists = true
            break
        end
    end

    if not exists then
        if #equipped >= state.hiveCapacity then
            table.remove(equipped, 1)
        end
        table.insert(equipped, beeId)
    end

    equipBee:FireServer(equipped)
end

equipBasicButton.MouseButton1Click:Connect(function()
    tryEquipBee("BasicPollinator")
end)

equipSpeedButton.MouseButton1Click:Connect(function()
    tryEquipBee("SwiftWing")
end)

equipBoosterButton.MouseButton1Click:Connect(function()
    tryEquipBee("GroveBooster")
end)

unlockZoneButton.MouseButton1Click:Connect(function()
    unlockZone:FireServer()
end)

for upgradeId, button in pairs(upgradeButtons) do
    button.MouseButton1Click:Connect(function()
        buyUpgrade:FireServer(upgradeId)
    end)
end

syncState.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then
        return
    end

    if payload.coins then
        coinsLabel.Text = string.format("Coins: %d", payload.coins)
    end

    if payload.zoneLevel then
        zoneLabel.Text = string.format("Zone: %d", payload.zoneLevel)
    end

    if type(payload.equippedBees) == "table" then
        state.equippedBees = payload.equippedBees
    end

    if type(payload.ownedBees) == "table" then
        state.ownedBees = payload.ownedBees
    end

    if payload.hiveCapacity then
        state.hiveCapacity = payload.hiveCapacity
    end

    if payload.action then
        if payload.success then
            feedbackLabel.Text = string.format("%s success", payload.action)
        else
            feedbackLabel.Text = string.format("%s failed", payload.action)
        end
    end
end)

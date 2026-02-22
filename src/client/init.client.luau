local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local existingGui = playerGui:FindFirstChild("BeeForestHud")
if existingGui then
	existingGui:Destroy()
end

local leaderstats = player:WaitForChild("leaderstats")
local honeyValue = leaderstats:WaitForChild("Honey") :: IntValue
local pollinationsValue = leaderstats:WaitForChild("Pollinations") :: IntValue

local function formatNumber(value: number): string
	local text = tostring(value)
	local withCommas = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	local cleaned = withCommas:gsub("^,", "")
	return cleaned
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BeeForestHud"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(16, 16)
panel.Size = UDim2.fromOffset(330, 140)
panel.BackgroundColor3 = Color3.fromRGB(32, 24, 12)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(245, 194, 100)
panelStroke.Transparency = 0.35
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -20, 0, 32)
titleLabel.Position = UDim2.fromOffset(12, 8)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 236, 163)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextScaled = true
titleLabel.Text = "Bee Forest Pollination"
titleLabel.Parent = panel

local honeyLabel = Instance.new("TextLabel")
honeyLabel.Name = "Honey"
honeyLabel.BackgroundTransparency = 1
honeyLabel.Size = UDim2.new(1, -20, 0, 28)
honeyLabel.Position = UDim2.fromOffset(12, 44)
honeyLabel.Font = Enum.Font.Gotham
honeyLabel.TextColor3 = Color3.fromRGB(255, 219, 120)
honeyLabel.TextXAlignment = Enum.TextXAlignment.Left
honeyLabel.TextScaled = true
honeyLabel.Parent = panel

local pollinationsLabel = honeyLabel:Clone()
pollinationsLabel.Name = "Pollinations"
pollinationsLabel.Position = UDim2.fromOffset(12, 72)
pollinationsLabel.TextColor3 = Color3.fromRGB(200, 241, 143)
pollinationsLabel.Parent = panel

local globalPollinationsLabel = honeyLabel:Clone()
globalPollinationsLabel.Name = "GlobalPollinations"
globalPollinationsLabel.Position = UDim2.fromOffset(12, 100)
globalPollinationsLabel.TextColor3 = Color3.fromRGB(255, 178, 220)
globalPollinationsLabel.Parent = panel

local beeForest: Folder? = nil

local function updatePlayerStats()
	honeyLabel.Text = string.format("Honey: %s", formatNumber(honeyValue.Value))
	pollinationsLabel.Text = string.format("Your Pollinations: %s", formatNumber(pollinationsValue.Value))
end

local function updateGlobalStats()
	if not beeForest then
		globalPollinationsLabel.Text = "Forest Pollinations: --"
		return
	end

	local totalPollinations = beeForest:GetAttribute("TotalPollinations")
	if typeof(totalPollinations) ~= "number" then
		totalPollinations = 0
	end

	globalPollinationsLabel.Text = string.format("Forest Pollinations: %s", formatNumber(totalPollinations))
end

local function attachForest(forestFolder: Folder)
	beeForest = forestFolder
	updateGlobalStats()
	forestFolder:GetAttributeChangedSignal("TotalPollinations"):Connect(updateGlobalStats)
end

updatePlayerStats()
honeyValue:GetPropertyChangedSignal("Value"):Connect(updatePlayerStats)
pollinationsValue:GetPropertyChangedSignal("Value"):Connect(updatePlayerStats)

local existingForest = workspace:FindFirstChild("BeeForest")
if existingForest and existingForest:IsA("Folder") then
	attachForest(existingForest)
else
	updateGlobalStats()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "BeeForest" and child:IsA("Folder") then
			attachForest(child)
		end
	end)
end

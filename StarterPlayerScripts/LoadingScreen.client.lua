local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local syncState = remotes:WaitForChild("SyncState")

local function getLoaderImageId()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local images = assets and assets:FindFirstChild("Images")
    local imageConfig = images and images:FindFirstChild("LoaderImage")

    if imageConfig and imageConfig:IsA("StringValue") and imageConfig.Value ~= "" then
        return imageConfig.Value
    end

    return ""
end

local gui = Instance.new("ScreenGui")
gui.Name = "BeeForestLoader"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(21, 42, 26)
background.BorderSizePixel = 0
background.Parent = gui

local image = Instance.new("ImageLabel")
image.Name = "SplashImage"
image.AnchorPoint = Vector2.new(0.5, 0.5)
image.Position = UDim2.fromScale(0.5, 0.44)
image.Size = UDim2.fromScale(0.48, 0.48)
image.BackgroundTransparency = 1
image.ScaleType = Enum.ScaleType.Fit
image.Image = getLoaderImageId()
image.Parent = background

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.78)
title.Size = UDim2.fromScale(0.7, 0.08)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Text = "Bee Forest Pollination"
title.Parent = background

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.86)
subtitle.Size = UDim2.fromScale(0.6, 0.05)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = Color3.fromRGB(210, 235, 186)
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Loading hive, bees and forest..."
subtitle.Parent = background

local dismissed = false
local function dismissLoader()
    if dismissed then
        return
    end

    dismissed = true
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fade = TweenService:Create(background, tweenInfo, { BackgroundTransparency = 1 })
    fade:Play()

    for _, guiObject in ipairs(background:GetDescendants()) do
        if guiObject:IsA("TextLabel") then
            TweenService:Create(guiObject, tweenInfo, { TextTransparency = 1 }):Play()
        elseif guiObject:IsA("ImageLabel") then
            TweenService:Create(guiObject, tweenInfo, { ImageTransparency = 1 }):Play()
        end
    end

    task.delay(0.65, function()
        if gui and gui.Parent then
            gui:Destroy()
        end
    end)
end

syncState.OnClientEvent:Connect(function(payload)
    if type(payload) == "table" and payload.coins ~= nil then
        dismissLoader()
    end
end)

task.delay(8, dismissLoader)

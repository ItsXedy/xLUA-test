-- Auto-Mine & AFK Bypass GUI for Delta
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager") -- Used for safe UI clicking

local player = Players.LocalPlayer
local zonesFolder = Workspace:WaitForChild("Zones", 5)

-- Static list of all known mines in the game
local staticZones = {
    "Atlantis", "BlackHole", "Celestial", "Clockwork", 
    "Crypt", "Dragon", "Genesis", "Glacier", 
    "Glitch", "Grotto", "Mine1", "Mine2", 
    "Mine3", "Mine4", "Mine5", "Mine6", 
    "Moon", "Neon", "Sky", "Tomb", "Toxic"
}

-- Prevent duplicate GUIs
if CoreGui:FindFirstChild("AutoMineGUI") then
    CoreGui.AutoMineGUI:Destroy()
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoMineGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 210)
mainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title Bar
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 0, 35)
titleLabel.Position = UDim2.new(0.05, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Auto-Mine Manager"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Minimize Button (-)
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
minimizeBtn.Position = UDim2.new(0.72, 0, 0.1, 0)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = 14
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = minimizeBtn

-- Destroy Button (X)
local destroyBtn = Instance.new("TextButton")
destroyBtn.Size = UDim2.new(0, 25, 0, 25)
destroyBtn.Position = UDim2.new(0.86, 0, 0.1, 0)
destroyBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
destroyBtn.BorderSizePixel = 0
destroyBtn.Text = "X"
destroyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
destroyBtn.TextSize = 12
destroyBtn.Font = Enum.Font.GothamBold
destroyBtn.Parent = mainFrame

local desCorner = Instance.new("UICorner")
desCorner.CornerRadius = UDim.new(0, 4)
desCorner.Parent = destroyBtn

-- Container for inner controls
local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 0.8, 0)
container.Position = UDim2.new(0, 0, 0.2, 0)
container.BackgroundTransparency = 1
container.Parent = mainFrame

-- Zone Dropdown Main Button
local zoneSelectBtn = Instance.new("TextButton")
zoneSelectBtn.Size = UDim2.new(0.9, 0, 0, 32)
zoneSelectBtn.Position = UDim2.new(0.05, 0, 0.05, 0)
zoneSelectBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
zoneSelectBtn.BorderSizePixel = 0
zoneSelectBtn.Text = "Select Zone: [Click]"
zoneSelectBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
zoneSelectBtn.TextSize = 11
zoneSelectBtn.Font = Enum.Font.Gotham
zoneSelectBtn.Parent = container

local zoneCorner = Instance.new("UICorner")
zoneCorner.CornerRadius = UDim.new(0, 6)
zoneCorner.Parent = zoneSelectBtn

-- Popup Scrolling Frame for Zone List
local dropdownFrame = Instance.new("ScrollingFrame")
dropdownFrame.Size = UDim2.new(0.9, 0, 0, 120)
dropdownFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
dropdownFrame.BorderSizePixel = 0
dropdownFrame.Visible = false
dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
dropdownFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
dropdownFrame.ScrollBarThickness = 4
dropdownFrame.ZIndex = 5
dropdownFrame.Parent = container

local dropCorner = Instance.new("UICorner")
dropCorner.CornerRadius = UDim.new(0, 6)
dropCorner.Parent = dropdownFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 3)
uiListLayout.Parent = dropdownFrame

-- Toggle Auto-Mine Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.9, 0, 0, 35)
toggleBtn.Position = UDim2.new(0.05, 0, 0.38, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "Auto-Mine: OFF"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 12
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = container

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = toggleBtn

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 25)
statusLabel.Position = UDim2.new(0.05, 0, 0.72, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = container

-- Logic variables
local selectedZoneName = nil
local isAutoMining = false
local activeTween = nil

-- Populate scrollable list
local function buildStaticZoneList()
    for _, child in ipairs(dropdownFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, zoneName in ipairs(staticZones) do
        local zoneBtn = Instance.new("TextButton")
        zoneBtn.Size = UDim2.new(1, 0, 0, 28)
        zoneBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        zoneBtn.BorderSizePixel = 0
        zoneBtn.Text = zoneName
        zoneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        zoneBtn.TextSize = 11
        zoneBtn.Font = Enum.Font.Gotham
        zoneBtn.ZIndex = 6
        zoneBtn.Parent = dropdownFrame
        
        local btnUICorner = Instance.new("UICorner")
        btnUICorner.CornerRadius = UDim.new(0, 4)
        btnUICorner.Parent = zoneBtn
        
        zoneBtn.MouseButton1Click:Connect(function()
            selectedZoneName = zoneName
            zoneSelectBtn.Text = "Zone: " .. selectedZoneName
            dropdownFrame.Visible = false
            toggleBtn.Position = UDim2.new(0.05, 0, 0.38, 0)
        end)
    end
end

buildStaticZoneList()

zoneSelectBtn.MouseButton1Click:Connect(function()
    dropdownFrame.Visible = not dropdownFrame.Visible
    toggleBtn.Position = dropdownFrame.Visible and UDim2.new(0.05, 0, 0.72, 0) or UDim2.new(0.05, 0, 0.38, 0)
end)

minimizeBtn.MouseButton1Click:Connect(function()
    local isMinimized = container.Visible
    container.Visible = not isMinimized
    dropdownFrame.Visible = false
    mainFrame.Size = isMinimized and UDim2.new(0, 240, 0, 35) or UDim2.new(0, 240, 0, 210)
    minimizeBtn.Text = isMinimized and "+" or "-"
end)

destroyBtn.MouseButton1Click:Connect(function()
    if activeTween then activeTween:Cancel() end
    screenGui:Destroy()
end)

-- Tool Activation Helper
local function triggerMine()
    local char = player.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    else
        local backpack = player:FindFirstChildOfClass("Backpack")
        local backpackTool = backpack and backpack:FindFirstChildOfClass("Tool")
        if backpackTool and char:FindFirstChild("Humanoid") then
            char.Humanoid:EquipTool(backpackTool)
            backpackTool:Activate()
        end
    end
end

-- Smooth Movement Tween
local function smoothMoveTo(targetCFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if activeTween then activeTween:Cancel() end
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local speed = 45 
    local duration = math.clamp(distance / speed, 0.1, 1.5)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    activeTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    activeTween:Play()
end

-- Anti-AFK Loop targeting the Settings TextButton/ImageButton
local function startAfkBypassLoop()
    task.spawn(function()
        -- Disable standard Roblox Idled kick connection
        local GC = getconnections or get_hidden_connections
        if GC then
            for _, conn in pairs(GC(player.Idled)) do
                if conn.Disable then conn:Disable() elseif conn.Disconnect then conn:Disconnect() end
            end
        else
            player.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
        
        while isAutoMining do
            -- Wait 4 minutes (240 seconds)
            for _ = 1, 240 do
                if not isAutoMining then break end
                task.wait(1)
            end
            
            if not isAutoMining then break end
            
            -- 1. Send Engine Input Ping
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            
            -- 2. Directly trigger the Settings button
            local pGui = player:FindFirstChild("PlayerGui")
            local settingsBtn = pGui and pGui:FindFirstChild("Hud")
                and pGui.Hud:FindFirstChild("TopRight")
                and pGui.Hud.TopRight:FindFirstChild("Dock")
                and pGui.Hud.TopRight.Dock:FindFirstChild("Settings")
            
            if settingsBtn and settingsBtn:IsA("GuiButton") then
                print("Anti-AFK: Clicking Settings button...")
                -- Fire click twice (Open then Close)
                for _ = 1, 2 do
                    firesignal(settingsBtn.Activated)
                    task.wait(0.4)
                end
            else
                warn("Anti-AFK: Settings button not found at path!")
            end
        end
    end)
end

-- Core Auto-Mine Loop
local function autoMineLoop()
    task.spawn(function()
        local currentTargetRock = nil
        
        while isAutoMining do
            if not selectedZoneName then
                statusLabel.Text = "Select a Zone!"
                task.wait(1)
                continue
            end
            
            local targetZoneFolder = zonesFolder and zonesFolder:FindFirstChild(selectedZoneName)
            local rocksFolder = targetZoneFolder and targetZoneFolder:FindFirstChild("Rocks")
            
            if rocksFolder then
                local rocks = rocksFolder:GetChildren()
                local targetExists = false
                if currentTargetRock and currentTargetRock.Parent == rocksFolder then
                    targetExists = true
                else
                    currentTargetRock = nil
                end
                
                if not targetExists and #rocks > 0 then
                    currentTargetRock = rocks[math.random(1, #rocks)]
                end
                
                if currentTargetRock then
                    local primaryPart = currentTargetRock:IsA("Model") and (currentTargetRock.PrimaryPart or currentTargetRock:FindFirstChildWhichIsA("BasePart")) or currentTargetRock
                    
                    if primaryPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        statusLabel.Text = "Mining: " .. selectedZoneName
                        smoothMoveTo(primaryPart.CFrame + Vector3.new(0, 3, 0))
                        task.wait(0.2)
                        triggerMine()
                    end
                else
                    statusLabel.Text = "No rocks available"
                end
            else
                statusLabel.Text = "Rocks folder missing"
            end
            
            task.wait(0.3)
        end
        
        if activeTween then activeTween:Cancel() end
        statusLabel.Text = "Status: Idle"
    end)
end

toggleBtn.MouseButton1Click:Connect(function()
    isAutoMining = not isAutoMining
    if isAutoMining then
        toggleBtn.Text = "Auto-Mine: ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
        autoMineLoop()
        startAfkBypassLoop() -- Starts the 5-minute timer loop for anti-AFK
    else
        toggleBtn.Text = "Auto-Mine: OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

print("Auto-Mine & Anti-AFK Script Loaded!")

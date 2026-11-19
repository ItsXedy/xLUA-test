-- Dynamic Loader UI built from README.md entries
-- Destroys the loader menu upon executing a selected script
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local README_URL = "https://raw.githubusercontent.com/ItsXedy/xLUA-test/refs/heads/main/README.md"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function fetchReadme(url)
	local cacheBuster = (url:find("?", 1, true) and "&" or "?") .. "v=" .. tostring(os.clock())
	local ok, res = pcall(function()
		return game:HttpGet(url .. cacheBuster)
	end)
	if not ok or type(res) ~= "string" or #res == 0 then
		return nil, tostring(res)
	end
	return res, nil
end

-- Extracts entries matching:
-- ### Section Title
-- ```lua
-- loadstring(game:HttpGet("https://..."))()
-- ```
local function parseEntries(markdown)
	local entries = {}
	local currentTitle = "Unnamed Script"

	for line in markdown:gmatch("[^\r\n]+") do
		local heading = line:match("^###%s+(.+)$")
		if heading then
			currentTitle = heading:gsub("^%s+", ""):gsub("%s+$", "")
		end

		local url = line:match('loadstring%s*%(%s*game%s*:%s*HttpGet%s*%(%s*["\'](.-)["\']%s*%)%s*%)')
		if url and #url > 0 then
			table.insert(entries, {
				title = currentTitle,
				url = url,
			})
		end
	end

	return entries
end

local function executeAndClose(url, guiToDestroy)
	local cacheBuster = (url:find("?", 1, true) and "&" or "?") .. "v=" .. tostring(os.clock())
	local okHttp, code = pcall(function()
		return game:HttpGet(url .. cacheBuster)
	end)

	if not okHttp or type(code) ~= "string" or #code == 0 then
		warn("HttpGet failed:", tostring(code))
		return
	end

	-- Strip accidental leading // lines if a hosted file has them
	code = code:gsub("^%s*//[^\r\n]*\r?\n", "")

	local fn, compileErr = loadstring(code)
	if not fn then
		warn("Compile error:", tostring(compileErr))
		return
	end

	-- Remove loader UI before running the target script
	if guiToDestroy and guiToDestroy.Parent then
		guiToDestroy:Destroy()
	end

	local okRun, runErr = pcall(fn)
	if not okRun then
		warn("Runtime error:", tostring(runErr))
	end
end

-- Build UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReadmeDynamicLoader"
screenGui.ResetOnSpawn = false
pcall(function()
	screenGui.Parent = CoreGui
end)
if not screenGui.Parent then
	screenGui.Parent = playerGui
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 360, 0, 320)
main.Position = UDim2.new(0.5, -180, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = main

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 0, 32)
titleLabel.Position = UDim2.new(0, 10, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "README Script Loader"
titleLabel.TextColor3 = Color3.fromRGB(240, 244, 248)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = main

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 72, 0, 28)
refreshBtn.Position = UDim2.new(1, -82, 0, 10)
refreshBtn.BackgroundColor3 = Color3.fromRGB(52, 58, 72)
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Text = "Refresh"
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 12
refreshBtn.Parent = main

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 1, -90)
listFrame.Position = UDim2.new(0, 10, 0, 46)
listFrame.BackgroundColor3 = Color3.fromRGB(32, 35, 43)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 5
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = listFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingBottom = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 6)
listPad.Parent = listFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 34)
statusLabel.Position = UDim2.new(0, 10, 1, -38)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(150, 220, 170)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Loading README..."
statusLabel.Parent = main

local function clearButtons()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function rebuildMenu()
	clearButtons()
	statusLabel.Text = "Fetching README.md..."

	local md, err = fetchReadme(README_URL)
	if not md then
		statusLabel.Text = "Failed to load README: " .. tostring(err)
		return
	end

	local entries = parseEntries(md)
	for i, entry in ipairs(entries) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -6, 0, 36)
		btn.LayoutOrder = i
		btn.BackgroundColor3 = Color3.fromRGB(64, 130, 246)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = entry.title
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.Parent = listFrame

		btn.MouseButton1Click:Connect(function()
			btn.Active = false
			btn.Text = "Loading..."
			task.spawn(function()
				executeAndClose(entry.url, screenGui)
			end)
		end)
	end

	listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 14)
	statusLabel.Text = string.format("Loaded %d script(s) from README.md", #entries)
end

refreshBtn.MouseButton1Click:Connect(function()
	task.spawn(rebuildMenu)
end)

task.spawn(rebuildMenu)

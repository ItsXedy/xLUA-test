local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local hasFs = (typeof(writefile) == "function") and (typeof(makefolder) == "function")
local decompileFn = (typeof(decompile) == "function" and decompile)
	or (typeof(getscriptbytecode) == "function" and typeof(Decompile) == "function" and Decompile)
	or nil

local function safeName(text)
	if type(text) ~= "string" or text == "" then
		return "Unnamed"
	end
	return (text:gsub('[<>:"/\\|?*]', "_"))
end

local function getGameFolderName()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and info and type(info.Name) == "string" and #info.Name > 0 then
		return safeName(info.Name) .. "_" .. tostring(game.PlaceId)
	end
	return "Place_" .. tostring(game.PlaceId)
end

local function ensureDir(dirPath)
	if not hasFs then
		return
	end
	local current = ""
	for _, seg in ipairs(string.split(dirPath, "/")) do
		if seg ~= "" then
			current = (current == "") and seg or (current .. "/" .. seg)
			local exists = (typeof(isfolder) == "function") and pcall(isfolder, current) and isfolder(current)
			if not exists then
				pcall(makefolder, current)
			end
		end
	end
end

local function getScriptSource(scriptInst)
	if decompileFn then
		local okDec, res = pcall(decompileFn, scriptInst)
		if okDec and type(res) == "string" and #res > 0 then
			return res
		end
	end

	local okSrc, src = pcall(function()
		return scriptInst.Source
	end)
	if okSrc and type(src) == "string" and #src > 0 then
		return src
	end

	return "-- [Could not read or decompile source on client]"
end

local function formatVal(v)
	local t = typeof(v)
	if t == "string" then
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "Vector3" then
		return string.format("Vector3.new(%s, %s, %s)", tostring(v.X), tostring(v.Y), tostring(v.Z))
	elseif t == "Vector2" then
		return string.format("Vector2.new(%s, %s)", tostring(v.X), tostring(v.Y))
	elseif t == "Color3" then
		return string.format("Color3.new(%s, %s, %s)", tostring(v.R), tostring(v.G), tostring(v.B))
	elseif t == "UDim2" then
		return string.format(
			"UDim2.new(%s, %s, %s, %s)",
			tostring(v.X.Scale), tostring(v.X.Offset), tostring(v.Y.Scale), tostring(v.Y.Offset)
		)
	elseif t == "UDim" then
		return string.format("UDim.new(%s, %s)", tostring(v.Scale), tostring(v.Offset))
	elseif t == "EnumItem" then
		return tostring(v)
	elseif t == "Instance" then
		return string.format("-- Instance: %s (%s)", v:GetFullName(), v.ClassName)
	else
		return string.format("%q", tostring(v))
	end
end

local function buildHeader(inst)
	local lines = {
		"-- Name: " .. inst.Name,
		"-- ClassName: " .. inst.ClassName,
		"-- FullName: " .. inst:GetFullName(),
	}

	local okAttrs, attrs = pcall(function()
		return inst:GetAttributes()
	end)
	if okAttrs and type(attrs) == "table" and next(attrs) ~= nil then
		table.insert(lines, "-- Attributes:")
		for k, v in pairs(attrs) do
			table.insert(lines, string.format("--   %s = %s", tostring(k), formatVal(v)))
		end
	end

	local propList = {
		"Value", "Text", "PlaceholderText", "Image", "Visible", "Enabled",
		"Active", "BackgroundTransparency", "TextTransparency", "Position",
		"Size", "AnchorPoint", "LayoutOrder", "ZIndex", "TextColor3", "BackgroundColor3"
	}
	local propLines = {}
	for _, p in ipairs(propList) do
		local okProp, val = pcall(function()
			return inst[p]
		end)
		if okProp then
			table.insert(propLines, string.format("--   %s = %s", p, formatVal(val)))
		end
	end
	if #propLines > 0 then
		table.insert(lines, "-- Properties:")
		for _, pl in ipairs(propLines) do
			table.insert(lines, pl)
		end
	end

	return table.concat(lines, "\n") .. "\n"
end

local function writeInstanceFile(folderPath, inst, stats)
	local base = safeName(inst.Name)
	local filePath
	local content

	if inst:IsA("RemoteEvent") then
		filePath = folderPath .. "/" .. base .. ".remote.lua"
		content = buildHeader(inst) .. "\n-- RemoteEvent: " .. inst:GetFullName() .. "\n"
		stats.remotes += 1
	elseif inst:IsA("RemoteFunction") then
		filePath = folderPath .. "/" .. base .. ".remotefunc.lua"
		content = buildHeader(inst) .. "\n-- RemoteFunction: " .. inst:GetFullName() .. "\n"
		stats.remotes += 1
	elseif inst:IsA("BindableEvent") then
		filePath = folderPath .. "/" .. base .. ".bindable.lua"
		content = buildHeader(inst) .. "\n-- BindableEvent: " .. inst:GetFullName() .. "\n"
		stats.remotes += 1
	elseif inst:IsA("BindableFunction") then
		filePath = folderPath .. "/" .. base .. ".bindablefunc.lua"
		content = buildHeader(inst) .. "\n-- BindableFunction: " .. inst:GetFullName() .. "\n"
		stats.remotes += 1
	elseif inst:IsA("ModuleScript") then
		filePath = folderPath .. "/" .. base .. ".lua"
		content = buildHeader(inst) .. "\n" .. getScriptSource(inst) .. "\n"
		stats.scripts += 1
	elseif inst:IsA("LocalScript") then
		filePath = folderPath .. "/" .. base .. ".client.lua"
		content = buildHeader(inst) .. "\n" .. getScriptSource(inst) .. "\n"
		stats.scripts += 1
	elseif inst:IsA("Script") then
		filePath = folderPath .. "/" .. base .. ".server.lua"
		content = buildHeader(inst) .. "\n" .. getScriptSource(inst) .. "\n"
		stats.scripts += 1
	else
		filePath = folderPath .. "/" .. base .. ".txt"
		content = buildHeader(inst)
	end

	pcall(writefile, filePath, content)
	stats.files += 1
end

local function dumpTreeToFiles(rootInst, targetFolder, stats)
	ensureDir(targetFolder)

	local function walk(inst, currentFolder)
		local children = inst:GetChildren()
		local instFolder = currentFolder .. "/" .. safeName(inst.Name)

		if #children > 0 then
			ensureDir(instFolder)
			writeInstanceFile(instFolder, inst, stats)
			for _, child in ipairs(children) do
				walk(child, instFolder)
			end
		else
			writeInstanceFile(currentFolder, inst, stats)
		end

		if (stats.files % 25) == 0 then
			task.wait()
		end
	end

	for _, child in ipairs(rootInst:GetChildren()) do
		walk(child, targetFolder)
	end
end

local function runFileDump(customName, baseFolder, scopeMode, statusLabel)
	if not hasFs then
		statusLabel.Text = "Error: writefile / makefolder not available."
		return
	end

	local cleanName = safeName(customName)
	local gameFolder = getGameFolderName()
	local rootBase = (baseFolder and baseFolder ~= "") and baseFolder:gsub("/+$", "") or "Dumps"

	local outputRoot = string.format("%s/%s/%s", rootBase, cleanName, gameFolder)
	ensureDir(outputRoot)

	local stats = { files = 0, remotes = 0, scripts = 0 }

	if scopeMode == "ReplicatedStorage" or scopeMode == "Both" then
		statusLabel.Text = "Dumping ReplicatedStorage files..."
		dumpTreeToFiles(ReplicatedStorage, outputRoot .. "/ReplicatedStorage", stats)
	end

	if scopeMode == "PlayerGui" or scopeMode == "Both" then
		statusLabel.Text = "Dumping UI (PlayerGui) files..."
		dumpTreeToFiles(playerGui, outputRoot .. "/PlayerGui", stats)
	end

	statusLabel.Text = string.format(
		"[%s] Saved %d files (%d scripts, %d remotes) -> %s",
		scopeMode, stats.files, stats.scripts, stats.remotes, outputRoot
	)
end

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FileTreeDumperUI"
screenGui.ResetOnSpawn = false
pcall(function()
	screenGui.Parent = CoreGui
end)
if not screenGui.Parent then
	screenGui.Parent = playerGui
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 305)
frame.Position = UDim2.new(0.5, -190, 0.5, -152)
frame.BackgroundColor3 = Color3.fromRGB(26, 28, 34)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "File & Folder Dumper (RS + UI + Remotes)"
title.TextColor3 = Color3.fromRGB(240, 244, 248)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -20, 0, 32)
nameBox.Position = UDim2.new(0, 10, 0, 42)
nameBox.BackgroundColor3 = Color3.fromRGB(38, 41, 50)
nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
nameBox.PlaceholderText = "Custom (name)"
nameBox.Text = "MyDump"
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 13
nameBox.ClearTextOnFocus = false
nameBox.Parent = frame

local dirBox = Instance.new("TextBox")
dirBox.Size = UDim2.new(1, -20, 0, 32)
dirBox.Position = UDim2.new(0, 10, 0, 80)
dirBox.BackgroundColor3 = Color3.fromRGB(38, 41, 50)
dirBox.TextColor3 = Color3.fromRGB(255, 255, 255)
dirBox.PlaceholderText = "Base directory (e.g. Dumps)"
dirBox.Text = "Dumps"
dirBox.Font = Enum.Font.Gotham
dirBox.TextSize = 13
dirBox.ClearTextOnFocus = false
dirBox.Parent = frame

-- Scope selector buttons: PlayerGui Only | ReplicatedStorage Only | Both
local selectedScope = "Both"
local scopeModes = {
	{ id = "PlayerGui", label = "PlayerGui Only" },
	{ id = "ReplicatedStorage", label = "RS Only" },
	{ id = "Both", label = "Both" },
}
local scopeButtons = {}

local scopeRow = Instance.new("Frame")
scopeRow.Size = UDim2.new(1, -20, 0, 32)
scopeRow.Position = UDim2.new(0, 10, 0, 118)
scopeRow.BackgroundTransparency = 1
scopeRow.Parent = frame

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 6)
rowLayout.Parent = scopeRow

local function refreshScopeButtons()
	for _, item in ipairs(scopeButtons) do
		local active = (item.id == selectedScope)
		item.button.BackgroundColor3 = active and Color3.fromRGB(64, 130, 246) or Color3.fromRGB(44, 48, 58)
		item.button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(185, 195, 210)
	end
end

for _, mode in ipairs(scopeModes) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / 3, -4, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(44, 48, 58)
	btn.TextColor3 = Color3.fromRGB(185, 195, 210)
	btn.Text = mode.label
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = scopeRow

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedScope = mode.id
		refreshScopeButtons()
	end)

	table.insert(scopeButtons, { id = mode.id, button = btn })
end
refreshScopeButtons()

local preview = Instance.new("TextLabel")
preview.Size = UDim2.new(1, -20, 0, 32)
preview.Position = UDim2.new(0, 10, 0, 156)
preview.BackgroundTransparency = 1
preview.TextColor3 = Color3.fromRGB(165, 175, 190)
preview.Font = Enum.Font.Code
preview.TextSize = 11
preview.TextWrapped = true
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.Parent = frame

local function updatePreview()
	local base = (dirBox.Text ~= "" and dirBox.Text:gsub("/+$", "")) or "Dumps"
	preview.Text = string.format("Dir: %s/%s/%s/...", base, safeName(nameBox.Text), getGameFolderName())
end

nameBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
dirBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
updatePreview()

local dumpBtn = Instance.new("TextButton")
dumpBtn.Size = UDim2.new(1, -20, 0, 38)
dumpBtn.Position = UDim2.new(0, 10, 0, 196)
dumpBtn.BackgroundColor3 = Color3.fromRGB(64, 130, 246)
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.Text = "Dump Files & Folders"
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.TextSize = 13
dumpBtn.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 44)
statusLabel.Position = UDim2.new(0, 10, 0, 242)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(140, 220, 165)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = hasFs
	and (decompileFn and "Ready (decompiler detected)." or "Ready (no decompiler global found; .Source fallback).")
	or "Warning: writefile/makefolder missing."
statusLabel.Parent = frame

dumpBtn.MouseButton1Click:Connect(function()
	dumpBtn.Active = false
	dumpBtn.Text = "Dumping..."
	task.spawn(function()
		runFileDump(nameBox.Text, dirBox.Text, selectedScope, statusLabel)
		dumpBtn.Text = "Dump Files & Folders"
		dumpBtn.Active = true
	end)
end)

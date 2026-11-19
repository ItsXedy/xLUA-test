local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Check filesystem availability
local canWriteFiles = (typeof(writefile) == "function") and (typeof(makefolder) == "function")

local function getGameLabel()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and info and type(info.Name) == "string" and #info.Name > 0 then
		return info.Name:gsub('[<>:"/\\|?*]', "_") .. "_" .. tostring(game.PlaceId)
	end
	return "Place_" .. tostring(game.PlaceId)
end

local function sanitizeSegment(str)
	if type(str) ~= "string" or str == "" then
		return "DefaultName"
	end
	return (str:gsub('[<>:"/\\|?*]', "_"))
end

local function ensureFolderPath(fullPath)
	if not canWriteFiles then
		return
	end
	local parts = string.split(fullPath, "/")
	local current = ""
	for _, part in ipairs(parts) do
		if part ~= "" then
			current = (current == "") and part or (current .. "/" .. part)
			local exists = (typeof(isfolder) == "function") and pcall(isfolder, current) and isfolder(current)
			if not exists then
				pcall(makefolder, current)
			end
		end
	end
end

local function serializeValue(val)
	local t = typeof(val)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return val
	elseif t == "Vector3" then
		return { _type = "Vector3", x = val.X, y = val.Y, z = val.Z }
	elseif t == "Vector2" then
		return { _type = "Vector2", x = val.X, y = val.Y }
	elseif t == "CFrame" then
		return { _type = "CFrame", components = { val:GetComponents() } }
	elseif t == "Color3" then
		return { _type = "Color3", r = val.R, g = val.G, b = val.B }
	elseif t == "UDim2" then
		return {
			_type = "UDim2",
			xScale = val.X.Scale,
			xOffset = val.X.Offset,
			yScale = val.Y.Scale,
			yOffset = val.Y.Offset,
		}
	elseif t == "UDim" then
		return { _type = "UDim", scale = val.Scale, offset = val.Offset }
	elseif t == "EnumItem" then
		return { _type = "EnumItem", enumType = tostring(val.EnumType), name = val.Name, value = val.Value }
	elseif t == "Instance" then
		return { _type = "InstanceRef", name = val.Name, className = val.ClassName, fullName = val:GetFullName() }
	else
		return { _type = t, raw = tostring(val) }
	end
end

local function getAttributesSafe(inst)
	local attrs = {}
	local ok, rawAttrs = pcall(function()
		return inst:GetAttributes()
	end)
	if ok and type(rawAttrs) == "table" then
		for k, v in pairs(rawAttrs) do
			attrs[k] = serializeValue(v)
		end
	end
	return attrs
end

local function extractNotableProperties(inst)
	local props = {}
	local candidates = {
		"Value", "Text", "PlaceholderText", "Image", "Visible", "Enabled",
		"Active", "BackgroundTransparency", "TextTransparency", "Position",
		"Size", "AnchorPoint", "LayoutOrder", "ZIndex", "TextColor3",
		"BackgroundColor3", "Archivable"
	}
	for _, propName in ipairs(candidates) do
		local ok, val = pcall(function()
			return inst[propName]
		end)
		if ok then
			props[propName] = serializeValue(val)
		end
	end
	return props
end

local function serializeTree(rootInst, remotesList)
	local function walk(inst)
		local node = {
			name = inst.Name,
			className = inst.ClassName,
			fullName = inst:GetFullName(),
			attributes = getAttributesSafe(inst),
			properties = extractNotableProperties(inst),
			children = {},
		}

		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
			table.insert(remotesList, {
				name = inst.Name,
				className = inst.ClassName,
				fullName = inst:GetFullName(),
				attributes = node.attributes,
			})
		end

		for _, child in ipairs(inst:GetChildren()) do
			table.insert(node.children, walk(child))
		end

		return node
	end

	return walk(rootInst)
end

-- Simple JSON encoder for Luau tables
local function encodeJson(val, indent)
	indent = indent or 0
	local pad = string.rep("  ", indent)
	local nextPad = string.rep("  ", indent + 1)
	local t = type(val)

	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return val and "true" or "false"
	elseif t == "number" then
		if val ~= val or val == math.huge or val == -math.huge then
			return "null"
		end
		return tostring(val)
	elseif t == "string" then
		local escaped = val
			:gsub("\\", "\\\\")
			:gsub('"', '\\"')
			:gsub("\n", "\\n")
			:gsub("\r", "\\r")
			:gsub("\t", "\\t")
		return '"' .. escaped .. '"'
	elseif t == "table" then
		local isArray = true
		local count = 0
		for k in pairs(val) do
			count += 1
			if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
				isArray = false
				break
			end
		end
		if isArray then
			for i = 1, count do
				if val[i] == nil then
					isArray = false
					break
				end
			end
		end

		if count == 0 then
			return isArray and "[]" or "{}"
		end

		local parts = {}
		if isArray then
			for i = 1, count do
				table.insert(parts, nextPad .. encodeJson(val[i], indent + 1))
			end
			return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
		else
			local keys = {}
			for k in pairs(val) do
				table.insert(keys, tostring(k))
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				table.insert(parts, nextPad .. encodeJson(k, indent + 1) .. ": " .. encodeJson(val[k], indent + 1))
			end
			return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
		end
	end

	return encodeJson(tostring(val), indent)
end

local function runDump(customName, customBaseDir, includeReplicatedStorage, includeUI, statusLabel)
	local cleanName = sanitizeSegment(customName)
	local gameFolder = getGameLabel()
	local baseDir = (customBaseDir and customBaseDir ~= "") and customBaseDir:gsub("/+$", "") or "Dumps"

	-- Structure: (baseDir)/(name)/(game's parent/place)/...
	local targetRoot = string.format("%s/%s/%s", baseDir, cleanName, gameFolder)
	ensureFolderPath(targetRoot)

	local remotes = {}
	local payload = {
		meta = {
			customName = cleanName,
			gameLabel = gameFolder,
			placeId = game.PlaceId,
			jobId = game.JobId,
			exportedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			targetDirectory = targetRoot,
		},
		data = {},
		remotes = remotes,
	}

	if includeReplicatedStorage then
		statusLabel.Text = "Scanning ReplicatedStorage..."
		payload.data.ReplicatedStorage = serializeTree(ReplicatedStorage, remotes)
	end

	if includeUI then
		statusLabel.Text = "Scanning UI (PlayerGui)..."
		payload.data.PlayerGui = serializeTree(playerGui, remotes)
	end

	payload.remotesCount = #remotes

	local jsonText = encodeJson(payload, 0)
	local outFile = targetRoot .. "/full_dump.json"
	local remotesFile = targetRoot .. "/remotes_only.json"

	if canWriteFiles then
		pcall(writefile, outFile, jsonText)
		pcall(writefile, remotesFile, encodeJson({
			count = #remotes,
			remotes = remotes,
		}, 0))
		statusLabel.Text = string.format("Saved %d remotes -> %s", #remotes, targetRoot)
	else
		pcall(function()
			if setclipboard then
				setclipboard(jsonText)
			end
		end)
		statusLabel.Text = string.format("No writefile API (%d remotes). Copied JSON if clipboard supported.", #remotes)
	end
end

-- Build UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DumpDirectoryUI"
screenGui.ResetOnSpawn = false
pcall(function()
	screenGui.Parent = CoreGui
end)
if not screenGui.Parent then
	screenGui.Parent = playerGui
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 270)
frame.Position = UDim2.new(0.5, -190, 0.5, -135)
frame.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "ReplicatedStorage & UI Dumper"
title.TextColor3 = Color3.fromRGB(240, 244, 248)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -20, 0, 34)
nameBox.Position = UDim2.new(0, 10, 0, 46)
nameBox.BackgroundColor3 = Color3.fromRGB(40, 43, 52)
nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
nameBox.PlaceholderText = "Custom (name) — e.g. MyExport"
nameBox.Text = "MyExport"
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 13
nameBox.ClearTextOnFocus = false
nameBox.Parent = frame

local dirBox = Instance.new("TextBox")
dirBox.Size = UDim2.new(1, -20, 0, 34)
dirBox.Position = UDim2.new(0, 10, 0, 88)
dirBox.BackgroundColor3 = Color3.fromRGB(40, 43, 52)
dirBox.TextColor3 = Color3.fromRGB(255, 255, 255)
dirBox.PlaceholderText = "Root folder (default: Dumps)"
dirBox.Text = "Dumps"
dirBox.Font = Enum.Font.Gotham
dirBox.TextSize = 13
dirBox.ClearTextOnFocus = false
dirBox.Parent = frame

local previewLabel = Instance.new("TextLabel")
previewLabel.Size = UDim2.new(1, -20, 0, 34)
previewLabel.Position = UDim2.new(0, 10, 0, 128)
previewLabel.BackgroundTransparency = 1
previewLabel.TextColor3 = Color3.fromRGB(165, 175, 190)
previewLabel.Font = Enum.Font.Code
previewLabel.TextSize = 11
previewLabel.TextWrapped = true
previewLabel.TextXAlignment = Enum.TextXAlignment.Left
previewLabel.Parent = frame

local function updatePreview()
	local base = (dirBox.Text ~= "" and dirBox.Text:gsub("/+$", "")) or "Dumps"
	local cname = sanitizeSegment(nameBox.Text)
	previewLabel.Text = string.format("Path: %s/%s/%s/...", base, cname, getGameLabel())
end

nameBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
dirBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
updatePreview()

local dumpBtn = Instance.new("TextButton")
dumpBtn.Size = UDim2.new(1, -20, 0, 38)
dumpBtn.Position = UDim2.new(0, 10, 0, 170)
dumpBtn.BackgroundColor3 = Color3.fromRGB(64, 130, 246)
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.Text = "Export ReplicatedStorage + UI + Remotes"
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.TextSize = 13
dumpBtn.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 42)
statusLabel.Position = UDim2.new(0, 10, 0, 216)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(140, 220, 165)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = canWriteFiles and "Ready." or "Warning: writefile/makefolder not found in this environment."
statusLabel.Parent = frame

dumpBtn.MouseButton1Click:Connect(function()
	dumpBtn.Active = false
	dumpBtn.Text = "Exporting..."
	task.spawn(function()
		runDump(nameBox.Text, dirBox.Text, true, true, statusLabel)
		dumpBtn.Text = "Export ReplicatedStorage + UI + Remotes"
		dumpBtn.Active = true
	end)
end)

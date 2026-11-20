-- autoplay_gui.lua | Roblox LocalScript via loadstring | mobile, Delta executor | target: Orbit (ReplicatedStorage.Orbit)

local run_service = game:GetService("RunService")
local replicated_storage = game:GetService("ReplicatedStorage")
local core_gui = game:GetService("CoreGui")
local players = game:GetService("Players")

local orbit_judge = require(replicated_storage.Orbit.OrbitJudge)

----------------------------------------------------------------
-- state & cleanup
----------------------------------------------------------------
if _G.stop_autoplay then
	pcall(_G.stop_autoplay)
end

local autoplay_enabled = false
local is_destroyed = false
local is_minimized = false

local live_session = nil
local original_new_session = nil
local original_classify = orbit_judge.classify

local forced_pointer_active = false
local forced_sector = 0
local forced_hit_held = false

local LOOKAHEAD_SEC = 0.5
local HOLD_RELEASE_SLACK = 0.02
local active_holds = {}
local fired_ids = {}
local connection = nil

----------------------------------------------------------------
-- judge hook: only force critical_perfect when autoplay is ON
----------------------------------------------------------------
orbit_judge.classify = function(note, error_ms)
	local real = original_classify(note, error_ms)
	if not autoplay_enabled or is_destroyed then
		return real
	end

	local cfg = orbit_judge.NOTE_TYPE_CONFIG[note.type]
	if real == nil then
		real = {
			result = "critical_perfect",
			timingErrorMs = 0,
			direction = "JUST",
			noteType = note.type,
			logic = cfg.logic,
		}
	else
		real.result = "critical_perfect"
		real.timingErrorMs = 0
		real.direction = "JUST"
	end
	return real
end

----------------------------------------------------------------
-- session capture
----------------------------------------------------------------
original_new_session = hookfunction(orbit_judge.newSession, function(notes)
	local session = original_new_session(notes)
	live_session = session
	active_holds = {}
	fired_ids = {}
	forced_pointer_active = false
	forced_hit_held = false

	local mt = getmetatable(session)

	local base_set_sector = mt.setPointerSector
	mt.setPointerSector = function(self, sector, time)
		if autoplay_enabled and not is_destroyed and forced_pointer_active then
			return base_set_sector(self, forced_sector, time)
		end
		return base_set_sector(self, sector, time)
	end

	local base_set_inactive = mt.setPointerInactive
	mt.setPointerInactive = function(self)
		if autoplay_enabled and not is_destroyed and forced_pointer_active then
			return base_set_sector(self, forced_sector, session.lastTime or 0)
		end
		return base_set_inactive(self)
	end

	local base_set_hit_held = mt.setHitHeld
	mt.setHitHeld = function(self, value)
		if autoplay_enabled and not is_destroyed and forced_pointer_active then
			return base_set_hit_held(self, forced_hit_held)
		end
		return base_set_hit_held(self, value)
	end

	return session
end)

----------------------------------------------------------------
-- autoplay driver
----------------------------------------------------------------
local function reset_forced_state()
	active_holds = {}
	forced_pointer_active = false
	forced_hit_held = false
	if live_session then
		pcall(function()
			live_session:setPointerInactive()
			live_session:setHitHeld(false)
		end)
	end
end

local function autoplay_tick()
	if not autoplay_enabled or is_destroyed then
		return
	end

	local session = live_session
	if not session or session.finished then
		return
	end

	local now = session.lastTime
	if not now then
		return
	end

	-- release any holds past their tail + slack
	for id, h in pairs(active_holds) do
		if now >= h.end_time + HOLD_RELEASE_SLACK then
			active_holds[id] = nil
		end
	end

	-- round-robin active holds across sectors
	local hold_count = 0
	for _ in pairs(active_holds) do
		hold_count += 1
	end

	if hold_count > 0 then
		forced_pointer_active = true
		forced_hit_held = true
		local tick_index = math.floor(now / 0.016)
		local i = 0
		for _, h in pairs(active_holds) do
			if i == tick_index % hold_count then
				forced_sector = h.sector
				session:setPointerSector(h.sector, now)
				break
			end
			i += 1
		end
	else
		forced_pointer_active = false
		forced_hit_held = false
	end

	-- fire eligible pending notes
	for i = session.scanFrom, #session.notes do
		local note = session.notes[i]
		if note.state.status ~= "pending" then
			continue
		end
		if fired_ids[note.id] then
			continue
		end
		local dt = note.hitTime - now
		if dt > LOOKAHEAD_SEC then
			break
		end
		local ref = orbit_judge.REFERENCE_JUDGMENT[note.cfg.logic]
		if -dt * 1000 > ref.lateMs then
			continue
		end
		if dt > 0 then
			continue
		end

		fired_ids[note.id] = true

		local err_ms = (now - note.hitTime) * 1000
		local result = orbit_judge.classify(note, err_ms)
		if not result then
			continue
		end

		session:accept(note, result, now, now)

		if note.cfg.kind == "hold" then
			active_holds[note.id] = {
				sector = note.sector,
				end_time = note.hitTime + note.duration,
			}
			forced_pointer_active = true
			forced_hit_held = true
			forced_sector = note.sector
			session:setPointerSector(note.sector, now)
		end
	end
end

connection = run_service.Heartbeat:Connect(autoplay_tick)

----------------------------------------------------------------
-- mobile-friendly GUI (draggable, minimize, destroy, toggle)
----------------------------------------------------------------
local parent_gui = (gethui and gethui()) or core_gui or players.LocalPlayer:WaitForChild("PlayerGui")

local old_gui = parent_gui:FindFirstChild("OrbitAutoplayGUI")
if old_gui then
	old_gui:Destroy()
end

local screen_gui = Instance.new("ScreenGui")
screen_gui.Name = "OrbitAutoplayGUI"
screen_gui.ResetOnSpawn = false
screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen_gui.Parent = parent_gui

local main_frame = Instance.new("Frame")
main_frame.Name = "MainFrame"
main_frame.Size = UDim2.new(0, 210, 0, 92)
main_frame.Position = UDim2.new(0.5, -105, 0.15, 0)
main_frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
main_frame.BorderSizePixel = 0
main_frame.Active = true
main_frame.Draggable = true
main_frame.Parent = screen_gui

local main_corner = Instance.new("UICorner")
main_corner.CornerRadius = UDim.new(0, 8)
main_corner.Parent = main_frame

local main_stroke = Instance.new("UIStroke")
main_stroke.Color = Color3.fromRGB(55, 55, 70)
main_stroke.Thickness = 1.5
main_stroke.Parent = main_frame

-- Top Bar
local top_bar = Instance.new("Frame")
top_bar.Name = "TopBar"
top_bar.Size = UDim2.new(1, 0, 0, 30)
top_bar.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
top_bar.BorderSizePixel = 0
top_bar.Parent = main_frame

local top_corner = Instance.new("UICorner")
top_corner.CornerRadius = UDim.new(0, 8)
top_corner.Parent = top_bar

local top_cover = Instance.new("Frame")
top_cover.Size = UDim2.new(1, 0, 0, 8)
top_cover.Position = UDim2.new(0, 0, 1, -8)
top_cover.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
top_cover.BorderSizePixel = 0
top_cover.Parent = top_bar

local title_label = Instance.new("TextLabel")
title_label.Size = UDim2.new(1, -66, 1, 0)
title_label.Position = UDim2.new(0, 10, 0, 0)
title_label.BackgroundTransparency = 1
title_label.Text = "Orbit Autoplay"
title_label.TextColor3 = Color3.fromRGB(235, 235, 245)
title_label.TextSize = 14
title_label.Font = Enum.Font.GothamBold
title_label.TextXAlignment = Enum.TextXAlignment.Left
title_label.Parent = top_bar

-- Minimize Button ("-")
local min_btn = Instance.new("TextButton")
min_btn.Name = "MinimizeBtn"
min_btn.Size = UDim2.new(0, 24, 0, 22)
min_btn.Position = UDim2.new(1, -54, 0.5, -11)
min_btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
min_btn.Text = "-"
min_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
min_btn.TextSize = 16
min_btn.Font = Enum.Font.GothamBold
min_btn.Parent = top_bar

local min_corner = Instance.new("UICorner")
min_corner.CornerRadius = UDim.new(0, 5)
min_corner.Parent = min_btn

-- Destroy Button ("X")
local destroy_btn = Instance.new("TextButton")
destroy_btn.Name = "DestroyBtn"
destroy_btn.Size = UDim2.new(0, 24, 0, 22)
destroy_btn.Position = UDim2.new(1, -27, 0.5, -11)
destroy_btn.BackgroundColor3 = Color3.fromRGB(185, 55, 65)
destroy_btn.Text = "X"
destroy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
destroy_btn.TextSize = 13
destroy_btn.Font = Enum.Font.GothamBold
destroy_btn.Parent = top_bar

local destroy_corner = Instance.new("UICorner")
destroy_corner.CornerRadius = UDim.new(0, 5)
destroy_corner.Parent = destroy_btn

-- Body Content
local content_frame = Instance.new("Frame")
content_frame.Name = "Content"
content_frame.Size = UDim2.new(1, 0, 1, -30)
content_frame.Position = UDim2.new(0, 0, 0, 30)
content_frame.BackgroundTransparency = 1
content_frame.Parent = main_frame

-- Toggle Autoplay Button
local toggle_btn = Instance.new("TextButton")
toggle_btn.Name = "ToggleBtn"
toggle_btn.Size = UDim2.new(1, -24, 0, 40)
toggle_btn.Position = UDim2.new(0, 12, 0.5, -20)
toggle_btn.BackgroundColor3 = Color3.fromRGB(170, 50, 60)
toggle_btn.Text = "Autoplay: OFF"
toggle_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle_btn.TextSize = 15
toggle_btn.Font = Enum.Font.GothamBold
toggle_btn.Parent = content_frame

local toggle_corner = Instance.new("UICorner")
toggle_corner.CornerRadius = UDim.new(0, 7)
toggle_corner.Parent = toggle_btn

----------------------------------------------------------------
-- button interactions & full cleanup
----------------------------------------------------------------
toggle_btn.MouseButton1Click:Connect(function()
	autoplay_enabled = not autoplay_enabled
	if autoplay_enabled then
		toggle_btn.Text = "Autoplay: ON"
		toggle_btn.BackgroundColor3 = Color3.fromRGB(45, 165, 95)
	else
		toggle_btn.Text = "Autoplay: OFF"
		toggle_btn.BackgroundColor3 = Color3.fromRGB(170, 50, 60)
		reset_forced_state()
	end
end)

min_btn.MouseButton1Click:Connect(function()
	is_minimized = not is_minimized
	if is_minimized then
		content_frame.Visible = false
		top_cover.Visible = false
		main_frame.Size = UDim2.new(0, 210, 0, 30)
		min_btn.Text = "+"
	else
		main_frame.Size = UDim2.new(0, 210, 0, 92)
		top_cover.Visible = true
		content_frame.Visible = true
		min_btn.Text = "-"
	end
end)

_G.stop_autoplay = function()
	if is_destroyed then
		return
	end
	is_destroyed = true
	autoplay_enabled = false

	if connection then
		connection:Disconnect()
		connection = nil
	end

	reset_forced_state()

	if original_new_session then
		pcall(function()
			hookfunction(orbit_judge.newSession, original_new_session)
		end)
	end
	orbit_judge.classify = original_classify

	if screen_gui then
		screen_gui:Destroy()
	end

	_G.stop_autoplay = nil
end

destroy_btn.MouseButton1Click:Connect(function()
	if _G.stop_autoplay then
		_G.stop_autoplay()
	end
end)
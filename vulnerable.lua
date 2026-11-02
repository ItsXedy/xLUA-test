-- Language: Lua 5.1 (Luau), Runtime: Delta Executor (Android), Target: any Roblox game
-- global_vuln_scanner.lua — plug-and-run, UI only fires if findings > 0

local scanner = {findings = {}}

local function log(category, severity, detail, ref)
    table.insert(scanner.findings, {category=category, severity=severity, detail=detail, ref=ref})
end

local function scan_remotes()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            local sev = "low"
            if name:match("admin") or name:match("kick") or name:match("ban") then sev = "critical"
            elseif name:match("cash") or name:match("coin") or name:match("money") or name:match("give")
                or name:match("set") or name:match("add") or name:match("reward") or name:match("purchase") then sev = "high"
            elseif name:match("damage") or name:match("hit") or name:match("kill") then sev = "medium" end
            log("remote_exposed", sev, obj.ClassName.." '"..obj.Name.."' at "..obj:GetFullName(), obj)
        end
    end
end

local function scan_bindables()
    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
            log("bindable_exposed", "low", obj.ClassName.." '"..obj.Name.."' at "..obj:GetFullName(), obj)
        end
    end
end

local function scan_client_trust()
    local player = game:GetService("Players").LocalPlayer
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local original = humanoid.WalkSpeed
        humanoid.WalkSpeed = original + 1
        task.wait(0.3)
        if humanoid.WalkSpeed == original + 1 then
            log("client_physics_trust", "medium", "WalkSpeed change not reverted server-side — no authoritative check detected", humanoid)
        end
        humanoid.WalkSpeed = original
    end

    local rs = game:GetService("ReplicatedStorage")
    for _, obj in ipairs(rs:GetDescendants()) do
        if obj:IsA("ModuleScript") then
            local ok, mod = pcall(require, obj)
            if ok and type(mod) == "table" then
                local fn_count = 0
                for k, v in pairs(mod) do if type(v) == "function" then fn_count = fn_count + 1 end end
                if fn_count > 0 then
                    log("leaked_module_logic", "medium", "ModuleScript '"..obj:GetFullName().."' exposes "..fn_count.." functions client-side", obj)
                end
            end
        end
    end
end

local function scan_env_capabilities()
    local caps = {
        {"loadstring", loadstring}, {"getrawmetatable", getrawmetatable},
        {"hookfunction", hookfunction}, {"getupvalue", getupvalue or (debug and debug.getupvalue)},
        {"setreadonly", setreadonly}, {"getgenv", getgenv},
    }
    for _, p in ipairs(caps) do
        if p[2] then log("executor_capability", "high", p[1].." available", nil) end
    end
end

local function run_scan()
    scanner.findings = {}
    scan_remotes()
    scan_bindables()
    scan_client_trust()
    scan_env_capabilities()
    local rank = {critical=4, high=3, medium=2, low=1}
    table.sort(scanner.findings, function(a,b) return rank[a.severity] > rank[b.severity] end)
    return scanner.findings
end

local function build_report_text()
    local lines = {"=== "..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.." — vuln scan ===",
                   "PlaceId: "..game.PlaceId, "Findings: "..#scanner.findings, ""}
    for _, f in ipairs(scanner.findings) do
        table.insert(lines, string.format("[%s] %s: %s", f.severity:upper(), f.category, f.detail))
    end
    return table.concat(lines, "\n")
end

local function save_report()
    local dir = "dump"
    if not isfolder(dir) then
        makefolder(dir)
    end
    local fname = dir.."/vuln_scan_"..game.PlaceId.."_"..os.time()..".txt"
    writefile(fname, build_report_text())
    return fname
end

local function show_ui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "VulnScanUI"
    gui.ResetOnSpawn = false
    gui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 170)
    frame.Position = UDim2.new(0.5, -160, 0.5, -85)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Vuln Scanner — "..#scanner.findings.." finding(s)"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 50)
    sub.Position = UDim2.new(0, 10, 0, 45)
    sub.BackgroundTransparency = 1
    sub.Text = "Save results to file?"
    sub.TextColor3 = Color3.fromRGB(200,200,200)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = frame

    local function make_btn(text, posX, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 140, 0, 36)
        btn.Position = UDim2.new(0, posX, 0, 115)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        return btn
    end

    local yes_btn = make_btn("Yes — Save", 10, Color3.fromRGB(45, 140, 70))
    local no_btn = make_btn("No — Ignore", 165, Color3.fromRGB(140, 45, 45))

    yes_btn.MouseButton1Click:Connect(function()
        local fname = save_report()
        sub.Text = "Saved: "..fname
        task.wait(1.2)
        gui:Destroy()
    end)

    no_btn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

-- entry point: scan, only show UI if findings exist
run_scan()
if #scanner.findings > 0 then
    show_ui()
end

return scanner
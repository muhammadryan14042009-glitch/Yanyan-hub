loadstring([==[
-- Yanyan hub v8
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local origFOV = camera.FieldOfView

local LOGO_TEXT = "R"
local LOGO_SIZE = 22

local S = { radius = 10, height = 0, speed = 1 }
local angle, orbitConn = 0, nil
local conns, tweens = {}, {}

local C = {
	bg = Color3.fromRGB(38, 44, 58),
	panel = Color3.fromRGB(28, 33, 45),
	row = Color3.fromRGB(18, 20, 26),
	accent = Color3.fromRGB(0, 230, 150),
	text = Color3.fromRGB(235, 235, 240),
	sub = Color3.fromRGB(150, 155, 170),
	off = Color3.fromRGB(55, 58, 68),
	core = Color3.fromRGB(16, 36, 34),
}

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = (r == "full") and UDim.new(1, 0) or UDim.new(0, r)
	c.Parent = o
end

local function isPointer(i)
	return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
end

local function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function loop(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	table.insert(tweens, t)
	t:Play()
	return t
end

-- ============================================================
-- PLAYER FEATURES
-- ============================================================

-- State
local walkConn, flyConn, noclipConn = nil, nil, nil
local walkflingConn, flyflingConn, wallConn, infJumpConn = nil, nil, nil, nil
local flyBody = nil
local PS = {
	walkSpeed  = 50,
	flySpeed   = 50,
	jumpPower  = 100,
}

local function getChar()
	return player.Character
end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- Kecepatan Berjalan
local function applyWalkSpeed()
	local h = getHum()
	if h then h.WalkSpeed = PS.walkSpeed end
end
local walkCharConn
local function setWalkSpeed(on)
	if walkCharConn then walkCharConn:Disconnect() walkCharConn = nil end
	if on then
		applyWalkSpeed()
		walkCharConn = player.CharacterAdded:Connect(function(c)
			c:WaitForChild("Humanoid").WalkSpeed = PS.walkSpeed
		end)
	else
		local h = getHum()
		if h then h.WalkSpeed = 16 end
	end
end

-- Terbang
local function cleanFly()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyBody and flyBody.Parent then flyBody:Destroy() end
	flyBody = nil
	local h = getHum()
	if h then h.PlatformStand = false end
end

local function setFly(on)
	cleanFly()
	if not on then return end
	local root = getRoot()
	local hum = getHum()
	if not root or not hum then return end

	hum.PlatformStand = true
	flyBody = Instance.new("BodyVelocity")
	flyBody.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	flyBody.Velocity = Vector3.zero
	flyBody.Parent = root

	flyConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local vel = Vector3.zero
		local spd = PS.flySpeed
		local cf = cam.CFrame
		if UIS:IsKeyDown(Enum.KeyCode.W) then vel = vel + cf.LookVector * spd end
		if UIS:IsKeyDown(Enum.KeyCode.S) then vel = vel - cf.LookVector * spd end
		if UIS:IsKeyDown(Enum.KeyCode.A) then vel = vel - cf.RightVector * spd end
		if UIS:IsKeyDown(Enum.KeyCode.D) then vel = vel + cf.RightVector * spd end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, spd, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vel = vel - Vector3.new(0, spd, 0) end
		if flyBody and flyBody.Parent then flyBody.Velocity = vel end
	end)
end

-- Kekuatan Lompat
local function applyJumpPower()
	local h = getHum()
	if h then h.JumpPower = PS.jumpPower end
end
local jumpCharConn
local function setJumpPower(on)
	if jumpCharConn then jumpCharConn:Disconnect() jumpCharConn = nil end
	if on then
		applyJumpPower()
		jumpCharConn = player.CharacterAdded:Connect(function(c)
			c:WaitForChild("Humanoid").JumpPower = PS.jumpPower
		end)
	else
		local h = getHum()
		if h then h.JumpPower = 50 end
	end
end

-- NoClip
local function setNoClip(on)
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	if on then
		noclipConn = RunService.Stepped:Connect(function()
			local c = getChar()
			if not c then return end
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					p.CanCollide = false
				end
			end
		end)
	else
		local c = getChar()
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = true end
			end
		end
	end
end

-- Anti-Lempar (orang lain tak bisa colide)
local antiConn = nil
local function setAntiFling(on)
	if antiConn then antiConn:Disconnect() antiConn = nil end
	if on then
		antiConn = RunService.Stepped:Connect(function()
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character then
					for _, part in ipairs(p.Character:GetChildren()) do
						if part:IsA("BasePart") then part.CanCollide = false end
					end
				end
			end
		end)
	end
end

-- WalkFling (bergerak cepat → fling player lain)
local function setWalkFling(on)
	if walkflingConn then walkflingConn:Disconnect() walkflingConn = nil end
	if on then
		walkflingConn = RunService.Stepped:Connect(function()
			local root = getRoot()
			if not root then return end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character then
					local pr = p.Character:FindFirstChild("HumanoidRootPart")
					if pr and (pr.Position - root.Position).Magnitude < 5 then
						local bv = Instance.new("BodyVelocity")
						bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
						bv.Velocity = (pr.Position - root.Position).Unit * 200 + Vector3.new(0, 80, 0)
						bv.Parent = pr
						game:GetService("Debris"):AddItem(bv, 0.12)
					end
				end
			end
		end)
	end
end

-- FlyFling (terbang + fling saat menyentuh)
local function setFlyFling(on)
	if flyflingConn then flyflingConn:Disconnect() flyflingConn = nil end
	setFly(on) -- aktifkan/matikan terbang juga
	if on then
		flyflingConn = RunService.Stepped:Connect(function()
			local root = getRoot()
			if not root then return end
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character then
					local pr = p.Character:FindFirstChild("HumanoidRootPart")
					if pr and (pr.Position - root.Position).Magnitude < 8 then
						local bv = Instance.new("BodyVelocity")
						bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
						bv.Velocity = (pr.Position - root.Position).Unit * 350 + Vector3.new(0, 120, 0)
						bv.Parent = pr
						game:GetService("Debris"):AddItem(bv, 0.12)
					end
				end
			end
		end)
	end
end

-- Jalan di Dinding
local function setWallWalk(on)
	if wallConn then wallConn:Disconnect() wallConn = nil end
	local root = getRoot()
	if on and root then
		wallConn = RunService.Stepped:Connect(function()
			local r = getRoot()
			if not r then return end
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { player.Character }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local dirs = {
				r.CFrame.RightVector,
				-r.CFrame.RightVector,
				r.CFrame.LookVector,
			}
			for _, dir in ipairs(dirs) do
				local result = workspace:Raycast(r.Position, dir * 2.5, params)
				if result then
					local h = getHum()
					if h then h.PlatformStand = false end
					break
				end
			end
		end)
	else
		local h = getHum()
		if h then h.PlatformStand = false end
	end
end

-- Tanpa kerusakan jatuh
local fallConn
local function setNoFallDamage(on)
	if fallConn then fallConn:Disconnect() fallConn = nil end
	if on then
		fallConn = player.CharacterAdded:Connect(function(c)
			local h = c:WaitForChild("Humanoid")
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		end)
		local h = getHum()
		if h then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end
	else
		local h = getHum()
		if h then h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end
	end
end

-- Lompat Tak Terbatas
local function setInfJump(on)
	if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
	if on then
		infJumpConn = UIS.JumpRequest:Connect(function()
			local h = getHum()
			if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
		end)
	end
end

-- Paksa Orang Ketiga
local camSaved = nil
local function setThirdPerson(on)
	if on then
		if not camSaved then
			camSaved = {
				mode = player.CameraMode,
				min = player.CameraMinZoomDistance,
				max = player.CameraMaxZoomDistance,
			}
		end
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = math.max(camSaved.max, 12)
		player.CameraMinZoomDistance = 10
	elseif camSaved then
		player.CameraMinZoomDistance = camSaved.min
		player.CameraMaxZoomDistance = camSaved.max
		player.CameraMode = camSaved.mode
		camSaved = nil
	end
end

-- Orbit
local function stopOrbit()
	if orbitConn then orbitConn:Disconnect() orbitConn = nil end
	camera.CameraType = Enum.CameraType.Custom
end

local function startOrbit()
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	orbitConn = RunService.RenderStepped:Connect(function(dt)
		local root = getRoot()
		if not root then return end
		angle += S.speed * dt
		local pos = root.Position + Vector3.new(math.cos(angle) * S.radius, S.height, math.sin(angle) * S.radius)
		camera.CFrame = CFrame.lookAt(pos, root.Position)
	end)
end

-- ============================================================
-- GUI
-- ============================================================
local gui = new("ScreenGui", { Name = "YanyanHub", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

-- LOGO BERAURA
local holder = new("Frame", {
	Name = "LogoHolder",
	Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
	Position = UDim2.new(0, 20, 0.5, -LOGO_SIZE / 2),
	BackgroundTransparency = 1, ZIndex = 5,
}, gui)

local function ring(size, thickness, transp)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 4,
	}, holder)
	corner(f, "full")
	local s = new("UIStroke", {
		Color = C.accent, Thickness = thickness, Transparency = transp,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, f)
	return f, s
end

local breathe = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local _, glowStroke = ring(LOGO_SIZE + 8, 4, 0.88)
loop(glowStroke, breathe, { Transparency = 0.6 })

local _, thinStroke = ring(LOGO_SIZE + 4, 1, 0.65)
loop(thinStroke, breathe, { Transparency = 0.3 })

local _, arcStroke = ring(LOGO_SIZE + 4, 1.5, 0)
local arcGrad = new("UIGradient", {
	Color = ColorSequence.new(C.accent),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.15),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, arcStroke)
table.insert(conns, RunService.RenderStepped:Connect(function()
	arcGrad.Rotation = (tick() * 140) % 360
end))

local rippleInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
for k = 0, 1 do
	local f, s = ring(LOGO_SIZE, 1.2, 1)
	task.delay(k * 1.0, function()
		if not f.Parent then return end
		s.Transparency = 0.35
		loop(f, rippleInfo, { Size = UDim2.fromOffset(LOGO_SIZE + 26, LOGO_SIZE + 26) })
		loop(s, rippleInfo, { Transparency = 1 })
	end)
end

local logo = new("TextLabel", {
	Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
	Text = LOGO_TEXT, Font = Enum.Font.GothamBold, TextSize = 11,
	BackgroundColor3 = C.core, TextColor3 = C.accent, ZIndex = 6,
}, holder)
corner(logo, "full")
new("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.4 }, logo)
local logoScale = new("UIScale", { Scale = 1 }, logo)

loop(logo, breathe, { TextColor3 = Color3.fromRGB(170, 255, 225) })

local hit = new("TextButton", {
	Name = "Hit", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(LOGO_SIZE + 18, LOGO_SIZE + 18),
	Text = "", BackgroundTransparency = 1, ZIndex = 7,
}, holder)

-- WINDOW
local CENTER = UDim2.new(0.5, 0, 0.5, 0)
local win = new("CanvasGroup", {
	Size = UDim2.fromOffset(430, 320), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 18),
	BackgroundColor3 = C.bg, Visible = false, GroupTransparency = 1,
}, gui)
corner(win, 14)
local winScale = new("UIScale", { Scale = 0.9 }, win)

local isOpen, token = false, 0
local openInfo   = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local fadeInInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out)
local closeInfo  = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local fadeOutInfo = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function setOpen(state, onDone)
	if isOpen == state then if onDone then onDone() end return end
	isOpen = state
	token += 1
	local my = token
	if state then
		win.Visible = true
		TweenService:Create(winScale, openInfo, { Scale = 1 }):Play()
		TweenService:Create(win, openInfo, { Position = CENTER }):Play()
		TweenService:Create(win, fadeInInfo, { GroupTransparency = 0 }):Play()
	else
		local t = TweenService:Create(winScale, closeInfo, { Scale = 0.92 })
		TweenService:Create(win, closeInfo, { Position = UDim2.new(0.5, 0, 0.5, 12) }):Play()
		TweenService:Create(win, fadeOutInfo, { GroupTransparency = 1 }):Play()
		t.Completed:Connect(function()
			if token == my then win.Visible = false end
			if onDone then onDone() end
		end)
		t:Play()
	end
end

-- Header
local header = new("Frame", { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.panel }, win)
corner(header, 10)

local badge = new("TextLabel", {
	Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(8, 6),
	Text = LOGO_TEXT, Font = Enum.Font.GothamBold, TextSize = 16,
	BackgroundColor3 = C.core, TextColor3 = C.accent,
}, header)
corner(badge, "full")
new("UIStroke", { Color = C.accent, Thickness = 1.5, Transparency = 0.4 }, badge)

local title = new("TextLabel", {
	Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(48, 0), BackgroundTransparency = 1,
	Text = "Yanyan hub", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

table.insert(conns, RunService.RenderStepped:Connect(function()
	title.TextColor3 = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
end))

local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -76, 0, 6), Text = "—",
	Font = Enum.Font.GothamBold, TextSize = 14, BackgroundColor3 = C.row, TextColor3 = C.text,
}, header)
corner(minBtn, 8)

local closeBtn = new("TextButton", {
	Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -38, 0, 6), Text = "X",
	Font = Enum.Font.GothamBold, TextSize = 14, BackgroundColor3 = C.row, TextColor3 = C.text,
}, header)
corner(closeBtn, 8)

-- Sidebar
local sidebar = new("Frame", { Size = UDim2.new(0, 130, 1, -68), Position = UDim2.fromOffset(8, 60), BackgroundColor3 = C.panel }, win)
corner(sidebar, 10)

local tabHolder = new("Frame", {
	Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 6), BackgroundTransparency = 1,
}, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4) }, tabHolder)
new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, tabHolder)

-- Kartu profil
local profile = new("Frame", {
	Size = UDim2.new(1, -12, 0, 48), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6), BackgroundColor3 = C.row,
}, sidebar)
corner(profile, 8)

local avatar = new("ImageLabel", {
	Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(8, 8),
	BackgroundColor3 = C.panel, Image = "",
}, profile)
corner(avatar, "full")

task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then avatar.Image = img end
end)

new("TextLabel", {
	Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(46, 7), BackgroundTransparency = 1,
	Text = player.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, profile)

new("TextLabel", {
	Size = UDim2.new(1, -50, 0, 14), Position = UDim2.fromOffset(46, 25), BackgroundTransparency = 1,
	Text = "@" .. player.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, profile)

-- Konten
local content = new("Frame", { Size = UDim2.new(1, -154, 1, -68), Position = UDim2.fromOffset(146, 60), BackgroundTransparency = 1, ClipsDescendants = true }, win)

local pages, tabs = {}, {}

local function showTab(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do
		local active = (n == name)
		TweenService:Create(t.btn, TweenInfo.new(0.15), { BackgroundTransparency = active and 0 or 1 }):Play()
		t.ind.Visible = active
		TweenService:Create(t.lbl, TweenInfo.new(0.15), { TextColor3 = active and C.text or C.sub }):Play()
	end
end

local function addTab(name, icon)
	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 8) }, page)
	new("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }, page)
	pages[name] = page

	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), Text = "", BackgroundColor3 = C.row,
		BackgroundTransparency = 1, AutoButtonColor = false,
	}, tabHolder)
	corner(b, 8)

	local ind = new("Frame", {
		Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, 2, 0.5, -9),
		BackgroundColor3 = C.accent, Visible = false,
	}, b)
	corner(ind, "full")

	new("TextLabel", {
		Size = UDim2.new(0, 28, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
		Text = icon, TextSize = 15, TextColor3 = C.text,
	}, b)

	local lbl = new("TextLabel", {
		Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(42, 0), BackgroundTransparency = 1,
		Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, b)

	tabs[name] = { btn = b, ind = ind, lbl = lbl }
	b.Activated:Connect(function() showTab(name) end)
	return page
end

-- ----------------------------------------------------------------
-- addRow: support toggle + value stepper (sama seperti v7)
-- ----------------------------------------------------------------
local function addRow(page, title, opts)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.row }, page)
	corner(row, 10)

	local label = new("TextLabel", {
		Size = UDim2.new(1, opts.value and -130 or -70, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
		Text = title, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, row)

	if opts.value then
		local step = opts.step or 1

		local box = new("TextBox", {
			Size = UDim2.fromOffset(44, 28), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -40, 0.5, 0),
			Text = tostring(round2(opts.getValue())), Font = Enum.Font.GothamBold, TextSize = 14,
			BackgroundColor3 = C.panel, TextColor3 = C.accent, ClearTextOnFocus = false,
		}, row)
		corner(box, 6)

		local function apply(n)
			if opts.min then n = math.max(opts.min, n) end
			if opts.max then n = math.min(opts.max, n) end
			opts.onValue(round2(n))
			box.Text = tostring(round2(opts.getValue()))
		end

		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then apply(n) else box.Text = tostring(round2(opts.getValue())) end
		end)

		local function stepBtn(text, posX, dir)
			local b = new("TextButton", {
				Size = UDim2.fromOffset(26, 28), AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, posX, 0.5, 0),
				Text = text, Font = Enum.Font.GothamBold, TextSize = 16,
				BackgroundColor3 = C.panel, TextColor3 = C.accent, AutoButtonColor = false,
			}, row)
			corner(b, 6)

			local held = 0
			b.InputBegan:Connect(function(i)
				if not isPointer(i) then return end
				held += 1
				local my = held
				TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = C.off }):Play()
				apply(opts.getValue() + dir * step)
				task.spawn(function()
					task.wait(0.4)
					while held == my and b.Parent and win.Visible do
						apply(opts.getValue() + dir * step)
						task.wait(0.07)
					end
				end)
			end)
			b.InputEnded:Connect(function(i)
				if not isPointer(i) then return end
				held += 1
				TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = C.panel }):Play()
			end)
		end

		stepBtn("-", -88, -1)
		stepBtn("+", -10, 1)
	end

	if opts.toggle then
		local tg = new("TextButton", {
			Size = UDim2.fromOffset(46, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Text = "", BackgroundColor3 = C.off, AutoButtonColor = false,
		}, row)
		corner(tg, "full")
		local knob = new("Frame", {
			Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 3, 0.5, -9),
			BackgroundColor3 = Color3.fromRGB(215, 215, 225),
		}, tg)
		corner(knob, "full")

		local on = false
		local function visual(state)
			local info = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			TweenService:Create(knob, info, { Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }):Play()
			TweenService:Create(tg, TweenInfo.new(0.15), { BackgroundColor3 = state and C.accent or C.off }):Play()
		end

		tg.Activated:Connect(function()
			on = not on
			visual(on)
			opts.onToggle(on)
			if opts.momentary and on then
				task.delay(0.35, function()
					on = false
					visual(false)
				end)
			end
		end)
	end

	return label
end

-- ============================================================
-- TAB PEMAIN — semua fitur
-- ============================================================
local pPemain = addTab("Pemain", "👤")

-- Kecepatan berjalan (value + toggle)
local walkEnabled = false
addRow(pPemain, "Kecepatan berjalan", {
	value = true, step = 5, min = 16, max = 500,
	onValue = function(n)
		PS.walkSpeed = n
		if walkEnabled then applyWalkSpeed() end
	end,
	getValue = function() return PS.walkSpeed end,
})
addRow(pPemain, "⚡ Aktifkan Kecepatan", {
	toggle = true,
	onToggle = function(on)
		walkEnabled = on
		setWalkSpeed(on)
	end,
})

-- Terbang (value + toggle)
local flyEnabled = false
addRow(pPemain, "Terbang", {
	value = true, step = 5, min = 10, max = 500,
	onValue = function(n)
		PS.flySpeed = n
	end,
	getValue = function() return PS.flySpeed end,
})
addRow(pPemain, "✈️ Aktifkan Terbang", {
	toggle = true,
	onToggle = function(on)
		flyEnabled = on
		setFly(on)
	end,
})

-- Kekuatan Lompat (value + toggle)
local jumpEnabled = false
addRow(pPemain, "Kekuatan Lompat", {
	value = true, step = 10, min = 50, max = 1000,
	onValue = function(n)
		PS.jumpPower = n
		if jumpEnabled then applyJumpPower() end
	end,
	getValue = function() return PS.jumpPower end,
})
addRow(pPemain, "🦘 Aktifkan Lompat", {
	toggle = true,
	onToggle = function(on)
		jumpEnabled = on
		setJumpPower(on)
	end,
})

-- Toggle-only features
addRow(pPemain, "NoClip", {
	toggle = true,
	onToggle = function(on) setNoClip(on) end,
})
addRow(pPemain, "Anti-Lempar", {
	toggle = true,
	onToggle = function(on) setAntiFling(on) end,
})
addRow(pPemain, "WalkFling", {
	toggle = true,
	onToggle = function(on) setWalkFling(on) end,
})
addRow(pPemain, "FlyFling (terbang & lempar)", {
	toggle = true,
	onToggle = function(on) setFlyFling(on) end,
})
addRow(pPemain, "Jalan di dinding", {
	toggle = true,
	onToggle = function(on) setWallWalk(on) end,
})
addRow(pPemain, "Tanpa kerusakan jatuh", {
	toggle = true,
	onToggle = function(on) setNoFallDamage(on) end,
})
addRow(pPemain, "Lompat tak terbatas", {
	toggle = true,
	onToggle = function(on) setInfJump(on) end,
})
addRow(pPemain, "Paksa Orang Ketiga", {
	toggle = true,
	onToggle = function(on) setThirdPerson(on) end,
})
addRow(pPemain, "Mulai ulang (mati)", {
	toggle = true, momentary = true,
	onToggle = function()
		local hum = getHum()
		if hum then hum.Health = 0 end
	end,
})

local leaveArmed = false
local leaveLabel
leaveLabel = addRow(pPemain, "🚪 Keluar dari Game", {
	toggle = true, momentary = true,
	onToggle = function()
		if leaveArmed then
			player:Kick("Keluar dari game")
			return
		end
		leaveArmed = true
		leaveLabel.Text = "Tap lagi untuk keluar"
		task.delay(3, function()
			leaveArmed = false
			leaveLabel.Text = "🚪 Keluar dari Game"
		end)
	end,
})

-- ============================================================
-- TAB KAMERA
-- ============================================================
local pKamera = addTab("Kamera", "🎥")
addRow(pKamera, "Orbit kamera", {
	toggle = true,
	onToggle = function(on) if on then startOrbit() else stopOrbit() end end,
})
addRow(pKamera, "Jarak", {
	value = true, step = 1, min = 5, max = 60,
	onValue = function(n) S.radius = n end,
	getValue = function() return S.radius end,
})
addRow(pKamera, "Ketinggian", {
	value = true, step = 1, min = 0, max = 50,
	onValue = function(n) S.height = n end,
	getValue = function() return S.height end,
})
addRow(pKamera, "Kecepatan putar", {
	value = true, step = 0.1, min = 0.1, max = 10,
	onValue = function(n) S.speed = n end,
	getValue = function() return S.speed end,
})

-- ============================================================
-- TAB ALAT
-- ============================================================
local pAlat = addTab("Alat", "🔧")
addRow(pAlat, "Sudut pandang (FOV)", {
	value = true, step = 5, min = 30, max = 120,
	onValue = function(n) workspace.CurrentCamera.FieldOfView = n end,
	getValue = function() return math.floor(workspace.CurrentCamera.FieldOfView + 0.5) end,
})

-- ============================================================
-- TAB LAINNYA
-- ============================================================
local pLain = addTab("Lainnya", "⚡")
addRow(pLain, "Transparansi menu (0-0.9)", {
	value = true, step = 0.1, min = 0, max = 0.9,
	onValue = function(n) win.BackgroundTransparency = n end,
	getValue = function() return win.BackgroundTransparency end,
})

showTab("Pemain")

-- ============================================================
-- HEADER BUTTONS
-- ============================================================
minBtn.Activated:Connect(function() setOpen(false) end)

closeBtn.Activated:Connect(function()
	setOpen(false, function()
		stopOrbit()
		setAntiFling(false)
		setThirdPerson(false)
		setNoClip(false)
		setWalkFling(false)
		setFlyFling(false)
		setWallWalk(false)
		setNoFallDamage(false)
		setInfJump(false)
		cleanFly()
		setWalkSpeed(false)
		setJumpPower(false)
		pcall(function() workspace.CurrentCamera.FieldOfView = origFOV end)
		for _, c in ipairs(conns) do c:Disconnect() end
		for _, t in ipairs(tweens) do t:Cancel() end
		gui:Destroy()
	end)
end)

-- ============================================================
-- LOGO DRAG & TAP
-- ============================================================
local dragging, moved, dragStart, startPos = false, false, nil, nil
local pressInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

hit.InputBegan:Connect(function(i)
	if isPointer(i) then
		dragging, moved = true, false
		dragStart, startPos = i.Position, holder.Position
		TweenService:Create(logoScale, pressInfo, { Scale = 0.85 }):Play()
	end
end)

table.insert(conns, UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = i.Position - dragStart
		if d.Magnitude > 6 then moved = true end
		if moved then
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end
end))

table.insert(conns, UIS.InputEnded:Connect(function(i)
	if dragging and isPointer(i) then
		dragging = false
		TweenService:Create(logoScale, pressInfo, { Scale = 1 }):Play()
		if not moved then setOpen(not isOpen) end
	end
end))
]==])()

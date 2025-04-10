local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")

-- Config
local maxDistance = 150
local minDistance = 50
local maxAllowedDistance = 500

local default_color = Color3.new(1, 1, 1)
local weapon_color = Color3.new(1, 0, 0)
local npc_color = Color3.fromRGB(128, 0, 128)

-- Cache
local ESPCache = {}

-- Helper
local function isNPC(char)
	return char:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(char)
end

local function hasWeapon(char)
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("Tool") then return true end
	end
	return false
end

local function createBox()
	local b = {}
	for i = 1, 12 do
		local l = Drawing.new("Line")
		l.Thickness = 2
		l.Transparency = 0.5
		b[i] = l
	end
	return b
end

local function createNameTag()
	local t = Drawing.new("Text")
	t.Size = 16
	t.Center = true
	t.Outline = true
	t.Transparency = 1
	return t
end

local function updateBox(box, corners, color)
	local edges = {
		{1,2}, {2,3}, {3,4}, {4,1},
		{5,6}, {6,7}, {7,8}, {8,5},
		{1,5}, {2,6}, {3,7}, {4,8},
	}
	for i, e in ipairs(edges) do
		local a = corners[e[1]]
		local b = corners[e[2]]
		local sa, va = Camera:WorldToViewportPoint(a)
		local sb, vb = Camera:WorldToViewportPoint(b)
		if va and vb then
			box[i].From = Vector2.new(sa.X, sa.Y)
			box[i].To = Vector2.new(sb.X, sb.Y)
			box[i].Color = color
			box[i].Visible = true
		else
			box[i].Visible = false
		end
	end
end

local function updateESP(char, data, dist)
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not root or not head then return end

	local cf = root.CFrame
	local size = Vector3.new(4, 6, 2)
	local corners = {}
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				table.insert(corners, (cf * CFrame.new(size.X/2 * x, size.Y/2 * y, size.Z/2 * z)).Position)
			end
		end
	end

	local color = default_color
	if isNPC(char) then color = npc_color
	elseif hasWeapon(char) then color = weapon_color end

	updateBox(data.box, corners, color)

	local screenPos, visible = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
	data.tag.Position = Vector2.new(screenPos.X, screenPos.Y)
	data.tag.Text = (Players:GetPlayerFromCharacter(char) and Players:GetPlayerFromCharacter(char).Name or "NPC") .. " [".. math.floor(dist) .." studs]"
	data.tag.Color = color
	data.tag.Visible = visible
end

-- Crear y manejar GUI
local function createSliderGUI()
	local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
	gui.Name = "ESPSliderGUI"
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(0, 300, 0, 80)
	frame.Position = UDim2.new(0, 20, 0, 100)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BorderSizePixel = 0

	local label = Instance.new("TextLabel", frame)
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Text = "ESP Distance: " .. tostring(maxDistance) .. " studs"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSans
	label.TextSize = 16

	local sliderBack = Instance.new("Frame", frame)
	sliderBack.Size = UDim2.new(0.9, 0, 0, 8)
	sliderBack.Position = UDim2.new(0.05, 0, 0, 40)
	sliderBack.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

	local sliderBar = Instance.new("Frame", sliderBack)
	sliderBar.Size = UDim2.new(0, 10, 0, 20)
	sliderBar.Position = UDim2.new((maxDistance - minDistance) / (maxAllowedDistance - minDistance), -5, 0.5, -6)
	sliderBar.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	sliderBar.BorderSizePixel = 0

	local dragging = false

	sliderBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			local mouseX = UIS:GetMouseLocation().X
			local relX = math.clamp(mouseX - sliderBack.AbsolutePosition.X, 0, sliderBack.AbsoluteSize.X)
			local percent = relX / sliderBack.AbsoluteSize.X
			maxDistance = math.floor(minDistance + (maxAllowedDistance - minDistance) * percent)
			sliderBar.Position = UDim2.new(percent, -5, 0.5, -6)
			label.Text = "ESP Distance: " .. tostring(maxDistance) .. " studs"
		end
	end)
end

createSliderGUI()

-- Escaneo cada 0.2s (no cada frame)
task.spawn(function()
	while true do
		for _, char in pairs(workspace:GetDescendants()) do
			if char:IsA("Model") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
				if not ESPCache[char] then
					local box = createBox()
					local tag = createNameTag()
					ESPCache[char] = {box = box, tag = tag}
				end
			end
		end

		-- Limpieza de personajes eliminados
		for char, data in pairs(ESPCache) do
			if not char:IsDescendantOf(workspace) then
				for _, l in ipairs(data.box) do l:Remove() end
				if data.tag then data.tag:Remove() end
				ESPCache[char] = nil
			end
		end

		task.wait(0.2)
	end
end)

-- Render loop para actualizar visuals
RunService.RenderStepped:Connect(function()
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for char, data in pairs(ESPCache) do
		local targetRoot = char:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local dist = (targetRoot.Position - root.Position).Magnitude
			if dist <= maxDistance then
				updateESP(char, data, dist)
			else
				for _, l in ipairs(data.box) do l.Visible = false end
				if data.tag then data.tag.Visible = false end
			end
		end
	end
end)

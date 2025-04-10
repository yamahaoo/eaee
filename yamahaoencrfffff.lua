local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")

-- Configuración inicial
local maxDistance = 150
local minDistance = 50
local maxAllowedDistance = 500

local default_color = Color3.new(1, 1, 1) -- Color por defecto
local weapon_color = Color3.new(1, 0, 0) -- Color para los personajes con armas (rojo)
local npc_color = Color3.fromRGB(128, 0, 128) -- Color para los NPCs (morado)

local ESPCache = {}

-- Helper para detectar NPCs
local function isNPC(char)
    return char:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(char)
end

-- Helper para verificar si un personaje tiene un arma
local function hasWeapon(char)
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            return true
        end
    end
    return false
end

-- Crear box de ESP
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

-- Crear nombre del tag
local function createNameTag()
    local t = Drawing.new("Text")
    t.Size = 16
    t.Center = true
    t.Outline = true
    t.Transparency = 1
    return t
end

-- Actualizar visuales del ESP (cajas)
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

-- Actualizar ESP de los personajes (nombre y caja)
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

    -- Determinar el color de la caja
    local color = default_color
    if isNPC(char) then
        color = npc_color
    elseif hasWeapon(char) then
        color = weapon_color
    end

    updateBox(data.box, corners, color)

    -- Mostrar nombre del jugador o NPC
    local screenPos, visible = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1.5, 0))
    data.tag.Position = Vector2.new(screenPos.X, screenPos.Y)
    data.tag.Text = (Players:GetPlayerFromCharacter(char) and Players:GetPlayerFromCharacter(char).Name or "NPC") .. " [".. math.floor(dist) .." studs]"
    data.tag.Color = color
    data.tag.Visible = visible
end

-- Variable para controlar si el ESP está habilitado o no
local toggleESP = false

-- Ciclo de actualización de ESP
RunService.Heartbeat:Connect(function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Si el toggle está activado, actualizamos el ESP
    if toggleESP then
        -- Actualizamos el ESP solo para los personajes dentro del rango
        for char, data in pairs(ESPCache) do
            local targetRoot = char:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local dist = (targetRoot.Position - root.Position).Magnitude
                -- Verificamos que la distancia esté dentro del máximo rango
                if dist <= maxDistance then
                    updateESP(char, data, dist)
                else
                    for _, l in ipairs(data.box) do l.Visible = false end
                    if data.tag then data.tag.Visible = false end
                end
            end
        end
    else
        -- Si el toggle está desactivado, ocultamos todos los ESPs
        for _, data in pairs(ESPCache) do
            for _, l in ipairs(data.box) do l.Visible = false end
            if data.tag then data.tag.Visible = false end
        end
    end
end)

-- Crear la interfaz de Rayfield y el slider
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "ESP by yamahao",
    Icon = 0, -- No icon
    LoadingTitle = "SouthBronx ESP",
    LoadingSubtitle = "by yamahao",
    Theme = "Bloom",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
       Enabled = true,
       FolderName = nil,
       FileName = "Big Hub"
    },
    Discord = {
       Enabled = true,
       Invite = "uBpYwJekRq",
       RememberJoins = false
    },
    KeySystem = false,
    KeySettings = {
       Title = "Untitled",
       Subtitle = "Key System",
       Note = "No method of obtaining the key is provided",
       FileName = "Key",
       SaveKey = true,
       GrabKeyFromSite = false,
       Key = {"Hello"}
    }
})

local MainTab = Window:CreateTab("Main", 0) -- Crear la pestaña principal

-- Slider de distancia del ESP
local Slider = MainTab:CreateSlider({
    Name = "ESP Distance",
    Range = {50, 500},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = maxDistance, -- Valor inicial
    Flag = "ESP_Distance",
    Callback = function(Value)
        maxDistance = Value -- Actualiza maxDistance cuando se mueve el slider
        print("Nuevo maxDistance: " .. maxDistance)  -- Depuración: verifica si el slider actualiza el valor
    end,
})

-- Toggle para activar/desactivar los visuals de ESP
local Toggle = MainTab:CreateToggle({
    Name = "Habilitar ESP",
    CurrentValue = false,
    Flag = "ESP_Toggle",  -- Flag único para guardar la configuración
    Callback = function(Value)
        toggleESP = Value -- Actualiza el estado del toggle
    end,
})

-- Inicializar la configuración
Rayfield:LoadConfiguration()

-- Ciclo para escanear personajes y crear ESP
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

        task.wait(0.2) -- Reduce la frecuencia de actualización
    end
end)

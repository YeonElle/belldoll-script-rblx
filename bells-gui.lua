--[[
    Bell's GUI v1.0  |  White + Pastel Blue (re-themable)
    Hookless "silent" aim, ESP, Fog/World, Theme editor.
    Menu toggle: RightShift (rebindable) or the round "B" button.

    HOW THE AIM WORKS (no hooks):
    While you fire, the camera is pointed so your cursor ray lands on the
    predicted target position on Heartbeat (after the frame is drawn, before the
    next input is read), then restored before the next frame renders. The game
    reads your aim from the aimed camera, but your screen never shows the snap.
    Works best with Shift Lock / first person (mouse centered).
]]

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UIS = cloneref(game:GetService("UserInputService"))
local Lighting = cloneref(game:GetService("Lighting"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService = cloneref(game:GetService("TweenService"))

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local env = (getgenv and getgenv()) or _G
if env.BellsGUI then pcall(env.BellsGUI.Unload) end

------------------------------------------------------------------ SETTINGS
local S = {
    SA = {
        Enabled = false, Key = Enum.KeyCode.E, Activation = "Mouse1",
        AimPart = "Head", TargetMode = "Closest To Cursor",
        FOV = 120, ShowFOV = true, WallCheck = true, TeamCheck = false,
        KnockedCheck = true, MaxDist = 500, HitChance = 100, Sticky = false,
        PredMode = "Manual", Prediction = 0.135, PingMult = 1.0,
        IgnoreY = false, YMult = 0.5, Resolver = true, OffsetY = 0,
        ShowTracer = true,
    },
    ESP = {
        Enabled = false, Boxes = true, Fill = false, Names = true, Distance = true,
        Health = true, Tool = false, Tracers = false, Chams = false,
        TeamColor = false, MaxDist = 2000, TracerOrigin = "Bottom",
        Color = Color3.fromRGB(168, 208, 255),
    },
    Fog = {
        Enabled = false, Density = 0.35, Haze = 1, Start = 0, End = 300,
        Color = Color3.fromRGB(200, 225, 255),
    },
    World = { Fullbright = false, FOVEnabled = false, FOV = 90, TimeEnabled = false, Time = 14 },
    UI = { MenuKey = Enum.KeyCode.RightControl },
}

------------------------------------------------------------------ THEME (2 colors)
local Theme = { Primary = Color3.fromRGB(168, 208, 255), Secondary = Color3.fromRGB(255, 255, 255) }
local Presets = {
    ["Pastel Blue / White"]  = {Color3.fromRGB(168, 208, 255), Color3.fromRGB(255, 255, 255)},
    ["Pastel Pink / White"]  = {Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 255, 255)},
    ["Mint / White"]         = {Color3.fromRGB(170, 235, 205), Color3.fromRGB(255, 255, 255)},
    ["Lavender / White"]     = {Color3.fromRGB(200, 185, 255), Color3.fromRGB(255, 255, 255)},
    ["Pastel Blue / Dark"]   = {Color3.fromRGB(168, 208, 255), Color3.fromRGB(32, 36, 48)},
}
local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
local function contrast(c) return lum(c) > 0.6 and Color3.fromRGB(45, 55, 72) or Color3.new(1, 1, 1) end
local roles = {
    bg      = function() return Theme.Secondary end,
    panel   = function() return Theme.Secondary:Lerp(Theme.Primary, 0.18) end,
    track   = function() return Theme.Secondary:Lerp(Theme.Primary, 0.35) end,
    off     = function() return Theme.Secondary:Lerp(Color3.new(0.5, 0.5, 0.5), 0.35) end,
    accent  = function() return Theme.Primary end,
    text    = function() return contrast(Theme.Secondary) end,
    sub     = function() return contrast(Theme.Secondary):Lerp(Theme.Secondary, 0.45) end,
    onAccent= function() return contrast(Theme.Primary) end,
}
local themeCbs = {}
local function reactive(fn) fn(); themeCbs[#themeCbs + 1] = fn end
local function bind(inst, prop, role) reactive(function() inst[prop] = roles[role]() end) end
local function refreshTheme() for _, f in ipairs(themeCbs) do pcall(f) end end

------------------------------------------------------------------ HELPERS
local conns, drawings = {}, {}
local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end
local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}) end
local function round(v, step) return tonumber(string.format("%.4f", math.floor(v / step + 0.5) * step)) end
local hasDrawing = typeof(Drawing) == "table" or typeof(Drawing) == "userdata"
local function draw(t, props)
    if not hasDrawing then return nil end
    local d = Drawing.new(t)
    for k, v in pairs(props or {}) do d[k] = v end
    drawings[#drawings + 1] = d
    return d
end

------------------------------------------------------------------ GUI BASE
local gui = new("ScreenGui", {Name = "BellsGUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
if not pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end) then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = new("Frame", {Size = UDim2.fromOffset(500, 340), Position = UDim2.new(0.5, -250, 0.5, -170), BorderSizePixel = 0, Parent = gui}, {corner(12)})
bind(main, "BackgroundColor3", "bg")
local stroke = new("UIStroke", {Thickness = 2, Parent = main}); bind(stroke, "Color", "accent")

local top = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0, Parent = main}, {corner(12)})
bind(top, "BackgroundColor3", "accent")
local topFill = new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BorderSizePixel = 0, Parent = top}); bind(topFill, "BackgroundColor3", "accent")
local title = new("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1, Text = "Bell's GUI", Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = top}); bind(title, "TextColor3", "onAccent")

-- dragging
do
    local dragging, startPos, startInput
    connect(top.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, main.Position, i.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local tabList = new("Frame", {Size = UDim2.new(0, 110, 1, -46), Position = UDim2.fromOffset(8, 42), BackgroundTransparency = 1, Parent = main},
    {new("UIListLayout", {Padding = UDim.new(0, 6)})})
local content = new("Frame", {Size = UDim2.new(1, -134, 1, -46), Position = UDim2.fromOffset(124, 42), BackgroundTransparency = 1, Parent = main})

local bubble = new("TextButton", {Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(12, 120), Text = "B", Font = Enum.Font.GothamBold, TextSize = 18, BorderSizePixel = 0, Parent = gui}, {corner(19)})
bind(bubble, "BackgroundColor3", "accent"); bind(bubble, "TextColor3", "onAccent")
connect(bubble.MouseButton1Click, function() main.Visible = not main.Visible end)

------------------------------------------------------------------ TABS & COMPONENTS
local currentTab
local function addTab(name)
    local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, 30), Text = name, Font = Enum.Font.GothamSemibold, TextSize = 13, BorderSizePixel = 0, AutoButtonColor = false, Parent = tabList}, {corner(8)})
    local page = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content},
        {new("UIListLayout", {Padding = UDim.new(0, 6)}), new("UIPadding", {PaddingRight = UDim.new(0, 6)})})
    reactive(function()
        local sel = currentTab == page
        btn.BackgroundColor3 = sel and roles.accent() or roles.panel()
        btn.TextColor3 = sel and roles.onAccent() or roles.text()
    end)
    connect(btn.MouseButton1Click, function()
        if currentTab then currentTab.Visible = false end
        currentTab = page; page.Visible = true; refreshTheme()
    end)
    if not currentTab then currentTab = page; page.Visible = true; refreshTheme() end
    return page
end

local function row(page, h)
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, h or 34), BorderSizePixel = 0, Parent = page}, {corner(8)})
    bind(f, "BackgroundColor3", "panel")
    return f
end
local function label(parent, text, size, xalign)
    local l = new("TextLabel", {Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = text, Font = Enum.Font.Gotham, TextSize = size or 13, TextXAlignment = xalign or Enum.TextXAlignment.Left, Parent = parent})
    bind(l, "TextColor3", "text"); return l
end
local function section(page, text)
    local l = new("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "  " .. text:upper(), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = page})
    bind(l, "TextColor3", "sub")
end
local function addToggle(page, name, tbl, key, cb)
    local f = row(page); local l = label(f, name); l.Position = UDim2.fromOffset(10, 7)
    local pill = new("TextButton", {Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -48, 0.5, -10), Text = "", BorderSizePixel = 0, AutoButtonColor = false, Parent = f}, {corner(10)})
    local knob = new("Frame", {Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, Parent = pill}, {corner(8)})
    bind(knob, "BackgroundColor3", "bg")
    local function render()
        pill.BackgroundColor3 = tbl[key] and roles.accent() or roles.off()
        knob.Position = tbl[key] and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
    end
    reactive(render)
    local function set(v) tbl[key] = v; render(); if cb then cb(v) end end
    connect(pill.MouseButton1Click, function() set(not tbl[key]) end)
    connect(f.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and false then end end)
    return set
end
local function addSlider(page, name, min, max, tbl, key, step, cb, suffix)
    step = step or 1
    local f = row(page, 44); local l = label(f, name); l.Position = UDim2.fromOffset(10, 4)
    local val = label(f, "", 13, Enum.TextXAlignment.Right); val.Position = UDim2.fromOffset(0, 4); val.Size = UDim2.new(1, -10, 0, 20)
    local bar = new("Frame", {Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 31), BorderSizePixel = 0, Parent = f}, {corner(3)})
    bind(bar, "BackgroundColor3", "track")
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = bar}, {corner(3)}); bind(fill, "BackgroundColor3", "accent")
    local function setv(v)
        v = math.clamp(round(v, step), min, max); tbl[key] = v
        fill.Size = UDim2.fromScale((v - min) / (max - min), 1); val.Text = tostring(v) .. (suffix or "")
        if cb then cb(v) end
    end
    local dragging = false
    local function fromX(x) setv(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end
    connect(f.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromX(i.Position.X) end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    setv(tbl[key]); return setv
end
local function addDropdown(page, name, options, tbl, key, cb)
    local f = row(page); local l = label(f, name); l.Position = UDim2.fromOffset(10, 7)
    local b = new("TextButton", {Size = UDim2.new(0, 150, 0, 24), Position = UDim2.new(1, -160, 0.5, -12), Font = Enum.Font.GothamSemibold, TextSize = 12, BorderSizePixel = 0, Parent = f}, {corner(6)})
    bind(b, "BackgroundColor3", "accent"); bind(b, "TextColor3", "onAccent")
    local function set(v) tbl[key] = v; b.Text = v .. "  ▾"; if cb then cb(v) end end
    connect(b.MouseButton1Click, function()
        local idx = table.find(options, tbl[key]) or 0
        set(options[idx % #options + 1])
    end)
    set(tbl[key]); return set
end
local function addButton(page, name, cb)
    local b = new("TextButton", {Size = UDim2.new(1, 0, 0, 32), Text = name, Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, Parent = page}, {corner(8)})
    bind(b, "BackgroundColor3", "accent"); bind(b, "TextColor3", "onAccent")
    connect(b.MouseButton1Click, cb)
end
local function addKeybind(page, name, tbl, key, cb)
    local f = row(page); local l = label(f, name); l.Position = UDim2.fromOffset(10, 7)
    local b = new("TextButton", {Size = UDim2.new(0, 110, 0, 24), Position = UDim2.new(1, -120, 0.5, -12), Font = Enum.Font.GothamSemibold, TextSize = 12, BorderSizePixel = 0, Parent = f}, {corner(6)})
    bind(b, "BackgroundColor3", "accent"); bind(b, "TextColor3", "onAccent")
    b.Text = tbl[key].Name
    local listening = false
    connect(b.MouseButton1Click, function() listening = true; b.Text = "..." end)
    connect(UIS.InputBegan, function(i)
        if listening and i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false; tbl[key] = (i.KeyCode == Enum.KeyCode.Escape) and tbl[key] or i.KeyCode; b.Text = tbl[key].Name
            if cb then cb(tbl[key]) end
        end
    end)
end
local function addColor(page, name, tbl, key, cb)
    section(page, name)
    local setters, c = {}, tbl[key]
    local ch = {R = c.R * 255, G = c.G * 255, B = c.B * 255}
    local preview = row(page, 14); local pv = new("Frame", {Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 4), BorderSizePixel = 0, Parent = preview}, {corner(3)})
    local function apply()
        tbl[key] = Color3.fromRGB(ch.R, ch.G, ch.B); pv.BackgroundColor3 = tbl[key]; if cb then cb(tbl[key]) end
    end
    for _, k in ipairs({"R", "G", "B"}) do
        setters[k] = addSlider(page, name .. " " .. k, 0, 255, ch, k, 1, apply)
    end
    pv.BackgroundColor3 = tbl[key]
    return function(col) ch.R, ch.G, ch.B = col.R * 255, col.G * 255, col.B * 255; for _, k in ipairs({"R", "G", "B"}) do setters[k](ch[k]) end end
end

------------------------------------------------------------------ PAGES
local pSA, pVis, pFog, pWorld, pTheme, pSet = addTab("Silent Aim"), addTab("Visuals"), addTab("Fog"), addTab("World"), addTab("Theme"), addTab("Settings")
local SA, ESP, FOG, W = S.SA, S.ESP, S.Fog, S.World

-- Silent Aim
section(pSA, "General")
addToggle(pSA, "Enable Silent Aim", SA, "Enabled")
addKeybind(pSA, "Toggle Key", SA, "Key")
addDropdown(pSA, "Activation", {"Mouse1", "Mouse2", "Always"}, SA, "Activation")
section(pSA, "Targeting")
addDropdown(pSA, "Aim Part", {"Head", "Torso", "HumanoidRootPart", "Closest Part", "Random"}, SA, "AimPart")
addDropdown(pSA, "Target Mode", {"Closest To Cursor", "Closest Distance", "Lowest Health"}, SA, "TargetMode")
addToggle(pSA, "Sticky Target", SA, "Sticky")
addSlider(pSA, "FOV Radius", 10, 800, SA, "FOV", 5, nil, "px")
addToggle(pSA, "Show FOV Circle", SA, "ShowFOV")
addToggle(pSA, "Show Target Tracer", SA, "ShowTracer")
addSlider(pSA, "Max Distance", 50, 3000, SA, "MaxDist", 10, nil, " st")
addSlider(pSA, "Hit Chance", 1, 100, SA, "HitChance", 1, nil, "%")
section(pSA, "Checks")
addToggle(pSA, "Wall Check", SA, "WallCheck")
addToggle(pSA, "Team Check", SA, "TeamCheck")
addToggle(pSA, "Knocked Check (K.O)", SA, "KnockedCheck")
section(pSA, "Prediction")
addDropdown(pSA, "Prediction Mode", {"Manual", "Auto (Ping)"}, SA, "PredMode")
addSlider(pSA, "Manual Prediction (s)", 0, 0.5, SA, "Prediction", 0.005)
addSlider(pSA, "Ping Multiplier", 0.1, 3, SA, "PingMult", 0.05, nil, "x")
addToggle(pSA, "Ignore Vertical Velocity", SA, "IgnoreY")
addSlider(pSA, "Vertical Velocity Mult", 0, 1, SA, "YMult", 0.05, nil, "x")
addToggle(pSA, "Velocity Resolver (anti-desync)", SA, "Resolver")
addSlider(pSA, "Aim Offset Y", -3, 3, SA, "OffsetY", 0.1, nil, " st")

-- Visuals
section(pVis, "ESP")
if not hasDrawing then section(pVis, "Drawing API missing: boxes/text disabled") end
addToggle(pVis, "Enable ESP", ESP, "Enabled")
addToggle(pVis, "Boxes", ESP, "Boxes")
addToggle(pVis, "Box Fill", ESP, "Fill")
addToggle(pVis, "Player Names", ESP, "Names")
addToggle(pVis, "Distance (m)", ESP, "Distance")
addToggle(pVis, "Health Bar", ESP, "Health")
addToggle(pVis, "Held Tool", ESP, "Tool")
addToggle(pVis, "Tracers", ESP, "Tracers")
addDropdown(pVis, "Tracer Origin", {"Bottom", "Center", "Mouse"}, ESP, "TracerOrigin")
addToggle(pVis, "Chams (Highlight)", ESP, "Chams")
addToggle(pVis, "Use Team Color", ESP, "TeamColor")
addSlider(pVis, "ESP Max Distance", 100, 5000, ESP, "MaxDist", 50, nil, " st")
addColor(pVis, "ESP Color", ESP, "Color")

-- Fog
local origFog = {Start = Lighting.FogStart, End = Lighting.FogEnd, Color = Lighting.FogColor}
local atmos
local function applyFog()
    if FOG.Enabled then
        if not atmos or not atmos.Parent then atmos = new("Atmosphere", {Name = "BellFog", Parent = Lighting}) end
        atmos.Density = FOG.Density; atmos.Haze = FOG.Haze; atmos.Color = FOG.Color; atmos.Decay = FOG.Color
        Lighting.FogStart = FOG.Start; Lighting.FogEnd = FOG.End; Lighting.FogColor = FOG.Color
    else
        if atmos then atmos:Destroy(); atmos = nil end
        Lighting.FogStart = origFog.Start; Lighting.FogEnd = origFog.End; Lighting.FogColor = origFog.Color
    end
end
section(pFog, "Fog")
addToggle(pFog, "Enable Fog", FOG, "Enabled", applyFog)
addSlider(pFog, "Density", 0, 1, FOG, "Density", 0.01, applyFog)
addSlider(pFog, "Haze", 0, 10, FOG, "Haze", 0.1, applyFog)
addSlider(pFog, "Fog Start", 0, 2000, FOG, "Start", 10, applyFog)
addSlider(pFog, "Fog End", 20, 5000, FOG, "End", 10, applyFog)
addColor(pFog, "Fog Color", FOG, "Color", applyFog)

-- World
local origLight = {Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, GlobalShadows = Lighting.GlobalShadows, ClockTime = Lighting.ClockTime}
local function applyWorld()
    if W.Fullbright then
        Lighting.Brightness = 2; Lighting.Ambient = Color3.new(1, 1, 1); Lighting.GlobalShadows = false
    else
        Lighting.Brightness = origLight.Brightness; Lighting.Ambient = origLight.Ambient; Lighting.GlobalShadows = origLight.GlobalShadows
    end
    if W.TimeEnabled then Lighting.ClockTime = W.Time else Lighting.ClockTime = origLight.ClockTime end
end
section(pWorld, "World")
addToggle(pWorld, "Fullbright", W, "Fullbright", applyWorld)
addToggle(pWorld, "Custom Time", W, "TimeEnabled", applyWorld)
addSlider(pWorld, "Time of Day", 0, 24, W, "Time", 0.1, applyWorld)
addToggle(pWorld, "Custom Field of View", W, "FOVEnabled")
addSlider(pWorld, "Field of View", 40, 120, W, "FOV", 1)

-- Theme
section(pTheme, "Preset")
local presetState = {Name = "Pastel Blue / White"}
local presetNames = {}
for n in pairs(Presets) do presetNames[#presetNames + 1] = n end
table.sort(presetNames)
local setPri, setSec
addDropdown(pTheme, "Theme Preset", presetNames, presetState, "Name", function(n)
    local p = Presets[n]; if not p then return end
    Theme.Primary, Theme.Secondary = p[1], p[2]
    if setPri then setPri(p[1]); setSec(p[2]) end
    refreshTheme()
end)
setPri = addColor(pTheme, "Color 1 (Accent)", Theme, "Primary", refreshTheme)
setSec = addColor(pTheme, "Color 2 (Base)", Theme, "Secondary", refreshTheme)

-- Settings
section(pSet, "Menu")
addKeybind(pSet, "Menu Key", S.UI, "MenuKey")
addButton(pSet, "Unload Bell's GUI", function() env.BellsGUI.Unload() end)

------------------------------------------------------------------ SILENT AIM CORE
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
local Target
local PART_LISTS = {
    Head = {"Head"}, Torso = {"UpperTorso", "Torso"}, HumanoidRootPart = {"HumanoidRootPart"},
    Closest = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Torso"},
}
local function validPlayer(plr)
    if plr == LP then return end
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end
    if SA.TeamCheck and plr.Team ~= nil and plr.Team == LP.Team then return end
    if SA.KnockedCheck then
        local be = char:FindFirstChild("BodyEffects"); local ko = be and be:FindFirstChild("K.O")
        if ko and ko.Value == true then return end
    end
    return char, hum, hrp
end
local function visible(part, char)
    rayParams.FilterDescendantsInstances = {LP.Character, char, Camera}
    local o = Camera.CFrame.Position
    return workspace:Raycast(o, part.Position - o, rayParams) == nil
end
local function pickPart(char, mouse)
    local m = SA.AimPart
    if m == "Closest Part" then
        local best, bd = nil, math.huge
        for _, n in ipairs(PART_LISTS.Closest) do
            local p = char:FindFirstChild(n)
            if p then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                if on and d < bd then best, bd = p, d end
            end
        end
        return best
    elseif m == "Random" then
        local list = {}
        for _, n in ipairs(PART_LISTS.Closest) do local p = char:FindFirstChild(n); if p then list[#list + 1] = p end end
        return list[math.random(1, #list)]
    end
    for _, n in ipairs(PART_LISTS[m] or {"Head"}) do local p = char:FindFirstChild(n); if p then return p end end
end
local function predictedPos(part, hum)
    local vel = part.AssemblyLinearVelocity
    if SA.Resolver and hum and (vel.Magnitude > 120 or (vel * Vector3.new(1, 0, 1)).Magnitude < 0.5 and hum.MoveDirection.Magnitude > 0.1) then
        vel = hum.MoveDirection * hum.WalkSpeed
    end
    vel = Vector3.new(vel.X, SA.IgnoreY and 0 or vel.Y * SA.YMult, vel.Z)
    local t = SA.Prediction
    if SA.PredMode == "Auto (Ping)" then
        local ok, ping = pcall(function() return LP:GetNetworkPing() end)
        t = ((ok and ping or 0.08) * SA.PingMult) + 0.02
    end
    return part.Position + vel * t + Vector3.new(0, SA.OffsetY, 0)
end
local function acquire()
    local mouse = UIS:GetMouseLocation()
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if SA.Sticky and Target and Target.plr.Parent then
        local char, hum = validPlayer(Target.plr)
        if char and Target.part.Parent == char then Target.hum = hum; return end
    end
    local best, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        local char, hum, hrp = validPlayer(plr)
        if char then
            local part = pickPart(char, mouse)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                local mdist = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                local wdist = myHRP and (hrp.Position - myHRP.Position).Magnitude or (hrp.Position - Camera.CFrame.Position).Magnitude
                if on and mdist <= SA.FOV and wdist <= SA.MaxDist and (not SA.WallCheck or visible(part, char)) then
                    local score = SA.TargetMode == "Closest Distance" and wdist or SA.TargetMode == "Lowest Health" and hum.Health or mdist
                    if not bestScore or score < bestScore then best, bestScore = {plr = plr, part = part, hum = hum}, score end
                end
            end
        end
    end
    Target = best
end
local touchHeld = 0
connect(UIS.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.Touch then touchHeld += 1 end end)
connect(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.Touch then touchHeld = math.max(0, touchHeld - 1) end end)
local function active()
    if SA.Activation == "Always" then return true end
    local b = SA.Activation == "Mouse2" and Enum.UserInputType.MouseButton2 or Enum.UserInputType.MouseButton1
    return UIS:IsMouseButtonPressed(b) or (SA.Activation == "Mouse1" and touchHeld > 0)
end

local fovCircle = draw("Circle", {Thickness = 1.5, NumSides = 64, Filled = false, Visible = false})
local tracer = draw("Line", {Thickness = 1.5, Visible = false})
local dot = draw("Circle", {Radius = 4, Filled = true, NumSides = 16, Visible = false})
local wasActive, rolled = false, true
local savedCF

connect(RunService.RenderStepped, function()
    local mouse = UIS:GetMouseLocation()
    if SA.Enabled then acquire() else Target = nil end
    if fovCircle then
        fovCircle.Visible = SA.Enabled and SA.ShowFOV
        fovCircle.Position = mouse; fovCircle.Radius = SA.FOV; fovCircle.Color = Theme.Primary
    end
    if tracer and dot then
        local show = SA.Enabled and SA.ShowTracer and Target ~= nil
        tracer.Visible, dot.Visible = show, show
        if show then
            local sp = Camera:WorldToViewportPoint(predictedPos(Target.part, Target.hum))
            tracer.From = mouse; tracer.To = Vector2.new(sp.X, sp.Y); tracer.Color = Theme.Primary
            dot.Position = Vector2.new(sp.X, sp.Y); dot.Color = Theme.Primary
        end
    end
    local act = SA.Enabled and active()
    if act and not wasActive then rolled = math.random(1, 100) <= SA.HitChance end
    wasActive = act
    if W.FOVEnabled then Camera.FieldOfView = W.FOV end
end)

-- aim AFTER the frame is drawn so the next input read sees the aimed camera...
connect(RunService.Heartbeat, function()
    if not (SA.Enabled and Target and rolled and active() and Target.part.Parent) then return end
    local pos = predictedPos(Target.part, Target.hum)
    local cf = Camera.CFrame
    local ml = UIS:GetMouseLocation()
    local dm = Camera:ViewportPointToRay(ml.X, ml.Y).Direction.Unit
    local dt = (pos - cf.Position).Unit
    local axis = dm:Cross(dt)
    if axis.Magnitude < 1e-4 then return end
    savedCF = cf
    Camera.CFrame = CFrame.new(cf.Position) * CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(dm:Dot(dt), -1, 1))) * (cf - cf.Position)
end)
-- ...and restore BEFORE the next frame renders (so you never see the snap)
RunService:BindToRenderStep("BellsGUI_Restore", Enum.RenderPriority.First.Value, function()
    if savedCF then Camera.CFrame = savedCF; savedCF = nil end
end)

------------------------------------------------------------------ ESP
local objs = {}
local function makeESP(plr)
    if plr == LP or objs[plr] then return end
    local o = {
        Outline = draw("Square", {Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0)}),
        Box = draw("Square", {Thickness = 1.5, Filled = false}),
        Fill = draw("Square", {Filled = true, Transparency = 0.15}),
        Name = draw("Text", {Size = 14, Center = true, Outline = true}),
        Dist = draw("Text", {Size = 13, Center = true, Outline = true}),
        Tool = draw("Text", {Size = 12, Center = true, Outline = true}),
        HBg = draw("Line", {Thickness = 4, Color = Color3.new(0, 0, 0)}),
        HBar = draw("Line", {Thickness = 2}),
        Tracer = draw("Line", {Thickness = 1}),
        Cham = new("Highlight", {FillTransparency = 0.6, OutlineTransparency = 0, Enabled = false, Parent = gui}),
    }
    objs[plr] = o
end
local function hideESP(o) for k, d in pairs(o) do if k ~= "Cham" and d then d.Visible = false end end; o.Cham.Enabled = false end
local function removeESP(plr)
    local o = objs[plr]; if not o then return end
    for k, d in pairs(o) do pcall(function() if k == "Cham" then d:Destroy() else d:Remove() end end) end
    objs[plr] = nil
end
for _, p in ipairs(Players:GetPlayers()) do makeESP(p) end
connect(Players.PlayerAdded, makeESP)
connect(Players.PlayerRemoving, removeESP)

connect(RunService.RenderStepped, function()
    for plr, o in pairs(objs) do
        hideESP(o)
        if ESP.Enabled then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
                local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                if on and dist <= ESP.MaxDist then
                    local col = ESP.TeamColor and plr.TeamColor.Color or ESP.Color
                    local tp = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.8, 0))
                    local bp = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
                    local h = math.abs(bp.Y - tp.Y); local w = h * 0.6
                    local pos, size = Vector2.new(sp.X - w / 2, tp.Y), Vector2.new(w, h)
                    if ESP.Boxes then
                        o.Outline.Position, o.Outline.Size, o.Outline.Visible = pos, size, true
                        o.Box.Position, o.Box.Size, o.Box.Color, o.Box.Visible = pos, size, col, true
                    end
                    if ESP.Fill then o.Fill.Position, o.Fill.Size, o.Fill.Color, o.Fill.Visible = pos, size, col, true end
                    if ESP.Names then o.Name.Text = plr.DisplayName; o.Name.Position = Vector2.new(sp.X, tp.Y - 17); o.Name.Color = col; o.Name.Visible = true end
                    local yb = bp.Y + 2
                    if ESP.Distance then o.Dist.Text = string.format("[%dm]", dist * 0.28); o.Dist.Position = Vector2.new(sp.X, yb); o.Dist.Color = Color3.new(1, 1, 1); o.Dist.Visible = true; yb += 14 end
                    if ESP.Tool then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then o.Tool.Text = tool.Name; o.Tool.Position = Vector2.new(sp.X, yb); o.Tool.Color = col; o.Tool.Visible = true end
                    end
                    if ESP.Health then
                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        local x = pos.X - 5
                        o.HBg.From, o.HBg.To, o.HBg.Visible = Vector2.new(x, pos.Y + h), Vector2.new(x, pos.Y), true
                        o.HBar.From, o.HBar.To = Vector2.new(x, pos.Y + h), Vector2.new(x, pos.Y + h - h * pct)
                        o.HBar.Color = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(90, 255, 130), pct); o.HBar.Visible = true
                    end
                    if ESP.Tracers then
                        local vs = Camera.ViewportSize
                        local from = ESP.TracerOrigin == "Bottom" and Vector2.new(vs.X / 2, vs.Y) or ESP.TracerOrigin == "Center" and vs / 2 or UIS:GetMouseLocation()
                        o.Tracer.From, o.Tracer.To, o.Tracer.Color, o.Tracer.Visible = from, Vector2.new(sp.X, bp.Y), col, true
                    end
                end
                if ESP.Chams and char then o.Cham.Adornee = char; o.Cham.FillColor = ESP.TeamColor and plr.TeamColor.Color or ESP.Color; o.Cham.OutlineColor = Color3.new(1, 1, 1); o.Cham.Enabled = true end
            end
        end
    end
end)

------------------------------------------------------------------ INPUT / UNLOAD
connect(UIS.InputBegan, function(i, gp)
    if gp then return end
    if i.KeyCode == S.UI.MenuKey then main.Visible = not main.Visible
    elseif i.KeyCode == SA.Key then SA.Enabled = not SA.Enabled end
end)

env.BellsGUI = {}
function env.BellsGUI.Unload()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep("BellsGUI_Restore") end)
    for plr in pairs(objs) do removeESP(plr) end
    for _, d in ipairs(drawings) do pcall(function() d:Remove() end) end
    FOG.Enabled = false; W.Fullbright = false; W.TimeEnabled = false
    applyFog(); applyWorld()
    gui:Destroy(); env.BellsGUI = nil
end
print("[Bell's GUI] loaded - press " .. S.UI.MenuKey.Name .. " to toggle the menu.")

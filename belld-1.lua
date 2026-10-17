--[[
    Pastel Silent Aim - universal silent aim + visuals GUI
    Theme: white + pastel blue (fully recolorable in Settings, 2-color system)
    Needs an executor with: hookmetamethod, getnamecallmethod, newcclosure, checkcaller, Drawing
    Menu key: RightShift (or tap the round button on mobile)
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.PastelSA and env.PastelSA.Unload then pcall(env.PastelSA.Unload) end

newcclosure = newcclosure or function(f) return f end
checkcaller = checkcaller or function() return false end

--// State / Config
local State = {Unloaded = false, Target = nil, AimPart = nil, AimPos = nil, KeyDown = false, Ping = 0.1, RandName = "Head"}
local Conns = {}
local function connect(sig, fn) local c = sig:Connect(fn); table.insert(Conns, c); return c end

local Cfg = {
    Aim = {
        Enabled = false, KeyMode = "Always", Key = nil,
        FOV = 150, ShowFOV = true, FOVFilled = false, FOVColor = Color3.fromRGB(168, 208, 255),
        Part = "Head", Priority = "Closest to Cursor", Sticky = false,
        MaxDistance = 1500, HitChance = 100,
        TeamCheck = true, VisCheck = false, AliveCheck = true, FFCheck = true,
        Prediction = true, PredMode = "Auto (Ping)", PredAmount = 0.135, PingMult = 1.0, YScale = 0.5, RandomOffset = 0,
        HookRaycast = true, HookFindPart = true, HookMouse = true, HookScreenRay = true,
        ShowLine = true, ShowDot = true,
    },
    ESP = {
        Enabled = false, TeamCheck = true, MaxDistance = 2000, TextSize = 13,
        Box = true, Fill = false, FillOpacity = 0.15, Name = true, DisplayName = false, Distance = true,
        Health = true, HealthText = false, Weapon = false, Tracer = false, TracerOrigin = "Bottom",
        HeadDot = false, Skeleton = false, Chams = false, ChamFill = 0.6,
        Color = Color3.fromRGB(168, 208, 255), TeamColors = false,
        HighlightTarget = true, TargetColor = Color3.fromRGB(255, 150, 170),
    },
    World = {
        Fog = false, FogMode = "Both", FogDensity = 0.35, FogColor = Color3.fromRGB(200, 220, 255), FogHaze = 2,
        Fullbright = false, TimeEnabled = false, Time = 14, FOVEnabled = false, CamFOV = 90,
    },
    MenuKey = Enum.KeyCode.RightShift,
}

--// Theme (two colors: Primary + Accent)
local Theme = {Primary = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(168, 208, 255), binds = {}}
function Theme:Get()
    local p, a = self.Primary, self.Accent
    local lum = 0.299 * p.R + 0.587 * p.G + 0.114 * p.B
    local text = lum < 0.5 and Color3.fromRGB(238, 242, 255) or Color3.fromRGB(48, 58, 84)
    local alum = 0.299 * a.R + 0.587 * a.G + 0.114 * a.B
    return {
        Bg = p, Panel = p:Lerp(a, 0.14), Element = p:Lerp(a, 0.28), Accent = a,
        Text = text, Sub = text:Lerp(p, 0.45), Off = text:Lerp(p, 0.78), Stroke = p:Lerp(a, 0.55),
        AccText = alum > 0.55 and Color3.fromRGB(48, 58, 84) or Color3.new(1, 1, 1),
    }
end
function Theme:Bind(fn) self.Cur = self.Cur or self:Get(); table.insert(self.binds, fn); fn(self.Cur) end
function Theme:Apply() self.Cur = self:Get(); for _, f in ipairs(self.binds) do pcall(f, self.Cur) end end

--// Helpers
local function new(class, props)
    local i = Instance.new(class)
    local parent = props and props.Parent
    for k, v in pairs(props or {}) do if k ~= "Parent" then i[k] = v end end
    if parent then i.Parent = parent end
    return i
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 6), Parent = o}) end
local function randName() local s = "" for _ = 1, 12 do s = s .. string.char(math.random(97, 122)) end return s end
local function guiParent()
    if gethui then local ok, h = pcall(gethui); if ok and h then return h end end
    local ok = pcall(function() return CoreGui.Name end)
    return ok and CoreGui or LP:WaitForChild("PlayerGui")
end

-- =====================================================================
--  CORE LOGIC
-- =====================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function sameTeam(plr) return plr.Team ~= nil and plr.Team == LP.Team end

local function isVisible(part, char)
    rayParams.FilterDescendantsInstances = {LP.Character, Camera}
    local origin = Camera.CFrame.Position
    local res = workspace:Raycast(origin, part.Position - origin, rayParams)
    return res == nil or res.Instance:IsDescendantOf(char)
end

local function aimActive()
    local A = Cfg.Aim
    if not A.Enabled then return false end
    if A.KeyMode == "Always" or not A.Key then return true end
    return State.KeyDown
end

local function validPlayer(plr)
    if plr == LP then return end
    local A = Cfg.Aim
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if A.AliveCheck and hum.Health <= 0 then return end
    if A.TeamCheck and sameTeam(plr) then return end
    if A.FFCheck and char:FindFirstChildOfClass("ForceField") then return end
    return char, hum, hrp
end

local function getPart(char, mousePos)
    local m = Cfg.Aim.Part
    if m == "Head" then return char:FindFirstChild("Head")
    elseif m == "Torso" then return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    elseif m == "HumanoidRootPart" then return char:FindFirstChild("HumanoidRootPart")
    elseif m == "Random" then return char:FindFirstChild(State.RandName) or char:FindFirstChild("HumanoidRootPart")
    else -- Closest Part
        local best, bd
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local sp, on = Camera:WorldToViewportPoint(p.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                    if not bd or d < bd then best, bd = p, d end
                end
            end
        end
        return best or char:FindFirstChild("HumanoidRootPart")
    end
end

local function evaluate(plr, mousePos, ignoreFOV)
    local char, hum, hrp = validPlayer(plr)
    if not char then return end
    local A = Cfg.Aim
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    if dist > A.MaxDistance then return end
    local part = getPart(char, mousePos)
    if not part then return end
    local sp, on = Camera:WorldToViewportPoint(part.Position)
    if not on then return end
    local d2 = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
    if not ignoreFOV and d2 > A.FOV then return end
    if A.VisCheck and not isVisible(part, char) then return end
    local score = d2
    if A.Priority == "Closest Distance" then score = dist
    elseif A.Priority == "Lowest Health" then score = hum.Health end
    return part, hrp, score
end

local function predictionAmount()
    local A = Cfg.Aim
    if A.PredMode == "Manual" then return A.PredAmount end
    return State.Ping * A.PingMult
end

local function computeAimPos(part, hrp)
    local A = Cfg.Aim
    local pos = part.Position
    if A.Prediction then
        local v = hrp.AssemblyLinearVelocity
        pos = pos + Vector3.new(v.X, v.Y * A.YScale, v.Z) * predictionAmount()
    end
    if A.RandomOffset > 0 then
        local r = A.RandomOffset
        pos = pos + Vector3.new((math.random() - 0.5) * r, (math.random() - 0.5) * r, (math.random() - 0.5) * r)
    end
    return pos
end

local function shouldRedirect()
    return State.AimPos ~= nil and (Cfg.Aim.HitChance >= 100 or math.random(1, 100) <= Cfg.Aim.HitChance)
end

--// Hooks
local hooked = false
if hookmetamethod and getnamecallmethod then
    hooked = pcall(function()
        local oldNC
        oldNC = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if State.Unloaded or not State.AimPos or checkcaller() then return oldNC(self, ...) end
            local method = getnamecallmethod()
            local A = Cfg.Aim
            if self == workspace then
                if method == "Raycast" and A.HookRaycast then
                    local args = {...}
                    local n = select("#", ...)
                    if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" and shouldRedirect() then
                        args[2] = (State.AimPos - args[1]).Unit * args[2].Magnitude
                        return oldNC(self, table.unpack(args, 1, n))
                    end
                elseif (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and A.HookFindPart then
                    local args = {...}
                    local n = select("#", ...)
                    if typeof(args[1]) == "Ray" and shouldRedirect() then
                        local r = args[1]
                        args[1] = Ray.new(r.Origin, (State.AimPos - r.Origin).Unit * r.Direction.Magnitude)
                        return oldNC(self, table.unpack(args, 1, n))
                    end
                end
            elseif self == Camera and A.HookScreenRay and (method == "ScreenPointToRay" or method == "ViewportPointToRay") then
                if shouldRedirect() then
                    local o = Camera.CFrame.Position
                    return Ray.new(o, (State.AimPos - o).Unit)
                end
            end
            return oldNC(self, ...)
        end))

        local oldIdx
        oldIdx = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if self == Mouse and not State.Unloaded and State.AimPos and Cfg.Aim.HookMouse and not checkcaller() then
                if key == "Hit" and shouldRedirect() then return CFrame.new(State.AimPos)
                elseif key == "Target" and shouldRedirect() then return State.AimPart end
            end
            return oldIdx(self, key)
        end))
    end)
end

--// Drawing objects
local hasDrawing = pcall(function() Drawing.new("Line"):Remove() end)
local FOVCircle, TargetLine, TargetDot
if hasDrawing then
    FOVCircle = Drawing.new("Circle"); FOVCircle.NumSides = 64; FOVCircle.Thickness = 1.5; FOVCircle.Transparency = 1
    TargetLine = Drawing.new("Line"); TargetLine.Thickness = 1.5; TargetLine.Transparency = 1
    TargetDot = Drawing.new("Circle"); TargetDot.Radius = 4; TargetDot.Filled = true; TargetDot.NumSides = 16; TargetDot.Transparency = 1
end

local function updateTarget()
    Camera = workspace.CurrentCamera
    local A = Cfg.Aim
    local mousePos = UIS:GetMouseLocation()

    if hasDrawing then
        FOVCircle.Visible = A.Enabled and A.ShowFOV
        FOVCircle.Position = mousePos
        FOVCircle.Radius = A.FOV
        FOVCircle.Color = A.FOVColor
        FOVCircle.Filled = A.FOVFilled
        FOVCircle.Transparency = A.FOVFilled and 0.9 or 1
        if A.FOVFilled then FOVCircle.Transparency = 0.15 end
    end

    if not aimActive() then
        State.Target, State.AimPart, State.AimPos = nil, nil, nil
        if hasDrawing then TargetLine.Visible = false; TargetDot.Visible = false end
        return
    end

    local part, hrp
    if A.Sticky and State.Target then
        part, hrp = evaluate(State.Target, mousePos, true)
        if not part then State.Target = nil end
    end
    if not part then
        local bestScore
        for _, plr in ipairs(Players:GetPlayers()) do
            local p, h, score = evaluate(plr, mousePos, false)
            if p and (not bestScore or score < bestScore) then
                bestScore, part, hrp, State.Target = score, p, h, plr
            end
        end
        if not part then State.Target = nil end
    end

    if part then
        State.AimPart = part
        State.AimPos = computeAimPos(part, hrp)
        if hasDrawing then
            local sp = Camera:WorldToViewportPoint(State.AimPos)
            local sv = Vector2.new(sp.X, sp.Y)
            TargetLine.Visible = A.ShowLine; TargetLine.From = mousePos; TargetLine.To = sv; TargetLine.Color = A.FOVColor
            TargetDot.Visible = A.ShowDot; TargetDot.Position = sv; TargetDot.Color = A.FOVColor
        end
    else
        State.AimPart, State.AimPos = nil, nil
        if hasDrawing then TargetLine.Visible = false; TargetDot.Visible = false end
    end
end

-- =====================================================================
--  ESP
-- =====================================================================
local ESPObjs = {}
local ESPFolder = new("Folder", {Name = randName(), Parent = guiParent()})

local R15 = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}}
local R6 = {{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

local function draw(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function createESP()
    local black = Color3.new(0, 0, 0)
    return {
        D = {
            Fill = draw("Square", {Filled = true, Visible = false}),
            BoxOut = draw("Square", {Thickness = 3, Filled = false, Color = black, Visible = false}),
            Box = draw("Square", {Thickness = 1, Filled = false, Visible = false}),
            Name = draw("Text", {Center = true, Outline = true, Font = 2, Visible = false}),
            Dist = draw("Text", {Center = true, Outline = true, Font = 2, Visible = false}),
            Tool = draw("Text", {Center = true, Outline = true, Font = 2, Visible = false}),
            HPOut = draw("Line", {Thickness = 4, Color = black, Visible = false}),
            HP = draw("Line", {Thickness = 2, Visible = false}),
            HPText = draw("Text", {Center = true, Outline = true, Font = 2, Visible = false}),
            Tracer = draw("Line", {Thickness = 1, Visible = false}),
            Head = draw("Circle", {NumSides = 16, Thickness = 1, Visible = false}),
        },
        Skel = {},
    }
end

local function hideESP(o)
    for _, d in pairs(o.D) do d.Visible = false end
    for _, l in ipairs(o.Skel) do l.Visible = false end
    if o.Cham then o.Cham.Enabled = false end
end

local function destroyESP(o)
    for _, d in pairs(o.D) do pcall(function() d:Remove() end) end
    for _, l in ipairs(o.Skel) do pcall(function() l:Remove() end) end
    if o.Cham then o.Cham:Destroy() end
end

local function updateESP(plr, o)
    local E = Cfg.ESP
    local D = o.D
    if not E.Enabled then return hideESP(o) end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return hideESP(o) end
    if E.TeamCheck and sameTeam(plr) then return hideESP(o) end
    local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
    local meters = dist * 0.28
    if meters > E.MaxDistance then return hideESP(o) end

    local color = E.Color
    if E.TeamColors then color = plr.TeamColor.Color end
    if E.HighlightTarget and plr == State.Target then color = E.TargetColor end

    -- chams
    if E.Chams then
        if not o.Cham then o.Cham = new("Highlight", {Parent = ESPFolder, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}) end
        o.Cham.Adornee = char; o.Cham.Enabled = true
        o.Cham.FillColor = color; o.Cham.OutlineColor = color
        o.Cham.FillTransparency = E.ChamFill; o.Cham.OutlineTransparency = 0
    elseif o.Cham then o.Cham.Enabled = false end

    local pos, on = Camera:WorldToViewportPoint(hrp.Position)
    if not on then
        for _, d in pairs(D) do d.Visible = false end
        for _, l in ipairs(o.Skel) do l.Visible = false end
        return
    end
    local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.7, 0))
    local bot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
    local h = math.abs(bot.Y - top.Y)
    local w = h * 0.58
    local x, y = pos.X - w / 2, top.Y
    local size, bpos = Vector2.new(w, h), Vector2.new(x, y)

    D.Box.Visible = E.Box; D.BoxOut.Visible = E.Box
    D.Box.Size = size; D.Box.Position = bpos; D.Box.Color = color
    D.BoxOut.Size = size; D.BoxOut.Position = bpos

    D.Fill.Visible = E.Fill; D.Fill.Size = size; D.Fill.Position = bpos; D.Fill.Color = color; D.Fill.Transparency = E.FillOpacity

    D.Name.Visible = E.Name
    D.Name.Text = E.DisplayName and plr.DisplayName or plr.Name
    D.Name.Size = E.TextSize; D.Name.Color = Color3.new(1, 1, 1); D.Name.Position = Vector2.new(pos.X, y - E.TextSize - 3)

    local belowY = y + h + 2
    D.Dist.Visible = E.Distance
    D.Dist.Text = string.format("[%dm]", math.floor(meters + 0.5))
    D.Dist.Size = E.TextSize - 1; D.Dist.Color = Color3.fromRGB(220, 230, 255); D.Dist.Position = Vector2.new(pos.X, belowY)
    if E.Distance then belowY = belowY + E.TextSize end

    local tool = char:FindFirstChildOfClass("Tool")
    D.Tool.Visible = E.Weapon
    D.Tool.Text = tool and tool.Name or "none"
    D.Tool.Size = E.TextSize - 1; D.Tool.Color = Color3.fromRGB(255, 235, 200); D.Tool.Position = Vector2.new(pos.X, belowY)

    local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    local hx = x - 5
    D.HPOut.Visible = E.Health; D.HPOut.From = Vector2.new(hx, y - 1); D.HPOut.To = Vector2.new(hx, y + h + 1)
    D.HP.Visible = E.Health; D.HP.From = Vector2.new(hx, y + h); D.HP.To = Vector2.new(hx, y + h - h * frac)
    D.HP.Color = Color3.fromRGB(255, 110, 110):Lerp(Color3.fromRGB(120, 235, 150), frac)
    D.HPText.Visible = E.HealthText; D.HPText.Text = tostring(math.floor(hum.Health))
    D.HPText.Size = E.TextSize - 2; D.HPText.Color = Color3.new(1, 1, 1)
    D.HPText.Position = Vector2.new(hx - 12, y + h - h * frac - 6)

    if E.Tracer then
        local vp = Camera.ViewportSize
        local from = E.TracerOrigin == "Center" and Vector2.new(vp.X / 2, vp.Y / 2)
            or E.TracerOrigin == "Mouse" and UIS:GetMouseLocation() or Vector2.new(vp.X / 2, vp.Y)
        D.Tracer.Visible = true; D.Tracer.From = from; D.Tracer.To = Vector2.new(pos.X, y + h); D.Tracer.Color = color
    else D.Tracer.Visible = false end

    local head = char:FindFirstChild("Head")
    if E.HeadDot and head then
        local hp = Camera:WorldToViewportPoint(head.Position)
        D.Head.Visible = true; D.Head.Position = Vector2.new(hp.X, hp.Y); D.Head.Radius = math.max(3, h * 0.07); D.Head.Color = color
    else D.Head.Visible = false end

    if E.Skeleton then
        local pairsList = char:FindFirstChild("UpperTorso") and R15 or R6
        for i, pr in ipairs(pairsList) do
            if not o.Skel[i] then o.Skel[i] = draw("Line", {Thickness = 1, Visible = false}) end
            local line = o.Skel[i]
            local a, b = char:FindFirstChild(pr[1]), char:FindFirstChild(pr[2])
            if a and b then
                local pa, oa = Camera:WorldToViewportPoint(a.Position)
                local pb, ob = Camera:WorldToViewportPoint(b.Position)
                line.Visible = oa and ob
                line.From = Vector2.new(pa.X, pa.Y); line.To = Vector2.new(pb.X, pb.Y); line.Color = color
            else line.Visible = false end
        end
    else
        for _, l in ipairs(o.Skel) do l.Visible = false end
    end
end

local function updateAllESP()
    if not hasDrawing then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            if not ESPObjs[plr] then ESPObjs[plr] = createESP() end
            updateESP(plr, ESPObjs[plr])
        end
    end
end

connect(Players.PlayerRemoving, function(plr)
    if ESPObjs[plr] then destroyESP(ESPObjs[plr]); ESPObjs[plr] = nil end
    if State.Target == plr then State.Target = nil end
end)

-- =====================================================================
--  WORLD (fog / lighting / camera)
-- =====================================================================
local Orig = {
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows, FOV = Camera.FieldOfView,
}
local Atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local AtmosOrig = Atmos and {Density = Atmos.Density, Color = Atmos.Color, Haze = Atmos.Haze, Offset = Atmos.Offset}
local OurAtmos
local applied = {Fog = false, Bright = false, Time = false, FOV = false}

local function getAtmos()
    if Atmos and Atmos.Parent then return Atmos end
    if not OurAtmos then OurAtmos = new("Atmosphere", {Parent = Lighting}) end
    return OurAtmos
end

local function restoreFog()
    Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = Orig.FogEnd, Orig.FogStart, Orig.FogColor
    if Atmos and Atmos.Parent and AtmosOrig then
        for k, v in pairs(AtmosOrig) do Atmos[k] = v end
    end
    if OurAtmos then OurAtmos:Destroy(); OurAtmos = nil end
end

local function updateWorld()
    local W = Cfg.World
    if W.Fog then
        applied.Fog = true
        local d = W.FogDensity
        if W.FogMode ~= "Atmosphere" then
            local fogEnd = d <= 0.001 and 1e5 or (30 + (1 - d) ^ 2 * 3000)
            Lighting.FogEnd = fogEnd; Lighting.FogStart = fogEnd * 0.05; Lighting.FogColor = W.FogColor
        else
            Lighting.FogEnd = Orig.FogEnd; Lighting.FogStart = Orig.FogStart
        end
        if W.FogMode ~= "Lighting Fog" then
            local at = getAtmos()
            at.Density = d; at.Color = W.FogColor; at.Haze = W.FogHaze; at.Offset = 0
        elseif OurAtmos then OurAtmos:Destroy(); OurAtmos = nil end
    elseif applied.Fog then
        applied.Fog = false; restoreFog()
    end

    if W.Fullbright then
        applied.Bright = true
        Lighting.Brightness = 2; Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(190, 190, 190); Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
    elseif applied.Bright then
        applied.Bright = false
        Lighting.Brightness, Lighting.GlobalShadows = Orig.Brightness, Orig.GlobalShadows
        Lighting.Ambient, Lighting.OutdoorAmbient = Orig.Ambient, Orig.OutdoorAmbient
    end

    if W.TimeEnabled then applied.Time = true; Lighting.ClockTime = W.Time
    elseif applied.Time then applied.Time = false; Lighting.ClockTime = Orig.ClockTime end

    if W.FOVEnabled then applied.FOV = true; Camera.FieldOfView = W.CamFOV
    elseif applied.FOV then applied.FOV = false; Camera.FieldOfView = Orig.FOV end
end

-- =====================================================================
--  GUI LIBRARY
-- =====================================================================
local Gui = new("ScreenGui", {Name = randName(), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000, IgnoreGuiInset = true})
if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
Gui.Parent = guiParent()

local function Lbl(parent, text, props, sub)
    local l = new("TextLabel", {BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    for k, v in pairs(props or {}) do l[k] = v end
    Theme:Bind(function(t) l.TextColor3 = sub and t.Sub or t.Text end)
    return l
end

local function Notify(msg)
    local t = Theme.Cur
    local f = new("TextLabel", {
        Text = "  " .. msg .. "  ", Font = Enum.Font.GothamMedium, TextSize = 13, AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 30), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
        BackgroundColor3 = t.Accent, TextColor3 = t.AccText, Parent = Gui,
    })
    corner(f, 8)
    task.delay(3, function()
        if f.Parent then
            TweenService:Create(f, TweenInfo.new(0.4), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
            task.wait(0.45); f:Destroy()
        end
    end)
end

local Main = new("Frame", {Size = UDim2.fromOffset(580, 400), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BorderSizePixel = 0, Parent = Gui})
corner(Main, 12)
local MainStroke = new("UIStroke", {Thickness = 1.5, Parent = Main})
local Scale = new("UIScale", {Scale = 1, Parent = Main})
Theme:Bind(function(t) Main.BackgroundColor3 = t.Bg; MainStroke.Color = t.Stroke end)

local Top = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, Parent = Main})
corner(Top, 12)
local TopFix = new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BorderSizePixel = 0, Parent = Top})
local Dot = new("Frame", {Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 14, 0.5, -5), BorderSizePixel = 0, Parent = Top})
corner(Dot, 5)
Lbl(Top, "Pastel Silent  |  universal", {Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -90, 1, 0), Font = Enum.Font.GothamBold, TextSize = 14})
local CloseBtn = new("TextButton", {Text = "-", Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -38, 0.5, -12), BorderSizePixel = 0, AutoButtonColor = false, Parent = Top})
corner(CloseBtn, 6)
Theme:Bind(function(t)
    Top.BackgroundColor3 = t.Panel; TopFix.BackgroundColor3 = t.Panel; Dot.BackgroundColor3 = t.Accent
    CloseBtn.BackgroundColor3 = t.Element; CloseBtn.TextColor3 = t.Text
end)

-- dragging
do
    local dragging, startPos, startIn
    Top.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startIn = true, Main.Position, i.Position
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startIn) / Scale.Scale
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local TabBar = new("Frame", {Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0, 130, 1, -40), BorderSizePixel = 0, Parent = Main})
new("UIListLayout", {Padding = UDim.new(0, 5), Parent = TabBar})
new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = TabBar})
Theme:Bind(function(t) TabBar.BackgroundColor3 = t.Bg end)
local Content = new("Frame", {Position = UDim2.new(0, 130, 0, 40), Size = UDim2.new(1, -130, 1, -40), BackgroundTransparency = 1, Parent = Main})

local function toggleMenu() Main.Visible = not Main.Visible end
CloseBtn.MouseButton1Click:Connect(toggleMenu)

-- floating button (mobile friendly)
local Float = new("TextButton", {Text = "=", Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 10, 0.5, -19), AutoButtonColor = false, Parent = Gui})
corner(Float, 19)
local FloatStroke = new("UIStroke", {Thickness = 1.5, Parent = Float})
Theme:Bind(function(t) Float.BackgroundColor3 = t.Accent; Float.TextColor3 = t.AccText; FloatStroke.Color = t.Stroke end)
Float.MouseButton1Click:Connect(toggleMenu)

local Tabs, Page = {}, {}
Page.__index = Page
local selectedTab

local function paintTabs()
    local t = Theme.Cur
    for _, tab in ipairs(Tabs) do
        local sel = tab == selectedTab
        tab.Btn.BackgroundColor3 = sel and t.Accent or t.Panel
        tab.Btn.TextColor3 = sel and t.AccText or t.Text
    end
end
Theme:Bind(paintTabs)

local function CreateTab(name)
    local btn = new("TextButton", {Text = name, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, AutoButtonColor = false, Parent = TabBar})
    corner(btn, 8)
    local frame = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, Parent = Content,
    })
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame})
    new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = frame})
    Theme:Bind(function(t) frame.ScrollBarImageColor3 = t.Accent end)
    local tab = setmetatable({Frame = frame, Btn = btn, n = 0}, Page)
    table.insert(Tabs, tab)
    btn.MouseButton1Click:Connect(function()
        if selectedTab then selectedTab.Frame.Visible = false end
        selectedTab = tab; frame.Visible = true; paintTabs()
    end)
    if not selectedTab then selectedTab = tab; frame.Visible = true; paintTabs() end
    return tab
end

local function Row(page, height)
    page.n = page.n + 1
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, LayoutOrder = page.n, Parent = page.Frame})
    corner(f, 8)
    Theme:Bind(function(t) f.BackgroundColor3 = t.Panel end)
    return f
end

function Page:Section(text)
    self.n = self.n + 1
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = self.n, Parent = self.Frame})
    local bar = new("Frame", {Size = UDim2.fromOffset(4, 14), Position = UDim2.new(0, 2, 0.5, -7), BorderSizePixel = 0, Parent = f})
    corner(bar, 2)
    Theme:Bind(function(t) bar.BackgroundColor3 = t.Accent end)
    Lbl(f, string.upper(text), {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -14, 1, 0), Font = Enum.Font.GothamBold, TextSize = 11}, true)
end

function Page:Label(text)
    local row = Row(self, 26)
    local l = Lbl(row, text, {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 12}, true)
    return {Set = function(s) l.Text = s end}
end

function Page:Button(text, cb)
    local row = Row(self, 32)
    local b = new("TextButton", {Text = text, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 0.5, -12), BorderSizePixel = 0, AutoButtonColor = false, Parent = row})
    corner(b, 6)
    Theme:Bind(function(t) b.BackgroundColor3 = t.Accent; b.TextColor3 = t.AccText end)
    b.MouseButton1Click:Connect(cb)
end

function Page:Toggle(text, default, cb)
    local row = Row(self, 32)
    local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row})
    Lbl(row, text, {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -70, 1, 0)})
    local sw = new("Frame", {Size = UDim2.fromOffset(38, 18), Position = UDim2.new(1, -48, 0.5, -9), BorderSizePixel = 0, Parent = row})
    corner(sw, 9)
    local knob = new("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sw})
    corner(knob, 7)
    local state = default and true or false
    local function paint()
        local t = Theme.Cur
        sw.BackgroundColor3 = state and t.Accent or t.Off
        TweenService:Create(knob, TweenInfo.new(0.12), {Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)}):Play()
    end
    Theme:Bind(paint)
    local obj = {}
    function obj.Set(v, silent) state = v and true or false; paint(); if not silent then cb(state) end end
    hit.MouseButton1Click:Connect(function() obj.Set(not state) end)
    return obj
end

local function sliderBar(parent, pos, size, min, max, default, dec, cb)
    local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Position = pos, Size = size, Parent = parent})
    local track = new("Frame", {BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, -3), Size = UDim2.new(1, 0, 0, 6), Parent = hit})
    corner(track, 3)
    local fill = new("Frame", {BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = track})
    corner(fill, 3)
    Theme:Bind(function(t) track.BackgroundColor3 = t.Off; fill.BackgroundColor3 = t.Accent end)
    local mult = 10 ^ dec
    local obj = {}
    function obj.Set(v, silent)
        v = math.clamp(v, min, max)
        v = math.floor(v * mult + 0.5) / mult
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        if not silent then cb(v) end
    end
    local dragging = false
    local function fromX(x)
        local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        obj.Set(min + (max - min) * math.clamp(rel, 0, 1))
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromX(i.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    connect(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    obj.Set(default, true)
    return obj
end

function Page:Slider(text, min, max, default, dec, suffix, cb)
    local row = Row(self, 46)
    Lbl(row, text, {Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -90, 0, 18)})
    local vl = Lbl(row, "", {Position = UDim2.new(1, -80, 0, 4), Size = UDim2.fromOffset(70, 18), TextXAlignment = Enum.TextXAlignment.Right}, true)
    local function fmt(v) return string.format("%." .. dec .. "f", v) .. (suffix or "") end
    vl.Text = fmt(default)
    return sliderBar(row, UDim2.new(0, 10, 0, 24), UDim2.new(1, -20, 0, 18), min, max, default, dec, function(v) vl.Text = fmt(v); cb(v) end)
end

function Page:Dropdown(text, options, default, cb)
    local row = Row(self, 32)
    row.ClipsDescendants = true
    Lbl(row, text, {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -160, 0, 32)})
    local btn = new("TextButton", {Text = default .. "  v", Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.fromOffset(140, 22), Position = UDim2.new(1, -150, 0, 5), BorderSizePixel = 0, AutoButtonColor = false, Parent = row})
    corner(btn, 6)
    Theme:Bind(function(t) btn.BackgroundColor3 = t.Element; btn.TextColor3 = t.Text end)
    local current, items, open = default, {}, false
    local function repaint()
        local t = Theme.Cur
        for name, b in pairs(items) do
            b.BackgroundColor3 = name == current and t.Accent or t.Element
            b.TextColor3 = name == current and t.AccText or t.Text
        end
    end
    local function setOpen(o) open = o; row.Size = UDim2.new(1, 0, 0, o and (40 + #options * 24) or 32) end
    for i, name in ipairs(options) do
        local b = new("TextButton", {Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, 36 + (i - 1) * 24), BorderSizePixel = 0, AutoButtonColor = false, Parent = row})
        corner(b, 6)
        items[name] = b
        b.MouseButton1Click:Connect(function() current = name; btn.Text = name .. "  v"; repaint(); cb(name); setOpen(false) end)
    end
    Theme:Bind(repaint)
    btn.MouseButton1Click:Connect(function() setOpen(not open) end)
    return {Set = function(v) current = v; btn.Text = v .. "  v"; repaint() end}
end

function Page:Keybind(text, default, cb)
    local row = Row(self, 32)
    Lbl(row, text, {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -120, 1, 0)})
    local btn = new("TextButton", {Text = default and default.Name or "None", Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.fromOffset(90, 22), Position = UDim2.new(1, -100, 0, 5), BorderSizePixel = 0, AutoButtonColor = false, Parent = row})
    corner(btn, 6)
    Theme:Bind(function(t) btn.BackgroundColor3 = t.Element; btn.TextColor3 = t.Text end)
    local listening = false
    btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..." end)
    connect(UIS.InputBegan, function(i)
        if not listening then return end
        local key
        if i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            key = i.KeyCode ~= Enum.KeyCode.Escape and i.KeyCode or nil
        elseif i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3 then
            listening = false; key = i.UserInputType
        else return end
        btn.Text = key and key.Name or "None"
        cb(key)
    end)
end

function Page:ColorPicker(text, default, cb)
    local row = Row(self, 32)
    row.ClipsDescendants = true
    local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = row})
    Lbl(row, text, {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -70, 0, 32)})
    local sw = new("Frame", {Size = UDim2.fromOffset(40, 18), Position = UDim2.new(1, -50, 0, 7), BorderSizePixel = 0, BackgroundColor3 = default, Parent = row})
    corner(sw, 6)
    local swStroke = new("UIStroke", {Thickness = 1, Parent = sw})
    Theme:Bind(function(t) swStroke.Color = t.Stroke end)
    local color, open, sliders = default, false, {}
    local chans = {"R", "G", "B"}
    local vals = {"R", "G", "B"}
    local function apply(silent)
        color = Color3.fromRGB(sliders[1].v, sliders[2].v, sliders[3].v)
        sw.BackgroundColor3 = color
        if not silent then cb(color) end
    end
    for i = 1, 3 do
        local y = 38 + (i - 1) * 26
        Lbl(row, chans[i], {Position = UDim2.new(0, 10, 0, y), Size = UDim2.fromOffset(14, 18), TextSize = 12}, true)
        local vl = Lbl(row, "", {Position = UDim2.new(1, -44, 0, y), Size = UDim2.fromOffset(34, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right}, true)
        local init = math.floor(({default.R, default.G, default.B})[i] * 255 + 0.5)
        local s = {v = init}
        local bar = sliderBar(row, UDim2.new(0, 28, 0, y), UDim2.new(1, -78, 0, 18), 0, 255, init, 0, function(v) s.v = v; vl.Text = tostring(v); apply(false) end)
        vl.Text = tostring(init)
        s.bar, s.vl = bar, vl
        sliders[i] = s
    end
    hit.MouseButton1Click:Connect(function() open = not open; row.Size = UDim2.new(1, 0, 0, open and 118 or 32) end)
    return {Set = function(c, silent)
        local rgb = {c.R, c.G, c.B}
        for i = 1, 3 do
            local v = math.floor(rgb[i] * 255 + 0.5)
            sliders[i].v = v; sliders[i].vl.Text = tostring(v); sliders[i].bar.Set(v, true)
        end
        apply(silent)
    end}
end

-- =====================================================================
--  MENUS
-- =====================================================================
local Aim = CreateTab("Silent Aim")
local Vis = CreateTab("Visuals")
local Set = CreateTab("Settings")
local A, E, W = Cfg.Aim, Cfg.ESP, Cfg.World

--// Silent Aim
Aim:Section("Main")
Aim:Toggle("Enable Silent Aim", A.Enabled, function(v) A.Enabled = v end)
Aim:Dropdown("Key Mode", {"Always", "Hold", "Toggle"}, A.KeyMode, function(v) A.KeyMode = v; State.KeyDown = false end)
Aim:Keybind("Aim Key", A.Key, function(k) A.Key = k; State.KeyDown = false end)

Aim:Section("Targeting")
Aim:Dropdown("Aim Part", {"Head", "Torso", "HumanoidRootPart", "Closest Part", "Random"}, A.Part, function(v) A.Part = v end)
Aim:Dropdown("Target Priority", {"Closest to Cursor", "Closest Distance", "Lowest Health"}, A.Priority, function(v) A.Priority = v end)
Aim:Toggle("Sticky Target", A.Sticky, function(v) A.Sticky = v end)
Aim:Slider("FOV Radius", 10, 800, A.FOV, 0, "px", function(v) A.FOV = v end)
Aim:Slider("Max Distance", 50, 5000, A.MaxDistance, 0, " studs", function(v) A.MaxDistance = v end)
Aim:Slider("Hit Chance", 1, 100, A.HitChance, 0, "%", function(v) A.HitChance = v end)

Aim:Section("Checks")
Aim:Toggle("Team Check", A.TeamCheck, function(v) A.TeamCheck = v end)
Aim:Toggle("Visible Check (wall check)", A.VisCheck, function(v) A.VisCheck = v end)
Aim:Toggle("Alive Check", A.AliveCheck, function(v) A.AliveCheck = v end)
Aim:Toggle("ForceField Check", A.FFCheck, function(v) A.FFCheck = v end)

Aim:Section("Prediction")
Aim:Toggle("Enable Prediction", A.Prediction, function(v) A.Prediction = v end)
Aim:Dropdown("Prediction Mode", {"Auto (Ping)", "Manual"}, A.PredMode, function(v) A.PredMode = v end)
local pingLabel = Aim:Label("Current ping: -- ms  |  auto amount: --")
Aim:Slider("Manual Amount", 0, 0.5, A.PredAmount, 3, "", function(v) A.PredAmount = v end)
Aim:Slider("Auto Ping Multiplier", 0, 3, A.PingMult, 2, "x", function(v) A.PingMult = v end)
Aim:Slider("Vertical (Y) Scale", 0, 1.5, A.YScale, 2, "x", function(v) A.YScale = v end)
Aim:Slider("Random Offset", 0, 3, A.RandomOffset, 2, " studs", function(v) A.RandomOffset = v end)

Aim:Section("Redirect Methods")
Aim:Toggle("Workspace:Raycast", A.HookRaycast, function(v) A.HookRaycast = v end)
Aim:Toggle("FindPartOnRay (legacy)", A.HookFindPart, function(v) A.HookFindPart = v end)
Aim:Toggle("Mouse.Hit / Mouse.Target", A.HookMouse, function(v) A.HookMouse = v end)
Aim:Toggle("Camera:ScreenPointToRay", A.HookScreenRay, function(v) A.HookScreenRay = v end)

Aim:Section("Indicators")
Aim:Toggle("Show FOV Circle", A.ShowFOV, function(v) A.ShowFOV = v end)
Aim:Toggle("Fill FOV Circle", A.FOVFilled, function(v) A.FOVFilled = v end)
Aim:ColorPicker("FOV / Indicator Color", A.FOVColor, function(c) A.FOVColor = c end)
Aim:Toggle("Target Line", A.ShowLine, function(v) A.ShowLine = v end)
Aim:Toggle("Target Dot", A.ShowDot, function(v) A.ShowDot = v end)

--// Visuals
Vis:Section("ESP")
Vis:Toggle("Enable ESP", E.Enabled, function(v) E.Enabled = v end)
Vis:Toggle("Hide Teammates", E.TeamCheck, function(v) E.TeamCheck = v end)
Vis:Toggle("Boxes", E.Box, function(v) E.Box = v end)
Vis:Toggle("Box Fill", E.Fill, function(v) E.Fill = v end)
Vis:Slider("Fill Opacity", 0.05, 1, E.FillOpacity, 2, "", function(v) E.FillOpacity = v end)
Vis:Toggle("Player Names", E.Name, function(v) E.Name = v end)
Vis:Toggle("Use Display Names", E.DisplayName, function(v) E.DisplayName = v end)
Vis:Toggle("Distance (m)", E.Distance, function(v) E.Distance = v end)
Vis:Toggle("Health Bar", E.Health, function(v) E.Health = v end)
Vis:Toggle("Health Number", E.HealthText, function(v) E.HealthText = v end)
Vis:Toggle("Held Weapon", E.Weapon, function(v) E.Weapon = v end)
Vis:Toggle("Tracers", E.Tracer, function(v) E.Tracer = v end)
Vis:Dropdown("Tracer Origin", {"Bottom", "Center", "Mouse"}, E.TracerOrigin, function(v) E.TracerOrigin = v end)
Vis:Toggle("Head Dot", E.HeadDot, function(v) E.HeadDot = v end)
Vis:Toggle("Skeleton", E.Skeleton, function(v) E.Skeleton = v end)
Vis:Toggle("Chams (Highlight)", E.Chams, function(v) E.Chams = v end)
Vis:Slider("Cham Fill Transparency", 0, 1, E.ChamFill, 2, "", function(v) E.ChamFill = v end)
Vis:Slider("ESP Max Distance", 100, 5000, E.MaxDistance, 0, "m", function(v) E.MaxDistance = v end)
Vis:Slider("Text Size", 10, 22, E.TextSize, 0, "", function(v) E.TextSize = v end)
Vis:Section("ESP Colors")
Vis:ColorPicker("ESP Color", E.Color, function(c) E.Color = c end)
Vis:Toggle("Use Team Colors", E.TeamColors, function(v) E.TeamColors = v end)
Vis:Toggle("Highlight Aim Target", E.HighlightTarget, function(v) E.HighlightTarget = v end)
Vis:ColorPicker("Aim Target Color", E.TargetColor, function(c) E.TargetColor = c end)

Vis:Section("Fog")
Vis:Toggle("Enable Custom Fog", W.Fog, function(v) W.Fog = v end)
Vis:Dropdown("Fog Mode", {"Both", "Atmosphere", "Lighting Fog"}, W.FogMode, function(v) W.FogMode = v end)
Vis:Slider("Fog Density", 0, 1, W.FogDensity, 2, "", function(v) W.FogDensity = v end)
Vis:ColorPicker("Fog Color", W.FogColor, function(c) W.FogColor = c end)
Vis:Slider("Fog Haze", 0, 10, W.FogHaze, 1, "", function(v) W.FogHaze = v end)

Vis:Section("World & Camera")
Vis:Toggle("Fullbright", W.Fullbright, function(v) W.Fullbright = v end)
Vis:Toggle("Custom Time of Day", W.TimeEnabled, function(v) W.TimeEnabled = v end)
Vis:Slider("Time", 0, 24, W.Time, 1, "h", function(v) W.Time = v end)
Vis:Toggle("Custom Camera FOV", W.FOVEnabled, function(v) W.FOVEnabled = v end)
Vis:Slider("Camera FOV", 40, 120, W.CamFOV, 0, "", function(v) W.CamFOV = v end)

--// Settings (theme = 2 colors)
local Presets = {
    ["White & Pastel Blue"] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(168, 208, 255)},
    ["White & Pastel Pink"] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 184, 210)},
    ["White & Mint"] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 235, 205)},
    ["White & Lavender"] = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(201, 187, 255)},
    ["Midnight & Pastel Blue"] = {Color3.fromRGB(28, 32, 48), Color3.fromRGB(140, 190, 255)},
}
local presetNames = {"White & Pastel Blue", "White & Pastel Pink", "White & Mint", "White & Lavender", "Midnight & Pastel Blue"}
local pickP, pickA

Set:Section("Theme (2 colors)")
Set:Dropdown("Preset", presetNames, "White & Pastel Blue", function(name)
    local p = Presets[name]
    Theme.Primary, Theme.Accent = p[1], p[2]
    pickP.Set(p[1], true); pickA.Set(p[2], true)
    Theme:Apply()
end)
pickP = Set:ColorPicker("Base Color (backgrounds)", Theme.Primary, function(c) Theme.Primary = c; Theme:Apply() end)
pickA = Set:ColorPicker("Accent Color (highlights)", Theme.Accent, function(c) Theme.Accent = c; Theme:Apply() end)
Set:Slider("UI Scale", 0.6, 1.4, 1, 2, "x", function(v) Scale.Scale = v end)

Set:Section("Menu")
Set:Keybind("Toggle Menu Key", Cfg.MenuKey, function(k) Cfg.MenuKey = k or Enum.KeyCode.RightShift end)

local function Unload()
    State.Unloaded = true
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for _, o in pairs(ESPObjs) do destroyESP(o) end
    if hasDrawing then
        for _, d in ipairs({FOVCircle, TargetLine, TargetDot}) do pcall(function() d:Remove() end) end
    end
    Cfg.World.Fog = false; Cfg.World.Fullbright = false; Cfg.World.TimeEnabled = false; Cfg.World.FOVEnabled = false
    pcall(updateWorld)
    pcall(function() Gui:Destroy() end)
    pcall(function() ESPFolder:Destroy() end)
    env.PastelSA = nil
end
Set:Button("Unload Script", Unload)
env.PastelSA = {Unload = Unload}

-- =====================================================================
--  MAIN LOOPS / INPUT
-- =====================================================================
connect(UIS.InputBegan, function(i, gp)
    if gp then return end
    if i.KeyCode == Cfg.MenuKey then toggleMenu() end
    local k = A.Key
    if k and (i.KeyCode == k or i.UserInputType == k) then
        if A.KeyMode == "Hold" then State.KeyDown = true
        elseif A.KeyMode == "Toggle" then State.KeyDown = not State.KeyDown end
    end
end)
connect(UIS.InputEnded, function(i)
    local k = A.Key
    if k and A.KeyMode == "Hold" and (i.KeyCode == k or i.UserInputType == k) then State.KeyDown = false end
end)

local lastSlow = 0
connect(RunService.RenderStepped, function()
    if State.Unloaded then return end
    local now = os.clock()
    if now - lastSlow > 0.35 then
        lastSlow = now
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        State.Ping = ok and v / 1000 or State.Ping
        local names = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Torso"}
        State.RandName = names[math.random(1, #names)]
        pingLabel.Set(string.format("Current ping: %d ms  |  auto amount: %.3f", State.Ping * 1000, State.Ping * A.PingMult))
    end
    updateTarget()
    updateAllESP()
    updateWorld()
end)

Notify(hooked and "Loaded - RightShift toggles the menu" or "Loaded, but hooks unavailable: silent aim won't work")
if not hasDrawing then Notify("Drawing API missing: ESP/FOV circle disabled") end

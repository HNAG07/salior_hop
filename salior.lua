-- ============================================================
--  Sailor Piece | YamatoBoss Auto-Farm  (Full Auto – No Toggles)
--  Tự động: Tele lên đầu boss → Farm → Hop server → lặp lại
-- ============================================================

-- [[ CONFIG – chỉnh ở đây ]]
local CFG = {
    BossName          = "YamatoBoss",
    SkillKeys         = { "Z", "X", "C", "V", "F" },
    SkillDelay        = 0.1,
    AttackRange       = 8,
    LockOffset        = 5,      -- studs trên đầu boss
    WeaponSlot        = 2,      -- slot vũ khí (bấm số)
    HakiKey           = "G",
    HakiInterval      = 10,     -- nhấn G mỗi X giây
    DropWait          = 10,     -- chờ lấy drop sau khi boss chết (giây)
    HopStabilize      = 10,     -- chờ sau khi hop (giây)
    HopThreshold      = 60,     -- nếu timer spawn > X giây thì hop
    DefaultCooldown   = 90,
    Debug             = true,
}

-- [[ SERVICES ]]
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local TweenService    = game:GetService("TweenService")

local LP              = Players.LocalPlayer
local Char            = LP.Character or LP.CharacterAdded:Wait()
local HRP             = Char:WaitForChild("HumanoidRootPart")
local Hum             = Char:WaitForChild("Humanoid")

-- ============================================================
--  MINIMAL STATUS UI
-- ============================================================
local function buildUI()
    local old = LP.PlayerGui:FindFirstChild("FarmStatusUI")
    if old then old:Destroy() end

    local SG = Instance.new("ScreenGui")
    SG.Name = "FarmStatusUI"
    SG.ResetOnSpawn = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.Parent = LP.PlayerGui

    -- Card nền
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(0, 280, 0, 80)
    Card.Position = UDim2.new(0, 16, 1, -96)
    Card.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
    Card.BorderSizePixel = 0
    Card.Active = true
    Card.Parent = SG
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    -- Stripe màu bên trái
    local Stripe = Instance.new("Frame")
    Stripe.Size = UDim2.new(0, 3, 1, -16)
    Stripe.Position = UDim2.new(0, 0, 0, 8)
    Stripe.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    Stripe.BorderSizePixel = 0
    Stripe.Parent = Card
    Instance.new("UICorner", Stripe).CornerRadius = UDim.new(1, 0)

    -- Gradient stripe
    local sg = Instance.new("UIGradient")
    sg.Rotation = 90
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247)),
    })
    sg.Parent = Stripe

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -16, 0, 20)
    Title.Position = UDim2.new(0, 12, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "⚔  YamatoBoss  ·  Auto Farm"
    Title.TextColor3 = Color3.fromRGB(200, 200, 240)
    Title.TextSize = 12
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Card

    -- Status dot
    local Dot = Instance.new("Frame")
    Dot.Name = "Dot"
    Dot.Size = UDim2.new(0, 7, 0, 7)
    Dot.Position = UDim2.new(0, 12, 0, 36)
    Dot.BackgroundColor3 = Color3.fromRGB(99, 241, 130)
    Dot.BorderSizePixel = 0
    Dot.Parent = Card
    Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

    -- Status text
    local Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.Size = UDim2.new(1, -28, 0, 18)
    Status.Position = UDim2.new(0, 24, 0, 32)
    Status.BackgroundTransparency = 1
    Status.Text = "Starting..."
    Status.TextColor3 = Color3.fromRGB(170, 170, 210)
    Status.TextSize = 12
    Status.Font = Enum.Font.Gotham
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Card

    -- Server info
    local SrvLabel = Instance.new("TextLabel")
    SrvLabel.Name = "SrvLabel"
    SrvLabel.Size = UDim2.new(1, -12, 0, 14)
    SrvLabel.Position = UDim2.new(0, 12, 0, 56)
    SrvLabel.BackgroundTransparency = 1
    SrvLabel.Text = "Server: " .. tostring(game.JobId):sub(1, 16) .. "..."
    SrvLabel.TextColor3 = Color3.fromRGB(90, 90, 120)
    SrvLabel.TextSize = 10
    SrvLabel.Font = Enum.Font.Gotham
    SrvLabel.TextXAlignment = Enum.TextXAlignment.Left
    SrvLabel.Parent = Card

    -- Drag
    local drag, dStart, dPos
    Card.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dStart = inp.Position
            dPos = Card.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    Card.InputChanged:Connect(function(inp)
        if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dStart
            Card.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X, dPos.Y.Scale, dPos.Y.Offset + d.Y)
        end
    end)

    -- Entrance anim
    Card.BackgroundTransparency = 1
    TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()

    -- Trả về hàm cập nhật status
    local DOT_ACTIVE   = Color3.fromRGB(99, 241, 130)
    local DOT_IDLE     = Color3.fromRGB(255, 180, 50)
    local DOT_HOP      = Color3.fromRGB(99, 180, 255)

    return function(msg, mode)
        Status.Text = msg
        if mode == "farm" then
            Dot.BackgroundColor3 = DOT_ACTIVE
        elseif mode == "hop" then
            Dot.BackgroundColor3 = DOT_HOP
        else
            Dot.BackgroundColor3 = DOT_IDLE
        end
    end
end

local setStatus = buildUI()

-- ============================================================
--  LOGGING
-- ============================================================
local function log(msg, mode)
    if CFG.Debug then print("[AutoFarm] " .. msg) end
    setStatus(msg, mode or "idle")
end

-- ============================================================
--  KEY PRESS
-- ============================================================
-- VK codes (Windows) + Roblox Enum names cho phím số
local VK = { Z=90, X=88, C=67, V=86, F=70, G=71, ["1"]=49, ["2"]=50, ["3"]=51, ["4"]=52, ["5"]=53 }
local KC_NUM = { ["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four", ["5"]="Five" }

local function pressKey(k)
    local vk = VK[k:upper()] or VK[k]

    -- Ưu tiên keypress() với VK code (executor API)
    if vk and type(keypress) == "function" then
        pcall(keypress,   vk)
        task.wait(0.05)
        pcall(keyrelease, vk)
        return
    end

    -- VIM fallback — dùng EnumItem đúng
    local enumName = KC_NUM[k] or k  -- "2" → "Two", "Z" → "Z"
    local kc = Enum.KeyCode[enumName]
    if kc then
        pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true,  kc, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, kc, false, game)
        end)
    end
end

-- ============================================================
--  CHARACTER HELPERS
-- ============================================================
local function refreshChar()
    Char = LP.Character or LP.CharacterAdded:Wait()
    HRP  = Char:WaitForChild("HumanoidRootPart")
    Hum  = Char:WaitForChild("Humanoid")
    task.wait(1)
    log("Character ready")
end

-- Equip slot WeaponSlot
local function equipSlot()
    -- Nhấn phím số slot
    pressKey(tostring(CFG.WeaponSlot))
    task.wait(0.15)
    -- Fallback EquipTool nếu chưa cầm
    if not Char:FindFirstChildOfClass("Tool") then
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            local tools = {}
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") then table.insert(tools, t) end
            end
            local t = tools[CFG.WeaponSlot]
            if t and Hum then Hum:EquipTool(t) end
        end
    end
end

local function attackOnce()
    local tool = Char:FindFirstChildOfClass("Tool")
    if not tool then
        equipSlot()
        task.wait(0.3) -- chờ equip xong
        tool = Char:FindFirstChildOfClass("Tool")
    end
    if tool then
        -- Đảm bảo Humanoid đang giữ tool trước khi Activate
        if Hum and Hum.Health > 0 then
            if tool.Parent ~= Char then
                Hum:EquipTool(tool)
                task.wait(0.2)
            end
            pcall(function() tool:Activate() end)
        end
    end
end

local function useSkills()
    for _, k in ipairs(CFG.SkillKeys) do
        pressKey(k)
        task.wait(CFG.SkillDelay)
    end
end

-- ============================================================
--  BOSS DETECTION
-- ============================================================
local function findBoss()
    local b = workspace:FindFirstChild(CFG.BossName, true)
    if b then
        local h = b:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return b end
    end
    return nil
end

local function bossPos(boss)
    if boss.PrimaryPart then return boss.PrimaryPart.Position end
    local p = boss:FindFirstChild("HumanoidRootPart")
        or boss:FindFirstChild("Root")
        or boss:FindFirstChildOfClass("BasePart")
    return p and p.Position or nil
end

-- ============================================================
--  POSITION LOCK (trên đầu boss)
-- ============================================================
local _lockConn = nil

local function stopLock()
    if _lockConn then _lockConn:Disconnect() _lockConn = nil end
end

local function lockAbove(boss)
    stopLock()
    local bh = boss:FindFirstChildOfClass("Humanoid")
    _lockConn = RunService.Heartbeat:Connect(function()
        if not boss or not boss.Parent or (bh and bh.Health <= 0) or not HRP then
            stopLock() return
        end
        local p = bossPos(boss)
        if p then HRP.CFrame = CFrame.new(p + Vector3.new(0, CFG.LockOffset, 0)) end
    end)
end

-- ============================================================
--  SPAWN TIMER
-- ============================================================
local function getSpawnTimer()
    local kws = {"spawn","respawn","appear","boss","time","wait"}
    local function scan(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                local txt  = (obj.Text or ""):lower()
                local nm   = obj.Name:lower()
                local pnm  = (obj.Parent and obj.Parent.Name or ""):lower()
                for _, kw in ipairs(kws) do
                    if txt:find(kw) or nm:find(kw) or pnm:find(kw) then
                        local m, s = txt:match("(%d+):(%d+)")
                        if m and s then return tonumber(m) * 60 + tonumber(s) end
                        local sec = txt:match("(%d+)%s*s") or txt:match("^%d+$")
                        if sec then return tonumber(sec) end
                        break
                    end
                end
            end
        end
    end
    local pg = LP:FindFirstChild("PlayerGui")
    return (pg and scan(pg)) or scan(workspace)
end

-- ============================================================
--  SERVER HOP
-- ============================================================
local _hopVisited = {}
local _hopCursor  = ""
local _hopFile    = "NotSameServers.json"
local _hour       = os.date("!*t").hour

pcall(function() _hopVisited = HttpService:JSONDecode(readfile(_hopFile)) end)
if not next(_hopVisited) then table.insert(_hopVisited, _hour) end

local function _hopOnce()
    local pid = game.PlaceId
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s"):format(
        pid, _hopCursor ~= "" and ("&cursor=" .. _hopCursor) or "")
    local ok, raw = pcall(game.HttpGet, game, url)
    if not ok then return false end
    local site = HttpService:JSONDecode(raw)
    _hopCursor = (site.nextPageCursor and site.nextPageCursor ~= "null") and site.nextPageCursor or ""
    local i = 0
    for _, sv in pairs(site.data or {}) do
        local id = tostring(sv.id)
        local ok2 = true
        for _, ex in pairs(_hopVisited) do
            if i ~= 0 then
                if id == tostring(ex) then ok2 = false end
            else
                if tonumber(_hour) ~= tonumber(ex) then
                    pcall(function() delfile(_hopFile) end)
                    _hopVisited = { _hour }
                end
            end
            i = i + 1
        end
        if ok2 and tonumber(sv.maxPlayers) > tonumber(sv.playing) then
            table.insert(_hopVisited, id)
            pcall(function() writefile(_hopFile, HttpService:JSONEncode(_hopVisited)) end)
            task.wait()
            pcall(function() TeleportService:TeleportToPlaceInstance(pid, id, LP) end)
            task.wait(4)
            return true
        end
    end
    return false
end

local function serverHop()
    log("Server hopping...", "hop")
    if not _hopOnce() and _hopCursor ~= "" then _hopOnce() end
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end

-- ============================================================
--  FARM BOSS  (tele + lock + đánh)
-- ============================================================
local function farmBoss(boss)
    log("Farming " .. boss.Name .. "...", "farm")
    local bh = boss:FindFirstChildOfClass("Humanoid")
    if not bh then return end

    equipSlot()

    -- Teleport lên đầu boss ngay
    local p = bossPos(boss)
    if p and HRP then HRP.CFrame = CFrame.new(p + Vector3.new(0, CFG.LockOffset, 0)) end

    -- Lock vị trí
    lockAbove(boss)

    while bh and bh.Health > 0 do
        -- Nếu nhân vật chết
        if not Hum or Hum.Health <= 0 then
            stopLock()
            refreshChar()
            equipSlot()
            boss = findBoss()
            if not boss then return end
            bh = boss:FindFirstChildOfClass("Humanoid")
            p = bossPos(boss)
            if p and HRP then HRP.CFrame = CFrame.new(p + Vector3.new(0, CFG.LockOffset, 0)) end
            lockAbove(boss)
        end

        attackOnce()
        useSkills()
        task.wait(0.5) -- tăng lên 0.5s để tránh spam warning
    end

    stopLock()
    log("Boss killed!", "idle")
end

-- ============================================================
--  AUTO HAKI  (nhấn G 1 lần duy nhất để bật, giữ nguyên)
-- ============================================================
task.spawn(function()
    task.wait(1.5)        -- chờ script load xong
    pressKey(CFG.HakiKey) -- bật haki 1 lần
    log("Haki activated!", "idle")
end)

-- ============================================================
--  MAIN LOOP  (tìm boss → farm → hop → lặp lại)
-- ============================================================
task.spawn(function()
    task.wait(2) -- chờ UI load
    log("Auto Farm started!", "idle")

    while true do
        local boss = findBoss()

        if boss then
            farmBoss(boss)

            -- Lấy drop rồi hop
            log("Waiting for drops...", "idle")
            task.wait(CFG.DropWait)
            serverHop()
            log("Stabilizing new server...", "hop")
            task.wait(CFG.HopStabilize)

        else
            -- Không có boss → hop ngay sang server khác
            log("No boss – hopping now...", "hop")
            serverHop()
            log("Stabilizing new server...", "hop")
            task.wait(CFG.HopStabilize)
        end
    end
end)

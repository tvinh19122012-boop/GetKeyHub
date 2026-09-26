--// ============================================================
--//  SIKE HUB · KEY SYSTEM  (paste ở ĐẦU script, trước mọi code khác)
--//  Luồng: GET KEY -> vượt link -> NHẬN KEY -> dán key -> VERIFY
--// ============================================================

local SERVER_URL = "https://getkeyhub.onrender.com" -- << SỬA: link server của bạn (KHÔNG có / ở cuối)
local SAVE_FILE  = "SIKE_key.txt" -- lưu key để tự đăng nhập khi key còn hạn

local Players = game:GetService("Players")
local Http    = game:GetService("HttpService")
local LP      = Players.LocalPlayer

-- ---------------- helpers ----------------
local function urlencode(s)
    return (tostring(s):gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function notify(title, text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = dur or 5,
        })
    end)
end

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body and body ~= "" then return body end
    local req = request or http_request or (syn and syn.request)
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and res then
            if type(res) == "table" and res.Body then return res.Body end
            if type(res) == "string" and res ~= "" then return res end
        end
    end
    return nil
end

local function getHWID()
    local ok, r = pcall(function()
        if gethwid then return gethwid() end
        return nil
    end)
    if ok and r ~= nil then
        if type(r) == "table" then r = r[1] or r[2] or "" end
        r = tostring(r):gsub("%s+", "")
        if #r >= 3 then return r end
    end
    return "UID_" .. tostring(LP and LP.UserId or 0)
end
local HWID = getHWID()

local function api(path)
    local body = httpGet(SERVER_URL .. path)
    if not body then
        return nil, "Không kết nối được server.\n(Server free có thể đang ngủ, chờ 30-60s rồi thử lại.)"
    end
    local ok2, data = pcall(function() return Http:JSONDecode(body) end)
    if not ok2 or type(data) ~= "table" then
        return nil, "Server trả về sai định dạng."
    end
    return data, nil
end

local REASONS = {
    expired    = "Key đã hết hạn 48h.\nBấm GET KEY để lấy key mới.",
    wrong_hwid = "Key này thuộc về máy khác.",
    not_found  = "Key không đúng.\nKiểm tra lại key vừa copy.",
    missing    = "Thiếu key.",
}

local function verifyKey(key)
    key = tostring(key or ""):gsub("%s+", ""):upper()
    if key == "" then return false, "Chưa nhập key." end
    local data, err = api("/api/verify?key=" .. urlencode(key) .. "&hwid=" .. urlencode(HWID))
    if not data then return false, err end
    if data.status == "success" and data.valid == true then
        return true, tonumber(data.expiresAt)
    end
    return false, REASONS[data.reason] or "Key không hợp lệ."
end

local function saveKey(key)
    pcall(function()
        if writefile then writefile(SAVE_FILE, tostring(key):gsub("%s+", "")) end
    end)
end

local function clearSavedKey()
    pcall(function()
        if delfile and isfile and isfile(SAVE_FILE) then delfile(SAVE_FILE) end
    end)
end

-- ---------------- tự đăng nhập nếu key cũ còn hạn ----------------
local passed = false
do
    local saved = nil
    pcall(function()
        if isfile and isfile(SAVE_FILE) and readfile then
            saved = tostring(readfile(SAVE_FILE) or ""):gsub("%s+", "")
        end
    end)
    if saved and saved ~= "" then
        local ok = verifyKey(saved)
        if ok then
            passed = true
            notify("SIKE HUB", "Key còn hạn — tự động đăng nhập ✔")
        else
            clearSavedKey()
        end
    end
end

-- ---------------- UI nhập key (chỉ hiện khi chưa pass) ----------------
if not passed then
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
    pcall(function()
        local old = parentGui:FindFirstChild("SikeHubKeySystem")
        if old then old:Destroy() end
    end)

    local T = {
        bg0 = Color3.fromRGB(8, 10, 15), bg1 = Color3.fromRGB(13, 16, 23),
        bg2 = Color3.fromRGB(18, 22, 32), bg3 = Color3.fromRGB(24, 29, 42),
        text = Color3.fromRGB(242, 245, 252), dim = Color3.fromRGB(148, 158, 180),
        faint = Color3.fromRGB(80, 90, 112), accent = Color3.fromRGB(88, 196, 255),
        hot = Color3.fromRGB(120, 220, 255), ok = Color3.fromRGB(72, 235, 168),
        danger = Color3.fromRGB(255, 100, 115),
    }

    local gui = Instance.new("ScreenGui")
    gui.Name = "SikeHubKeySystem"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parentGui

    local W, H = 380, 470
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
    main.BackgroundColor3 = T.bg0
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 16); mc.Parent = main
    local ms = Instance.new("UIStroke"); ms.Color = T.accent; ms.Thickness = 1; ms.Transparency = 0.6; ms.Parent = main

    local function label(txt, y, h, size, color, parent)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -48, 0, h)
        l.Position = UDim2.new(0, 24, 0, y)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.Font = Enum.Font.GothamBold
        l.TextSize = size
        l.TextColor3 = color
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextWrapped = true
        l.Parent = parent or main
        return l
    end

    -- logo + title
    local logo = Instance.new("Frame")
    logo.Size = UDim2.new(0, 46, 0, 46)
    logo.Position = UDim2.new(0, 24, 0, 20)
    logo.BackgroundColor3 = T.bg3
    logo.BorderSizePixel = 0
    logo.Parent = main
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(1, 0); lc.Parent = logo
    local lt = Instance.new("TextLabel")
    lt.Size = UDim2.new(1, 0, 1, 0); lt.BackgroundTransparency = 1
    lt.Text = "S"; lt.Font = Enum.Font.GothamBlack; lt.TextSize = 24
    lt.TextColor3 = T.hot; lt.Parent = logo

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 280, 0, 24); title.Position = UDim2.new(0, 82, 0, 22)
    title.BackgroundTransparency = 1; title.Text = "SIKE HUB"
    title.Font = Enum.Font.GothamBlack; title.TextSize = 19
    title.TextColor3 = T.text; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(0, 280, 0, 16); sub.Position = UDim2.new(0, 82, 0, 48)
    sub.BackgroundTransparency = 1; sub.Text = "KEY SYSTEM · MỖI MÁY 1 KEY · 48H"
    sub.Font = Enum.Font.Gotham; sub.TextSize = 10
    sub.TextColor3 = T.faint; sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = main

    -- status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -48, 0, 40); status.Position = UDim2.new(0, 24, 0, 78)
    status.BackgroundTransparency = 1; status.Text = "Nhập key để sử dụng script."
    status.Font = Enum.Font.Gotham; status.TextSize = 12
    status.TextColor3 = T.dim; status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top; status.TextWrapped = true
    status.Parent = main

    local function setStatus(txt, color)
        status.Text = txt
        status.TextColor3 = color or T.dim
    end

    -- key input
    label("YOUR KEY", 122, 14, 10, T.faint)
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -48, 0, 42); keyBox.Position = UDim2.new(0, 24, 0, 140)
    keyBox.BackgroundColor3 = T.bg2; keyBox.BorderSizePixel = 0
    keyBox.PlaceholderText = "SIKE-XXXX-XXXX-XXXX"
    keyBox.PlaceholderColor3 = T.faint
    keyBox.Text = ""; keyBox.Font = Enum.Font.Code; keyBox.TextSize = 14
    keyBox.TextColor3 = T.hot; keyBox.ClearTextOnFocus = false
    keyBox.Parent = main
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(0, 10); kc.Parent = keyBox
    local ks = Instance.new("UIStroke"); ks.Color = T.accent; ks.Thickness = 1; ks.Transparency = 0.6; ks.Parent = keyBox

    local function button(txt, y, color1, color2)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -48, 0, 44); b.Position = UDim2.new(0, 24, 0, y)
        b.BackgroundColor3 = color1; b.BorderSizePixel = 0
        b.Text = txt; b.Font = Enum.Font.GothamBlack; b.TextSize = 14
        b.TextColor3 = Color3.new(1, 1, 1); b.AutoButtonColor = true
        b.Parent = main
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 11); c.Parent = b
        return b
    end

    local verifyBtn = button("✔  VERIFY KEY", 192, Color3.fromRGB(30, 110, 82))

    -- divider
    local div = Instance.new("TextLabel")
    div.Size = UDim2.new(1, -48, 0, 16); div.Position = UDim2.new(0, 24, 0, 244)
    div.BackgroundTransparency = 1; div.Text = "— CHƯA CÓ KEY? —"
    div.Font = Enum.Font.GothamBold; div.TextSize = 10
    div.TextColor3 = T.faint; div.Parent = main

    local getBtn = button("📋  GET KEY (COPY LINK)", 266, Color3.fromRGB(40, 88, 140))

    -- link box (hiện link để copy tay nếu cần)
    local linkBox = Instance.new("TextBox")
    linkBox.Size = UDim2.new(1, -48, 0, 66); linkBox.Position = UDim2.new(0, 24, 0, 318)
    linkBox.BackgroundColor3 = T.bg1; linkBox.BorderSizePixel = 0
    linkBox.Text = "Bấm GET KEY để lấy link vượt..."; linkBox.Font = Enum.Font.Code; linkBox.TextSize = 11
    linkBox.TextColor3 = T.dim; linkBox.TextWrapped = true
    linkBox.TextXAlignment = Enum.TextXAlignment.Left; linkBox.TextYAlignment = Enum.TextYAlignment.Top
    linkBox.ClearTextOnFocus = false; linkBox.TextEditable = true
    linkBox.Parent = main
    local lc2 = Instance.new("UICorner"); lc2.CornerRadius = UDim.new(0, 10); lc2.Parent = linkBox
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = linkBox

    local foot = Instance.new("TextLabel")
    foot.Size = UDim2.new(1, -48, 0, 60); foot.Position = UDim2.new(0, 24, 0, 392)
    foot.BackgroundTransparency = 1
    foot.Text = "Mở link bằng trình duyệt → vượt link → bấm NHẬN KEY → dán key vào ô trên → VERIFY.\nKey ngẫu nhiên theo máy, hạn 48h."
    foot.Font = Enum.Font.Gotham; foot.TextSize = 11
    foot.TextColor3 = T.faint; foot.TextXAlignment = Enum.TextXAlignment.Left
    foot.TextYAlignment = Enum.TextYAlignment.Top; foot.TextWrapped = true
    foot.Parent = main

    -- ---------------- actions ----------------
    getBtn.MouseButton1Click:Connect(function()
        setStatus("Đang tạo link vượt...", T.dim)
        local data, err = api("/api/getlink?hwid=" .. urlencode(HWID))
        if not data then
            setStatus("✘ " .. err, T.danger)
            return
        end
        if data.status == "success" and data.link then
            linkBox.Text = data.link
            local copied = false
            pcall(function()
                if setclipboard then setclipboard(data.link); copied = true end
            end)
            if copied then
                setStatus("✔ Đã COPY link! Mở trình duyệt, vượt link để lấy key.", T.ok)
                notify("SIKE HUB", "Đã copy link vượt ✔")
            else
                setStatus("✔ Link đã hiện ở ô bên dưới — copy tay rồi mở trình duyệt vượt link.", T.ok)
            end
        else
            setStatus("✘ " .. tostring(data.message or "Lỗi tạo link."), T.danger)
        end
    end)

    verifyBtn.MouseButton1Click:Connect(function()
        setStatus("Đang kiểm tra key...", T.dim)
        local ok, info = verifyKey(keyBox.Text)
        if ok then
            saveKey(keyBox.Text)
            local left = ""
            if type(info) == "number" then
                if info <= 0 then
                    left = " (vĩnh viễn)"
                else
                    local h = math.max(0, math.floor((info / 1000 - os.time()) / 3600))
                    left = " (còn ~" .. h .. "h)"
                end
            end
            setStatus("✔ Key hợp lệ" .. left .. "! Đang mở script...", T.ok)
            notify("SIKE HUB", "Key hợp lệ ✔")
            task.wait(0.8)
            gui:Destroy()
            passed = true
        else
            setStatus("✘ " .. tostring(info), T.danger)
        end
    end)

    -- chặn script chạy tiếp cho tới khi nhập key đúng
    while not passed do
        task.wait(0.2)
    end
end

--// ============================================================
--//  TỚI ĐÂY LÀ KEY ĐÃ HỢP LỆ — CODE SCRIPT CHÍNH Ở BÊN DƯỚI
--// ============================================================


--// ================= MAIN SCRIPT: SIKE HUB =================

-- BLOX FRUITS · SIKE HUB · v7.0
for _,g in ipairs((gethui and {gethui()} or {game:GetService("CoreGui")})) do
    local o=g:FindFirstChild("BF_SikeHub"); if o then o:Destroy() end
    local l=g:FindFirstChild("SikeHubLoading"); if l then l:Destroy() end
end

local S={Players=game:GetService("Players"),RunService=game:GetService("RunService"),
    Tween=game:GetService("TweenService"),UIS=game:GetService("UserInputService"),
    RS=game:GetService("ReplicatedStorage"),WS=game:GetService("Workspace"),
    Light=game:GetService("Lighting"),TP=game:GetService("TeleportService"),
    HTTP=game:GetService("HttpService"),VU=game:GetService("VirtualUser")}
local LP=S.Players.LocalPlayer
local parentGui=(gethui and gethui()) or game:GetService("CoreGui")
local IS_MOBILE=S.UIS.TouchEnabled and not S.UIS.MouseEnabled
if not firetouchinterest then firetouchinterest=function() end end
if not fireclickdetector then fireclickdetector=function() end end

local R={}
do
    local m=S.RS:WaitForChild("Modules",15)
    if m then
        local n=m:WaitForChild("Net",10)
        if n then R.Attack=n:WaitForChild("RE/RegisterAttack",10); R.Hit=n:WaitForChild("RE/RegisterHit",10) end
    end
    local rm=S.RS:WaitForChild("Remotes",15)
    if rm then R.CommF=rm:WaitForChild("CommF_",10); R.Raids=rm:FindFirstChild("Raids"); R.Btn=rm:FindFirstChild("ButtonEnabler") end
end
local function Invoke(...)
    if not R.CommF then return nil end
    local a={...}
    local ok,r=pcall(function() return R.CommF:InvokeServer(table.unpack(a)) end)
    return ok and r or nil
end

local SEAP={[1]={[1]=true,[9792993051]=true},[2]={[4442272183]=true,[79091703265657]=true},[3]={[7449423635]=true,[100117331123089]=true}}
local PlaceId=game.PlaceId
local SeaIndex=1
for s,ids in pairs(SEAP) do if ids[PlaceId] then SeaIndex=s break end end

local MOB_DISPLAY={["God's Guard"]="Sky Guards"}
local function DisplayName(n) return MOB_DISPLAY[n] or n end

local loadingDone=false
do
    local lg=Instance.new("ScreenGui")
    lg.Name="SikeHubLoading"; lg.ResetOnSpawn=false; lg.IgnoreGuiInset=true
    lg.DisplayOrder=9999; lg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; lg.Parent=parentGui
    local function mk(c,p)
        local o=Instance.new(c)
        for k,v in pairs(p) do if k~="Parent" then pcall(function() o[k]=v end) end end
        o.Parent=p.Parent or lg; return o
    end
    local back=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=1})
    S.Tween:Create(back,TweenInfo.new(0.5),{BackgroundTransparency=0.35}):Play()
    local stage=mk("Frame",{Size=UDim2.new(0,500,0,400),Position=UDim2.new(0.5,-250,0.5,-200),BackgroundTransparency=1,ZIndex=5})
    local orbit=mk("Frame",{Size=UDim2.new(0,200,0,200),Position=UDim2.new(0.5,-100,0,30),BackgroundTransparency=1,ZIndex=6,Parent=stage})
    local rings={}
    for i,sz in ipairs({200,150,110}) do
        local r=mk("Frame",{Size=UDim2.new(0,sz,0,sz),Position=UDim2.new(0.5,-sz/2,0.5,-sz/2),BackgroundTransparency=1,ZIndex=6+i,Parent=orbit})
        mk("UICorner",{CornerRadius=UDim.new(1,0)},r)
        local col=i==1 and Color3.fromRGB(88,196,255) or i==2 and Color3.fromRGB(160,130,255) or Color3.fromRGB(120,220,255)
        local st=mk("UIStroke",{Color=col,Thickness=1.5,Transparency=1},r)
        rings[i]={f=r,s=st,sp=i==1 and 40 or i==2 and -60 or 90}
    end
    task.spawn(function()
        local t=0
        while lg.Parent do
            t=t+0.02
            for _,r in ipairs(rings) do if r.f.Parent then r.f.Rotation=t*r.sp end end
            task.wait(0.02)
        end
    end)
    local burst=mk("Frame",{Size=UDim2.new(0,80,0,80),Position=UDim2.new(0.5,-40,0.5,-40),BackgroundColor3=Color3.fromRGB(88,196,255),BackgroundTransparency=0.7,BorderSizePixel=0,ZIndex=5,Parent=orbit})
    mk("UICorner",{CornerRadius=UDim.new(1,0)},burst)
    mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(88,196,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(160,130,255))}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})},burst)
    task.spawn(function()
        while lg.Parent do
            pcall(function() S.Tween:Create(burst,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.35,Size=UDim2.new(0,110,0,110),Position=UDim2.new(0.5,-55,0.5,-55)}):Play() end)
            task.wait(1.2)
            pcall(function() S.Tween:Create(burst,TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=0.75,Size=UDim2.new(0,80,0,80),Position=UDim2.new(0.5,-40,0.5,-40)}):Play() end)
            task.wait(1.2)
        end
    end)
    local card=mk("Frame",{Size=UDim2.new(0,70,0,70),Position=UDim2.new(0.5,-35,0.5,-35),BackgroundColor3=Color3.fromRGB(10,14,22),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=10,Parent=orbit})
    mk("UICorner",{CornerRadius=UDim.new(0,20)},card)
    local cs=mk("UIStroke",{Color=Color3.fromRGB(88,196,255),Thickness=1.5,Transparency=1},card)
    local glyph=mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="S",Font=Enum.Font.GothamBlack,TextSize=40,TextColor3=Color3.fromRGB(160,220,255),TextTransparency=1,ZIndex=11,Parent=card})
    local title=mk("TextLabel",{Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,250),BackgroundTransparency=1,Text="S I K E  H U B",Font=Enum.Font.GothamBlack,TextSize=28,TextColor3=Color3.fromRGB(242,245,252),TextTransparency=1,ZIndex=7,Parent=stage})
    local sub=mk("TextLabel",{Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,292),BackgroundTransparency=1,Text="INITIALIZING",Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Color3.fromRGB(140,158,190),TextTransparency=1,ZIndex=7,Parent=stage})
    local trk=mk("Frame",{Size=UDim2.new(0,360,0,3),Position=UDim2.new(0.5,-180,0,330),BackgroundColor3=Color3.fromRGB(24,30,44),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=7,Parent=stage})
    mk("UICorner",{CornerRadius=UDim.new(1,0)},trk)
    local fill=mk("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(88,196,255),BorderSizePixel=0,ZIndex=8,Parent=trk})
    mk("UICorner",{CornerRadius=UDim.new(1,0)},fill)
    local pct=mk("TextLabel",{Size=UDim2.new(0,60,0,14),Position=UDim2.new(1,-60,0,342),BackgroundTransparency=1,Text="0%",Font=Enum.Font.Code,TextSize=11,TextColor3=Color3.fromRGB(120,220,255),TextTransparency=1,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=7,Parent=stage})
    local pctL=mk("TextLabel",{Size=UDim2.new(0,200,0,14),Position=UDim2.new(0,0,0,342),BackgroundTransparency=1,Text="loading",Font=Enum.Font.Gotham,TextSize=10,TextColor3=Color3.fromRGB(80,90,112),TextTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=stage})
    task.spawn(function()
        task.wait(0.15)
        S.Tween:Create(rings[1].s,TweenInfo.new(0.5),{Transparency=0.45}):Play()
        task.wait(0.1)
        S.Tween:Create(rings[2].s,TweenInfo.new(0.5),{Transparency=0.35}):Play()
        task.wait(0.1)
        S.Tween:Create(rings[3].s,TweenInfo.new(0.5),{Transparency=0.2}):Play()
        task.wait(0.15)
        S.Tween:Create(card,TweenInfo.new(0.5),{BackgroundTransparency=0}):Play()
        S.Tween:Create(cs,TweenInfo.new(0.5),{Transparency=0.3}):Play()
        task.wait(0.1)
        S.Tween:Create(glyph,TweenInfo.new(0.5),{TextTransparency=0}):Play()
        task.wait(0.25)
        S.Tween:Create(title,TweenInfo.new(0.5),{TextTransparency=0}):Play()
        task.wait(0.15)
        S.Tween:Create(sub,TweenInfo.new(0.5),{TextTransparency=0}):Play()
        S.Tween:Create(trk,TweenInfo.new(0.5),{BackgroundTransparency=0}):Play()
        S.Tween:Create(pct,TweenInfo.new(0.5),{TextTransparency=0}):Play()
        S.Tween:Create(pctL,TweenInfo.new(0.5),{TextTransparency=0}):Play()
    end)
    local phases={{t="loading",h="interface",d=0.25,p=15},{t="remotes",h="CommF_",d=0.25,p=35},{t="sea",h="sea "..SeaIndex,d=0.25,p=55},{t="panels",h="7 tabs",d=0.30,p=75},{t="ready",h="welcome",d=0.30,p=100}}
    task.spawn(function()
        for _,ph in ipairs(phases) do
            pctL.Text=ph.t.."  ·  "..ph.h
            pct.Text=ph.p.."%"
            S.Tween:Create(fill,TweenInfo.new(ph.d,Enum.EasingStyle.Quint),{Size=UDim2.new(ph.p/100,0,1,0)}):Play()
            task.wait(ph.d)
        end
        task.wait(0.4)
        S.Tween:Create(back,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
        for _,r in ipairs(rings) do pcall(function() S.Tween:Create(r.s,TweenInfo.new(0.4),{Transparency=1}):Play() end) end
        S.Tween:Create(glyph,TweenInfo.new(0.4),{TextTransparency=1}):Play()
        S.Tween:Create(card,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
        S.Tween:Create(cs,TweenInfo.new(0.4),{Transparency=1}):Play()
        S.Tween:Create(title,TweenInfo.new(0.4),{TextTransparency=1}):Play()
        S.Tween:Create(sub,TweenInfo.new(0.4),{TextTransparency=1}):Play()
        S.Tween:Create(fill,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
        S.Tween:Create(trk,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
        S.Tween:Create(pct,TweenInfo.new(0.4),{TextTransparency=1}):Play()
        S.Tween:Create(pctL,TweenInfo.new(0.4),{TextTransparency=1}):Play()
        S.Tween:Create(burst,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
        task.wait(0.5)
        lg:Destroy()
        loadingDone=true
        print("[SIKE HUB] loading complete")
    end)
end

local DATA={}
DATA.CHEAP={"Rocket-Rocket","Spin-Spin","Blade-Blade","Chop-Chop","Spring-Spring","Bomb-Bomb","Smoke-Smoke","Spike-Spike","Flame-Flame","Ice-Ice","Sand-Sand","Dark-Dark","Diamond-Diamond","Light-Light","Rubber-Rubber","Ghost-Ghost","Revive-Revive","Magma-Magma"}
DATA.BOSSES={
    [1]={"The Gorilla King","Bobby","Yeti","Mob Leader","Vice Admiral","Saber Expert"},
    [2]={"Warden","Chief Warden","Swan","Magma Admiral","Fishman Lord","Wysper","Thunder God","Cyborg","Ice Admiral","Ghost Captain","Don Swan","Smoke Admiral","Cursed Captain","Darkbeard","Order","Diamond","Jeremy","Fajita","Kilo Admiral","Captain Elephant","Beautiful Pirate","Longma","Hydra Leader","Trial of God"},
    [3]={"Stone","Hydra Leader","Kilo Admiral","Captain Elephant","Beautiful Pirate","Longma","Trial of God","Cake Queen","Cursed Captain","Soul Reaper","Dough King","Rip_indra","Ope","Cursed Skeleton"}}
DATA.MOBS={
    [1]={"Bandit","Monkey","Gorilla","Pirate","Brute","Desert Bandit","Desert Officer","Snow Bandit","Snowman","Chief Petty Officer","Sky Bandit","Dark Master","Prisoner","Dangerous Prisoner","Toga Warrior","Gladiator","Military Soldier","Military Spy","Fishman Warrior","Fishman Commando","God's Guard","Shanda","Royal Squad","Royal Soldier","Galley Pirate","Galley Captain"},
    [2]={"Raider","Mercenary","Swan Pirate","Factory Staff","Marine Lieutenant","Marine Captain","Zombie","Vampire","Snow Trooper","Winter Warrior","Lab Subordinate","Horned Warrior","Magma Ninja","Lava Pirate","Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Arctic Warrior","Snow Lurker","Sea Soldier","Water Fighter"},
    [3]={"Pirate Millionaire","Pistol Billionaire","Dragon Crew Warrior","Dragon Crew Archer","Hydra Enforcer","Venomous Assailant","Marine Commodore","Marine Rear Admiral","Fishman Raider","Fishman Captain","Forest Pirate","Jungle Pirate","Musketeer Pirate","Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy","Peanut Scout","Peanut President","Ice Cream Chef","Ice Cream Commander","Cookie Crafter","Cake Guard","Baking Staff","Head Baker","Cocoa Warrior","Chocolate Bar Battler","Sweet Thief","Candy Rebel","Candy Pirate","Snow Demon","Isle Outlaw","Island Boy","Isle Champion","Skull Slayer","Reef Bandit","Coral Pirate","Sea Chanter","Ocean Prophet","High Disciple","Grand Devotee"}}

local State={AutoLevelFarm=false,AutoRaidMode=false,AutoBossFarm=false,AutoChestFarm=false,AutoNearestMob=false,AutoSpecificMob=false,SelectedMob="Bandit",SelectedBoss="The Gorilla King",AutoQuest=true,AutoHaki=true,BringMobs=true,AutoEquipWeapon=true,EquipType="Melee",AutoBuyChip=false,AutoClearRaid=false,NoClip=false,InfJump=false,FPS_Shadows=false,FPS_PostFX=false,FPS_Atmosphere=false,FPS_Terrain=false,FPS_Particles=false,FPS_Decals=false,FPS_Beams=false,FPS_Accessories=false,FPS_DamageNums=false,FPS_ItemDrops=false,FPS_Decor=false,FPS_Lighting=false,AttackRange=70,BringRange=250,HoverHeight=18,Speed=170,AttackDelay=0.030,AttackBurst=1,RaidChip="Flame",Destroyed=false,SubStatus="Idle",MyLevel=1,QuestLevel=-1,KillsSinceAccept=0,TrackedMobs={},BringLast=0,LastChipBuy=0,LastSummonTry=0,RaidClickAttempts=0,PanicMode=false,Running=false,LastEquipped=nil,OriginalProps={}}
local function AnyModeOn() return State.AutoLevelFarm or State.AutoRaidMode or State.AutoBossFarm or State.AutoChestFarm or State.AutoNearestMob or State.AutoSpecificMob end

local GetRoot=function() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local GetHum=function() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function IsAlive() local h=GetHum(); return h and h.Health>0 end
local function GetMyLevel()
    local d=LP:FindFirstChild("Data")
    if d then local l=d:FindFirstChild("Level") if l then return l.Value end end
    local ls=LP:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Level") then return ls.Level.Value end
    return 1
end

local EquipWeapon
do
    local SW,ML,GN={},{},{}
    for _,n in ipairs({"cutlass","katana","iron mace","dual katana","triple katana","dark blade","yoru","wando","shisui","saddi","koko","tushita","bisento","pole","trident","true triple katana","cursed dual katana","dark dagger","buddy sword","dragon heart","canvander","rengoku","spikey trident","midnight blade","hallow scythe","yama","fox lamp","longsword","gravity cane","ice sword","flame sword","sand sword","pipe","dark blade v2","dark blade v3","soul cane","shark saw"}) do SW[n]=true end
    for _,n in ipairs({"combat","black leg","electro","fishman karate","dragon talon","superhuman","death step","sharkman karate","electric claw","godhuman","sanguine art","dragontalon"}) do ML[n]=true end
    for _,n in ipairs({"flintlock","musket","slingshot","dual flintlock","refined slingshot","bizarre rifle","kabucha","acidum rifle","serpent bow","soul guitar"}) do GN[n]=true end
    local function Classify(t)
        if not t or not t:IsA("Tool") then return nil end
        local n=t.Name:lower()
        if GN[n] then return "Gun" end
        if SW[n] then return "Sword" end
        if ML[n] then return "Melee" end
        local it=t:GetAttribute("ItemType")
        if it then local x=tostring(it):lower()
            if x=="sword" then return "Sword" end
            if x=="gun" then return "Gun" end
            if x=="melee" or x=="fightingstyle" or x=="fighting_style" then return "Melee" end
        end
        local tt=t:GetAttribute("ToolType")
        if tt then local x=tostring(tt):lower()
            if x=="sword" then return "Sword" end
            if x=="gun" then return "Gun" end
            if x=="melee" then return "Melee" end
        end
        if t:FindFirstChild("GunClient") or t:FindFirstChild("GunType") then return "Gun" end
        if t:FindFirstChild("SwordClient") or t:FindFirstChild("Blade") then return "Sword" end
        if n:find("sword") or n:find("blade") or n:find("katana") then return "Sword" end
        if n:find("gun") or n:find("pistol") or n:find("rifle") or n:find("bow") then return "Gun" end
        if t:FindFirstChild("Handle") then return "Melee" end
        return nil
    end
    local function Find(k)
        local c=LP.Character; if not c then return nil end
        local bp=LP:FindFirstChild("Backpack"); if not bp then return nil end
        for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and Classify(t)==k then return t end end
        for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and Classify(t)==k then return t end end
        return nil
    end
    EquipWeapon=function()
        if not State.AutoEquipWeapon then return end
        local k=State.EquipType or "Melee"
        local tool=Find(k)
        if not tool then return end
        if State.LastEquipped==tool and tool.Parent==LP.Character then return end
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
        pcall(function() h:EquipTool(tool) end)
        State.LastEquipped=tool
    end
end

local FPS={}
do
    local function sp(i,p) if not State.OriginalProps[i] then State.OriginalProps[i]={} end; if State.OriginalProps[i][p]==nil then pcall(function() State.OriginalProps[i][p]=i[p] end) end end
    local function rp(i,p) if State.OriginalProps[i] and State.OriginalProps[i][p]~=nil then pcall(function() i[p]=State.OriginalProps[i][p] end) end end
    FPS.setShadows=function(o) if o then sp(S.Light,"GlobalShadows") pcall(function() S.Light.GlobalShadows=false end) else rp(S.Light,"GlobalShadows") end end
    FPS.setPostFX=function(o)
        for _,fx in ipairs(S.Light:GetChildren()) do
            if fx:IsA("BloomEffect") or fx:IsA("BlurEffect") or fx:IsA("DepthOfFieldEffect") or fx:IsA("SunRaysEffect") or fx:IsA("ColorCorrectionEffect") then
                if o then sp(fx,"Enabled") pcall(function() fx.Enabled=false end) else rp(fx,"Enabled") end
            end
        end
    end
    FPS.setAtmosphere=function(o)
        if o then sp(S.Light,"FogEnd") sp(S.Light,"FogStart") pcall(function() S.Light.FogEnd=0 S.Light.FogStart=0 end)
            for _,at in ipairs(S.Light:GetChildren()) do if at:IsA("Atmosphere") then sp(at,"Density") sp(at,"Haze") pcall(function() at.Density=0 at.Haze=0 end) end end
        else rp(S.Light,"FogEnd") rp(S.Light,"FogStart")
            for _,at in ipairs(S.Light:GetChildren()) do if at:IsA("Atmosphere") then rp(at,"Density") rp(at,"Haze") end end
        end
    end
    FPS.setTerrain=function(o)
        local t=S.WS:FindFirstChildOfClass("Terrain"); if not t then return end
        if o then sp(t,"WaterWaveSize") sp(t,"WaterReflectance") sp(t,"WaterTransparency") pcall(function() t.WaterWaveSize=0 t.WaterReflectance=0 t.WaterTransparency=1 t.Decoration=false end)
        else rp(t,"WaterWaveSize") rp(t,"WaterReflectance") rp(t,"WaterTransparency") end
    end
    FPS.setParticles=function(o)
        if o then for _,d in ipairs(S.WS:GetDescendants()) do if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then if d.Enabled then sp(d,"Enabled") pcall(function() d.Enabled=false end) end end end
        else for i in pairs(State.OriginalProps) do if i:IsA("ParticleEmitter") or i:IsA("Fire") or i:IsA("Smoke") or i:IsA("Sparkles") then rp(i,"Enabled") end end end
    end
    FPS.setDecals=function(o)
        if o then for _,d in ipairs(S.WS:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then if d.Transparency<1 then sp(d,"Transparency") pcall(function() d.Transparency=1 end) end end end
        else for i in pairs(State.OriginalProps) do if i:IsA("Decal") or i:IsA("Texture") then rp(i,"Transparency") end end end
    end
    FPS.setBeams=function(o)
        if o then for _,d in ipairs(S.WS:GetDescendants()) do if d:IsA("Beam") or d:IsA("Trail") or d:IsA("SelectionBox") then if d.Enabled then sp(d,"Enabled") pcall(function() d.Enabled=false end) end end end
        else for i in pairs(State.OriginalProps) do if i:IsA("Beam") or i:IsA("Trail") or i:IsA("SelectionBox") then rp(i,"Enabled") end end end
    end
    FPS.setAccessories=function(o)
        if o then for _,p in ipairs(S.Players:GetPlayers()) do local c=p.Character if c then for _,d in ipairs(c:GetDescendants()) do if d:IsA("Accessory") or d:IsA("Hat") then sp(d,"Transparency") pcall(function() d.Transparency=1 end) end end end end
        else for i in pairs(State.OriginalProps) do if i:IsA("Accessory") or i:IsA("Hat") then rp(i,"Transparency") end end end
    end
    FPS.setDamageNums=function(o)
        local pg=LP:FindFirstChild("PlayerGui"); if not pg then return end
        for _,g in ipairs(pg:GetChildren()) do if g:IsA("ScreenGui") and (g.Name:lower():find("damage") or g.Name:lower():find("number")) then if o then sp(g,"Enabled") pcall(function() g.Enabled=false end) else rp(g,"Enabled") end end end
    end
    FPS.setItemDrops=function(o)
        if not o then return end
        for _,n in ipairs({"ItemDrops","Drops"}) do local d=S.WS:FindFirstChild(n) if d then for _,c in ipairs(d:GetChildren()) do if c:IsA("Model") or c:IsA("BasePart") then sp(c,"Parent") pcall(function() c.Parent=nil end) end end end end
    end
    FPS.setDecor=function(o)
        if o then for _,n in ipairs({"Grass","Plants","Rocks","Bushes","Trees","Foliage"}) do for _,f in ipairs(S.WS:GetDescendants()) do if f.Name==n and (f:IsA("Folder") or f:IsA("Model")) then for _,p in ipairs(f:GetDescendants()) do if p:IsA("BasePart") then sp(p,"Transparency") pcall(function() p.Transparency=1 end) end end end end end
        else for i in pairs(State.OriginalProps) do if i:IsA("BasePart") then rp(i,"Transparency") end end end
    end
    FPS.setLighting=function(o)
        if o then sp(S.Light,"Brightness") sp(S.Light,"ClockTime") sp(S.Light,"OutdoorAmbient") sp(S.Light,"Ambient") pcall(function() S.Light.Brightness=0.5 S.Light.ClockTime=0 S.Light.OutdoorAmbient=Color3.new(0,0,0) S.Light.Ambient=Color3.new(0,0,0) end)
        else rp(S.Light,"Brightness") rp(S.Light,"ClockTime") rp(S.Light,"OutdoorAmbient") rp(S.Light,"Ambient") end
    end
    FPS.restoreAll=function()
        State.OriginalProps={}
        FPS.setShadows(false) FPS.setPostFX(false) FPS.setAtmosphere(false)
        FPS.setTerrain(false) FPS.setParticles(false) FPS.setDecals(false)
        FPS.setBeams(false) FPS.setAccessories(false) FPS.setDamageNums(false)
        FPS.setLighting(false)
    end
end

local MoveTo,TeleportTo,BringMobs,DoAttack,StopMoving
do
    local Block=Instance.new("Part")
    Block.Size=Vector3.new(1,1,1); Block.Anchored=true; Block.CanCollide=false; Block.CanTouch=false
    Block.Transparency=1; Block.Name="SikeHub_MoveBlock"; Block.Parent=S.WS
    local ShouldTween,TweenInst=false,nil
    StopMoving=function()
        ShouldTween=false
        if TweenInst then pcall(function() TweenInst:Cancel() end) TweenInst=nil end
        local c=LP.Character
        if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
    end
    S.RunService.Heartbeat:Connect(function()
        if State.Destroyed or not AnyModeOn() or State.PanicMode then return end
        if not ShouldTween then return end
        local hrp=GetRoot(); if not hrp then return end
        if (hrp.Position-Block.Position).Magnitude<=250 then hrp.CFrame=Block.CFrame else Block.CFrame=hrp.CFrame end
        local c=LP.Character
        if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end)
    MoveTo=function(cf)
        if State.PanicMode then return end
        local hrp=GetRoot(); if not hrp or not cf then return end
        cf=typeof(cf)=="CFrame" and cf or CFrame.new(cf)
        local d=(hrp.Position-cf.Position).Magnitude
        if d<=5 then hrp.CFrame=cf Block.CFrame=cf return end
        if TweenInst then pcall(function() TweenInst:Cancel() end) end
        ShouldTween=true
        TweenInst=S.Tween:Create(Block,TweenInfo.new(d/State.Speed,Enum.EasingStyle.Linear),{CFrame=cf})
        TweenInst:Play()
    end
    TeleportTo=function(cf)
        if State.PanicMode then return end
        local hrp=GetRoot(); if not hrp or not cf then return end
        cf=typeof(cf)=="CFrame" and cf or CFrame.new(cf)
        if TweenInst then pcall(function() TweenInst:Cancel() end) end
        ShouldTween=false; Block.CFrame=cf; hrp.CFrame=cf
    end
    BringMobs=function()
        if not State.BringMobs then return end
        if tick()-State.BringLast<0.35 then return end
        State.BringLast=tick()
        local hrp=GetRoot(); if not hrp then return end
        pcall(function() sethiddenproperty(LP,"SimulationRadius",math.huge) end)
        local en=S.WS:FindFirstChild("Enemies"); if not en then return end
        for _,mob in ipairs(en:GetChildren()) do
            if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob.Humanoid.Health>0 then
                local mrp=mob.HumanoidRootPart
                if (mrp.Position-hrp.Position).Magnitude<=State.BringRange then
                    local bv=mrp:FindFirstChild("BringLock")
                    if not bv then bv=Instance.new("BodyPosition"); bv.Name="BringLock"; bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.P=200000; bv.D=500; bv.Parent=mrp end
                    bv.Position=Vector3.new(hrp.Position.X,hrp.Position.Y-State.HoverHeight,hrp.Position.Z)
                end
            end
        end
    end
    DoAttack=function()
        if not R.Attack or not R.Hit then return end
        local hrp=GetRoot(); if not hrp then return end
        local en=S.WS:FindFirstChild("Enemies"); if not en then return end
        local range=State.AttackRange
        if IS_MOBILE then range=range+15 end
        local hits={}
        for _,e in ipairs(en:GetChildren()) do
            if e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart") and e.Humanoid.Health>0 then
                local mrp=e.HumanoidRootPart
                local d1=(mrp.Position-hrp.Position).Magnitude
                local head=e:FindFirstChild("Head")
                local d2=head and (head.Position-hrp.Position).Magnitude or math.huge
                if d1<=range or d2<=range then table.insert(hits,e) end
            end
        end
        if #hits==0 then return end
        local args={[1]=nil,[2]={},[4]="078da5141"}
        for _,mob in ipairs(hits) do
            if not args[1] then args[1]=mob.Head end
            table.insert(args[2],{[1]=mob,[2]=mob.HumanoidRootPart})
            table.insert(args[2],mob)
        end
        pcall(function() R.Attack:FireServer(0) R.Hit:FireServer(table.unpack(args)) end)
    end
end

local function CheckHaki()
    if not State.AutoHaki or not R.CommF then return end
    local c=LP.Character
    if not c or c:FindFirstChild("HasBuso") then return end
    pcall(function() R.CommF:InvokeServer("Buso") end)
end
local function FindMob(name)
    local en=S.WS:FindFirstChild("Enemies"); if not en then return nil end
    local hrp=GetRoot(); if not hrp then return nil end
    local best,bd=nil,math.huge
    for _,e in ipairs(en:GetChildren()) do
        if e.Name==name and e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart") and e.Humanoid.Health>0 then
            local d=(e.HumanoidRootPart.Position-hrp.Position).Magnitude
            if d<bd then best,bd=e,d end
        end
    end
    return best,bd
end
local function FindNearestMob(md)
    md=md or 3000
    local en=S.WS:FindFirstChild("Enemies"); if not en then return nil end
    local hrp=GetRoot(); if not hrp then return nil end
    local best,bd=nil,math.huge
    for _,e in ipairs(en:GetChildren()) do
        if e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart") and e.Humanoid.Health>0 then
            local d=(e.HumanoidRootPart.Position-hrp.Position).Magnitude
            if d<bd and d<=md then best,bd=e,d end
        end
    end
    return best,bd
end
local function TrackKills(name)
    local en=S.WS:FindFirstChild("Enemies"); if not en then return end
    local live={}
    for _,e in ipairs(en:GetChildren()) do if e.Name==name and e:FindFirstChild("Humanoid") and e.Humanoid.Health>0 then live[e]=true end end
    for i in pairs(State.TrackedMobs) do if not live[i] or not i.Parent then State.KillsSinceAccept=State.KillsSinceAccept+1 end end
    State.TrackedMobs=live
end
local function FindNearestChest()
    local hrp=GetRoot(); if not hrp then return nil end
    local best,bd=nil,math.huge
    for _,o in ipairs(S.WS:GetDescendants()) do
        if o.Name=="Chest" or o.Name=="ChestFolderValue" then
            local p=o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
            if p then local d=(p.Position-hrp.Position).Magnitude; if d<bd and d<=500 then best,bd=p,d end end
        end
    end
    return best
end
local function RunChestFarm()
    local c=FindNearestChest()
    if c then State.SubStatus="Chest Farm"; TeleportTo(CFrame.new(c.Position+Vector3.new(0,3,0))); task.wait(0.15)
    else State.SubStatus="Chest — none"; task.wait(0.5) end
end
local function FindBoss(name)
    local en=S.WS:FindFirstChild("Enemies")
    if en then for _,e in ipairs(en:GetChildren()) do if e.Name==name and e:FindFirstChild("Humanoid") and e.Humanoid.Health>0 then return e end end end
    local map=S.WS:FindFirstChild("Map")
    if map then for _,o in ipairs(map:GetDescendants()) do if o.Name==name and o:FindFirstChild("Humanoid") and o.Humanoid.Health>0 then return o end end end
    return nil
end
local function FarmMobTarget(mob,label)
    if not mob then State.SubStatus=label.." — none" return false end
    local hrp=GetRoot(); if not hrp then return false end
    local mrp=mob:FindFirstChild("HumanoidRootPart"); if not mrp then return false end
    EquipWeapon()
    State.SubStatus=label.." — "..DisplayName(mob.Name)
    local mobPos=mrp.Position
    local tcf=CFrame.new(mobPos+Vector3.new(0,State.HoverHeight,5))
    local dist=(hrp.Position-tcf.Position).Magnitude
    if dist>4 then MoveTo(tcf); task.wait(0.05) end
    hrp=GetRoot()
    if not hrp then return false end
    local nowDist=(hrp.Position-mobPos).Magnitude
    if nowDist>State.AttackRange+20 then return false end
    BringMobs()
    for _=1,math.max(1,State.AttackBurst) do DoAttack() end
    return true
end
local function RunBossFarm()
    local b=FindBoss(State.SelectedBoss)
    if b then FarmMobTarget(b,"Boss") else State.SubStatus="Boss — searching" task.wait(0.5) end
end
local function RunNearestMobFarm()
    local m=FindNearestMob(3000)
    if not m then State.SubStatus="Nearest — none" task.wait(0.5) return end
    FarmMobTarget(m,"Nearest")
end
local function RunSpecificMobFarm()
    local m=FindMob(State.SelectedMob)
    if not m then State.SubStatus="Specific — no "..DisplayName(State.SelectedMob) task.wait(0.5) return end
    FarmMobTarget(m,"Specific")
end

local function HasChip()
    local c=LP.Character
    if c and c:FindFirstChild("Special Microchip") then return true end
    local bp=LP:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Special Microchip") then return true end
    return false
end
local function UnequipChip()
    local c=LP.Character; if not c then return end
    local h=c:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:UnequipTools() end) end
    local chip=c:FindFirstChild("Special Microchip")
    if chip then local bp=LP:FindFirstChild("Backpack"); if bp then pcall(function() chip.Parent=bp end) end end
end
local function FruitInBackpack(full)
    if not full then return false end
    local s=full:match("^([^%-]+)") or full
    local function check(c)
        if not c then return false end
        for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and (t.Name==full or t.Name==s or t.Name==s.."-"..s or t.Name==s.." Fruit") then return true end end
        return false
    end
    return check(LP.Character) or check(LP:FindFirstChild("Backpack"))
end
local function InRaid()
    local pg=LP:FindFirstChild("PlayerGui")
    local m=pg and pg:FindFirstChild("Main")
    if not m then return false end
    local top=m:FindFirstChild("TopHUDList")
    local t=top and top:FindFirstChild("RaidTimer")
    if t and t.Visible then return true end
    local t2=m:FindFirstChild("Timer")
    return t2 and t2.Visible or false
end
local function RunBuyChip()
    if HasChip() then return end
    if tick()-State.LastChipBuy<5 then return end
    State.LastChipBuy=tick()
    State.SubStatus="Raid — Beli chip"
    pcall(function() Invoke("RaidsNpc","Select",State.RaidChip) end)
    task.wait(2)
    if HasChip() then return end
    pcall(function() Invoke("BuyChip",State.RaidChip) end)
    task.wait(1.5)
    if HasChip() then return end
    for _,fn in ipairs(DATA.CHEAP) do
        local s=fn:match("^([^%-]+)") or fn
        State.SubStatus="Raid — "..s
        pcall(function() Invoke("LoadFruit",fn) end)
        local ok=false
        for _=1,10 do task.wait(0.2) if FruitInBackpack(fn) then ok=true break end end
        if not ok then
            pcall(function() Invoke("LoadFruit",s) end)
            for _=1,8 do task.wait(0.2) if FruitInBackpack(s) then ok=true break end end
        end
        if not ok then continue end
        pcall(function() Invoke("RaidsNpc","Select",State.RaidChip) end)
        for _=1,20 do task.wait(0.25) if HasChip() then State.SubStatus="Raid — chip ready" State.RaidClickAttempts=0 return end end
    end
    State.SubStatus="Raid — chip fail"
    task.wait(2)
end
local function RunStartRaid()
    if InRaid() then State.RaidClickAttempts=0 return end
    if not HasChip() then State.SubStatus="Raid — waiting chip" return end
    if tick()-State.LastSummonTry<3 then return end
    State.LastSummonTry=tick()
    State.RaidClickAttempts=State.RaidClickAttempts+1
    UnequipChip(); task.wait(0.2)
    State.SubStatus="Raid — finding summon"
    local summon=nil
    local map=S.WS:FindFirstChild("Map")
    if map then
        local islName=SeaIndex==3 and "Boat Castle" or "CircleIsland"
        local isl=map:FindFirstChild(islName)
        if isl then summon=isl:FindFirstChild("RaidSummon2") or isl:FindFirstChild("RaidSummon") or isl:FindFirstChild("RaidSummon1") end
        if not summon then for _,d in ipairs(map:GetDescendants()) do if d.Name=="RaidSummon2" or d.Name=="RaidSummon" or d.Name=="RaidSummon1" then summon=d break end end end
    end
    if summon then
        local buttonPart=nil
        local button=summon:FindFirstChild("Button",true)
        if button then buttonPart=button:FindFirstChild("Main",true) or button:FindFirstChildWhichIsA("BasePart",true) end
        if not buttonPart then for _,d in ipairs(summon:GetDescendants()) do if d:IsA("BasePart") and d:FindFirstChildOfClass("ClickDetector") then buttonPart=d break end end end
        if not buttonPart then for _,d in ipairs(summon:GetDescendants()) do if d:IsA("BasePart") and d.Name=="Main" then buttonPart=d break end end end
        if buttonPart then
            State.SubStatus="Raid — walking in"
            local hrp=GetRoot()
            if hrp then
                local approach=buttonPart.Position+Vector3.new(0,3,30)
                hrp.CFrame=CFrame.new(approach,buttonPart.Position)
                task.wait(0.15)
                local endPos=buttonPart.Position+Vector3.new(0,2,6)
                local d=(hrp.Position-endPos).Magnitude
                local tw=S.Tween:Create(hrp,TweenInfo.new(d/80,Enum.EasingStyle.Linear),{CFrame=CFrame.new(endPos,buttonPart.Position)})
                tw:Play(); pcall(function() tw.Completed:Wait() end)
                UnequipChip(); task.wait(0.1)
                local click=buttonPart:FindFirstChildOfClass("ClickDetector")
                if click then
                    pcall(function() fireclickdetector(click,5) end); task.wait(0.15)
                    pcall(function() fireclickdetector(click,1) end); task.wait(0.15)
                    pcall(function() fireclickdetector(click) end)
                end
                for _,d in ipairs(summon:GetDescendants()) do if d:IsA("ClickDetector") and d~=click then pcall(function() fireclickdetector(d,5) end) end end
                pcall(function() firetouchinterest(hrp,buttonPart,0); task.wait(0.05); firetouchinterest(hrp,buttonPart,1) end)
            end
        end
        if R.Raids then pcall(function() R.Raids:FireServer("Start",State.RaidChip) end); pcall(function() R.Raids:FireServer("Start") end) end
        if R.Btn then pcall(function() R.Btn:FireServer("Start",State.RaidChip) end) end
        if R.CommF then pcall(function() R.CommF:InvokeServer("Raid",State.RaidChip) end); pcall(function() R.CommF:InvokeServer("StartRaid",State.RaidChip) end) end
    else
        State.SubStatus="Raid — no summon"
        if R.CommF then pcall(function() R.CommF:InvokeServer("StartRaid",State.RaidChip) end) end
    end
    State.SubStatus="Raid — verifying"
    for _=1,15 do task.wait(0.4) if InRaid() then State.SubStatus="Raid — started" State.RaidClickAttempts=0 return end end
    State.SubStatus="Raid — retry "..State.RaidClickAttempts
    if State.RaidClickAttempts>=4 then State.RaidClickAttempts=0 State.LastChipBuy=0 end
end
local function RunClearRaid()
    if not InRaid() then State.SubStatus="Raid — waiting" return end
    if State.RaidChip=="Magma" or State.RaidChip=="Flame" then
        local map=S.WS:FindFirstChild("Map")
        if map then for _,d in ipairs(map:GetDescendants()) do if d.Name=="Lava" and d.Parent then pcall(function() d:Destroy() end) end end end
    end
    local names={"Island 5","Island 4","Island 3","Island 2","Island 1"}
    local found=nil
    local origin=S.WS:FindFirstChild("_WorldOrigin")
    local locs=origin and origin:FindFirstChild("Locations")
    if locs then
        local hrp=GetRoot()
        if hrp then for _,n in ipairs(names) do local t=locs:FindFirstChild(n) if t and (t.Position-hrp.Position).Magnitude<=3000 then found=t State.SubStatus="Raid — "..n break end end end
    end
    if not found then
        local rm=S.WS:FindFirstChild("RaidMap")
        if rm then for _,n in ipairs(names) do local t=rm:FindFirstChild(n) if t then found=t State.SubStatus="Raid — "..n break end end end
    end
    if found then
        local hrp=GetRoot()
        local p=found:IsA("BasePart") and found.Position or found:GetPivot().Position
        if hrp and (hrp.Position-p).Magnitude>100 then TeleportTo(CFrame.new(p+Vector3.new(0,120,0))) task.wait(0.3) end
    else State.SubStatus="Raid — clearing" end
    local en=S.WS:FindFirstChild("Enemies")
    if en then
        local hrp=GetRoot()
        if hrp then
            for _,e in ipairs(en:GetChildren()) do
                if e:FindFirstChild("Humanoid") and e:FindFirstChild("HumanoidRootPart") and e.Humanoid.Health>0 then
                    local d=(e.HumanoidRootPart.Position-hrp.Position).Magnitude
                    if d<=5000 then
                        local mrp=e.HumanoidRootPart
                        local bv=mrp:FindFirstChild("BringLock")
                        if not bv then bv=Instance.new("BodyPosition"); bv.Name="BringLock"; bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge); bv.P=200000; bv.D=500; bv.Parent=mrp end
                        bv.Position=Vector3.new(hrp.Position.X,hrp.Position.Y-State.HoverHeight,hrp.Position.Z)
                    end
                end
            end
            for _=1,math.max(1,State.AttackBurst) do DoAttack() end
        end
    end
end
local function GetLevelTarget(lvl)
    if lvl<=9 then return "Bandit",CFrame.new(1059,15,1550),"BanditQuest1",1
    elseif lvl<=14 then return "Monkey",CFrame.new(-1598,36,153),"JungleQuest",1
    elseif lvl<=29 then return "Gorilla",CFrame.new(-1598,36,153),"JungleQuest",2
    elseif lvl<=44 then return "Pirate",CFrame.new(-1141,4,3831),"BuggyQuest1",1
    elseif lvl<=59 then return "Brute",CFrame.new(-1141,4,3831),"BuggyQuest1",2
    elseif lvl<=74 then return "Desert Bandit",CFrame.new(894,5,4392),"DesertQuest",1
    elseif lvl<=89 then return "Desert Officer",CFrame.new(894,5,4392),"DesertQuest",2
    elseif lvl<=99 then return "Snow Bandit",CFrame.new(1389,88,-1298),"SnowQuest",1
    elseif lvl<=119 then return "Snowman",CFrame.new(1389,88,-1298),"SnowQuest",2
    elseif lvl<=149 then return "Chief Petty Officer",CFrame.new(-5039,27,4324),"MarineQuest2",1
    elseif lvl<=174 then return "Sky Bandit",CFrame.new(-4839,716,-2619),"SkyQuest",1
    elseif lvl<=189 then return "Dark Master",CFrame.new(-4839,716,-2619),"SkyQuest",2
    elseif lvl<=209 then return "Prisoner",CFrame.new(5308,1,475),"PrisonerQuest",1
    elseif lvl<=249 then return "Dangerous Prisoner",CFrame.new(5308,1,475),"PrisonerQuest",2
    elseif lvl<=274 then return "Toga Warrior",CFrame.new(-1580,6,-2986),"ColosseumQuest",1
    elseif lvl<=299 then return "Gladiator",CFrame.new(-1580,6,-2986),"ColosseumQuest",2
    elseif lvl<=324 then return "Military Soldier",CFrame.new(-5313,10,8515),"MagmaQuest",1
    elseif lvl<=374 then return "Military Spy",CFrame.new(-5313,10,8515),"MagmaQuest",2
    elseif lvl<=399 then return "Fishman Warrior",CFrame.new(61122,18,1569),"FishmanQuest",1
    elseif lvl<=449 then return "Fishman Commando",CFrame.new(61122,18,1569),"FishmanQuest",2
    elseif lvl<=474 then return "God's Guard",CFrame.new(-4721,843,-1949),"SkyExp1Quest",1
    elseif lvl<=524 then return "Shanda",CFrame.new(-7859,5544,-381),"SkyExp1Quest",2
    elseif lvl<=549 then return "Royal Squad",CFrame.new(-7906,5634,-1411),"SkyExp2Quest",1
    elseif lvl<=624 then return "Royal Soldier",CFrame.new(-7906,5634,-1411),"SkyExp2Quest",2
    elseif lvl<=649 then return "Galley Pirate",CFrame.new(5259,37,4050),"FountainQuest",1
    elseif lvl<=699 then return "Galley Captain",CFrame.new(5259,37,4050),"FountainQuest",2
    elseif lvl<=724 then return "Raider",CFrame.new(-429,71,1836),"Area1Quest",1
    elseif lvl<=774 then return "Mercenary",CFrame.new(-429,71,1836),"Area1Quest",2
    elseif lvl<=799 then return "Swan Pirate",CFrame.new(638,71,918),"Area2Quest",1
    elseif lvl<=874 then return "Factory Staff",CFrame.new(632,73,918),"Area2Quest",2
    elseif lvl<=899 then return "Marine Lieutenant",CFrame.new(-2440,71,-3216),"MarineQuest3",1
    elseif lvl<=949 then return "Marine Captain",CFrame.new(-2440,71,-3216),"MarineQuest3",2
    elseif lvl<=974 then return "Zombie",CFrame.new(-5497,47,-795),"ZombieQuest",1
    elseif lvl<=999 then return "Vampire",CFrame.new(-5497,47,-795),"ZombieQuest",2
    elseif lvl<=1049 then return "Snow Trooper",CFrame.new(609,400,-5372),"SnowMountainQuest",1
    elseif lvl<=1099 then return "Winter Warrior",CFrame.new(609,400,-5372),"SnowMountainQuest",2
    elseif lvl<=1124 then return "Lab Subordinate",CFrame.new(-6064,15,-4902),"IceSideQuest",1
    elseif lvl<=1174 then return "Horned Warrior",CFrame.new(-6064,15,-4902),"IceSideQuest",2
    elseif lvl<=1199 then return "Magma Ninja",CFrame.new(-5428,15,-5299),"FireSideQuest",1
    elseif lvl<=1249 then return "Lava Pirate",CFrame.new(-5428,15,-5299),"FireSideQuest",2
    elseif lvl<=1274 then return "Ship Deckhand",CFrame.new(1037,125,32911),"ShipQuest1",1
    elseif lvl<=1299 then return "Ship Engineer",CFrame.new(1037,125,32911),"ShipQuest1",2
    elseif lvl<=1324 then return "Ship Steward",CFrame.new(968,125,33244),"ShipQuest2",1
    elseif lvl<=1349 then return "Ship Officer",CFrame.new(968,125,33244),"ShipQuest2",2
    elseif lvl<=1374 then return "Arctic Warrior",CFrame.new(5667,26,-6486),"FrostQuest",1
    elseif lvl<=1424 then return "Snow Lurker",CFrame.new(5667,26,-6486),"FrostQuest",2
    elseif lvl<=1449 then return "Sea Soldier",CFrame.new(-3054,235,-10142),"ForgottenQuest",1
    elseif lvl<=1499 then return "Water Fighter",CFrame.new(-3054,240,-10146),"ForgottenQuest",2
    elseif lvl<=1524 then return "Pirate Millionaire",CFrame.new(-290,42,5581),"PiratePortQuest",1
    elseif lvl<=1574 then return "Pistol Billionaire",CFrame.new(-290,42,5581),"PiratePortQuest",2
    elseif lvl<=1599 then return "Dragon Crew Warrior",CFrame.new(6738,127,-713),"DragonCrewQuest",1
    elseif lvl<=1624 then return "Dragon Crew Archer",CFrame.new(6738,127,-713),"DragonCrewQuest",2
    elseif lvl<=1649 then return "Hydra Enforcer",CFrame.new(5213,1004,758),"VenomCrewQuest",1
    elseif lvl<=1699 then return "Venomous Assailant",CFrame.new(5213,1004,758),"VenomCrewQuest",2
    elseif lvl<=1724 then return "Marine Commodore",CFrame.new(2180,27,-6741),"MarineTreeIsland",1
    elseif lvl<=1774 then return "Marine Rear Admiral",CFrame.new(2179,28,-6740),"MarineTreeIsland",2
    elseif lvl<=1799 then return "Fishman Raider",CFrame.new(3142,108,7482),"DeepForestIsland3",1
    elseif lvl<=1824 then return "Fishman Captain",CFrame.new(-10581,330,-8761),"DeepForestIsland3",2
    elseif lvl<=1849 then return "Forest Pirate",CFrame.new(-13234,331,-7625),"DeepForestIsland",1
    elseif lvl<=1899 then return "Forest Pirate",CFrame.new(-13234,331,-7625),"DeepForestIsland",2
    elseif lvl<=1924 then return "Jungle Pirate",CFrame.new(-12680,389,-9902),"DeepForestIsland2",1
    elseif lvl<=1974 then return "Musketeer Pirate",CFrame.new(-12680,389,-9902),"DeepForestIsland2",2
    elseif lvl<=1999 then return "Reborn Skeleton",CFrame.new(-9479,141,5566),"HauntedQuest1",1
    elseif lvl<=2024 then return "Living Zombie",CFrame.new(-9479,141,5566),"HauntedQuest1",2
    elseif lvl<=2049 then return "Demonic Soul",CFrame.new(-9516,172,6078),"HauntedQuest2",1
    elseif lvl<=2074 then return "Posessed Mummy",CFrame.new(-9516,172,6078),"HauntedQuest2",2
    elseif lvl<=2099 then return "Peanut Scout",CFrame.new(-2104,38,-10194),"NutsIslandQuest",1
    elseif lvl<=2124 then return "Peanut President",CFrame.new(-2104,38,-10194),"NutsIslandQuest",2
    elseif lvl<=2149 then return "Ice Cream Chef",CFrame.new(-820,65,-10965),"IceCreamIslandQuest",1
    elseif lvl<=2199 then return "Ice Cream Commander",CFrame.new(-820,65,-10965),"IceCreamIslandQuest",2
    elseif lvl<=2224 then return "Cookie Crafter",CFrame.new(-2021,37,-12028),"CakeQuest1",1
    elseif lvl<=2249 then return "Cake Guard",CFrame.new(-2021,37,-12028),"CakeQuest1",2
    elseif lvl<=2274 then return "Baking Staff",CFrame.new(-1927,37,-12842),"CakeQuest2",1
    elseif lvl<=2299 then return "Head Baker",CFrame.new(-1927,37,-12842),"CakeQuest2",2
    elseif lvl<=2324 then return "Cocoa Warrior",CFrame.new(233,29,-12201),"ChocQuest1",1
    elseif lvl<=2349 then return "Chocolate Bar Battler",CFrame.new(233,29,-12201),"ChocQuest1",2
    elseif lvl<=2374 then return "Sweet Thief",CFrame.new(150,30,-12774),"ChocQuest2",1
    elseif lvl<=2399 then return "Candy Rebel",CFrame.new(150,30,-12774),"ChocQuest2",2
    elseif lvl<=2424 then return "Candy Pirate",CFrame.new(-1150,20,-14446),"CandyQuest1",1
    elseif lvl<=2449 then return "Snow Demon",CFrame.new(-1150,20,-14446),"CandyQuest1",2
    elseif lvl<=2474 then return "Isle Outlaw",CFrame.new(-16547,61,-173),"TikiQuest1",1
    elseif lvl<=2524 then return "Island Boy",CFrame.new(-16547,61,-173),"TikiQuest1",2
    elseif lvl<=2574 then return "Isle Champion",CFrame.new(-16539,55,1051),"TikiQuest2",1
    elseif lvl<=2599 then return "Skull Slayer",CFrame.new(-16665,104,1579),"TikiQuest3",2
    elseif lvl<=2624 then return "Reef Bandit",CFrame.new(10778,-2087,9265),"SubmergedQuest1",1
    elseif lvl<=2649 then return "Coral Pirate",CFrame.new(10778,-2087,9265),"SubmergedQuest1",2
    elseif lvl<=2674 then return "Sea Chanter",CFrame.new(10880,-2086,10032),"SubmergedQuest2",1
    elseif lvl<=2699 then return "Ocean Prophet",CFrame.new(10880,-2086,10032),"SubmergedQuest2",2
    elseif lvl<=2719 then return "High Disciple",CFrame.new(9640,-1992,9613),"SubmergedQuest3",1
    else return "Grand Devotee",CFrame.new(9640,-1992,9613),"SubmergedQuest3",2 end
end
local function RunLevelFarm()
    local mn,gcf,qn,qid=GetLevelTarget(State.MyLevel)
    if not mn then State.SubStatus="No target" task.wait(1) return end
    EquipWeapon()
    if State.AutoQuest then
        local changed=State.QuestLevel~=State.MyLevel
        local done=State.KillsSinceAccept>=8
        if changed or done then
            local hrp=GetRoot()
            if hrp and (hrp.Position-gcf.Position).Magnitude>12 then
                State.SubStatus="→ quest giver"
                MoveTo(gcf+Vector3.new(0,5,3))
                task.wait(0.05)
                return
            end
            State.SubStatus="Accepting: "..qn
            Invoke("StartQuest",qn,qid)
            State.QuestLevel=State.MyLevel
            State.KillsSinceAccept=0
            State.TrackedMobs={}
            task.wait(1)
            return
        end
    end
    local live,dist=FindMob(mn)
    if live and dist and dist<500 then
        State.SubStatus=string.format("%s [%d]",DisplayName(mn),State.MyLevel)
        FarmMobTarget(live,"Level")
    else
        State.SubStatus="Traveling → "..DisplayName(mn)
        MoveTo(gcf)
    end
    TrackKills(mn)
end

local MainLoop=function()
    while AnyModeOn() and not State.Destroyed do
        if State.PanicMode then State.SubStatus="PANIC" task.wait(0.5) continue end
        if not IsAlive() then State.SubStatus="Dead" task.wait(1) continue end
        State.MyLevel=GetMyLevel()
        CheckHaki()
        if State.AutoRaidMode then
            if State.AutoClearRaid and InRaid() then RunClearRaid()
            elseif HasChip() and not InRaid() then RunStartRaid()
            elseif State.AutoBuyChip and not HasChip() then RunBuyChip()
            elseif State.AutoClearRaid then State.SubStatus="Raid — waiting"
            else State.SubStatus="Raid — waiting chip" end
        elseif State.AutoBossFarm then RunBossFarm()
        elseif State.AutoNearestMob then RunNearestMobFarm()
        elseif State.AutoSpecificMob then RunSpecificMobFarm()
        elseif State.AutoChestFarm then RunChestFarm()
        elseif State.AutoLevelFarm then RunLevelFarm() end
        if State.AttackDelay>0 then task.wait(State.AttackDelay) else task.wait() end
    end
    if not AnyModeOn() then State.SubStatus="Idle" end
end

task.spawn(function() while not State.Destroyed do task.wait(60) pcall(function() S.VU:CaptureController() S.VU:ClickButton2(Vector2.new()) end) end end)
S.RunService.Stepped:Connect(function()
    if State.Destroyed or not State.NoClip then return end
    local c=LP.Character; if not c then return end
    for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end
end)
do
    local jH,tH=false,false
    S.UIS.InputBegan:Connect(function(i,gp) if gp then return end
        if i.KeyCode==Enum.KeyCode.Space then jH=true end
        if i.UserInputType==Enum.UserInputType.Touch then tH=true end
    end)
    S.UIS.InputEnded:Connect(function(i)
        if i.KeyCode==Enum.KeyCode.Space then jH=false end
        if i.UserInputType==Enum.UserInputType.Touch then tH=false end
    end)
    task.spawn(function() while not State.Destroyed do task.wait(0.2) if not State.InfJump then jH=false tH=false end end end)
    S.RunService.Heartbeat:Connect(function()
        if State.Destroyed or not State.InfJump or State.PanicMode then return end
        local h=GetHum(); if not h or h.Health<=0 then return end
        local want=S.UIS:IsKeyDown(Enum.KeyCode.Space) or jH or tH
        if not want then return end
        local st=h:GetState()
        if st==Enum.HumanoidStateType.Freefall or st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Landed then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
            local hrp=h.Parent and h.Parent:FindFirstChild("HumanoidRootPart")
            if hrp then local v=hrp.AssemblyLinearVelocity; hrp.AssemblyLinearVelocity=Vector3.new(v.X,math.max(v.Y,45),v.Z) end
        end
    end)
end
local function RemoveFog()
    pcall(function()
        S.Light.FogEnd=1e6; S.Light.FogStart=0
        if S.Light:FindFirstChildOfClass("Atmosphere") then S.Light.Atmosphere.Density=0 S.Light.Atmosphere.Haze=0 end
    end)
end
local function ResetCharacter()
    local c=LP.Character
    if c then local h=c:FindFirstChildOfClass("Humanoid") if h then h.Health=0 end end
end
local function ServerHop()
    local ok,res=pcall(function() return game:HttpGet("https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100") end)
    if not ok then return end
    local d=S.HTTP:JSONDecode(res)
    if not d or not d.data then return end
    for _,srv in ipairs(d.data) do
        if srv.playing<srv.maxPlayers and srv.id~=game.JobId then
            pcall(function() S.TP:TeleportToPlaceInstance(PlaceId,srv.id,LP) end)
            return
        end
    end
end
local function Rejoin() pcall(function() S.TP:Teleport(PlaceId,LP) end) end
local CODES={"Sub2CaptainMaui","kittgaming","Sub2Fer999","Enyu_is_Pro","Magicbus","JCWK","Starcodeheo","Bluxxy","fudd10_v2","fudd10","Bignews","THEGREATACE","Sub2NoobMaster123","Sub2UncleKizaru","Sub2Daigrock","Axiore","TantaiGaming","StrawHatMaine"}
local function RedeemAllCodes()
    for _,c in ipairs(CODES) do pcall(function() Invoke("Redeem",c) end) task.wait(0.3) end
end

local UI={}
do
    local T={bg0=Color3.fromRGB(8,10,15),bg1=Color3.fromRGB(13,16,23),bg2=Color3.fromRGB(18,22,32),bg3=Color3.fromRGB(24,29,42),bg4=Color3.fromRGB(32,38,54),text=Color3.fromRGB(242,245,252),textDim=Color3.fromRGB(148,158,180),textFaint=Color3.fromRGB(80,90,112),accent=Color3.fromRGB(88,196,255),accentHot=Color3.fromRGB(120,220,255),accentDim=Color3.fromRGB(40,88,140),violet=Color3.fromRGB(160,130,255),ok=Color3.fromRGB(72,235,168),okDim=Color3.fromRGB(30,110,82),warn=Color3.fromRGB(255,200,110),danger=Color3.fromRGB(255,100,115),dangerDim=Color3.fromRGB(90,30,40),border=Color3.fromRGB(30,36,50),border2=Color3.fromRGB(48,56,74),border3=Color3.fromRGB(66,76,98)}
    local F={black=Enum.Font.GothamBlack,bold=Enum.Font.GothamBold,med=Enum.Font.GothamMedium,reg=Enum.Font.Gotham,mono=Enum.Font.Code}
    local mk,tw,glass
    mk=function(c,p,par) local o=Instance.new(c) for k,v in pairs(p) do if k~="Parent" and k~="Children" then pcall(function() o[k]=v end) end end if p.Children then for _,x in ipairs(p.Children) do x.Parent=o end end o.Parent=p.Parent or par return o end
    tw=function(o,t,p,st,dr) return S.Tween:Create(o,TweenInfo.new(t,st or Enum.EasingStyle.Quint,dr or Enum.EasingDirection.Out),p):Play() end
    glass=function(par,p,r)
        local f=mk("Frame",p,par)
        mk("UICorner",{CornerRadius=UDim.new(0,r or 10)},f)
        mk("UIStroke",{Color=T.border2,Thickness=1,Transparency=0.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f)
        return f
    end
    local sg=Instance.new("ScreenGui")
    sg.Name="BF_SikeHub"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=parentGui
    local W,H=IS_MOBILE and 400 or 620, IS_MOBILE and 340 or 460
    local main=mk("Frame",{Size=UDim2.new(0,W,0,H),Position=UDim2.new(0.5,-W/2,0.5,-H/2),BackgroundColor3=T.bg0,BorderSizePixel=0,Active=true,ClipsDescendants=true},sg)
    mk("UICorner",{CornerRadius=UDim.new(0,18)},main)
    mk("UIStroke",{Color=T.accentDim,Thickness=1,Transparency=0.55,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},main)
    local glowTR=mk("Frame",{Size=UDim2.new(0,280,0,280),Position=UDim2.new(1,-140,0,-140),BackgroundColor3=T.accent,BackgroundTransparency=0.92,BorderSizePixel=0,ZIndex=0},main)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},glowTR)
    mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.accent),ColorSequenceKeypoint.new(1,T.violet)}),Rotation=45},glowTR)
    local glowBL=mk("Frame",{Size=UDim2.new(0,220,0,220),Position=UDim2.new(0,-110,1,-110),BackgroundColor3=T.violet,BackgroundTransparency=0.94,BorderSizePixel=0,ZIndex=0},main)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},glowBL)
    local topLine=mk("Frame",{Size=UDim2.new(1,-36,0,1),Position=UDim2.new(0,18,0,0),BackgroundColor3=T.accent,BorderSizePixel=0,ZIndex=10},main)
    mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.bg0),ColorSequenceKeypoint.new(0.25,T.accent),ColorSequenceKeypoint.new(0.5,T.violet),ColorSequenceKeypoint.new(0.75,T.accent),ColorSequenceKeypoint.new(1,T.bg0)})},topLine)
    local header=mk("Frame",{Size=UDim2.new(1,0,0,64),BackgroundColor3=T.bg1,BackgroundTransparency=0.15,BorderSizePixel=0,ZIndex=2},main)
    mk("UICorner",{CornerRadius=UDim.new(0,18)},header)
    mk("Frame",{Size=UDim2.new(1,0,0.5,0),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=T.bg1,BackgroundTransparency=0.15,BorderSizePixel=0,ZIndex=2},header)
    local logoBox=mk("Frame",{Size=UDim2.new(0,40,0,40),Position=UDim2.new(0,18,0.5,-20),BackgroundColor3=T.bg3,BorderSizePixel=0,ZIndex=4},header)
    mk("UICorner",{CornerRadius=UDim.new(0,12)},logoBox)
    mk("UIStroke",{Color=T.accentDim,Thickness=1,Transparency=0.3},logoBox)
    local inner=mk("Frame",{Size=UDim2.new(0,26,0,26),Position=UDim2.new(0.5,-13,0.5,-13),BackgroundColor3=T.accent,BackgroundTransparency=0.86,BorderSizePixel=0,ZIndex=5,Parent=logoBox},nil)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},inner)
    mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="S",Font=F.black,TextSize=22,TextColor3=T.accentHot,ZIndex=6},logoBox)
    mk("TextLabel",{Size=UDim2.new(0,260,0,20),Position=UDim2.new(0,72,0,12),BackgroundTransparency=1,Text="SIKE HUB",Font=F.black,TextSize=17,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4},header)
    local seaLbl=mk("TextLabel",{Size=UDim2.new(0,260,0,15),Position=UDim2.new(0,72,0,34),BackgroundTransparency=1,Text="v7.0  ·  sea "..SeaIndex,Font=F.reg,TextSize=11,TextColor3=T.textFaint,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4},header)
    local pill=mk("Frame",{Size=UDim2.new(0,108,0,28),Position=UDim2.new(1,-186,0.5,-14),BackgroundColor3=T.bg2,BorderSizePixel=0,ZIndex=4},header)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},pill)
    local pillStroke=mk("UIStroke",{Color=T.border2,Thickness=1,Transparency=0.4},pill)
    local pillDot=mk("Frame",{Size=UDim2.new(0,8,0,8),Position=UDim2.new(0,14,0.5,-4),BackgroundColor3=T.textFaint,BorderSizePixel=0,ZIndex=5},pill)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},pillDot)
    local pillText=mk("TextLabel",{Size=UDim2.new(1,-30,1,0),Position=UDim2.new(0,28,0,0),BackgroundTransparency=1,Text="IDLE",Font=F.bold,TextSize=11,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5},pill)
    local minBtn=mk("TextButton",{Size=UDim2.new(0,32,0,32),Position=UDim2.new(1,-76,0.5,-16),BackgroundColor3=T.bg3,BorderSizePixel=0,Text="—",Font=F.bold,TextSize=16,TextColor3=T.text,AutoButtonColor=false,ZIndex=6},header)
    mk("UICorner",{CornerRadius=UDim.new(0,10)},minBtn)
    local closeBtn=mk("TextButton",{Size=UDim2.new(0,32,0,32),Position=UDim2.new(1,-40,0.5,-16),BackgroundColor3=T.bg3,BorderSizePixel=0,Text="✕",Font=F.bold,TextSize=15,TextColor3=T.text,AutoButtonColor=false,ZIndex=6},header)
    mk("UICorner",{CornerRadius=UDim.new(0,10)},closeBtn)
    local body=mk("Frame",{Size=UDim2.new(1,0,1,-64),Position=UDim2.new(0,0,0,64),BackgroundTransparency=1,ZIndex=2},main)
    local sidebar=mk("Frame",{Size=UDim2.new(0,146,1,-24),Position=UDim2.new(0,12,0,12),BackgroundColor3=T.bg1,BackgroundTransparency=0.3,BorderSizePixel=0},body)
    mk("UICorner",{CornerRadius=UDim.new(0,14)},sidebar)
    mk("UIStroke",{Color=T.border,Thickness=1,Transparency=0.5},sidebar)
    mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},sidebar)
    mk("UIPadding",{PaddingTop=UDim.new(0,12),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingBottom=UDim.new(0,12)},sidebar)
    local pageHolder=mk("Frame",{Size=UDim2.new(1,-180,1,-24),Position=UDim2.new(0,168,0,12),BackgroundColor3=T.bg1,BackgroundTransparency=0.3,BorderSizePixel=0},body)
    mk("UICorner",{CornerRadius=UDim.new(0,14)},pageHolder)
    mk("UIStroke",{Color=T.border,Thickness=1,Transparency=0.5},pageHolder)
    local pages,tabBtns={},{}
    local function makeTab(lbl,o,n)
        local b=mk("TextButton",{Size=UDim2.new(1,0,0,34),BackgroundColor3=T.bg2,BackgroundTransparency=0.5,BorderSizePixel=0,Text="",AutoButtonColor=false,LayoutOrder=o},sidebar)
        mk("UICorner",{CornerRadius=UDim.new(0,9)},b)
        local ind=mk("Frame",{Size=UDim2.new(0,3,0,16),Position=UDim2.new(0,6,0.5,-8),BackgroundColor3=T.accent,BorderSizePixel=0,Visible=false},b)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},ind)
        local dot=mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(0,18,0.5,-3),BackgroundColor3=T.textFaint,BorderSizePixel=0},b)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},dot)
        local t=mk("TextLabel",{Size=UDim2.new(1,-40,1,0),Position=UDim2.new(0,30,0,0),BackgroundTransparency=1,Text=lbl,Font=F.med,TextSize=12,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left},b)
        tabBtns[n]={btn=b,ind=ind,dot=dot,lbl=t}
    end
    local function newPage(n)
        local p=mk("Frame",{Name=n,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Visible=false},pageHolder)
        local sc=mk("ScrollingFrame",{Size=UDim2.new(1,-18,1,-18),Position=UDim2.new(0,9,0,9),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.border3,ScrollBarImageTransparency=0.3,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ElasticBehavior=Enum.ElasticBehavior.Never},p)
        mk("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},sc)
        pages[n]={root=p,scroll=sc}
        return sc
    end
    local scHome=newPage("Home")
    local scFarm=newPage("Farm")
    local scAttack=newPage("Attack")
    local scRaid=newPage("Raid")
    local scMisc=newPage("Misc")
    local scFPS=newPage("FPS")
    local scAbout=newPage("About")
    makeTab("Home",1,"Home") makeTab("Farm",2,"Farm") makeTab("Attack",3,"Attack")
    makeTab("Raid",4,"Raid") makeTab("Misc",5,"Misc") makeTab("FPS",6,"FPS") makeTab("About",7,"About")
    local function sec(par,txt,o)
        local w=mk("Frame",{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=o},par)
        mk("TextLabel",{Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Text=txt,Font=F.bold,TextSize=10,TextColor3=T.textFaint,TextXAlignment=Enum.TextXAlignment.Left},w)
        mk("Frame",{Size=UDim2.new(0,22,0,2),Position=UDim2.new(0,0,0,20),BackgroundColor3=T.accent,BorderSizePixel=0},w)
        return w
    end
    local function tgl(par,lbl,desc,def,cb,o)
        local w=glass(par,{Size=UDim2.new(1,0,0,IS_MOBILE and 76 or 68),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=o},12)
        mk("TextLabel",{Size=UDim2.new(1,-100,0,18),Position=UDim2.new(0,18,0,14),BackgroundTransparency=1,Text=lbl,Font=F.bold,TextSize=IS_MOBILE and 14 or 13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},w)
        if desc and desc~="" then
            mk("TextLabel",{Size=UDim2.new(1,-100,0,34),Position=UDim2.new(0,18,0,36),BackgroundTransparency=1,Text=desc,Font=F.reg,TextSize=11,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true},w)
        end
        local tr=mk("Frame",{Size=UDim2.new(0,48,0,26),Position=UDim2.new(1,-66,0,16),BackgroundColor3=def and T.okDim or T.bg3,BorderSizePixel=0},w)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},tr)
        local tS=mk("UIStroke",{Color=def and T.ok or T.border2,Thickness=1,Transparency=0.3},tr)
        local kn=mk("Frame",{Size=UDim2.new(0,20,0,20),Position=def and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},tr)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},kn)
        local st=def
        local function refresh()
            local tp=st and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
            tw(kn,0.25,{Position=tp})
            tw(tr,0.25,{BackgroundColor3=st and T.okDim or T.bg3})
            tw(tS,0.25,{Color=st and T.ok or T.border2})
        end
        local cl=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""},w)
        cl.MouseButton1Click:Connect(function() st=not st refresh() if cb then cb(st) end end)
        return {frame=w,set=function(v) if st~=v then st=v refresh() if cb then cb(st) end end end,get=function() return st end}
    end
    local function sld(par,lbl,desc,mn,mx,def,un,cb,o)
        local w=glass(par,{Size=UDim2.new(1,0,0,96),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=o},12)
        mk("TextLabel",{Size=UDim2.new(1,-130,0,18),Position=UDim2.new(0,18,0,14),BackgroundTransparency=1,Text=lbl,Font=F.bold,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left},w)
        local vl=mk("TextLabel",{Size=UDim2.new(0,110,0,18),Position=UDim2.new(1,-128,0,14),BackgroundTransparency=1,Text=tostring(def)..(un or ""),Font=F.mono,TextSize=12,TextColor3=T.accentHot,TextXAlignment=Enum.TextXAlignment.Right},w)
        if desc and desc~="" then
            mk("TextLabel",{Size=UDim2.new(1,-36,0,34),Position=UDim2.new(0,18,0,36),BackgroundTransparency=1,Text=desc,Font=F.reg,TextSize=11,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true},w)
        end
        local th=mk("Frame",{Size=UDim2.new(1,-36,0,24),Position=UDim2.new(0,18,0,68),BackgroundTransparency=1,BorderSizePixel=0},w)
        local tb=mk("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,0.5,-4),BackgroundColor3=T.bg3,BorderSizePixel=0},th)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},tb)
        local r0=math.clamp((def-mn)/(mx-mn),0,1)
        local fl=mk("Frame",{Size=UDim2.new(r0,0,1,0),BackgroundColor3=T.accent,BorderSizePixel=0},tb)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},fl)
        mk("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.accentDim),ColorSequenceKeypoint.new(1,T.accentHot)})},fl)
        local ks=IS_MOBILE and 22 or 18
        local kn=mk("Frame",{Size=UDim2.new(0,ks,0,ks),Position=UDim2.new(r0,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=3},th)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},kn)
        mk("UIStroke",{Color=T.accentDim,Thickness=2,Transparency=0.2},kn)
        local dr=false
        local function upd(ax)
            local tx=tb.AbsolutePosition.X
            local tw_=tb.AbsoluteSize.X
            if tw_<=0 then return end
            local r=math.clamp((ax-tx)/tw_,0,1)
            local v=math.floor(mn+r*(mx-mn)+0.5)
            fl.Size=UDim2.new(r,0,1,0)
            kn.Position=UDim2.new(r,0,0.5,0)
            vl.Text=tostring(v)..(un or "")
            if cb then cb(v) end
        end
        th.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true upd(i.Position.X) end end)
        S.UIS.InputChanged:Connect(function(i) if not dr then return end; if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then upd(i.Position.X) end end)
        S.UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=false end end)
        return {frame=w,set=function(v)
            v=math.clamp(math.floor(v+0.5),mn,mx)
            local r=(v-mn)/(mx-mn)
            fl.Size=UDim2.new(r,0,1,0)
            kn.Position=UDim2.new(r,0,0.5,0)
            vl.Text=tostring(v)..(un or "")
            if cb then cb(v) end
        end}
    end
    local function seg(par,lbl,opts,def,cb,o)
        local w=glass(par,{Size=UDim2.new(1,0,0,82),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=o},12)
        mk("TextLabel",{Size=UDim2.new(1,-36,0,18),Position=UDim2.new(0,18,0,14),BackgroundTransparency=1,Text=lbl,Font=F.bold,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left},w)
        local row=mk("Frame",{Size=UDim2.new(1,-36,0,38),Position=UDim2.new(0,18,0,36),BackgroundColor3=T.bg3,BorderSizePixel=0},w)
        mk("UICorner",{CornerRadius=UDim.new(0,10)},row)
        mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center},row)
        mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},row)
        local btns,cur={},def
        local function refresh()
            for n,b in pairs(btns) do
                local on=n==cur
                tw(b,0.18,{BackgroundColor3=on and T.accentDim or T.bg3})
                b.TextColor3=on and T.text or T.textDim
            end
        end
        for i,opt in ipairs(opts) do
            local b=mk("TextButton",{Size=UDim2.new(1/#opts,-4,1,-8),BackgroundColor3=cur==opt and T.accentDim or T.bg3,BorderSizePixel=0,Text=opt,Font=F.bold,TextSize=12,TextColor3=cur==opt and T.text or T.textDim,AutoButtonColor=false,LayoutOrder=i},row)
            mk("UICorner",{CornerRadius=UDim.new(0,7)},b)
            btns[opt]=b
            b.MouseButton1Click:Connect(function() cur=opt refresh() if cb then cb(opt) end end)
        end
        refresh()
        return {frame=w,set=function(v) cur=v refresh() if cb then cb(v) end end,get=function() return cur end}
    end
    local _openList=nil
    local function drop(par,lbl,opts,def,cb,o)
        local w=glass(par,{Size=UDim2.new(1,0,0,68),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=o,ZIndex=10},12)
        w.ClipsDescendants=false
        local function norm(e)
            if type(e)=="table" then return {display=e.display or e.value,value=e.value or e.display} end
            return {display=e,value=e}
        end
        local nd={}
        for _,e in ipairs(opts) do table.insert(nd,norm(e)) end
        local dN=norm(def)
        mk("TextLabel",{Size=UDim2.new(1,-140,0,18),Position=UDim2.new(0,18,0,14),BackgroundTransparency=1,Text=lbl,Font=F.bold,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=11},w)
        local cl=mk("TextLabel",{Size=UDim2.new(0,130,0,18),Position=UDim2.new(1,-148,0,14),BackgroundTransparency=1,Text=tostring(dN.display),Font=F.mono,TextSize=12,TextColor3=T.accentHot,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=11},w)
        local row=mk("Frame",{Size=UDim2.new(1,-36,0,32),Position=UDim2.new(0,18,0,36),BackgroundColor3=T.bg3,BorderSizePixel=0,ZIndex=11},w)
        mk("UICorner",{CornerRadius=UDim.new(0,8)},row)
        mk("UIStroke",{Color=T.border2,Thickness=1,Transparency=0.4},row)
        mk("TextLabel",{Size=UDim2.new(0,20,1,0),Position=UDim2.new(1,-24,0,0),BackgroundTransparency=1,Text="▾",Font=F.bold,TextSize=12,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=12},row)
        local cur={display=dN.display,value=dN.value}
        local lo=false
        local btn=mk("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=12},row)
        local function closeL()
            if _openList and _openList.Parent then _openList:Destroy() end
            _openList=nil; lo=false
        end
        btn.MouseButton1Click:Connect(function()
            if lo then closeL() return end
            closeL()
            local list=mk("ScrollingFrame",{Name="SikeHubDropdown",Size=UDim2.new(0,row.AbsoluteSize.X,0,160),Position=UDim2.new(0,row.AbsolutePosition.X-sg.AbsolutePosition.X,0,row.AbsolutePosition.Y-sg.AbsolutePosition.Y+row.AbsoluteSize.Y+4),BackgroundColor3=T.bg1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.border3,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=500},sg)
            mk("UICorner",{CornerRadius=UDim.new(0,8)},list)
            mk("UIStroke",{Color=T.border3,Thickness=1,Transparency=0.2},list)
            mk("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},list)
            mk("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)},list)
            for i,opt in ipairs(nd) do
                local sel=cur.value==opt.value
                local b=mk("TextButton",{Size=UDim2.new(1,0,0,30),BackgroundColor3=sel and T.accentDim or T.bg3,BorderSizePixel=0,Text=tostring(opt.display),Font=F.med,TextSize=12,TextColor3=sel and T.text or T.textDim,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,LayoutOrder=i,ZIndex=501},list)
                mk("UICorner",{CornerRadius=UDim.new(0,6)},b)
                mk("UIPadding",{PaddingLeft=UDim.new(0,10)},b)
                b.MouseButton1Click:Connect(function()
                    cur={display=opt.display,value=opt.value}
                    cl.Text=tostring(opt.display)
                    closeL()
                    if cb then cb(opt.value) end
                end)
            end
            _openList=list; lo=true
        end)
        return {frame=w,set=function(v)
            for _,o in ipairs(nd) do
                if o.value==v then
                    cur={display=o.display,value=o.value}
                    cl.Text=tostring(o.display)
                    if cb then cb(o.value) end
                    return
                end
            end
        end,get=function() return cur.value end,setOptions=function(no,nd2)
            nd={}
            for _,e in ipairs(no) do table.insert(nd,norm(e)) end
            if nd2 then local d=norm(nd2); cur={display=d.display,value=d.value}; cl.Text=tostring(d.display) end
            if lo then closeL() end
        end}
    end
    local function act(par,lbl,cb,o,vr)
        vr=vr or "default"
        local bg,fg=T.bg2,T.text
        if vr=="primary" then bg,fg=T.accentDim,T.text
        elseif vr=="danger" then bg,fg=T.dangerDim,T.danger
        elseif vr=="ok" then bg,fg=T.okDim,T.ok end
        local b=mk("TextButton",{Size=UDim2.new(1,0,0,IS_MOBILE and 48 or 42),BackgroundColor3=bg,BorderSizePixel=0,Text=lbl,Font=F.bold,TextSize=13,TextColor3=fg,AutoButtonColor=false,LayoutOrder=o},par)
        mk("UICorner",{CornerRadius=UDim.new(0,11)},b)
        mk("UIStroke",{Color=T.border2,Thickness=1,Transparency=0.45},b)
        b.MouseEnter:Connect(function() tw(b,0.15,{BackgroundColor3=bg:Lerp(Color3.new(1,1,1),0.08)}) end)
        b.MouseLeave:Connect(function() tw(b,0.15,{BackgroundColor3=bg}) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    sec(scHome,"STATUS",1)
    local sr=mk("Frame",{Size=UDim2.new(1,0,0,84),BackgroundTransparency=1,LayoutOrder=2},scHome)
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},sr)
    local function stat(lbl,v,col,o)
        local t=glass(sr,{Size=UDim2.new(1/3,-6,1,0),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=o},12)
        mk("TextLabel",{Size=UDim2.new(1,-24,0,14),Position=UDim2.new(0,16,0,14),BackgroundTransparency=1,Text=lbl,Font=F.bold,TextSize=9,TextColor3=T.textFaint,TextXAlignment=Enum.TextXAlignment.Left},t)
        local vv=mk("TextLabel",{Size=UDim2.new(1,-24,0,24),Position=UDim2.new(0,16,0,32),BackgroundTransparency=1,Text=v,Font=F.black,TextSize=20,TextColor3=col,TextXAlignment=Enum.TextXAlignment.Left},t)
        local dot=mk("Frame",{Size=UDim2.new(0,6,0,6),Position=UDim2.new(1,-18,1,-18),BackgroundColor3=col,BorderSizePixel=0},t)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},dot)
        return vv
    end
    local levelTile=stat("LEVEL","1",T.accentHot,1)
    local modeTile=stat("MODE","None",T.violet,2)
    local statusTile=stat("STATUS","Idle",T.ok,3)
    sec(scHome,"ACTIVE MODULES",3)
    local mc=glass(scHome,{Size=UDim2.new(1,0,0,180),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=4},12)
    local mr=mk("Frame",{Size=UDim2.new(1,-36,1,-32),Position=UDim2.new(0,18,0,16),BackgroundTransparency=1},mc)
    mk("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},mr)
    local function mp(txt,o)
        local w=mk("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,LayoutOrder=o},mr)
        local d=mk("Frame",{Size=UDim2.new(0,8,0,8),Position=UDim2.new(0,0,0.5,-4),BackgroundColor3=T.textFaint,BorderSizePixel=0},w)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},d)
        local l=mk("TextLabel",{Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1,Text=txt,Font=F.med,TextSize=12,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left},w)
        return {dot=d,label=l}
    end
    local mF=mp("Auto Level Farm",1)
    local mR=mp("Auto Raid",2)
    local mB=mp("Auto Boss Farm",3)
    local mC=mp("Auto Chest Farm",4)
    local mN=mp("Auto Nearest Mob",5)
    local mS=mp("Auto Specific Mob",6)

    sec(scFarm,"LEVEL FARMING",1)
    local fT=tgl(scFarm,"Auto Level Farm","Kills mobs at your level. Auto-quest + Bring Mobs stack on top.",State.AutoLevelFarm,function(v) State.AutoLevelFarm=v UI.Upd() end,2)
    sec(scFarm,"MOB TARGETING",3)
    tgl(scFarm,"Auto Nearest Mob","Kills closest enemy.",State.AutoNearestMob,function(v) State.AutoNearestMob=v UI.Upd() end,4)
    tgl(scFarm,"Auto Specific Mob","Only farms chosen mob type.",State.AutoSpecificMob,function(v) State.AutoSpecificMob=v UI.Upd() end,5)
    local function bldMob()
        local raw=DATA.MOBS[SeaIndex] or DATA.MOBS[1]
        local out={}
        for _,n in ipairs(raw) do table.insert(out,{display=DisplayName(n),value=n}) end
        return out
    end
    local mo=bldMob()
    local mD=drop(scFarm,"Target Mob",mo,mo[1].value,function(v) State.SelectedMob=v end,6)
    State.SelectedMob=mo[1].value
    sec(scFarm,"BOSS FARMING",7)
    tgl(scFarm,"Auto Boss Farm","Repeatedly kills chosen boss.",State.AutoBossFarm,function(v) State.AutoBossFarm=v UI.Upd() end,8)
    local bl=DATA.BOSSES[SeaIndex] or DATA.BOSSES[1]
    local bD=drop(scFarm,"Boss",bl,bl[1],function(v) State.SelectedBoss=v end,9)
    State.SelectedBoss=bl[1]
    sec(scFarm,"AUTO WEAPON",10)
    tgl(scFarm,"Auto Equip Weapon","Equips chosen weapon before each swing.",State.AutoEquipWeapon,function(v) State.AutoEquipWeapon=v State.LastEquipped=nil end,11)
    seg(scFarm,"Weapon Type",{"Melee","Sword"},State.EquipType,function(v) State.EquipType=v State.LastEquipped=nil end,12)
    sec(scFarm,"SUB FEATURES",13)
    tgl(scFarm,"Auto Quest","Auto-accepts quests on level-up.",State.AutoQuest,function(v) State.AutoQuest=v end,14)
    tgl(scFarm,"Auto Haki","Keeps Buso Haki active.",State.AutoHaki,function(v) State.AutoHaki=v end,15)
    tgl(scFarm,"Bring Mobs","Pulls nearby mobs to you.",State.BringMobs,function(v) State.BringMobs=v end,16)
    sec(scFarm,"OTHER FARMERS",17)
    tgl(scFarm,"Auto Chest Farm","Teleports to nearby chests.",State.AutoChestFarm,function(v) State.AutoChestFarm=v UI.Upd() end,18)
    sec(scFarm,"TUNING",19)
    sld(scFarm,"Attack Range","Max distance to hit.",30,200,State.AttackRange," studs",function(v) State.AttackRange=v end,20)
    sld(scFarm,"Bring Range","Max distance to pull.",50,600,State.BringRange," studs",function(v) State.BringRange=v end,21)
    sld(scFarm,"Fly Height","Height above mobs.",5,100,State.HoverHeight," studs",function(v) State.HoverHeight=v end,22)
    sld(scFarm,"Tween Speed","Movement speed.",80,350,State.Speed," studs/s",function(v) State.Speed=v end,23)

    sec(scAttack,"TIMING",1)
    local adS=sld(scAttack,"Attack Delay","Milliseconds between swings. 0 = every frame.",0,100,State.AttackDelay*1000," ms",function(v) State.AttackDelay=v/1000 end,2)
    local mhS=sld(scAttack,"Multi Hit","Hit events per swing.",1,5,State.AttackBurst," hits",function(v) State.AttackBurst=math.floor(v) end,3)
    sec(scAttack,"PRESETS",4)
    act(scAttack,"Safe — 33/sec",function() adS.set(30) mhS.set(1) end,5,"default")
    act(scAttack,"Normal — 60/sec",function() adS.set(16) mhS.set(1) end,6,"primary")
    act(scAttack,"Fast — 120/sec",function() adS.set(16) mhS.set(2) end,7,"default")
    act(scAttack,"Max — 300/sec",function() adS.set(0) mhS.set(5) end,8,"danger")

    sec(scRaid,"MAIN MODE",1)
    local rT=tgl(scRaid,"Auto Raid","Buys chip, walks to summon, clicks button, clears islands.",State.AutoRaidMode,function(v) State.AutoRaidMode=v UI.Upd() end,2)
    sec(scRaid,"SUB OPTIONS",3)
    tgl(scRaid,"Auto Buy Chip","Buys chips automatically.",State.AutoBuyChip,function(v) State.AutoBuyChip=v end,4)
    tgl(scRaid,"Auto Clear Raid","Clears all islands.",State.AutoClearRaid,function(v) State.AutoClearRaid=v end,5)
    sec(scRaid,"NOTES",6)
    local rn=glass(scRaid,{Size=UDim2.new(1,0,0,96),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=7},12)
    mk("UIStroke",{Color=T.ok,Thickness=1,Transparency=0.6},rn)
    mk("TextLabel",{Size=UDim2.new(1,-32,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1,Text="Walk-in + click + remote fallback. Watch console for status.",Font=F.reg,TextSize=11,TextColor3=T.ok,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true},rn)

    sec(scMisc,"CLIENT",1)
    tgl(scMisc,"No Clip","Walk through walls.",State.NoClip,function(v) State.NoClip=v end,2)
    tgl(scMisc,"Infinite Jump","Hold space to float upward.",State.InfJump,function(v) State.InfJump=v end,3)
    sec(scMisc,"CHARACTER",4)
    act(scMisc,"Reset Character",ResetCharacter,5,"default")
    act(scMisc,"Remove Fog / Weather",RemoveFog,6,"primary")
    sec(scMisc,"SERVER",7)
    act(scMisc,"Server Hop",ServerHop,8,"primary")
    act(scMisc,"Rejoin (same server)",Rejoin,9,"default")
    sec(scMisc,"UTILITY",10)
    act(scMisc,"Redeem All Codes",RedeemAllCodes,11,"primary")
    sec(scMisc,"PERFORMANCE",12)
    local fc=glass(scMisc,{Size=UDim2.new(1,0,0,56),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=13},12)
    mk("TextLabel",{Size=UDim2.new(0,120,1,0),Position=UDim2.new(0,18,0,0),BackgroundTransparency=1,Text="FRAME RATE",Font=F.bold,TextSize=11,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left},fc)
    local fpsVal=mk("TextLabel",{Size=UDim2.new(1,-150,1,0),Position=UDim2.new(0,130,0,0),BackgroundTransparency=1,Text="60",Font=F.black,TextSize=20,TextColor3=T.accentHot,TextXAlignment=Enum.TextXAlignment.Right},fc)

    sec(scFPS,"MASTER",1)
    local fM,fS=nil,{}
    fM=tgl(scFPS,"Enable All FPS Boosts","Turns every optimization below on at once.",false,function(v) for _,t in pairs(fS) do t.set(v) end end,2)
    sec(scFPS,"RENDERING",3)
    fS.sh=tgl(scFPS,"Disable Global Shadows","Shadow maps cost a full GPU render pass per light.",false,function(v) State.FPS_Shadows=v FPS.setShadows(v) end,4)
    fS.pf=tgl(scFPS,"Disable Post Processing","Removes Bloom, Blur, DOF, SunRays, ColorCorrection.",false,function(v) State.FPS_PostFX=v FPS.setPostFX(v) end,5)
    fS.at=tgl(scFPS,"Disable Atmosphere / Fog","Zeroes Atmosphere density and haze.",false,function(v) State.FPS_Atmosphere=v FPS.setAtmosphere(v) end,6)
    fS.tr=tgl(scFPS,"Disable Terrain Water","Flattens water waves and reflections.",false,function(v) State.FPS_Terrain=v FPS.setTerrain(v) end,7)
    fS.pa=tgl(scFPS,"Disable All Particles","Hides every ParticleEmitter, Fire, Smoke, Sparkles.",false,function(v) State.FPS_Particles=v FPS.setParticles(v) end,8)
    fS.de=tgl(scFPS,"Disable Decals & Textures","Makes surface Decals and Textures invisible.",false,function(v) State.FPS_Decals=v FPS.setDecals(v) end,9)
    fS.be=tgl(scFPS,"Disable Beams & Trails","Kills every Beam, Trail, SelectionBox.",false,function(v) State.FPS_Beams=v FPS.setBeams(v) end,10)
    sec(scFPS,"CHARACTERS",11)
    fS.ac=tgl(scFPS,"Hide Accessories","Makes hats, wings, capes invisible on every player.",false,function(v) State.FPS_Accessories=v FPS.setAccessories(v) end,12)
    sec(scFPS,"WORLD",13)
    fS.dn=tgl(scFPS,"Hide Damage Numbers","Hides floating damage popups.",false,function(v) State.FPS_DamageNums=v FPS.setDamageNums(v) end,14)
    fS.id=tgl(scFPS,"Hide Item Drops","Removes dropped items from view.",false,function(v) State.FPS_ItemDrops=v FPS.setItemDrops(v) end,15)
    fS.dc=tgl(scFPS,"Hide Island Decor","Hides grass, plants, rocks, bushes, trees.",false,function(v) State.FPS_Decor=v FPS.setDecor(v) end,16)
    sec(scFPS,"LIGHTING",17)
    fS.li=tgl(scFPS,"Darken Lighting","Minimizes lighting calculations.",false,function(v) State.FPS_Lighting=v FPS.setLighting(v) end,18)
    sec(scFPS,"ACTIONS",19)
    act(scFPS,"Enable All FPS Boosts",function() fM.set(true) end,20,"primary")
    act(scFPS,"Restore Defaults",function()
        FPS.restoreAll()
        for _,t in pairs(fS) do t.set(false) end
        fM.set(false)
    end,21,"default")

    sec(scAbout,"HOTKEYS",1)
    local hk=glass(scAbout,{Size=UDim2.new(1,0,0,130),BackgroundColor3=T.bg2,BackgroundTransparency=0.15,BorderSizePixel=0,LayoutOrder=2},12)
    for i,c in ipairs({{key="RightShift",desc="Panic stop"},{key="RightCtrl",desc="Panic stop"},{key="Header drag",desc="Reposition window"}}) do
        mk("TextLabel",{Size=UDim2.new(0,110,0,20),Position=UDim2.new(0,18,0,16+(i-1)*30),BackgroundTransparency=1,Text=c.key,Font=F.mono,TextSize=12,TextColor3=T.danger,TextXAlignment=Enum.TextXAlignment.Left},hk)
        mk("TextLabel",{Size=UDim2.new(1,-150,0,20),Position=UDim2.new(0,134,0,16+(i-1)*30),BackgroundTransparency=1,Text=c.desc,Font=F.reg,TextSize=12,TextColor3=T.textDim,TextXAlignment=Enum.TextXAlignment.Left},hk)
    end
    sec(scAbout,"ACTIONS",3)
    act(scAbout,"Reset Quest Tracker",function() State.QuestLevel=-1 State.KillsSinceAccept=0 State.TrackedMobs={} end,4,"default")
    act(scAbout,"Stop Everything",function()
        State.AutoLevelFarm=false State.AutoRaidMode=false State.AutoBossFarm=false
        State.AutoChestFarm=false State.AutoNearestMob=false State.AutoSpecificMob=false
        State.PanicMode=true StopMoving()
        fT.set(false) rT.set(false)
        UI.Upd()
    end,5,"danger")
    act(scAbout,"Unload Script",function()
        State.Destroyed=true State.PanicMode=true StopMoving()
        if sg then sg:Destroy() end
    end,6,"danger")

    local function setTab(n)
        for nn,p in pairs(pages) do p.root.Visible=(nn==n) end
        for nn,d in pairs(tabBtns) do
            local on=nn==n
            d.ind.Visible=on
            tw(d.btn,0.2,{BackgroundColor3=on and T.bg3 or T.bg2,BackgroundTransparency=on and 0 or 0.5})
            tw(d.dot,0.2,{BackgroundColor3=on and T.accentHot or T.textFaint})
            tw(d.lbl,0.2,{TextColor3=on and T.text or T.textDim})
        end
    end
    for n,d in pairs(tabBtns) do d.btn.MouseButton1Click:Connect(function() setTab(n) end) end
    setTab("Home")

    UI.Upd=function()
        local anyOn=AnyModeOn()
        local function sp(p,on,col) tw(p.dot,0.2,{BackgroundColor3=on and col or T.textFaint}) tw(p.label,0.2,{TextColor3=on and T.text or T.textDim}) end
        sp(mF,State.AutoLevelFarm,T.ok)
        sp(mR,State.AutoRaidMode,T.violet)
        sp(mB,State.AutoBossFarm,T.danger)
        sp(mC,State.AutoChestFarm,T.warn)
        sp(mN,State.AutoNearestMob,T.accentHot)
        sp(mS,State.AutoSpecificMob,T.violet)
        if anyOn then
            tw(pill,0.2,{BackgroundColor3=T.okDim}) tw(pillStroke,0.2,{Color=T.ok,Transparency=0.2}) tw(pillDot,0.2,{BackgroundColor3=T.ok})
            if State.AutoRaidMode then pillText.Text="RAID" modeTile.Text="Raid" modeTile.TextColor3=T.violet
            elseif State.AutoBossFarm then pillText.Text="BOSS" modeTile.Text="Boss" modeTile.TextColor3=T.danger
            elseif State.AutoNearestMob then pillText.Text="NEAREST" modeTile.Text="Nearest" modeTile.TextColor3=T.accentHot
            elseif State.AutoSpecificMob then pillText.Text="SPECIFIC" modeTile.Text="Specific" modeTile.TextColor3=T.violet
            elseif State.AutoChestFarm then pillText.Text="CHEST" modeTile.Text="Chest" modeTile.TextColor3=T.warn
            elseif State.AutoLevelFarm then pillText.Text="FARM" modeTile.Text="Farm" modeTile.TextColor3=T.accentHot end
            pillText.TextColor3=T.ok
            if not State.Running then State.Running=true task.spawn(function() MainLoop() State.Running=false end) end
        else
            pillText.Text="IDLE" pillText.TextColor3=T.textDim
            tw(pillDot,0.2,{BackgroundColor3=T.textFaint})
            tw(pill,0.2,{BackgroundColor3=T.bg2})
            tw(pillStroke,0.2,{Color=T.border2,Transparency=0.4})
            modeTile.Text="None" modeTile.TextColor3=T.textDim
            State.SubStatus="Idle"
        end
    end

    do
        local dr,ds,sp2=false,nil,nil
        header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true ds=i.Position sp2=main.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dr=false end end)
        end end)
        S.UIS.InputChanged:Connect(function(i)
            if not dr then return end
            if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
            local d=i.Position-ds
            main.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end)
    end

    S.UIS.InputBegan:Connect(function(i,gp)
        if gp then return end
        if i.KeyCode==Enum.KeyCode.RightControl or i.KeyCode==Enum.KeyCode.RightShift then
            State.PanicMode=true State.AutoLevelFarm=false State.AutoRaidMode=false
            State.AutoBossFarm=false State.AutoChestFarm=false State.AutoNearestMob=false State.AutoSpecificMob=false
            StopMoving()
            fT.set(false) rT.set(false)
            UI.Upd()
        end
    end)

    local min=false
    local origS=UDim2.new(0,W,0,H)
    minBtn.MouseButton1Click:Connect(function()
        min=not min
        tw(main,0.3,{Size=min and UDim2.new(0,W,0,64) or origS},Enum.EasingStyle.Quint)
        body.Visible=not min
        minBtn.Text=min and "+" or "—"
    end)
    closeBtn.MouseButton1Click:Connect(function()
        State.Destroyed=true State.PanicMode=true StopMoving()
        if sg then sg:Destroy() end
        print("[SIKE HUB] unloaded")
    end)
    minBtn.MouseEnter:Connect(function() tw(minBtn,0.15,{BackgroundColor3=T.bg4}) end)
    minBtn.MouseLeave:Connect(function() tw(minBtn,0.15,{BackgroundColor3=T.bg3}) end)
    closeBtn.MouseEnter:Connect(function() tw(closeBtn,0.15,{BackgroundColor3=T.dangerDim}) end)
    closeBtn.MouseLeave:Connect(function() tw(closeBtn,0.15,{BackgroundColor3=T.bg3}) end)

    main.Size=UDim2.new(0,W,0,0) main.BackgroundTransparency=1 main.Visible=false
    task.spawn(function()
        while not loadingDone do task.wait(0.05) end
        task.wait(0.15)
        main.Visible=true main.Size=UDim2.new(0,W,0,0)
        tw(main,0.55,{Size=origS,BackgroundTransparency=0},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end)
    task.spawn(function()
        local f,l=0,tick()
        S.RunService.RenderStepped:Connect(function()
            f=f+1
            local n=tick()
            if n-l>=1 then fpsVal.Text=tostring(f) f=0 l=n end
        end)
    end)
    task.spawn(function()
        while sg.Parent and not State.Destroyed do
            State.MyLevel=GetMyLevel()
            levelTile.Text=tostring(State.MyLevel)
            local s=State.SubStatus
            if #s>20 then s=string.sub(s,1,18)..".." end
            statusTile.Text=s
            task.wait(0.35)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if State.Destroyed then break end
        local n=game.PlaceId
        if n~=PlaceId then
            PlaceId=n
            local ns=1
            for s,ids in pairs(SEAP) do if ids[PlaceId] then ns=s break end end
            if ns~=SeaIndex then
                SeaIndex=ns
                for _,fn in ipairs(SeaChanged) do pcall(fn,ns) end
                print("[SIKE HUB] sea changed → "..ns)
            end
        end
    end
end)

print("[SIKE HUB] loaded — v7.0")
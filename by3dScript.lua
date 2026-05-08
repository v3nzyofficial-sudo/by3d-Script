local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- === 1. ПРОВЕРКА ПЛЕЙСА И ИНТРО ===
local SUPPORTED_PLACES = {
    [82531082592278] = true,
    [84742598039080] = true
}

local isSupported = SUPPORTED_PLACES[game.PlaceId]
local IntroGui = Instance.new("ScreenGui", (gethui and gethui()) or game:GetService("CoreGui"))
IntroGui.Name = "Aebeesee_Intro"; IntroGui.IgnoreGuiInset = true

local IntroFrame = Instance.new("Frame", IntroGui)
IntroFrame.Size = UDim2.new(1, 0, 1, 0); IntroFrame.BackgroundColor3 = Color3.new(0, 0, 0); IntroFrame.BackgroundTransparency = 1

local MainText = Instance.new("TextLabel", IntroFrame)
MainText.Size = UDim2.new(1, 0, 0, 50); MainText.Position = UDim2.new(0, 0, 0.42, 0); MainText.BackgroundTransparency = 1; MainText.Font = Enum.Font.GothamBold; MainText.TextSize = 24; MainText.TextColor3 = Color3.new(1, 1, 1); MainText.TextTransparency = 1; MainText.TextWrapped = true

local SubText = Instance.new("TextLabel", IntroFrame)
SubText.Size = UDim2.new(1, 0, 0, 30); SubText.Position = UDim2.new(0, 0, 0.49, 0); SubText.BackgroundTransparency = 1; SubText.Font = Enum.Font.Gotham; SubText.TextSize = 16; SubText.TextColor3 = Color3.fromRGB(160, 160, 160); SubText.TextTransparency = 1; SubText.TextWrapped = true

local TGText = Instance.new("TextLabel", IntroFrame)
TGText.Size = UDim2.new(1, 0, 0, 30); TGText.Position = UDim2.new(0, 0, 0.55, 0); TGText.BackgroundTransparency = 1; TGText.Font = Enum.Font.GothamMedium; TGText.TextSize = 18; TGText.TextColor3 = Color3.fromRGB(0, 170, 255); TGText.TextTransparency = 1; TGText.Text = "t.me/By3dScripts"

if isSupported then
    MainText.Text = "Этот скрипт не является читом и не дает преимущество над игроками!"
    SubText.Text = "Скрипт был разработан для игры с друзьями"
else
    MainText.Text = "Эта игра не поддерживается :("
    SubText.Text = "возможно мы скоро добавим поддержку вашего плейса"
end

local function playIntro()
    TweenService:Create(IntroFrame, TweenInfo.new(1.5), {BackgroundTransparency = 0.2}):Play()
    task.wait(1)
    TweenService:Create(MainText, TweenInfo.new(2, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
    task.wait(0.8)
    TweenService:Create(SubText, TweenInfo.new(2, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
    task.wait(0.8)
    TweenService:Create(TGText, TweenInfo.new(2, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
    task.wait(5)
    TweenService:Create(MainText, TweenInfo.new(1.5), {TextTransparency = 1}):Play()
    TweenService:Create(SubText, TweenInfo.new(1.5), {TextTransparency = 1}):Play()
    TweenService:Create(TGText, TweenInfo.new(1.5), {TextTransparency = 1}):Play()
    local last = TweenService:Create(IntroFrame, TweenInfo.new(1.5), {BackgroundTransparency = 1})
    last:Play(); last.Completed:Connect(function() IntroGui:Destroy() end)
end

if not isSupported then playIntro(); task.wait(11); return end
task.spawn(playIntro)

-- === 2. ОСНОВНЫЕ НАСТРОЙКИ ===
local FRIEND_COLOR = Color3.fromRGB(0, 255, 0)
local DAMAGE_COLOR = Color3.fromRGB(255, 0, 0)
local FIGHT_COLOR = Color3.fromRGB(255, 200, 0)
local VICTORY_COLOR = Color3.fromRGB(0, 255, 255)
local COLLAB_COLOR = Color3.fromRGB(255, 100, 255)
local DEAD_ENEMY_COLOR = Color3.fromRGB(255, 255, 0)
local HIT_COLOR = Color3.fromRGB(255, 255, 0)
local NEWBIE_COLOR = Color3.fromRGB(255, 255, 255)
local ANTISPAM_TIME = 2
local DETECTION_RADIUS = 35
local NEWBIE_THRESHOLD = 7

local NOTIF_SOUND = "rbxassetid://4590662766"
local DEATH_SOUND = "rbxassetid://185207902"

local cooldowns = {}
local lastDangerNotify = 0

-- === 3. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function playSnd(id)
    local s = Instance.new("Sound", game:GetService("SoundService"))
    s.SoundId = id; s.Volume = 0.5; s:Play()
    s.Ended:Connect(function() s:Destroy() end)
end

local function flashHighlight(target, color, duration, isPulsing, alwaysVisible)
    if not target then return end
    local h = target:FindFirstChild("TempHighlight") or Instance.new("Highlight")
    h.Name = "TempHighlight"; h.FillColor = color; h.OutlineColor = Color3.new(1, 1, 1)
    h.DepthMode = alwaysVisible and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    
    if not target:FindFirstChild("TempHighlight") then h.FillTransparency = 1; h.OutlineTransparency = 1; h.Parent = target end
    TweenService:Create(h, TweenInfo.new(0.4), {FillTransparency = 0.5, OutlineTransparency = 0}):Play()
    
    if isPulsing then
        task.spawn(function()
            local endTime = tick() + duration
            while tick() < endTime and h and h.Parent do
                local alpha = (math.sin(tick() * 8) + 1) / 2
                h.FillTransparency = 0.3 + (alpha * 0.4); task.wait()
            end
            if h then 
                local tw = TweenService:Create(h, TweenInfo.new(0.5), {FillTransparency = 1, OutlineTransparency = 1})
                tw:Play(); tw.Completed:Connect(function() h:Destroy() end)
            end
        end)
    else
        task.delay(duration, function()
            if h then
                local tw = TweenService:Create(h, TweenInfo.new(1), {FillTransparency = 1, OutlineTransparency = 1})
                tw:Play(); tw.Completed:Connect(function() h:Destroy() end)
            end
        end)
    end
end

local function findTarget(victimChar, range)
    local closest, dist = nil, range or 60
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character ~= victimChar and p.Character:FindFirstChild("HumanoidRootPart") then
            local mag = (p.Character.HumanoidRootPart.Position - victimChar.HumanoidRootPart.Position).Magnitude
            if mag < dist then closest = p.Character; dist = mag end
        end
    end
    return closest
end

-- === 4. ИНТЕРФЕЙС УВЕДОМЛЕНИЙ ===
local ScreenGui = Instance.new("ScreenGui", (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "FinalGuard_Absolute"; ScreenGui.ResetOnSpawn = false
local Container = Instance.new("Frame", ScreenGui)
Container.Size = UDim2.new(0, 300, 1, 0); Container.Position = UDim2.new(1, -310, 0, 20); Container.BackgroundTransparency = 1
Instance.new("UIListLayout", Container).Padding = UDim.new(0, 8)

local function createNotif(title, text, accentColor, userId)
    local key = tostring(userId or "0") .. tostring(title or "Log")
    if cooldowns[key] then return end
    cooldowns[key] = true; task.delay(ANTISPAM_TIME, function() if cooldowns then cooldowns[key] = nil end end)

    pcall(function()
        local targetPlayer = Players:GetPlayerByUserId(userId)
        local Group = Instance.new("CanvasGroup", Container)
        Group.Size = UDim2.new(1, 0, 0, 85); Group.BackgroundColor3 = Color3.fromRGB(30, 32, 35)
        Group.BorderSizePixel = 0; Group.Position = UDim2.new(1.5, 0, 0, 0); Group.GroupTransparency = 1
        Instance.new("UICorner", Group).CornerRadius = UDim.new(0, 8)
        
        local Line = Instance.new("Frame", Group); Line.Size = UDim2.new(0, 4, 1, 0); Line.BackgroundColor3 = accentColor or Color3.fromRGB(80, 80, 80)
        
        local ClickBtn = Instance.new("TextButton", Group); ClickBtn.Size = UDim2.new(1, 0, 1, 0); ClickBtn.BackgroundTransparency = 1; ClickBtn.Text = ""; ClickBtn.ZIndex = 10
        ClickBtn.MouseButton1Click:Connect(function()
            if targetPlayer and targetPlayer.Character then
                local tool = targetPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then flashHighlight(tool, Color3.new(1, 0, 0), 3, true, true) end
            end
        end)

        task.spawn(function()
            local Av = Instance.new("ImageLabel", Group); Av.Size = UDim2.new(0, 42, 0, 42); Av.Position = UDim2.new(0, 12, 0, 10); Av.BackgroundTransparency = 1; Instance.new("UICorner", Av).CornerRadius = UDim.new(1, 0)
            local s, res = pcall(function() return Players:GetUserThumbnailAsync(userId or 1, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
            if s then Av.Image = res end
        end)

        local function txt(t, p, b, sz, col)
            local l = Instance.new("TextLabel", Group); l.Text = t; l.Position = p; l.Size = UDim2.new(1, -70, 0, 20); l.Font = b and Enum.Font.GothamBold or Enum.Font.Gotham; l.TextColor3 = col or Color3.new(1,1,1); l.TextSize = sz or 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.BackgroundTransparency = 1
        end
        txt(title, UDim2.new(0, 65, 0, 10), true, 14, accentColor)
        txt(text, UDim2.new(0, 65, 0, 28), false, 12, Color3.fromRGB(200, 200, 200))

        local InvFrame = Instance.new("ScrollingFrame", Group); InvFrame.Size = UDim2.new(1, -75, 0, 26); InvFrame.Position = UDim2.new(0, 65, 0, 50); InvFrame.BackgroundTransparency = 1; InvFrame.ScrollBarThickness = 2; InvFrame.ScrollBarImageColor3 = Color3.new(1, 1, 1); InvFrame.CanvasSize = UDim2.new(0, 0, 0, 0); InvFrame.Active = true
        local InvL = Instance.new("UIListLayout", InvFrame); InvL.FillDirection = Enum.FillDirection.Horizontal; InvL.Padding = UDim.new(0, 5)
        InvL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() InvFrame.CanvasSize = UDim2.new(0, InvL.AbsoluteContentSize.X + 10, 0, 0) end)

        task.spawn(function()
            if targetPlayer then
                local bp = targetPlayer:FindFirstChild("Backpack"); if bp then for _, x in pairs(bp:GetChildren()) do if x:IsA("Tool") then local b = Instance.new("TextLabel", InvFrame); b.Text = " "..x.Name.." "; b.AutomaticSize = Enum.AutomaticSize.X; b.BackgroundColor3 = Color3.fromRGB(50, 52, 55); b.TextColor3 = Color3.new(0.9, 0.9, 0.9); b.TextSize = 10; b.Font = Enum.Font.GothamMedium; Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4) end end end
            end
        end)
        playSnd(NOTIF_SOUND); TweenService:Create(Group, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0}):Play()
        task.delay(5, function() pcall(function() local out = TweenService:Create(Group, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(1.2, 0, 0, 0), GroupTransparency = 1}); out:Play(); out.Completed:Connect(function() Group:Destroy() end) end) end)
    end)
end

-- === 5. МОНИТОРИНГ ===
function monitorEnemies(player)
    if player.AccountAge < NEWBIE_THRESHOLD then createNotif("🐣 НОВОРЕГ", player.DisplayName.." ("..player.AccountAge.." дн.)", NEWBIE_COLOR, player.UserId) end
    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 15)
        if player.AccountAge < NEWBIE_THRESHOLD then flashHighlight(char, NEWBIE_COLOR, 99999, false, false) end
        hum.HealthChanged:Connect(function(hp)
            if hp <= 0 then
                local enemyPos = char.HumanoidRootPart.Position
                local meNear = (LocalPlayer.Character and (LocalPlayer.Character.HumanoidRootPart.Position - enemyPos).Magnitude < 35)
                for _, friend in pairs(Players:GetPlayers()) do
                    if friend ~= LocalPlayer and LocalPlayer:IsFriendsWith(friend.UserId) and friend.Character then
                        if (enemyPos - friend.Character.HumanoidRootPart.Position).Magnitude < 35 then
                            if meNear then createNotif("🤝 КОЛЛАБА", LocalPlayer.DisplayName.." и "..friend.DisplayName.." убили "..player.DisplayName, COLLAB_COLOR, friend.UserId); flashHighlight(char, COLLAB_COLOR, 4, false, false)
                            else createNotif("🏆 ПОБЕДА", "Ваш друг убил "..player.DisplayName, VICTORY_COLOR, friend.UserId); flashHighlight(char, DEAD_ENEMY_COLOR, 4, false, false) end
                            break
                        end
                    end
                end
            end
        end)
    end
    if player.Character then task.spawn(onChar, player.Character) end; player.CharacterAdded:Connect(onChar)
end

function monitorFriends(player)
    if player == LocalPlayer then return end
    local function setupChar(char)
        local hum = char:WaitForChild("Humanoid", 15); if not hum then return end
        createNotif("В СЕТИ", player.DisplayName, Color3.fromRGB(100, 100, 100), player.UserId)
        
        local h = Instance.new("Highlight", char); h.FillColor = FRIEND_COLOR; h.FillTransparency = 0.5; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        
        local lastHP = hum.Health; local colorTween = nil
        local function listen(part) part.ChildAdded:Connect(function(c) if c:IsA("Sound") then createNotif("🔔 СИГНАЛ", "Видимо ваш друг начал файт!", FIGHT_COLOR, player.UserId); if colorTween then colorTween:Cancel() end; h.FillColor = FIGHT_COLOR; colorTween = TweenService:Create(h, TweenInfo.new(3), {FillColor = FRIEND_COLOR}); colorTween:Play() end end) end
        task.spawn(function() local head = char:WaitForChild("Head", 5); if head then listen(head) end; listen(char:WaitForChild("HumanoidRootPart", 5)) end)
        task.spawn(function()
            local bp = player:WaitForChild("Backpack", 5); if bp then bp.ChildAdded:Connect(function(t) if t:IsA("Tool") then createNotif("ИНВЕНТАРЬ", player.DisplayName.." взял "..t.Name, Color3.fromRGB(40, 40, 60), player.UserId) end end) end
            char.ChildAdded:Connect(function(t) if t:IsA("Tool") then createNotif("ИНВЕНТАРЬ", player.DisplayName.." экипировал "..t.Name, Color3.fromRGB(40, 40, 60), player.UserId) end end)
        end)
        task.spawn(function()
            while char and char.Parent do
                if char:FindFirstChildOfClass("Tool") then
                    local victim = findTarget(char, 18)
                    if victim then
                        local vHum = victim:FindFirstChild("Humanoid")
                        if vHum and vHum.Health > 0 and not LocalPlayer:IsFriendsWith(Players:GetPlayerFromCharacter(victim).UserId) then
                            local oldH = vHum.Health; local conn; conn = vHum.HealthChanged:Connect(function(nH) if nH < oldH then createNotif("⚔️ УДАР", "Твой друг кому то нанёс урон!", HIT_COLOR, player.UserId); flashHighlight(victim, HIT_COLOR, 2, false, false); conn:Disconnect() end end)
                            task.wait(0.5); if conn then conn:Disconnect() end
                        end
                    end
                end; task.wait(0.2)
            end
        end)
        hum.HealthChanged:Connect(function(hp)
            if hp < lastHP and hp > 0 then
                if colorTween then colorTween:Cancel() end; createNotif("🚨 АТАКА", player.DisplayName.." ["..math.floor(hp).." HP]", DAMAGE_COLOR, player.UserId); h.FillColor = DAMAGE_COLOR; colorTween = TweenService:Create(h, TweenInfo.new(0.6), {FillColor = FRIEND_COLOR}); colorTween:Play()
                local att = findTarget(char, 120); if att then flashHighlight(att, DAMAGE_COLOR, 2, false, true) end
            elseif hp <= 0 then
                -- ПОДСВЕТКА УБИЙЦЫ (ЧЕСТНАЯ - НЕ ВИДНО ЗА СТЕНАМИ)
                local killer = findTarget(char, 120); if killer then createNotif("💀 УБИЙЦА", "УБИТ ИГРОКОМ: "..killer.Name, DAMAGE_COLOR, player.UserId); flashHighlight(killer, DAMAGE_COLOR, 10, true, false) end
                if h then h:Destroy() end; playSnd(DEATH_SOUND)
            end; lastHP = hp
        end)
    end
    if player.Character then task.spawn(setupChar, player.Character) end; player.CharacterAdded:Connect(setupChar)
end

-- Цикл опасности (ЧЕСТНЫЙ - врагов НЕ видно за стенами)
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            for _, fr in pairs(Players:GetPlayers()) do
                if LocalPlayer:IsFriendsWith(fr.UserId) and fr.Character then
                    for _, en in pairs(Players:GetPlayers()) do
                        if en ~= LocalPlayer and not LocalPlayer:IsFriendsWith(en.UserId) and en.Character then
                            if (fr.Character.HumanoidRootPart.Position - en.Character.HumanoidRootPart.Position).Magnitude <= DETECTION_RADIUS and en.Character:FindFirstChildOfClass("Tool") then
                                if not en.Character:FindFirstChild("TempHighlight") then 
                                    flashHighlight(en.Character, DAMAGE_COLOR, 4, true, false) 
                                    if tick() - lastDangerNotify > 10 then createNotif("⚠️ ОПАСНОСТЬ", "Возможно рядом враг!", DAMAGE_COLOR, en.UserId); lastDangerNotify = tick() end 
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

for _, p in pairs(Players:GetPlayers()) do if LocalPlayer:IsFriendsWith(p.UserId) then monitorFriends(p) else monitorEnemies(p) end end
Players.PlayerAdded:Connect(function(p) task.wait(1); if LocalPlayer:IsFriendsWith(p.UserId) then monitorFriends(p) else monitorEnemies(p) end end)
function applyWorld() LocalPlayer.CameraMaxZoomDistance = 10000; Lighting.FogEnd = 100000 end; applyWorld(); Lighting.Changed:Connect(applyWorld)

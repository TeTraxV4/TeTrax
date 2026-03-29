zt = '<font color="#0000FF">W</font><font color="#1A33FF">Y</font><font color="#3366FF">T</font><font color="#4D80FF">V</font><font color="#6699FF">3</font><font color="#80B2FF">补</font><font color="#99CCFF">S</font>'

WindUI=loadstring(game:HttpGet("https://raw.githubusercontent.com/454244513/WindUIFix/refs/heads/main/main.lua"))()

Window=WindUI:CreateWindow({
   Title = zt,
   IconThemed=true,
   Author="五月天",
   Folder="Pirates",
   Size=UDim2.fromOffset(0, 0),
   Transparent=true,
   Background="https://chaton-images.s3.us-east-2.amazonaws.com/gBI4uU8QoX71O2c3zC9bwwIf3vt5IKvx1QMUsAYNxuA5Xj8RHU02Kphw64eFz6oj_1976x1220x2153600.jpeg",
   BackgroundImageTransparency = 0.3,
   Theme = "Dark",
   User = { 
       Enabled = true,
       Callback = function() end,
       Anonymous = false
   },
   SideBarWidth = 170,
   HideSearchBar = false,
   OpenButton = {
       Title=zt,
       Icon = "crown",
       CornerRadius = UDim.new(0.3,0),
       StrokeThickness = 2,
       Enabled = true,
       Transparent = false,
       Draggable = true,
       OnlyMobile = true,
       Scale = 0.5,
       Color = ColorSequence.new(Color3.fromHex("#0000CC"), Color3.fromHex("#ffffff"))
   }
})

-- ==================== 创建标签页====================
local Tabs = {
    aim = Window:Tab({ Title = "自瞄", Icon = "crosshair", }),
    teleport = Window:Tab({ Title = "传送玩家", Icon = "map-pin", }),
}

-- ==================== 自瞄功能 ====================

-- 依赖服务
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

-- 彩虹颜色函数
local function GetRainbowColor(hue)
    return Color3.fromHSV(hue, 1, 1)
end

-- 自瞄核心配置
local AimSettings = {
    Enabled = false,
    FOV = 100,
    Smoothness = 10,
    CrosshairDistance = 5,
    FOVColor = Color3.fromRGB(0, 255, 0),
    FriendCheck = true,
    WallCheck = true,
    TargetPlayers = {},
    TargetAll = true,
    FOVRainbowEnabled = true,
    FOVRainbowSpeed = 8,
    FOVEnabled = true,
    WeaponCheck = true
}

local AimTargetPart = "头"
local AimBlacklist = {}
local AimTeamCheck = false
local CurrentTarget = nil
local FOVCircle = nil
local AimConnection = nil
local CurrentFOVHue = 0

-- 武器白名单
local AllowedWeapons = {
    ["M1911"] = true, ["Glock"] = true, ["Stagecoach"] = true, ["Uzi"] = true,
    ["Python"] = true, ["Mossberg"] = true, ["Double Barrel"] = true, ["Deagle"] = true,
    ["MP7"] = true, ["AK-47"] = true, ["RPK"] = true, ["M4A1"] = true,
    ["M1 Garand"] = true, ["Dragunov"] = true, ["AUG"] = true, ["RPG"] = true,
    ["Scar L"] = true, ["FN FAL"] = true, ["AS Val"] = true, ["Barrett M107"] = true,
    ["P90"] = true, ["AWP"] = true, ["Flamethrower"] = true, ["M249 SAW"] = true,
}

-- 获取当前武器
local function GetCurrentWeapon()
    local success, v3item = pcall(function() return load("v3item") end)
    if not success or not v3item then return nil, "none" end
    local inventory = v3item.inventory
    if not inventory then return nil, "none" end
    local equippedItem = inventory.getEquippedItem()
    if not equippedItem then return nil, "none" end
    local weaponName = equippedItem.name
    local weaponType = weaponName == "RPG" and "rpg" or "other"
    return weaponName, weaponType
end

local function IsWeaponAllowed()
    local weaponName, _ = GetCurrentWeapon()
    if not weaponName then return false end
    return AllowedWeapons[weaponName] or false
end

local function IsFriend(player)
    if not AimSettings.FriendCheck then return false end
    local success, result = pcall(function()
        return LocalPlayer:IsFriendsWith(player.UserId)
    end)
    return success and result
end

local function WallCheck(targetPosition, targetCharacter)
    if not AimSettings.WallCheck then return true end
    pcall(function()
        local camera = Workspace.CurrentCamera
        local origin = camera.CFrame.Position
        local direction = (targetPosition - origin).Unit
        local distance = (targetPosition - origin).Magnitude
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.IgnoreWater = true
        local raycastResult = Workspace:Raycast(origin, direction * distance, raycastParams)
        return raycastResult == nil
    end)
    return true
end

local function GetTargetPosition(character, partName)
    if not character then return nil end
    local part
    if partName == "头" then
        part = character:FindFirstChild("Head")
    elseif partName == "上身" then
        part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    elseif partName == "左腿" then
        part = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("LeftUpperLeg")
    elseif partName == "右腿" then
        part = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("RightUpperLeg")
    else
        part = character:FindFirstChild("Head")
    end
    return part and part.Position
end

local function UpdateFOVCircle()
    pcall(function()
        if FOVCircle then
            FOVCircle.Visible = AimSettings.Enabled and AimSettings.FOVEnabled
            FOVCircle.Radius = AimSettings.FOV
            if AimSettings.FOVRainbowEnabled then
                FOVCircle.Color = GetRainbowColor(CurrentFOVHue)
            else
                FOVCircle.Color = AimSettings.FOVColor
            end
            FOVCircle.Position = Workspace.CurrentCamera.ViewportSize / 2
        end
    end)
end

local function GetClosestPlayer()
    local camera = Workspace.CurrentCamera
    local mousePos = camera.ViewportSize / 2
    local nearestPlayer = nil
    local shortestDistance = AimSettings.FOV

    if not AimSettings.TargetAll and #AimSettings.TargetPlayers > 0 then
        for _, targetName in ipairs(AimSettings.TargetPlayers) do
            local target = Players:FindFirstChild(targetName)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local inBlacklist = false
                for _, blackName in ipairs(AimBlacklist) do
                    if target.Name == blackName then inBlacklist = true; break end
                end
                if inBlacklist then goto continue end
                if AimTeamCheck and LocalPlayer.Team and target.Team == LocalPlayer.Team then goto continue end
                local humanoid = target.Character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local targetPos = target.Character.HumanoidRootPart.Position
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distance <= AimSettings.FOV and WallCheck(targetPos, target.Character) then
                            if not AimSettings.FriendCheck or not IsFriend(target) then
                                if distance < shortestDistance then
                                    shortestDistance = distance
                                    nearestPlayer = target
                                end
                            end
                        end
                    end
                end
            end
            ::continue::
        end
        CurrentTarget = nearestPlayer
        return nearestPlayer
    end

    if CurrentTarget and CurrentTarget ~= LocalPlayer and CurrentTarget.Character then
        local hrp = CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = CurrentTarget.Character:FindFirstChild("Humanoid")
        if hrp and humanoid and humanoid.Health > 0 then
            local inBlacklist = false
            for _, blackName in ipairs(AimBlacklist) do
                if CurrentTarget.Name == blackName then inBlacklist = true; break end
            end
            if not inBlacklist then
                if not (AimTeamCheck and LocalPlayer.Team and CurrentTarget.Team == LocalPlayer.Team) then
                    local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distance <= AimSettings.FOV and WallCheck(hrp.Position, CurrentTarget.Character) then
                            if not AimSettings.FriendCheck or not IsFriend(CurrentTarget) then
                                return CurrentTarget
                            end
                        end
                    end
                end
            end
        end
    end

    CurrentTarget = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local skip = false
            if AimSettings.FriendCheck and IsFriend(player) then skip = true end
            if not skip then
                for _, blackName in ipairs(AimBlacklist) do
                    if player.Name == blackName then skip = true; break end
                end
            end
            if not skip and AimTeamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then skip = true end
            if skip then goto nextPlayer end
            
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                if WallCheck(humanoidRootPart.Position, player.Character) then
                    local screenPos, onScreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearestPlayer = player
                        end
                    end
                end
            end
        end
        ::nextPlayer::
    end

    if nearestPlayer then CurrentTarget = nearestPlayer end
    return nearestPlayer
end

local function AimBot()
    if not AimSettings.Enabled then return end
    if AimSettings.WeaponCheck and not IsWeaponAllowed() then return end
    
    pcall(function()
        local camera = Workspace.CurrentCamera
        local target = GetClosestPlayer()
        if target and target.Character then
            local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
            local head = target.Character:FindFirstChild("Head")
            
            local targetPart = AimTargetPart
            if AimSettings.WeaponCheck then
                local _, weaponType = GetCurrentWeapon()
                if weaponType == "rpg" then targetPart = "左腿" end
            end
            
            local targetPosition = GetTargetPosition(target.Character, targetPart) or (head and head.Position) or (humanoidRootPart and humanoidRootPart.Position)
            if not targetPosition then return end
            
            if humanoidRootPart and AimSettings.CrosshairDistance > 0 then
                local targetVelocity = humanoidRootPart.Velocity
                local distance = (targetPosition - camera.CFrame.Position).Magnitude
                local timeToTarget = distance / 1000
                targetPosition = targetPosition + (targetVelocity * timeToTarget * AimSettings.CrosshairDistance)
            end
            
            local currentCFrame = camera.CFrame
            local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
            local smoothedCFrame = currentCFrame:Lerp(targetCFrame, 1 / AimSettings.Smoothness)
            camera.CFrame = smoothedCFrame
        end
    end)
end

-- 彩虹FOV更新
task.spawn(function()
    while true do
        task.wait(0.05)
        if AimSettings.FOVRainbowEnabled and AimSettings.Enabled then
            CurrentFOVHue = (CurrentFOVHue + AimSettings.FOVRainbowSpeed / 360) % 1
            UpdateFOVCircle()
        end
    end
end)

-- 创建FOV圆圈
local function InitFOVCircle()
    pcall(function()
        if not FOVCircle then
            FOVCircle = Drawing.new("Circle")
            FOVCircle.Thickness = 2
            FOVCircle.Filled = false
            FOVCircle.NumSides = 64
            FOVCircle.Transparency = 1
            FOVCircle.Visible = false
            FOVCircle.Radius = AimSettings.FOV
            FOVCircle.Position = Workspace.CurrentCamera.ViewportSize / 2
            FOVCircle.Color = AimSettings.FOVColor
        end
        UpdateFOVCircle()
    end)
end

-- 获取玩家列表
local function GetPlayerList()
    local list = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end
    return list
end

-- ==================== 自瞄UI ====================
local AimTab = Tabs.aim

AimTab:Toggle("启用自瞄", "AimToggle", false, function(value)
    AimSettings.Enabled = value
    if value then
        InitFOVCircle()
        if not AimConnection then
            AimConnection = RunService.RenderStepped:Connect(AimBot)
        end
    else
        if AimConnection then
            AimConnection:Disconnect()
            AimConnection = nil
        end
        if FOVCircle then FOVCircle.Visible = false end
    end
end)

AimTab:Toggle("仅允许武器自瞄", "WeaponOnly", false, function(value)
    AimSettings.WeaponCheck = value
end)

AimTab:Toggle("显示FOV圆圈", "FOVToggle", true, function(value)
    AimSettings.FOVEnabled = value
    if FOVCircle then FOVCircle.Visible = AimSettings.Enabled and value end
end)

AimTab:Toggle("FOV彩虹效果", "FOVRainbow", true, function(value)
    AimSettings.FOVRainbowEnabled = value
end)

AimTab:Slider("FOV彩虹速度", "FOVSpeed", 8, 1, 30, true, function(value)
    AimSettings.FOVRainbowSpeed = value
end)

AimTab:Slider("自瞄范围(FOV)", "AimFOV", 100, 30, 300, true, function(value)
    AimSettings.FOV = value
    if FOVCircle then FOVCircle.Radius = value end
end)

AimTab:Slider("自瞄平滑度", "Smoothness", 10, 1, 50, true, function(value)
    AimSettings.Smoothness = value
end)

AimTab:Slider("预判距离", "Prediction", 5, 0, 20, true, function(value)
    AimSettings.CrosshairDistance = value
end)

AimTab:ColorPicker("FOV圆圈颜色", "FOVColor", Color3.fromRGB(0, 255, 0), function(color)
    AimSettings.FOVColor = color
    if not AimSettings.FOVRainbowEnabled and FOVCircle then
        FOVCircle.Color = color
    end
end)

AimTab:Toggle("好友检测", "FriendCheck", true, function(value)
    AimSettings.FriendCheck = value
end)

AimTab:Toggle("墙壁检测", "WallCheck", true, function(value)
    AimSettings.WallCheck = value
end)

AimTab:Toggle("队伍检测", "TeamCheck", false, function(value)
    AimTeamCheck = value
end)

local targetDropdown = AimTab:Dropdown("目标自瞄模式", "TargetMode", {"所有玩家", "指定玩家"}, function(value)
    AimSettings.TargetAll = (value == "所有玩家")
end)

local playerDropdown = AimTab:Dropdown("选择目标玩家", "TargetPlayer", GetPlayerList(), function(value)
    if value and value ~= "" then
        AimSettings.TargetPlayers = {value}
    end
end)

AimTab:Dropdown("自瞄部位", "AimPart", {"头", "上身", "左腿", "右腿"}, function(value)
    AimTargetPart = value
end)

AimTab:Section("黑名单管理")
local blacklistInput = AimTab:Input("黑名单(逗号分隔)", "Blacklist", "", function(value)
    AimBlacklist = {}
    for name in string.gmatch(value, "[^,]+") do
        table.insert(AimBlacklist, string.gsub(name, "^%s*(.-)%s*$", "%1"))
    end
end)

AimTab:Button("清空白名单", function()
    AimBlacklist = {}
    blacklistInput:SetText("")
end)

AimTab:Section("快速预设")
AimTab:Button("强锁[子弹有延迟]", function()
    AimSettings.FOV = 99
    AimSettings.Smoothness = 1
    AimSettings.CrosshairDistance = 0.96
    if FOVCircle then FOVCircle.Radius = 99 end
end)

AimTab:Button("强锁[子弹无延迟]", function()
    AimSettings.FOV = 120
    AimSettings.Smoothness = 1
    AimSettings.CrosshairDistance = 0
    if FOVCircle then FOVCircle.Radius = 120 end
end)

AimTab:Button("平滑类", function()
    AimSettings.FOV = 130
    AimSettings.Smoothness = 6
    AimSettings.CrosshairDistance = 1
    if FOVCircle then FOVCircle.Radius = 130 end
end)

AimTab:Section("当前状态")
local statusLabel = AimTab:Label("自瞄状态: 未启用")

task.spawn(function()
    while true do
        task.wait(0.5)
        if AimSettings.Enabled then
            statusLabel:SetText("自瞄状态: 已启用" .. (CurrentTarget and (" | 目标: " .. CurrentTarget.Name) or ""))
        else
            statusLabel:SetText("自瞄状态: 未启用")
        end
    end
end)

-- 更新玩家列表
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        if playerDropdown and playerDropdown.AddOption then
            playerDropdown:AddOption(player.Name)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        if playerDropdown and playerDropdown.RemoveOption then
            playerDropdown:RemoveOption(player.Name)
        end
    end
end)

-- ==================== 传送玩家功能 ====================

local TeleportSettings = {
    SelectPlr = nil,
    SnipePlr = false,
    SnipeAllPlrs = false,
    SnipeToHeadLookVector = false,
    PredTeleport = false,
    PredValue = 2,
    BringPlayerDistance = 6
}

local TeleportTab = Tabs.teleport

-- 获取玩家列表函数
local function GetTeleportPlayerList()
    local list = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end
    return list
end

-- 传送到选中玩家
local function TeleportToSelectedPlayer()
    pcall(function()
        local target = Players:FindFirstChild(TeleportSettings.SelectPlr)
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
        end
    end)
end

-- 预判传送
local function PredTeleportLoop()
    while TeleportSettings.PredTeleport do
        pcall(function()
            local target = Players:FindFirstChild(TeleportSettings.SelectPlr)
            if target and target.Character and target.Character.Humanoid and target.Character.Humanoid.Health > 0 then
                local root = target.Character.HumanoidRootPart
                local ping = LocalPlayer:GetNetworkPing() * 2
                local pred_pos = root.CFrame + root.Velocity * ping * TeleportSettings.PredValue
                LocalPlayer.Character.HumanoidRootPart.CFrame = pred_pos
            end
        end)
        task.wait()
    end
end

-- 传送到玩家身后
local function TeleportBehindPlayerLoop()
    while TeleportSettings.SnipePlr do
        pcall(function()
            local target = Players:FindFirstChild(TeleportSettings.SelectPlr)
            if target and target.Character and target.Character.Humanoid and target.Character.Humanoid.Health > 0 then
                local root = target.Character.HumanoidRootPart
                LocalPlayer.Character.HumanoidRootPart.CFrame = root.CFrame - root.CFrame.LookVector * TeleportSettings.BringPlayerDistance
            end
        end)
        task.wait()
    end
end

-- 吸玩家到面前
local function PullPlayerToFaceLoop()
    while TeleportSettings.SnipeToHeadLookVector do
        pcall(function()
            local target = Players:FindFirstChild(TeleportSettings.SelectPlr)
            if target and target.Character and target.Character.Humanoid and target.Character.Humanoid.Health > 0 then
                local head = LocalPlayer.Character.Head
                local target_root = target.Character.HumanoidRootPart
                local target_seat = target.Character.Humanoid.SeatPart
                local target_pos = head.CFrame + head.CFrame.LookVector * TeleportSettings.BringPlayerDistance
                if target_seat then
                    target_seat.CFrame = target_pos
                else
                    target_root.CFrame = target_pos
                end
            end
        end)
        task.wait()
    end
end

-- 吸全体玩家
local function PullAllPlayersLoop()
    while TeleportSettings.SnipeAllPlrs do
        pcall(function()
            for _, player in pairs(Players:GetPlayers()) do
                if not TeleportSettings.SnipeAllPlrs then return end
                if player ~= LocalPlayer and player.Character and player.Character.Humanoid and player.Character.Humanoid.Health > 0 then
                    local head = LocalPlayer.Character.Head
                    local target_root = player.Character.HumanoidRootPart
                    target_root.CFrame = head.CFrame + head.CFrame.LookVector * TeleportSettings.BringPlayerDistance
                end
            end
        end)
        task.wait()
    end
end

-- 停止所有传送
local function StopAllTeleports()
    TeleportSettings.PredTeleport = false
    TeleportSettings.SnipePlr = false
    TeleportSettings.SnipeToHeadLookVector = false
    TeleportSettings.SnipeAllPlrs = false
end

-- ==================== 传送玩家UI ====================

local teleportDropdown = TeleportTab:Dropdown("选择玩家", "SelectPlayer", GetTeleportPlayerList(), function(player)
    TeleportSettings.SelectPlr = player
end)

TeleportTab:Button("传送到选中玩家", function()
    TeleportToSelectedPlayer()
end)

TeleportTab:Toggle("循环预判传送", "PredToggle", false, function(value)
    TeleportSettings.PredTeleport = value
    if value then
        coroutine.wrap(PredTeleportLoop)()
    end
end)

TeleportTab:Slider("预判倍数", "PredSlider", 2, 0.1, 10, true, function(value)
    TeleportSettings.PredValue = value
end)

TeleportTab:Toggle("循环传送到玩家身后", "BehindToggle", false, function(value)
    TeleportSettings.SnipePlr = value
    if value then
        coroutine.wrap(TeleportBehindPlayerLoop)()
    end
end)

TeleportTab:Toggle("吸选中玩家到面前", "PullToggle", false, function(value)
    TeleportSettings.SnipeToHeadLookVector = value
    if value then
        coroutine.wrap(PullPlayerToFaceLoop)()
    end
end)

TeleportTab:Toggle("吸全体玩家", "PullAllToggle", false, function(value)
    TeleportSettings.SnipeAllPlrs = value
    if value then
        coroutine.wrap(PullAllPlayersLoop)()
    end
end)

TeleportTab:Slider("传送/吸人距离", "DistanceSlider", 6, 1, 20, true, function(value)
    TeleportSettings.BringPlayerDistance = value
end)

TeleportTab:Button("停止所有传送", function()
    StopAllTeleports()
end)

-- 更新传送玩家列表
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        if teleportDropdown and teleportDropdown.AddOption then
            teleportDropdown:AddOption(player.Name)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        if teleportDropdown and teleportDropdown.RemoveOption then
            teleportDropdown:RemoveOption(player.Name)
        end
    end
end)

-- ==================== 窗口特效 ====================
task.spawn(function()
    local mc
    if Window.UIElements and Window.UIElements.Main then
        mc = Window.UIElements.Main
    elseif Window:FindFirstChild("Main") then
        mc = Window.Main
    end
    
    if mc then
        local s = Instance.new("UIStroke")
        s.Name = "RS"
        s.Thickness = 2
        s.Color = Color3.new(1, 1, 1)
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        
        local g = Instance.new("UIGradient")
        g.Name = "RG"
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#000000")),
            ColorSequenceKeypoint.new(0.3, Color3.fromHex("#001f3f")),
            ColorSequenceKeypoint.new(0.6, Color3.fromHex("#0066cc")),
            ColorSequenceKeypoint.new(0.8, Color3.fromHex("#3385ff")),
            ColorSequenceKeypoint.new(1, Color3.fromHex("#000000"))
        })
        g.Enabled = true
        g.Offset = Vector2.new(0, 0)
        g.Parent = s
        s.Parent = mc
        
        task.spawn(function()
            while mc and mc.Parent do
                task.wait(0.01)
                g.Rotation = (g.Rotation + 3) % 360
            end
        end)
    end
end)
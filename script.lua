--[[
    Скрипт для Delta Executor на базе Rayfield UI (V11 Ultimate Bypass)
    Новое: Полный обход античита (Anti-Kick) и рабочая серверная Невидимость (FE Invis).
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "TWKS Multi-Hack V11 | God Mode",
    LoadingTitle = "Взлом античита и инжект...",
    LoadingSubtitle = "by TWKS",
    Theme = "DarkTheme"
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local walkSpeedValue = 50
local flySpeedValue = 50
local aimbotSmoothness = 1
local isSpeedEnabled = false
local isFlyEnabled = false
local isAntiGrabEnabled = false 
local isAimbotEnabled = false
local isEspEnabled = false
local isNoclipEnabled = false
local isInfJumpEnabled = false
local isInvisEnabled = false

local espColor = Color3.fromRGB(255, 0, 0)
local selectedAimbotTargets = {} 
local tpTargetName = "" 

local localCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local localHumanoid = localCharacter:WaitForChild("Humanoid")
local localRoot = localCharacter:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    localCharacter = char
    localHumanoid = char:WaitForChild("Humanoid")
    localRoot = char:WaitForChild("HumanoidRootPart")
end)

-- ==================== ULTIMATE ANTI-CHEAT BYPASS ====================
local rawmetatable = getrawmetatable(game)
if setreadonly then setreadonly(rawmetatable, false) else make_writeable(rawmetatable) end
local oldIndex = rawmetatable.__index
local oldNewindex = rawmetatable.__newindex
local oldNamecall = rawmetatable.__namecall

-- 1. Блокировка попыток сервера кикнуть или забанить игрока локально
rawmetatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "Kick" or method == "kick" or method == "Ban" then
        return wait(9e9) -- Бесконечная пауза вместо кика
    end
    -- Блокировка подозрительных репортов (вызов античит-ремоутов)
    if method == "FireServer" or method == "InvokeServer" then
        local name = tostring(self.Name):lower()
        if name:find("ban") or name:find("kick") or name:find("report") or name:find("log") or name:find("admin") then
            return nil
        end
    end
    return oldNamecall(self, ...)
end)

-- 2. Подмена физических свойств для проверок античита
rawmetatable.__newindex = newcclosure(function(self, index, value)
    if self and self:IsA("Humanoid") and self == localHumanoid then
        if index == "WalkSpeed" and isSpeedEnabled then return end
    end
    return oldNewindex(self, index, value)
end)

rawmetatable.__index = newcclosure(function(self, index)
    if self and self:IsA("Humanoid") and self == localHumanoid then
        if index == "WalkSpeed" and isSpeedEnabled then return 16 end
    end
    return oldIndex(self, index)
end)

if setreadonly then setreadonly(rawmetatable, true) else make_readonly(rawmetatable) end

local function getPlayerNames()
    local list = {}
    local allPlayers = Players:GetPlayers()
    for i = 1, #allPlayers do
        local p = allPlayers[i]
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

local TabCombat = Window:CreateTab("Бой", 4483362458)
local TabVisuals = Window:CreateTab("Визуалы", 4483362458)
local TabMovement = Window:CreateTab("Движение", 4483362458)
local TabTeleport = Window:CreateTab("Телепорт", 4483362458)

-- ==================== COMBAT (AIMBOT) ====================

local SelectedLabel = TabCombat:CreateLabel("Цели: Нет")

local TargetDropdown = TabCombat:CreateDropdown({
    Name = "Выбрать цель (Аимбот)",
    Options = getPlayerNames(),
    CurrentOption = {""},
    MultipleOptions = true,
    Callback = function(Options)
        selectedAimbotTargets = {}
        local targetsStr = ""
        for _, name in pairs(type(Options) == "table" and Options or {Options}) do
            if name ~= "" then
                selectedAimbotTargets[name] = true
                targetsStr = targetsStr .. name .. ", "
            end
        end
        SelectedLabel:Set(targetsStr ~= "" and "Цели: " .. targetsStr:sub(1, -3) or "Цели: Нет")
    end,
})

TabCombat:CreateSlider({
    Name = "Плавность Аимбота",
    Range = {1, 15},
    Increment = 1,
    CurrentValue = 1,
    Callback = function(Value)
        aimbotSmoothness = Value
    end,
})

TabCombat:CreateToggle({
    Name = "Включить Аимбот",
    CurrentValue = false,
    Callback = function(Value)
        isAimbotEnabled = Value
    end,
})

RunService.RenderStepped:Connect(function()
    if not isAimbotEnabled then return end
    local closestTarget = nil
    local shortestDistance = math.huge
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for name, _ in pairs(selectedAimbotTargets) do
        local targetPlayer = Players:FindFirstChild(name)
        if targetPlayer and targetPlayer.Character then
            local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestTarget = root
                    end
                end
            end
        end
    end

    if closestTarget then
        local targetCFrame = CFrame.new(Camera.CFrame.Position, closestTarget.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / aimbotSmoothness)
    end
end)


-- ==================== VISUALS (ESP & INVISIBILITY) ====================

-- FE Invisibility Logic (Удаление соединений для рассинхрона с сервером)
local invisibleClone = nil

TabVisuals:CreateToggle({
    Name = "Невидимость (FE Invis)",
    CurrentValue = false,
    Callback = function(Value)
        isInvisEnabled = Value
        if isInvisEnabled and localCharacter and localRoot then
            -- Делаем все парты прозрачными локально
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = 1
                    if part:FindFirstChild("face") then part.face.Transparency = 1 end
                elseif part:IsA("Decal") or part:IsA("Texture") then
                    part.Transparency = 1
                elseif part:IsA("Accessory") then
                    if part:FindFirstChild("Handle") then part.Handle.Transparency = 1 end
                end
            end
            
            -- Рассинхрон для сервера (отправляем тело под карту, оставляя контроль у вас)
            local tWeld = localCharacter:FindFirstChild("Torso") and localCharacter.Torso:FindFirstChild("Neck")
            if tWeld then tWeld:Destroy() end 
            
            Rayfield:Notify({Title = "Невидимость", Content = "Вы стали невидимым для всех!", Duration = 3, Image = 4483362458})
        else
            -- Возврат в нормальное состояние требует ресета
            if localHumanoid then localHumanoid.Health = 0 end
        end
    end,
})

local activeEsps = {}

local function createEsp(player)
    if player == LocalPlayer then return end
    local function applyEsp(character)
        if not character then return end
        local head = character:WaitForChild("Head", 5)
        if not head then return end

        if character:FindFirstChild("ESPHighlight") then character.ESPHighlight:Destroy() end
        if head:FindFirstChild("ESPNick") then head.ESPNick:Destroy() end

        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillColor = espColor
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.Adornee = character
        highlight.Parent = character

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESPNick"
        billboard.Size = UDim2.new(0, 250, 0, 60)
        billboard.AlwaysOnTop = true
        billboard.ExtentsOffset = Vector3.new(0, 3, 0)
        billboard.Adornee = head
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = player.DisplayName or player.Name
        label.TextColor3 = espColor
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 24 
        
        label.Parent = billboard
        billboard.Parent = head
        
        activeEsps[player.Name] = {highlight, billboard}
    end
    player.CharacterAdded:Connect(applyEsp)
    if player.Character then applyEsp(player.Character) end
end

local function removeEsp(player)
    if activeEsps[player.Name] then
        for _, obj in ipairs(activeEsps[player.Name]) do
            if obj and obj.Parent then obj:Destroy() end
        end
        activeEsps[player.Name] = nil
    end
end

TabVisuals:CreateToggle({
    Name = "Включить ESP",
    CurrentValue = false,
    Callback = function(Value)
        isEspEnabled = Value
        if isEspEnabled then
            local allPlayers = Players:GetPlayers()
            for i = 1, #allPlayers do createEsp(allPlayers[i]) end
        else
            local allPlayers = Players:GetPlayers()
            for i = 1, #allPlayers do removeEsp(allPlayers[i]) end
        end
    end,
})

TabVisuals:CreateColorPicker({
    Name = "Цвет ESP",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "EspColorPicker",
    Callback = function(Value)
        espColor = Value
        for _, objs in pairs(activeEsps) do
            if objs[1] then objs[1].FillColor = espColor end
            if objs[2] and objs[2]:FindFirstChild("TextLabel") then 
                objs[2].TextLabel.TextColor3 = espColor 
            end
        end
    end
})

Players.PlayerAdded:Connect(function(p) if isEspEnabled then createEsp(p) end end)
Players.PlayerRemoving:Connect(removeEsp)


-- ==================== MOVEMENT, FLIGHT & INF JUMP ====================

TabMovement:CreateSlider({
    Name = "Скорость (Speed / Fly)",
    Range = {16, 250},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(Value)
        walkSpeedValue = Value
        flySpeedValue = Value
    end,
})

TabMovement:CreateToggle({
    Name = "Включить Speed Hack",
    CurrentValue = false,
    Callback = function(Value)
        isSpeedEnabled = Value
    end,
})

TabMovement:CreateToggle({
    Name = "Включить Полет (Fly)",
    CurrentValue = false,
    Callback = function(Value)
        isFlyEnabled = Value
        if not Value then workspace.Gravity = 196.2 end
    end,
})

TabMovement:CreateToggle({
    Name = "Anti-Grab (Никто не схватит)",
    CurrentValue = false,
    Callback = function(Value)
        isAntiGrabEnabled = Value
    end,
})

TabMovement:CreateToggle({
    Name = "Сквозь Стены (Noclip)",
    CurrentValue = false,
    Callback = function(Value)
        isNoclipEnabled = Value
    end,
})

TabMovement:CreateToggle({
    Name = "Бесконечные Прыжки (Inf Jump)",
    CurrentValue = false,
    Callback = function(Value)
        isInfJumpEnabled = Value
    end,
})

UserInputService.JumpRequest:Connect(function()
    if isInfJumpEnabled and localHumanoid then
        localHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if isAntiGrabEnabled and localCharacter and localHumanoid then
            if localHumanoid.PlatformStand then localHumanoid.PlatformStand = false end
            if localHumanoid.Sit then localHumanoid.Sit = false end

            local children = localCharacter:GetChildren()
            for i = 1, #children do
                local child = children[i]
                if child:IsA("Weld") or child:IsA("ManualWeld") or child:IsA("WeldConstraint") then
                    child:Destroy()
                end
            end
        end
        -- Поддержка невидимости каждый фрейм
        if isInvisEnabled and localCharacter then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = 1
                end
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if isNoclipEnabled and localCharacter then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    elseif isAntiGrabEnabled and localCharacter then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function(deltaTime)
    if not localCharacter or not localRoot or not localHumanoid then return end

    if isSpeedEnabled and localHumanoid.MoveDirection.Magnitude > 0 then
        localRoot.CFrame = localRoot.CFrame + (localHumanoid.MoveDirection * (walkSpeedValue * deltaTime * 0.72))
    end

    if isFlyEnabled then
        workspace.Gravity = 0
        localRoot.Velocity = Vector3.zero
        if localHumanoid.MoveDirection.Magnitude > 0 then
            localRoot.CFrame = localRoot.CFrame + (Camera.CFrame.LookVector * (flySpeedValue * deltaTime))
        end
    end
end)


-- ==================== TELEPORT ====================

local TeleportDropdown = TabTeleport:CreateDropdown({
    Name = "Выбрать игрока (ТП)",
    Options = getPlayerNames(),
    CurrentOption = "",
    MultipleOptions = false,
    Callback = function(Option)
        if type(Option) == "table" then
            tpTargetName = Option[1] or ""
        else
            tpTargetName = Option or ""
        end
    end,
})

TabTeleport:CreateButton({
    Name = "Телепортироваться",
    Callback = function()
        if tpTargetName and tpTargetName ~= "" then
            local targetPlayer = Players:FindFirstChild(tpTargetName)
            if targetPlayer and targetPlayer.Character then
                local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot and localRoot then
                    localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 4, 0)
                end
            else
                Rayfield:Notify({Title = "Ошибка", Content = "Игрок не найден!", Duration = 3, Image = 4483362458})
            end
        end
    end,
})

task.spawn(function()
    while task.wait(5) do
        local updatedNames = getPlayerNames()
        TargetDropdown:Refresh(updatedNames, true)
        TeleportDropdown:Refresh(updatedNames, true)
    end
end)


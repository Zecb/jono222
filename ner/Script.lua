-- ============================================================
-- AUTO VOTE + SPEEDUP + ANTI-AFK + UNITS + UPGRADES + SAVE + AUTO REPLAY + MENU BIND
-- + ACCOUNT CONFIGS (по UserId) + AUTO-LOAD (auto-inject после телепорта)
-- ============================================================

local repo = 'https://raw.githubusercontent.com/Progoonerfrfr/LinoriaLib/main/'

local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Auto Vote Menu',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Vote      = Window:AddTab('Голосование'),
    SpeedUp   = Window:AddTab('Скорость'),
    Units     = Window:AddTab('Юниты'),
    Utilities = Window:AddTab('Утилиты'),
    Settings  = Window:AddTab('Настройки'),
}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local MODIFIERS = {
    " Shiny", " Void", " Gold", " Rainbow", " Diamond",
    " Crystal", " Galaxy", " Divine", " Cosmic",
}

local function stripModifier(name)
    if type(name) ~= "string" then return name end
    local base = name
    for _, mod in ipairs(MODIFIERS) do
        if base:sub(-#mod) == mod then
            base = base:sub(1, #base - #mod)
            break
        end
    end
    return base
end

local function parseLevel(str)
    if type(str) ~= 'string' then return nil end
    local num = str:match('%d+')
    if num then return tonumber(num) end
    return nil
end

local function parseLevelInfo(text)
    if type(text) ~= 'string' then return nil end
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    if current and max then
        return { current = tonumber(current), max = tonumber(max) }
    end
    return nil
end

local function clickButton(btn, forceVisible)
    if not btn or not btn.Parent then return false end
    if forceVisible then
        local p = btn.Parent
        local depth = 0
        while p and p ~= game and depth < 10 do
            if p:IsA("GuiObject") and not p.Visible then
                p.Visible = true
            end
            p = p.Parent
            depth = depth + 1
        end
    end
    local fired = false
    if getconnections then
        for _, sigName in ipairs({'Activated', 'MouseButton1Click', 'MouseButton1Down'}) do
            local sig = btn[sigName]
            if sig then
                local ok, conns = pcall(getconnections, sig)
                if ok and conns then
                    for _, c in pairs(conns) do
                        if c.Enabled then
                            pcall(function() c:Fire() end)
                            fired = true
                        end
                    end
                end
            end
        end
    end
    if not fired and firesignal then
        pcall(firesignal, btn.Activated)
        pcall(firesignal, btn.MouseButton1Click)
        fired = true
    end
    pcall(function() btn:Activate() end)
    return fired
end

local function getHRP()
    local char = game:GetService("Players").LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- 💰 ПАРСЕР ЧИСЕЛ
-- ============================================================
local SUFFIXES = {
    K=1e3, M=1e6, B=1e9, T=1e12, Q=1e15, QA=1e15, QI=1e18,
    SX=1e21, SP=1e24, OC=1e27, NO=1e30, DC=1e33,
}

local function parseMoney(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return nil end
    local cleaned = str:gsub("[^%d%.%a]", ""):upper()
    if cleaned == "" then return nil end
    if cleaned:find("MAX") or cleaned:find("FULL") then return nil end
    local numStr, suffix = cleaned:match("^(%d+%.?%d*)(%a*)$")
    if not numStr then
        local only = cleaned:match("^(%d+%.?%d*)")
        if only then return tonumber(only) end
        return nil
    end
    local num = tonumber(numStr)
    if not num then return nil end
    if suffix == "" then return math.floor(num) end
    local mult = SUFFIXES[suffix]
    if not mult and #suffix >= 2 then mult = SUFFIXES[suffix:sub(1, 2)] end
    if not mult then mult = SUFFIXES[suffix:sub(1, 1)] end
    if not mult then return math.floor(num) end
    return math.floor(num * mult)
end

local function getMoney()
    local ok, money = pcall(function()
        return game:GetService("Players").LocalPlayer.leaderstats.Money
    end)
    if not ok or not money then return 0 end
    return parseMoney(tostring(money.Value)) or 0
end

-- ============================================================
-- 🎯 ЛИМИТЫ
-- ============================================================
local RS = game:GetService("ReplicatedStorage")
local Modules = RS:WaitForChild("Modules", 10)

local TOWER_LIMITS = {}

local function loadTowerLimits()
    if not Modules then return false end
    local limitModule = Modules:FindFirstChild("TowersPlacementsMax")
    if not limitModule then return false end
    local ok, data = pcall(require, limitModule)
    if ok and type(data) == "table" then
        TOWER_LIMITS = data
        local count = 0
        for _ in pairs(data) do count = count + 1 end
        print('[Limits] 📋 Загружено лимитов:', count)
        return true
    end
    return false
end
loadTowerLimits()

local function getLimitForUnit(displayName)
    local base = stripModifier(displayName)
    return TOWER_LIMITS[base] or TOWER_LIMITS[displayName] or 1
end

-- ============================================================
-- 🎯 REMOTES
-- ============================================================
local Functions = RS:WaitForChild("Functions", 10)

local RequestTower, SpawnTower, GetPlayerPlacement
local function loadRemotes()
    if not Functions then return false end
    RequestTower       = Functions:FindFirstChild("RequestTower")
    SpawnTower         = Functions:FindFirstChild("SpawnTower")
    GetPlayerPlacement = Functions:FindFirstChild("GetPlayerPlacement")
    return RequestTower and SpawnTower
end
loadRemotes()

local function findUnitIdByName(baseName)
    local ok, folder = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.UnitManager.Units
    end)
    if not ok or not folder then return nil end

    for _, unit in ipairs(folder:GetChildren()) do
        if unit:IsA("GuiObject") then
            local unitNameLabel = unit:FindFirstChild("UnitName")
            local unitId = unit:FindFirstChild("UnitID")

            if unitNameLabel and unitId and unitId:IsA("StringValue") then
                if unitNameLabel.Text == baseName then
                    return unitId.Value
                end
            end
        end
    end
    return nil
end

local function getOwnedVariants(baseName)
    local result = {}
    local ok, gameFolder = pcall(function()
        return RS:FindFirstChild("Game")
    end)
    if not ok or not gameFolder then return result end

    local towersExists = gameFolder:FindFirstChild("TowersExists")
    if not towersExists then return result end

    for _, child in ipairs(towersExists:GetChildren()) do
        local name = child.Name
        if name == baseName then
            table.insert(result, 1, name)
        elseif #name > #baseName and name:sub(1, #baseName) == baseName then
            local nextChar = name:sub(#baseName + 1, #baseName + 1)
            if nextChar == " " then
                table.insert(result, name)
            end
        end
    end

    return result
end

-- ============================================================
-- 🗳 ГОЛОСОВАНИЕ
-- ============================================================
local function getAllVoteButtons()
    local result = {}
    local ok, voting = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.Voting
    end)
    if not ok or not voting then return result end
    local function scan(folder, prefix)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("ImageButton") or child:IsA("TextButton") then
                result[prefix .. " " .. child.Name] = child
            end
        end
    end
    scan(voting:FindFirstChild("Maps"),      "[Map]")
    scan(voting:FindFirstChild("Universes"), "[Universe]")
    return result
end

local allButtons, filteredKeys, selectedKey, searchQuery = {}, {}, nil, ''

local VoteGroup = Tabs.Vote:AddLeftGroupbox('🗳 Карты')

local SearchInputOpt = VoteGroup:AddInput('SearchInput', {
    Text = '🔍 Поиск карты', Default = '', Placeholder = 'raid, endless...',
    Numeric = false, Finished = false,
    Callback = function(Value)
        searchQuery = string.lower(Value or '')
        task.spawn(function()
            task.wait(0.05)
            if _G.__refreshVoteList then _G.__refreshVoteList(true) end
        end)
    end,
})

local TargetDropdown = VoteGroup:AddDropdown('VoteTarget', {
    Values = {}, Default = 1, Multi = false, Text = 'Карта',
    Callback = function(Value)
        selectedKey = Value
        if Value then print('[AutoVote] Выбрано:', Value) end
    end,
})

local function refreshList(silent)
    allButtons = getAllVoteButtons()
    filteredKeys = {}
    for k in pairs(allButtons) do
        if searchQuery == '' or string.find(string.lower(k), searchQuery, 1, true) then
            table.insert(filteredKeys, k)
        end
    end
    table.sort(filteredKeys)
    TargetDropdown:SetValues(filteredKeys)
    if not silent then Library:Notify('🔄 Найдено: ' .. #filteredKeys, 2) end
    if selectedKey and not allButtons[selectedKey] then selectedKey = nil end
end

_G.__refreshVoteList = refreshList

VoteGroup:AddButton({ Text = '🔄 Обновить', Func = function() refreshList(false) end })
VoteGroup:AddButton({
    Text = '❌ Очистить поиск',
    Func = function()
        searchQuery = ''
        pcall(function() SearchInputOpt:SetValue('') end)
        refreshList(false)
    end,
})

local autoVoteEnabled = false
VoteGroup:AddToggle('AutoVoteToggle', {
    Text = '🎯 Авто войт карты', Default = false,
    Callback = function(Value)
        autoVoteEnabled = Value
        if Value then
            task.spawn(function()
                local lastLogged = nil
                while autoVoteEnabled do
                    if not selectedKey or not allButtons[selectedKey] or not allButtons[selectedKey].Parent then
                        refreshList(true)
                    end
                    if selectedKey and allButtons[selectedKey] and allButtons[selectedKey].Parent then
                        clickButton(allButtons[selectedKey])
                        if selectedKey ~= lastLogged then
                            lastLogged = selectedKey
                            print('[AutoVote] ✅', selectedKey)
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

local AutoRefreshToggle = VoteGroup:AddToggle('AutoRefreshToggle', { Text = 'Авто-обновление', Default = true })

task.spawn(function()
    while task.wait(2) do
        if AutoRefreshToggle and AutoRefreshToggle.Value then refreshList(true) end
    end
end)
refreshList(true)

local function getAllComplicationButtons()
    local result = {}
    local ok, folder = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.ComplicationVoting.Modes
    end)
    if not ok or not folder then return result end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("ImageButton") or child:IsA("TextButton") then
            result[child.Name] = child
        else
            for _, sub in ipairs(child:GetDescendants()) do
                if sub:IsA("TextButton") or sub:IsA("ImageButton") then
                    result[child.Name] = sub
                    break
                end
            end
        end
    end
    return result
end

local compButtons, compKeys, selectedComp, compSearch = {}, {}, nil, ''

local CompGroup = Tabs.Vote:AddRightGroupbox('🎯 Сложности')

local CompSearchOpt = CompGroup:AddInput('CompSearchInput', {
    Text = '🔍 Поиск сложности', Default = '', Placeholder = 'nightmare...',
    Numeric = false, Finished = false,
    Callback = function(Value)
        compSearch = string.lower(Value or '')
        task.spawn(function()
            task.wait(0.05)
            if _G.__refreshCompList then _G.__refreshCompList(true) end
        end)
    end,
})

local CompDropdown = CompGroup:AddDropdown('CompTarget', {
    Values = {}, Default = 1, Multi = false, Text = 'Сложность',
    Callback = function(Value)
        selectedComp = Value
        if Value then print('[Complication] Выбрано:', Value) end
    end,
})

local function refreshCompList(silent)
    compButtons = getAllComplicationButtons()
    compKeys = {}
    for k in pairs(compButtons) do
        if compSearch == '' or string.find(string.lower(k), compSearch, 1, true) then
            table.insert(compKeys, k)
        end
    end
    table.sort(compKeys)
    CompDropdown:SetValues(compKeys)
    if not silent then Library:Notify('🔄 Сложностей: ' .. #compKeys, 2) end
end

_G.__refreshCompList = refreshCompList

CompGroup:AddButton({ Text = '🔄 Обновить', Func = function() refreshCompList(false) end })

local autoCompEnabled = false
CompGroup:AddToggle('AutoCompToggle', {
    Text = '🎯 Авто голос сложности', Default = false,
    Callback = function(Value)
        autoCompEnabled = Value
        if Value then
            task.spawn(function()
                local lastLogged = nil
                while autoCompEnabled do
                    if not selectedComp or not compButtons[selectedComp] or not compButtons[selectedComp].Parent then
                        refreshCompList(true)
                    end
                    if selectedComp and compButtons[selectedComp] and compButtons[selectedComp].Parent then
                        clickButton(compButtons[selectedComp])
                        if selectedComp ~= lastLogged then
                            lastLogged = selectedComp
                            print('[Complication] ✅', selectedComp)
                        end
                    end
                    task.wait(0.8)
                end
            end)
        end
    end,
})

task.spawn(function()
    while task.wait(1) do refreshCompList(true) end
end)
refreshCompList(true)

-- ============================================================
-- 💾 СОХРАНЕНИЕ (по аккаунту)
-- ============================================================
local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer
local USER_ID      = tostring(LocalPlayer.UserId)

local BASE_FOLDER     = 'AutoVoteMenu'
local CONFIGS_FOLDER  = 'AutoVoteMenu/configs'
local ACCOUNTS_FOLDER = 'AutoVoteMenu/accounts'

local POSITIONS_FILE = CONFIGS_FOLDER .. '/' .. USER_ID .. '_positions.json'
local SPEED_FILE     = CONFIGS_FOLDER .. '/' .. USER_ID .. '_speed.json'
local ACCOUNT_FILE   = CONFIGS_FOLDER .. '/' .. USER_ID .. '_account.txt'
local ACC_FOLDER     = ACCOUNTS_FOLDER .. '/' .. USER_ID

local savedPositions = {}
local selectedLevel = nil
local speedInterval = 3

local function ensureFolders()
    if makefolder and type(makefolder) == "function" then
        pcall(makefolder, BASE_FOLDER)
        pcall(makefolder, CONFIGS_FOLDER)
        pcall(makefolder, ACCOUNTS_FOLDER)
        pcall(makefolder, ACC_FOLDER)
    end
end
ensureFolders()

print('[Configs] 📁 Аккаунт:', LocalPlayer.Name, '| UserId:', USER_ID)

local function saveAccountInfo()
    if not writefile then return end
    local info = string.format(
        "Name: %s\nUserId: %d\nLastSave: %s\n",
        LocalPlayer.Name, LocalPlayer.UserId, os.date("%Y-%m-%d %H:%M:%S")
    )
    pcall(function()
        ensureFolders()
        writefile(ACCOUNT_FILE, info)
    end)
end
saveAccountInfo()

-- === СКОРОСТЬ ===
local function saveSpeedToFile()
    if not writefile then return false end
    local json = string.format('{\n "level": %d,\n "interval": %.2f\n}', selectedLevel or 0, speedInterval or 3)
    return pcall(function()
        ensureFolders()
        writefile(SPEED_FILE, json)
    end)
end

local function loadSpeedFromFile()
    if not readfile or not isfile then return false end
    local exists = false
    pcall(function() exists = isfile(SPEED_FILE) end)
    if not exists then return false end
    local content = nil
    pcall(function() content = readfile(SPEED_FILE) end)
    if not content or content == "" then return false end
    local lvl = content:match('"level"%s*:%s*(%d+)')
    local interval = content:match('"interval"%s*:%s*([%d%.]+)')
    if lvl then
        local n = tonumber(lvl)
        if n and n > 0 then selectedLevel = n end
    end
    if interval then speedInterval = tonumber(interval) or 3 end
    return true
end

-- === ПОЗИЦИИ ===
local function savePositionsToFile()
    if not writefile then return false end
    local function esc(s)
        return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    end
    local lines = {}
    for _, p in ipairs(savedPositions) do
        table.insert(lines, string.format(
            '  {"name":%s,"x":%.4f,"y":%.4f,"z":%.4f}',
            esc(p.name), p.pos.X, p.pos.Y, p.pos.Z))
    end
    local json = '{\n "positions": [\n' .. table.concat(lines, ',\n') .. '\n ]\n}'
    return pcall(function()
        ensureFolders()
        writefile(POSITIONS_FILE, json)
    end)
end

local function loadPositionsFromFile()
    if not readfile or not isfile then return false end
    local exists = false
    pcall(function() exists = isfile(POSITIONS_FILE) end)
    if not exists then return false end
    local content = nil
    pcall(function() content = readfile(POSITIONS_FILE) end)
    if not content or content == "" then return false end

    local loaded = {}
    for obj in content:gmatch('{([^{}]+)}') do
        local name = obj:match('"name":"([^"]*)"')
        local x = obj:match('"x":([%-%d%.]+)')
        local y = obj:match('"y":([%-%d%.]+)')
        local z = obj:match('"z":([%-%d%.]+)')
        if name and x and y and z then
            table.insert(loaded, {
                name = name,
                pos = Vector3.new(tonumber(x), tonumber(y), tonumber(z)),
            })
        end
    end
    if #loaded > 0 then
        savedPositions = loaded
        print('[Positions] 📂 [' .. USER_ID .. '] Загружено позиций:', #loaded)
        return true
    end
    return false
end

loadPositionsFromFile()
loadSpeedFromFile()

task.spawn(function()
    while task.wait(30) do
        pcall(savePositionsToFile)
        pcall(saveSpeedToFile)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then
        pcall(savePositionsToFile)
        pcall(saveSpeedToFile)
    end
end)

-- ============================================================
-- ⚡ СКОРОСТЬ
-- ============================================================
local function getSpeedFrame()
    local ok, frame = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.SpeedUp.Frame
    end)
    return ok and frame or nil
end

local function getAvailableSpeeds()
    local list = {}
    local frame = getSpeedFrame()
    if not frame then return list end
    for i = 1, 5 do
        local btn = frame:FindFirstChild('Buttonx' .. i)
        if btn and getconnections then
            local ok, conns = pcall(getconnections, btn.Activated)
            if ok and conns and #conns > 0 then table.insert(list, 'x' .. i) end
        end
    end
    return list
end

local function clickSpeed(level)
    local frame = getSpeedFrame()
    if not frame then return false end
    local btn = frame:FindFirstChild('Buttonx' .. tostring(level))
    if not btn then return false end
    for _, c in pairs(getconnections(btn.Activated)) do
        if c.Enabled then c:Fire() return true end
    end
    return false
end

local autoSpeedEnabled = false

local SpeedGroup = Tabs.SpeedUp:AddLeftGroupbox('⚡ Авто-скорость')

local SpeedDropdown = SpeedGroup:AddDropdown('SpeedSelect', {
    Values = {}, Default = 1, Multi = false, Text = 'Скорость',
    Callback = function(Value)
        local lvl = parseLevel(Value)
        if lvl then
            selectedLevel = lvl
            print('[SpeedUp] Выбрано: x' .. lvl)
            pcall(saveSpeedToFile)
        end
    end,
})

SpeedGroup:AddButton({
    Text = '🔄 Обновить список',
    Func = function()
        local list = getAvailableSpeeds()
        if #list == 0 then Library:Notify('❌ Нет кнопок', 3) return end
        SpeedDropdown:SetValues(list)
        if selectedLevel then pcall(function() SpeedDropdown:SetValue('x' .. selectedLevel) end) end
        Library:Notify('✅ ' .. table.concat(list, ', '), 3)
    end,
})

SpeedGroup:AddSlider('SpeedInterval', {
    Text = '⏱ Интервал (сек)', Default = 3, Min = 1, Max = 30, Rounding = 1, Compact = false,
    Callback = function(v) speedInterval = v pcall(saveSpeedToFile) end,
})

SpeedGroup:AddToggle('AutoSpeedToggle', {
    Text = '⚡ Авто-скорость', Default = false,
    Callback = function(Value)
        autoSpeedEnabled = Value
        if Value then
            task.spawn(function()
                local waited = 0
                while autoSpeedEnabled and not selectedLevel and waited < 30 do
                    local val = SpeedDropdown.Value
                    if val and val ~= '' then
                        local lvl = parseLevel(val)
                        if lvl then selectedLevel = lvl end
                    end
                    if not selectedLevel then loadSpeedFromFile() end
                    if not selectedLevel then task.wait(0.5) waited = waited + 0.5 end
                end
                if not selectedLevel then return end
                print('[SpeedUp] ▶ ВКЛ, x' .. selectedLevel)
                while autoSpeedEnabled do
                    clickSpeed(selectedLevel)
                    local elapsed = 0
                    while elapsed < speedInterval and autoSpeedEnabled do
                        task.wait(0.2)
                        elapsed = elapsed + 0.2
                    end
                end
                print('[SpeedUp] ■ ВЫКЛ')
            end)
        end
    end,
})

task.spawn(function()
    task.wait(1)
    local list = getAvailableSpeeds()
    if #list > 0 then
        SpeedDropdown:SetValues(list)
        if selectedLevel then pcall(function() SpeedDropdown:SetValue('x' .. selectedLevel) end) end
    end
end)

-- ============================================================
-- 🎯 ЮНИТЫ
-- ============================================================
local function scanSlots()
    local result = {}
    local ok, frame = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.Towers.Frame
    end)
    if not ok or not frame then return result end
    for i = 1, 6 do
        local slot = frame:FindFirstChild("Slot" .. i)
        if slot then
            local tv = slot:FindFirstChild("TowerValue")
            local name = tv and tv:IsA("StringValue") and tv.Value or nil
            result[i] = {
                index = i,
                slot = slot,
                name = (name and name ~= "" and name) or nil,
                textButton = slot:FindFirstChild("TextButton"),
            }
        end
    end
    return result
end

local function findSlotByName(towerName)
    local slots = scanSlots()
    for i = 1, 6 do
        local d = slots[i]
        if d and d.name == towerName then return d end
    end
    return nil
end

local function getPriceFromSlot(slot)
    if not slot then return nil end
    local p = slot:FindFirstChild("Price")
    if not p then return nil end
    return parseMoney(p.Text or "")
end

local function getUnitManagerFolder()
    local ok, folder = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.UnitManager.Units
    end)
    return ok and folder or nil
end

local function scanUnitManager()
    local result = {}
    local folder = getUnitManagerFolder()
    if not folder then return result end

    for idx, unit in ipairs(folder:GetChildren()) do
        if unit:IsA("GuiObject") then
            local upgradeBtn = unit:FindFirstChild("Upgrade")
            if upgradeBtn and (upgradeBtn:IsA("TextButton") or upgradeBtn:IsA("ImageButton")) then
                local priceLabel = upgradeBtn:FindFirstChild("Price")
                local priceRaw = nil
                if priceLabel and priceLabel:IsA("TextLabel") then priceRaw = priceLabel.Text end

                local price, isMax = nil, false
                if priceRaw then
                    local lower = priceRaw:lower()
                    if lower:find("max") or lower:find("full") or lower:find("макс") then
                        isMax = true
                    else
                        price = parseMoney(priceRaw)
                    end
                end

                local levelLabel = unit:FindFirstChild("Level")
                local levelText = nil
                if levelLabel and levelLabel:IsA("TextLabel") then levelText = levelLabel.Text end
                local levelInfo = parseLevelInfo(levelText)
                if levelInfo and levelInfo.current >= levelInfo.max then isMax = true end

                local unitId = unit:FindFirstChild("UnitID")
                local realName = unit.Name
                if unitId and unitId:IsA("StringValue") then realName = unitId.Value end

                table.insert(result, {
                    name = realName,
                    instance = unit,
                    button = upgradeBtn,
                    price = price,
                    priceRaw = priceRaw,
                    isMax = isMax,
                    levelText = levelText,
                    order = idx,
                })
            end
        end
    end
    return result
end

local function getPlacedTowersInWorld()
    local result = {}
    local ok, towersFolder = pcall(function()
        return workspace:FindFirstChild("Towers")
    end)
    if not ok or not towersFolder then return result end
    for _, obj in ipairs(towersFolder:GetChildren()) do
        local pos = nil
        local name = obj.Name
        if obj:IsA("Model") then
            local part = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then pos = part.Position end
        elseif obj:IsA("BasePart") then
            pos = obj.Position
        end
        if pos then
            table.insert(result, { instance = obj, name = name, position = pos })
        end
    end
    return result
end

local occupiedCheckRadius = 2
local skipOccupiedEnabled = true
local skipExactEnabled = true

local function checkOccupied(pos, expectedName)
    if occupiedCheckRadius <= 0 then return false, nil, false end
    local placed = getPlacedTowersInWorld()
    for _, t in ipairs(placed) do
        if (t.position - pos).Magnitude <= occupiedCheckRadius then
            return true, t.name, (expectedName and t.name == expectedName) or false
        end
    end
    return false, nil, false
end

local runOnePlacePass = nil
local runOneUpgradePass = nil

-- ============================================================
-- UI: Башни в слотах
-- ============================================================
local UnitsInfoGroup = Tabs.Units:AddLeftGroupbox('🗼 Башни в слотах')
local slotLabels = {}
for i = 1, 6 do
    slotLabels[i] = UnitsInfoGroup:AddLabel('Слот ' .. i .. ': —', false)
end

local function updateTowerLabels()
    local slots = scanSlots()
    for i = 1, 6 do
        local d = slots[i]
        if d and d.name then
            local variants = {}
            local seen = {}
            local function add(v)
                if v and v ~= "" and not seen[v] then
                    seen[v] = true
                    table.insert(variants, v)
                end
            end

            add(findUnitIdByName(d.name))
            local owned = getOwnedVariants(d.name)
            for _, v in ipairs(owned) do add(v) end
            add(d.name)

            local varText = #variants > 1 and (" [" .. #variants .. " вар.]") or ""
            if slotLabels[i] then
                pcall(function()
                    slotLabels[i]:SetText('Слот ' .. i .. ': ' .. d.name .. varText)
                end)
            end
        else
            if slotLabels[i] then
                pcall(function()
                    slotLabels[i]:SetText('Слот ' .. i .. ': —')
                end)
            end
        end
    end
end

UnitsInfoGroup:AddButton({ Text = '🔄 Обновить', Func = function() updateTowerLabels() end })

UnitsInfoGroup:AddButton({
    Text = '📊 Показать все варианты всех слотов',
    Func = function()
        local slots = scanSlots()
        print("╔═══════════════════════════════════════════╗")
        print("║   📊 ВСЕ ДОСТУПНЫЕ ВАРИАНТЫ                  ║")
        print("╚═══════════════════════════════════════════╝")
        for i = 1, 6 do
            local d = slots[i]
            if d and d.name then
                print("")
                print("🔷 Слот " .. i .. ": " .. d.name)

                local variants = {}
                local seen = {}
                local function add(v)
                    if v and v ~= "" and not seen[v] then
                        seen[v] = true
                        table.insert(variants, v)
                    end
                end

                add(findUnitIdByName(d.name))
                local owned = getOwnedVariants(d.name)
                for _, v in ipairs(owned) do add(v) end
                add(d.name)
                for _, mod in ipairs(MODIFIERS) do add(d.name .. mod) end

                for j, v in ipairs(variants) do
                    print("   [" .. j .. "] " .. v)
                end
            end
        end
        print("")
        print("═══════════════════════════════════════════")
    end,
})

task.spawn(function()
    while task.wait(1) do pcall(updateTowerLabels) end
end)

-- ============================================================
local checkBalanceEnabled = true
local selectedPosIndex = 1

local UnitsGroup = Tabs.Units:AddLeftGroupbox('🎯 Юнит и позиции')

local UnitDropdown = UnitsGroup:AddDropdown('UnitSelect', {
    Values = {}, Default = 1, Multi = false, Text = 'Юнит для позиции',
    Callback = function(Value)
        if Value then print('[Units] Выбран:', Value) end
    end,
})

local function refreshUnitsList()
    local slots = scanSlots()
    local labels = {}
    for i = 1, 6 do
        local d = slots[i]
        if d and d.name then
            local price = getPriceFromSlot(d.slot)
            table.insert(labels, d.name .. (price and (" | $" .. price) or ""))
        end
    end
    if #labels == 0 then Library:Notify('❌ Слоты не найдены', 3) return end
    UnitDropdown:SetValues(labels)
    Library:Notify('🔄 Юнитов: ' .. #labels, 2)
end

UnitsGroup:AddButton({ Text = '🔄 Обновить список', Func = function() refreshUnitsList() end })

local MoneyLabel = UnitsGroup:AddLabel('💰 Баланс: 0', false)
UnitsGroup:AddToggle('CheckBalanceToggle', {
    Text = '💰 Проверять баланс', Default = true,
    Callback = function(v) checkBalanceEnabled = v end,
})

local PosLabel = UnitsGroup:AddLabel('📊 Позиций: 0', false)

local function getSelectedUnitName()
    local val = UnitDropdown.Value
    if not val or val == '' then return nil end
    return val:match("^(.-)%s*|") or val
end

local function updatePosLabel()
    pcall(function()
        PosLabel:SetText('📊 Позиций: ' .. #savedPositions)
    end)
end

local function printPositionsList()
    print('╔═══════════════════════════════════════════╗')
    print('║   📊 СПИСОК ПОЗИЦИЙ (' .. #savedPositions .. ')')
    print('╚═══════════════════════════════════════════╝')
    if #savedPositions == 0 then
        print('  (пусто)')
    else
        for i, p in ipairs(savedPositions) do
            local occupied, who, isExact = checkOccupied(p.pos, p.name)
            local status = occupied and (isExact and '✅' or '🔴') or '🟢'
            print(string.format('  #%d [%s] %s  @ %.1f, %.1f, %.1f',
                i, p.name, status, p.pos.X, p.pos.Y, p.pos.Z))
        end
    end
    print('═══════════════════════════════════════════')
end

UnitsGroup:AddButton({
    Text = '📌 Set Position',
    Func = function()
        local hrp = getHRP()
        if not hrp then Library:Notify('❌ Игрок не найден', 3) return end
        local unitName = getSelectedUnitName()
        if not unitName then Library:Notify('❌ Выбери юнита', 3) return end
        table.insert(savedPositions, { name = unitName, pos = hrp.Position })
        updatePosLabel()
        savePositionsToFile()
        print(string.format('[Units] 📌 #%d [%s]', #savedPositions, unitName))
        Library:Notify('📌 #' .. #savedPositions .. ' [' .. unitName .. ']', 2)
    end,
})

UnitsGroup:AddButton({
    Text = '❌ Удалить последнюю',
    Func = function()
        if #savedPositions == 0 then return end
        table.remove(savedPositions)
        updatePosLabel()
        savePositionsToFile()
    end,
})

UnitsGroup:AddButton({
    Text = '🗑 Reset ALL',
    Func = function()
        savedPositions = {}
        updatePosLabel()
        savePositionsToFile()
    end,
})

UnitsGroup:AddButton({
    Text = '📋 Список в консоль (F9)',
    Func = function()
        printPositionsList()
        Library:Notify('📋 Список выведен в F9', 2)
    end,
})

-- ============================================================
-- Плейсмент
-- ============================================================
local ActionGroup = Tabs.Units:AddRightGroupbox('⚙️ Плейсмент')

ActionGroup:AddSlider('PosIndexSlider', {
    Text = 'Индекс позиции', Default = 1, Min = 1, Max = 12, Rounding = 0, Compact = false,
    Callback = function(v) selectedPosIndex = v end,
})

_G.__yOffset = -2

ActionGroup:AddSlider('YOffsetSlider', {
    Text = '📉 Смещение Y',
    Default = -2,
    Min = -20, Max = 10, Rounding = 1, Compact = false,
    Tooltip = 'Начни с -2, если не работает — -5, -10',
    Callback = function(v)
        _G.__yOffset = v
        print('[Units] Смещение Y =', v)
    end,
})

_G.__placeDelay = 0.15
ActionGroup:AddSlider('PlaceDelay', {
    Text = '⏱ Задержка', Default = 0.15, Min = 0.05, Max = 2, Rounding = 2, Compact = false,
    Callback = function(v) _G.__placeDelay = v end,
})

ActionGroup:AddSlider('OccupiedRadius', {
    Text = '📏 Радиус (0=выкл)', Default = 2, Min = 0, Max = 20, Rounding = 1, Compact = false,
    Callback = function(v) occupiedCheckRadius = v end,
})

ActionGroup:AddToggle('SkipOccupiedToggle', {
    Text = '⏭ Пропускать занятые', Default = true,
    Callback = function(v) skipOccupiedEnabled = v end,
})

ActionGroup:AddToggle('SkipExactToggle', {
    Text = '⏭ Не дублировать', Default = true,
    Callback = function(v) skipExactEnabled = v end,
})

-- ============================================================
-- 🎯 placeUnitAt
-- ============================================================
local function placeUnitAt(positionData, useCFrame)
    if not loadRemotes() then return false, 'Functions нет' end

    local baseName = positionData.name
    local pos = positionData.pos

    if skipOccupiedEnabled or skipExactEnabled then
        local occupied, who, isExact = checkOccupied(pos, baseName)
        if occupied then
            if isExact and skipExactEnabled then return false, 'уже стоит' end
            if not isExact and skipOccupiedEnabled then return false, 'занято' end
        end
    end

    local slotData = findSlotByName(baseName)
    if not slotData then
        return false, 'слот "' .. baseName .. '" не найден'
    end

    if checkBalanceEnabled then
        local money = getMoney()
        local price = getPriceFromSlot(slotData.slot)
        if price and price > money then
            return false, string.format('нужно %d, у тебя %d', price, money)
        end
    end

    local variants = {}
    local seen = {}

    local function add(v)
        if v and v ~= "" and not seen[v] then
            seen[v] = true
            table.insert(variants, v)
        end
    end

    add(findUnitIdByName(baseName))
    local owned = getOwnedVariants(baseName)
    for _, v in ipairs(owned) do
        add(v)
    end
    add(baseName)
    for _, mod in ipairs(MODIFIERS) do
        add(baseName .. mod)
    end

    table.sort(variants, function(a, b)
        local aHasMod = (a ~= baseName)
        local bHasMod = (b ~= baseName)
        if aHasMod and not bHasMod then return true end
        if not aHasMod and bHasMod then return false end
        return #a < #b
    end)

    print('[Units] 📋 Варианты "' .. baseName .. '": ' .. table.concat(variants, ' | '))

    if slotData.textButton then
        clickButton(slotData.textButton, true)
        task.wait(0.15)
    end

    local yOffset = _G.__yOffset or -2
    local finalPos = Vector3.new(pos.X, pos.Y + yOffset, pos.Z)
    local cf = CFrame.new(finalPos)

    for _, fullUnitId in ipairs(variants) do
        local ok1, ret1 = pcall(function()
            return RequestTower:InvokeServer(
                {[1] = fullUnitId, [2] = baseName},
                false,
                true
            )
        end)

        if ok1 and ret1 ~= false then
            task.wait(0.08)

            local ok2, ret2 = pcall(function()
                return SpawnTower:InvokeServer(
                    baseName,
                    cf,
                    false,
                    fullUnitId
                )
            end)

            if ok2 and ret2 ~= false then
                print('[Units] ✅ ' .. fullUnitId)
                return true, '✅ ' .. fullUnitId
            end
        end
        task.wait(0.1)
    end

    return false, 'все варианты отклонены'
end

ActionGroup:AddButton({
    Text = '▶ Place',
    Func = function()
        if #savedPositions == 0 then Library:Notify('❌ Нет позиций', 3) return end
        local idx = math.min(selectedPosIndex, #savedPositions)
        local p = savedPositions[idx]
        if not p then return end
        local ok, err = placeUnitAt(p, true)
        Library:Notify(ok and ('✅ #' .. idx) or ('❌ ' .. tostring(err)), 3)
        updatePosLabel()
    end,
})

local autoPlaceEnabled = false
local autoPlaceInterval = 5

ActionGroup:AddSlider('AutoPlaceInterval', {
    Text = '🔁 Интервал авто', Default = 5, Min = 1, Max = 30, Rounding = 1, Compact = false,
    Callback = function(v) autoPlaceInterval = v end,
})

runOnePlacePass = function()
    if #savedPositions == 0 then return 0 end
    local placed, failed, skipped = 0, 0, 0

    for i, p in ipairs(savedPositions) do
        if not autoPlaceEnabled then break end

        local ok, err = placeUnitAt(p, true)

        if ok then
            placed = placed + 1
        elseif err and (err:find('уже стоит') or err:find('занято')) then
            skipped = skipped + 1
            print(string.format('[Units] ⏭ #%d [%s]: %s', i, p.name, tostring(err)))
        else
            failed = failed + 1
            print(string.format('[Units] ❌ #%d [%s]: %s', i, p.name, tostring(err)))
        end

        updatePosLabel()
        task.wait(_G.__placeDelay or 0.15)
    end

    print(string.format('[Units] 📊 Плейсмент: ✅%d | ❌%d | ⏭%d', placed, failed, skipped))
    return placed
end

ActionGroup:AddToggle('AutoPlaceToggle', {
    Text = '🔁 Auto Place', Default = false,
    Callback = function(Value)
        autoPlaceEnabled = Value
        if Value then
            print('[Cycle] 🔁 Цикл ВКЛ')
            task.spawn(function()
                while autoPlaceEnabled do
                    runOnePlacePass()

                    if autoPlaceEnabled then
                        local el = 0
                        while el < autoPlaceInterval and autoPlaceEnabled do
                            task.wait(0.3)
                            el = el + 0.3
                        end
                    end
                end
                print('[Cycle] ■ Цикл ВЫКЛ')
            end)
        end
    end,
})

-- ============================================================
-- ⬆️ AUTO UPGRADE
-- ============================================================
local UpgGroup = Tabs.Units:AddRightGroupbox('⬆️ Auto Upgrade')

local upgradeMode         = 'cheapest'
local autoUpgradeEnabled  = false
local upgradeInterval     = 0.3
local upgradeFilterName   = nil
local upgradeMaxPerPass   = 10
local _manualUpgradeRun   = false
local upgradeStats        = { session = 0, total = 0 }

UpgGroup:AddDropdown('UpgradeMode', {
    Values = { '💰 Дешёвое сначала', '💎 Дорогое сначала', '🔢 По порядку' },
    Default = 1, Multi = false, Text = 'Приоритет',
    Tooltip = 'В каком порядке апгрейдить юниты',
    Callback = function(Value)
        if Value:find('Дешёвое') then upgradeMode = 'cheapest'
        elseif Value:find('Дорогое') then upgradeMode = 'expensive'
        else upgradeMode = 'order' end
        print('[Upgrade] Режим:', upgradeMode)
    end,
})

local filterDropdown
filterDropdown = UpgGroup:AddDropdown('UpgradeFilter', {
    Values = { 'Все юниты' },
    Default = 1, Multi = false, Text = 'Фильтр юнита',
    Tooltip = 'Апгрейдить только выбранный тип юнита',
    Callback = function(Value)
        if Value == 'Все юниты' or Value == '' then
            upgradeFilterName = nil
        else
            upgradeFilterName = Value
        end
        print('[Upgrade] Фильтр:', tostring(upgradeFilterName))
    end,
})

UpgGroup:AddButton({
    Text = '🔄 Обновить список юнитов',
    Func = function()
        local units = scanUnitManager()
        local seen = {}
        local names = { 'Все юниты' }
        for _, u in ipairs(units) do
            if u.name and not seen[u.name] then
                seen[u.name] = true
                table.insert(names, u.name)
            end
        end
        table.sort(names, function(a, b)
            if a == 'Все юниты' then return true end
            if b == 'Все юниты' then return false end
            return a < b
        end)
        filterDropdown:SetValues(names)
        Library:Notify('🔄 Юнитов: ' .. (#names - 1), 2)
    end,
})

UpgGroup:AddSlider('UpgradeInterval', {
    Text = '⏱ Задержка между апгрейдами',
    Default = 0.3, Min = 0.05, Max = 3, Rounding = 2, Compact = false,
    Tooltip = 'Пауза после каждого успешного апгрейда',
    Callback = function(v) upgradeInterval = v end,
})

UpgGroup:AddSlider('UpgradeMaxPerPass', {
    Text = '📊 Макс. апгрейдов за проход',
    Default = 10, Min = 1, Max = 100, Rounding = 0,
    Tooltip = 'Сколько юнитов можно апгрейдить за один цикл',
    Callback = function(v) upgradeMaxPerPass = v end,
})

local UpgStatusLabel = UpgGroup:AddLabel('Юнитов: 0 | Апгрейдов: 0', false)

local function updateUpgStatus()
    local arr = scanUnitManager()
    local withPrice, maxed, filtered = 0, 0, 0
    for _, u in ipairs(arr) do
        if not upgradeFilterName or u.name == upgradeFilterName then
            filtered = filtered + 1
            if u.isMax then maxed = maxed + 1
            elseif u.price then withPrice = withPrice + 1 end
        end
    end
    pcall(function()
        UpgStatusLabel:SetText(string.format(
            'Юнитов: %d (фильтр: %d) | Готово: %d | MAX: %d | Апгрейдов: %d',
            #arr, filtered, withPrice, maxed, upgradeStats.session
        ))
    end)
end

runOneUpgradePass = function()
    local units = scanUnitManager()
    if #units == 0 then return 0 end

    if upgradeFilterName then
        local filtered = {}
        for _, u in ipairs(units) do
            if u.name == upgradeFilterName then
                table.insert(filtered, u)
            end
        end
        units = filtered
        if #units == 0 then return 0 end
    end

    if upgradeMode == 'cheapest' then
        table.sort(units, function(a, b)
            return (a.price or math.huge) < (b.price or math.huge)
        end)
    elseif upgradeMode == 'expensive' then
        table.sort(units, function(a, b)
            return (a.price or 0) > (b.price or 0)
        end)
    else
        table.sort(units, function(a, b)
            return (a.order or 0) < (b.order or 0)
        end)
    end

    local upgraded, skipped_money, skipped_max, skipped_click = 0, 0, 0, 0
    local money = getMoney()

    for _, unit in ipairs(units) do
        if not autoUpgradeEnabled and not _manualUpgradeRun then break end
        if upgraded >= upgradeMaxPerPass then break end

        local skip = false

        if not unit.button or not unit.button.Parent then
            skip = true
        end

        if not skip and unit.isMax then
            skipped_max = skipped_max + 1
            skip = true
        end

        if not skip and not unit.price then
            skipped_max = skipped_max + 1
            skip = true
        end

        if not skip then
            money = getMoney()
            if unit.price > money then
                skipped_money = skipped_money + 1
                skip = true
                if upgradeMode == 'cheapest' then
                    break
                end
            end
        end

        if not skip then
            local ok = clickButton(unit.button, true)
            if ok then
                upgraded = upgraded + 1
                upgradeStats.session = upgradeStats.session + 1
                upgradeStats.total = upgradeStats.total + 1
                task.wait(upgradeInterval)
            else
                skipped_click = skipped_click + 1
            end
        end
    end

    if upgraded > 0 or skipped_money > 0 then
        print(string.format('[Upgrade] ✅%d | 💰%d | 💎MAX:%d | ❌%d | Баланс: %d',
            upgraded, skipped_money, skipped_max, skipped_click, money))
    end
    updateUpgStatus()
    return upgraded
end

UpgGroup:AddToggle('AutoUpgradeToggle', {
    Text = '⬆️ Auto Upgrade',
    Default = false,
    Tooltip = 'Автоматически апгрейдит юниты по выбранному приоритету',
    Callback = function(Value)
        autoUpgradeEnabled = Value
        if Value then
            print('[Upgrade] ⬆️ ВКЛ | режим:', upgradeMode, '| фильтр:', tostring(upgradeFilterName))
            task.spawn(function()
                local failStreak = 0
                while autoUpgradeEnabled do
                    local upg = runOneUpgradePass()
                    if upg == 0 then
                        failStreak = failStreak + 1
                        local waitTime = math.min(0.5 + failStreak * 0.5, 5)
                        task.wait(waitTime)
                    else
                        failStreak = 0
                        task.wait(0.1)
                    end
                end
                print('[Upgrade] ■ ВЫКЛ')
            end)
        end
    end,
})

UpgGroup:AddButton({
    Text = '🔄 Сбросить счётчик',
    Func = function()
        upgradeStats.session = 0
        updateUpgStatus()
    end,
})

UpgGroup:AddButton({
    Text = '▶ Тест: 1 проход',
    Func = function()
        _manualUpgradeRun = true
        local upg = runOneUpgradePass()
        _manualUpgradeRun = false
        Library:Notify('⬆️ Апгрейдов: ' .. tostring(upg), 2)
    end,
})

task.spawn(function()
    while task.wait(1) do
        pcall(function() MoneyLabel:SetText('💰 Баланс: ' .. tostring(getMoney())) end)
        pcall(updatePosLabel)
    end
end)

task.spawn(function()
    while task.wait(2) do pcall(updateUpgStatus) end
end)

task.spawn(function()
    task.wait(1)
    refreshUnitsList()
    updatePosLabel()
end)

-- ============================================================
-- 🛡 ANTI-AFK
-- ============================================================
local ANTI_AFK_DELAY = 4.5

local function tryClickAntiMacro(screenGui)
    if not screenGui or not screenGui.Parent then return false end
    for attempt = 1, 20 do
        if not screenGui.Parent then return false end
        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj:IsA("GuiButton") then
                local isHere = false
                if obj:IsA("TextButton") and obj.Text == "I'm here" then isHere = true
                elseif obj.Name == "I'm here" then isHere = true end
                if isHere then
                    pcall(function() obj:Activate() end)
                    if getconnections then
                        pcall(function()
                            for _, c in pairs(getconnections(obj.Activated)) do
                                if c.Enabled then c:Fire() end
                            end
                        end)
                    end
                    print("[AntiAFK] ✅ Нажал 'I'm here'")
                    return true
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function handleAntiMacroWindow(screenGui)
    if not screenGui or not screenGui.Parent then return end
    task.wait(ANTI_AFK_DELAY)
    if not screenGui.Parent then return end
    tryClickAntiMacro(screenGui)
end

local function scanAllScreenGuis()
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("ScreenGui") and (child.Name == "AntiMacroCheck" or child.Name:lower():find("macro")) then
            task.spawn(handleAntiMacroWindow, child)
        end
    end
end

local AntiAFKGroup = Tabs.Utilities:AddLeftGroupbox('🛡 Anti-AFK')
local antiAfkEnabled = false
local antiAfkConns = {}

local function setupAntiAFK()
    for _, c in ipairs(antiAfkConns) do
        pcall(function() c:Disconnect() end)
    end
    antiAfkConns = {}

    if not antiAfkEnabled then return end

    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    scanAllScreenGuis()

    local conn1 = playerGui.ChildAdded:Connect(function(child)
        if not antiAfkEnabled then return end
        if child:IsA("ScreenGui") and (child.Name == "AntiMacroCheck" or child.Name:lower():find("macro")) then
            task.spawn(handleAntiMacroWindow, child)
        end
    end)
    table.insert(antiAfkConns, conn1)

    local existing = playerGui:FindFirstChild("AntiMacroCheck")
    if existing then
        local conn2 = existing.DescendantAdded:Connect(function(desc)
            if not antiAfkEnabled then return end
            if desc:IsA("GuiButton")
               and (desc.Name == "I'm here" or (desc:IsA("TextButton") and desc.Text == "I'm here")) then
                task.spawn(handleAntiMacroWindow, existing)
            end
        end)
        table.insert(antiAfkConns, conn2)
    end

    task.spawn(function()
        while antiAfkEnabled do
            task.wait(5)
            scanAllScreenGuis()
        end
    end)
end

AntiAFKGroup:AddToggle('AntiAFKToggle', {
    Text = '🛡️ Anti-AFK',
    Default = true,
    Callback = function(Value)
        antiAfkEnabled = Value
        if Value then
            print("[AntiAFK] ▶ ВКЛ")
            setupAntiAFK()
        else
            print("[AntiAFK] ■ ВЫКЛ")
            for _, c in ipairs(antiAfkConns) do
                pcall(function() c:Disconnect() end)
            end
            antiAfkConns = {}
        end
    end,
})

AntiAFKGroup:AddSlider('AntiAFKDelay', {
    Text = '⏱ Задержка (сек)',
    Default = 4.5,
    Min = 0, Max = 15, Rounding = 1, Compact = false,
    Callback = function(v) ANTI_AFK_DELAY = v end,
})

AntiAFKGroup:AddButton({
    Text = '🔍 Проверить сейчас',
    Func = function()
        scanAllScreenGuis()
        Library:Notify('🔍 Скан запущен', 2)
    end,
})

task.spawn(function()
    task.wait(1)
    antiAfkEnabled = true
    print("[AntiAFK] ▶ Автозапуск (default=true)")
    setupAntiAFK()
end)

-- ============================================================
-- 🔁 AUTO REPLAY
-- ============================================================
local AutoReplayGroup = Tabs.Utilities:AddLeftGroupbox('🔁 Auto Replay')
local autoReplayEnabled = false
local autoReplayConns = {}
local autoReplayDelay = 1.5

local function getEndScreen()
    local ok, es = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.EndScreen
    end)
    return ok and es or nil
end

local function tryClickReplay(reason)
    if not autoReplayEnabled then return false end

    local es = getEndScreen()
    if not es then return false end
    if not es.Visible then return false end

    local rp = es:FindFirstChild("Replay")
    if not rp then return false end
    if not rp:IsA("GuiObject") then return false end
    if not rp.Visible then return false end
    if rp.AbsoluteSize.X <= 0 or rp.AbsoluteSize.Y <= 0 then return false end

    local fired = clickButton(rp, true)
    print(string.format('[AutoReplay] 🖱 Клик по Replay (%s): %s', tostring(reason), fired and 'OK' or 'fail'))
    return fired
end

local function watchEndScreen(es)
    if not es then return end

    local existing = es:FindFirstChild("Replay")
    if existing then
        task.spawn(function()
            task.wait(autoReplayDelay)
            tryClickReplay('replay existing')
        end)

        local connV = existing:GetPropertyChangedSignal("Visible"):Connect(function()
            if not autoReplayEnabled then return end
            if existing.Visible then
                task.spawn(function()
                    task.wait(autoReplayDelay)
                    tryClickReplay('replay became visible')
                end)
            end
        end)
        table.insert(autoReplayConns, connV)
    end

    local connR = es.ChildAdded:Connect(function(child)
        if not autoReplayEnabled then return end
        if child.Name == "Replay" then
            print('[AutoReplay] 📺 Появился Replay')
            if child:IsA("GuiObject") then
                local connV2 = child:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not autoReplayEnabled then return end
                    if child.Visible then
                        task.spawn(function()
                            task.wait(autoReplayDelay)
                            tryClickReplay('replay appeared + visible')
                        end)
                    end
                end)
                table.insert(autoReplayConns, connV2)
            end
            task.spawn(function()
                task.wait(autoReplayDelay)
                tryClickReplay('replay appeared')
            end)
        end
    end)
    table.insert(autoReplayConns, connR)
end

local function attachToGameGui(gg)
    if not gg then return end

    local es = gg:FindFirstChild("EndScreen")
    if es then
        watchEndScreen(es)
        task.spawn(function()
            task.wait(autoReplayDelay)
            tryClickReplay('initial scan')
        end)

        local connVis = es:GetPropertyChangedSignal("Visible"):Connect(function()
            if not autoReplayEnabled then return end
            if es.Visible then
                task.spawn(function()
                    task.wait(autoReplayDelay)
                    tryClickReplay('endscreen visible')
                end)
            end
        end)
        table.insert(autoReplayConns, connVis)
    end

    local connES = gg.ChildAdded:Connect(function(child)
        if not autoReplayEnabled then return end
        if child.Name == "EndScreen" then
            print('[AutoReplay] 📺 Появился EndScreen')
            watchEndScreen(child)

            if child:IsA("GuiObject") then
                local connV = child:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not autoReplayEnabled then return end
                    if child.Visible then
                        task.spawn(function()
                            task.wait(autoReplayDelay)
                            tryClickReplay('endscreen appeared + visible')
                        end)
                    end
                end)
                table.insert(autoReplayConns, connV)
            end
        end
    end)
    table.insert(autoReplayConns, connES)
end

local function setupAutoReplay()
    for _, c in ipairs(autoReplayConns) do
        pcall(function() c:Disconnect() end)
    end
    autoReplayConns = {}

    if not autoReplayEnabled then return end

    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    local gameGui = playerGui:FindFirstChild("GameGui")
    if gameGui then
        attachToGameGui(gameGui)
    else
        local connGG = playerGui.ChildAdded:Connect(function(child)
            if not autoReplayEnabled then return end
            if child.Name == "GameGui" then
                connGG:Disconnect()
                attachToGameGui(child)
            end
        end)
        table.insert(autoReplayConns, connGG)
    end

    task.spawn(function()
        while autoReplayEnabled do
            task.wait(2)
            pcall(tryClickReplay, 'periodic')
        end
    end)
end

AutoReplayGroup:AddToggle('AutoReplayToggle', {
    Text = '🔁 Auto Replay',
    Default = false,
    Tooltip = 'Жмёт Replay когда EndScreen.Replay появляется / становится Visible',
    Callback = function(Value)
        autoReplayEnabled = Value
        if Value then
            print('[AutoReplay] ▶ ВКЛ')
            setupAutoReplay()
        else
            print('[AutoReplay] ■ ВЫКЛ')
            for _, c in ipairs(autoReplayConns) do
                pcall(function() c:Disconnect() end)
            end
            autoReplayConns = {}
        end
    end,
})

AutoReplayGroup:AddSlider('AutoReplayDelay', {
    Text = '⏱ Задержка перед кликом (сек)',
    Default = 1.5, Min = 0, Max = 10, Rounding = 1, Compact = false,
    Tooltip = 'Пауза между появлением Replay и кликом',
    Callback = function(v) autoReplayDelay = v end,
})

AutoReplayGroup:AddButton({
    Text = '🔍 Тест: нажать Replay сейчас',
    Func = function()
        local es = getEndScreen()
        if not es then Library:Notify('❌ EndScreen не найден', 3) return end
        if not es.Visible then Library:Notify('❌ EndScreen скрыт', 3) return end
        local rp = es:FindFirstChild("Replay")
        if not rp then Library:Notify('❌ Replay не найден', 3) return end
        local fired = clickButton(rp, true)
        Library:Notify(fired and '🔁 Клик отправлен' or '❌ Клик не сработал', 2)
    end,
})

AutoReplayGroup:AddButton({
    Text = '📊 Диагностика EndScreen',
    Func = function()
        local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then print('[Diag] PlayerGui не найден') return end

        local gameGui = playerGui:FindFirstChild("GameGui")
        print('[Diag] GameGui:', gameGui and '✅' or '❌')

        if gameGui then
            local endScreen = gameGui:FindFirstChild("EndScreen")
            print('[Diag] EndScreen:', endScreen and '✅' or '❌')

            if endScreen then
                print('[Diag] EndScreen.Visible:', endScreen.Visible)
                print('[Diag] EndScreen.ClassName:', endScreen.ClassName)

                local replay = endScreen:FindFirstChild("Replay")
                print('[Diag] Replay:', replay and '✅' or '❌')

                if replay then
                    print('[Diag] Replay.ClassName:', replay.ClassName)
                    print('[Diag] Replay.Visible:', replay.Visible)
                    print('[Diag] Replay.AbsoluteSize:', tostring(replay.AbsoluteSize))
                end

                print('[Diag] Дети EndScreen:')
                for _, c in ipairs(endScreen:GetChildren()) do
                    print('  - ' .. c.Name .. ' [' .. c.ClassName .. '] Visible=' .. tostring(c.Visible))
                end
            end
        end
    end,
})

-- ============================================================
-- 🧬 AUTO MUTATION
-- ============================================================
local AutoMutationGroup = Tabs.Utilities:AddLeftGroupbox('🧬 Auto Mutation')

local autoMutationEnabled = false
local selectedMutator = 'None'
local autoMutationConns = {}
local mutatorDropdown = nil
_G.__autoMutationUsed = false

local function getMutatorVoting()
    local ok, folder = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.SlopMutatorGui.MutatorVoting
    end)
    return ok and folder or nil
end

local function getSlopGui()
    local ok, gui = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.SlopMutatorGui
    end)
    return ok and gui or nil
end

local function scanMutators()
    local list = {}
    local folder = getMutatorVoting()
    if not folder then return list end

    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(list, child.Name)
        end
    end
    table.sort(list)
    return list
end

local function clickMutator()
    local folder = getMutatorVoting()
    if not folder then return false end

    local target = folder:FindFirstChild(selectedMutator)
    if not target then
        print('[AutoMutation] ❌ "' .. selectedMutator .. '" не найден')
        return false
    end

    local buttons = {}
    if target:IsA("TextButton") or target:IsA("ImageButton") then
        table.insert(buttons, target)
    end
    for _, d in ipairs(target:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            table.insert(buttons, d)
        end
    end

    if #buttons == 0 then
        print('[AutoMutation] ⚠ В "' .. selectedMutator .. '" нет кнопок')
        pcall(function() target:Activate() end)
        return false
    end

    print('[AutoMutation] 🖱 Кнопок в "' .. selectedMutator .. '": ' .. #buttons)

    local anyFired = false

    for _, btn in ipairs(buttons) do
        local p = btn.Parent
        local depth = 0
        while p and p ~= game and depth < 10 do
            if p:IsA("GuiObject") and not p.Visible then
                p.Visible = true
            end
            p = p.Parent
            depth = depth + 1
        end

        if getconnections then
            for _, sigName in ipairs({'Activated', 'MouseButton1Click', 'MouseButton1Down', 'MouseButton1Up', 'InputBegan', 'InputEnded'}) do
                local sig = btn[sigName]
                if sig then
                    local ok, conns = pcall(getconnections, sig)
                    if ok and conns then
                        for _, c in pairs(conns) do
                            if c.Enabled then
                                pcall(function() c:Fire() end)
                                anyFired = true
                            end
                        end
                    end
                end
            end
        end

        if firesignal then
            pcall(firesignal, btn.Activated)
            pcall(firesignal, btn.MouseButton1Click)
            pcall(firesignal, btn.MouseButton1Down)
            pcall(firesignal, btn.MouseButton1Up)
            anyFired = true
        end

        pcall(function() btn:Activate() end)

        local VIM = game:GetService("VirtualInputManager")
        if VIM and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            pcall(function() VIM:SendMouseMoveEvent(pos.X, pos.Y, game) end)
            task.wait(0.05)
            pcall(function() VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0) end)
            task.wait(0.03)
            pcall(function() VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0) end)
            anyFired = true
        end
    end

    print('[AutoMutation] ✅ Клик по "' .. selectedMutator .. '"')
    return anyFired
end

local function closeMutatorMenu()
    local slopGui = getSlopGui()
    if not slopGui then return end

    local closeBtn = nil

    for _, d in ipairs(slopGui:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            local nm = d.Name:lower()
            local txt = d:IsA("TextButton") and d.Text:lower() or ''
            if nm:find("close") or nm:find("confirm") or nm:find("submit")
               or nm:find("done") or nm:find("ok")
               or txt:find("confirm") or txt:find("done")
               or txt:find("подтверд") or txt:find("ок") then
                closeBtn = d
                break
            end
        end
    end

    if closeBtn then
        clickButton(closeBtn, true)
        print('[AutoMutation] 🚪 Нажал закрытие меню:', closeBtn:GetFullName())
    else
        pcall(function()
            slopGui.Enabled = false
        end)
        print('[AutoMutation] 🚪 Скрыл SlopMutatorGui (кнопка закрытия не найдена)')
    end
end

local function stopAutoMutation(reason)
    if _G.__autoMutationUsed then return end
    _G.__autoMutationUsed = true
    autoMutationEnabled = false

    for _, c in ipairs(autoMutationConns) do
        pcall(function() c:Disconnect() end)
    end
    autoMutationConns = {}

    pcall(function()
        if Library.Options and Library.Options.AutoMutationToggle then
            Library.Options.AutoMutationToggle:SetValue(false)
        end
    end)

    print('[AutoMutation] 🛑 СТОП (' .. tostring(reason) .. ') — больше не проверяю')
    pcall(function()
        Library:Notify('🛑 Auto Mutation остановлен: ' .. tostring(reason), 3)
    end)
end

local function watchMobs(mobsFolder)
    if not mobsFolder then return end

    if #mobsFolder:GetChildren() > 0 then
        stopAutoMutation("уже есть мобы")
        return
    end

    local conn = mobsFolder.ChildAdded:Connect(function()
        if not autoMutationEnabled or _G.__autoMutationUsed then return end
        stopAutoMutation("появился первый моб")
    end)
    table.insert(autoMutationConns, conn)
end

local function setupAutoMutation()
    for _, c in ipairs(autoMutationConns) do
        pcall(function() c:Disconnect() end)
    end
    autoMutationConns = {}

    if _G.__autoMutationUsed then
        print('[AutoMutation] ⚠ Уже сработал — не запускаю')
        return
    end

    if not autoMutationEnabled then return end

    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    local connGui = playerGui.ChildAdded:Connect(function(child)
        if not autoMutationEnabled or _G.__autoMutationUsed then return end
        if child.Name == "SlopMutatorGui" then
            print('[AutoMutation] 📺 Появился SlopMutatorGui')
            task.wait(0.5)

            local voting = child:FindFirstChild("MutatorVoting")
            if voting then
                local connV = voting.ChildAdded:Connect(function(m)
                    if not autoMutationEnabled or _G.__autoMutationUsed then return end
                    if m.Name == selectedMutator then
                        task.wait(0.3)
                        clickMutator()
                        task.wait(0.5)
                        closeMutatorMenu()
                    end
                end)
                table.insert(autoMutationConns, connV)

                if voting:FindFirstChild(selectedMutator) then
                    task.wait(0.3)
                    clickMutator()
                    task.wait(0.5)
                    closeMutatorMenu()
                end
            end
        end
    end)
    table.insert(autoMutationConns, connGui)

    task.spawn(function()
        while autoMutationEnabled and not _G.__autoMutationUsed do
            task.wait(1.5)
            local folder = getMutatorVoting()
            if folder then
                local target = folder:FindFirstChild(selectedMutator)
                if target and target.Visible and target.AbsoluteSize.X > 0 then
                    clickMutator()
                    task.wait(0.5)
                    closeMutatorMenu()
                end
            end
        end
    end)

    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then
        local connMobs = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Mobs" then
                connMobs:Disconnect()
                if autoMutationEnabled and not _G.__autoMutationUsed then
                    watchMobs(child)
                end
            end
        end)
        table.insert(autoMutationConns, connMobs)
    else
        watchMobs(mobsFolder)
    end
end

mutatorDropdown = AutoMutationGroup:AddDropdown('MutatorSelect', {
    Values = { 'None' },
    Default = 'None',
    Multi = false,
    Text = 'Мутация',
    Tooltip = 'Какую мутацию выбирать автоматически',
    Callback = function(Value)
        selectedMutator = Value or 'None'
        print('[AutoMutation] Выбрано:', selectedMutator)
    end,
})

AutoMutationGroup:AddButton({
    Text = '🔄 Обновить список мутаций',
    Func = function()
        local list = scanMutators()
        if #list == 0 then
            Library:Notify('❌ MutatorVoting не найден. Открой окно выбора мутации.', 3)
            return
        end
        mutatorDropdown:SetValues(list)
        Library:Notify('🔄 Найдено: ' .. table.concat(list, ', '), 3)
        print('[AutoMutation] Доступно:', table.concat(list, ', '))
    end,
})

AutoMutationGroup:AddToggle('AutoMutationToggle', {
    Text = '🧬 Auto Mutation',
    Default = false,
    Tooltip = 'Автоматически жмёт выбранную мутацию при появлении (1 раз за сессию)',
    Callback = function(Value)
        autoMutationEnabled = Value
        if Value then
            if _G.__autoMutationUsed then
                Library:Notify('⚠ Уже сработал — перезапусти скрипт', 3)
                pcall(function()
                    if Library.Options and Library.Options.AutoMutationToggle then
                        Library.Options.AutoMutationToggle:SetValue(false)
                    end
                end)
                return
            end
            print('[AutoMutation] ▶ ВКЛ, цель: ' .. selectedMutator)
            local list = scanMutators()
            if #list > 0 then
                mutatorDropdown:SetValues(list)
            end
            setupAutoMutation()
        else
            print('[AutoMutation] ■ ВЫКЛ')
            for _, c in ipairs(autoMutationConns) do
                pcall(function() c:Disconnect() end)
            end
            autoMutationConns = {}
        end
    end,
})

AutoMutationGroup:AddButton({
    Text = '🔍 Тест: кликнуть сейчас',
    Func = function()
        local ok = clickMutator()
        if ok then
            task.wait(0.5)
            closeMutatorMenu()
            Library:Notify('🧬 Клик по "' .. selectedMutator .. '" + закрытие', 2)
        else
            Library:Notify('❌ Не удалось кликнуть', 3)
        end
    end,
})

AutoMutationGroup:AddButton({
    Text = '📊 Диагностика MutatorVoting',
    Func = function()
        local folder = getMutatorVoting()
        print('========== MutatorVoting ==========')
        if not folder then
            print('❌ Не найден. Открой SlopMutatorGui в игре.')
            return
        end

        print('Visible:', folder.Visible)
        print('Дети:')
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("GuiObject") then
                local btn = nil
                if c:IsA("TextButton") or c:IsA("ImageButton") then
                    btn = c
                else
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("TextButton") or d:IsA("ImageButton") then
                            btn = d
                            break
                        end
                    end
                end
                print(string.format('  %s [%s] Visible=%s Clickable=%s',
                    c.Name, c.ClassName, tostring(c.Visible), btn and '✅' or '❌'))
            end
        end
        print('===================================')
    end,
})

task.spawn(function()
    while task.wait(3) do
        local list = scanMutators()
        if #list > 0 then
            local cur = mutatorDropdown.Values or {}
            if #cur ~= #list then
                mutatorDropdown:SetValues(list)
            end
        end
    end
end)

-- ============================================================
-- 🔄 AUTO-LOAD / AUTO-INJECT (перезагрузка скрипта после телепорта/респавна)
-- ============================================================
local AutoLoadGroup = Tabs.Utilities:AddLeftGroupbox('🔄 Auto-Load Script')

local AUTOLOAD_URL_FILE   = 'AutoVoteMenu/autoload_url.txt'
local AUTOLOAD_STATE_FILE = 'AutoVoteMenu/autoload_state.txt'

-- 🎯 URL по умолчанию (можно поменять в UI)
local DEFAULT_AUTOLOAD_URL = 'https://raw.githubusercontent.com/Zecb/jono222/main/ner/Script.lua'

-- 🎯 Поиск функции queue_on_teleport у разных экзекьюторов
local function getQueueFn()
    if queue_on_teleport       then return queue_on_teleport       end
    if queueonteleport         then return queueonteleport         end
    if syn and syn.queue_on_teleport       then return syn.queue_on_teleport       end
    if fluxus and fluxus.queue_on_teleport then return fluxus.queue_on_teleport     end
    return nil
end

-- 🎯 Собирает loader, который выполнится на новой стороне
local function buildLoader(url)
    return string.format([[
        -- AutoLoad Loader
        task.wait(3)
        repeat task.wait(0.3) until game:IsLoaded()
        local plr = game:GetService("Players").LocalPlayer
        repeat task.wait(0.2) until plr and plr.Character
        task.wait(2)
        local ok, err = pcall(function()
            loadstring(game:HttpGet(%q))()
        end)
        if not ok then warn("[AutoLoad] ❌ Ошибка:", tostring(err)) end
    ]], url)
end

-- 🎯 Читает URL из файла
local function loadSavedURL()
    if not readfile or not isfile then return nil end
    local exists = false
    pcall(function() exists = isfile(AUTOLOAD_URL_FILE) end)
    if not exists then return nil end
    local url = nil
    pcall(function() url = readfile(AUTOLOAD_URL_FILE) end)
    if not url or url == '' then return nil end
    return url:gsub('%s+', '')
end

-- 🎯 Сохраняет URL
local function saveURL(url)
    if not writefile then return false end
    return pcall(function()
        if makefolder then pcall(makefolder, 'AutoVoteMenu') end
        writefile(AUTOLOAD_URL_FILE, url:gsub('%s+', ''))
    end)
end

-- 🎯 Основная функция: поставить скрипт в очередь на следующий телепорт
local function doQueueAutoLoad()
    local queueFn = getQueueFn()
    if not queueFn then
        return false, 'queue_on_teleport недоступен'
    end
    local url = loadSavedURL() or DEFAULT_AUTOLOAD_URL
    if not url then
        return false, 'URL не задан'
    end
    local ok = pcall(function() queueFn(buildLoader(url)) end)
    if ok then
        print('[AutoLoad] ✅ Скрипт поставлен в очередь: ' .. url)
    end
    return ok, nil
end

-- 🎯 UI
local URLInputOpt = AutoLoadGroup:AddInput('AutoLoadURL', {
    Text = '🌐 URL скрипта (raw GitHub и т.п.)',
    Default = DEFAULT_AUTOLOAD_URL,
    Placeholder = 'https://raw.githubusercontent.com/user/repo/main/script.lua',
    Numeric = false,
    Finished = true,
    Callback = function(v)
        if not v or v == '' then return end
        if saveURL(v) then
            print('[AutoLoad] 🌐 URL сохранён:', v)
        end
    end,
})

AutoLoadGroup:AddLabel('📌 URL по умолчанию уже прописан', false)

AutoLoadGroup:AddButton({
    Text = '💾 Сохранить URL',
    Func = function()
        local url = URLInputOpt.Value
        if not url or url == '' then
            Library:Notify('❌ Введи URL', 3)
            return
        end
        if saveURL(url) then
            Library:Notify('💾 URL сохранён', 2)
        else
            Library:Notify('❌ writefile недоступен', 3)
        end
    end,
})

AutoLoadGroup:AddButton({
    Text = '🚀 Заскриптовать сейчас (1 раз)',
    Func = function()
        local ok, err = doQueueAutoLoad()
        if ok then
            Library:Notify('🚀 Поставлено на след. телепорт', 3)
        else
            Library:Notify('❌ ' .. tostring(err), 3)
        end
    end,
})

local autoLoadEnabled = false

AutoLoadGroup:AddToggle('AutoLoadToggle', {
    Text = '🔄 Авто-загрузка скрипта после телепорта',
    Default = false,
    Tooltip = 'Скрипт сам себя перезапустит после респавна/реинжоина/телепорта',
    Callback = function(Value)
        autoLoadEnabled = Value
        if writefile then
            pcall(function()
                if makefolder then pcall(makefolder, 'AutoVoteMenu') end
                writefile(AUTOLOAD_STATE_FILE, Value and '1' or '0')
            end)
        end
        if Value then
            local ok, err = doQueueAutoLoad()
            if not ok then
                Library:Notify('❌ ' .. tostring(err), 3)
                autoLoadEnabled = false
                pcall(function()
                    Library.Options.AutoLoadToggle:SetValue(false)
                end)
            else
                Library:Notify('🔄 Auto-Load ВКЛ', 2)
            end
        end
    end,
})

AutoLoadGroup:AddButton({
    Text = '🔎 Диагностика',
    Func = function()
        print('========== AutoLoad ==========')
        print('queue_on_teleport:', queue_on_teleport and '✅' or '❌')
        print('queueonteleport:', queueonteleport and '✅' or '❌')
        print('syn.queue_on_teleport:',
            (syn and syn.queue_on_teleport) and '✅' or '❌')
        print('fluxus.queue_on_teleport:',
            (fluxus and fluxus.queue_on_teleport) and '✅' or '❌')
        print('readfile:', readfile and '✅' or '❌')
        print('writefile:', writefile and '✅' or '❌')
        print('URL:', loadSavedURL() or ('(по умолчанию) ' .. DEFAULT_AUTOLOAD_URL))
        print('Enabled:', tostring(autoLoadEnabled))
        print('==============================')
    end,
})

-- 🎯 Восстановление URL и состояния при загрузке
task.spawn(function()
    task.wait(1)
    local url = loadSavedURL()
    if url then
        pcall(function() URLInputOpt:SetValue(url) end)
    else
        -- сохраняем дефолт при первом запуске
        pcall(saveURL, DEFAULT_AUTOLOAD_URL)
    end
    if readfile and isfile then
        local exists = false
        pcall(function() exists = isfile(AUTOLOAD_STATE_FILE) end)
        if exists then
            local st = nil
            pcall(function() st = readfile(AUTOLOAD_STATE_FILE) end)
            if st == '1' then
                task.wait(2)
                pcall(function()
                    Library.Options.AutoLoadToggle:SetValue(true)
                end)
            end
        end
    end
end)

-- 🎯 Ловим момент, когда телепорт стартует, и перескриптовываем
pcall(function()
    local lp = game:GetService("Players").LocalPlayer
    if lp.OnTeleport then
        lp.OnTeleport:Connect(function(state)
            if not autoLoadEnabled then return end
            if state == Enum.TeleportState.Started
            or state == Enum.TeleportState.InProgress then
                doQueueAutoLoad()
            end
        end)
        print('[AutoLoad] 🎯 OnTeleport-хук установлен')
    end
end)

-- ============================================================
-- ⌨ KEYBIND МЕНЮ
-- ============================================================
local UserInputService = game:GetService("UserInputService")

local keybindEnabled = false
local keybindKey = Enum.KeyCode.RightShift
local keybindConn = nil
local mainGuiRef = nil
local lastToggle = 0
local DEBOUNCE = 0.35

local function findScriptGui()
    if mainGuiRef and mainGuiRef.Parent then return mainGuiRef end

    if Library then
        for _, k in ipairs({'ScreenGui','Gui','MainGui','Main','Root','UIRoot','UI'}) do
            local v = Library[k]
            if typeof(v) == 'Instance' and v:IsA('ScreenGui') then
                mainGuiRef = v
                return v
            end
        end
    end

    local containers = {}
    pcall(function()
        local hui = gethui()
        if hui then table.insert(containers, hui) end
    end)
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    pcall(function()
        local plr = game:GetService("Players").LocalPlayer
        local pg = plr and plr:FindFirstChild("PlayerGui")
        if pg then table.insert(containers, pg) end
    end)

    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "SlopMutatorGui" then
                if child:FindFirstChild("Main")
                    or child:FindFirstChild("Root")
                    or child:FindFirstChild("MainFrame")
                    or child:FindFirstChild("Window")
                    or child:FindFirstChild("MainHolder") then
                    mainGuiRef = child
                    return child
                end
            end
        end
    end
    return nil
end

local function setMenuVisible(state)
    local gui = mainGuiRef
    if not (gui and gui.Parent) then gui = findScriptGui() end
    if not gui then return false end
    pcall(function() gui.Enabled = state end)
    return true
end

local function toggleMenu()
    local now = tick()
    if now - lastToggle < DEBOUNCE then return end
    lastToggle = now
    local gui = mainGuiRef
    if not (gui and gui.Parent) then gui = findScriptGui() end
    if not gui then
        pcall(function() Library:Notify('❌ GUI меню не найден', 2) end)
        return
    end
    pcall(function() gui.Enabled = not gui.Enabled end)
    pcall(function()
        Library:Notify(gui.Enabled and '📖 Меню открыто' or '📕 Меню скрыто', 1)
    end)
end

local function rebuildKeybind()
    if keybindConn then
        pcall(function() keybindConn:Disconnect() end)
        keybindConn = nil
    end
    if not keybindEnabled then return end
    keybindConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == keybindKey then
            task.spawn(toggleMenu)
        end
    end)
end

task.spawn(function()
    task.wait(1)
    pcall(findScriptGui)
end)

local KeybindGroup = Tabs.Utilities:AddLeftGroupbox('⌨ Бинд меню')

KeybindGroup:AddToggle('KeybindToggle', {
    Text = '⌨ Вкл. бинд показа/скрытия меню',
    Default = false,
    Tooltip = 'Нажми выбранную клавишу — меню скроется/появится',
    Callback = function(Value)
        keybindEnabled = Value
        rebuildKeybind()
    end,
})

KeybindGroup:AddDropdown('KeybindKey', {
    Values = {
        'RightShift','LeftShift','RightControl','LeftControl',
        'RightAlt','LeftAlt','Tab','CapsLock','Backquote',
        'F1','F2','F3','F4','F5','F6','F7','F8','F9','F10',
        'Insert','Home','End','PageUp','PageDown','Delete',
        'P','O','K','L','M','N','B','V','H','J','U','Y',
    },
    Default = 'RightShift',
    Multi = false,
    Text = 'Клавиша бинда',
    Tooltip = 'Какая клавиша будет открывать/закрывать меню',
    Callback = function(Value)
        local ok = pcall(function() keybindKey = Enum.KeyCode[Value] end)
        if ok then
            rebuildKeybind()
            pcall(function() Library:Notify('⌨ Бинд: ' .. Value, 1) end)
        end
    end,
})

KeybindGroup:AddButton({
    Text = '📖 Показать меню',
    Func = function()
        if setMenuVisible(true) then
            pcall(function() Library:Notify('📖 Меню открыто', 1) end)
        end
    end,
})

KeybindGroup:AddButton({
    Text = '📕 Скрыть меню',
    Func = function()
        if setMenuVisible(false) then
            pcall(function() Library:Notify('📕 Меню скрыто. Верни: ' .. keybindKey.Name, 2) end)
        end
    end,
})

KeybindGroup:AddButton({
    Text = '🔎 Найти GUI меню',
    Func = function()
        local gui = findScriptGui()
        if gui then
            pcall(function() Library:Notify('✅ GUI: ' .. gui:GetFullName(), 3) end)
            print('[Keybind] Найден GUI:', gui:GetFullName())
        else
            pcall(function() Library:Notify('❌ GUI не найден, смотри F9', 3) end)
            local hui = (gethui and gethui()) or game:GetService("CoreGui")
            for _, c in ipairs(hui:GetChildren()) do
                if c:IsA("ScreenGui") then
                    print('  ScreenGui:', c.Name, '| детей:', #c:GetChildren())
                end
            end
        end
    end,
})

-- ============================================================
-- ⚙ НАСТРОЙКИ
-- ============================================================
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

if makefolder then
    pcall(makefolder, 'AutoVoteMenu')
    pcall(makefolder, 'AutoVoteMenu/accounts')
    pcall(makefolder, ACC_FOLDER)
end

ThemeManager:SetFolder(ACC_FOLDER)
SaveManager:SetFolder(ACC_FOLDER)

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ============================================================
-- 🎯 МЕНЕДЖЕР КОНФИГОВ АККАУНТА (UI)
-- ============================================================
local ConfigGroup = Tabs.Settings:AddLeftGroupbox('👤 Аккаунт')

ConfigGroup:AddLabel('👤 ' .. LocalPlayer.Name, false)
ConfigGroup:AddLabel('🆔 UserId: ' .. USER_ID, false)
ConfigGroup:AddLabel('📁 Файлы: ' .. USER_ID .. '_*.json', false)

ConfigGroup:AddButton({
    Text = '💾 Сохранить конфиг аккаунта',
    Func = function()
        saveAccountInfo()
        savePositionsToFile()
        saveSpeedToFile()
        Library:Notify('💾 Сохранено для ' .. LocalPlayer.Name, 3)
        print('[Configs] 💾 Сохранено:', LocalPlayer.Name, '(' .. USER_ID .. ')')
    end,
})

ConfigGroup:AddButton({
    Text = '📂 Загрузить конфиг аккаунта',
    Func = function()
        loadPositionsFromFile()
        loadSpeedFromFile()
        pcall(updatePosLabel)
        Library:Notify('📂 Загружено для ' .. LocalPlayer.Name, 3)
    end,
})

ConfigGroup:AddButton({
    Text = '📋 Список всех конфигов аккаунтов',
    Func = function()
        print('========== КОНФИГИ АККАУНТОВ ==========')
        if not listfiles or not isfolder then
            print('❌ listfiles/isfolder недоступны')
            return
        end

        local exists = false
        pcall(function() exists = isfolder(CONFIGS_FOLDER) end)
        if not exists then
            print('Папка не найдена:', CONFIGS_FOLDER)
            return
        end

        local files = nil
        pcall(function() files = listfiles(CONFIGS_FOLDER) end)
        if not files then return end

        local accounts = {}
        for _, file in ipairs(files) do
            local uid = file:match('(%d+)_account%.txt$')
            if uid then
                local content = nil
                pcall(function() content = readfile(file) end)
                local name = content and content:match('Name:%s*([^\n]+)') or '?'
                table.insert(accounts, { uid = uid, name = name, file = file })
            end
        end

        print('Найдено аккаунтов:', #accounts)
        for _, a in ipairs(accounts) do
            local marker = (a.uid == USER_ID) and ' ← ТЫ' or ''
            print(string.format('  %s (%s)%s', a.name, a.uid, marker))
        end
        print('=======================================')
    end,
})

-- ============================================================
-- ФИНАЛЬНАЯ ПРОВЕРКА СКОРОСТИ ИЗ КОНФИГА
-- ============================================================
task.spawn(function()
    task.wait(2)
    local val = SpeedDropdown.Value
    if val and val ~= '' then
        local lvl = parseLevel(val)
        if lvl then
            selectedLevel = lvl
            print('[SpeedUp] 🔄 Из конфига: x' .. lvl)
        end
    else
        if loadSpeedFromFile() then
            print('[SpeedUp] 🔄 Из файла: x' .. tostring(selectedLevel))
        end
    end
end)

task.spawn(function()
    local lastLevel, lastInterval = selectedLevel, speedInterval
    while task.wait(2) do
        if selectedLevel ~= lastLevel or speedInterval ~= lastInterval then
            lastLevel = selectedLevel
            lastInterval = speedInterval
            pcall(saveSpeedToFile)
        end
    end
end)

task.spawn(function()
    local lastCount = #savedPositions
    while task.wait(5) do
        if #savedPositions ~= lastCount then
            lastCount = #savedPositions
            pcall(savePositionsToFile)
        end
    end
end)

Library.ToggleKeybind = Enum.KeyCode.RightShift

print('[AutoVote+SpeedUp+Units+AutoUpgrade+AntiAFK+AutoReplay+AutoMutation+Keybind+AccountConfigs+AutoLoad] Загружено ✅')

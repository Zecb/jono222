-- ============================================================
-- ════════════════════════════════════════════════════════════
--   SLOP TOWER DEFENSE — FULL AUTO SCRIPT
-- ════════════════════════════════════════════════════════════
--
--   📋 ФУНКЦИИ:
--     🗳 Auto Vote (карты + сложности)
--     ⚡ Auto Speed (фикс + волновая)
--     🎯 Units Placement (с проверкой занятости)
--     ⬆️ Auto Upgrade (правила + приоритет)
--     🛡 Anti-AFK
--     🔁 Auto Replay
--     🧬 Auto Mutation
--     💾 Account Configs (по UserId)
--     🔄 Auto-Load / Auto-Inject
--     🛡 Anti-Double-Inject
--     ⌨  Menu Keybind
--
--   📅 Версия: расширенная (восстановленная)
-- ════════════════════════════════════════════════════════════
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 🛡 ЗАЩИТА ОТ ПОВТОРНОГО ИНЖЕКТА (Anti-Double-Inject)
-- ════════════════════════════════════════════════════════════
if _G.__SLOP_TD_LOADED then
    warn('[SlopTD] ⚠ Скрипт уже активен — пропускаю повторный инжект.')
    warn('[SlopTD] 💡 Для перезапуска: перезайди в игру.')
    return
end
_G.__SLOP_TD_LOADED = true

-- ════════════════════════════════════════════════════════════
-- 📚 ЗАГРУЗКА БИБЛИОТЕКИ
-- ════════════════════════════════════════════════════════════
local repo = 'https://raw.githubusercontent.com/Progoonerfrfr/LinoriaLib/main/'

local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'Slop Tower Defense — Auto',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

-- ════════════════════════════════════════════════════════════
-- 📑 ВКЛАДКИ
-- ════════════════════════════════════════════════════════════
local Tabs = {
    Vote      = Window:AddTab('Голосование'),
    SpeedUp   = Window:AddTab('Скорость'),
    Units     = Window:AddTab('Юниты'),
    Utilities = Window:AddTab('Утилиты'),
    Settings  = Window:AddTab('Настройки'),
}

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🧰 УТИЛИТЫ И ХЕЛПЕРЫ
-- ════════════════════════════════════════════════════════════
-- ============================================================

-- Список модификаторов юнитов (для парсинга имён вида "Ice Void")
local MODIFIERS = {
    " Shiny", " Void", " Gold", " Rainbow", " Diamond",
    " Crystal", " Galaxy", " Divine", " Cosmic",
}

-- Убирает модификатор из имени юнита
-- "Ice Void" -> "Ice"
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

-- Парсит уровень из строки типа "x3"
local function parseLevel(str)
    if type(str) ~= 'string' then return nil end
    local num = str:match('%d+')
    if num then return tonumber(num) end
    return nil
end

-- Парсит "5/10" -> {current=5, max=10}
local function parseLevelInfo(text)
    if type(text) ~= 'string' then return nil end
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    if current and max then
        return { current = tonumber(current), max = tonumber(max) }
    end
    return nil
end

-- Универсальный кликер кнопок (3 способа)
local function clickButton(btn, forceVisible)
    if not btn or not btn.Parent then return false end

    -- Принудительно делаем видимым (для скрытых GUI)
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

    -- Способ 1: через getconnections
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

    -- Способ 2: через firesignal
    if not fired and firesignal then
        pcall(firesignal, btn.Activated)
        pcall(firesignal, btn.MouseButton1Click)
        fired = true
    end

    -- Способ 3: через :Activate()
    pcall(function() btn:Activate() end)

    return fired
end

-- Получить HumanoidRootPart игрока
local function getHRP()
    local char = game:GetService("Players").LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   💰 ПАРСЕР ЧИСЕЛ (K/M/B/T и т.д.)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local SUFFIXES = {
    K=1e3, M=1e6, B=1e9, T=1e12, Q=1e15, QA=1e15, QI=1e18,
    SX=1e21, SP=1e24, OC=1e27, NO=1e30, DC=1e33,
}

-- "1.5K" -> 1500, "2M" -> 2000000
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

-- Получить текущий баланс
local function getMoney()
    local ok, money = pcall(function()
        return game:GetService("Players").LocalPlayer.leaderstats.Money
    end)
    if not ok or not money then return 0 end
    return parseMoney(tostring(money.Value)) or 0
end

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 ЛИМИТЫ БАШЕН (TowersPlacementsMax)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local RS        = game:GetService("ReplicatedStorage")
local Modules   = RS:WaitForChild("Modules", 10)
local Functions = RS:WaitForChild("Functions", 10)

local TOWER_LIMITS = {}

local function loadTowerLimits()
    if not Modules then
        print('[Limits] ❌ Модуль Modules не найден')
        return false
    end
    local limitModule = Modules:FindFirstChild("TowersPlacementsMax")
    if not limitModule then
        print('[Limits] ⚠ TowersPlacementsMax не найден')
        return false
    end
    local ok, data = pcall(require, limitModule)
    if ok and type(data) == "table" then
        TOWER_LIMITS = data
        local count = 0
        for _ in pairs(data) do count = count + 1 end
        print('[Limits] 📋 Загружено лимитов:', count)
        return true
    end
    print('[Limits] ❌ Не удалось загрузить лимиты')
    return false
end
loadTowerLimits()

-- Получить лимит для конкретного юнита
local function getLimitForUnit(displayName)
    local base = stripModifier(displayName)
    return TOWER_LIMITS[base] or TOWER_LIMITS[displayName] or 1
end

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 REMOTES (RequestTower, SpawnTower)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local RequestTower, SpawnTower, GetPlayerPlacement

local function loadRemotes()
    -- ⚡ Уже найдены — повторно искать незачем. loadRemotes() зовётся
    -- на КАЖДУЮ попытку постановки, а 3 × FindFirstChild каждый раз
    -- — чистые накладные расходы.
    if RequestTower and SpawnTower then return true end

    if not Functions then
        print('[Remotes] ❌ Functions не найден')
        return false
    end
    RequestTower       = Functions:FindFirstChild("RequestTower")
    SpawnTower         = Functions:FindFirstChild("SpawnTower")
    GetPlayerPlacement = Functions:FindFirstChild("GetPlayerPlacement")

    if RequestTower and SpawnTower then
        print('[Remotes] ✅ RequestTower + SpawnTower загружены')
        return true
    end
    print('[Remotes] ⚠ Не все remotes найдены')
    return false
end
loadRemotes()

-- Forward-declaration: findUnitIdByName ниже вызывает buildUnitIdMap,
-- а сам buildUnitIdMap определён сильно ниже (в секции лейблов слотов).
-- Без этого Luau посчитал бы его глобалом — и каждый вызов был бы nil.
local buildUnitIdMap

-- Найти UnitID по имени — через кешированную карту (buildUnitIdMap).
-- Раньше здесь был полный обход UnitManager (100+ юнитов × 2
-- FindFirstChild) НА КАЖДУЮ попытку постановки.
local function findUnitIdByName(baseName)
    local ok, id = pcall(function()
        return buildUnitIdMap()[baseName]
    end)
    if not ok then return nil end
    return id
end

-- ============================================================
-- 🗃 ОБЩИЙ КЕШ СКАНИРОВАНИЙ
-- ============================================================
-- Лежит в _G, а не в local: главный чанк скрипта упирается в лимит
-- Luau в 200 локальных переменных, и каждый local стоит один регистр.
-- Два кеша сложены в одну таблицу — 0 локалей вместо 6.
_G.SLOP_SCAN_CACHE = _G.SLOP_SCAN_CACHE or {
    teNames = nil, teTime = 0, TE_TTL = 2.0,   -- RS.Game.TowersExists
    idMap   = nil, idTime = 0, ID_TTL = 1.5,   -- UnitManager → UnitName→UnitID
}

-- Один обход RS.Game.TowersExists → список имён (с кешем на 2 сек).
-- force=true — игнорировать кеш (нужно после покупки/прокачки юнита).
local function getTowersExistsNames(force)
    local S  = _G.SLOP_SCAN_CACHE
    local now = tick()
    if not force and S.teNames and (now - S.teTime) < S.TE_TTL then
        return S.teNames
    end

    local names = {}
    local ok, gameFolder = pcall(function()
        return RS:FindFirstChild("Game")
    end)
    if ok and gameFolder then
        local towersExists = gameFolder:FindFirstChild("TowersExists")
        if towersExists then
            for _, child in ipairs(towersExists:GetChildren()) do
                names[#names + 1] = child.Name
            end
        end
    end

    S.teNames = names
    S.teTime  = now
    return names
end

-- Все owned юниты, ВКЛЮЧАЯ непоставленных.
-- RS.Game.TowersExists хранит и базовые имена ("Alien Toilets"),
-- и варианты с модификаторами ("Alien Toilets Shiny").
-- Здесь они схлопываются до базовых имён — как показываются в слотах.
local function getAllOwnedUnitNames()
    local result, seen = {}, {}

    for _, name in ipairs(getTowersExistsNames()) do
        local base = stripModifier(name)
        if base and base ~= '' and not seen[base] then
            seen[base] = true
            result[#result + 1] = base
        end
    end

    table.sort(result)
    return result
end

-- Получить все имеющиеся варианты юнита (с модификаторами)
-- namesCache — необязательный заранее собранный список имён (из getTowersExistsNames)
local function getOwnedVariants(baseName, namesCache)
    local result = {}
    local names = namesCache or getTowersExistsNames()

    for _, name in ipairs(names) do
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
-- ════════════════════════════════════════════════════════════
--   🗳 ГОЛОСОВАНИЕ ЗА КАРТЫ
-- ════════════════════════════════════════════════════════════
-- ============================================================

-- Получить все кнопки голосования
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

-- 🔍 Поиск
local SearchInputOpt = VoteGroup:AddInput('SearchInput', {
    Text = '🔍 Поиск карты',
    Default = '',
    Placeholder = 'raid, endless...',
    Numeric = false,
    Finished = false,
    Tooltip = 'Введи часть названия карты для фильтра',
    Callback = function(Value)
        searchQuery = string.lower(Value or '')
        task.spawn(function()
            task.wait(0.05)
            if _G.__refreshVoteList then _G.__refreshVoteList(true) end
        end)
    end,
})

-- 🎯 Выбор карты
local TargetDropdown = VoteGroup:AddDropdown('VoteTarget', {
    Values = {},
    Default = 1,
    Multi = false,
    Text = 'Карта',
    Tooltip = 'Какую карту голосовать',
    Callback = function(Value)
        selectedKey = Value
        if Value then print('[AutoVote] 🎯 Выбрано:', Value) end
    end,
})

-- Обновление списка карт
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

    if not silent then
        Library:Notify('🔄 Найдено карт: ' .. #filteredKeys, 2)
        print('[AutoVote] 🔄 Обновлено, найдено:', #filteredKeys)
    end

    if selectedKey and not allButtons[selectedKey] then
        selectedKey = nil
    end
end

_G.__refreshVoteList = refreshList

-- 🔄 Обновить
VoteGroup:AddButton({
    Text = '🔄 Обновить',
    Tooltip = 'Обновить список доступных карт',
    Func = function()
        refreshList(false)
    end,
})

-- ❌ Очистить поиск
VoteGroup:AddButton({
    Text = '❌ Очистить поиск',
    Tooltip = 'Сбросить фильтр поиска',
    Func = function()
        searchQuery = ''
        pcall(function() SearchInputOpt:SetValue('') end)
        refreshList(false)
    end,
})

-- 🎯 Авто-войт
local autoVoteEnabled = false

VoteGroup:AddToggle('AutoVoteToggle', {
    Text = '🎯 Авто войт карты',
    Default = false,
    Tooltip = 'Автоматически голосует за выбранную карту',
    Callback = function(Value)
        autoVoteEnabled = Value
        if Value then
            print('[AutoVote] ▶ ВКЛ')
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
                            print('[AutoVote] ✅ Проголосовал:', selectedKey)
                        end
                    end
                    task.wait(1)
                end
                print('[AutoVote] ■ ВЫКЛ')
            end)
        end
    end,
})

-- 🔄 Авто-обновление списка
local AutoRefreshToggle = VoteGroup:AddToggle('AutoRefreshToggle', {
    Text = 'Авто-обновление',
    Default = false,
    Tooltip = 'Обновляет список карт каждые 5 сек (если тормозит — не включай)',
})
refreshList(true)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 ГОЛОСОВАНИЕ ЗА СЛОЖНОСТИ
-- ════════════════════════════════════════════════════════════
-- ============================================================

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

-- 🔍 Поиск сложности
local CompSearchOpt = CompGroup:AddInput('CompSearchInput', {
    Text = '🔍 Поиск сложности',
    Default = '',
    Placeholder = 'nightmare...',
    Numeric = false,
    Finished = false,
    Tooltip = 'Фильтр по названию сложности',
    Callback = function(Value)
        compSearch = string.lower(Value or '')
        task.spawn(function()
            task.wait(0.05)
            if _G.__refreshCompList then _G.__refreshCompList(true) end
        end)
    end,
})

-- 🎯 Выбор сложности
local CompDropdown = CompGroup:AddDropdown('CompTarget', {
    Values = {},
    Default = 1,
    Multi = false,
    Text = 'Сложность',
    Tooltip = 'Какую сложность голосовать',
    Callback = function(Value)
        selectedComp = Value
        if Value then print('[Complication] 🎯 Выбрано:', Value) end
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
    if not silent then
        Library:Notify('🔄 Сложностей: ' .. #compKeys, 2)
        print('[Complication] 🔄 Обновлено, найдено:', #compKeys)
    end
end

_G.__refreshCompList = refreshCompList

CompGroup:AddButton({
    Text = '🔄 Обновить',
    Tooltip = 'Обновить список сложностей',
    Func = function() refreshCompList(false) end,
})

-- 🎯 Авто-войт сложности
local autoCompEnabled = false

CompGroup:AddToggle('AutoCompToggle', {
    Text = '🎯 Авто голос сложности',
    Default = false,
    Tooltip = 'Автоматически голосует за выбранную сложность',
    Callback = function(Value)
        autoCompEnabled = Value
        if Value then
            print('[Complication] ▶ ВКЛ')
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
                            print('[Complication] ✅ Проголосовал:', selectedComp)
                        end
                    end
                    task.wait(0.8)
                end
                print('[Complication] ■ ВЫКЛ')
            end)
        end
    end,
})

-- ⚠ Цикл обновления списка сложностей УБРАН (был 1 сек → лаги).
--   Обновление теперь только вручную кнопкой «🔄 Обновить».
refreshCompList(true)

-- ⏸ КОНЕЦ ЧАСТИ 1/4
-- ➡️ ПРОДОЛЖЕНИЕ В ЧАСТИ 2/4
-- ════════════════════════════════════════════════════════════
-- ⏸ ПРОДОЛЖЕНИЕ ЧАСТИ 2/4
-- ============================================================

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   💾 СОХРАНЕНИЕ (по аккаунту / UserId)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local USER_ID     = tostring(LocalPlayer.UserId)

-- Папки
local BASE_FOLDER     = 'SlopTDMenu'
local CONFIGS_FOLDER  = 'SlopTDMenu/configs'
local ACCOUNTS_FOLDER = 'SlopTDMenu/accounts'

-- Файлы конкретного аккаунта
-- ⚠ PRIORITY_FILE и UNIT_RULES_FILE удалены вместе со старой системой
--   апгрейда (правила по юнитам). Теперь приоритет лежит в
--   PRIORITY_UNITS_FILE — см. секцию AUTO UPGRADE.
local POSITIONS_FILE  = CONFIGS_FOLDER .. '/' .. USER_ID .. '_positions.json'
local SPEED_FILE      = CONFIGS_FOLDER .. '/' .. USER_ID .. '_speed.json'
local WAVE_SPEED_FILE = CONFIGS_FOLDER .. '/' .. USER_ID .. '_wavespeed.json'
local ACCOUNT_FILE    = CONFIGS_FOLDER .. '/' .. USER_ID .. '_account.txt'
local ACC_FOLDER      = ACCOUNTS_FOLDER .. '/' .. USER_ID

-- Переменные состояния
local savedPositions = {}
local selectedLevel  = nil
local speedInterval  = 3

-- Создаём папки
local function ensureFolders()
    if makefolder and type(makefolder) == "function" then
        pcall(makefolder, BASE_FOLDER)
        pcall(makefolder, CONFIGS_FOLDER)
        pcall(makefolder, ACCOUNTS_FOLDER)
        pcall(makefolder, ACC_FOLDER)
    end
end
ensureFolders()

print('[SlopTD] 📁 Аккаунт:', LocalPlayer.Name, '| UserId:', USER_ID)

-- ──────── ИНФО АККАУНТА ────────
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

-- ──────── СКОРОСТЬ ────────
local function saveSpeedToFile()
    if not writefile then return false end
    local json = string.format(
        '{\n "level": %d,\n "interval": %.2f\n}',
        selectedLevel or 0, speedInterval or 3
    )
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

    local lvl      = content:match('"level"%s*:%s*(%d+)')
    local interval = content:match('"interval"%s*:%s*([%d%.]+)')
    if lvl then
        local n = tonumber(lvl)
        if n and n > 0 then selectedLevel = n end
    end
    if interval then speedInterval = tonumber(interval) or 3 end

    print('[SpeedUp] 📂 Загружено: x' .. tostring(selectedLevel) ..
          ' | интервал: ' .. tostring(speedInterval))
    return true
end

-- ──────── ПОЗИЦИИ ────────
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
        local x    = obj:match('"x":([%-%d%.]+)')
        local y    = obj:match('"y":([%-%d%.]+)')
        local z    = obj:match('"z":([%-%d%.]+)')
        if name and x and y and z then
            table.insert(loaded, {
                name = name,
                pos  = Vector3.new(tonumber(x), tonumber(y), tonumber(z)),
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

-- Загрузка при старте
loadPositionsFromFile()
loadSpeedFromFile()

-- ⏱ Автосохранение каждые 30 сек
task.spawn(function()
    while task.wait(30) do
        pcall(savePositionsToFile)
        pcall(saveSpeedToFile)
    end
end)

-- ⏱ Сохранение при выходе
Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then
        pcall(savePositionsToFile)
        pcall(saveSpeedToFile)
    end
end)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⚡ СКОРОСТЬ — БАЗОВАЯ (фиксированная)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local function getSpeedFrame()
    local ok, frame = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.SpeedUp.Frame
    end)
    return ok and frame or nil
end

-- Получить список доступных скоростей
local function getAvailableSpeeds()
    local list = {}
    local frame = getSpeedFrame()
    if not frame then return list end
    for i = 1, 5 do
        local btn = frame:FindFirstChild('Buttonx' .. i)
        if btn and getconnections then
            local ok, conns = pcall(getconnections, btn.Activated)
            if ok and conns and #conns > 0 then
                table.insert(list, 'x' .. i)
            end
        end
    end
    return list
end

-- Нажать кнопку скорости
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

local SpeedGroup = Tabs.SpeedUp:AddLeftGroupbox('⚡ Авто-скорость (фикс.)')

-- Выбор скорости
local SpeedDropdown = SpeedGroup:AddDropdown('SpeedSelect', {
    Values = {},
    Default = 1,
    Multi = false,
    Text = 'Скорость',
    Tooltip = 'Какую скорость держать постоянно',
    Callback = function(Value)
        local lvl = parseLevel(Value)
        if lvl then
            selectedLevel = lvl
            print('[SpeedUp] 🎯 Выбрано: x' .. lvl)
            pcall(saveSpeedToFile)
        end
    end,
})

SpeedGroup:AddButton({
    Text = '🔄 Обновить список',
    Tooltip = 'Обновить доступные кнопки скорости',
    Func = function()
        local list = getAvailableSpeeds()
        if #list == 0 then
            Library:Notify('❌ Нет кнопок скорости', 3)
            return
        end
        SpeedDropdown:SetValues(list)
        if selectedLevel then
            pcall(function() SpeedDropdown:SetValue('x' .. selectedLevel) end)
        end
        Library:Notify('✅ Скорости: ' .. table.concat(list, ', '), 3)
        print('[SpeedUp] 🔄 Доступно:', table.concat(list, ', '))
    end,
})

SpeedGroup:AddSlider('SpeedInterval', {
    Text = '⏱ Интервал (сек)',
    Default = 3,
    Min = 1, Max = 30, Rounding = 1, Compact = false,
    Tooltip = 'Как часто нажимать кнопку скорости',
    Callback = function(v)
        speedInterval = v
        pcall(saveSpeedToFile)
    end,
})

SpeedGroup:AddToggle('AutoSpeedToggle', {
    Text = '⚡ Авто-скорость (фиксированная)',
    Default = false,
    Tooltip = 'Всегда держит выбранную скорость (отключается если вкл. волновая скорость)',
    Callback = function(Value)
        autoSpeedEnabled = Value
        if Value then
            task.spawn(function()
                -- Ожидание выбора скорости
                local waited = 0
                while autoSpeedEnabled and not selectedLevel and waited < 30 do
                    local val = SpeedDropdown.Value
                    if val and val ~= '' then
                        local lvl = parseLevel(val)
                        if lvl then selectedLevel = lvl end
                    end
                    if not selectedLevel then loadSpeedFromFile() end
                    if not selectedLevel then
                        task.wait(0.5)
                        waited = waited + 0.5
                    end
                end

                if not selectedLevel then
                    Library:Notify('⚠ Скорость не выбрана', 3)
                    return
                end

                print('[SpeedUp] ▶ ВКЛ, x' .. selectedLevel)

                while autoSpeedEnabled do
                    -- Не кликаем если работает волновая скорость
                    if not waveSpeedEnabled then
                        clickSpeed(selectedLevel)
                    end

                    local elapsed = 0
                    while elapsed < speedInterval and autoSpeedEnabled do
                        task.wait(0.2)
                        elapsed = elapsed + 0.2
                    end
                end
                print('[SpeedUp] ■ ВЫКЛ')
            end)
        else
            print('[SpeedUp] ■ ВЫКЛ')
        end
    end,
})

-- Автозагрузка списка скоростей через 1 сек
task.spawn(function()
    task.wait(1)
    local list = getAvailableSpeeds()
    if #list > 0 then
        SpeedDropdown:SetValues(list)
        if selectedLevel then
            pcall(function() SpeedDropdown:SetValue('x' .. selectedLevel) end)
        end
        print('[SpeedUp] 🔄 Автозагрузка списка:', table.concat(list, ', '))
    end
end)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🌊 ВОЛНОВАЯ СКОРОСТЬ (workspace.Info.Wave.Value)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local WaveSpeedGroup = Tabs.SpeedUp:AddRightGroupbox('🌊 Скорость по волнам')

local waveSpeedEnabled     = false
local waveSpeedRules       = {}   -- [{wave=N, level=M}, ...] отсортировано по wave
local lastAppliedWaveLevel = nil

-- ──────── ПРОЧИТАТЬ ТЕКУЩУЮ ВОЛНУ ────────
local function getCurrentWave()
    local ok, info = pcall(function()
        return workspace:FindFirstChild("Info")
    end)
    if not ok or not info then return nil end

    local wave = info:FindFirstChild("Wave")
    if not wave then return nil end

    local ok2, v = pcall(function() return wave.Value end)
    if not ok2 then return nil end

    if type(v) == "number" then
        return math.floor(v)
    elseif type(v) == "string" then
        local n = v:match("%d+")
        return n and tonumber(n) or nil
    end
    return nil
end

-- ──────── СОХРАНЕНИЕ ПРАВИЛ ────────
local function saveWaveSpeedToFile()
    if not writefile then return false end
    local lines = {}
    for _, r in ipairs(waveSpeedRules) do
        table.insert(lines, string.format('  {"wave":%d,"level":%d}', r.wave, r.level))
    end
    local json = '{\n "rules": [\n' .. table.concat(lines, ',\n') .. '\n ]\n}'
    return pcall(function()
        ensureFolders()
        writefile(WAVE_SPEED_FILE, json)
    end)
end

local function loadWaveSpeedFromFile()
    if not readfile or not isfile then return false end
    local exists = false
    pcall(function() exists = isfile(WAVE_SPEED_FILE) end)
    if not exists then return false end
    local content = nil
    pcall(function() content = readfile(WAVE_SPEED_FILE) end)
    if not content or content == "" then return false end

    local loaded = {}
    for obj in content:gmatch('{([^{}]+)}') do
        local w = obj:match('"wave"%s*:%s*(%d+)')
        local l = obj:match('"level"%s*:%s*(%d+)')
        if w and l then
            table.insert(loaded, { wave = tonumber(w), level = tonumber(l) })
        end
    end
    if #loaded > 0 then
        table.sort(loaded, function(a, b) return a.wave < b.wave end)
        waveSpeedRules = loaded
        print('[WaveSpeed] 📂 [' .. USER_ID .. '] Загружено правил:', #loaded)
        return true
    end
    return false
end

-- ──────── ЛОГИКА: какая скорость для волны ────────
local function getSpeedLevelForWave(wave)
    if #waveSpeedRules == 0 then return nil end
    local best = nil
    for _, r in ipairs(waveSpeedRules) do
        if wave >= r.wave then
            if not best or r.wave > best.wave then
                best = r
            end
        end
    end
    return best and best.level or nil
end

-- ──────── UI: ввод волны (С ИСПРАВЛЕНИЕМ) ────────
-- pendingWave/pendingSpeed — страховка на случай, если .Value не успел обновиться
local pendingWave  = 1
local pendingSpeed = 2

local waveInputOpt = WaveSpeedGroup:AddInput('WaveSpeedWaveInput', {
    Text        = '🌊 Номер волны (с которой)',
    Default     = '1',
    Placeholder = '1, 5, 10, 20...',
    Numeric     = true,
    Finished    = false,   -- реагируем сразу при вводе, а не по Enter/фокусу
    Tooltip     = 'С какой волны применять эту скорость',
    Callback = function(v)
        local n = tonumber(tostring(v):match('%d+'))
        if n then
            pendingWave = n
            print('[WaveSpeed] ✏ Введена волна:', n)
        end
    end,
})

-- ──────── UI: выбор скорости ────────
local waveSpeedDropdown = WaveSpeedGroup:AddDropdown('WaveSpeedLevelPicker', {
    Values  = { 'x1','x2','x3','x4','x5' },
    Default = 1,
    Multi   = false,
    Text    = '⚡ Скорость с этой волны',
    Tooltip = 'Какую скорость держать начиная с этой волны',
    Callback = function(v)
        local lvl = parseLevel(v)
        if lvl then
            pendingSpeed = lvl
            print('[WaveSpeed] ✏ Введена скорость: x' .. lvl)
        end
    end,
})

WaveSpeedGroup:AddButton({
    Text = '🔄 Обновить доступные скорости',
    Tooltip = 'Подтянуть кнопки скоростей из игры',
    Func = function()
        local list = getAvailableSpeeds()
        if #list == 0 then
            Library:Notify('❌ Нет кнопок скорости', 3)
            return
        end
        waveSpeedDropdown:SetValues(list)
        Library:Notify('✅ Скорости: ' .. table.concat(list, ', '), 2)
    end,
})

-- ──────── UI: список правил ────────
local waveSpeedListLabel = WaveSpeedGroup:AddLabel('🌊 Правил: 0', false)

local function updateWaveSpeedLabel()
    local cnt = #waveSpeedRules
    if cnt == 0 then
        pcall(function() waveSpeedListLabel:SetText('🌊 Правил: 0') end)
        return
    end
    local parts = {}
    for _, r in ipairs(waveSpeedRules) do
        table.insert(parts, 'W' .. r.wave .. '→x' .. r.level)
    end
    pcall(function()
        waveSpeedListLabel:SetText('🌊 ' .. table.concat(parts, ' | '))
    end)
end

-- ──────── UI: показать текущие правила в консоли ────────
local function printCurrentRules()
    print('--- 🌊 Текущие правила ---')
    if #waveSpeedRules == 0 then
        print('  (пусто)')
    else
        for i, r in ipairs(waveSpeedRules) do
            print(string.format('  [%d] волна %d → x%d', i, r.wave, r.level))
        end
    end
    print('--------------------------')
end

-- ──────── UI: добавить правило (С ПРАВКОЙ) ────────
WaveSpeedGroup:AddButton({
    Text    = '➕ Добавить / обновить правило',
    Tooltip = 'Например: с 20 волны держать x5. Если правило для этой волны уже есть — оно обновится.',
    Func = function()
        -- Читаем и из input, и из pending-страховки
        local waveRaw = waveInputOpt.Value
        local waveNum = tonumber(tostring(waveRaw):match('%d+')) or pendingWave

        local lvlRaw = waveSpeedDropdown.Value
        local lvl    = parseLevel(lvlRaw) or pendingSpeed

        if not waveNum or waveNum < 1 then
            Library:Notify('❌ Введи корректную волну (≥1)', 3)
            return
        end
        if not lvl then
            Library:Notify('❌ Выбери скорость', 3)
            return
        end

        print('[WaveSpeed] 🔍 Читаю из UI:')
        print('   Поле волны =', tostring(waveRaw))
        print('   pendingWave =', pendingWave)
        print('   Итоговая волна =', waveNum)
        print('   Скорость =', lvl)

        local replaced = false
        for _, r in ipairs(waveSpeedRules) do
            if r.wave == waveNum then
                print('[WaveSpeed] ♻ Заменяю существующее правило для волны ' .. waveNum ..
                      ' (было x' .. r.level .. ', стало x' .. lvl .. ')')
                r.level = lvl
                replaced = true
                break
            end
        end

        if not replaced then
            table.insert(waveSpeedRules, { wave = waveNum, level = lvl })
            print('[WaveSpeed] ➕ Добавляю новое правило: волна ' .. waveNum .. ' → x' .. lvl)
        end

        table.sort(waveSpeedRules, function(a, b) return a.wave < b.wave end)

        saveWaveSpeedToFile()
        updateWaveSpeedLabel()
        printCurrentRules()
        Library:Notify((replaced and '♻ W' or '➕ W') .. waveNum .. ' → x' .. lvl, 2)

        -- Сброс поля на следующую волну, чтобы второе правило
        -- не записалось на ту же волну, что и первое
        pcall(function()
            local nextWave = tostring(waveNum + 1)
            waveInputOpt:SetValue(nextWave)
            pendingWave = waveNum + 1
            print('[WaveSpeed] 🔄 Поле волны сброшено на:', nextWave)
        end)
    end,
})

-- ──────── UI: удалить конкретное правило ────────
local deleteWaveInput = WaveSpeedGroup:AddInput('WaveSpeedDeleteInput', {
    Text        = '🗑 Номер волны для удаления',
    Default     = '',
    Placeholder = 'например 10',
    Numeric     = true,
    Finished    = false,
    Tooltip     = 'Введи номер волны, правило которой нужно удалить',
    Callback = function(v) end,
})

WaveSpeedGroup:AddButton({
    Text    = '🗑 Удалить правило по волне',
    Tooltip = 'Убирает правило для указанной волны',
    Func = function()
        local raw = deleteWaveInput.Value
        local num = tonumber(tostring(raw):match('%d+'))
        if not num then
            Library:Notify('❌ Введи номер волны', 3)
            return
        end
        local found = false
        for i, r in ipairs(waveSpeedRules) do
            if r.wave == num then
                table.remove(waveSpeedRules, i)
                found = true
                break
            end
        end
        if found then
            saveWaveSpeedToFile()
            updateWaveSpeedLabel()
            printCurrentRules()
            Library:Notify('🗑 Удалено правило W' .. num, 2)
            pcall(function() deleteWaveInput:SetValue('') end)
        else
            Library:Notify('ℹ Нет правила для W' .. num, 2)
        end
    end,
})

-- ──────── UI: удалить последнее ────────
WaveSpeedGroup:AddButton({
    Text = '➖ Удалить последнее правило',
    Tooltip = 'Убрать последнее добавленное правило',
    Func = function()
        if #waveSpeedRules == 0 then return end
        local rm = table.remove(waveSpeedRules)
        saveWaveSpeedToFile()
        updateWaveSpeedLabel()
        printCurrentRules()
        Library:Notify('➖ W' .. rm.wave .. ' (x' .. rm.level .. ')', 2)
    end,
})

-- ──────── UI: очистить всё ────────
WaveSpeedGroup:AddButton({
    Text = '🗑 Очистить ВСЕ правила',
    Tooltip = 'Удалить ВСЕ правила скорости по волнам',
    Func = function()
        waveSpeedRules = {}
        saveWaveSpeedToFile()
        updateWaveSpeedLabel()
        printCurrentRules()
        Library:Notify('🗑 Все правила волн удалены', 2)
    end,
})

-- ──────── UI: показать в F9 ────────
WaveSpeedGroup:AddButton({
    Text = '📋 Показать правила (F9)',
    Tooltip = 'Вывести все правила в консоль',
    Func = function()
        print('========== 🌊 ВОЛНОВАЯ СКОРОСТЬ ==========')
        if #waveSpeedRules == 0 then
            print('  (правил нет)')
        else
            for i, r in ipairs(waveSpeedRules) do
                print(string.format('  %d) с волны %-4d → x%d', i, r.wave, r.level))
            end
        end
        local cur = getCurrentWave()
        print('  Текущая волна:', cur or '?')
        print('  Применено:', lastAppliedWaveLevel and ('x' .. lastAppliedWaveLevel) or '—')
        print('===========================================')
    end,
})

-- ──────── UI: диагностика ────────
WaveSpeedGroup:AddButton({
    Text = '🔎 Диагностика волны',
    Tooltip = 'Проверить, читается ли workspace.Info.Wave',
    Func = function()
        print('========== WAVE DIAG ==========')
        local info = workspace:FindFirstChild("Info")
        print('workspace.Info:', info and '✅' or '❌')
        if info then
            local w = info:FindFirstChild("Wave")
            print('Info.Wave:', w and '✅' or '❌')
            if w then
                print('  ClassName:', w.ClassName)
                print('  Value:', tostring(w.Value))
                print('  Type:', typeof(w.Value))
            end
        end
        print('Текущая волна (getCurrentWave):', tostring(getCurrentWave()))
        print('================================')
    end,
})

-- ──────── ГЛАВНЫЙ ЦИКЛ ────────
task.spawn(function()
    while task.wait(0.5) do
        if waveSpeedEnabled then
            local wave = getCurrentWave()
            if wave then
                local targetLevel = getSpeedLevelForWave(wave)

                -- Если правил для этой волны нет — берём дефолтную скорость
                if not targetLevel and selectedLevel then
                    targetLevel = selectedLevel
                end

                if targetLevel and targetLevel ~= lastAppliedWaveLevel then
                    local ok = clickSpeed(targetLevel)
                    if ok then
                        lastAppliedWaveLevel = targetLevel
                        print(string.format('[WaveSpeed] 🌊 Волна %d → x%d', wave, targetLevel))
                        pcall(function()
                            Library:Notify('🌊 Волна ' .. wave .. ' → x' .. targetLevel, 1.5)
                        end)
                    end
                end
            end
        end
    end
end)

-- ──────── UI: включить/выключить ────────
WaveSpeedGroup:AddToggle('WaveSpeedToggle', {
    Text = '🌊 Включить волновую скорость',
    Default = false,
    Tooltip = 'Скорость будет меняться автоматически по волнам',
    Callback = function(Value)
        waveSpeedEnabled = Value
        if Value then
            lastAppliedWaveLevel = nil
            local cur = getCurrentWave()
            print('[WaveSpeed] ▶ ВКЛ | текущая волна: ' .. tostring(cur))
            local cnt = #waveSpeedRules
            Library:Notify('🌊 ВКЛ | правил: ' .. cnt, 2)
        else
            print('[WaveSpeed] ■ ВЫКЛ')
        end
    end,
})

-- Автозагрузка правил
task.spawn(function()
    task.wait(1.5)
    loadWaveSpeedFromFile()
    updateWaveSpeedLabel()
    local list = getAvailableSpeeds()
    if #list > 0 then
        waveSpeedDropdown:SetValues(list)
    end
end)

-- ⏸ КОНЕЦ ЧАСТИ 2/4
-- ➡️ ПРОДОЛЖЕНИЕ В ЧАСТИ 3/4
-- ════════════════════════════════════════════════════════════
-- ⏸ ПРОДОЛЖЕНИЕ ЧАСТИ 3/4
-- ============================================================

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 ЮНИТЫ — СКАНЕР И УТИЛИТЫ
-- ════════════════════════════════════════════════════════════
-- ============================================================

-- Сканирование 6 слотов башен
local function scanSlots()
    local result = {}
    local ok, frame = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.Towers.Frame
    end)
    if not ok or not frame then return result end

    for i = 1, 6 do
        local slot = frame:FindFirstChild("Slot" .. i)
        if slot then
            local tv   = slot:FindFirstChild("TowerValue")
            local name = tv and tv:IsA("StringValue") and tv.Value or nil
            result[i] = {
                index      = i,
                slot       = slot,
                name       = (name and name ~= "" and name) or nil,
                textButton = slot:FindFirstChild("TextButton"),
            }
        end
    end
    return result
end

-- Найти слот по имени башни
local function findSlotByName(towerName)
    local slots = scanSlots()
    for i = 1, 6 do
        local d = slots[i]
        if d and d.name == towerName then return d end
    end
    return nil
end

-- Получить цену из слота
local function getPriceFromSlot(slot)
    if not slot then return nil end
    local p = slot:FindFirstChild("Price")
    if not p then return nil end
    return parseMoney(p.Text or "")
end

-- Папка UnitManager
local function getUnitManagerFolder()
    local ok, folder = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui.GameGui.UnitManager.Units
    end)
    return ok and folder or nil
end

-- ============================================================
-- 🎯 КЕШИРОВАННЫЙ SCAN UNIT MANAGER
--   Без кеша каждый вызов обходил ВСЕ юниты в GUI заново.
--   Теперь полный обход — не чаще 1 раза в TTL сек.
--   Принудительное обновление: scanUnitManager(true)
--
--   Состояние кеша лежит в _G, а не в local: главный чанк этого
--   скрипта упирается в лимит Luau — 200 локальных переменных
--   на функцию, каждый local здесь стоит один регистр.
-- ============================================================
_G.SLOP_UNIT_CACHE = _G.SLOP_UNIT_CACHE or { list = nil, time = 0, ttl = 1.5 }

local function scanUnitManager(force)
    local C   = _G.SLOP_UNIT_CACHE
    local now = tick()
    if not force and C.list and (now - C.time) < C.ttl then
        return C.list
    end

    local result = {}
    local folder = getUnitManagerFolder()
    if not folder then
        C.list = result
        C.time = now
        return result
    end

    for idx, unit in ipairs(folder:GetChildren()) do
        if unit:IsA("GuiObject") then
            local upgradeBtn = unit:FindFirstChild("Upgrade")
            if upgradeBtn and (upgradeBtn:IsA("TextButton") or upgradeBtn:IsA("ImageButton")) then
                local priceLabel = upgradeBtn:FindFirstChild("Price")
                local priceRaw = nil
                if priceLabel and priceLabel:IsA("TextLabel") then
                    priceRaw = priceLabel.Text
                end

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
                local levelText  = nil
                if levelLabel and levelLabel:IsA("TextLabel") then
                    levelText = levelLabel.Text
                end
                local levelInfo = parseLevelInfo(levelText)
                if levelInfo and levelInfo.current >= levelInfo.max then
                    isMax = true
                end

                local unitId   = unit:FindFirstChild("UnitID")
                local realName = unit.Name
                if unitId and unitId:IsA("StringValue") then
                    realName = unitId.Value
                end

                table.insert(result, {
                    name      = realName,
                    instance  = unit,
                    button    = upgradeBtn,
                    price     = price,
                    priceRaw  = priceRaw,
                    isMax     = isMax,
                    levelText = levelText,
                    order     = idx,
                })
            end
        end
    end

    C.list = result
    C.time = now
    return result
end

-- Получить размещённые башни в мире
-- Forward-declaration: checkOccupied() ниже вызывает эту функцию,
-- а ускоренное тело определено сильно ниже (после buildUnitIdMap).
-- Без этого Luau посчитал бы её глобалом.
local getPlacedTowersInWorld

-- Проверки
local occupiedCheckRadius   = 2
local skipOccupiedEnabled   = true
local skipExactEnabled      = true

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

-- Проверка: все позиции расставлены?
local function isAllPositionsPlaced()
    if #savedPositions == 0 then return false end
    for _, p in ipairs(savedPositions) do
        local occupied, _, isExact = checkOccupied(p.pos, p.name)
        if not (occupied and isExact) then
            return false
        end
    end
    return true
end

-- Forward declarations
local runOnePlacePass   = nil
local runOneUpgradePass = nil

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🗼 UI: БАШНИ В СЛОТАХ
-- ════════════════════════════════════════════════════════════
-- ============================================================

local UnitsInfoGroup = Tabs.Units:AddLeftGroupbox('🗼 Башни в слотах')

local slotLabels = {}
for i = 1, 6 do
    slotLabels[i] = UnitsInfoGroup:AddLabel('Слот ' .. i .. ': —', false)
end

-- Один обход UnitManager → карта UnitName → UnitID (вместо 6 обходов),
-- с кешем на 1.5 сек. force=true — игнорировать кеш.
-- Forward-declared выше (см. рядом с findUnitIdByName).
buildUnitIdMap = function(force)
    local S   = _G.SLOP_SCAN_CACHE
    local now = tick()
    if not force and S.idMap and (now - S.idTime) < S.ID_TTL then
        return S.idMap
    end

    local map = {}
    local folder = getUnitManagerFolder()
    if folder then
        for _, unit in ipairs(folder:GetChildren()) do
            if unit:IsA("GuiObject") then
                local unitNameLabel = unit:FindFirstChild("UnitName")
                local unitId = unit:FindFirstChild("UnitID")
                if unitNameLabel and unitId and unitId:IsA("StringValue") then
                    if map[unitNameLabel.Text] == nil then
                        map[unitNameLabel.Text] = unitId.Value
                    end
                end
            end
        end
    end

    S.idMap  = map
    S.idTime = now
    return map
end

-- ════════════════════════════════════════════════════════════
-- 🌍 УСКОРЕНИЕ ПРОВЕРКИ ЗАНЯТОСТИ
-- ════════════════════════════════════════════════════════════
-- Раньше checkOccupied() на КАЖДУЮ позицию заново обходил
-- workspace.Towers, а внутри делал FindFirstChildWhichIsA("BasePart") —
-- это поиск по ВСЕМ потомкам. При 12 позициях и 20 башнях это
-- сотни глубоких поисков на один проход расстановки.
--
--   1) _partCache — Model → BasePart. Ссылка на инстанс постоянна,
--      меняется только .Position, поэтому искать заново незачем.
--   2) _placedSnapshot — позиции на ОДИН проход расстановки.

local _partCache      = {}   -- Model -> BasePart | false (части нет)
local _placedSnapshot = nil

local function invalidatePlacedSnapshot()
    _placedSnapshot = nil
end

local function getPlacedTowersInWorld()
    if _placedSnapshot then return _placedSnapshot end

    local result = {}
    local ok, towersFolder = pcall(function()
        return workspace:FindFirstChild("Towers")
    end)
    if not ok or not towersFolder then
        _placedSnapshot = result
        return result
    end

    for _, obj in ipairs(towersFolder:GetChildren()) do
        local part = nil
        local name = obj.Name

        if obj:IsA("Model") then
            local cached = _partCache[obj]
            if cached == nil then
                cached = obj:FindFirstChild("HumanoidRootPart")
                    or obj.PrimaryPart
                    or obj:FindFirstChildWhichIsA("BasePart") or false
                _partCache[obj] = cached
            end
            if cached then part = cached end
        elseif obj:IsA("BasePart") then
            part = obj
        end

        if part then
            table.insert(result, { instance = obj, name = name, position = part.Position })
        end
    end

    _placedSnapshot = result
    return result
end

-- Обновление лейблов слотов
local function updateTowerLabels()
    local slots = scanSlots()

    -- Данные собираются ОДИН раз на все 6 слотов, а не 6 раз
    local idMap  = buildUnitIdMap()
    local tNames = getTowersExistsNames()

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

            add(idMap[d.name])
            local owned = getOwnedVariants(d.name, tNames)
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

UnitsInfoGroup:AddButton({
    Text = '🔄 Обновить',
    Tooltip = 'Обновить информацию о слотах',
    Func = function() updateTowerLabels() end,
})

-- 📊 Показать все варианты всех слотов
UnitsInfoGroup:AddButton({
    Text = '📊 Показать все варианты всех слотов',
    Tooltip = 'Выведет в F9 все доступные варианты для каждого слота',
    Func = function()
        local slots = scanSlots()
        local idMap  = buildUnitIdMap()
        local tNames = getTowersExistsNames()
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

                add(idMap[d.name])
                local owned = getOwnedVariants(d.name, tNames)
                for _, v in ipairs(owned) do add(v) end
                add(d.name)
                for _, mod in ipairs(MODIFIERS) do
                    add(d.name .. mod)
                end

                for j, v in ipairs(variants) do
                    print("   [" .. j .. "] " .. v)
                end
            end
        end

        print("")
        print("═══════════════════════════════════════════")
    end,
})

-- ⚠ Авто-обновление лейблов перенесено в единый цикл в конце скрипта (раз в 5 сек)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 UI: ЮНИТ И ПОЗИЦИИ
-- ════════════════════════════════════════════════════════════
-- ============================================================

local checkBalanceEnabled = true
local selectedPosIndex    = 1

local UnitsGroup = Tabs.Units:AddLeftGroupbox('🎯 Юнит и позиции')

local UnitDropdown = UnitsGroup:AddDropdown('UnitSelect', {
    Values  = {},
    Default = 1,
    Multi   = false,
    Text    = 'Юнит для позиции',
    Tooltip = 'Выбери юнита для сохранения позиции',
    Callback = function(Value)
        if Value then print('[Units] 🎯 Выбран:', Value) end
    end,
})

-- Обновление списка юнитов
local function refreshUnitsList(silent)
    local slots  = scanSlots()
    local labels = {}
    for i = 1, 6 do
        local d = slots[i]
        if d and d.name then
            local price = getPriceFromSlot(d.slot)
            table.insert(labels, d.name .. (price and (" | $" .. price) or ""))
        end
    end
    if #labels == 0 then
        if not silent then Library:Notify('❌ Слоты не найдены', 3) end
        return
    end
    UnitDropdown:SetValues(labels)
    if not silent then
        Library:Notify('🔄 Юнитов: ' .. #labels, 2)
    end
    print('[Units] 🔄 Список обновлён, юнитов:', #labels)
end

UnitsGroup:AddButton({
    Text = '🔄 Обновить список',
    Tooltip = 'Обновить список юнитов из слотов',
    Func = function() refreshUnitsList() end,
})

local MoneyLabel = UnitsGroup:AddLabel('💰 Баланс: 0', false)

UnitsGroup:AddToggle('CheckBalanceToggle', {
    Text    = '💰 Проверять баланс',
    Default = true,
    Tooltip = 'Не размещать башню если не хватает денег',
    Callback = function(v) checkBalanceEnabled = v end,
})

local PosLabel = UnitsGroup:AddLabel('📊 Позиций: 0', false)

-- Получить имя выбранного юнита
local function getSelectedUnitName()
    local val = UnitDropdown.Value
    if not val or val == '' then return nil end
    return val:match("^(.-)%s*|") or val
end

-- Обновить счётчик позиций
local function updatePosLabel()
    pcall(function()
        PosLabel:SetText('📊 Позиций: ' .. #savedPositions)
    end)
end

-- ============================================================
--   📋 СПИСОК ПОЗИЦИЙ В КОНСОЛЬ
-- ============================================================

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

-- ============================================================
--   📌 КНОПКИ УПРАВЛЕНИЯ ПОЗИЦИЯМИ
-- ============================================================

-- Set Position
UnitsGroup:AddButton({
    Text    = '📌 Set Position',
    Tooltip = 'Сохранить текущую позицию для выбранного юнита',
    Func = function()
        local hrp = getHRP()
        if not hrp then
            Library:Notify('❌ Игрок не найден', 3)
            return
        end
        local unitName = getSelectedUnitName()
        if not unitName then
            Library:Notify('❌ Выбери юнита', 3)
            return
        end
        table.insert(savedPositions, { name = unitName, pos = hrp.Position })
        updatePosLabel()
        savePositionsToFile()
        print(string.format('[Units] 📌 #%d [%s] @ %.1f, %.1f, %.1f',
            #savedPositions, unitName, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
        Library:Notify('📌 #' .. #savedPositions .. ' [' .. unitName .. ']', 2)
    end,
})

-- Удалить последнюю
UnitsGroup:AddButton({
    Text    = '❌ Удалить последнюю',
    Tooltip = 'Удалить последнюю сохранённую позицию',
    Func = function()
        if #savedPositions == 0 then return end
        local rm = table.remove(savedPositions)
        updatePosLabel()
        savePositionsToFile()
        Library:Notify('❌ Удалено: ' .. tostring(rm and rm.name), 2)
    end,
})

-- Reset ALL
UnitsGroup:AddButton({
    Text    = '🗑 Reset ALL',
    Tooltip = 'Удалить ВСЕ позиции',
    Func = function()
        savedPositions = {}
        updatePosLabel()
        savePositionsToFile()
        Library:Notify('🗑 Все позиции удалены', 2)
    end,
})

-- Список в консоль
UnitsGroup:AddButton({
    Text    = '📋 Список в консоль (F9)',
    Tooltip = 'Вывести все позиции в F9 со статусом',
    Func = function()
        printPositionsList()
        Library:Notify('📋 Список выведен в F9', 2)
    end,
})

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⚙️ UI: ПЛЕЙСМЕНТ
-- ════════════════════════════════════════════════════════════
-- ============================================================

local ActionGroup = Tabs.Units:AddRightGroupbox('⚙️ Плейсмент')

ActionGroup:AddSlider('PosIndexSlider', {
    Text    = 'Индекс позиции',
    Default = 1,
    Min     = 1, Max = 12, Rounding = 0, Compact = false,
    Tooltip = 'Какую позицию разместить кнопкой ▶ Place',
    Callback = function(v) selectedPosIndex = v end,
})

_G.__yOffset = -2

ActionGroup:AddSlider('YOffsetSlider', {
    Text    = '📉 Смещение Y',
    Default = -2,
    Min     = -20, Max = 10, Rounding = 1, Compact = false,
    Tooltip = 'Начни с -2, если не работает — -5, -10',
    Callback = function(v)
        _G.__yOffset = v
        print('[Units] 📉 Y-offset =', v)
    end,
})

_G.__placeDelay = 0.15

ActionGroup:AddSlider('PlaceDelay', {
    Text    = '⏱ Задержка',
    Default = 0.15,
    Min     = 0.05, Max = 2, Rounding = 2, Compact = false,
    Tooltip = 'Задержка между попытками размещения',
    Callback = function(v) _G.__placeDelay = v end,
})

-- ──────── ⚡ ТАЙМИНГИ ПОСТАНОВКИ (скорость) ────────
ActionGroup:AddSlider('InvokeDelay', {
    Text    = '⚡ Пауза между вариантами',
    Default = 0.1,
    Min     = 0, Max = 0.5, Rounding = 2, Compact = false,
    Tooltip = 'Пауза после неудачной попытки варианта. 0 = максимум скорости (больше риска отклонения по rate-limit)',
    Callback = function(v) _G.__invokeDelay = v end,
})

ActionGroup:AddToggle('FastPlaceToggle', {
    Text    = '⚡ Быстрая постановка',
    Default = false,
    Tooltip = 'Убирает фиксированные паузы (0.15 после клика по слоту, 0.08 после RequestTower). Быстрее, но если игра не успевает обработать слот — выключи',
    Callback = function(v) _G.__fastPlace = v end,
})

ActionGroup:AddToggle('SlopDebugToggle', {
    Text    = '🐛 Подробный лог',
    Default = false,
    Tooltip = 'Печатать в F9 перечень вариантов перед каждой постановкой (замедляет, включай только для отладки)',
    Callback = function(v) _G.__SLOP_DEBUG = v end,
})

ActionGroup:AddSlider('OccupiedRadius', {
    Text    = '📏 Радиус (0=выкл)',
    Default = 2,
    Min     = 0, Max = 20, Rounding = 1, Compact = false,
    Tooltip = 'Радиус проверки: занята ли позиция',
    Callback = function(v) occupiedCheckRadius = v end,
})

ActionGroup:AddToggle('SkipOccupiedToggle', {
    Text    = '⏭ Пропускать занятые',
    Default = true,
    Tooltip = 'Не размещать башню если позиция уже занята другой',
    Callback = function(v) skipOccupiedEnabled = v end,
})

ActionGroup:AddToggle('SkipExactToggle', {
    Text    = '⏭ Не дублировать',
    Default = true,
    Tooltip = 'Не ставить ту же самую башню на ту же позицию',
    Callback = function(v) skipExactEnabled = v end,
})

-- ============================================================
-- ════════════════════════════════════════════════════════════
-- 🎯 ФУНКЦИЯ РАЗМЕЩЕНИЯ ЮНИТА
-- ════════════════════════════════════════════════════════════

-- ⚡ Какой вариант сработал для базового имени. После первой
--   удачной постановки следующие идут по короткому пути: 1 попытка
--   вместо перебора всех. Заполняется в placeUnitAt.
local _goodVariant = {}
-- ============================================================

local function placeUnitAt(positionData, useCFrame)
    if not loadRemotes() then return false, 'Functions нет' end

    local baseName = positionData.name
    local pos      = positionData.pos

    -- Проверка занятости
    if skipOccupiedEnabled or skipExactEnabled then
        local occupied, who, isExact = checkOccupied(pos, baseName)
        if occupied then
            if isExact and skipExactEnabled then return false, 'уже стоит' end
            if not isExact and skipOccupiedEnabled then return false, 'занято' end
        end
    end

    -- Слот найден?
    local slotData = findSlotByName(baseName)
    if not slotData then
        return false, 'слот "' .. baseName .. '" не найден'
    end

    -- Хватает денег?
    if checkBalanceEnabled then
        local money = getMoney()
        local price = getPriceFromSlot(slotData.slot)
        if price and price > money then
            return false, string.format('нужно %d, у тебя %d', price, money)
        end
    end

    -- ══════════════════════════════════════════════════════
    -- ⚡ ПОРЯДОК ПЕРЕБОРА ВАРИАНТОВ
    -- ══════════════════════════════════════════════════════
    -- Каждая неудачная попытка — это 2 InvokeServer (сетевых
    -- round-trip) плюс ожидания. Значит порядок решает всё.
    --
    -- Раньше sort() КЛАД ВСЕ варианты с модификаторами вперёд, а
    -- чистый baseName — в самый конец. В худшем случае только
    -- последний вариант и был правильным: ~15 неудачных
    -- round-trip на одну постановку.
    --
    -- Теперь: 1) что уже сработало  2) id из UnitManager
    --         3) чистое имя  4) owned-варианты  5) неowned-модификаторы
    local variants = {}
    local seen = {}
    local function add(v)
        if v and v ~= "" and not seen[v] then
            seen[v] = true
            table.insert(variants, v)
        end
    end

    add(_goodVariant[baseName])          -- 1) сработавший раньше
    add(findUnitIdByName(baseName))      -- 2) id из UnitManager
    add(baseName)                        -- 3) чистое имя
    local owned = getOwnedVariants(baseName)
    for _, v in ipairs(owned) do add(v) end  -- 4) owned-варианты
    for _, mod in ipairs(MODIFIERS) do   -- 5) остальные модификаторы
        add(baseName .. mod)
    end

    if _G.__SLOP_DEBUG then
        print('[Units] 📋 Варианты "' .. baseName .. '" (' .. #variants .. '): '
            .. table.concat(variants, ' | '))
    end

    -- Клик по слоту
    if slotData.textButton then
        clickButton(slotData.textButton, true)
        if not _G.__fastPlace then task.wait(0.15) end
    end

    local yOffset  = _G.__yOffset or -2
    local finalPos = Vector3.new(pos.X, pos.Y + yOffset, pos.Z)
    local cf       = CFrame.new(finalPos)

    local invDelay = _G.__invokeDelay or 0.1

    -- Пробуем каждый вариант
    for _, fullUnitId in ipairs(variants) do
        local ok1, ret1 = pcall(function()
            return RequestTower:InvokeServer(
                { [1] = fullUnitId, [2] = baseName },
                false, true
            )
        end)

        if ok1 and ret1 ~= false then
            if not _G.__fastPlace then task.wait(0.08) end

            local ok2, ret2 = pcall(function()
                return SpawnTower:InvokeServer(baseName, cf, false, fullUnitId)
            end)

            if ok2 and ret2 ~= false then
                _goodVariant[baseName] = fullUnitId  -- запоминаем на будущее
                invalidatePlacedSnapshot()
                print('[Units] ✅ Размещено: ' .. fullUnitId)
                return true, '✅ ' .. fullUnitId
            end
        end
        if invDelay > 0 then task.wait(invDelay) end
    end

    return false, 'все варианты отклонены'
end

-- ============================================================
--   ▶ PLACE (одиночное размещение)
-- ============================================================

ActionGroup:AddButton({
    Text    = '▶ Place',
    Tooltip = 'Разместить выбранную позицию',
    Func = function()
        if #savedPositions == 0 then
            Library:Notify('❌ Нет позиций', 3)
            return
        end
        local idx = math.min(selectedPosIndex, #savedPositions)
        local p = savedPositions[idx]
        if not p then return end
        local ok, err = placeUnitAt(p, true)
        Library:Notify(ok and ('✅ #' .. idx) or ('❌ ' .. tostring(err)), 3)
        updatePosLabel()
    end,
})

-- ============================================================
--   🔁 AUTO PLACE (цикл)
-- ============================================================

local autoPlaceEnabled  = false
local autoPlaceInterval = 5

ActionGroup:AddSlider('AutoPlaceInterval', {
    Text    = '🔁 Интервал авто',
    Default = 5,
    Min     = 1, Max = 30, Rounding = 1, Compact = false,
    Tooltip = 'Пауза между проходами расстановки',
    Callback = function(v) autoPlaceInterval = v end,
})

runOnePlacePass = function()
    if #savedPositions == 0 then return 0 end
    local placed, failed, skipped = 0, 0, 0

    -- Новый проход → снимок позиций в мире устарел
    invalidatePlacedSnapshot()

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
    Text    = '🔁 Auto Place',
    Default = false,
    Tooltip = 'Автоматически расставляет все позиции в цикле',
    Callback = function(Value)
        autoPlaceEnabled = Value
        if Value then
            print('[Cycle] 🔁 Цикл расстановки ВКЛ')
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
                print('[Cycle] ■ Цикл расстановки ВЫКЛ')
            end)
        else
            print('[Cycle] ■ Цикл расстановки ВЫКЛ')
        end
    end,
})

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⬆️ AUTO UPGRADE — НОВАЯ СИСТЕМА
--   Логика:
--     1. Приоритетные юниты ставятся
--     2. Как только ВСЕ приоритетные на карте —
--        качаем их до MAX
--     3. Потом обычный режим: все остальные юниты
-- ════════════════════════════════════════════════════════════
-- ⚠ Отдельного фонового цикла (2 сек) тут намеренно НЕТ: он дёргал бы
--   scanUnitManager каждые 2 сек. updateUpgStatus/updatePhaseLabel сидят
--   в общем оптимизированном цикле в конце скрипта (раз в 5 сек).
-- ============================================================

local UpgGroup = Tabs.Units:AddRightGroupbox('⬆️ Auto Upgrade')

-- ──────── СОСТОЯНИЕ ────────
local autoUpgradeEnabled = false
local upgradeInterval    = 0.3
local upgradeMaxPerPass  = 10
local upgradeMode        = 'cheapest'  -- cheapest / expensive / order
local upgradeStats       = { session = 0, total = 0 }
local _manualUpgradeRun  = false

-- 🎯 ПРИОРИТЕТНЫЙ СПИСОК ЮНИТОВ
local priorityUnits      = {}      -- { "Alien Toilets", "Ice" }
local priorityEnabled    = false

-- Фазы: idle → waiting_placement → upgrading → done
local _priorityPhase     = 'idle'

-- Файл приоритета
local PRIORITY_UNITS_FILE = CONFIGS_FOLDER .. '/' .. USER_ID .. '_priorityunits.json'

-- ──────── СОХРАНЕНИЕ / ЗАГРУЗКА ────────
local function savePriorityUnits()
    if not writefile then return false end
    local lines = {}
    for _, name in ipairs(priorityUnits) do
        table.insert(lines, '  "' .. tostring(name):gsub('"', '\\"') .. '"')
    end
    local json = '{\n "units": [\n' .. table.concat(lines, ',\n') .. '\n ]\n}'
    return pcall(function()
        ensureFolders()
        writefile(PRIORITY_UNITS_FILE, json)
    end)
end

local function loadPriorityUnits()
    if not readfile or not isfile then return false end
    local exists = false
    pcall(function() exists = isfile(PRIORITY_UNITS_FILE) end)
    if not exists then return false end
    local content = nil
    pcall(function() content = readfile(PRIORITY_UNITS_FILE) end)
    if not content or content == "" then return false end

    local loaded = {}
    for name in content:gmatch('"([^"]+)"') do
        if name ~= 'units' then
            table.insert(loaded, name)
        end
    end
    if #loaded > 0 then
        priorityUnits = loaded
        print('[Priority] 📂 [' .. USER_ID .. '] Загружено:', table.concat(loaded, ', '))
        return true
    end
    return false
end

-- ──────── ИНДЕКС ЮНИТОВ ────────
-- scanUnitManager отдаёт UnitID.Value — это ПОЛНЫЙ id ("Ice Shiny"),
-- а в списке приоритета лежат БАЗОВЫЕ имена ("Ice"). Поэтому ключ
-- кладём в карту дважды: и полный, и базовый. Иначе приоритет на "Ice"
-- молча не совпадёт ни с одним вариантом, и автоапгрейд залипнет
-- в фазе «качаю приоритетных» навсегда.
--
-- Индекс строится ОДИН раз на весь приоритетный блок и передаётся
-- в три проверки ниже — это 1 обход UnitManager за проход, а не 3.
--
-- ⚠ force=true в runOneUpgradePass — ОБЯЗАТЕЛЬНО, не убирать:
--   после клика по Upgrade цена/isMax в GUI меняются сервером с
--   задержкой. Со свежим кешем (1.5 сек) снимок остаётся устаревшим,
--   getFirstNonMaxPriorityUnit вернёт тот же юнит, и скрипт будет
--   долбить по кнопке ~10 раз в секунду, переплачивая за апгрейды.
local function buildUnitIndex(force)
    local byName = {}
    for _, u in ipairs(scanUnitManager(force)) do
        byName[u.name] = u
        local base = stripModifier(u.name)
        if base and base ~= '' and byName[base] == nil then
            byName[base] = u
        end
    end
    return byName
end

-- ──────── ПРОВЕРКИ ────────

-- Все ли приоритетные уже стоят на карте?
local function areAllPriorityUnitsPlaced(byName)
    if #priorityUnits == 0 then return true end
    for _, name in ipairs(priorityUnits) do
        if not byName[name] then return false end
    end
    return true
end

-- Все ли приоритетные на MAX?
local function areAllPriorityUnitsMaxed(byName)
    if #priorityUnits == 0 then return true end
    for _, name in ipairs(priorityUnits) do
        local u = byName[name]
        if not u or not u.isMax then return false end
    end
    return true
end

-- Первый непрокачанный приоритетный
local function getFirstNonMaxPriorityUnit(byName)
    for _, name in ipairs(priorityUnits) do
        local u = byName[name]
        if u and not u.isMax then
            return u, name
        end
    end
    return nil, nil
end

-- ──────── UI: СТАТУС ФАЗЫ ────────
local PriorityPhaseLabel = UpgGroup:AddLabel('📊 Фаза: обычный режим', false)

local function updatePhaseLabel()
    local txt
    if not priorityEnabled or #priorityUnits == 0 then
        txt = '📊 Фаза: обычный режим'
    else
        if _priorityPhase == 'waiting_placement' then
            txt = '⏳ Жду расстановки приоритетных (' .. #priorityUnits .. ')'
        elseif _priorityPhase == 'upgrading' then
            txt = '⬆️ Качаю приоритетных до MAX'
        elseif _priorityPhase == 'done' then
            txt = '✅ Приоритет готов — обычный режим'
        else
            txt = '📊 Фаза: idle'
        end
    end
    pcall(function() PriorityPhaseLabel:SetText(txt) end)
end

-- ──────── UI: ВЫБОР ЮНИТА ────────
local PriorityUnitPicker = UpgGroup:AddDropdown('PriorityUnitPicker', {
    Values  = { '— выбери юнита —' },
    Default = 1,
    Multi   = false,
    Text    = '🎯 Юнит для приоритета',
    Tooltip = 'Добавь юнитов в список — они прокачаются до MAX раньше остальных',
    Callback = function(v) end,
})

UpgGroup:AddButton({
    Text    = '🔄 Обновить список юнитов',
    Tooltip = 'Подтянуть всех owned юнитов (включая непоставленных)',
    Func = function()
        local names = getAllOwnedUnitNames()
        local list  = { '— выбери юнита —' }
        for _, n in ipairs(names) do
            table.insert(list, n)
        end
        PriorityUnitPicker:SetValues(list)
        Library:Notify('🔄 Найдено: ' .. #names, 2)
        print('[Priority] 📦 Доступно юнитов:', #names)
    end,
})

-- ──────── UI: СПИСОК ПРИОРИТЕТА ────────
local PriorityListLabel = UpgGroup:AddLabel('🎯 Приоритет: (пусто)', false)

local function updatePriorityListLabel()
    if #priorityUnits == 0 then
        pcall(function() PriorityListLabel:SetText('🎯 Приоритет: (пусто)') end)
    else
        pcall(function()
            PriorityListLabel:SetText('🎯 ' .. table.concat(priorityUnits, ' → '))
        end)
    end
end

-- Список изменился → фазу сбрасываем, иначе она навсегда останется 'done'
local function priorityListChanged()
    _priorityPhase = 'idle'
    savePriorityUnits()
    updatePriorityListLabel()
    updatePhaseLabel()
end

UpgGroup:AddButton({
    Text    = '➕ Добавить в приоритет',
    Tooltip = 'Добавляет выбранного юнита в конец списка',
    Func = function()
        local v = PriorityUnitPicker.Value
        if not v or v == '' or v:find('выбери') then
            Library:Notify('❌ Выбери юнита', 3)
            return
        end
        for _, ex in ipairs(priorityUnits) do
            if ex == v then
                Library:Notify('⚠ Уже в списке', 2)
                return
            end
        end
        table.insert(priorityUnits, v)
        priorityListChanged()
        Library:Notify('➕ ' .. v .. ' (#' .. #priorityUnits .. ')', 2)
        print('[Priority] ➕ ' .. v)
    end,
})

UpgGroup:AddButton({
    Text    = '➖ Убрать последнего',
    Tooltip = 'Убирает последнего из списка',
    Func = function()
        if #priorityUnits == 0 then return end
        local rm = table.remove(priorityUnits)
        priorityListChanged()
        Library:Notify('➖ ' .. tostring(rm), 2)
    end,
})

UpgGroup:AddButton({
    Text    = '🗑 Очистить список',
    Tooltip = 'Убирает всех из приоритета',
    Func = function()
        priorityUnits = {}
        priorityListChanged()
        Library:Notify('🗑 Список очищен', 2)
    end,
})

UpgGroup:AddButton({
    Text    = '📋 Показать список (F9)',
    Tooltip = 'Выводит приоритетный список в консоль',
    Func = function()
        print('═══ 🎯 ПРИОРИТЕТНЫЙ СПИСОК ═══')
        if #priorityUnits == 0 then
            print('  (пусто)')
        else
            local byName = buildUnitIndex(true)
            for i, name in ipairs(priorityUnits) do
                local u = byName[name]
                local status
                if not u then
                    status = '❌ не поставлен'
                elseif u.isMax then
                    status = '✅ MAX'
                else
                    status = '⬆️ ' .. tostring(u.levelText or '?')
                end
                print(string.format('  %d) %-25s %s', i, name, status))
            end
        end
        print('═══════════════════════════════════')
    end,
})

-- ──────── UI: ГЛАВНЫЙ ТОГГЛ ────────
UpgGroup:AddToggle('PriorityUpgradeToggle', {
    Text    = '🎯 Включить приоритетную прокачку',
    Default = false,
    Tooltip = 'Пока все приоритетные не прокачаны до MAX — остальные не трогаются',
    Callback = function(Value)
        priorityEnabled = Value
        if Value then
            _priorityPhase = 'idle'
            print('[Priority] ▶ ВКЛ | юнитов в списке:', #priorityUnits)
            if #priorityUnits == 0 then
                Library:Notify('⚠ Добавь хотя бы одного юнита', 3)
            end
        else
            print('[Priority] ■ ВЫКЛ')
        end
        updatePhaseLabel()
    end,
})

-- ──────── UI: ОБЫЧНЫЕ НАСТРОЙКИ ────────
UpgGroup:AddDropdown('UpgradeMode', {
    Values  = { '💰 Дешёвое сначала', '💎 Дорогое сначала', '🔢 По порядку' },
    Default = 1,
    Multi   = false,
    Text    = 'Режим обычного апгрейда',
    Tooltip = 'В каком порядке качать остальных юнитов',
    Callback = function(Value)
        if Value:find('Дешёвое') then upgradeMode = 'cheapest'
        elseif Value:find('Дорогое') then upgradeMode = 'expensive'
        else upgradeMode = 'order' end
        print('[Upgrade] 🎯 Режим:', upgradeMode)
    end,
})

UpgGroup:AddSlider('UpgradeInterval', {
    Text    = '⏱ Задержка между апгрейдами',
    Default = 0.3,
    Min     = 0.05, Max = 3, Rounding = 2, Compact = false,
    Tooltip = 'Пауза после каждого клика по кнопке Upgrade',
    Callback = function(v) upgradeInterval = v end,
})

UpgGroup:AddSlider('UpgradeMaxPerPass', {
    Text    = '📊 Макс. апгрейдов за проход',
    Default = 10,
    Min     = 1, Max = 100, Rounding = 0,
    Tooltip = 'Сколько апгрейдов за один цикл (обычный режим)',
    Callback = function(v) upgradeMaxPerPass = v end,
})

local UpgStatusLabel = UpgGroup:AddLabel('Юнитов: 0 | MAX: 0 | Апгрейдов: 0', false)

local function updateUpgStatus()
    local arr = scanUnitManager()
    local maxed = 0
    for _, u in ipairs(arr) do
        if u.isMax then maxed = maxed + 1 end
    end
    pcall(function()
        UpgStatusLabel:SetText(string.format(
            'Юнитов: %d | MAX: %d | Апгрейдов: %d',
            #arr, maxed, upgradeStats.session))
    end)
end

-- ============================================================
--   🎯 ЯДРО: ОДИН ПРОХОД АПГРЕЙДА
-- ============================================================

runOneUpgradePass = function()
    -- ═══════════════════════════════════════════════
    -- ФАЗА 1 + 2: ПРИОРИТЕТ (расстановка → прокачка до MAX)
    -- ═══════════════════════════════════════════════
    if priorityEnabled and #priorityUnits > 0 then
        local byName = buildUnitIndex(true)   -- один обход на весь приоритетный блок

        -- ФАЗА 1: ЖДЁМ РАССТАНОВКИ ПРИОРИТЕТНЫХ
        if not areAllPriorityUnitsPlaced(byName) then
            if _priorityPhase ~= 'waiting_placement' then
                _priorityPhase = 'waiting_placement'
                print('[Priority] ⏳ Жду расстановки приоритетных юнитов...')
                updatePhaseLabel()
                pcall(function()
                    Library:Notify('⏳ Жду расстановки приоритетных', 3)
                end)
            end
            return -1  -- особая метка: ждём
        end

        -- ФАЗА 2: КАЧАЕМ ПРИОРИТЕТНЫХ ДО MAX
        if not areAllPriorityUnitsMaxed(byName) then
            if _priorityPhase ~= 'upgrading' then
                _priorityPhase = 'upgrading'
                print('[Priority] ⬆️ Все приоритетные на карте — качаю до MAX')
                updatePhaseLabel()
                pcall(function()
                    Library:Notify('⬆️ Качаю приоритетных', 2)
                end)
            end

            local unit, name = getFirstNonMaxPriorityUnit(byName)
            if not unit then return 0 end
            if not unit.button or not unit.button.Parent then return 0 end

            local money = getMoney()
            if unit.price and unit.price > money then
                return 0  -- ждём денег
            end

            if clickButton(unit.button, true) then
                upgradeStats.session = upgradeStats.session + 1
                upgradeStats.total   = upgradeStats.total + 1
                print(string.format('[Priority] ⬆️ %s (цена: %s)',
                    name, tostring(unit.priceRaw or '?')))
                task.wait(upgradeInterval)
                updateUpgStatus()
                return 1
            end
            return 0
        end

        -- ФАЗА 3: ПРИОРИТЕТ ГОТОВ
        if _priorityPhase ~= 'done' then
            _priorityPhase = 'done'
            print('[Priority] ✅ Все приоритетные прокачаны! Перехожу в обычный режим')
            pcall(function()
                Library:Notify('✅ Приоритет прокачан', 3)
            end)
            updatePhaseLabel()
        end
    end

    -- ═══════════════════════════════════════════════
    -- ФАЗА 4: ОБЫЧНЫЙ РЕЖИМ
    -- ═══════════════════════════════════════════════
    local arr = scanUnitManager()
    if #arr == 0 then return 0 end

    -- Копия: table.sort ниже не должен портить кеш scanUnitManager
    local units = {}
    for i = 1, #arr do units[i] = arr[i] end
    if #units == 0 then return 0 end

    -- Сортировка
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

    local upgraded, skipped_money, skipped_max = 0, 0, 0
    local money = getMoney()

    for _, unit in ipairs(units) do
        if not autoUpgradeEnabled and not _manualUpgradeRun then break end
        if upgraded >= upgradeMaxPerPass then break end

        if not unit.button or not unit.button.Parent then
            -- нет кнопки — пропускаем
        elseif unit.isMax then
            skipped_max = skipped_max + 1
        elseif not unit.price then
            skipped_max = skipped_max + 1
        else
            -- ⚡ getMoney() НЕ дёргаем на каждом юните: это
            -- leaderstats.Money + tostring + parseMoney. При 100 юнитов
            -- это 100 разборов чисел за проход. Обновляем только
            -- после реально сделанного апгрейда — баланс меняется
            -- только тогда.
            if unit.price > money then
                skipped_money = skipped_money + 1
                if upgradeMode == 'cheapest' then break end
            else
                if clickButton(unit.button, true) then
                    upgraded = upgraded + 1
                    upgradeStats.session = upgradeStats.session + 1
                    upgradeStats.total   = upgradeStats.total + 1
                    money = getMoney()
                    task.wait(upgradeInterval)
                end
            end
        end
    end

    if upgraded > 0 or skipped_money > 0 then
        print(string.format('[Upgrade] ✅%d | 💰%d | 💎MAX:%d',
            upgraded, skipped_money, skipped_max))
    end
    updateUpgStatus()
    return upgraded
end

-- ──────── ГЛАВНЫЙ ТОГГЛ ────────
UpgGroup:AddToggle('AutoUpgradeToggle', {
    Text    = '⬆️ Auto Upgrade',
    Default = false,
    Tooltip = 'Автоматический апгрейд (с приоритетной логикой если включена)',
    Callback = function(Value)
        autoUpgradeEnabled = Value
        if Value then
            local pcount = priorityEnabled and #priorityUnits or 0
            print('[Upgrade] ⬆️ ВКЛ | приоритетных:', pcount)
            task.spawn(function()
                local failStreak = 0
                while autoUpgradeEnabled do
                    local upg = runOneUpgradePass()

                    if upg == -1 then
                        -- Ждём расстановки приоритетных
                        failStreak = 0
                        task.wait(1.5)
                    elseif upg == 0 then
                        failStreak = failStreak + 1
                        task.wait(math.min(0.5 + failStreak * 0.5, 5))
                    else
                        failStreak = 0
                        task.wait(0.1)
                    end
                end
                print('[Upgrade] ■ ВЫКЛ')
            end)
        else
            print('[Upgrade] ■ ВЫКЛ')
        end
    end,
})

UpgGroup:AddButton({
    Text    = '▶ Тест: 1 проход',
    Tooltip = 'Сделать один проход апгрейда',
    Func = function()
        _manualUpgradeRun = true
        local upg = runOneUpgradePass()
        _manualUpgradeRun = false
        if upg == -1 then
            Library:Notify('⏳ Жду расстановки приоритетных', 3)
        else
            Library:Notify('⬆️ Апгрейдов: ' .. tostring(upg), 2)
        end
    end,
})

-- ──────── ПЕРВИЧНАЯ ЗАГРУЗКА ────────
task.spawn(function()
    task.wait(1)
    refreshUnitsList(true)   -- silent: без Notify при старте
    updatePosLabel()
    loadPriorityUnits()
    updatePriorityListLabel()
    updatePhaseLabel()
    updateUpgStatus()
    print('[Priority] 📂 Приоритетных юнитов в конфиге:', #priorityUnits)
end)

-- ⏸ КОНЕЦ ЧАСТИ 3/4
-- ➡️ ПРОДОЛЖЕНИЕ В ЧАСТИ 4/4
-- ════════════════════════════════════════════════════════════
-- ⏸ ПРОДОЛЖЕНИЕ ЧАСТИ 4/4 (ФИНАЛЬНАЯ)
-- ============================================================

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🛡 ANTI-AFK
-- ════════════════════════════════════════════════════════════
-- ============================================================
-- Секция обёрнута в do...end: её локали освобождаются на выходе
-- (лимит Luau — 200 локальных переменных на функцию)
do

local ANTI_AFK_DELAY = 4.5

-- Попытка кликнуть "I'm here" в Anti-Macro окне
local function tryClickAntiMacro(screenGui)
    if not screenGui or not screenGui.Parent then return false end

    for attempt = 1, 20 do
        if not screenGui.Parent then return false end

        for _, obj in ipairs(screenGui:GetDescendants()) do
            if obj:IsA("GuiButton") then
                local isHere = false
                if obj:IsA("TextButton") and obj.Text == "I'm here" then
                    isHere = true
                elseif obj.Name == "I'm here" then
                    isHere = true
                end

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

local AntiAFKGroup     = Tabs.Utilities:AddLeftGroupbox('🛡 Anti-AFK')
local antiAfkEnabled   = false
local antiAfkConns     = {}

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
    Text    = '🛡️ Anti-AFK',
    Default = true,
    Tooltip = 'Автоматически жмёт "I\'m here" в Anti-Macro окне',
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
    Text    = '⏱ Задержка (сек)',
    Default = 4.5,
    Min     = 0, Max = 15, Rounding = 1, Compact = false,
    Tooltip = 'Задержка перед кликом по "I\'m here"',
    Callback = function(v) ANTI_AFK_DELAY = v end,
})

AntiAFKGroup:AddButton({
    Text    = '🔍 Проверить сейчас',
    Tooltip = 'Принудительно просканировать Anti-Macro окна',
    Func = function()
        scanAllScreenGuis()
        Library:Notify('🔍 Скан запущен', 2)
    end,
})

-- Автозапуск Anti-AFK
task.spawn(function()
    task.wait(1)
    antiAfkEnabled = true
    print("[AntiAFK] ▶ Автозапуск (default=true)")
    setupAntiAFK()
end)

end -- do: ANTI-AFK

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🔁 AUTO REPLAY
-- ════════════════════════════════════════════════════════════
-- ============================================================
-- Секция обёрнута в do...end: её локали освобождаются на выходе
do

local AutoReplayGroup   = Tabs.Utilities:AddLeftGroupbox('🔁 Auto Replay')
local autoReplayEnabled = false
local autoReplayConns   = {}
local autoReplayDelay   = 1.5

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
    print(string.format('[AutoReplay] 🖱 Клик по Replay (%s): %s',
        tostring(reason), fired and 'OK' or 'fail'))
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

    local connES = ggChildAdded:Connect(function(child)
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
    Text    = '🔁 Auto Replay',
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
    Text    = '⏱ Задержка перед кликом (сек)',
    Default = 1.5,
    Min     = 0, Max = 10, Rounding = 1, Compact = false,
    Tooltip = 'Пауза между появлением Replay и кликом',
    Callback = function(v) autoReplayDelay = v end,
})

AutoReplayGroup:AddButton({
    Text    = '🔍 Тест: нажать Replay сейчас',
    Tooltip = 'Проверить работу кнопки Replay прямо сейчас',
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
    Text    = '📊 Диагностика EndScreen',
    Tooltip = 'Выведет информацию о структуре EndScreen в F9',
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

end -- do: AUTO REPLAY

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🧬 AUTO MUTATION
-- ════════════════════════════════════════════════════════════
-- ============================================================
-- Секция обёрнута в do...end: её локали освобождаются на выходе
-- (scanMutators/mutatorDropdown нужны только внутри секции,
--  поэтому поток обновления мутаций живёт здесь, а не в общем цикле)
do

local AutoMutationGroup   = Tabs.Utilities:AddLeftGroupbox('🧬 Auto Mutation')
local autoMutationEnabled = false
local selectedMutator     = 'None'
local autoMutationConns   = {}
local mutatorDropdown     = nil
_G.__autoMutationUsed     = false

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
    local list   = {}
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
        -- Принудительно делаем всё видимым
        local p = btn.Parent
        local depth = 0
        while p and p ~= game and depth < 10 do
            if p:IsA("GuiObject") and not p.Visible then
                p.Visible = true
            end
            p = p.Parent
            depth = depth + 1
        end

        -- Все сигналы
        if getconnections then
            for _, sigName in ipairs({
                'Activated', 'MouseButton1Click', 'MouseButton1Down',
                'MouseButton1Up', 'InputBegan', 'InputEnded'
            }) do
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

        -- Реальный клик через VIM
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
            local nm  = d.Name:lower()
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
        print('[AutoMutation] 🚪 Нажал закрытие:', closeBtn:GetFullName())
    else
        pcall(function() slopGui.Enabled = false end)
        print('[AutoMutation] 🚪 Скрыл SlopMutatorGui')
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
    Values  = { 'None' },
    Default = 'None',
    Multi   = false,
    Text    = 'Мутация',
    Tooltip = 'Какую мутацию выбирать автоматически',
    Callback = function(Value)
        selectedMutator = Value or 'None'
        print('[AutoMutation] 🎯 Выбрано:', selectedMutator)
    end,
})

AutoMutationGroup:AddButton({
    Text    = '🔄 Обновить список мутаций',
    Tooltip = 'Подтянуть список доступных мутаций',
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
    Text    = '🧬 Auto Mutation',
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
    Text    = '🔍 Тест: кликнуть сейчас',
    Tooltip = 'Проверить работу клика по мутации',
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
    Text    = '📊 Диагностика MutatorVoting',
    Tooltip = 'Выведет структуру MutatorVoting в F9',
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

-- 🧬 Авто-обновление списка мутаций (было 3 сек → тормозило, теперь 6 сек)
task.spawn(function()
    task.wait(6)
    while task.wait(6) do
        local list = scanMutators()
        if #list > 0 then
            local cur = mutatorDropdown.Values or {}
            if #cur ~= #list then
                mutatorDropdown:SetValues(list)
            end
        end
    end
end)

end -- do: AUTO MUTATION

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🔄 AUTO-LOAD / AUTO-INJECT
-- ════════════════════════════════════════════════════════════
-- ============================================================
-- Секция обёрнута в do...end: её локали освобождаются на выходе
-- (это самый «локальный» по величине блок скрипта)
do

local AutoLoadGroup = Tabs.Utilities:AddLeftGroupbox('🔄 Auto-Load Script')

local AUTOLOAD_URL_FILE   = 'SlopTDMenu/autoload_url.txt'
local AUTOLOAD_STATE_FILE = 'SlopTDMenu/autoload_state.txt'

local DEFAULT_AUTOLOAD_URL = 'https://raw.githubusercontent.com/Zecb/jono222/main/ner/Script.lua'

local function getQueueFn()
    if queue_on_teleport       then return queue_on_teleport       end
    if queueonteleport         then return queueonteleport         end
    if syn and syn.queue_on_teleport       then return syn.queue_on_teleport       end
    if fluxus and fluxus.queue_on_teleport then return fluxus.queue_on_teleport     end
    return nil
end

local function buildLoader(url)
    return string.format([[
        if _G.__SLOP_TD_LOADED then
            warn("[AutoLoad] ⚠ Скрипт уже активен — пропускаю")
            return
        end
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

local function saveURL(url)
    if not writefile then return false end
    return pcall(function()
        if makefolder then pcall(makefolder, 'SlopTDMenu') end
        writefile(AUTOLOAD_URL_FILE, url:gsub('%s+', ''))
    end)
end

local function doQueueAutoLoad(force)
    if _G.__AUTOLOAD_SESSION_QUEUED and not force then
        print('[AutoLoad] ℹ Уже в очереди')
        return false, 'уже в очереди'
    end
    local queueFn = getQueueFn()
    if not queueFn then
        return false, 'queue_on_teleport недоступен'
    end
    local url = loadSavedURL() or DEFAULT_AUTOLOAD_URL
    local ok = pcall(function() queueFn(buildLoader(url)) end)
    if ok then
        _G.__AUTOLOAD_SESSION_QUEUED = true
        print('[AutoLoad] ✅ Поставлен в очередь: ' .. url)
    end
    return ok, nil
end

local URLInputOpt = AutoLoadGroup:AddInput('AutoLoadURL', {
    Text        = '🌐 URL скрипта (raw GitHub)',
    Default     = DEFAULT_AUTOLOAD_URL,
    Placeholder = 'https://raw.githubusercontent.com/user/repo/main/script.lua',
    Numeric     = false,
    Finished    = true,
    Tooltip     = 'Ссылка на RAW-скрипт, который будет запускаться после телепорта',
    Callback = function(v)
        if not v or v == '' then return end
        if saveURL(v) then
            print('[AutoLoad] 🌐 URL сохранён:', v)
        end
    end,
})

AutoLoadGroup:AddLabel('📌 URL по умолчанию уже прописан', false)
AutoLoadGroup:AddLabel('🛡 Защита от двойного инжекта: ВКЛ', false)

AutoLoadGroup:AddButton({
    Text    = '💾 Сохранить URL',
    Tooltip = 'Сохранить введённый URL',
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
    Text    = '🚀 Поставить в очередь (1 раз)',
    Tooltip = 'Поставить скрипт в очередь на следующий телепорт',
    Func = function()
        local ok, err = doQueueAutoLoad(true)
        if ok then
            Library:Notify('🚀 Поставлено на след. телепорт', 3)
        else
            Library:Notify('❌ ' .. tostring(err), 3)
        end
    end,
})

AutoLoadGroup:AddButton({
    Text    = '♻ Сбросить флаг очереди',
    Tooltip = 'Если нужно поставить в очередь заново',
    Func = function()
        _G.__AUTOLOAD_SESSION_QUEUED = false
        Library:Notify('♻ Флаг очереди сброшен', 2)
    end,
})

local autoLoadEnabled = false

AutoLoadGroup:AddToggle('AutoLoadToggle', {
    Text    = '🔄 Авто-загрузка скрипта после телепорта',
    Default = false,
    Tooltip = 'Скрипт сам себя перезапустит после респавна/реинжоина/телепорта',
    Callback = function(Value)
        autoLoadEnabled = Value
        if writefile then
            pcall(function()
                if makefolder then pcall(makefolder, 'SlopTDMenu') end
                writefile(AUTOLOAD_STATE_FILE, Value and '1' or '0')
            end)
        end
        if Value then
            local ok, err = doQueueAutoLoad()
            if not ok then
                Library:Notify('⚠ ' .. tostring(err), 3)
            else
                Library:Notify('🔄 Auto-Load ВКЛ', 2)
            end
        end
    end,
})

AutoLoadGroup:AddButton({
    Text    = '🔎 Диагностика',
    Tooltip = 'Проверить доступность queue_on_teleport и других функций',
    Func = function()
        print('========== AutoLoad ==========')
        print('queue_on_teleport:', queue_on_teleport and '✅' or '❌')
        print('queueonteleport:', queueonteleport and '✅' or '❌')
        print('syn.queue_on_teleport:', (syn and syn.queue_on_teleport) and '✅' or '❌')
        print('fluxus.queue_on_teleport:', (fluxus and fluxus.queue_on_teleport) and '✅' or '❌')
        print('readfile:', readfile and '✅' or '❌')
        print('writefile:', writefile and '✅' or '❌')
        print('URL:', loadSavedURL() or ('(дефолт) ' .. DEFAULT_AUTOLOAD_URL))
        print('Enabled:', tostring(autoLoadEnabled))
        print('Session queued:', tostring(_G.__AUTOLOAD_SESSION_QUEUED))
        print('Global loaded:', tostring(_G.__SLOP_TD_LOADED))
        print('==============================')
    end,
})

task.spawn(function()
    task.wait(1)
    local url = loadSavedURL()
    if url then
        pcall(function() URLInputOpt:SetValue(url) end)
    else
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

-- ⚠ OnTeleport-хук НЕ ставится намеренно.
--   queue_on_teleport сам выполнит загруженный loader в новой сессии.
--   Если добавить ещё и хук — doQueueAutoLoad() вызовется дважды за
--   телепорт, и в игре окажется N копий скрипта при N телепортах
--   (фикс из коммита 062f662 на GitHub; здесь сохранён).

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⌨ KEYBIND МЕНЮ
-- ════════════════════════════════════════════════════════════
-- ============================================================

local UserInputService = game:GetService("UserInputService")

local keybindEnabled = false
local keybindKey     = Enum.KeyCode.RightShift
local keybindConn    = nil
local mainGuiRef     = nil
local lastToggle     = 0
local DEBOUNCE       = 0.35

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
    Text    = '⌨ Вкл. бинд меню',
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
    Multi   = false,
    Text    = 'Клавиша бинда',
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
    Text    = '📖 Показать меню',
    Tooltip = 'Принудительно показать меню',
    Func = function()
        if setMenuVisible(true) then
            pcall(function() Library:Notify('📖 Меню открыто', 1) end)
        end
    end,
})

KeybindGroup:AddButton({
    Text    = '📕 Скрыть меню',
    Tooltip = 'Принудительно скрыть меню',
    Func = function()
        if setMenuVisible(false) then
            pcall(function() Library:Notify('📕 Меню скрыто. Верни: ' .. keybindKey.Name, 2) end)
        end
    end,
})

KeybindGroup:AddButton({
    Text    = '🔎 Найти GUI меню',
    Tooltip = 'Проверить, что GUI меню найдено',
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

end -- do: AUTO-LOAD / KEYBIND

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⚙ НАСТРОЙКИ (SaveManager + ThemeManager)
-- ════════════════════════════════════════════════════════════
-- ============================================================

SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

if makefolder then
    pcall(makefolder, 'SlopTDMenu')
    pcall(makefolder, 'SlopTDMenu/accounts')
    pcall(makefolder, ACC_FOLDER)
end

ThemeManager:SetFolder(ACC_FOLDER)
SaveManager:SetFolder(ACC_FOLDER)

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   🎯 МЕНЕДЖЕР КОНФИГОВ АККАУНТА (UI)
-- ════════════════════════════════════════════════════════════
-- ============================================================

local ConfigGroup = Tabs.Settings:AddLeftGroupbox('👤 Аккаунт')

ConfigGroup:AddLabel('👤 ' .. LocalPlayer.Name, false)
ConfigGroup:AddLabel('🆔 UserId: ' .. USER_ID, false)
ConfigGroup:AddLabel('📁 Файлы: ' .. USER_ID .. '_*.json', false)

ConfigGroup:AddButton({
    Text    = '💾 Сохранить конфиг аккаунта',
    Tooltip = 'Сохранить все настройки для этого аккаунта',
    Func = function()
        saveAccountInfo()
        savePositionsToFile()
        saveSpeedToFile()
        savePriorityUnits()
        saveWaveSpeedToFile()
        Library:Notify('💾 Сохранено для ' .. LocalPlayer.Name, 3)
        print('[SlopTD] 💾 Сохранено:', LocalPlayer.Name, '(' .. USER_ID .. ')')
    end,
})

ConfigGroup:AddButton({
    Text    = '📂 Загрузить конфиг аккаунта',
    Tooltip = 'Загрузить все настройки этого аккаунта',
    Func = function()
        loadPositionsFromFile()
        loadSpeedFromFile()
        loadPriorityUnits()
        loadWaveSpeedFromFile()
        updatePriorityListLabel()
        updatePhaseLabel()
        updateWaveSpeedLabel()
        pcall(updatePosLabel)
        Library:Notify('📂 Загружено для ' .. LocalPlayer.Name, 3)
    end,
})

ConfigGroup:AddButton({
    Text    = '📋 Список всех конфигов аккаунтов',
    Tooltip = 'Показать все сохранённые аккаунты в F9',
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
-- ════════════════════════════════════════════════════════════
--   🔄 ФИНАЛЬНАЯ ПРОВЕРКА СКОРОСТИ
-- ════════════════════════════════════════════════════════════
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

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⏱ ФИНАЛЬНЫЕ АВТОСОХРАНЕНИЯ
-- ════════════════════════════════════════════════════════════

-- Автосохранение скорости при изменении
task.spawn(function()
    local lastLevel, lastInterval = selectedLevel, speedInterval
    while task.wait(3) do
        if selectedLevel ~= lastLevel or speedInterval ~= lastInterval then
            lastLevel = selectedLevel
            lastInterval = speedInterval
            pcall(saveSpeedToFile)
        end
    end
end)

-- Автосохранение позиций при изменении
task.spawn(function()
    local lastCount = #savedPositions
    while task.wait(5) do
        if #savedPositions ~= lastCount then
            lastCount = #savedPositions
            pcall(savePositionsToFile)
        end
    end
end)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⚡ ОПТИМИЗИРОВАННЫЙ ЕДИНЫЙ ЦИКЛ ОБНОВЛЕНИЙ
-- ════════════════════════════════════════════════════════════
-- Раньше было ~6 отдельных фоновых циклов с task.wait(1..3),
-- каждый из которых обходил GUI Roblox. Суммарно 4500+ обходов/сек.
-- Теперь 5 потоков с интервалами 3-5 сек и разным стартовым сдвигом,
-- чтобы пиковые нагрузки не совпадали. Старт сдвинут, чтобы первый
-- проход случился не сразу после инжекта (иначе лагает открытие меню).
-- Списки карт/сложностей обновляются только вручную (кнопка) или
-- по тумблеру авто-обновления.
-- (поток мутаций живёт в секции AUTO MUTATION — он использует
--  scanMutators/mutatorDropdown, которые стали локалями do-блока)
-- ============================================================

task.spawn(function()
    -- 🔄 Лейблы слотов — раз в 5 сек
    task.wait(2)
    while task.wait(5) do
        pcall(updateTowerLabels)
    end
end)

task.spawn(function()
    -- 💰 Баланс + позиции — раз в 3 сек
    task.wait(1)
    while task.wait(3) do
        pcall(function() MoneyLabel:SetText('💰 Баланс: ' .. tostring(getMoney())) end)
        pcall(updatePosLabel)
    end
end)

task.spawn(function()
    -- ⬆️ Статус апгрейдов + лейбл фазы — раз в 5 сек (через кеш)
    task.wait(3)
    while task.wait(5) do
        pcall(updateUpgStatus)
        pcall(updatePhaseLabel)
    end
end)

task.spawn(function()
    -- 🗳 Карты — раз в 5 сек, ТОЛЬКО если включён тумблер (по умолчанию ВЫКЛ)
    task.wait(4)
    while task.wait(5) do
        if AutoRefreshToggle and AutoRefreshToggle.Value then
            pcall(refreshList, true)
        end
    end
end)

task.spawn(function()
    -- 🎯 Сложности — только первичное наполнение, дальше по кнопке
    task.wait(5)
    if not compKeys or #compKeys == 0 then
        pcall(refreshCompList, true)
    end
end)

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ⌨ DEFAULT KEYBIND
-- ════════════════════════════════════════════════════════════
-- ============================================================

Library.ToggleKeybind = Enum.KeyCode.RightShift

-- ============================================================
-- ════════════════════════════════════════════════════════════
--   ✅ ФИНАЛЬНЫЙ ПРИНТ
-- ════════════════════════════════════════════════════════════
-- ============================================================

print('╔════════════════════════════════════════════════════════╗')
print('║  🎮 SLOP TOWER DEFENSE — AUTO SCRIPT ЗАГРУЖЕН ✅      ║')
print('╠════════════════════════════════════════════════════════╣')
print('║  🗳 Голосование (карты + сложности)                   ║')
print('║  ⚡ Авто-скорость + 🌊 Волновая скорость              ║')
print('║  🎯 Плейсмент юнитов                                  ║')
print('║  ⬆️ Auto Upgrade (приоритетная прокачка)                 ║')
print('║  🛡 Anti-AFK                                          ║')
print('║  🔁 Auto Replay                                       ║')
print('║  🧬 Auto Mutation                                     ║')
print('║  💾 Конфиги по аккаунту (UserId)                      ║')
print('║  🔄 Auto-Load / Auto-Inject                           ║')
print('║  🛡 Anti-Double-Inject                                ║')
print('║  ⌨  Keybind: RightShift                               ║')
print('╚════════════════════════════════════════════════════════╝')
print('[SlopTD] 🎮 Скрипт загружен ✅')
print('🛡 Anti-double-inject: ВКЛ | 🌊 Волновая скорость: доступна | 🎯 Приоритет апгрейда: доступен')

--[[
    GTA 5 RP Settings UI
    Полноценное меню настроек с Redux системой и автосохранением
    Place in StarterPlayerScripts as LocalScript
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
	-- Colors (GTA 5 RP Style)
	BACKGROUND = Color3.fromRGB(15, 15, 18),
	BACKGROUND_SECONDARY = Color3.fromRGB(22, 22, 28),
	ACCENT = Color3.fromRGB(240, 195, 70),
	ACCENT_HOVER = Color3.fromRGB(255, 215, 90),
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_SECONDARY = Color3.fromRGB(160, 160, 165),
	TEXT_MUTED = Color3.fromRGB(100, 100, 105),
	DANGER = Color3.fromRGB(220, 70, 70),
	SUCCESS = Color3.fromRGB(70, 200, 120),
	BORDER = Color3.fromRGB(45, 45, 55),

	-- Animation
	ANIM_SPEED = 0.25,
	ANIM_STYLE = Enum.EasingStyle.Quint,

	-- Keys
	TOGGLE_KEY = Enum.KeyCode.M,
	HIDE_HINTS_KEY = Enum.KeyCode.U,
}

-- Привязываем внутренние ссылки к глобальному окружению для безопасного экспорта
_G.GTA5_InternalState = State
_G.GTA5_InternalDispatch = dispatch
_G.GTA5_InternalSubscribe = subscribe


-- ═══════════════════════════════════════════════════════════════════════════
-- STATE MANAGEMENT & AUTOSAVE
-- ═══════════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local SAVE_KEY = "GTA5_Settings_v2"

local State = {
	menuOpen = false,
	hintsVisible = true,
	currentTab = "graphics",
	currentRedux = "Default Redux",

	-- Настройки прицеливания, прыжков, размера прицела и мыши
	isAiming = false,
	canJumpGlobal = true,
	jumpCooldownTime = 1.2, -- КД на прыжок в секундах
	isRolling = false,
	crosshairSize = 1.0,    -- Масштаб прицела по умолчанию (1.0 = 100%)
	mouseSensitivity = 1.0, -- ИСПРАВЛЕНО: Чувствительность мыши по умолчанию (от 0.1 до 4.0)

	-- Настройки свиста
	whistleAnimId = "rbxassetid://121347910577501",
	whistleSoundId = "rbxassetid://116848351544313",
	isWhistling = false,

	-- Динамические Ключи Управления (Keybinds)
	binds = {
		whistle = Enum.KeyCode.X,
		shoulder = Enum.KeyCode.Z,
		roll = Enum.KeyCode.Space,
		toggleMenu = Enum.KeyCode.M,
		hideHints = Enum.KeyCode.U
	},

	-- Данные для красивого рендеринга в UI
	keybindsList = {
		{ id = "whistle", titleRu = "Свист", titleEn = "Whistle" },
		{ id = "shoulder", titleRu = "Смена плеча", titleEn = "Shoulder Swap" },
		{ id = "roll", titleRu = "Перекат (в бою)", titleEn = "Combat Roll" },
		{ id = "toggleMenu", titleRu = "Меню настроек", titleEn = "Settings Menu" },
		{ id = "hideHints", titleRu = "Скрыть подсказки", titleEn = "Toggle Hints" }
	},

	reduxPresets = {
		{ id = "Default Redux", name = "Стандарт", description = "Оригинальная графика игры" },
		{ id = "By3d Redux", name = "By3d Redux", description = "Серая атмосфера без теней" },
		{ id = "SeaCapt Redux", name = "SeaCapt Redux", description = "Кастомный пресет" }
	}
}

local StateListeners = {}
local function subscribe(callback)
	table.insert(StateListeners, callback)
	return function()
		for i, cb in ipairs(StateListeners) do
			if cb == callback then table.remove(StateListeners, i) break end
		end
	end
end

local function dispatch(action, payload)
	if action == "TOGGLE_MENU" then
		State.menuOpen = not State.menuOpen
	elseif action == "SET_MENU" then
		State.menuOpen = payload
	elseif action == "TOGGLE_HINTS" then
		State.hintsVisible = not State.hintsVisible
	elseif action == "SET_TAB" then
		State.currentTab = payload
	elseif action == "SET_REDUX" then
		State.currentRedux = payload
	elseif action == "CHANGE_BIND" then
		State.binds[payload.actionId] = payload.newKey
	elseif action == "SET_CROSSHAIR_SIZE" then
		State.crosshairSize = math.clamp(payload, 0.5, 2.5)
		if updateCrosshairScale then updateCrosshairScale() end
		if updatePreviewCrosshair then updatePreviewCrosshair() end
	elseif action == "SET_SENSITIVITY" then
		-- ИСПРАВЛЕНО: Меняем чувствительность с ограничением и вызываем обновление
		State.mouseSensitivity = math.clamp(payload, 0.1, 4.0)
		if updateMouseSensitivity then updateMouseSensitivity() end
	end

	for _, callback in ipairs(StateListeners) do
		task.spawn(callback, action, payload)
	end
end

-- Автосохранение
local function saveSettings()
	local serializableBinds = {}
	for k, v in pairs(State.binds) do serializableBinds[k] = v.Name end

	local data = {
		hintsVisible = State.hintsVisible,
		currentRedux = State.currentRedux,
		crosshairSize = State.crosshairSize,
		mouseSensitivity = State.mouseSensitivity, -- ИСПРАВЛЕНО: Сохраняем чувствительность мыши
		binds = serializableBinds
	}

	local saveEvent = ReplicatedStorage:FindFirstChild("SaveSettingsEvent")
	if saveEvent then
		saveEvent:FireServer(data)
	elseif plugin then
		plugin:SetSetting(SAVE_KEY, HttpService:JSONEncode(data))
	end
end

local function loadSettings()
	local data
	local loadEvent = ReplicatedStorage:FindFirstChild("LoadSettingsEvent")
	if loadEvent then
		data = loadEvent:InvokeServer()
	elseif plugin then
		local saved = plugin:GetSetting(SAVE_KEY)
		if saved then pcall(function() data = HttpService:JSONDecode(saved) end) end
	end

	if data then
		if data.hintsVisible ~= nil then State.hintsVisible = data.hintsVisible end
		if data.currentRedux then State.currentRedux = data.currentRedux end
		if data.crosshairSize then State.crosshairSize = data.crosshairSize end
		if data.mouseSensitivity then State.mouseSensitivity = data.mouseSensitivity end -- ИСПРАВЛЕНО: Загружаем чувствительность мыши
		if data.binds then
			for actionId, keyName in pairs(data.binds) do
				if Enum.KeyCode[keyName] then State.binds[actionId] = Enum.KeyCode[keyName] end
			end
		end
	end
end

-- Подписка на автоматическое сохранение триггеров
subscribe(function(action)
	if action == "TOGGLE_HINTS" or action == "SET_REDUX" or action == "CHANGE_BIND" or action == "SET_CROSSHAIR_SIZE" or action == "SET_SENSITIVITY" then
		saveSettings()
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

local function create(className, props, parent)
	local instance = Instance.new(className)
	for prop, value in pairs(props) do
		if prop ~= "Children" then
			instance[prop] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	if props.Children then
		for _, child in ipairs(props.Children) do
			child.Parent = instance
		end
	end
	return instance
end

local function tween(object, props, duration, style, direction)
	local tw = TweenService:Create(
		object,
		TweenInfo.new(
			duration or CONFIG.ANIM_SPEED,
			style or CONFIG.ANIM_STYLE,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	tw:Play()
	return tw
end

local function addHover(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		tween(button, {BackgroundColor3 = hoverColor}, 0.15)
	end)
	button.MouseLeave:Connect(function()
		tween(button, {BackgroundColor3 = normalColor}, 0.15)
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI ROOT & CORE GUI FIX (WITHOUT CROSSHAIR)
-- ═══════════════════════════════════════════════════════════════════════════

local StarterGui = game:GetService("StarterGui")

-- Отключаем стандартные элементы интерфейса Roblox, предотвращая наложение
task.spawn(function()
	local success = false
	while not success do
		local ok, err = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
		end)
		if ok then success = true else task.wait(0.1) end
	end
end)

local screenGui = create("ScreenGui", {
	Name = "GTA5_SettingsUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 100,
	IgnoreGuiInset = true -- Полностью убирает отступ сверху экрана (TopBar)
}, playerGui)

-- Управление видимостью окон при переключении табов
subscribe(function(action, payload)
	-- Насильно переключаем видимость контейнеров, защищая от пропадания
	if action == "SET_TAB" or action == "TOGGLE_MENU" then
		if keybindsTab then keybindsTab.Visible = (State.currentTab == "keybinds" and State.menuOpen) end
		if infoTab then infoTab.Visible = (State.currentTab == "info" and State.menuOpen) end
		if graphicsTab then graphicsTab.Visible = (State.currentTab == "graphics" and State.menuOpen) end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBIND HINTS (Right side)
-- ═══════════════════════════════════════════════════════════════════════════

local hintsContainer = create("Frame", {
	Name = "HintsContainer",
	Size = UDim2.new(0, 260, 0, 0),
	Position = UDim2.new(1, -275, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = CONFIG.BACKGROUND,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.Y
}, screenGui)

create("UICorner", {CornerRadius = UDim.new(0, 6)}, hintsContainer)
create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1, Transparency = 0.7}, hintsContainer)

-- Accent line
create("Frame", {
	Name = "AccentLine",
	Size = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = CONFIG.ACCENT,
	BorderSizePixel = 0
}, hintsContainer)

-- Header
local hintsHeader = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	LayoutOrder = 0
}, hintsContainer)

create("TextLabel", {
	Size = UDim2.new(1, -20, 1, 0),
	Position = UDim2.new(0, 15, 0, 0),
	BackgroundTransparency = 1,
	Text = "KEYBINDS",
	TextColor3 = CONFIG.ACCENT,
	TextSize = 13,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left
}, hintsHeader)

create("Frame", {
	Size = UDim2.new(1, -24, 0, 1),
	Position = UDim2.new(0, 12, 1, -1),
	BackgroundColor3 = CONFIG.ACCENT,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0
}, hintsHeader)

-- Hints content
local hintsContent = create("Frame", {
	Name = "Content",
	Size = UDim2.new(1, 0, 0, 0),
	Position = UDim2.new(0, 0, 0, 40),
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y
}, hintsContainer)

create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2)
}, hintsContent)

create("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10)
}, hintsContent)

-- ═══════════════════════════════════════════════════════════════════════════
-- SIDEBAR HINTS INITIALIZATION DEFER
-- ═══════════════════════════════════════════════════════════════════════════

-- Объявляем глобальные функции заранее, чтобы они были видны для подписки
local updateHintsVisibility
local generateHintsUI

-- Функция анимации подсказок
function updateHintsVisibility()
	if not hintsContainer or not State then return end
	if State.hintsVisible then
		hintsContainer.Visible = true
		tween(hintsContainer, {Position = UDim2.new(1, -275, 0.5, 0)}, 0.35)
	else
		local tw = tween(hintsContainer, {Position = UDim2.new(1, 50, 0.5, 0)}, 0.35)
		tw.Completed:Connect(function()
			if not State.hintsVisible then
				hintsContainer.Visible = false
			end
		end)
	end
end

-- Функция генерации элементов боковой панели (вызовется позже)
function generateHintsUI()
	if not hintsContent or not State or not State.keybindsList then return end

	-- Очищаем старые элементы, чтобы избежать дублирования
	hintsContent:ClearAllChildren()

	for i, bindData in ipairs(State.keybindsList) do
		local currentKey = State.binds[bindData.id]
		local keyName = currentKey and currentKey.Name or "None"

		local row = create("Frame", {
			Name = bindData.id .. "Row",
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			LayoutOrder = i
		}, hintsContent)

		-- Key box
		local keyBox = create("Frame", {
			Name = "KeyBox",
			Size = UDim2.new(0, 44, 0, 30),
			Position = UDim2.new(0, 0, 0.5, -15),
			BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
			BorderSizePixel = 0
		}, row)

		create("UICorner", {CornerRadius = UDim.new(0, 4)}, keyBox)
		create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1, Transparency = 0.4}, keyBox)

		local keyLabel = create("TextLabel", {
			Name = "KeyLabel",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = keyName,
			TextColor3 = CONFIG.ACCENT,
			TextSize = (keyName == "Space" or keyName == "LeftShift") and 9 or 13,
			Font = Enum.Font.GothamBold
		}, keyBox)

		-- Text Ru / En
		create("TextLabel", {
			Size = UDim2.new(1, -54, 0, 18),
			Position = UDim2.new(0, 52, 0, 3),
			BackgroundTransparency = 1,
			Text = bindData.titleRu,
			TextColor3 = CONFIG.TEXT_PRIMARY,
			TextSize = 13,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd
		}, row)

		create("TextLabel", {
			Size = UDim2.new(1, -54, 0, 14),
			Position = UDim2.new(0, 52, 0, 21),
			BackgroundTransparency = 1,
			Text = bindData.titleEn,
			TextColor3 = CONFIG.TEXT_MUTED,
			TextSize = 10,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left
		}, row)
	end
end

-- Подписка на изменение видимости подсказок
subscribe(function(action)
	if action == "TOGGLE_HINTS" then
		updateHintsVisibility()
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SETTINGS MENU (Center)
-- ═══════════════════════════════════════════════════════════════════════════

local menuOverlay = create("Frame", {
	Name = "MenuOverlay",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 10
}, screenGui)

local menuContainer = create("Frame", {
	Name = "MenuContainer",
	Size = UDim2.new(0, 550, 0, 420),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = CONFIG.BACKGROUND,
	BorderSizePixel = 0,
	ZIndex = 11
}, menuOverlay)

create("UICorner", {CornerRadius = UDim.new(0, 8)}, menuContainer)
create("UIStroke", {Color = CONFIG.BORDER, Thickness = 1}, menuContainer)

-- Menu Header
local menuHeader = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 55),
	BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
	BorderSizePixel = 0,
	ZIndex = 12
}, menuContainer)

create("UICorner", {CornerRadius = UDim.new(0, 8)}, menuHeader)

-- Fix corner overlap
create("Frame", {
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
	BorderSizePixel = 0,
	ZIndex = 12
}, menuHeader)

create("TextLabel", {
	Size = UDim2.new(1, -20, 1, 0),
	Position = UDim2.new(0, 20, 0, 0),
	BackgroundTransparency = 1,
	Text = "НАСТРОЙКИ / SETTINGS",
	TextColor3 = CONFIG.ACCENT,
	TextSize = 16,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 13
}, menuHeader)

-- Close button
local closeBtn = create("TextButton", {
	Size = UDim2.new(0, 36, 0, 36),
	Position = UDim2.new(1, -46, 0.5, -18),
	BackgroundColor3 = CONFIG.DANGER,
	BackgroundTransparency = 0.8,
	Text = "X",
	TextColor3 = CONFIG.DANGER,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	ZIndex = 13
}, menuHeader)

create("UICorner", {CornerRadius = UDim.new(0, 6)}, closeBtn)

closeBtn.MouseButton1Click:Connect(function()
	dispatch("SET_MENU", false)
end)

addHover(closeBtn, Color3.fromRGB(220, 70, 70), Color3.fromRGB(255, 90, 90))

-- Tabs
local tabsContainer = create("Frame", {
	Name = "Tabs",
	Size = UDim2.new(1, -40, 0, 40),
	Position = UDim2.new(0, 20, 0, 65),
	BackgroundTransparency = 1,
	ZIndex = 12
}, menuContainer)

create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8)
}, tabsContainer)

local tabs = {
	{id = "graphics", label = "Графика", labelEn = "Graphics"},
	{id = "keybinds", label = "Управление", labelEn = "Controls"},
	{id = "info", label = "Информация", labelEn = "Info"},
}

local tabButtons = {}

for i, tab in ipairs(tabs) do
	local isActive = State.currentTab == tab.id
	local btn = create("TextButton", {
		Name = tab.id .. "Tab",
		Size = UDim2.new(0, 140, 1, 0),
		BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY,
		Text = tab.label,
		TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_SECONDARY,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		LayoutOrder = i,
		ZIndex = 13
	}, tabsContainer)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, btn)

	tabButtons[tab.id] = btn

	btn.MouseButton1Click:Connect(function()
		dispatch("SET_TAB", tab.id)
	end)
end

-- Tab content container
local contentContainer = create("Frame", {
	Name = "Content",
	Size = UDim2.new(1, -40, 1, -125),
	Position = UDim2.new(0, 20, 0, 115),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 12
}, menuContainer)

-- ═══════════════════════════════════════════════════════════════════════════
-- REDUX LOADING SCREEN ANIMATION
-- ═══════════════════════════════════════════════════════════════════════════

local function triggerReduxLoadingScreen()
	local loadOverlay = create("Frame", {
		Name = "ReduxLoadingScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(5, 5, 5),
		BackgroundTransparency = 1,
		ZIndex = 9999
	}, screenGui)

	local statusText = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.45, 0),
		BackgroundTransparency = 1,
		Text = "APPLYING REDUX...",
		TextColor3 = CONFIG.ACCENT,
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		ZIndex = 10000
	}, loadOverlay)

	local barText = create("TextLabel", {
		Size = UDim2.new(0, 400, 0, 30),
		Position = UDim2.new(0.5, 0, 0.52, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = CONFIG.ACCENT,
		TextSize = 18,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10000
	}, loadOverlay)

	-- Анимация появления экрана
	tween(loadOverlay, { BackgroundTransparency = 0 }, 0.25)
	task.wait(0.3)

	-- Имитация заполнения бара квадратиками
	local totalSquares = 20
	for i = 1, totalSquares do
		local progress = string.rep("■", i) .. string.rep(" ", totalSquares - i)
		barText.Text = "[" .. progress .. "]"
		task.wait(0.08) -- Скорость заполнения
	end

	task.wait(0.4)
	-- Плавное исчезновение по окончании загрузки
	local fade = tween(loadOverlay, { BackgroundTransparency = 1 }, 0.3)
	tween(statusText, { TextTransparency = 1 }, 0.3)
	tween(barText, { TextTransparency = 1 }, 0.3)

	fade.Completed:Connect(function()
		loadOverlay:Destroy()
	end)
end

-- Подключаем запуск экрана к изменению настроек редукса
subscribe(function(action, payload)
	if action == "SET_REDUX" then
		task.spawn(triggerReduxLoadingScreen)
	end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- ALL TABS AND CONTAINERS INITIALIZATION (Порядок важен, чтобы не было nil!)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. GRAPHICS TAB
local graphicsTab = create("ScrollingFrame", {
	Name = "GraphicsTab",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = CONFIG.ACCENT,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 13,
	Visible = true
}, contentContainer)

create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }, graphicsTab)

-- Section: Redux Presets
local reduxSection = create("Frame", {
	Name = "ReduxSection", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 14
}, graphicsTab)
create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, reduxSection)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "ГРАФИЧЕСКИЕ ПРЕСЕТЫ / REDUX PRESETS",
	TextColor3 = CONFIG.ACCENT, TextSize = 12, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 15
}, reduxSection)

local reduxButtons = {}
for i, preset in ipairs(State.reduxPresets) do
	local isActive = State.currentRedux == preset.id
	local presetBtn = create("TextButton", {
		Name = preset.id, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY, Text = "", LayoutOrder = i, ZIndex = 15
	}, reduxSection)
	create("UICorner", {CornerRadius = UDim.new(0, 6)}, presetBtn)
	create("UIStroke", {Color = isActive and CONFIG.ACCENT or CONFIG.BORDER, Thickness = isActive and 2 or 1}, presetBtn)

	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 15, 0, 12), BackgroundTransparency = 1, Text = preset.name,
		TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_PRIMARY, TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16
	}, presetBtn)

	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 15, 0, 34), BackgroundTransparency = 1, Text = preset.description,
		TextColor3 = isActive and Color3.fromRGB(30, 30, 30) or CONFIG.TEXT_MUTED, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16
	}, presetBtn)

	local indicator = create("Frame", {
		Name = "Indicator", Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -35, 0.5, -10), BackgroundColor3 = isActive and CONFIG.SUCCESS or CONFIG.BORDER, ZIndex = 16
	}, presetBtn)
	create("UICorner", {CornerRadius = UDim.new(1, 0)}, indicator)

	if isActive then
		create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "✓", TextColor3 = CONFIG.TEXT_PRIMARY, TextSize = 14, Font = Enum.Font.GothamBold, ZIndex = 17}, indicator)
	end

	reduxButtons[preset.id] = {button = presetBtn, indicator = indicator}
	presetBtn.MouseButton1Click:Connect(function()
		dispatch("SET_REDUX", preset.id)
		local reduxEvent = ReplicatedStorage:FindFirstChild("ReduxEvent")
		if reduxEvent then reduxEvent:FireServer(preset.id) end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CROSSHAIR CUSTOMIZATION SECTION & PREVIEW
-- ═══════════════════════════════════════════════════════════════════════════

local crosshairSection = create("Frame", {
	Name = "CrosshairSection",
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 2,
	ZIndex = 14
}, graphicsTab)

create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, crosshairSection)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "НАСТРОЙКА ПРИЦЕЛА / CROSSHAIR SETTINGS",
	TextColor3 = CONFIG.ACCENT, TextSize = 12, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 15
}, crosshairSection)

-- Контейнер для кнопок изменения размера и Предпросмотра
local settingsRow = create("Frame", {
	Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY, LayoutOrder = 1, ZIndex = 15
}, crosshairSection)
create("UICorner", {CornerRadius = UDim.new(0, 6)}, settingsRow)

-- 1. ОКНО ПРЕДПРОСМОТРА (Preview Box с фоном-имитацией неба)
local previewBox = create("Frame", {
	Name = "PreviewBox",
	Size = UDim2.new(0, 100, 0, 90),
	Position = UDim2.new(0, 10, 0.5, -45),
	BackgroundColor3 = Color3.fromRGB(25, 35, 45),
	ZIndex = 16
}, settingsRow)
create("UICorner", {CornerRadius = UDim.new(0, 4)}, previewBox)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 4), BackgroundTransparency = 1,
	Text = "PREVIEW", TextColor3 = CONFIG.TEXT_MUTED, TextSize = 8, Font = Enum.Font.GothamBold, ZIndex = 17
}, previewBox)

-- Мини-версия прицела для окна предпросмотра
local previewCrosshair = create("Frame", {
	Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 17
}, previewBox)

local pRing = create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 19 }, previewCrosshair)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, pRing)
local pRingStroke = create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5, Transparency = 0.1 }, pRing)

local pDot = create("Frame", { Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 20 }, previewCrosshair)
create("UICorner", {CornerRadius = UDim.new(1, 0)}, pDot)

-- Функция обновления масштаба внутри превью
function updatePreviewCrosshair()
	local scale = State.crosshairSize or 1.0
	previewCrosshair.Size = UDim2.new(0, 24 * scale, 0, 24 * scale)
	if pRingStroke then pRingStroke.Thickness = 1.5 * scale end
	if pDot then pDot.Size = UDim2.new(0, 4 * scale, 0, 4 * scale) end
end

-- 2. КНОПКИ УПРАВЛЕНИЯ
local controlContainer = create("Frame", {
	Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 120, 0, 0), BackgroundTransparency = 1, ZIndex = 16
}, settingsRow)

local sizeLabel = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 20), BackgroundTransparency = 1,
	Text = "Текущий размер / Current Size: " .. math.round(State.crosshairSize * 100) .. "%",
	TextColor3 = CONFIG.TEXT_PRIMARY, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17
}, controlContainer)

local decreaseBtn = create("TextButton", {
	Size = UDim2.new(0, 40, 0, 34), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = CONFIG.BACKGROUND,
	Text = "-", TextColor3 = CONFIG.ACCENT, TextSize = 18, Font = Enum.Font.GothamBold, ZIndex = 17
}, controlContainer)
create("UICorner", {CornerRadius = UDim.new(0, 4)}, decreaseBtn)

local increaseBtn = create("TextButton", {
	Size = UDim2.new(0, 40, 0, 34), Position = UDim2.new(0, 50, 0, 50), BackgroundColor3 = CONFIG.BACKGROUND,
	Text = "+", TextColor3 = CONFIG.ACCENT, TextSize = 18, Font = Enum.Font.GothamBold, ZIndex = 17
}, controlContainer)
create("UICorner", {CornerRadius = UDim.new(0, 4)}, increaseBtn)

decreaseBtn.MouseButton1Click:Connect(function()
	dispatch("SET_CROSSHAIR_SIZE", State.crosshairSize - 0.1)
	sizeLabel.Text = "Текущий размер / Current Size: " .. math.round(State.crosshairSize * 100) .. "%"
end)

increaseBtn.MouseButton1Click:Connect(function()
	dispatch("SET_CROSSHAIR_SIZE", State.crosshairSize + 0.1)
	sizeLabel.Text = "Текущий размер / Current Size: " .. math.round(State.crosshairSize * 100) .. "%"
end)

task.spawn(function()
	task.wait(0.5)
	updatePreviewCrosshair()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. KEYBINDS TAB & MOUSE SENSITIVITY (MONOLITHIC FIXED LAYOUT)
-- ═══════════════════════════════════════════════════════════════════════════

local keybindsTab = create("ScrollingFrame", {
	Name = "KeybindsTab", 
	Size = UDim2.new(1, 0, 1, 0), 
	BackgroundTransparency = 1, 
	ScrollBarThickness = 4, 
	ScrollBarImageColor3 = CONFIG.ACCENT,
	CanvasSize = UDim2.new(0, 0, 0, 0), 
	-- ИСПРАВЛЕНО: Правильное название перечисления в Roblox — Enum.AutomaticSize.Y
	AutomaticCanvasSize = Enum.AutomaticSize.Y, 
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Visible = false, 
	ZIndex = 13
}, contentContainer)

local mainListLayout = create("UIListLayout", { 
	SortOrder = Enum.SortOrder.LayoutOrder, 
	Padding = UDim.new(0, 8) 
}, keybindsTab)

-- Глобальная правильная функция изменения чувствительности (ИСПРАВЛЕННАЯ БЕЗОПАСНАЯ ВЕРСИЯ)
function updateMouseSensitivity()
	local sens = State.mouseSensitivity or 1.0
	pcall(function()
		game:GetService("UserInputService").MouseDeltaSensitivity = sens
	end)

	-- ИСПРАВЛЕНО: Полностью переписан блок поиска элементов UI без ломающих парсер двоеточий
	local standaloneTab = contentContainer and contentContainer:FindFirstChild("KeybindsTab")
	local section = standaloneTab and standaloneTab:FindFirstChild("SensitivitySection")
	local bg = section and section:FindFirstChildOfClass("Frame")

	if bg then
		local track = bg:FindFirstChildOfClass("Frame")
		if track then
			local progress = track:FindFirstChild("Progress")
			local btn = track:FindFirstChild("KeyButton")
			local lbl = bg:FindFirstChildOfClass("TextLabel")

			local pct = (State.mouseSensitivity - 0.1) / (4.0 - 0.1)
			if progress then progress.Size = UDim2.new(pct, 0, 1, 0) end
			if btn then btn.Position = UDim2.new(pct, -8, 0.5, -8) end
			if lbl then lbl.Text = string.format("%.2fx", State.mouseSensitivity) end
		end
	end
end

local isCurrentlyBinding = false

function rebuildKeybindsUI()
	if not keybindsTab then return end

	-- Полностью очищаем вкладку перед перерисовкой
	for _, child in ipairs(keybindsTab:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end

	-- 1. Заголовок управления
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), 
		BackgroundTransparency = 1, 
		Text = "УПРАВЛЕНИЕ / CONTROLS", 
		TextColor3 = CONFIG.ACCENT,
		TextSize = 12, 
		Font = Enum.Font.GothamBlack, 
		TextXAlignment = Enum.TextXAlignment.Left, 
		LayoutOrder = 0, 
		ZIndex = 14
	}, keybindsTab)

	-- 2. Динамическая генерация рядов кнопок управления
	for i, bindData in ipairs(State.keybindsList) do
		local currentKey = State.binds[bindData.id]
		local row = create("Frame", {
			Name = bindData.id .. "BindRow", 
			Size = UDim2.new(1, 0, 0, 50), 
			BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY, 
			LayoutOrder = i, 
			ZIndex = 14
		}, keybindsTab)
		create("UICorner", {CornerRadius = UDim.new(0, 6)}, row)

		local keyButton = create("TextButton", {
			Name = "KeyButton", 
			Size = UDim2.new(0, 80, 0, 34), 
			Position = UDim2.new(0, 10, 0.5, -17), 
			BackgroundColor3 = CONFIG.BACKGROUND,
			Text = currentKey.Name, 
			TextColor3 = CONFIG.ACCENT, 
			TextSize = 13, 
			Font = Enum.Font.GothamBold, 
			ZIndex = 15
		}, row)
		create("UICorner", {CornerRadius = UDim.new(0, 4)}, keyButton)
		local stroke = create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1.5}, keyButton)

		keyButton.MouseButton1Click:Connect(function()
			if isCurrentlyBinding then return end
			isCurrentlyBinding = true
			keyButton.Text = "..."
			stroke.Color = CONFIG.TEXT_MUTED

			local inputConnection
			inputConnection = UserInputService.InputBegan:Connect(function(input, gp)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					inputConnection:Disconnect()
					if input.KeyCode ~= Enum.KeyCode.Escape then
						dispatch("CHANGE_BIND", { actionId = bindData.id, newKey = input.KeyCode })
						rebuildKeybindsUI()
						if updateHintsLabels then updateHintsLabels() end
					else
						keyButton.Text = currentKey.Name
						stroke.Color = CONFIG.ACCENT
					end
					isCurrentlyBinding = false
				end
			end)
		end)

		create("TextLabel", {Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 100, 0, 8), BackgroundTransparency = 1, Text = bindData.titleRu, TextColor3 = CONFIG.TEXT_PRIMARY, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15}, row)
		create("TextLabel", {Size = UDim2.new(1, -110, 0, 16), Position = UDim2.new(0, 100, 0, 28), BackgroundTransparency = 1, Text = bindData.titleEn, TextColor3 = CONFIG.TEXT_MUTED, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15}, row)
	end

	-- 3. РЕНДЕР СЛАЙДЕРА ЧУВСТВИТЕЛЬНОСТИ (Теперь он рендерится строго в конце списка!)
	local sensSection = create("Frame", {
		Name = "SensitivitySection",
		Size = UDim2.new(1, 0, 0, 85),
		BackgroundTransparency = 1,
		LayoutOrder = 100, -- Гарантирует позицию в самом низу под кнопками
		ZIndex = 14
	}, keybindsTab)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ / MOUSE SENSITIVITY",
		TextColor3 = CONFIG.ACCENT,
		TextSize = 12,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 15
	}, sensSection)

	local sliderBackground = create("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
		ZIndex = 15
	}, sensSection)
	create("UICorner", {CornerRadius = UDim.new(0, 6)}, sliderBackground)

	local valueLabel = create("TextLabel", {
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -70, 0, 0),
		BackgroundTransparency = 1,
		Text = string.format("%.2fx", State.mouseSensitivity),
		TextColor3 = CONFIG.ACCENT,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 16
	}, sliderBackground)

	local sliderTrack = create("Frame", {
		Size = UDim2.new(1, -100, 0, 4),
		Position = UDim2.new(0, 20, 0.5, -2),
		BackgroundColor3 = CONFIG.BACKGROUND,
		BorderSizePixel = 0,
		ZIndex = 16
	}, sliderBackground)
	create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderTrack)

	local currentPercentage = (State.mouseSensitivity - 0.1) / (4.0 - 0.1)
	local sliderProgress = create("Frame", {
		Name = "Progress",
		Size = UDim2.new(currentPercentage, 0, 1, 0),
		BackgroundColor3 = CONFIG.ACCENT,
		BorderSizePixel = 0,
		ZIndex = 17
	}, sliderTrack)
	create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderProgress)

	local sliderButton = create("TextButton", {
		Name = "KeyButton",
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(currentPercentage, -8, 0.5, -8),
		BackgroundColor3 = CONFIG.TEXT_PRIMARY,
		Text = "",
		ZIndex = 18
	}, sliderTrack)
	create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderButton)
	create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1.5}, sliderButton)

	-- Логика интерактивного перетаскивания мыши
	local isDragging = false
	local function updateSliderPosition(input)
		local trackSize = sliderTrack.AbsoluteSize.X
		local trackPos = sliderTrack.AbsolutePosition.X
		if trackSize <= 0 then return end

		local mouseX = input.Position.X
		local relativeX = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
		local newSens = 0.1 + (relativeX * (4.0 - 0.1))
		newSens = math.round(newSens * 100) / 100

		dispatch("SET_SENSITIVITY", newSens)

		sliderProgress.Size = UDim2.new(relativeX, 0, 1, 0)
		sliderButton.Position = UDim2.new(relativeX, -8, 0.5, -8)
		valueLabel.Text = string.format("%.2fx", newSens)
	end

	sliderButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSliderPosition(input) end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. INFO TAB
-- ═══════════════════════════════════════════════════════════════════════════

local infoTab = create("Frame", {
	Name = "InfoTab", 
	Size = UDim2.new(1, 0, 1, 0), 
	BackgroundTransparency = 1, 
	Visible = false, 
	ZIndex = 13
}, contentContainer)

create("UIListLayout", { 
	SortOrder = Enum.SortOrder.LayoutOrder, 
	Padding = UDim.new(0, 12), 
	HorizontalAlignment = Enum.HorizontalAlignment.Center 
}, infoTab)

create("TextLabel", { 
	Size = UDim2.new(1, 0, 0, 30), 
	BackgroundTransparency = 1, 
	Text = "GTA 5 RP SYSTEM", 
	TextColor3 = CONFIG.ACCENT, 
	TextSize = 24, 
	Font = Enum.Font.GothamBlack, 
	LayoutOrder = 1, 
	ZIndex = 14 
}, infoTab)

create("TextLabel", { 
	Size = UDim2.new(1, 0, 0, 20), 
	BackgroundTransparency = 1, 
	Text = "Version 1.0.0", 
	TextColor3 = CONFIG.TEXT_MUTED, 
	TextSize = 14, 
	Font = Enum.Font.Gotham, 
	LayoutOrder = 2, 
	ZIndex = 14 
}, infoTab)

create("Frame", { 
	Size = UDim2.new(0.6, 0, 0, 1), 
	BackgroundColor3 = CONFIG.BORDER, 
	LayoutOrder = 3, 
	ZIndex = 14 
}, infoTab)

create("TextLabel", { 
	Size = UDim2.new(0.9, 0, 0, 80), 
	BackgroundTransparency = 1, 
	Text = "Система движения и оружия в стиле GTA 5 RP.\n Включает инерцию, плавные повороты, систему Redux для графики и автосохранение настроек.", 
	TextColor3 = CONFIG.TEXT_SECONDARY, 
	TextSize = 13, 
	Font = Enum.Font.Gotham, 
	TextWrapped = true, 
	LayoutOrder = 4, 
	ZIndex = 14 
}, infoTab)

-- ═══════════════════════════════════════════════════════════════════════════
-- UPDATE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function updateTabs()
	if not tabButtons or not graphicsTab or not keybindsTab or not infoTab then return end

	for id, btn in pairs(tabButtons) do
		local isActive = State.currentTab == id
		tween(btn, {
			BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY,
			TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_SECONDARY
		}, 0.2)
	end

	graphicsTab.Visible = (State.currentTab == "graphics")
	keybindsTab.Visible = (State.currentTab == "keybinds")
	infoTab.Visible = (State.currentTab == "info")

	if State.currentTab == "keybinds" then
		rebuildKeybindsUI()
	end
end

-- Функция обновления текста клавиш на боковой панели (теперь она вынесена отдельно!)
function updateHintsLabels()
	if not hintsContent or not State.keybindsList then return end

	for _, bindData in ipairs(State.keybindsList) do
		local row = hintsContent:FindFirstChild(bindData.id .. "Row")
		if row then
			local keyBox = row:FindFirstChildOfClass("Frame")
			local keyLabel = keyBox and keyBox:FindFirstChild("KeyLabel")
			if keyLabel then
-- Функция обновления текста клавиш на боковой панели (Исправленная безопасная версия)
function updateHintsLabels()
	if not hintsContent or not State or not State.keybindsList then return end
	
	for _, bindData in ipairs(State.keybindsList) do
		local row = hintsContent:FindFirstChild(bindData.id .. "Row")
		if row then
			local keyBox = row:FindFirstChildOfClass("Frame")
			if keyBox then
				-- ИСПРАВЛЕНО: Безопасный поиск элемента без ломающих синтаксис двоеточий после оператора and
				local keyLabel = keyBox:FindFirstChild("KeyLabel")
				if keyLabel then
					local currentKey = State.binds[bindData.id]
					if currentKey then
						keyLabel.Text = currentKey.Name
						keyLabel.TextSize = (currentKey.Name == "Space" or currentKey.Name == "LeftShift") and 9 or 13
					end
				end
			end
		end
	end
end


				-- Функция генерации и перерисовки элементов вкладки управления
				function rebuildKeybindsUI()
					if not keybindsTab then return end

					-- ИСПРАВЛЕНО: Правильный и безопасный цикл очистки элементов перед перерисовкой
					for _, child in ipairs(keybindsTab:GetChildren()) do
						if child:IsA("Frame") or child:IsA("TextLabel") then 
							child:Destroy() 
						end
					end

					-- 1. Заголовок управления
					create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 24), 
						BackgroundTransparency = 1, 
						Text = "УПРАВЛЕНИЕ / CONTROLS", 
						TextColor3 = CONFIG.ACCENT,
						TextSize = 12, 
						Font = Enum.Font.GothamBlack, 
						TextXAlignment = Enum.TextXAlignment.Left, 
						LayoutOrder = 0, 
						ZIndex = 14
					}, keybindsTab)

					-- 2. Динамическая генерация рядов кнопок управления
					local isCurrentlyBinding = false
					for i, bindData in ipairs(State.keybindsList) do
						local currentKey = State.binds[bindData.id]
						local row = create("Frame", {
							Name = bindData.id .. "BindRow", 
							Size = UDim2.new(1, 0, 0, 50), 
							BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY, 
							LayoutOrder = i, 
							ZIndex = 14
						}, keybindsTab)
						create("UICorner", {CornerRadius = UDim.new(0, 6)}, row)

						local keyButton = create("TextButton", {
							Name = "KeyButton", 
							Size = UDim2.new(0, 80, 0, 34), 
							Position = UDim2.new(0, 10, 0.5, -17), 
							BackgroundColor3 = CONFIG.BACKGROUND,
							Text = currentKey.Name, 
							TextColor3 = CONFIG.ACCENT, 
							TextSize = 13, 
							Font = Enum.Font.GothamBold, 
							ZIndex = 15
						}, row)
						create("UICorner", {CornerRadius = UDim.new(0, 4)}, keyButton)
						local stroke = create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1.5}, keyButton)

						keyButton.MouseButton1Click:Connect(function()
							if isCurrentlyBinding then return end
							isCurrentlyBinding = true
							keyButton.Text = "..."
							stroke.Color = CONFIG.TEXT_MUTED

							local inputConnection
							inputConnection = UserInputService.InputBegan:Connect(function(input, gp)
								if input.UserInputType == Enum.UserInputType.Keyboard then
									inputConnection:Disconnect()
									if input.KeyCode ~= Enum.KeyCode.Escape then
										dispatch("CHANGE_BIND", { actionId = bindData.id, newKey = input.KeyCode })
										rebuildKeybindsUI()
										if updateHintsLabels then updateHintsLabels() end
									else
										keyButton.Text = currentKey.Name
										stroke.Color = CONFIG.ACCENT
									end
									isCurrentlyBinding = false
								end
							end)
						end)

						create("TextLabel", {Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 100, 0, 8), BackgroundTransparency = 1, Text = bindData.titleRu, TextColor3 = CONFIG.TEXT_PRIMARY, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15}, row)
						create("TextLabel", {Size = UDim2.new(1, -110, 0, 16), Position = UDim2.new(0, 100, 0, 28), BackgroundTransparency = 1, Text = bindData.titleEn, TextColor3 = CONFIG.TEXT_MUTED, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15}, row)
					end

					-- 3. РЕНДЕР СЛАЙДЕРА ЧУВСТВИТЕЛЬНОСТИ
					local sensSection = create("Frame", {
						Name = "SensitivitySection",
						Size = UDim2.new(1, 0, 0, 85),
						BackgroundTransparency = 1,
						LayoutOrder = 100, 
						ZIndex = 14
					}, keybindsTab)

					create("TextLabel", {
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ / MOUSE SENSITIVITY",
						TextColor3 = CONFIG.ACCENT,
						TextSize = 12,
						Font = Enum.Font.GothamBlack,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 15
					}, sensSection)

					local sliderBackground = create("Frame", {
						Size = UDim2.new(1, 0, 0, 46),
						Position = UDim2.new(0, 0, 0, 28),
						BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
						ZIndex = 15
					}, sensSection)
					create("UICorner", {CornerRadius = UDim.new(0, 6)}, sliderBackground)

					local valueLabel = create("TextLabel", {
						Size = UDim2.new(0, 60, 1, 0),
						Position = UDim2.new(1, -70, 0, 0),
						BackgroundTransparency = 1,
						Text = string.format("%.2fx", State.mouseSensitivity),
						TextColor3 = CONFIG.ACCENT,
						TextSize = 14,
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 16
					}, sliderBackground)

					local sliderTrack = create("Frame", {
						Size = UDim2.new(1, -100, 0, 4),
						Position = UDim2.new(0, 20, 0.5, -2),
						BackgroundColor3 = CONFIG.BACKGROUND,
						BorderSizePixel = 0,
						ZIndex = 16
					}, sliderBackground)
					create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderTrack)

					local currentPercentage = (State.mouseSensitivity - 0.1) / (4.0 - 0.1)
					local sliderProgress = create("Frame", {
						Name = "Progress",
						Size = UDim2.new(currentPercentage, 0, 1, 0),
						BackgroundColor3 = CONFIG.ACCENT,
						BorderSizePixel = 0,
						ZIndex = 17
					}, sliderTrack)
					create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderProgress)

					local sliderButton = create("TextButton", {
						Name = "KeyButton",
						Size = UDim2.new(0, 16, 0, 16),
						Position = UDim2.new(currentPercentage, -8, 0.5, -8),
						BackgroundColor3 = CONFIG.TEXT_PRIMARY,
						Text = "",
						ZIndex = 18
					}, sliderTrack)
					create("UICorner", {CornerRadius = UDim.new(1, 0)}, sliderButton)
					create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1.5}, sliderButton)

					local isDragging = false
					local function updateSliderPosition(input)
						local trackSize = sliderTrack.AbsoluteSize.X
						local trackPos = sliderTrack.AbsolutePosition.X
						if trackSize <= 0 then return end

						local mouseX = input.Position.X
						local relativeX = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
						local newSens = 0.1 + (relativeX * (4.0 - 0.1))
						newSens = math.round(newSens * 100) / 100

						dispatch("SET_SENSITIVITY", newSens)

						sliderProgress.Size = UDim2.new(relativeX, 0, 1, 0)
						sliderButton.Position = UDim2.new(relativeX, -8, 0.5, -8)
						valueLabel.Text = string.format("%.2fx", newSens)
					end

					sliderButton.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateSliderPosition(input) end
					end)
				end


		-- Текстовые описания
		create("TextLabel", {
			Size = UDim2.new(1, -110, 0, 20),
			Position = UDim2.new(0, 100, 0, 8),
			BackgroundTransparency = 1,
			Text = bindData.titleRu,
			TextColor3 = CONFIG.TEXT_PRIMARY,
			TextSize = 14,
			Font = Enum.Font.GothamSemibold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15
		}, row)

		create("TextLabel", {
			Size = UDim2.new(1, -110, 0, 16),
			Position = UDim2.new(0, 100, 0, 28),
			BackgroundTransparency = 1,
			Text = bindData.titleEn,
			TextColor3 = CONFIG.TEXT_MUTED,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15
		}, row)
	end
end

-- Вызываем обновление билда при инициализации вкладки управления
subscribe(function(action)
	if action == "SET_TAB" and State.currentTab == "keybinds" then
		rebuildKeybindsUI()
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- INFO TAB
-- ═══════════════════════════════════════════════════════════════════════════

local infoTab = create("Frame", {
	Name = "InfoTab",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 13
}, contentContainer)

create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12),
	HorizontalAlignment = Enum.HorizontalAlignment.Center
}, infoTab)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "GTA 5 RP SYSTEM",
	TextColor3 = CONFIG.ACCENT,
	TextSize = 24,
	Font = Enum.Font.GothamBlack,
	LayoutOrder = 1,
	ZIndex = 14
}, infoTab)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Text = "Version 1.0.0",
	TextColor3 = CONFIG.TEXT_MUTED,
	TextSize = 14,
	Font = Enum.Font.Gotham,
	LayoutOrder = 2,
	ZIndex = 14
}, infoTab)

create("Frame", {
	Size = UDim2.new(0.6, 0, 0, 1),
	BackgroundColor3 = CONFIG.BORDER,
	LayoutOrder = 3,
	ZIndex = 14
}, infoTab)

create("TextLabel", {
	Size = UDim2.new(0.9, 0, 0, 80),
	BackgroundTransparency = 1,
	Text = "Система движения и оружия в стиле GTA 5 RP.\nВключает инерцию, плавные повороты, систему Redux для графики и автосохранение настроек.",
	TextColor3 = CONFIG.TEXT_SECONDARY,
	TextSize = 13,
	Font = Enum.Font.Gotham,
	TextWrapped = true,
	LayoutOrder = 4,
	ZIndex = 14
}, infoTab)

-- ═══════════════════════════════════════════════════════════════════════════
-- UPDATE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

local function updateTabs()
	for id, btn in pairs(tabButtons) do
		local isActive = State.currentTab == id
		tween(btn, {
			BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY,
			TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_SECONDARY
		}, 0.2)
	end

	graphicsTab.Visible = State.currentTab == "graphics"
	keybindsTab.Visible = State.currentTab == "keybinds"
	infoTab.Visible = State.currentTab == "info"
end

local function updateReduxButtons()
	for id, data in pairs(reduxButtons) do
		local isActive = State.currentRedux == id
		local btn = data.button
		local indicator = data.indicator

		tween(btn, {
			BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY
		}, 0.2)

		tween(indicator, {
			BackgroundColor3 = isActive and CONFIG.SUCCESS or CONFIG.BORDER
		}, 0.2)

		-- Update text colors
		for _, child in ipairs(btn:GetChildren()) do
			if child:IsA("TextLabel") then
				if child.TextSize >= 14 then
					tween(child, {TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_PRIMARY}, 0.2)
				else
					tween(child, {TextColor3 = isActive and Color3.fromRGB(30, 30, 30) or CONFIG.TEXT_MUTED}, 0.2)
				end
			end
		end

		-- Update stroke
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, {
				Color = isActive and CONFIG.ACCENT or CONFIG.BORDER,
				Thickness = isActive and 2 or 1
			}, 0.2)
		end

		-- Update checkmark
		local check = indicator:FindFirstChild("TextLabel")
		if isActive and not check then
			create("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "✓",
				TextColor3 = CONFIG.TEXT_PRIMARY,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				ZIndex = 17
			}, indicator)
		elseif not isActive and check then
			check:Destroy()
		end
	end
end

local function updateMenuVisibility()
	if State.menuOpen then
		menuOverlay.Visible = true
		tween(menuOverlay, {BackgroundTransparency = 0.5}, 0.3)
		menuContainer.Position = UDim2.new(0.5, 0, 0.6, 0)
		menuContainer.Visible = true
		tween(menuContainer, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.35)
	else
		tween(menuOverlay, {BackgroundTransparency = 1}, 0.25)
		local tw = tween(menuContainer, {Position = UDim2.new(0.5, 0, 0.6, 0)}, 0.25)
		tw.Completed:Connect(function()
			if not State.menuOpen then
				menuOverlay.Visible = false
			end
		end)
	end
end

-- Subscribe to state changes
subscribe(function(action)
	if action == "SET_TAB" then
		updateTabs()
	elseif action == "SET_REDUX" then
		updateReduxButtons()
	elseif action == "TOGGLE_MENU" or action == "SET_MENU" then
		updateMenuVisibility()
	end
end)

local function playWhistle()
	local character = player.Character
	if not character or State.isWhistling then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	State.isWhistling = true
	-- Звук
	local sound = Instance.new("Sound")
	sound.SoundId = State.whistleSoundId
	sound.Parent = rootPart
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)

	-- Анимация
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animInstance = Instance.new("Animation")
		animInstance.AnimationId = State.whistleAnimId
		local track = animator:LoadAnimation(animInstance)
		track:Play()
		track.Stopped:Connect(function() 
			State.isWhistling = false 
			animInstance:Destroy()
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WHISTLE LOGIC (HIGH PRIORITY OVERLAY)
-- ═══════════════════════════════════════════════════════════════════════════

local function playWhistle()
	local character = player.Character
	-- Защита от спама: если уже свистим, повторно не запускаем
	if not character or State.isWhistling then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	State.isWhistling = true

	-- Воспроизведение звука свиста из корня персонажа
	local sound = Instance.new("Sound")
	sound.SoundId = State.whistleSoundId
	sound.Volume = 1.0
	sound.Parent = rootPart
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3) -- Автоудаление звука через 3 секунды

	-- Воспроизведение анимации с наивысшим приоритетом наложения
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animInstance = Instance.new("Animation")
		animInstance.AnimationId = State.whistleAnimId

		local track = animator:LoadAnimation(animInstance)
		-- Выставляем наивысший приоритет, чтобы перекрыть анимацию оружия и бега
		track.Priority = Enum.AnimationPriority.Action4 
		track:Play()

		-- Сброс состояния блокировки, когда анимация полностью завершится
		track.Stopped:Connect(function() 
			State.isWhistling = false 
			animInstance:Destroy()
			track:Destroy()
		end)
	else
		-- Сейв-механика на случай, если аниматор отсутствует в персонаже
		State.isWhistling = false
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MOVEMENT MODIFIERS & JUMP COOLDOWN SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

-- Отслеживание прицеливания (Нажатие ПКМ)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		State.isAiming = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		State.isAiming = false
	end
end)

-- Системный цикл обновления характеристик Humanoid
RunService.Stepped:Connect(function()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- 1. Логика замедления при прицеливании
	if State.isAiming then
		humanoid.WalkSpeed = 8 -- Медленная ходьба в прицеле
	else
		humanoid.WalkSpeed = 16 -- Стандартная скорость GTA V RP
	end

	-- 2. Глобальный контроль прыжков через свойства Humanoid
	-- Если кулдаун активен И игрок не находится в состоянии прицеливания, прыгать нельзя
	if (not State.canJumpGlobal and not State.isAiming) or State.isRolling then
		humanoid.JumpPower = 0
	else
		humanoid.JumpPower = 50 -- Базовая стандартная сила прыжка
	end
end)

-- Хук на совершение прыжка персонажем для активации таймера КД
local characterAddedConnection
local function setupJumpTracker(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.Jumping:Connect(function(isActive)
		if isActive and State.canJumpGlobal and not State.isAiming then
			State.canJumpGlobal = false
			task.wait(State.jumpCooldownTime)
			State.canJumpGlobal = true
		end
	end)
end

if player.Character then setupJumpTracker(player.Character) end
player.CharacterAdded:Connect(setupJumpTracker)


-- ═══════════════════════════════════════════════════════════════════════════
-- GENERAL INPUT HANDLING
-- ═══════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == State.binds.toggleMenu then
		dispatch("TOGGLE_MENU")
	elseif input.KeyCode == State.binds.hideHints then
		dispatch("TOGGLE_HINTS")
	elseif input.KeyCode == State.binds.whistle and not State.menuOpen then
		playWhistle()
	elseif input.KeyCode == State.binds.roll and not State.menuOpen and not State.isRolling then
		-- Сюда помещается ваш вызов триггера анимации переката (Combat Roll)
		-- Пример контроля спама:
		-- State.isRolling = true
		-- performRollAnim()
		-- task.wait(1.0)
		-- State.isRolling = false
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Полный запуск инициализации всех систем при старте
task.spawn(function()
	task.wait(0.5)

	-- 1. Безопасно загружаем сохраненные бинды, сенсу и масштабы
	if loadSettings then pcall(loadSettings) end              

	-- 2. Генерируем элементы боковой панели, так как State уже загружен
	if generateHintsUI then pcall(generateHintsUI) end

	-- 3. Выставляем корректную видимость панели подсказок и обновляем текст кнопок
	if updateHintsVisibility then pcall(updateHintsVisibility) end
	if updateHintsLabels then pcall(updateHintsLabels) end     

	-- 4. Нативно применяем чувствительность и масштаб прицела из сохранений
	if updateMouseSensitivity then pcall(updateMouseSensitivity) end
	if updateCrosshairScale then pcall(updateCrosshairScale) end

	-- 5. Применяем сохраненный графический пресет Redux
	local reduxEvent = ReplicatedStorage:FindFirstChild("ReduxEvent")
	if reduxEvent and State and State.currentRedux ~= "Default Redux" then
		reduxEvent:FireServer(State.currentRedux)
	end

	-- 6. Плавная начальная анимация выезда боковой панели при спавне
	if hintsContainer then
		hintsContainer.Position = UDim2.new(1, 50, 0.5, 0)
		task.wait(0.3)
		if State and State.hintsVisible then
			tween(hintsContainer, {Position = UDim2.new(1, -275, 0.5, 0)}, 0.4)
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- GLOBAL API EXPORT (CLEAN MULTILINE)
-- ═══════════════════════════════════════════════════════════════════════════

_G.GTA5_Settings.toggleHints = function()
	if _G.GTA5_InternalDispatch then 
		pcall(_G.GTA5_InternalDispatch, "TOGGLE_HINTS") 
	end
end

_G.GTA5_Settings.setRedux = function(id)
	if _G.GTA5_InternalDispatch then 
		pcall(_G.GTA5_InternalDispatch, "SET_REDUX", id) 
	end
end



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

-- ═══════════════════════════════════════════════════════════════════════════
-- STATE MANAGEMENT (Redux-like)
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
	-- UI State
	menuOpen = false,
	hintsVisible = true,
	currentTab = "graphics",

	-- Graphics Settings
	currentRedux = "Default Redux",
	shadowsEnabled = true,

	-- Keybinds
	keybinds = {
		{key = "M", action = "menu", titleRu = "Меню настроек", titleEn = "Settings Menu"},
		{key = "X", action = "whistle", titleRu = "Свист", titleEn = "Whistle"},
		{key = "Z", action = "shoulder", titleRu = "Смена плеча", titleEn = "Shoulder Swap"},
		{key = "SPACE", action = "roll", titleRu = "Перекат (в бою)", titleEn = "Combat Roll"},
		{key = "SHIFT", action = "sprint", titleRu = "Спринт", titleEn = "Sprint"},
		{key = "ALT", action = "walk", titleRu = "Ходьба", titleEn = "Walk Mode"},
		{key = "U", action = "hints", titleRu = "Скрыть подсказки", titleEn = "Toggle Hints"},
	},

	-- Redux Presets
	reduxPresets = {
		{
			id = "Default Redux",
			name = "Стандарт",
			nameEn = "Default",
			description = "Оригинальная графика игры",
			descEn = "Original game graphics",
			icon = "rbxassetid://7734053495"
		},
		{
			id = "By3d Redux",
			name = "By3d Redux",
			nameEn = "By3d Redux",
			description = "Серая атмосфера без теней",
			descEn = "Gray atmosphere, no shadows",
			icon = "rbxassetid://7734053495"
		},
		{
			id = "SeaCapt Redux",
			name = "SeaCapt Redux", 
			nameEn = "SeaCapt Redux",
			description = "Кастомные настройки",
			descEn = "Custom settings",
			icon = "rbxassetid://7734053495"
		},
	}
}

-- Listeners for state changes
local StateListeners = {}

local function subscribe(callback)
	table.insert(StateListeners, callback)
	return function()
		for i, cb in ipairs(StateListeners) do
			if cb == callback then
				table.remove(StateListeners, i)
				break
			end
		end
	end
end

local function dispatch(action, payload)
	-- Update state based on action
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
	elseif action == "SET_SHADOWS" then
		State.shadowsEnabled = payload
	end

	-- Notify listeners
	for _, callback in ipairs(StateListeners) do
		task.spawn(callback, action, payload)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DATA PERSISTENCE (Auto-save)
-- ═══════════════════════════════════════════════════════════════════════════

local SAVE_KEY = "GTA5_Settings_v1"

local function saveSettings()
	local data = {
		hintsVisible = State.hintsVisible,
		currentRedux = State.currentRedux,
	}

	-- Используем SetAsync через RemoteFunction если есть, иначе локально
	local saveEvent = ReplicatedStorage:FindFirstChild("SaveSettingsEvent")
	if saveEvent then
		saveEvent:FireServer(data)
	else
		-- Локальное сохранение (для тестирования)
		if plugin then
			plugin:SetSetting(SAVE_KEY, data)
		end
	end

	print("[GTA5 Settings] Settings saved")
end

local function loadSettings()
	local loadEvent = ReplicatedStorage:FindFirstChild("LoadSettingsEvent")
	if loadEvent then
		local data = loadEvent:InvokeServer()
		if data then
			State.hintsVisible = data.hintsVisible ~= false
			State.currentRedux = data.currentRedux or "Default Redux"
		end
	end

	print("[GTA5 Settings] Settings loaded")
end

-- Auto-save on state change
local saveDebounce = false
subscribe(function(action)
	if action == "TOGGLE_HINTS" or action == "SET_REDUX" then
		if not saveDebounce then
			saveDebounce = true
			task.delay(1, function()
				saveSettings()
				saveDebounce = false
			end)
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UI UTILITIES
-- ════════════════════════════��══════════════════════════════════════════════

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
-- MAIN UI
-- ═══════════════════════════════════════════════════════════════════════════

local screenGui = create("ScreenGui", {
	Name = "GTA5_SettingsUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 100
}, playerGui)

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

-- Create keybind rows
for i, bind in ipairs(State.keybinds) do
	local row = create("Frame", {
		Name = bind.key .. "Row",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = i
	}, hintsContent)

	-- Key box
	local keyBox = create("Frame", {
		Size = UDim2.new(0, 44, 0, 30),
		Position = UDim2.new(0, 0, 0.5, -15),
		BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
		BorderSizePixel = 0
	}, row)

	create("UICorner", {CornerRadius = UDim.new(0, 4)}, keyBox)
	create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1, Transparency = 0.4}, keyBox)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = bind.key,
		TextColor3 = CONFIG.ACCENT,
		TextSize = bind.key == "SPACE" or bind.key == "SHIFT" and 9 or 15,
		Font = Enum.Font.GothamBold
	}, keyBox)

	-- Text
	create("TextLabel", {
		Size = UDim2.new(1, -54, 0, 18),
		Position = UDim2.new(0, 52, 0, 3),
		BackgroundTransparency = 1,
		Text = bind.titleRu,
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
		Text = bind.titleEn,
		TextColor3 = CONFIG.TEXT_MUTED,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left
	}, row)
end

-- Hints visibility animation
local function updateHintsVisibility()
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
-- GRAPHICS TAB
-- ═══════════════════════════════════════════════════════════════════════════

local graphicsTab = create("ScrollingFrame", {
	Name = "GraphicsTab",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = CONFIG.ACCENT,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 13
}, contentContainer)

create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12)
}, graphicsTab)

-- Section: Redux Presets
local reduxSection = create("Frame", {
	Name = "ReduxSection",
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.Y,
	LayoutOrder = 1,
	ZIndex = 14
}, graphicsTab)

create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8)
}, reduxSection)

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Text = "ГРАФИЧЕСКИЕ ПРЕСЕТЫ / REDUX PRESETS",
	TextColor3 = CONFIG.ACCENT,
	TextSize = 12,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 0,
	ZIndex = 15
}, reduxSection)

local reduxButtons = {}

for i, preset in ipairs(State.reduxPresets) do
	local isActive = State.currentRedux == preset.id

	local presetBtn = create("TextButton", {
		Name = preset.id,
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = isActive and CONFIG.ACCENT or CONFIG.BACKGROUND_SECONDARY,
		Text = "",
		LayoutOrder = i,
		ZIndex = 15
	}, reduxSection)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, presetBtn)
	create("UIStroke", {
		Color = isActive and CONFIG.ACCENT or CONFIG.BORDER,
		Thickness = isActive and 2 or 1
	}, presetBtn)

	-- Content
	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.new(0, 15, 0, 12),
		BackgroundTransparency = 1,
		Text = preset.name,
		TextColor3 = isActive and CONFIG.BACKGROUND or CONFIG.TEXT_PRIMARY,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16
	}, presetBtn)

	create("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 15, 0, 34),
		BackgroundTransparency = 1,
		Text = preset.description,
		TextColor3 = isActive and Color3.fromRGB(30, 30, 30) or CONFIG.TEXT_MUTED,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16
	}, presetBtn)

	-- Active indicator
	local indicator = create("Frame", {
		Name = "Indicator",
		Size = UDim2.new(0, 20, 0, 20),
		Position = UDim2.new(1, -35, 0.5, -10),
		BackgroundColor3 = isActive and CONFIG.SUCCESS or CONFIG.BORDER,
		ZIndex = 16
	}, presetBtn)

	create("UICorner", {CornerRadius = UDim.new(1, 0)}, indicator)

	if isActive then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "✓",
			TextColor3 = CONFIG.TEXT_PRIMARY,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			ZIndex = 17
		}, indicator)
	end

	reduxButtons[preset.id] = {button = presetBtn, indicator = indicator}

	presetBtn.MouseButton1Click:Connect(function()
		dispatch("SET_REDUX", preset.id)

		-- Send to server
		local reduxEvent = ReplicatedStorage:FindFirstChild("ReduxEvent")
		if reduxEvent then
			reduxEvent:FireServer(preset.id)
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS TAB
-- ═══════════════════════════════════════════════════════════════════════════

local keybindsTab = create("ScrollingFrame", {
	Name = "KeybindsTab",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = CONFIG.ACCENT,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Visible = false,
	ZIndex = 13
}, contentContainer)

create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6)
}, keybindsTab)

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

for i, bind in ipairs(State.keybinds) do
	local row = create("Frame", {
		Name = bind.key .. "Bind",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = CONFIG.BACKGROUND_SECONDARY,
		LayoutOrder = i,
		ZIndex = 14
	}, keybindsTab)

	create("UICorner", {CornerRadius = UDim.new(0, 6)}, row)

	-- Key display
	local keyDisplay = create("Frame", {
		Size = UDim2.new(0, 60, 0, 34),
		Position = UDim2.new(0, 10, 0.5, -17),
		BackgroundColor3 = CONFIG.BACKGROUND,
		ZIndex = 15
	}, row)

	create("UICorner", {CornerRadius = UDim.new(0, 4)}, keyDisplay)
	create("UIStroke", {Color = CONFIG.ACCENT, Thickness = 1.5}, keyDisplay)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = bind.key,
		TextColor3 = CONFIG.ACCENT,
		TextSize = (bind.key == "SPACE" or bind.key == "SHIFT" or bind.key == "ALT") and 10 or 16,
		Font = Enum.Font.GothamBold,
		ZIndex = 16
	}, keyDisplay)

	-- Action text
	create("TextLabel", {
		Size = UDim2.new(1, -90, 0, 20),
		Position = UDim2.new(0, 80, 0, 8),
		BackgroundTransparency = 1,
		Text = bind.titleRu,
		TextColor3 = CONFIG.TEXT_PRIMARY,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 15
	}, row)

	create("TextLabel", {
		Size = UDim2.new(1, -90, 0, 16),
		Position = UDim2.new(0, 80, 0, 28),
		BackgroundTransparency = 1,
		Text = bind.titleEn,
		TextColor3 = CONFIG.TEXT_MUTED,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 15
	}, row)
end

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

-- ═══════════════════════════════════════════════════════════════════════════
-- INPUT HANDLING
-- ═══════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == CONFIG.TOGGLE_KEY then
		dispatch("TOGGLE_MENU")
	elseif input.KeyCode == CONFIG.HIDE_HINTS_KEY then
		dispatch("TOGGLE_HINTS")
	end
end)

-- Close menu on overlay click
menuOverlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		local menuPos = menuContainer.AbsolutePosition
		local menuSize = menuContainer.AbsoluteSize

		if mousePos.X < menuPos.X or mousePos.X > menuPos.X + menuSize.X or
			mousePos.Y < menuPos.Y or mousePos.Y > menuPos.Y + menuSize.Y then
			dispatch("SET_MENU", false)
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Load saved settings
task.spawn(function()
	task.wait(0.5)
	loadSettings()
	updateHintsVisibility()
	updateReduxButtons()

	-- Apply saved redux
	local reduxEvent = ReplicatedStorage:FindFirstChild("ReduxEvent")
	if reduxEvent and State.currentRedux ~= "Default Redux" then
		reduxEvent:FireServer(State.currentRedux)
	end
end)

-- Initial hints animation
hintsContainer.Position = UDim2.new(1, 50, 0.5, 0)
task.wait(0.8)
if State.hintsVisible then
	tween(hintsContainer, {Position = UDim2.new(1, -275, 0.5, 0)}, 0.4)
end

-- Export API
_G.GTA5_Settings = {
	getState = function() return State end,
	dispatch = dispatch,
	subscribe = subscribe,
	toggleMenu = function() dispatch("TOGGLE_MENU") end,
	toggleHints = function() dispatch("TOGGLE_HINTS") end,
	setRedux = function(id) dispatch("SET_REDUX", id) end,
}

print("[GTA5 Settings] UI Loaded - Press F1 to open settings")

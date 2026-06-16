local sampev = require "samp.events"
local imgui = require "mimgui"
local keys = require "vkeys"
local ffi = require "ffi"
local jsoncfg = require "jsoncfg"
local fa6 = require "fAwesome6"
local hasRequests, requests = pcall(require, "requests")
if not hasRequests then
    requests = nil
end
local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new
local MONEY_INPUT_MAX = 144000000000

function newMoneyValue(value)
    return new("long long[1]", tonumber(value) or 0)
end

function cp1251(text)
    return text
end

local itemID = 0

local SCRIPT_META = { VERSION = "V9.0", AUTHOR = "Baretti" }
local SCRIPT_VERSION = SCRIPT_META.VERSION
local SCRIPT_AUTHOR = SCRIPT_META.AUTHOR
local UPDATE_MANIFEST_URL = "https://raw.githubusercontent.com/ArendaHelper/ArendaHelper/refs/heads/main/updates.json"
local FORUM_THREAD_URL = "https://www.blast.hk/threads/249837/"
local UPDATE_REQUEST_TIMEOUT = 8
local UPDATE_POPUP_MAX_LINES = 7
local UPDATE_POPUP_WIDTH = 620

local updateState = {
    checked = false,
    checking = false,
    hasUpdate = false,
    popupVisible = false,
    popupAlpha = 0.00,
    popupState = false,
    popupDuration = 0.25,
    popupThread = nil,
    latestVersion = SCRIPT_VERSION,
    changelog = {}
}

local function setUpdatePopupVisible(visible)
    visible = visible == true

    local currentVisible = updateState.popupVisible == true
    local currentAlpha = tonumber(updateState.popupAlpha) or 0.00

    if visible == updateState.popupState then
        if visible and currentVisible and currentAlpha >= 0.999 then
            return false
        end
        if (not visible) and (not currentVisible) and currentAlpha <= 0.001 then
            return false
        end
    end

    if visible then
        updateState.popupVisible = true
    end
    updateState.popupState = visible

    if updateState.popupThread and updateState.popupThread:status() ~= "dead" then
        return true
    end

    updateState.popupThread =
        lua_thread.create(
        function()
            local lastTick = os.clock()

            while true do
                wait(0)

                local now = os.clock()
                local delta = now - lastTick
                if delta < 0.00 then
                    delta = 0.00
                end
                lastTick = now

                local target = updateState.popupState and 1.00 or 0.00
                local duration = tonumber(updateState.popupDuration) or 0.25
                if duration <= 0.00 then
                    duration = 0.01
                end

                local current = tonumber(updateState.popupAlpha) or 0.00
                local step = delta / duration

                if target > current then
                    current = math.min(target, current + step)
                elseif target < current then
                    current = math.max(target, current - step)
                end

                updateState.popupAlpha = current

                if current <= 0.001 and not updateState.popupState then
                    updateState.popupVisible = false
                end

                if (updateState.popupState and current >= 0.999) or ((not updateState.popupState) and current <= 0.001) then
                    break
                end
            end
        end
    )

    return true
end

local function hideUpdatePopupImmediately()
    updateState.popupState = false
    updateState.popupVisible = false
    updateState.popupAlpha = 0.00
end

local function openForumThread()
    if FORUM_THREAD_URL == "" then
        sampAddChatMessage("[АРЕНДА] Ссылка на форум не настроена.", 0xFFFF00)
        return false
    end

    local commands = {
        'cmd /c start "" "' .. FORUM_THREAD_URL .. '"',
        'start "" "' .. FORUM_THREAD_URL .. '"',
        'explorer "' .. FORUM_THREAD_URL .. '"'
    }

    for i = 1, #commands do
        local ok, result = pcall(os.execute, commands[i])
        if ok and (result == true or result == 0 or result == "exit") then
            return true
        end
    end

    sampAddChatMessage("[АРЕНДА] Не удалось открыть ссылку. Откройте вручную: " .. FORUM_THREAD_URL, 0xFFFF00)
    return false
end

local ui = {
    show = new.bool(false),
    showInventoryItemIds = new.bool(false),
    quietMode = new.bool(false),
    daysPid = new.int(0),
    daysCount = new.int(1),
    daysTotal = newMoneyValue(10000),
    daysTotalBuf = new.char[32](),
    hoursPid = new.int(0),
    hoursCount = new.int(1),
    hoursPrice = newMoneyValue(1000),
    hoursPriceBuf = new.char[32](),
    restartPid = new.int(0),
    restartTotal = newMoneyValue(10000),
    restartTotalBuf = new.char[32](),
    maxPid = new.int(0),
    maxTotal = newMoneyValue(10000),
    maxTotalBuf = new.char[32](),
    newItemId = new.int(0),
    newItemNameBuf = new.char[64](),
    newSetNameBuf = new.char[64](),
    newSetItemLimit = 21,
    itemIntMax = MONEY_INPUT_MAX
}

ui.newSetItemCount = 1
ui.newSetItemIds = {}
for i = 1, ui.newSetItemLimit do
    ui.newSetItemIds[i] = new.int(0)
end

local ITEM_UI_DEFAULTS = {
    daysPid = 0,
    daysCount = 1,
    daysTotal = 10000,
    hoursPid = 0,
    hoursCount = 1,
    hoursPrice = 1000,
    restartPid = 0,
    restartTotal = 10000,
    maxPid = 0,
    maxTotal = 10000
}

local SET_UI_DEFAULTS = {
    daysPid = 0,
    daysCount = 1,
    daysTotal = 10000,
    hoursPid = 0,
    hoursCount = 1,
    hoursTotal = 10000,
    restartPid = 0,
    restartTotal = 10000,
    maxPid = 0,
    maxTotal = 10000
}

local uiStyleApplied = false
local THEME_PRESET = {
    CUSTOM = "custom",
    DARK = "dark",
    LIGHT = "light",
    DEFAULT = "custom"
}
local UI_TEXT = {
    THEME_PALETTE_BACKGROUND = "Фон интерфейса",
    THEME_PALETTE_SURFACE = "Элементы интерфейса",
    THEME_PALETTE_ACCENT = "Акцент",
    THEME_PALETTE_BORDER = "Границы",

    THEME_PRESET_DARK = "Dark",
    THEME_PRESET_LIGHT = "Light",
    THEME_PRESET_CUSTOM = "Пользовательская",

    TAB_SETTINGS = "Настройки",
    TAB_STYLES = "Стили",
    TAB_HOURS = "По часам",
    TAB_DAYS = "По дням",
    TAB_RESTART = "До рестарта",
    TAB_MAX = "Максимальный срок",

    POPUP_CREATE_RENT_ID = "Создать аренду##createRentPopup",
    POPUP_CREATE_RENT_MODE_ID = "Создание аренды (тип)##createRentModePopup",
    POPUP_CREATE_RENT_MODE_TITLE = "Выберите тип создания аренды",
    BTN_CREATE_SINGLE_RENT = "Одиночная аренда",
    BTN_CREATE_SET_RENT = "Создание сета",

    CARD_DAYS_TITLE = "Сдача по дням",
    CARD_DAYS_DESC = "Формат: ID игрока + дни + сумма за весь срок",
    INPUT_DAYS_PID = "ID игрока##daysPid",
    BTN_DAYS_NEAREST = "Ближний ID##daysNearest",
    TOOLTIP_NEAREST_ID = "Укажет айди ближайшего игрока",
    TOOLTIP_RENT_PRICE_LIMITS_FMT = "Лимиты цены за 1 час (за каждый предмет):\nРодной сервер: %s$ - %s$ за час\nVice City: %s VC$ - %s VC$ за час\nДля сета лимит применяется к каждому предмету отдельно.",
    INPUT_DAYS_COUNT = "Дней##daysCount",
    INPUT_DAYS_TOTAL = "Сумма за весь срок##daysTotal",
    BTN_RENT_DAYS = "Сдать по дням",

    CARD_HOURS_TITLE = "Сдача по часам",
    CARD_HOURS_DESC = "Формат: ID игрока + часы + цена за час",
    CARD_HOURS_DESC_SET = "Формат: ID игрока + часы + сумма за весь срок",
    INPUT_HOURS_PID = "ID игрока##hoursPid",
    BTN_HOURS_NEAREST = "Ближний ID##hoursNearest",
    INPUT_HOURS_COUNT = "Часов##hoursCount",
    INPUT_HOURS_PRICE = "Цена за час##hoursPrice",
    INPUT_HOURS_SET_TOTAL = "Сумма за весь срок##hoursPrice",
    TEXT_TOTAL_FMT = "Итого: %s",
    TEXT_SET_TOTAL_FMT = "Сумма за весь срок: %s",
    TEXT_SET_PER_ITEM_FMT = "Распределение по сету: %d предмет(ов), примерно %s за предмет",
    TEXT_SET_PER_ITEM_HOURLY_FMT = "За 1 предмет примерно: %s/ч",
    BTN_RENT_HOURS = "Сдать по часам",

    CARD_RESTART_TITLE = "Сдача до рестарта",
    CARD_RESTART_DESC = "Формат: ID игрока + сумма за срок до 05:05 МСК",
    INPUT_RESTART_PID = "ID игрока##restartPid",
    BTN_RESTART_NEAREST = "Ближний ID##restartNearest",
    INPUT_RESTART_TOTAL = "Сумма за весь срок##restartTotal",
    TEXT_RESTART_LEFT_FMT = "До рестарта примерно: %d ч %d мин",
    TEXT_RATE_CALC_FMT = "Расчёт: %s/ч * %d ч = %s",
    BTN_RENT_RESTART = "Сдать до рестарта",

    CARD_MAX_TITLE = "Сдача на максимальный срок",
    CARD_MAX_DESC = "Формат: ID игрока + сумма за весь срок (720 ч)",
    INPUT_MAX_PID = "ID игрока##maxPid",
    BTN_MAX_NEAREST = "Ближний ID##maxNearest",
    INPUT_MAX_TOTAL = "Сумма за весь срок##maxTotal",
    BTN_RENT_MAX = "Сдать на максимальный срок",

    POPUP_RENT_EDIT_TITLE = "Редактирование аренды",
    POPUP_RENT_CREATE_TITLE = "Создание аренды",
    INPUT_ITEM_ID = "ID предмета##newRentItemId",
    INPUT_ITEM_NAME = "Название предмета##newRentItemName",
    POPUP_RENT_SET_CREATE_TITLE = "Создание сета аренды",
    POPUP_RENT_SET_EDIT_TITLE = "Редактирование сета аренды",
    POPUP_CREATE_RENT_SET_ID = "Создание сета##createRentSetPopup",
    INPUT_SET_NAME = "Название сета##newRentSetName",
    INPUT_SET_ITEM_ID_FMT = "##setItemId%d",
    BTN_ADD_SET_ITEM = "Добавить поле",
    BTN_REMOVE_SET_ITEM = "Убрать поле",
    TEXT_SET_IDS_COUNT_FMT = "Лимит предметов: %d/%d",
    TEXT_SET_GRID_FMT = "Сетка: 3 x 7 (Лимит %d шт)",
    BTN_SAVE_SET = "Сохранить сет",
    SETS_LIST_TITLE = "Конфигурация сетов",
    SETS_EMPTY = "Сеты пока не созданы.",
    SET_ROW_FMT = "%s",
    BTN_SAVE_CHANGES = "Сохранить изменения",
    BTN_SAVE = "Сохранить",
    BTN_CANCEL = "Отмена",
    ITEMS_PANEL_TITLE = "Конфигурация сдачи предметов",
    ITEMS_INFO_DATE_FMT = "Сегодня: %d %s %d",
    ITEMS_INFO_TIME_FMT = "%02d:%02d:%02d",
    ITEMS_INFO_RESTART_LEFT_FMT = "До рестарта осталось: %d ч %d мин",
    ITEMS_SECTION_ACCESSORIES = "Аксессуары",
    ITEMS_EMPTY = "Список пуст. Добавьте новый предмет.",
    DRAGDROP_HINT = "Удерживайте и перетаскивайте предмет для смены позиции",
    BTN_CREATE_RENT = "Создать аренду",
    ITEM_ROW_FMT = "%s [ID: %d]##rentItem%d",
    SET_SELECT_ROW_FMT = "%s##rentSet%d",
    TEXT_SELECTED_TARGET_ITEM_FMT = "Активный предмет: %s [ID: %d]",
    TEXT_SELECTED_TARGET_SET_FMT = "Активный сет: %s",

    SET_VIEW_WINDOW_TITLE_FMT = "Состав сета: %s##setViewWindow",
    SET_VIEW_STATUS_UNKNOWN = "Не проверено",
    SET_VIEW_STATUS_FREE = "Свободно",
    SET_VIEW_STATUS_BUSY = "В аренде",
    SET_VIEW_STATUS_MISSING = "Не найдено",
    SET_VIEW_TEXT_EMPTY = "В сете нет валидных ID предметов.",
    SET_VIEW_TEXT_SCANNING_FMT = "Проверка предметов: %d/%d",
    SET_VIEW_TEXT_FREE_COUNT_FMT = "Свободных: %d из %d",
    SET_VIEW_LAST_SCAN_NEVER = "Последняя проверка: ещё не выполнялась",
    SET_VIEW_LAST_SCAN_JUST_NOW = "Последняя проверка: только что",
    SET_VIEW_LAST_SCAN_MINUTES_FMT = "Последняя проверка: %d мин назад",
    SET_VIEW_SCAN_EXPIRED = "Устарел (более 5 минут). Проверьте предметы заново.",
    SET_VIEW_BTN_REFRESH = "Проверить",
    SET_VIEW_BTN_RENT_FREE = "Сдать свободных",

    SETTINGS_ITEM_IDS_TOGGLE = "Узнать ID предметов##settingsShowInventoryIds",
    SETTINGS_ITEM_IDS_HINT = "Показывает номер слота и ID предмета в окне инвентаря.",
    SETTINGS_ITEM_IDS_STATE_ON = "Информация об ID предметов: включена.",
    SETTINGS_ITEM_IDS_STATE_OFF = "Информация об ID предметов: выключена.",
    SETTINGS_QUIET_MODE_TOGGLE = "Тихий режим##settingsQuietMode",
    SETTINGS_QUIET_MODE_HINT = "Скрывает обычные сообщения [АРЕНДА], оставляет запуск, суммы, ошибки и итоги.",
    SETTINGS_QUIET_MODE_STATE_ON = "Тихий режим: включён.",
    SETTINGS_QUIET_MODE_STATE_OFF = "Тихий режим: выключен.",
    THEME_TITLE = "Настройка темы",
    BTN_THEME_CUSTOM = "Пользовательская",
    BTN_THEME_DARK = "Dark",
    BTN_THEME_LIGHT = "Light",
    THEME_CURRENT_FMT = "Текущая тема: %s",
    THEME_HINT_CUSTOM_ONLY = "Для ручной палитры переключитесь на «Пользовательская».",
    THEME_BASE_COLORS = "Базовые цвета",
    BTN_THEME_RESET = "Сбросить пользовательскую палитру",

    MAIN_WINDOW_TITLE_FMT = "Аренда предметов  •  Автор: %s  •  %s",
    MAIN_CONTROL_TITLE = "Управление сдачей предметов",
    STATUS_IDLE = "Статус: ожидание",
    STATUS_CHECKING = "Статус: идёт сканирование (кнопка \"Проверить предметы\")",
    STATUS_AUTO_RENT = "Статус: активна цепочка сдачи",
    BTN_STOP_ACTIVE_MODE = "Остановить активный режим",
    BTN_CHECK_ITEMS = "Проверить предметы",

    MANUAL_MINUTE_TITLE_FMT = "Ручная сдача: %s",
    MANUAL_MINUTE_HINT = "Обнаружен диалог поминутной аренды. Укажите минуты и цену за 1 минуту.",
    MANUAL_MINUTE_WAIT_PRICE = "Сначала нажмите «Продолжить» для отправки минут и открытия диалога цены.",
    MANUAL_MINUTE_WAIT_CURRENCY = "Определение валюты... подождите несколько секунд.",
    MANUAL_MINUTE_INPUT = "Минуты##manualMinuteValue",
    MANUAL_PRICE_INPUT = "Цена за 1 минуту##manualMinutePrice",
    MANUAL_LIMIT_MINUTES_FMT = "Лимит минут: %d - %d",
    MANUAL_LIMIT_PRICE_FMT = "Лимит цены (%s): %s - %s",
    MANUAL_TOTAL_CALC_FMT = "Калькулятор: %d мин * %s = %s",
    BTN_MANUAL_CONTINUE = "Продолжить",
    BTN_MANUAL_STOP = "Остановить процесс"
}

function uiLabel(key)
    local value = UI_TEXT[key]
    if type(value) ~= "string" then
        return u8(tostring(key))
    end
    return u8(value)
end

function uiLabelFmt(key, ...)
    local value = UI_TEXT[key]
    if type(value) ~= "string" then
        value = tostring(key)
    end
    return u8(value:format(...))
end

local THEME_PALETTE_KEYS = {
    "Background",
    "Surface",
    "Accent",
    "Border"
}

local THEME_PALETTE_LABELS = {
    Background = "THEME_PALETTE_BACKGROUND",
    Surface = "THEME_PALETTE_SURFACE",
    Accent = "THEME_PALETTE_ACCENT",
    Border = "THEME_PALETTE_BORDER"
}

local THEME_DEFAULT_PALETTE = {
    Background = {13 / 255, 20 / 255, 28 / 255, 1.00},
    Surface = {0.14, 0.18, 0.24, 0.92},
    Accent = {0.15, 0.46, 0.72, 1.00},
    Border = {0.22, 0.29, 0.38, 0.70}
}

local uiTheme = {
    preset = THEME_PRESET.DEFAULT,
    palette = {}
}

function clampThemeChannel(value, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value > 1.00 and value <= 255.00 then
        value = value / 255.00
    end

    if value < 0.00 then
        return 0.00
    end

    if value > 1.00 then
        return 1.00
    end

    return value
end

function clamp01(value)
    if value < 0.00 then
        return 0.00
    end
    if value > 1.00 then
        return 1.00
    end
    return value
end

for i = 1, #THEME_PALETTE_KEYS do
    local key = THEME_PALETTE_KEYS[i]
    local c = THEME_DEFAULT_PALETTE[key]
    uiTheme.palette[key] = new.float[4](c[1], c[2], c[3], c[4])
end

function normalizeThemePreset(value)
    value = tostring(value or ""):lower()
    if value == THEME_PRESET.DARK or value == THEME_PRESET.LIGHT then
        return value
    end
    if value == "classic" then
        return THEME_PRESET.DARK
    end
    return THEME_PRESET.CUSTOM
end

function resetThemeCustomColors()
    for i = 1, #THEME_PALETTE_KEYS do
        local key = THEME_PALETTE_KEYS[i]
        local c = THEME_DEFAULT_PALETTE[key]
        local dst = uiTheme.palette[key]
        dst[0] = c[1]
        dst[1] = c[2]
        dst[2] = c[3]
        dst[3] = c[4]
    end
end

function loadThemeFromData(themeData)
    if type(themeData) ~= "table" then
        return
    end

    uiTheme.preset = normalizeThemePreset(themeData.preset)

    local paletteData = themeData.palette
    if type(paletteData) ~= "table" and type(themeData.colors) == "table" then
        local old = themeData.colors
        paletteData = {
            Background = old.WindowBg or old.ChildBg,
            Surface = old.FrameBg or old.Tab or old.Header,
            Accent = old.Button or old.TabActive or old.CheckMark,
            Border = old.Border
        }
    end

    if type(paletteData) ~= "table" then
        return
    end

    for i = 1, #THEME_PALETTE_KEYS do
        local key = THEME_PALETTE_KEYS[i]
        local src = paletteData[key]
        if type(src) == "table" then
            local dst = uiTheme.palette[key]
            dst[0] = clampThemeChannel(src[1], dst[0])
            dst[1] = clampThemeChannel(src[2], dst[1])
            dst[2] = clampThemeChannel(src[3], dst[2])
            dst[3] = clampThemeChannel(src[4], dst[3])
        end
    end
end

function serializeThemeToData()
    local palette = {}
    for i = 1, #THEME_PALETTE_KEYS do
        local key = THEME_PALETTE_KEYS[i]
        local src = uiTheme.palette[key]
        palette[key] = {src[0], src[1], src[2], src[3]}
    end

    return {
        preset = normalizeThemePreset(uiTheme.preset),
        palette = palette
    }
end

function applyUiShapeStyle(style)
    style.WindowRounding = 12
    style.ChildRounding = 10
    style.FrameRounding = 8
    style.GrabRounding = 8
    style.ScrollbarRounding = 10
    style.TabRounding = 8
    style.WindowPadding = imgui.ImVec2(14, 14)
    style.FramePadding = imgui.ImVec2(10, 7)
    style.ItemSpacing = imgui.ImVec2(10, 8)
    style.SelectableTextAlign = imgui.ImVec2(0.50, 0.50)
end

function makeColor(r, g, b, a)
    return {clamp01(r), clamp01(g), clamp01(b), clamp01(a or 1.00)}
end

function getColorChannel(src, idx, fallback)
    local value = nil
    if src ~= nil then
        value = src[idx]
        if value == nil then
            value = src[idx + 1]
        end
    end

    value = tonumber(value)
    if not value then
        return fallback or 0.00
    end

    return value
end

function colorFromSource(src, alphaOverride)
    return makeColor(
        getColorChannel(src, 0, 0.00),
        getColorChannel(src, 1, 0.00),
        getColorChannel(src, 2, 0.00),
        alphaOverride or getColorChannel(src, 3, 1.00)
    )
end

function mulColor(src, factor, alpha)
    return makeColor(
        getColorChannel(src, 0, 0.00) * factor,
        getColorChannel(src, 1, 0.00) * factor,
        getColorChannel(src, 2, 0.00) * factor,
        alpha or getColorChannel(src, 3, 1.00)
    )
end

function mixColor(a, b, t, alpha)
    local a0 = getColorChannel(a, 0, 0.00)
    local a1 = getColorChannel(a, 1, 0.00)
    local a2 = getColorChannel(a, 2, 0.00)
    local a3 = getColorChannel(a, 3, 1.00)

    local b0 = getColorChannel(b, 0, 0.00)
    local b1 = getColorChannel(b, 1, 0.00)
    local b2 = getColorChannel(b, 2, 0.00)
    local b3 = getColorChannel(b, 3, 1.00)

    return makeColor(
        a0 + (b0 - a0) * t,
        a1 + (b1 - a1) * t,
        a2 + (b2 - a2) * t,
        alpha or (a3 + (b3 - a3) * t)
    )
end

function setStyleColor(colors, idx, c)
    colors[idx] = imgui.ImVec4(c[1], c[2], c[3], c[4])
end

function applyThemeCustomColors(style)
    local colors = style.Colors

    local bg = uiTheme.palette.Background
    local surface = uiTheme.palette.Surface
    local accent = uiTheme.palette.Accent
    local border = uiTheme.palette.Border

    local titleBg = mixColor(mulColor(bg, 0.82, 1.00), surface, 0.20, 1.00)
    local titleBgActive = mixColor(surface, accent, 0.22, 1.00)

    local frameBg = mulColor(surface, 1.00, 0.88)
    local frameBgHovered = mixColor(surface, accent, 0.12, 0.95)
    local frameBgActive = mixColor(surface, accent, 0.22, 1.00)

    local button = mulColor(accent, 1.00, 0.95)
    local buttonHovered = mulColor(accent, 1.14, 1.00)
    local buttonActive = mulColor(accent, 0.86, 1.00)

    local tab = mulColor(surface, 0.96, 0.95)
    local tabHovered = mixColor(surface, accent, 0.12, 1.00)
    local tabActive = mixColor(surface, accent, 0.26, 1.00)

    local header = mulColor(surface, 0.90, 0.92)
    local headerHovered = mixColor(surface, accent, 0.14, 1.00)
    local headerActive = mixColor(surface, accent, 0.22, 1.00)

    local checkMark = mulColor(accent, 1.26, 1.00)
    local borderColor = colorFromSource(border)

    setStyleColor(colors, imgui.Col.WindowBg, colorFromSource(bg, 1.00))
    setStyleColor(colors, imgui.Col.ChildBg, colorFromSource(bg, 1.00))
    setStyleColor(colors, imgui.Col.TitleBg, titleBg)
    setStyleColor(colors, imgui.Col.TitleBgActive, titleBgActive)
    setStyleColor(colors, imgui.Col.Border, borderColor)

    setStyleColor(colors, imgui.Col.FrameBg, frameBg)
    setStyleColor(colors, imgui.Col.FrameBgHovered, frameBgHovered)
    setStyleColor(colors, imgui.Col.FrameBgActive, frameBgActive)

    setStyleColor(colors, imgui.Col.Button, button)
    setStyleColor(colors, imgui.Col.ButtonHovered, buttonHovered)
    setStyleColor(colors, imgui.Col.ButtonActive, buttonActive)

    setStyleColor(colors, imgui.Col.Tab, tab)
    setStyleColor(colors, imgui.Col.TabHovered, tabHovered)
    setStyleColor(colors, imgui.Col.TabActive, tabActive)

    setStyleColor(colors, imgui.Col.CheckMark, checkMark)

    setStyleColor(colors, imgui.Col.Header, header)
    setStyleColor(colors, imgui.Col.HeaderHovered, headerHovered)
    setStyleColor(colors, imgui.Col.HeaderActive, headerActive)
end
function applyUiThemePreset(preset)
    preset = normalizeThemePreset(preset)
    local style = imgui.GetStyle()

    if preset == THEME_PRESET.LIGHT then
        imgui.StyleColorsLight(style)
    else
        imgui.StyleColorsDark(style)
    end

    applyUiShapeStyle(style)

    if preset == THEME_PRESET.CUSTOM then
        applyThemeCustomColors(style)
    end

    uiTheme.preset = preset
    uiStyleApplied = true
end

function setUiThemePreset(preset)
    preset = normalizeThemePreset(preset)
    if uiTheme.preset == preset and uiStyleApplied then
        return false
    end
    applyUiThemePreset(preset)
    return true
end

function getUiThemePresetText(preset)
    preset = normalizeThemePreset(preset)
    if preset == THEME_PRESET.DARK then
        return UI_TEXT.THEME_PRESET_DARK
    end
    if preset == THEME_PRESET.LIGHT then
        return UI_TEXT.THEME_PRESET_LIGHT
    end
    return UI_TEXT.THEME_PRESET_CUSTOM
end
local ITEMS_CONFIG_DIR = getWorkingDirectory() .. "\\Arenda Helper"
local ITEMS_CONFIG_PATH = ITEMS_CONFIG_DIR .. "\\arenda_items.json"
local LOGO_IMAGE_PATH = ITEMS_CONFIG_DIR .. "\\logo.png"
local LOGO_IMAGE_ASPECT = 1400 / 420
local LOGO_IMAGE_MAX_WIDTH = 286

function ensureItemsConfigDir()
    if not doesDirectoryExist(ITEMS_CONFIG_DIR) then
        createDirectory(ITEMS_CONFIG_DIR)
    end
end

function ensureLogoFileOrFail()
    ensureItemsConfigDir()

    if doesFileExist(LOGO_IMAGE_PATH) then
        return true
    end

    local err = string.format("[ARENDA][ERROR] Required logo file not found: %s", LOGO_IMAGE_PATH)
    print(err)
    error(err)
end
local logoTexture = nil
local logoLoadFailed = false

function tryLoadLogoTexture()
    if logoTexture or logoLoadFailed then
        return
    end

    ensureItemsConfigDir()

    if not doesFileExist(LOGO_IMAGE_PATH) then
        return
    end

    local ok, tex = pcall(imgui.CreateTextureFromFile, LOGO_IMAGE_PATH)
    if ok and tex then
        logoTexture = tex
        return
    end

    logoLoadFailed = true
    sampAddChatMessage("[АРЕНДА] Не удалось загрузить logo.png из папки Arenda Helper.", 0xFFFF00)
end

local rentItems = {}
rentSets = {}
pendingCreateRentPopup = nil
local selectedRentItemIndex = 0
local selectedRentSetIndex = 0
local selectedRentTargetType = "item"
local rentItemEditorIndex = 0
rentSetEditorIndex = 0
local fa6FontMerged = false
local activeRentModeTab = "hours"
local showSetViewWindow = new.bool(false)
local SET_VIEW_WINDOW_SIZE = imgui.ImVec2(370, 427)
local SET_VIEW_WINDOW_DEFAULT_POS = {x = 68, y = 574}
local setViewWindowPos = {
    x = SET_VIEW_WINDOW_DEFAULT_POS.x,
    y = SET_VIEW_WINDOW_DEFAULT_POS.y
}
local setViewWindowPosSavePending = false
local setViewWindowPosChangedAt = 0
local setViewWindowMenu = nil
local setViewWindowCloseHandled = true
local SET_VIEW_SCAN_FRESH_SECONDS = 5 * 60
local SET_VIEW_STATUS = {
    UNKNOWN = "unknown",
    FREE = "free",
    BUSY = "busy",
    MISSING = "missing"
}
local setViewWindowState = {
    setIndex = 0,
    setName = "",
    itemIds = {},
    statusByItemId = {},
    rentUntilByItemId = {},
    freeItemIds = {},
    lastScanAt = 0,
    scanning = false,
    cursor = 0
}
local ICONS = {
    EDIT = fa6.PEN_TO_SQUARE or fa6.PEN or "E",
    VIEW = fa6.EYE or "V",
    DELETE = fa6.TRASH_CAN or fa6.TRASH or "X",
    SETTINGS = fa6.GEAR or fa6.SLIDERS or fa6.WRENCH or "S",
    STYLES = fa6.PALETTE or fa6.PAINTBRUSH or fa6.BRUSH or "S",
    TAB_HOURS = fa6.CLOCK or fa6.STOPWATCH or fa6.HOURGLASS or "H",
    TAB_DAYS = fa6.CALENDAR_DAYS or fa6.CALENDAR_DAY or fa6.CALENDAR or "D",
    TAB_RESTART = fa6.CLOCK_ROTATE_LEFT or fa6.ARROW_ROTATE_LEFT or fa6.ARROWS_ROTATE or "R",
    TAB_MAX = fa6.INFINITY or fa6.HOURGLASS_END or fa6.BOLT or "M",
    SET_ADD = fa6.CIRCLE_PLUS or fa6.SQUARE_PLUS or fa6.PLUS or "+",
    SET_REMOVE = fa6.CIRCLE_MINUS or fa6.SQUARE_MINUS or fa6.MINUS or "-",
    MANUAL_CONTINUE = fa6.CIRCLE_CHECK or fa6.CHECK or fa6.PLAY or ">",
    MANUAL_STOP = fa6.CIRCLE_STOP or fa6.BAN or fa6.XMARK or "X",
    MODE_SINGLE = fa6.CUBE or fa6.BOX or "S",
    MODE_SET = fa6.LAYER_GROUP or fa6.CUBES or "T",
    INFO_DATE = fa6.CALENDAR_DAY or fa6.CALENDAR_DAYS or fa6.CALENDAR or "D",
    INFO_TIME = fa6.CLOCK or fa6.STOPWATCH or "T",
    INFO_RESTART = fa6.HOURGLASS_HALF or fa6.HOURGLASS_END or fa6.HOURGLASS or "R",
    TEXT_DISTRIBUTION = fa6.LAYER_GROUP or fa6.CUBES or fa6.BOXES_STACKED or "S",
    TEXT_PER_ITEM_RATE = fa6.CLOCK or fa6.STOPWATCH or fa6.HOURGLASS_HALF or "H",
    TEXT_RATE_CALC = fa6.CALCULATOR or fa6.GEAR or fa6.SLIDERS or "C",
    TEXT_TOTAL = fa6.COINS or fa6.MONEY_BILL or fa6.MONEY_BILL_WAVE or "$",
    TITLE = fa6.BOX_OPEN or fa6.BOX or fa6.CUBE or fa6.CUBES or "A",
    UPDATE = fa6.CLOUD_ARROW_DOWN or fa6.CIRCLE_UP or fa6.DOWNLOAD or "U",
    CHANGELOG = fa6.LIST_CHECK or fa6.CLIPBOARD_LIST or fa6.LIST or "N",
    CHANGELOG_ITEM = fa6.CIRCLE_CHECK or fa6.CHECK or "-",
    DOWNLOAD = fa6.DOWNLOAD or fa6.CLOUD_ARROW_DOWN or "D",
    CLOSE = fa6.XMARK or fa6.CIRCLE_XMARK or "X",
    VERSION = fa6.CODE_BRANCH or fa6.TAG or "V"
}
local TAB_LABELS = {
    SETTINGS = tostring(ICONS.SETTINGS) .. " " .. uiLabel("TAB_SETTINGS") .. "##tab_settings",
    STYLES = tostring(ICONS.STYLES) .. " " .. uiLabel("TAB_STYLES") .. "##tab_styles",
    HOURS = tostring(ICONS.TAB_HOURS) .. " " .. uiLabel("TAB_HOURS") .. "##tab_hours",
    DAYS = tostring(ICONS.TAB_DAYS) .. " " .. uiLabel("TAB_DAYS") .. "##tab_days",
    RESTART = tostring(ICONS.TAB_RESTART) .. " " .. uiLabel("TAB_RESTART") .. "##tab_restart",
    MAX = tostring(ICONS.TAB_MAX) .. " " .. uiLabel("TAB_MAX") .. "##tab_max"
}

function getMainWindowTitle()
    return tostring(ICONS.TITLE) .. "  " .. uiLabelFmt("MAIN_WINDOW_TITLE_FMT", SCRIPT_AUTHOR, SCRIPT_VERSION)
end
ui.msgEmptyItems = cp1251("Список предметов пуст. Добавьте предмет через /arenda.")
ui.msgEmptySets = cp1251("Список сетов пуст. Создайте сет через /arenda.")
local normalizeRentItemUiState
local ensureRentItemUiState
local normalizeRentSetUiState
local ensureRentSetUiState
local syncUiToSelectedRentItem
local syncUiToSelectedRentSet
local syncUiToSelectedRentTarget
local loadUiFromSelectedRentItem
local loadUiFromSelectedRentSet
local loadUiFromSelectedRentTarget
local formatNumberDots

function utf8ToCp1251Safe(text)
    if type(text) ~= "string" then
        return ""
    end
    local ok, decoded = pcall(u8.decode, u8, text)
    if ok and type(decoded) == "string" then
        return decoded
    end
    return text
end

function cp1251ToUtf8Safe(text)
    if type(text) ~= "string" then
        return ""
    end
    local ok, encoded =
        pcall(
        function()
            return u8(text)
        end
    )
    if ok and type(encoded) == "string" then
        return encoded
    end
    return text
end

function normalizeSetViewWindowPos(pos)
    local x = SET_VIEW_WINDOW_DEFAULT_POS.x
    local y = SET_VIEW_WINDOW_DEFAULT_POS.y

    if type(pos) == "table" then
        local parsedX = tonumber(pos.x)
        local parsedY = tonumber(pos.y)

        if parsedX and parsedX == parsedX then
            x = parsedX
        end

        if parsedY and parsedY == parsedY then
            y = parsedY
        end
    end

    return {
        x = x,
        y = y
    }
end

function saveRentItemsToJson()
    ensureItemsConfigDir()

    if syncUiToSelectedRentTarget then
        syncUiToSelectedRentTarget()
    elseif syncUiToSelectedRentItem then
        syncUiToSelectedRentItem()
    end

    local selectedItemId = 0
    if selectedRentItemIndex >= 1 and selectedRentItemIndex <= #rentItems then
        selectedItemId = tonumber(rentItems[selectedRentItemIndex].id) or 0
    end

    local data = {
        selectedItemId = selectedItemId,
        selectedSetIndex = selectedRentSetIndex,
        selectedTargetType = selectedRentTargetType,
        items = {},
        sets = {},
        theme = serializeThemeToData(),
        setViewWindowPos = normalizeSetViewWindowPos(setViewWindowPos),
        settings = {
            showInventoryItemIds = ui.showInventoryItemIds[0] == true,
            quietMode = ui.quietMode[0] == true
        }
    }

    for i = 1, #rentItems do
        local id = tonumber(rentItems[i].id)
        if id and id >= 1 and id == math.floor(id) then
            local uiState = normalizeRentItemUiState(rentItems[i].ui)
            rentItems[i].ui = uiState
            table.insert(
                data.items,
                {
                    id = id,
                    name = cp1251ToUtf8Safe(tostring(rentItems[i].name or "")),
                    ui = uiState
                }
            )
        end
    end

    for i = 1, #rentSets do
        local set = rentSets[i]
        if type(set) == "table" then
            local setName = cp1251ToUtf8Safe(tostring(set.name or ""))
            local setIds = {}
            if type(set.itemIds) == "table" then
                for j = 1, #set.itemIds do
                    local id = tonumber(set.itemIds[j])
                    if id and id >= 1 and id == math.floor(id) then
                        table.insert(setIds, id)
                    end
                end
            end
            if #setIds > 0 then
                local uiState = normalizeRentSetUiState(set.ui)
                set.ui = uiState
                table.insert(
                    data.sets,
                    {
                        name = setName,
                        itemIds = setIds,
                        ui = uiState,
                        scanCache = serializeSetScanCache(set.scanCache, setIds)
                    }
                )
            end
        end
    end

    jsoncfg.write(ITEMS_CONFIG_PATH, data)
end

function loadRentItemsFromJson()
    ensureItemsConfigDir()
    local data = jsoncfg.read(ITEMS_CONFIG_PATH)
    if type(data) ~= "table" then
        return
    end

    loadThemeFromData(data.theme)

    setViewWindowPos = normalizeSetViewWindowPos(data.setViewWindowPos)
    setViewWindowPosSavePending = false
    setViewWindowPosChangedAt = 0

    local settingsData = data.settings
    if type(settingsData) ~= "table" then
        settingsData = {}
    end
    setInventoryItemIdsEnabled(settingsData.showInventoryItemIds == true, true, true)
    setQuietModeEnabled(settingsData.quietMode == true, true, true)

    if type(data.items) ~= "table" then
        data.items = {}
    end

    local loaded = {}
    for i = 1, #data.items do
        local it = data.items[i]
        if type(it) == "table" then
            local id = tonumber(it.id)
            if id and id >= 1 and id == math.floor(id) then
                local name = utf8ToCp1251Safe(tostring(it.name or ""))
                if name == "" then
                    name = cp1251("Предмет ") .. tostring(id)
                end
                table.insert(
                    loaded,
                    {
                        id = id,
                        name = name,
                        ui = normalizeRentItemUiState(it.ui)
                    }
                )
            end
        end
    end

    rentItems = loaded

    local loadedSets = {}
    if type(data.sets) == "table" then
        for i = 1, #data.sets do
            local set = data.sets[i]
            if type(set) == "table" then
                local setName = utf8ToCp1251Safe(tostring(set.name or ""))
                setName = setName:gsub("^%s+", ""):gsub("%s+$", "")
                if setName == "" then
                    setName = cp1251("Сет ") .. tostring(i)
                end

                local setIds = {}
                if type(set.itemIds) == "table" then
                    for j = 1, #set.itemIds do
                        local id = tonumber(set.itemIds[j])
                        if id and id >= 1 and id == math.floor(id) then
                            table.insert(setIds, id)
                        end
                    end
                end

                if #setIds > 0 then
                    table.insert(
                        loadedSets,
                        {
                            name = setName,
                            itemIds = setIds,
                            ui = normalizeRentSetUiState(set.ui),
                            scanCache = normalizeSetScanCache(set.scanCache, setIds)
                        }
                    )
                end
            end
        end
    end
    rentSets = loadedSets

    local selectedId = tonumber(data.selectedItemId)
    local selectedIndex = (#rentItems > 0) and 1 or 0

    if selectedId and #rentItems > 0 then
        for i = 1, #rentItems do
            if tonumber(rentItems[i].id) == selectedId then
                selectedIndex = i
                break
            end
        end
    end

    selectedRentItemIndex = selectedIndex

    local loadedSetIndex = tonumber(data.selectedSetIndex)
    if loadedSetIndex and loadedSetIndex >= 1 and loadedSetIndex <= #rentSets then
        selectedRentSetIndex = math.floor(loadedSetIndex)
    elseif #rentSets > 0 then
        selectedRentSetIndex = 1
    else
        selectedRentSetIndex = 0
    end

    if selectedRentItemIndex > 0 then
        itemID = tonumber(rentItems[selectedRentItemIndex].id) or 0
    else
        itemID = 0
    end

    local savedTargetType = tostring(data.selectedTargetType or "item")
    if savedTargetType == "set" and selectedRentSetIndex > 0 then
        selectedRentTargetType = "set"
    else
        selectedRentTargetType = "item"
    end

    if selectedRentTargetType == "item" and selectedRentItemIndex <= 0 and selectedRentSetIndex > 0 then
        selectedRentTargetType = "set"
    end

    if loadUiFromSelectedRentTarget then
        loadUiFromSelectedRentTarget()
    elseif loadUiFromSelectedRentItem then
        loadUiFromSelectedRentItem()
    end
end
local LIMITS = {
    pidMin = 0,
    pidMax = 999,
    daysMin = 1,
    daysMax = 30,
    hoursMin = 1,
    hoursMax = 720
}

local DIALOG_ID_RENT_TARGET = 25669
local DIALOG_ID_RENT_HOURS = 25670
local DIALOG_ID_RENT_PRICE = 25671
local DIALOG_ID_RENT_CONFIRM = 25672
local DIALOG_ID_RENT_INFO = 0
local DIALOG_TITLE_RENT_INFO = cp1251("Информация об аренде")
local RENT_MODE_LABEL_DAYS = cp1251("Сдача по дням")
local RENT_MODE_LABEL_HOURS = cp1251("Сдача по часам")
local RENT_MODE_LABEL_RESTART = cp1251("Сдача до рестарта")
local RENT_MODE_LABEL_MAX = cp1251("Сдача на максимальный срок")
local RENT_MODE_LABEL_UNKNOWN = cp1251("сдача")
local FMT_MODE_STARTED = cp1251("[АРЕНДА] Запущено: %s.")
local FMT_MODE_STARTED_HOURS = cp1251("[АРЕНДА] Запущено: %s | %s: %d ч (срок) | %s/ч | Итого %s")
local FMT_MODE_STARTED_RESTART = cp1251("[АРЕНДА] Запущено: %s -> до рестарта (05:05 МСК): %d ч %d мин (срок до рестарта)")
local FMT_MODE_STARTED_MAX = cp1251("[АРЕНДА] Запущено: %s -> %d ч (фиксированный срок)")
local FMT_UNEXPECTED_DIALOG_MODE = cp1251("Неожиданный диалог в режиме \"%s\" (ID: %d). Остановлено.")

local NEARBY_PLAYER_MAX_DISTANCE = 2.0

local RESTART_MSK_HOUR = 5
local RESTART_MSK_MIN = 5
local MSK_OFFSET_HOURS = 3
local ROUND_UP_FROM_MIN = 30
local MSK_MONTH_NAMES = {
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря"
}

local function calcSecondsToRestart()
    local utc = os.date("!*t")

    local restartUtcHour = RESTART_MSK_HOUR - MSK_OFFSET_HOURS
    if restartUtcHour < 0 then
        restartUtcHour = restartUtcHour + 24
    end

    local nowSec = utc.hour * 3600 + utc.min * 60 + utc.sec
    local restartSec = restartUtcHour * 3600 + RESTART_MSK_MIN * 60

    local diff = restartSec - nowSec
    if diff <= 0 then
        diff = diff + 86400
    end

    return diff, utc
end

function calcHoursToRestart()
    local diff, utc = calcSecondsToRestart()

    local totalMin = math.floor(diff / 60)
    local hours = math.floor(totalMin / 60)
    local mins = totalMin % 60

    if utc.min >= ROUND_UP_FROM_MIN then
        hours = hours + 1
    end

    if hours < 1 then
        hours = 1
    end
    if hours > LIMITS.hoursMax then
        hours = LIMITS.hoursMax
    end

    return hours, mins
end

function calcExactTimeToRestart()
    local diff = calcSecondsToRestart()
    local hours = math.floor(diff / 3600)
    local mins = math.floor((diff % 3600) / 60)
    return hours, mins
end

function getLocalDateTimeNow()
    local now = os.date("*t")
    local monthName = MSK_MONTH_NAMES[now.month] or tostring(now.month)
    return now.day, monthName, now.year, now.hour, now.min, now.sec
end

function isIntInRange(v, min, max)
    return type(v) == "number" and v == math.floor(v) and v >= min and v <= max
end

function hasRentItems()
    return #rentItems > 0 and selectedRentItemIndex >= 1 and selectedRentItemIndex <= #rentItems and
        tonumber(rentItems[selectedRentItemIndex].id) ~= nil
end

function hasRentSets()
    return #rentSets > 0 and selectedRentSetIndex >= 1 and selectedRentSetIndex <= #rentSets and
        type(rentSets[selectedRentSetIndex]) == "table"
end

function isSetConfigSelected()
    return selectedRentTargetType == "set" and hasRentSets()
end

function clampRentItemUiValue(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    value = math.floor(value)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function createDefaultRentItemUiState()
    return {
        daysPid = ITEM_UI_DEFAULTS.daysPid,
        daysCount = ITEM_UI_DEFAULTS.daysCount,
        daysTotal = ITEM_UI_DEFAULTS.daysTotal,
        hoursPid = ITEM_UI_DEFAULTS.hoursPid,
        hoursCount = ITEM_UI_DEFAULTS.hoursCount,
        hoursPrice = ITEM_UI_DEFAULTS.hoursPrice,
        restartPid = ITEM_UI_DEFAULTS.restartPid,
        restartTotal = ITEM_UI_DEFAULTS.restartTotal,
        maxPid = ITEM_UI_DEFAULTS.maxPid,
        maxTotal = ITEM_UI_DEFAULTS.maxTotal
    }
end

function createDefaultRentSetUiState()
    return {
        daysPid = SET_UI_DEFAULTS.daysPid,
        daysCount = SET_UI_DEFAULTS.daysCount,
        daysTotal = SET_UI_DEFAULTS.daysTotal,
        hoursPid = SET_UI_DEFAULTS.hoursPid,
        hoursCount = SET_UI_DEFAULTS.hoursCount,
        hoursTotal = SET_UI_DEFAULTS.hoursTotal,
        restartPid = SET_UI_DEFAULTS.restartPid,
        restartTotal = SET_UI_DEFAULTS.restartTotal,
        maxPid = SET_UI_DEFAULTS.maxPid,
        maxTotal = SET_UI_DEFAULTS.maxTotal
    }
end

normalizeRentItemUiState = function(state)
    local normalized = createDefaultRentItemUiState()
    if type(state) ~= "table" then
        return normalized
    end

    normalized.daysPid = clampRentItemUiValue(state.daysPid, LIMITS.pidMin, LIMITS.pidMax, normalized.daysPid)
    normalized.daysCount = clampRentItemUiValue(state.daysCount, LIMITS.daysMin, LIMITS.daysMax, normalized.daysCount)
    normalized.daysTotal = clampRentItemUiValue(state.daysTotal, 1, ui.itemIntMax, normalized.daysTotal)
    normalized.hoursPid = clampRentItemUiValue(state.hoursPid, LIMITS.pidMin, LIMITS.pidMax, normalized.hoursPid)
    normalized.hoursCount =
        clampRentItemUiValue(state.hoursCount, LIMITS.hoursMin, LIMITS.hoursMax, normalized.hoursCount)
    normalized.hoursPrice = clampRentItemUiValue(state.hoursPrice, 1, ui.itemIntMax, normalized.hoursPrice)
    normalized.restartPid = clampRentItemUiValue(state.restartPid, LIMITS.pidMin, LIMITS.pidMax, normalized.restartPid)
    normalized.restartTotal = clampRentItemUiValue(state.restartTotal, 1, ui.itemIntMax, normalized.restartTotal)
    normalized.maxPid = clampRentItemUiValue(state.maxPid, LIMITS.pidMin, LIMITS.pidMax, normalized.maxPid)
    normalized.maxTotal = clampRentItemUiValue(state.maxTotal, 1, ui.itemIntMax, normalized.maxTotal)

    return normalized
end

normalizeRentSetUiState = function(state)
    local normalized = createDefaultRentSetUiState()
    if type(state) ~= "table" then
        return normalized
    end

    normalized.daysPid = clampRentItemUiValue(state.daysPid, LIMITS.pidMin, LIMITS.pidMax, normalized.daysPid)
    normalized.daysCount = clampRentItemUiValue(state.daysCount, LIMITS.daysMin, LIMITS.daysMax, normalized.daysCount)
    normalized.daysTotal = clampRentItemUiValue(state.daysTotal, 1, ui.itemIntMax, normalized.daysTotal)
    normalized.hoursPid = clampRentItemUiValue(state.hoursPid, LIMITS.pidMin, LIMITS.pidMax, normalized.hoursPid)
    normalized.hoursCount =
        clampRentItemUiValue(state.hoursCount, LIMITS.hoursMin, LIMITS.hoursMax, normalized.hoursCount)
    normalized.hoursTotal = clampRentItemUiValue(state.hoursTotal, 1, ui.itemIntMax, normalized.hoursTotal)
    normalized.restartPid = clampRentItemUiValue(state.restartPid, LIMITS.pidMin, LIMITS.pidMax, normalized.restartPid)
    normalized.restartTotal = clampRentItemUiValue(state.restartTotal, 1, ui.itemIntMax, normalized.restartTotal)
    normalized.maxPid = clampRentItemUiValue(state.maxPid, LIMITS.pidMin, LIMITS.pidMax, normalized.maxPid)
    normalized.maxTotal = clampRentItemUiValue(state.maxTotal, 1, ui.itemIntMax, normalized.maxTotal)

    return normalized
end

function getSelectedRentItem()
    if not hasRentItems() then
        return nil
    end
    return rentItems[selectedRentItemIndex]
end

function getSelectedRentSet()
    if not hasRentSets() then
        return nil
    end
    return rentSets[selectedRentSetIndex]
end

ensureRentItemUiState = function(item)
    if type(item) ~= "table" then
        return nil
    end

    item.ui = normalizeRentItemUiState(item.ui)
    return item.ui
end

ensureRentSetUiState = function(set)
    if type(set) ~= "table" then
        return nil
    end

    set.ui = normalizeRentSetUiState(set.ui)
    return set.ui
end

function applyRentItemUiStateToInputs(state)
    local normalized = normalizeRentItemUiState(state)

    ui.daysPid[0] = normalized.daysPid
    ui.daysCount[0] = normalized.daysCount
    ui.daysTotal[0] = normalized.daysTotal

    ui.hoursPid[0] = normalized.hoursPid
    ui.hoursCount[0] = normalized.hoursCount
    ui.hoursPrice[0] = normalized.hoursPrice

    ui.restartPid[0] = normalized.restartPid
    ui.restartTotal[0] = normalized.restartTotal
    ui.maxPid[0] = normalized.maxPid
    ui.maxTotal[0] = normalized.maxTotal

    imgui.StrCopy(ui.daysTotalBuf, formatNumberDots(ui.daysTotal[0]))
    imgui.StrCopy(ui.hoursPriceBuf, formatNumberDots(ui.hoursPrice[0]))
    imgui.StrCopy(ui.restartTotalBuf, formatNumberDots(ui.restartTotal[0]))
    imgui.StrCopy(ui.maxTotalBuf, formatNumberDots(ui.maxTotal[0]))
end

function applyRentSetUiStateToInputs(state)
    local normalized = normalizeRentSetUiState(state)

    ui.daysPid[0] = normalized.daysPid
    ui.daysCount[0] = normalized.daysCount
    ui.daysTotal[0] = normalized.daysTotal

    ui.hoursPid[0] = normalized.hoursPid
    ui.hoursCount[0] = normalized.hoursCount
    ui.hoursPrice[0] = normalized.hoursTotal

    ui.restartPid[0] = normalized.restartPid
    ui.restartTotal[0] = normalized.restartTotal
    ui.maxPid[0] = normalized.maxPid
    ui.maxTotal[0] = normalized.maxTotal

    imgui.StrCopy(ui.daysTotalBuf, formatNumberDots(ui.daysTotal[0]))
    imgui.StrCopy(ui.hoursPriceBuf, formatNumberDots(ui.hoursPrice[0]))
    imgui.StrCopy(ui.restartTotalBuf, formatNumberDots(ui.restartTotal[0]))
    imgui.StrCopy(ui.maxTotalBuf, formatNumberDots(ui.maxTotal[0]))
end

syncUiToSelectedRentItem = function()
    local item = getSelectedRentItem()
    if not item then
        return false
    end

    local state = ensureRentItemUiState(item)
    state.daysPid = clampRentItemUiValue(ui.daysPid[0], LIMITS.pidMin, LIMITS.pidMax, ITEM_UI_DEFAULTS.daysPid)
    state.daysCount = clampRentItemUiValue(ui.daysCount[0], LIMITS.daysMin, LIMITS.daysMax, ITEM_UI_DEFAULTS.daysCount)
    state.daysTotal = clampRentItemUiValue(getMoneyInputValue(ui.daysTotal), 1, ui.itemIntMax, ITEM_UI_DEFAULTS.daysTotal)
    state.hoursPid = clampRentItemUiValue(ui.hoursPid[0], LIMITS.pidMin, LIMITS.pidMax, ITEM_UI_DEFAULTS.hoursPid)
    state.hoursCount =
        clampRentItemUiValue(ui.hoursCount[0], LIMITS.hoursMin, LIMITS.hoursMax, ITEM_UI_DEFAULTS.hoursCount)
    state.hoursPrice = clampRentItemUiValue(getMoneyInputValue(ui.hoursPrice), 1, ui.itemIntMax, ITEM_UI_DEFAULTS.hoursPrice)
    state.restartPid = clampRentItemUiValue(ui.restartPid[0], LIMITS.pidMin, LIMITS.pidMax, ITEM_UI_DEFAULTS.restartPid)
    state.restartTotal = clampRentItemUiValue(getMoneyInputValue(ui.restartTotal), 1, ui.itemIntMax, ITEM_UI_DEFAULTS.restartTotal)
    state.maxPid = clampRentItemUiValue(ui.maxPid[0], LIMITS.pidMin, LIMITS.pidMax, ITEM_UI_DEFAULTS.maxPid)
    state.maxTotal = clampRentItemUiValue(getMoneyInputValue(ui.maxTotal), 1, ui.itemIntMax, ITEM_UI_DEFAULTS.maxTotal)

    return true
end

syncUiToSelectedRentSet = function()
    local set = getSelectedRentSet()
    if not set then
        return false
    end

    local state = ensureRentSetUiState(set)
    state.daysPid = clampRentItemUiValue(ui.daysPid[0], LIMITS.pidMin, LIMITS.pidMax, SET_UI_DEFAULTS.daysPid)
    state.daysCount = clampRentItemUiValue(ui.daysCount[0], LIMITS.daysMin, LIMITS.daysMax, SET_UI_DEFAULTS.daysCount)
    state.daysTotal = clampRentItemUiValue(getMoneyInputValue(ui.daysTotal), 1, ui.itemIntMax, SET_UI_DEFAULTS.daysTotal)
    state.hoursPid = clampRentItemUiValue(ui.hoursPid[0], LIMITS.pidMin, LIMITS.pidMax, SET_UI_DEFAULTS.hoursPid)
    state.hoursCount =
        clampRentItemUiValue(ui.hoursCount[0], LIMITS.hoursMin, LIMITS.hoursMax, SET_UI_DEFAULTS.hoursCount)
    state.hoursTotal = clampRentItemUiValue(getMoneyInputValue(ui.hoursPrice), 1, ui.itemIntMax, SET_UI_DEFAULTS.hoursTotal)
    state.restartPid = clampRentItemUiValue(ui.restartPid[0], LIMITS.pidMin, LIMITS.pidMax, SET_UI_DEFAULTS.restartPid)
    state.restartTotal = clampRentItemUiValue(getMoneyInputValue(ui.restartTotal), 1, ui.itemIntMax, SET_UI_DEFAULTS.restartTotal)
    state.maxPid = clampRentItemUiValue(ui.maxPid[0], LIMITS.pidMin, LIMITS.pidMax, SET_UI_DEFAULTS.maxPid)
    state.maxTotal = clampRentItemUiValue(getMoneyInputValue(ui.maxTotal), 1, ui.itemIntMax, SET_UI_DEFAULTS.maxTotal)

    return true
end

syncUiToSelectedRentTarget = function()
    if selectedRentTargetType == "set" then
        return syncUiToSelectedRentSet()
    end
    return syncUiToSelectedRentItem()
end

loadUiFromSelectedRentItem = function()
    local item = getSelectedRentItem()
    if not item then
        applyRentItemUiStateToInputs(createDefaultRentItemUiState())
        return false
    end

    applyRentItemUiStateToInputs(ensureRentItemUiState(item))
    return true
end

loadUiFromSelectedRentSet = function()
    local set = getSelectedRentSet()
    if not set then
        applyRentSetUiStateToInputs(createDefaultRentSetUiState())
        return false
    end

    applyRentSetUiStateToInputs(ensureRentSetUiState(set))
    return true
end

loadUiFromSelectedRentTarget = function()
    if selectedRentTargetType == "set" then
        return loadUiFromSelectedRentSet()
    end
    return loadUiFromSelectedRentItem()
end

function ensureRentItemSelected()
    if hasRentItems() then
        return true
    end

    sampAddChatMessage("[АРЕНДА] " .. ui.msgEmptyItems, 0xFFFF00)
    return false
end

function ensureRentSetSelected()
    if hasRentSets() then
        return true
    end

    sampAddChatMessage("[АРЕНДА] " .. ui.msgEmptySets, 0xFFFF00)
    return false
end

function isPlayerOnline(pid)
    if type(pid) ~= "number" then
        return false
    end

    if sampIsPlayerConnected then
        return sampIsPlayerConnected(pid)
    end

    if sampGetCharHandleBySampPlayerId then
        local ok, handle = sampGetCharHandleBySampPlayerId(pid)
        return ok and handle ~= 0
    end

    if sampGetPlayerNickname then
        local nick = sampGetPlayerNickname(pid)
        return nick ~= nil and nick ~= ""
    end

    return true
end

function getSelectedItemName()
    if hasRentItems() and selectedRentTargetType == "item" then
        local item = rentItems[selectedRentItemIndex]
        if item and item.name and item.name ~= "" then
            return item.name
        end
        return cp1251("Предмет ") .. tostring(itemID)
    end

    if hasRentSets() and selectedRentTargetType == "set" then
        local set = rentSets[selectedRentSetIndex]
        return tostring(set.name or (cp1251("Сет ") .. tostring(selectedRentSetIndex)))
    end

    if itemID and itemID > 0 then
        return cp1251("Предмет ") .. tostring(itemID)
    end

    return cp1251("Нет выбранной конфигурации")
end

function selectRentItem(index)
    if type(index) ~= "number" then
        return false
    end
    index = math.floor(index)
    if index < 1 or index > #rentItems then
        return false
    end

    syncUiToSelectedRentTarget()

    selectedRentTargetType = "item"
    selectedRentItemIndex = index
    itemID = tonumber(rentItems[index].id) or 0
    ensureRentItemUiState(rentItems[index])
    loadUiFromSelectedRentItem()
    return true
end

function selectRentSet(index)
    if type(index) ~= "number" then
        return false
    end

    index = math.floor(index)
    if index < 1 or index > #rentSets then
        return false
    end

    syncUiToSelectedRentTarget()

    selectedRentTargetType = "set"
    selectedRentSetIndex = index
    ensureRentSetUiState(rentSets[index])
    loadUiFromSelectedRentSet()
    return true
end

function normalizeRentItemName(name, id)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = cp1251("Предмет ") .. tostring(id)
    end
    return name
end

function addOrUpdateRentItem(id, name)
    if type(id) ~= "number" or id ~= math.floor(id) or id < 1 then
        return false, cp1251("ID предмета должен быть положительным числом.")
    end

    name = normalizeRentItemName(name, id)

    for i = 1, #rentItems do
        if tonumber(rentItems[i].id) == id then
            return false, cp1251("Предмет с таким ID уже есть в списке. Используйте редактирование.")
        end
    end
    table.insert(rentItems, {id = id, name = name, ui = createDefaultRentItemUiState()})
    selectRentItem(#rentItems)
    saveRentItemsToJson()
    return true, cp1251("Элемент добавлен.")
end
function updateRentItemByIndex(index, id, name)
    index = tonumber(index)
    if not index then
        return false, cp1251("Элемент не найден.")
    end

    index = math.floor(index)
    if index < 1 or index > #rentItems then
        return false, cp1251("Элемент не найден.")
    end

    if type(id) ~= "number" or id ~= math.floor(id) or id < 1 then
        return false, cp1251("ID предмета должен быть положительным числом.")
    end

    for i = 1, #rentItems do
        if i ~= index and tonumber(rentItems[i].id) == id then
            return false, cp1251("Предмет с таким ID уже есть в списке.")
        end
    end

    name = normalizeRentItemName(name, id)
    rentItems[index].id = id
    rentItems[index].name = name
    ensureRentItemUiState(rentItems[index])

    selectRentItem(index)
    saveRentItemsToJson()
    return true, cp1251("Элемент обновлён.")
end

function removeRentItemByIndex(index)
    index = tonumber(index)
    if not index then
        return false, cp1251("Элемент не найден.")
    end

    index = math.floor(index)
    if index < 1 or index > #rentItems then
        return false, cp1251("Элемент не найден.")
    end

    local wasSelected = (selectedRentItemIndex == index)
    table.remove(rentItems, index)

    if #rentItems == 0 then
        selectedRentItemIndex = 0
        itemID = 0

        if selectedRentTargetType == "item" and #rentSets > 0 then
            selectedRentTargetType = "set"
            if selectedRentSetIndex < 1 or selectedRentSetIndex > #rentSets then
                selectedRentSetIndex = 1
            end
        end

        loadUiFromSelectedRentTarget()
        saveRentItemsToJson()
        return true, cp1251("Элемент удалён.")
    end

    if wasSelected then
        if index > #rentItems then
            selectedRentItemIndex = #rentItems
        else
            selectedRentItemIndex = index
        end
    elseif selectedRentItemIndex > index then
        selectedRentItemIndex = selectedRentItemIndex - 1
    end

    if selectedRentItemIndex < 1 then
        selectedRentItemIndex = 1
    end

    if selectedRentTargetType == "item" then
        selectRentItem(selectedRentItemIndex)
    end

    saveRentItemsToJson()
    return true, cp1251("Элемент удалён.")
end

function normalizeRentSetName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = cp1251("Новый сет")
    end
    return name
end

function resetCreateRentSetDraft()
    ui.newSetItemCount = 1
    imgui.StrCopy(ui.newSetNameBuf, "")

    for i = 1, ui.newSetItemLimit do
        ui.newSetItemIds[i][0] = 0
    end
end

function collectRentSetItemIdsFromDraft()
    local ids = {}

    for i = 1, ui.newSetItemCount do
        local id = tonumber(ui.newSetItemIds[i][0])
        if id and id > 0 and id == math.floor(id) then
            table.insert(ids, id)
        end
    end

    return ids
end

function addRentSet(name, itemIds)
    name = normalizeRentSetName(name)
    if type(itemIds) ~= "table" or #itemIds == 0 then
        return false, cp1251("Для сета нужно указать хотя бы один ID предмета.")
    end

    table.insert(
        rentSets,
        {
            name = name,
            itemIds = itemIds,
            ui = createDefaultRentSetUiState(),
            scanCache = createEmptySetScanCache()
        }
    )

    if selectedRentSetIndex <= 0 then
        selectedRentSetIndex = #rentSets
    end

    saveRentItemsToJson()
    return true, cp1251("Сет сохранён.")
end

function updateRentSetByIndex(index, name, itemIds)
    index = tonumber(index)
    if not index then
        return false, cp1251("Сет не найден.")
    end

    index = math.floor(index)
    if index < 1 or index > #rentSets then
        return false, cp1251("Сет не найден.")
    end

    name = normalizeRentSetName(name)
    if type(itemIds) ~= "table" or #itemIds == 0 then
        return false, cp1251("Для сета нужно указать хотя бы один ID предмета.")
    end

    local state = ensureRentSetUiState(rentSets[index])
    rentSets[index].name = name
    rentSets[index].itemIds = itemIds
    rentSets[index].ui = state or createDefaultRentSetUiState()
    rentSets[index].scanCache = normalizeSetScanCache(rentSets[index].scanCache, itemIds)
    saveRentItemsToJson()
    return true, cp1251("Сет обновлён.")
end

function removeRentSetByIndex(index)
    index = tonumber(index)
    if not index then
        return false, cp1251("Сет не найден.")
    end

    index = math.floor(index)
    if index < 1 or index > #rentSets then
        return false, cp1251("Сет не найден.")
    end

    local wasSelected = (selectedRentSetIndex == index)
    table.remove(rentSets, index)

    if showSetViewWindow[0] then
        if setViewWindowState.setIndex == index then
            showSetViewWindow[0] = false
            setViewWindowCloseHandled = true
            resetSetViewScanSession()
        elseif setViewWindowState.setIndex > index then
            setViewWindowState.setIndex = setViewWindowState.setIndex - 1
        end
    end

    if rentSetEditorIndex == index then
        rentSetEditorIndex = 0
    elseif rentSetEditorIndex > index then
        rentSetEditorIndex = rentSetEditorIndex - 1
    end

    if #rentSets == 0 then
        selectedRentSetIndex = 0
        if selectedRentTargetType == "set" then
            if #rentItems > 0 then
                selectedRentTargetType = "item"
                if selectedRentItemIndex < 1 or selectedRentItemIndex > #rentItems then
                    selectedRentItemIndex = 1
                end
                selectRentItem(selectedRentItemIndex)
            else
                loadUiFromSelectedRentTarget()
            end
        end

        saveRentItemsToJson()
        return true, cp1251("Сет удалён.")
    end

    if wasSelected then
        if index > #rentSets then
            selectedRentSetIndex = #rentSets
        else
            selectedRentSetIndex = index
        end
    elseif selectedRentSetIndex > index then
        selectedRentSetIndex = selectedRentSetIndex - 1
    end

    if selectedRentSetIndex < 1 then
        selectedRentSetIndex = 1
    end

    if selectedRentTargetType == "set" then
        selectRentSet(selectedRentSetIndex)
    end

    saveRentItemsToJson()
    return true, cp1251("Сет удалён.")
end

function openCreateRentModePopup()
    imgui.OpenPopup(uiLabel("POPUP_CREATE_RENT_MODE_ID"))
end

function openCreateRentSetPopup()
    rentSetEditorIndex = 0
    resetCreateRentSetDraft()
    imgui.OpenPopup(uiLabel("POPUP_CREATE_RENT_SET_ID"))
end

function openEditRentSetPopup(index)
    index = tonumber(index)
    if not index then
        return
    end

    index = math.floor(index)
    local set = rentSets[index]
    if not set then
        return
    end

    resetCreateRentSetDraft()
    rentSetEditorIndex = index
    imgui.StrCopy(ui.newSetNameBuf, cp1251ToUtf8Safe(tostring(set.name or "")))

    local ids = set.itemIds
    if type(ids) ~= "table" then
        ids = {}
    end

    local count = math.min(#ids, ui.newSetItemLimit)
    if count < 1 then
        count = 1
    end

    ui.newSetItemCount = count
    for i = 1, count do
        local id = tonumber(ids[i])
        if id and id > 0 and id == math.floor(id) then
            ui.newSetItemIds[i][0] = id
        else
            ui.newSetItemIds[i][0] = 0
        end
    end

    imgui.OpenPopup(uiLabel("POPUP_CREATE_RENT_SET_ID"))
end

function openCreateRentItemPopup()
    rentItemEditorIndex = 0
    ui.newItemId[0] = 0
    imgui.StrCopy(ui.newItemNameBuf, "")
    imgui.OpenPopup(uiLabel("POPUP_CREATE_RENT_ID"))
end

function openEditRentItemPopup(index)
    index = tonumber(index)
    if not index then
        return
    end

    index = math.floor(index)
    local it = rentItems[index]
    if not it then
        return
    end

    rentItemEditorIndex = index
    ui.newItemId[0] = tonumber(it.id) or itemID
    imgui.StrCopy(ui.newItemNameBuf, cp1251ToUtf8Safe(tostring(it.name or "")))
    imgui.OpenPopup(uiLabel("POPUP_CREATE_RENT_ID"))
end

local PAT_RENT_PRICE_MIN = cp1251("Стоимость не может быть меньше")
local PAT_RENT_PRICE_MAX = cp1251("и не более")

local FMT_BAD_HOURLY = cp1251("Неверная цена за час: %s.")
local FMT_ALLOWED_RANGE = cp1251("Допустимый диапазон: %s – %s.")
local TXT_RENT_CANCELLED = cp1251("Сдача отменена. Проверьте сумму и попробуйте снова.")

local TXT_CANT_PARSE = cp1251("Не удалось определить лимиты цены за 1 час из текста диалога.")
local TXT_STOPPED = cp1251("Остановлено. Исправьте сумму/срок и попробуйте снова.")
local SERVER_ERROR_RENT_SHOP_ACTIVE_HEAD = cp1251("Нельзя сдать предмет в аренду")
local SERVER_ERROR_RENT_SHOP_ACTIVE_TAIL = cp1251("игрок арендует лавку")
local SERVER_ERROR_RENT_SHOP_ACTIVE_ALT = cp1251("Игрок уже арендует лавку")
local SERVER_MSG_RENT_OFFER_TIMEOUT_HEAD = cp1251("[Предложение]")
local SERVER_MSG_RENT_OFFER_TIMEOUT_BODY = cp1251("перестанет быть активным через 60 секунд")
local SERVER_MSG_RENT_OFFER_TIMEOUT_EXACT_PATTERN = cp1251("^%s*%[Предложение%]%s*Предложение%s+перестанет%s+быть%s+активным%s+через%s+60%s+секунд%.?%s*$")
local SERVER_MSG_RENT_ACCEPTED_HEAD = cp1251("[Аренда]")
local SERVER_MSG_RENT_ACCEPTED_HEAD_ALT = cp1251("[АРЕНДА]")
local SERVER_MSG_RENT_OFFER_ACCEPTED_FRAGMENT = cp1251("по аренде предмета было успешно принято игроком")
local TXT_RENT_OFFER_NOT_ACCEPTED = cp1251("Игрок не принял предложение аренды за 60 секунд.")
local SERVER_ERROR_TRANSFER_ACTIVE_PART = cp1251("активное действие на передачу предмета")
local STOP_REASON_TRANSFER_ACTIVE_CHECK = cp1251("Проверка остановлена. Завершите текущее действие на передачу предмета и попробуйте снова.")
PAT_MINUTE_RENT_PROMPT = cp1251("На сколько минут Вы хотите сдать предмет?")

TXT_MINUTE_MANUAL_STARTED = cp1251("Ошибка: этот предмет нельзя сдать по часам. Запущена ручная поминутная сдача.")
TXT_MINUTE_MANUAL_HINT = cp1251("Обнаружен диалог другого типа. Введите данные вручную в окне «Ручная сдача».")
TXT_MINUTE_PRICE_WAIT = cp1251("Ожидаю диалог цены за 1 минуту.")
TXT_MINUTE_FLOW_STOPPED = cp1251("Ручная сдача остановлена пользователем.")
TXT_MINUTE_CURRENCY_WAIT = cp1251("Идёт определение валюты. Подождите...")

MINUTE_RENT_LIMITS = {
    minutesMin = 5,
    minutesMax = 120,
    saMin = 5000,
    saMax = 200000,
    vcMin = 50,
    vcMax = 2000
}

HOURLY_RENT_LIMITS = {
    saMin = 50000,
    saMax = 200000000,
    vcMin = 1000,
    vcMax = 200000000
}

function getHourlyPriceLimitsByCurrency(currency)
    if currency == "VC$" then
        return HOURLY_RENT_LIMITS.vcMin, HOURLY_RENT_LIMITS.vcMax, "VC$"
    end
    return HOURLY_RENT_LIMITS.saMin, HOURLY_RENT_LIMITS.saMax, "SA$"
end

function getUnifiedHourlyPriceLimits(limits)
    if type(limits) ~= "table" then
        return nil
    end

    local minPrice, maxPrice, currency = getHourlyPriceLimitsByCurrency(limits.currency)
    return {
        min = minPrice,
        max = maxPrice,
        currency = currency
    }
end

function stripColorCodes(s)
    local clean = s or ""
    clean = clean:gsub("{%x%x%x%x%x%x%x%x}", "")
    clean = clean:gsub("{%x%x%x%x%x%x}", "")
    return clean
end

function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function normalizeVersionToken(versionText)
    if type(versionText) ~= "string" then
        return nil
    end

    local core = versionText:upper():match("V%s*(%d[%d%.]*)")
    if not core then
        core = versionText:match("(%d[%d%.]*)")
    end
    if not core then
        return nil
    end

    core = core:gsub("%.+", "."):gsub("^%.+", ""):gsub("%.+$", "")
    if core == "" then
        return nil
    end

    return "V" .. core
end

local function splitVersionParts(versionText)
    local normalized = normalizeVersionToken(versionText)
    if not normalized then
        return nil
    end

    local parts = {}
    for token in normalized:gsub("^V", ""):gmatch("%d+") do
        parts[#parts + 1] = tonumber(token) or 0
    end

    if #parts == 0 then
        return nil
    end

    return parts
end

local function compareVersions(leftVersion, rightVersion)
    local leftParts = splitVersionParts(leftVersion)
    local rightParts = splitVersionParts(rightVersion)

    if not leftParts or not rightParts then
        return 0
    end

    local maxLen = math.max(#leftParts, #rightParts)
    for i = 1, maxLen do
        local left = leftParts[i] or 0
        local right = rightParts[i] or 0
        if left > right then
            return 1
        end
        if left < right then
            return -1
        end
    end

    return 0
end

local function decodeHtmlEntities(text)
    text = tostring(text or "")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&amp;", "&")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&#(%d+);", function(num)
        local code = tonumber(num)
        if code and code >= 32 and code <= 126 then
            return string.char(code)
        end
        return " "
    end)

    return text
end

local function htmlToPlainText(html)
    local text = tostring(html or "")
    text = text:gsub("\r", "\n")
    text = text:gsub("<[bB][rR]%s*/?>", "\n")
    text = text:gsub("</[pP]>", "\n")
    text = text:gsub("</[lL][iI]>", "\n")
    text = text:gsub("<[lL][iI][^>]*>", "- ")
    text = text:gsub("<[^>]+>", " ")
    text = decodeHtmlEntities(text)
    text = text:gsub("[ \t]+", " ")
    text = text:gsub("\n%s+", "\n")
    text = text:gsub("\n\n+", "\n")

    return text
end

local function extractLatestVersionToken(text)
    if type(text) ~= "string" then
        return nil
    end

    local latest = nil
    for token in text:gmatch("[Vv]%s*%d%d?%.%d+[%d%.]*") do
        local normalized = normalizeVersionToken(token)
        if normalized and (not latest or compareVersions(normalized, latest) > 0) then
            latest = normalized
        end
    end

    return latest
end

local function extractChangelogFromText(plainText, latestVersion)
    local lines = {}
    local seen = {}

    plainText = tostring(plainText or "")
    local scope = plainText

    if latestVersion then
        local pos = plainText:find(latestVersion, 1, true)
        if pos then
            scope = plainText:sub(pos, math.min(#plainText, pos + 2600))
        end
    end

    for rawLine in scope:gmatch("[^\n]+") do
        local line = trim(rawLine)
        line = line:gsub("^[-•*%d%.%)%s]+", "")
        line = line:gsub("%s+", " ")

        if line ~= "" then
            local lowered = line:lower()
            local isChange = false

            if latestVersion and line:find(latestVersion, 1, true) then
                isChange = true
            end

            if
                lowered:find("добав", 1, true) or lowered:find("исправ", 1, true) or lowered:find("фикс", 1, true) or
                    lowered:find("измен", 1, true) or
                    lowered:find("оптим", 1, true) or
                    lowered:find("улучш", 1, true)
             then
                isChange = true
            end

            if isChange then
                line = utf8ToCp1251Safe(line)
                if #line > 118 then
                    line = line:sub(1, 115) .. "..."
                end

                if not seen[line] then
                    lines[#lines + 1] = line
                    seen[line] = true
                end

                if #lines >= UPDATE_POPUP_MAX_LINES then
                    break
                end
            end
        end
    end

    if #lines == 0 then
        lines = {
            cp1251("Новая версия найдена на форуме."),
            cp1251("Полный список изменений откройте кнопкой «Обновить».")
        }
    end

    return lines
end

local function extractChangelogFromManifest(changelogValue)
    local lines = {}

    local function pushLine(raw)
        local line = trim(utf8ToCp1251Safe(tostring(raw or "")))
        if line == "" then
            return
        end

        if #line > 118 then
            line = line:sub(1, 115) .. "..."
        end

        lines[#lines + 1] = line
    end

    if type(changelogValue) == "table" then
        for i = 1, #changelogValue do
            pushLine(changelogValue[i])
            if #lines >= UPDATE_POPUP_MAX_LINES then
                break
            end
        end
    elseif type(changelogValue) == "string" then
        for rawLine in changelogValue:gmatch("[^\r\n]+") do
            pushLine(rawLine)
            if #lines >= UPDATE_POPUP_MAX_LINES then
                break
            end
        end
    end

    if #lines == 0 then
        lines = {
            cp1251("Новая версия найдена."),
            cp1251("Подробности доступны по кнопке «Обновить».")
        }
    end

    return lines
end

local function requestUpdateInfo()
    if not requests then
        return nil, nil, cp1251("Библиотека requests не найдена для проверки обновлений.")
    end

    if UPDATE_MANIFEST_URL == "" then
        return nil, nil, cp1251("Ссылка на updates.json не настроена.")
    end

    local ok, response =
        pcall(
        requests.get,
        UPDATE_MANIFEST_URL,
        {
            timeout = UPDATE_REQUEST_TIMEOUT,
            headers = {
                ["User-Agent"] = "ArendaUpdater/1.0",
                ["Accept"] = "application/json"
            }
        }
    )

    if not ok or type(response) ~= "table" then
        return nil, nil, cp1251("Ошибка запроса при проверке обновления.")
    end

    local status = tonumber(response.status_code) or 0
    if status < 200 or status >= 400 then
        return nil, nil, cp1251("Сервер updates.json недоступен (HTTP " .. tostring(status) .. ").")
    end

    local body = tostring(response.text or "")
    if body == "" then
        return nil, nil, cp1251("updates.json вернул пустой ответ.")
    end

    local payload = nil

    if type(response.json) == "function" then
        local jsonOk, decoded = pcall(response.json)
        if jsonOk and type(decoded) == "table" then
            payload = decoded
        end
    end

    if type(payload) ~= "table" then
        local hasCjson, cjson = pcall(require, "cjson.safe")
        if hasCjson and cjson then
            payload = cjson.decode(body)
        end
    end

    if type(payload) ~= "table" then
        return nil, nil, cp1251("Некорректный формат updates.json.")
    end

    local latestVersion =
        normalizeVersionToken(
        tostring(payload.version or payload.latest_version or payload.latest or payload.script_version or "")
    )

    if not latestVersion then
        return nil, nil, cp1251("В updates.json не найдено поле version.")
    end


    local changelog = extractChangelogFromManifest(payload.changelog or payload.changes or payload.notes)
    return latestVersion, changelog, nil
end

local function startUpdateCheck(force)
    force = force == true

    if updateState.checking then
        return false
    end

    if updateState.checked and not force then
        return false
    end

    updateState.checking = true
    if force then
        updateState.checked = false
    end

    lua_thread.create(
        function()
            local latestVersion, changelog, err = requestUpdateInfo()

            updateState.checked = true
            updateState.checking = false

            if latestVersion and compareVersions(latestVersion, SCRIPT_VERSION) > 0 then
                updateState.hasUpdate = true
                setUpdatePopupVisible(true)
                updateState.latestVersion = latestVersion
                updateState.changelog = changelog or {}

                sampAddChatMessage(
                    string.format("[АРЕНДА] Обновление доступно: %s -> %s", SCRIPT_VERSION, latestVersion),
                    0xFFFF00
                )
                return
            end

            updateState.hasUpdate = false
            setUpdatePopupVisible(false)
            updateState.latestVersion = latestVersion or SCRIPT_VERSION
            updateState.changelog = changelog or {}

            if force then
                if err then
                    sampAddChatMessage("[АРЕНДА] " .. err, 0xFFFF00)
                else
                    sampAddChatMessage("[АРЕНДА] Обновление не найдено. Установлена актуальная версия.", 0xFFFF00)
                end
            end
        end
    )

    return true
end

function parseMoneyToken(token)
    token = trim(token)
    if token == "" then
        return nil, nil
    end

    local currency
    if token:find(":cashv:", 1, true) then
        currency = "VC$"
    elseif token:find(":cash:", 1, true) then
        currency = "SA$"
    elseif token:find("VC%$") then
        currency = "VC$"
    elseif token:find("SA%$") then
        currency = "SA$"
    elseif token:find("%$") then
        currency = "SA$"
    end

    local num = tonumber((token:gsub("[^0-9]", "")))
    return num, currency
end

function parseHourlyLimits(text)
    local clean = stripColorCodes(text):gsub("\r", "\n")
    local line

    for l in clean:gmatch("[^\n]+") do
        if l:find(PAT_RENT_PRICE_MIN, 1, true) and l:find(PAT_RENT_PRICE_MAX, 1, true) then
            line = l
            break
        end
    end
    if not line then
        line = clean
    end

    local minChunk, maxChunk = line:match(PAT_RENT_PRICE_MIN .. "%s*(.-)%s*" .. PAT_RENT_PRICE_MAX .. "%s*(.-)%s*%.?$")
    if not minChunk or not maxChunk then
        return nil
    end

    local minVal, cur1 = parseMoneyToken(minChunk)
    local maxVal, cur2 = parseMoneyToken(maxChunk)
    if not minVal or not maxVal then
        return nil
    end

    local currency = cur1 or cur2 or "SA$"
    if minVal > maxVal then
        minVal, maxVal = maxVal, minVal
    end

    return {min = minVal, max = maxVal, currency = currency}
end

formatNumberDots = function(n)
    n = tonumber(n) or 0
    local sign = ""
    if n < 0 then
        sign = "-"
        n = -n
    end
    local str = tostring(math.floor(n))
    local out = ""
    while #str > 3 do
        out = "." .. str:sub(-3) .. out
        str = str:sub(1, -4)
    end
    out = str .. out
    return sign .. out
end

function getMoneyInputValue(valuePtr)
    return math.floor(tonumber(valuePtr[0]) or 0)
end


function drawRentPriceLimitsTooltip()
    if not imgui.IsItemHovered() then
        return
    end

    imgui.SetTooltip(
        uiLabelFmt(
            "TOOLTIP_RENT_PRICE_LIMITS_FMT",
            formatNumberDots(HOURLY_RENT_LIMITS.saMin),
            formatNumberDots(HOURLY_RENT_LIMITS.saMax),
            formatNumberDots(HOURLY_RENT_LIMITS.vcMin),
            formatNumberDots(HOURLY_RENT_LIMITS.vcMax)
        )
    )
end
function syncMoneyInputBuffer(buf, valuePtr, minValue)
    local raw = ffi.string(buf)
    local digits = raw:gsub("[^0-9]", "")

    if digits == "" then
        valuePtr[0] = 0
        return
    end

    local value = tonumber(digits) or 0
    if minValue and value < minValue then
        value = minValue
    end
    if value > ui.itemIntMax then
        value = ui.itemIntMax
    end

    valuePtr[0] = value

    local formatted = formatNumberDots(value)
    if raw ~= formatted then
        imgui.StrCopy(buf, formatted)
    end
end


imgui.StrCopy(ui.daysTotalBuf, formatNumberDots(ui.daysTotal[0]))
imgui.StrCopy(ui.hoursPriceBuf, formatNumberDots(ui.hoursPrice[0]))
imgui.StrCopy(ui.restartTotalBuf, formatNumberDots(ui.restartTotal[0]))
imgui.StrCopy(ui.maxTotalBuf, formatNumberDots(ui.maxTotal[0]))
local spawned = false
local spawnMessageDueAt = nil
local lastCurrency = nil
local inventoryItemIdsEnabled = false
local quietModeEnabled = false
local rawSampAddChatMessage = sampAddChatMessage
local QUIET_CHAT_SUPPRESS_PATTERNS = {
    "Успешно загружен",
    "Обновление не найдено",
    "Поиск предметов начат",
    "Обработана ячейка",
    "Ищу предмет ID",
    "Ищу предмет для игрока",
    "Найден предмет НЕ в аренде",
    "Диалог не получен. Повтор"
}
local QUIET_CHAT_IMPORTANT_PATTERNS = {
    "Цена:",
    "Итого",
    "Сумма за весь срок",
    "Распределение:",
    "Запущено:",
    "Успешно!",
    "принял предложение",
    "Сканирование завершено",
    "заверш",
    "Заверш",
    "нельзя",
    "не найден",
    "не найдены",
    "Нет ",
    "нет ",
    "пуст",
    "Пуст",
    "Некоррект",
    "Ошибка",
    "[Ошибка]",
    "Не удалось",
    "Сначала",
    "Дождитесь",
    "долж",
    "Лимит",
    "лимит",
    "отмен",
    "Останов",
    "останов",
    "Пропущ",
    "пропущ",
    "Тихий режим",
    "Обновление доступно"
}

function isQuietChatMessageImportant(message)
    local text = tostring(message or "")

    for i = 1, #QUIET_CHAT_SUPPRESS_PATTERNS do
        if text:find(QUIET_CHAT_SUPPRESS_PATTERNS[i], 1, true) then
            return false
        end
    end

    for i = 1, #QUIET_CHAT_IMPORTANT_PATTERNS do
        if text:find(QUIET_CHAT_IMPORTANT_PATTERNS[i], 1, true) then
            return true
        end
    end

    return false
end

function shouldShowArendaChatMessage(message)
    if not quietModeEnabled then
        return true
    end

    local text = tostring(message or "")
    if not text:find("[АРЕНДА]", 1, true) then
        return true
    end

    return isQuietChatMessageImportant(text)
end

function sendArendaChatRaw(message, color)
    if rawSampAddChatMessage then
        rawSampAddChatMessage(message, color or 0xFFFF00)
    end
end

function sampAddChatMessage(message, color)
    if shouldShowArendaChatMessage(message) then
        sendArendaChatRaw(message, color)
    end
end
local INVENTORY_ID_OVERLAY_INTERVAL = 0.50
local inventoryIdOverlayNextTick = 0
manualMinuteRent = {
    active = false,
    stage = "",
    currentDialogId = 0,
    minutes = new.int(5),
    price = new.int(5000),
    priceMin = 5000,
    priceMax = 200000,
    currency = "SA$",
    noticeShown = false,
    currencyReady = false,
    closeMainRequested = false
}

function getMinutePriceLimitsByCurrency(currency)
    if currency == "VC$" then
        return MINUTE_RENT_LIMITS.vcMin, MINUTE_RENT_LIMITS.vcMax, "VC$"
    end
    return MINUTE_RENT_LIMITS.saMin, MINUTE_RENT_LIMITS.saMax, "SA$"
end

function applyMinutePriceLimits(currency)
    local minPrice, maxPrice, normalizedCurrency = getMinutePriceLimitsByCurrency(currency)
    manualMinuteRent.currency = normalizedCurrency
    manualMinuteRent.priceMin = minPrice
    manualMinuteRent.priceMax = maxPrice

    if manualMinuteRent.price[0] < minPrice then
        manualMinuteRent.price[0] = minPrice
    end
    if manualMinuteRent.price[0] > maxPrice then
        manualMinuteRent.price[0] = maxPrice
    end
end

function clampManualMinuteValues()
    if manualMinuteRent.minutes[0] < MINUTE_RENT_LIMITS.minutesMin then
        manualMinuteRent.minutes[0] = MINUTE_RENT_LIMITS.minutesMin
    end
    if manualMinuteRent.minutes[0] > MINUTE_RENT_LIMITS.minutesMax then
        manualMinuteRent.minutes[0] = MINUTE_RENT_LIMITS.minutesMax
    end

    if manualMinuteRent.price[0] < manualMinuteRent.priceMin then
        manualMinuteRent.price[0] = manualMinuteRent.priceMin
    end
    if manualMinuteRent.price[0] > manualMinuteRent.priceMax then
        manualMinuteRent.price[0] = manualMinuteRent.priceMax
    end
end

function formatMoney(amount, currency)
    currency = currency or lastCurrency or "SA$"
    local str = formatNumberDots(amount)
    if currency == "VC$" then
        return "VC$" .. str
    end
    return str .. "$"
end
local enable = false
local mode = "check"

local scanIndex = 0
local processedCount = 0
local notRentedFound = false
local notRentedSlots = {}
local currentInventorySlot = nil
local currentInventorySlotScanIndex = -1

local waitingForDialog = false
local dialogWaitStart = 0
local noDialogTries = 0
local DIALOG_TIMEOUT = 1.0
local MAX_NO_DIALOG_TRIES = 2
local attemptCount = 0
local busy = false

local rentedUntil = nil

local rentChainActive = false
local rentCfg = nil

local awaitingConfirm = false
local awaitingConfirmStart = 0
local awaitingConfirmPid = nil
awaitingConfirmManual = false

local setRentSession = {
    active = false,
    setName = "",
    setIndex = 0,
    itemIds = {},
    cursor = 0,
    completed = 0,
    failed = 0,
    modeKind = "",
    pid = 0,
    days = 1,
    hours = 1,
    total = 0,
    perItemTotal = 0
}

function resetSetRentSession()
    setRentSession.active = false
    setRentSession.setName = ""
    setRentSession.setIndex = 0
    setRentSession.itemIds = {}
    setRentSession.cursor = 0
    setRentSession.completed = 0
    setRentSession.failed = 0
    setRentSession.modeKind = ""
    setRentSession.pid = 0
    setRentSession.days = 1
    setRentSession.hours = 1
    setRentSession.total = 0
    setRentSession.perItemTotal = 0
end

function isSetRentSessionActive()
    return setRentSession.active == true
end

local setCheckSession = {
    active = false,
    setName = "",
    setIndex = 0,
    itemIds = {},
    cursor = 0
}

function resetSetCheckSession()
    setCheckSession.active = false
    setCheckSession.setName = ""
    setCheckSession.setIndex = 0
    setCheckSession.itemIds = {}
    setCheckSession.cursor = 0
end

function isSetCheckSessionActive()
    return setCheckSession.active == true
end
function resetCurrentInventorySlot()
    currentInventorySlot = nil
    currentInventorySlotScanIndex = -1
end

function rememberInventorySlot(slot)
    slot = tonumber(slot)
    if not slot or slot < 0 then
        return false
    end

    currentInventorySlot = math.floor(slot)
    currentInventorySlotScanIndex = scanIndex
    return true
end

function getCurrentInventorySlotNumber()
    if currentInventorySlot and currentInventorySlotScanIndex == scanIndex then
        return currentInventorySlot
    end

    return scanIndex + 1
end

function resetScanSessionState()
    scanIndex = 0
    processedCount = 0
    notRentedFound = false
    notRentedSlots = {}
    resetCurrentInventorySlot()
end

function resetDialogSessionState()
    waitingForDialog = false
    dialogWaitStart = 0
    noDialogTries = 0
    attemptCount = 0
    busy = false
    rentedUntil = nil
end

function resetAwaitingConfirmState()
    awaitingConfirm = false
    awaitingConfirmStart = 0
    awaitingConfirmPid = nil
    awaitingConfirmManual = false
end

function getNickById(pid)
    if sampGetPlayerNickname then
        local nick = sampGetPlayerNickname(pid)
        if nick and nick ~= "" then
            return nick
        end
    end
    return tostring(pid)
end

function findNearestPlayerId(maxDistance)
    if not (sampGetCharHandleBySampPlayerId and doesCharExist and getCharCoordinates and playerPed) then
        return nil, nil
    end

    if not doesCharExist(playerPed) then
        return nil, nil
    end

    local px, py, pz = getCharCoordinates(playerPed)
    local maxDist = tonumber(maxDistance) or NEARBY_PLAYER_MAX_DISTANCE
    if maxDist < 1 then
        maxDist = 1
    end

    local maxDistSq = maxDist * maxDist
    local nearestId = nil
    local nearestDistSq = nil
    local localId = sampGetLocalPlayerId and sampGetLocalPlayerId() or -1

    for pid = LIMITS.pidMin, LIMITS.pidMax do
        if pid ~= localId and isPlayerOnline(pid) then
            local ok, ped = sampGetCharHandleBySampPlayerId(pid)
            if ok and ped and ped ~= -1 and doesCharExist(ped) then
                local x, y, z = getCharCoordinates(ped)
                local dx = x - px
                local dy = y - py
                local dz = z - pz
                local distSq = dx * dx + dy * dy + dz * dz

                if distSq <= maxDistSq and (not nearestDistSq or distSq < nearestDistSq) then
                    nearestId = pid
                    nearestDistSq = distSq
                end
            end
        end
    end

    if not nearestId then
        return nil, nil
    end

    return nearestId, math.sqrt(nearestDistSq)
end

function applyPlayerIdToAllModesAndItems(pid)
    pid = clampRentItemUiValue(pid, LIMITS.pidMin, LIMITS.pidMax, LIMITS.pidMin)

    ui.daysPid[0] = pid
    ui.hoursPid[0] = pid
    ui.restartPid[0] = pid
    ui.maxPid[0] = pid

    for i = 1, #rentItems do
        local state = ensureRentItemUiState(rentItems[i])
        if state then
            state.daysPid = pid
            state.hoursPid = pid
            state.restartPid = pid
            state.maxPid = pid
        end
    end

    for i = 1, #rentSets do
        local state = ensureRentSetUiState(rentSets[i])
        if state then
            state.daysPid = pid
            state.hoursPid = pid
            state.restartPid = pid
            state.maxPid = pid
        end
    end

    return pid
end

function applyNearestPlayerId()
    local pid, distance = findNearestPlayerId(NEARBY_PLAYER_MAX_DISTANCE)
    if not pid then
        sampAddChatMessage(
            string.format("[АРЕНДА] Рядом нет игроков (до %.1f м).", NEARBY_PLAYER_MAX_DISTANCE),
            0xFFFF00
        )
        return false
    end

    pid = applyPlayerIdToAllModesAndItems(pid)
    sampAddChatMessage(
        string.format("[АРЕНДА] Ближайший игрок: %s [%d], %.1f м.", getNickById(pid), pid, distance or 0),
        0xFFFF00
    )
    return true
end
function evalanon(code)
    evalcef(("(() => {%s})()"):format(code))
end

function evalcef(code, encoded)
    encoded = encoded or 0

    if type(code) ~= "string" or code == "" then
        return false
    end

    if
        not (
            raknetNewBitStream and raknetBitStreamWriteInt8 and raknetBitStreamWriteInt16 and raknetBitStreamWriteInt32 and
                raknetBitStreamWriteString and raknetEmulPacketReceiveBitStream and raknetDeleteBitStream
        )
     then
        return false
    end

    local bs = nil
    local ok =
        pcall(
        function()
            bs = raknetNewBitStream()
            if not bs or bs == 0 then
                error("bitstream")
            end

            raknetBitStreamWriteInt8(bs, 17)
            raknetBitStreamWriteInt32(bs, 0)
            raknetBitStreamWriteInt16(bs, #code)
            raknetBitStreamWriteInt8(bs, encoded)
            raknetBitStreamWriteString(bs, code)
            raknetEmulPacketReceiveBitStream(220, bs)
        end
    )

    if bs and bs ~= 0 then
        pcall(raknetDeleteBitStream, bs)
    end

    return ok
end

function sendCefEventPacket(eventName)
    if type(eventName) ~= "string" or eventName == "" then
        return false
    end

    if
        not (
            raknetNewBitStream and raknetBitStreamWriteInt8 and raknetBitStreamWriteInt16 and
                raknetBitStreamWriteInt32 and raknetBitStreamWriteString and raknetDeleteBitStream and
                (raknetSendBitStreamEx or raknetSendBitStream)
        )
     then
        return false
    end

    local bs = nil
    local ok =
        pcall(
        function()
            bs = raknetNewBitStream()
            if not bs or bs == 0 then
                error("bitstream")
            end

            raknetBitStreamWriteInt8(bs, 220)
            raknetBitStreamWriteInt8(bs, 18)
            raknetBitStreamWriteInt16(bs, #eventName)
            raknetBitStreamWriteString(bs, eventName)
            raknetBitStreamWriteInt32(bs, 0)

            if raknetSendBitStreamEx then
                raknetSendBitStreamEx(bs, 1, 9, 0)
            else
                raknetSendBitStream(bs)
            end
        end
    )

    if bs and bs ~= 0 then
        pcall(raknetDeleteBitStream, bs)
    end

    return ok
end

function getBitStreamUnreadBytes(bs)
    if not (bs and raknetBitStreamGetNumberOfUnreadBits) then
        return 0
    end

    local ok, bits = pcall(raknetBitStreamGetNumberOfUnreadBits, bs)
    if not ok then
        return 0
    end

    return math.floor((tonumber(bits) or 0) / 8)
end

function parseCefUiEventPacket(packetId, bs)
    if packetId ~= 220 or not bs then
        return nil, nil
    end

    if
        not (
            raknetBitStreamGetReadOffset and raknetBitStreamSetReadOffset and raknetBitStreamReadInt8 and
                raknetBitStreamReadInt16 and raknetBitStreamReadInt32 and raknetBitStreamReadString
        )
     then
        return nil, nil
    end

    local oldOffset = raknetBitStreamGetReadOffset(bs)
    local eventName, payload = nil, nil
    local hasInlinePayload = false

    local ok =
        pcall(
        function()
            raknetBitStreamSetReadOffset(bs, 8)

            local eventType = raknetBitStreamReadInt8(bs)
            if eventType ~= 18 then
                return
            end

            local nameLen = tonumber(raknetBitStreamReadInt16(bs)) or 0
            if nameLen < 1 or nameLen > 256 then
                return
            end

            eventName = raknetBitStreamReadString(bs, nameLen)
            payload = ""

            local pipePos = type(eventName) == "string" and eventName:find("|", 1, true) or nil
            if pipePos then
                payload = eventName:sub(pipePos + 1)
                eventName = eventName:sub(1, pipePos - 1)
                hasInlinePayload = payload ~= ""
            end

            local unreadBytes = getBitStreamUnreadBytes(bs)
            if unreadBytes <= 0 or hasInlinePayload then
                return
            end

            local payloadStartOffset = raknetBitStreamGetReadOffset(bs)
            if unreadBytes >= 4 then
                local payloadLen = tonumber(raknetBitStreamReadInt32(bs)) or 0
                local afterLenBytes = getBitStreamUnreadBytes(bs)
                if payloadLen > 4 and payloadLen <= afterLenBytes then
                    payload = raknetBitStreamReadString(bs, payloadLen)
                    return
                end
            end

            raknetBitStreamSetReadOffset(bs, payloadStartOffset)
            payload = raknetBitStreamReadString(bs, unreadBytes)
        end
    )

    pcall(raknetBitStreamSetReadOffset, bs, oldOffset)

    if not ok then
        return nil, nil
    end

    return eventName, payload
end

function handleCefUiEventPacket(packetId, bs)
    local eventName, payload = parseCefUiEventPacket(packetId, bs)
    if eventName ~= "rightClickOnBlock" or type(payload) ~= "string" then
        return
    end

    local slot = payload:match([["slot"%s*:%s*(%d+)]])
    if slot then
        rememberInventorySlot(slot)
    end
end

if addEventHandler then
    addEventHandler(
        "onSendPacket",
        function(packetId, bs)
            handleCefUiEventPacket(packetId, bs)
        end
    )
    addEventHandler(
        "onReceivePacket",
        function(packetId, bs)
            handleCefUiEventPacket(packetId, bs)
        end
    )
end

function closeInventoryViaCef(delay, attempts, interval)
    delay = tonumber(delay) or 0
    if delay < 0 then
        delay = 0
    end

    attempts = math.floor(tonumber(attempts) or 3)
    if attempts < 1 then
        attempts = 1
    end

    interval = tonumber(interval) or 120
    if interval < 0 then
        interval = 0
    end

    lua_thread.create(
        function()
            if delay > 0 then
                wait(delay)
            end

            for i = 1, attempts do
                sendCefEventPacket("inventoryClose")

                if i < attempts and interval > 0 then
                    wait(interval)
                end
            end
        end
    )
end

function clearInventoryItemIdsOverlay()
    evalanon(
        [[
        (() => {
            document.querySelectorAll('.custom-debug-id, .custom-debug-slot').forEach(label => label.remove());
        })();
    ]]
    )
end

function applyInventoryItemIdsOverlay()
    evalanon(
        [[
        (() => {
            const containers = document.querySelectorAll('.inventory-main__grid, .inventory-grid__grid, .character-main__loadout-ammunition, .character-main__loadout-gear, .character-main__loadout-accessories');
            containers.forEach(container => {
                const slots = container.querySelectorAll('.inventory-item-hoc, .inventory-grid__item-bg');
                slots.forEach((slot, slotIndex) => {
                    slot.querySelectorAll('.custom-debug-id, .custom-debug-slot').forEach(label => label.remove());

                    if (window.getComputedStyle(slot).position === 'static') {
                        slot.style.position = 'relative';
                    }

                    const slotLabel = document.createElement('div');
                    slotLabel.className = 'custom-debug-slot';
                    slotLabel.style.cssText = 'position:absolute!important;bottom:2px!important;left:2px!important;background:rgba(0,0,0,0.88)!important;color:#00e8ff!important;font-family:Tahoma,Arial,sans-serif!important;font-size:11px!important;font-weight:700!important;line-height:1!important;padding:1px 4px 2px 4px!important;border-radius:3px!important;z-index:9999!important;pointer-events:none!important;border:1px solid rgba(0,232,255,0.55)!important;text-shadow:0 0 2px rgba(0,0,0,0.85)!important;';
                    slotLabel.innerText = slotIndex;
                    slot.appendChild(slotLabel);

                    let itemID = null;
                    const img = slot.querySelector('.inventory-item__image');
                    if (img) {
                        const rawId = img.getAttribute('alt') || img.getAttribute('title') || slot.getAttribute('data-item-id') || '';
                        const match = rawId.match(/\d+/);
                        if (match) {
                            itemID = match[0];
                        }
                    }

                    if (itemID) {
                        const idLabel = document.createElement('div');
                        idLabel.className = 'custom-debug-id';
                        idLabel.style.cssText = 'position:absolute!important;top:2px!important;right:2px!important;background:rgba(0,0,0,0.88)!important;color:#f3d33f!important;font-family:Tahoma,Arial,sans-serif!important;font-size:11px!important;font-weight:700!important;line-height:1!important;padding:1px 4px 2px 4px!important;border-radius:3px!important;z-index:9999!important;pointer-events:none!important;border:1px solid rgba(255,215,64,0.55)!important;text-shadow:0 0 2px rgba(0,0,0,0.85)!important;';
                        idLabel.innerText = 'ID:' + itemID;
                        slot.appendChild(idLabel);
                    }
                });
            });
        })();
    ]]
    )
end

function setQuietModeEnabled(enabled, silent, skipSave)
    local normalized = enabled == true

    if quietModeEnabled == normalized then
        ui.quietMode[0] = normalized
        return false
    end

    quietModeEnabled = normalized
    ui.quietMode[0] = normalized

    if not silent then
        if quietModeEnabled then
            sendArendaChatRaw("[АРЕНДА] Тихий режим {00FF00}включён{FFFF00}.", 0xFFFF00)
        else
            sendArendaChatRaw("[АРЕНДА] Тихий режим {FF8000}выключен{FFFF00}.", 0xFFFF00)
        end
    end

    if not skipSave then
        saveRentItemsToJson()
    end

    return true
end

function setInventoryItemIdsEnabled(enabled, silent, skipSave)
    local normalized = enabled == true

    if inventoryItemIdsEnabled == normalized then
        ui.showInventoryItemIds[0] = normalized
        return false
    end

    inventoryItemIdsEnabled = normalized
    ui.showInventoryItemIds[0] = normalized
    inventoryIdOverlayNextTick = 0

    if inventoryItemIdsEnabled then
        applyInventoryItemIdsOverlay()
        if not silent then
            sampAddChatMessage("[АРЕНДА] Информация об ID предметов {00FF00}включена{FFFF00}. Откройте /invent.", 0xFFFF00)
        end
    else
        clearInventoryItemIdsOverlay()
        if not silent then
            sampAddChatMessage("[АРЕНДА] Информация об ID предметов {FF8000}выключена{FFFF00}.", 0xFFFF00)
        end
    end

    if not skipSave then
        saveRentItemsToJson()
    end

    return true
end

function queueEscPresses(presses, delay, interval)
    presses = tonumber(presses)
    if presses == nil then
        presses = 1
    end

    if presses < 1 then
        return
    end

    delay = tonumber(delay) or 250
    interval = tonumber(interval) or 120

    lua_thread.create(
        function()
            wait(delay)

            for i = 1, presses do
                if setVirtualKeyDown then
                    pcall(setVirtualKeyDown, 27, true)
                    wait(50)
                    pcall(setVirtualKeyDown, 27, false)
                else
                    break
                end

                if i < presses then
                    wait(interval)
                end
            end
        end
    )
end

function stopScript(msg, color, opts)
    opts = opts or {}
    if msg then
        sampAddChatMessage("[АРЕНДА] " .. msg, color or 0xFFFF00)
    end

    enable = false
    mode = "check"
    resetDialogSessionState()
    rentChainActive = false
    rentCfg = nil

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetScanSessionState()
    resetSetRentSession()
    resetSetCheckSession()
    resetSetViewScanSession()

    local escPresses = tonumber(opts.escPresses)
    if escPresses == nil then
        escPresses = 1
    end
    local escDelay = tonumber(opts.escDelay) or 250
    local escInterval = tonumber(opts.escInterval) or 120

    if escPresses < 0 then
        escPresses = 0
    end

    if escPresses > 0 then
        queueEscPresses(escPresses, escDelay, escInterval)
    end
end

function stopWithInventoryCloseCef(msg, color, escDelay, closeInterval)
    local escDelayValue = tonumber(escDelay) or 250
    local closeIntervalValue = tonumber(closeInterval) or 120

    stopScript(
        msg,
        color,
        {
            escPresses = 1,
            escDelay = escDelayValue,
            escInterval = closeIntervalValue
        }
    )
    closeInventoryViaCef(escDelayValue + 50 + closeIntervalValue, 1, 0)
end

function stopWithInventoryCloseEsc2(msg, color, escDelay, escInterval)
    stopWithInventoryCloseCef(msg, color, escDelay, escInterval)
end

function stopWithInventoryClose(msg, color)
    stopWithInventoryCloseCef(msg, color, 60, 120)
end

function stopWithInventoryCloseDefault(msg, color)
    stopWithInventoryCloseCef(msg, color, 250, 120)
end

function stopAutoRentByServerError(reason)
    if enable and mode == "auto_rent" then
        stopWithInventoryClose("Сдача отменена. " .. reason .. ".", 0xFFFF00)
    end
end

resetManualMinuteRentState = function()
    manualMinuteRent.active = false
    manualMinuteRent.stage = ""
    manualMinuteRent.currentDialogId = 0
    manualMinuteRent.noticeShown = false
    manualMinuteRent.currencyReady = false
    manualMinuteRent.closeMainRequested = false

    manualMinuteRent.minutes[0] = MINUTE_RENT_LIMITS.minutesMin
    applyMinutePriceLimits(lastCurrency or "SA$")
    manualMinuteRent.price[0] = manualMinuteRent.priceMin
end

function isManualMinuteRentActive()
    return manualMinuteRent.active and enable and mode == "auto_rent" and rentChainActive and rentCfg ~= nil
end

function isMinuteRentDialog(text)
    local clean = stripColorCodes(text or ""):gsub("\r", "\n")
    return clean:find(PAT_MINUTE_RENT_PROMPT, 1, true) ~= nil
end

function openManualMinuteRent()
    if manualMinuteRent.active then
        manualMinuteRent.currentDialogId = DIALOG_ID_RENT_HOURS
        if manualMinuteRent.stage == "probe_wait_hours" then
            manualMinuteRent.stage = "minutes"
            manualMinuteRent.noticeShown = false
        end
        return
    end

    manualMinuteRent.active = true
    manualMinuteRent.stage = "probe_wait_price"
    manualMinuteRent.currentDialogId = DIALOG_ID_RENT_HOURS
    manualMinuteRent.noticeShown = false
    manualMinuteRent.currencyReady = false
    manualMinuteRent.closeMainRequested = true

    manualMinuteRent.minutes[0] = MINUTE_RENT_LIMITS.minutesMin
    applyMinutePriceLimits(lastCurrency or "SA$")
    manualMinuteRent.price[0] = manualMinuteRent.priceMin


    sampAddChatMessage("[АРЕНДА] " .. TXT_MINUTE_MANUAL_STARTED, 0xFFFF00)
    sampAddChatMessage("[АРЕНДА] " .. TXT_MINUTE_MANUAL_HINT, 0xFFFF00)
    lua_thread.create(
        function()
            wait(140)
            if not isManualMinuteRentActive() then
                return
            end
            sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 1, 0, tostring(MINUTE_RENT_LIMITS.minutesMin))
        end
    )
end

function onManualMinutePriceDialog(text)
    local limits = parseHourlyLimits(text)
    local clean = stripColorCodes(text or "")

    local currency = nil
    if clean:find(":cashv:%s*50") or clean:find("VC%$%s*50") then
        currency = "VC$"
    elseif clean:find(":cash:%s*5000") or clean:find("SA%$%s*5000") or clean:find("%$%s*5000") then
        currency = "SA$"
    elseif limits and limits.currency then
        currency = limits.currency
    end

    currency = currency or lastCurrency or "SA$"

    applyMinutePriceLimits(currency)
    lastCurrency = manualMinuteRent.currency
    clampManualMinuteValues()

    manualMinuteRent.currentDialogId = DIALOG_ID_RENT_PRICE
    manualMinuteRent.noticeShown = false

    if manualMinuteRent.stage == "probe_wait_price" then
        manualMinuteRent.stage = "probe_wait_hours"
        manualMinuteRent.currencyReady = true

        lua_thread.create(
            function()
                wait(140)
                if not isManualMinuteRentActive() then
                    return
                end
                sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 0, 0, "")
            end
        )
        return
    end

    if manualMinuteRent.stage == "price_wait" then
        local submitPrice = manualMinuteRent.price[0]
        if submitPrice < manualMinuteRent.priceMin or submitPrice > manualMinuteRent.priceMax then
            local minStr = formatMoney(manualMinuteRent.priceMin, manualMinuteRent.currency)
            local maxStr = formatMoney(manualMinuteRent.priceMax, manualMinuteRent.currency)
            sampAddChatMessage("[АРЕНДА] " .. string.format(FMT_ALLOWED_RANGE, minStr, maxStr), 0xFFFF00)
            manualMinuteRent.stage = "price"
            return
        end

        if rentCfg then
            rentCfg.hourly = submitPrice
            rentCfg.manualFlowUsed = true
        end

        resetManualMinuteRentState()

        lua_thread.create(
            function()
                wait(140)
                if not (enable and mode == "auto_rent" and rentChainActive) then
                    return
                end
                sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 1, 0, tostring(submitPrice))
            end
        )
        return
    end

    manualMinuteRent.stage = "price"
end
function continueManualMinuteRentFlow()
    if not isManualMinuteRentActive() then
        return
    end

    clampManualMinuteValues()

    if manualMinuteRent.stage == "probe_wait_price" or manualMinuteRent.stage == "probe_wait_hours" then
        if not manualMinuteRent.noticeShown then
            sampAddChatMessage("[АРЕНДА] " .. TXT_MINUTE_CURRENCY_WAIT, 0xFFFF00)
            manualMinuteRent.noticeShown = true
        end
        return
    end

    if manualMinuteRent.stage == "minutes" then
        local submitMinutes = manualMinuteRent.minutes[0]

        manualMinuteRent.stage = "price_wait"
        manualMinuteRent.currentDialogId = DIALOG_ID_RENT_HOURS
        manualMinuteRent.noticeShown = false

        lua_thread.create(
            function()
                wait(140)
                if not isManualMinuteRentActive() then
                    return
                end
                sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 1, 0, tostring(submitMinutes))
            end
        )
        return
    end

    if manualMinuteRent.stage == "price_wait" then
        if not manualMinuteRent.noticeShown then
            sampAddChatMessage("[АРЕНДА] " .. TXT_MINUTE_PRICE_WAIT, 0xFFFF00)
            manualMinuteRent.noticeShown = true
        end
        return
    end

    if manualMinuteRent.stage ~= "price" then
        return
    end

    local submitPrice = manualMinuteRent.price[0]
    if submitPrice < manualMinuteRent.priceMin or submitPrice > manualMinuteRent.priceMax then
        local minStr = formatMoney(manualMinuteRent.priceMin, manualMinuteRent.currency)
        local maxStr = formatMoney(manualMinuteRent.priceMax, manualMinuteRent.currency)
        sampAddChatMessage("[АРЕНДА] " .. string.format(FMT_ALLOWED_RANGE, minStr, maxStr), 0xFFFF00)
        return
    end

    if rentCfg then
        rentCfg.hourly = submitPrice
        rentCfg.manualFlowUsed = true
    end

    resetManualMinuteRentState()

    lua_thread.create(
        function()
            wait(140)
            if not (enable and mode == "auto_rent" and rentChainActive) then
                return
            end
            sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 1, 0, tostring(submitPrice))
        end
    )
end
function stopManualMinuteRentFlow()
    if not manualMinuteRent.active then
        return
    end

    local currentDialogId = manualMinuteRent.currentDialogId
    resetManualMinuteRentState()

    lua_thread.create(
        function()
            wait(140)

            if currentDialogId == DIALOG_ID_RENT_PRICE then
                sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 0, 0, "")
                wait(280)
                sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 0, 0, "")
            else
                sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 0, 0, "")
                wait(280)
                sampSendDialogResponse(DIALOG_ID_RENT_TARGET, 0, 0, "")
            end

            wait(280)
            stopScript(TXT_MINUTE_FLOW_STOPPED, 0xFFFF00, {escPresses = 1, escDelay = 60, escInterval = 120})
        end
    )
end
function formatSlotList(slots, maxShown)
    if type(slots) ~= "table" or #slots == 0 then
        return ""
    end

    maxShown = tonumber(maxShown) or 10
    if maxShown < 1 then
        maxShown = 1
    end

    local shown = math.min(#slots, maxShown)
    local parts = {}

    for i = 1, shown do
        parts[#parts + 1] = tostring(slots[i])
    end

    local text = table.concat(parts, ", ")
    if #slots > shown then
        text = text .. " +" .. tostring(#slots - shown)
    end

    return text
end

function finishScan()
    if mode == "check" then
        if isSetCheckSessionActive() then
            handleSetCheckScanResult()
            return
        end

        if isSetViewScanActive() then
            handleSetViewScanResult()
            return
        end

        if processedCount == 0 then
            stopWithInventoryCloseDefault("Предметы с ID " .. itemID .. " не найдены.", 0xFFFF00)
            return
        end

        if notRentedFound then
            local notRentedCount = #notRentedSlots
            local slotsText = formatSlotList(notRentedSlots, 12)
            local msg =
                "Сканирование завершено: найден(ы) предмет(ы) НЕ в аренде. ID: " ..
                itemID .. ". Кол-во: " .. notRentedCount

            if slotsText ~= "" then
                msg = msg .. ". Ячейки: " .. slotsText
            end

            stopWithInventoryCloseDefault(msg, 0xFF8000)
        else
            stopWithInventoryCloseDefault(
                "Сканирование завершено: все предметы с ID " .. itemID .. " в аренде.",
                0x00FF00
            )
        end
        return
    end

    if mode == "auto_rent" then
        if isSetRentSessionActive() then
            finishSetRentStep(false, "предмет не найден или уже в аренде")
        else
            stopWithInventoryCloseDefault("Предмет без аренды не найден (все в аренде или предметов нет).", 0xFF8000)
        end
        return
    end

    stopWithInventoryCloseDefault("Завершено.", 0xFFFF00)
end

function clickInventoryItemByIndex(index)
    currentInventorySlot = nil
    currentInventorySlotScanIndex = math.floor(tonumber(index) or scanIndex)
    evalanon(
        [[
        (function() {
            const imgs = document.querySelectorAll('img[alt="ID:]] ..
            itemID ..
                [["]');
            if (!imgs || imgs.length === 0) { console.log("Предметы не найдены"); return; }

            const idx = ]] ..
                    index ..
                        [[;
            if (idx < 0 || idx >= imgs.length) { console.log("Индекс вне диапазона: " + idx + " / " + imgs.length); return; }

            const img = imgs[idx];
            const item = img.closest('.inventory-item');
            if (!item) { console.log("Не найден .inventory-item"); return; }

            const evt = new MouseEvent("contextmenu", { bubbles: true, cancelable: true, button: 2 });
            item.dispatchEvent(evt);

            let attempts = 0;
            const normalizeText = (value) => (value || '').replace(/\s+/g, ' ').trim().toUpperCase();
            const targetText = 'СДАТЬ В АРЕНДУ';

            const clickTargetButton = () => {
                const labels = Array.from(document.querySelectorAll('.inventory-button--context .inventory-button__text'));
                if (labels.length === 0) {
                    return false;
                }

                for (const label of labels) {
                    const btn = label.closest('.inventory-button') || label;
                    const labelText = normalizeText(label.textContent);
                    const btnText = normalizeText(btn.textContent);

                    if (labelText.includes(targetText) || btnText.includes(targetText)) {
                        btn.click();
                        return true;
                    }
                }

                return false;
            };

            const interval = setInterval(() => {
                if (clickTargetButton()) {
                    clearInterval(interval);
                    return;
                }

                attempts++;
                if (attempts > 20) clearInterval(interval);
            }, 100);
        })();
    ]]
    )
end

function startCheck(customItemId, customTitle)
    local targetItemId = tonumber(customItemId)

    if targetItemId then
        targetItemId = math.floor(targetItemId)
        if targetItemId < 1 then
            sampAddChatMessage("[АРЕНДА] Некорректный ID для проверки.", 0xFFFF00)
            return false
        end
        itemID = targetItemId
    else
        if not ensureRentItemSelected() then
            return false
        end
    end

    enable = true
    mode = "check"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false
    rentCfg = nil

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetSetRentSession()

    if not (isSetCheckSessionActive() and targetItemId) then
        resetSetCheckSession()
    end

    local checkTitle = tostring(customTitle or getSelectedItemName())
    if checkTitle == "" then
        checkTitle = cp1251("Предмет")
    end

    sampAddChatMessage(
        string.format("[АРЕНДА] Поиск предметов начат. %s [ID: %d]", checkTitle, itemID),
        0x00FF00
    )

    return true
end

function buildSetRentItemIds(set)
    local ids = {}

    if type(set) ~= "table" or type(set.itemIds) ~= "table" then
        return ids
    end

    for i = 1, #set.itemIds do
        local id = tonumber(set.itemIds[i])
        if id and id >= 1 and id == math.floor(id) then
            table.insert(ids, id)
        end
    end

    return ids
end

function getRentItemNameById(itemId)
    for i = 1, #rentItems do
        local it = rentItems[i]
        if tonumber(it.id) == itemId then
            local name = tostring(it.name or "")
            if name ~= "" then
                return name
            end
            break
        end
    end

    return cp1251("Предмет")
end

function createEmptySetScanCache()
    return {
        lastScanAt = 0,
        statuses = {},
        statusByItemId = {},
        rentUntilByItemId = {}
    }
end

function normalizeSetScanCache(cache, validItemIds)
    local normalized = createEmptySetScanCache()

    local allowedIds = {}
    if type(validItemIds) == "table" then
        for i = 1, #validItemIds do
            local id = tonumber(validItemIds[i])
            if id and id >= 1 and id == math.floor(id) then
                allowedIds[id] = true
            end
        end
    end

    local hasAllowedIds = next(allowedIds) ~= nil

    local function normalizeAllowedItemId(rawId)
        local id = tonumber(rawId)
        if not id then
            return nil
        end

        id = math.floor(id)
        if id < 1 then
            return nil
        end

        if hasAllowedIds and not allowedIds[id] then
            return nil
        end

        return id
    end

    local function applyStatus(rawId, rawStatus)
        local id = normalizeAllowedItemId(rawId)
        if not id then
            return
        end

        local status = tostring(rawStatus or SET_VIEW_STATUS.UNKNOWN)
        if status ~= SET_VIEW_STATUS.FREE and status ~= SET_VIEW_STATUS.BUSY and status ~= SET_VIEW_STATUS.MISSING then
            status = SET_VIEW_STATUS.UNKNOWN
        end

        normalized.statusByItemId[id] = status
    end

    local function applyRentUntil(rawId, rawRentUntil)
        local id = normalizeAllowedItemId(rawId)
        if not id then
            return
        end

        if type(rawRentUntil) ~= "string" then
            return
        end

        local rentUntil = trim(rawRentUntil)
        if rentUntil == "" then
            normalized.rentUntilByItemId[id] = nil
            return
        end

        normalized.rentUntilByItemId[id] = rentUntil
    end

    if type(cache) == "table" then
        local lastScanAt = tonumber(cache.lastScanAt) or 0
        if lastScanAt > 0 then
            normalized.lastScanAt = math.floor(lastScanAt)
        end

        if type(cache.statuses) == "table" then
            for i = 1, #cache.statuses do
                local row = cache.statuses[i]
                if type(row) == "table" then
                    applyStatus(row.id, row.status)
                    applyRentUntil(row.id, row.rentUntil)
                end
            end
        end

        if type(cache.statusByItemId) == "table" then
            for key, value in pairs(cache.statusByItemId) do
                applyStatus(key, value)
            end
        end

        if type(cache.rentUntilByItemId) == "table" then
            for key, value in pairs(cache.rentUntilByItemId) do
                applyRentUntil(key, value)
            end
        end
    end

    for id, status in pairs(normalized.statusByItemId) do
        local row = {id = id, status = status}

        if status == SET_VIEW_STATUS.BUSY then
            local rentUntil = normalized.rentUntilByItemId[id]
            if type(rentUntil) == "string" and rentUntil ~= "" then
                row.rentUntil = rentUntil
            else
                normalized.rentUntilByItemId[id] = nil
            end
        else
            normalized.rentUntilByItemId[id] = nil
        end

        table.insert(normalized.statuses, row)
    end

    table.sort(
        normalized.statuses,
        function(a, b)
            return (a.id or 0) < (b.id or 0)
        end
    )

    return normalized
end

function serializeSetScanCache(cache, validItemIds)
    local normalized = normalizeSetScanCache(cache, validItemIds)
    return {
        lastScanAt = normalized.lastScanAt,
        statuses = normalized.statuses
    }
end

function getSetViewLastScanAgeSeconds()
    local lastScanAt = tonumber(setViewWindowState.lastScanAt) or 0
    if lastScanAt <= 0 then
        return nil
    end

    local age = os.time() - lastScanAt
    if age < 0 then
        age = 0
    end

    return age
end

function isSetViewScanFresh()
    local ageSeconds = getSetViewLastScanAgeSeconds()
    if not ageSeconds then
        return false
    end

    return ageSeconds <= SET_VIEW_SCAN_FRESH_SECONDS
end

function getSetViewLastScanText()
    local ageSeconds = getSetViewLastScanAgeSeconds()
    if not ageSeconds then
        return uiLabel("SET_VIEW_LAST_SCAN_NEVER")
    end

    if ageSeconds < 60 then
        return uiLabel("SET_VIEW_LAST_SCAN_JUST_NOW")
    end

    local minutesAgo = math.floor(ageSeconds / 60)
    return uiLabelFmt("SET_VIEW_LAST_SCAN_MINUTES_FMT", minutesAgo)
end

function resetSetViewScanSession()
    setViewWindowState.scanning = false
    setViewWindowState.cursor = 0
end

function isSetViewScanActive()
    return setViewWindowState.scanning == true
end

function rebuildSetViewFreeItems()
    local freeIds = {}

    for i = 1, #setViewWindowState.itemIds do
        local itemId = tonumber(setViewWindowState.itemIds[i]) or 0
        if itemId > 0 and setViewWindowState.statusByItemId[itemId] == SET_VIEW_STATUS.FREE then
            table.insert(freeIds, itemId)
        end
    end

    setViewWindowState.freeItemIds = freeIds
end

function setSetViewItemStatus(itemId, status, rentUntil)
    if type(itemId) ~= "number" or itemId < 1 then
        return
    end

    if status ~= SET_VIEW_STATUS.FREE and status ~= SET_VIEW_STATUS.BUSY and status ~= SET_VIEW_STATUS.MISSING then
        status = SET_VIEW_STATUS.UNKNOWN
    end

    setViewWindowState.statusByItemId[itemId] = status

    if status == SET_VIEW_STATUS.BUSY and type(rentUntil) == "string" then
        rentUntil = trim(rentUntil)
        if rentUntil ~= "" then
            setViewWindowState.rentUntilByItemId[itemId] = rentUntil
        else
            setViewWindowState.rentUntilByItemId[itemId] = nil
        end
    else
        setViewWindowState.rentUntilByItemId[itemId] = nil
    end

    rebuildSetViewFreeItems()
end

function syncSetViewWindowSetData()
    local index = tonumber(setViewWindowState.setIndex) or 0
    index = math.floor(index)

    if index < 1 or index > #rentSets then
        return false
    end

    local set = rentSets[index]
    if type(set) ~= "table" then
        return false
    end

    setViewWindowState.setIndex = index
    setViewWindowState.setName = tostring(set.name or (cp1251("Сет ") .. tostring(index)))
    setViewWindowState.itemIds = buildSetRentItemIds(set)

    local cacheSource = set.scanCache
    if isSetViewScanActive() and setViewWindowState.setIndex == index then
        cacheSource = {
            lastScanAt = setViewWindowState.lastScanAt,
            statusByItemId = setViewWindowState.statusByItemId,
            rentUntilByItemId = setViewWindowState.rentUntilByItemId
        }
    end

    local normalizedCache = normalizeSetScanCache(cacheSource, setViewWindowState.itemIds)
    setViewWindowState.statusByItemId = normalizedCache.statusByItemId
    setViewWindowState.rentUntilByItemId = normalizedCache.rentUntilByItemId
    setViewWindowState.lastScanAt = normalizedCache.lastScanAt
    rebuildSetViewFreeItems()

    set.scanCache = normalizedCache
    return true
end

function persistSetViewScanCache(saveNow)
    local index = tonumber(setViewWindowState.setIndex) or 0
    index = math.floor(index)
    if index < 1 or index > #rentSets then
        return false
    end

    local set = rentSets[index]
    if type(set) ~= "table" then
        return false
    end

    local cache = normalizeSetScanCache(
        {
            lastScanAt = setViewWindowState.lastScanAt,
            statusByItemId = setViewWindowState.statusByItemId,
            rentUntilByItemId = setViewWindowState.rentUntilByItemId
        },
        setViewWindowState.itemIds
    )

    set.scanCache = cache

    if saveNow then
        saveRentItemsToJson()
    end

    return true
end

function openSetViewWindow(index)
    if isSetViewScanActive() and enable and mode == "check" then
        stopScript("Проверка сета остановлена.", 0xFFFF00, {escPresses = 0})
    end

    index = tonumber(index)
    if not index then
        return false
    end

    index = math.floor(index)
    if index < 1 or index > #rentSets then
        return false
    end

    local isSetViewWindowVisible = showSetViewWindow[0] or (setViewWindowMenu and setViewWindowMenu.alpha > 0.00)
    local currentSetViewIndex = tonumber(setViewWindowState.setIndex) or 0

    if isSetViewWindowVisible and currentSetViewIndex == index then
        showSetViewWindow[0] = false
        setViewWindowCloseHandled = false
        saveRentItemsToJson()
        return true
    end

    if not selectRentSet(index) then
        return false
    end

    setViewWindowState.setIndex = index
    if not syncSetViewWindowSetData() then
        return false
    end

    resetSetViewScanSession()
    showSetViewWindow[0] = true
    setViewWindowCloseHandled = false
    if setViewWindowMenu and not setViewWindowMenu.state then
        setViewWindowMenu.switch()
    end
    saveRentItemsToJson()
    return true
end


function startNextSetViewScanStep()
    if not isSetViewScanActive() then
        return false
    end

    local totalItems = #setViewWindowState.itemIds
    if totalItems == 0 then
        resetSetViewScanSession()
        stopScript("В сете нет валидных ID для проверки.", 0xFFFF00, {escPresses = 0})
        return false
    end

    if setViewWindowState.cursor >= totalItems then
        local freeCount = #setViewWindowState.freeItemIds
        local setName = tostring(setViewWindowState.setName or cp1251("Сет"))

        setViewWindowState.lastScanAt = os.time()
        persistSetViewScanCache(true)
        resetSetViewScanSession()
        stopWithInventoryCloseDefault(
            string.format("Проверка сета \"%s\" завершена. Свободных: %d/%d.", setName, freeCount, totalItems),
            0x00FF00
        )
        return true
    end

    setViewWindowState.cursor = setViewWindowState.cursor + 1

    local currentItemId = tonumber(setViewWindowState.itemIds[setViewWindowState.cursor]) or 0
    if currentItemId < 1 then
        return startNextSetViewScanStep()
    end

    local checkTitle =
        string.format("Проверка сета \"%s\" (%d/%d)", setViewWindowState.setName, setViewWindowState.cursor, totalItems)
    return startCheck(currentItemId, checkTitle)
end

function startSetViewScan()
    if not showSetViewWindow[0] then
        return false
    end

    if not syncSetViewWindowSetData() then
        showSetViewWindow[0] = false
        setViewWindowCloseHandled = true
        resetSetViewScanSession()
        return false
    end

    if enable then
        sampAddChatMessage("[АРЕНДА] Сначала остановите активный процесс, затем обновите список.", 0xFFFF00)
        return false
    end

    setViewWindowState.statusByItemId = {}
    setViewWindowState.rentUntilByItemId = {}
    setViewWindowState.freeItemIds = {}

    for i = 1, #setViewWindowState.itemIds do
        local itemId = tonumber(setViewWindowState.itemIds[i]) or 0
        if itemId > 0 then
            setViewWindowState.statusByItemId[itemId] = SET_VIEW_STATUS.UNKNOWN
        end
    end

    if #setViewWindowState.itemIds == 0 then
        resetSetViewScanSession()
        return false
    end

    setViewWindowState.scanning = true
    setViewWindowState.cursor = 0
    return startNextSetViewScanStep()
end

function handleSetViewScanResult()
    if not isSetViewScanActive() then
        return false
    end

    local currentItemId = tonumber(setViewWindowState.itemIds[setViewWindowState.cursor]) or 0
    if currentItemId > 0 then
        if processedCount == 0 then
            setSetViewItemStatus(currentItemId, SET_VIEW_STATUS.MISSING)
        elseif notRentedFound then
            setSetViewItemStatus(currentItemId, SET_VIEW_STATUS.FREE)
        else
            setSetViewItemStatus(currentItemId, SET_VIEW_STATUS.BUSY, rentedUntil)
        end
    end

    return startNextSetViewScanStep()
end

function runSetViewRentFreeItemsFromUi()
    if isSetViewScanActive() then
        sampAddChatMessage("[АРЕНДА] Дождитесь завершения проверки сета.", 0xFFFF00)
        return false
    end

    if enable then
        sampAddChatMessage("[АРЕНДА] Сначала остановите активный процесс.", 0xFFFF00)
        return false
    end

    if not syncSetViewWindowSetData() then
        sampAddChatMessage("[АРЕНДА] Сет из окна просмотра больше недоступен.", 0xFFFF00)
        return false
    end

    if not isSetViewScanFresh() then
        sampAddChatMessage("[АРЕНДА] Прошло более 5 минут с последней проверки сета. Нажмите «Проверить».", 0xFFFF00)
        return false
    end

    if not selectRentSet(setViewWindowState.setIndex) then
        sampAddChatMessage("[АРЕНДА] Не удалось выбрать сет для запуска.", 0xFFFF00)
        return false
    end

    local ids = {}
    for i = 1, #setViewWindowState.freeItemIds do
        local itemId = tonumber(setViewWindowState.freeItemIds[i]) or 0
        if itemId > 0 then
            table.insert(ids, itemId)
        end
    end

    if #ids == 0 then
        sampAddChatMessage("[АРЕНДА] Свободных предметов в сете не найдено.", 0xFFFF00)
        return false
    end

    local modeKind = tostring(activeRentModeTab or "hours")

    if modeKind == "days" then
        local pid = ui.daysPid[0]
        local days = ui.daysCount[0]
        local total = getMoneyInputValue(ui.daysTotal)

        if not validatePlayerForUi(pid) then
            return false
        end

        if not isIntInRange(days, LIMITS.daysMin, LIMITS.daysMax) then
            sampAddChatMessage(
                string.format("[АРЕНДА] Дней должно быть от %d до %d.", LIMITS.daysMin, LIMITS.daysMax),
                0xFFFF00
            )
            return false
        end

        if total < 1 then
            sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
            return false
        end

        return startAutoRentForSetItemIds(
            "days",
            pid,
            days,
            nil,
            total,
            ids,
            setViewWindowState.setName,
            setViewWindowState.setIndex
        )
    end

    if modeKind == "restart" then
        local pid = ui.restartPid[0]
        local total = getMoneyInputValue(ui.restartTotal)

        if not validatePlayerForUi(pid) then
            return false
        end

        if total < 1 then
            sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
            return false
        end

        return startAutoRentForSetItemIds(
            "restart",
            pid,
            nil,
            nil,
            total,
            ids,
            setViewWindowState.setName,
            setViewWindowState.setIndex
        )
    end

    if modeKind == "max" then
        local pid = ui.maxPid[0]
        local total = getMoneyInputValue(ui.maxTotal)

        if not validatePlayerForUi(pid) then
            return false
        end

        if total < 1 then
            sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
            return false
        end

        return startAutoRentForSetItemIds(
            "max",
            pid,
            nil,
            nil,
            total,
            ids,
            setViewWindowState.setName,
            setViewWindowState.setIndex
        )
    end

    local pid = ui.hoursPid[0]
    local hours = ui.hoursCount[0]
    local total = getMoneyInputValue(ui.hoursPrice)

    if not validatePlayerForUi(pid) then
        return false
    end

    if not isIntInRange(hours, LIMITS.hoursMin, LIMITS.hoursMax) then
        sampAddChatMessage(
            string.format("[АРЕНДА] Часов должно быть от %d до %d.", LIMITS.hoursMin, LIMITS.hoursMax),
            0xFFFF00
        )
        return false
    end

    if total < 1 then
        sampAddChatMessage("[АРЕНДА] Сумма за весь срок должна быть больше 0.", 0xFFFF00)
        return false
    end

    return startAutoRentForSetItemIds(
        "hours",
        pid,
        nil,
        hours,
        total,
        ids,
        setViewWindowState.setName,
        setViewWindowState.setIndex
    )
end

function startNextSetCheckStep()
    if not isSetCheckSessionActive() then
        return false
    end

    local totalItems = #setCheckSession.itemIds
    if totalItems == 0 then
        stopWithInventoryCloseDefault("Сет пуст. Проверка остановлена.", 0xFFFF00)
        return false
    end

    if setCheckSession.cursor >= totalItems then
        stopWithInventoryCloseDefault(
            string.format("Сет \"%s\" полный, можно сдать в аренду.", setCheckSession.setName),
            0x00FF00
        )
        return true
    end

    setCheckSession.cursor = setCheckSession.cursor + 1

    local currentItemId = tonumber(setCheckSession.itemIds[setCheckSession.cursor]) or 0
    if currentItemId < 1 then
        stopWithInventoryCloseDefault(
            string.format("Сет \"%s\" нельзя сдать. Причина: некорректный ID в составе сета.", setCheckSession.setName),
            0xFF8000
        )
        return false
    end

    local checkTitle = string.format("Проверка сета \"%s\" (%d/%d)", setCheckSession.setName, setCheckSession.cursor, totalItems)
    return startCheck(currentItemId, checkTitle)
end

function handleSetCheckScanResult()
    if not isSetCheckSessionActive() then
        return false
    end

    local totalItems = #setCheckSession.itemIds
    local currentItemId = tonumber(setCheckSession.itemIds[setCheckSession.cursor]) or itemID

    if processedCount == 0 then
        stopWithInventoryCloseDefault(
            string.format(
                "Сет \"%s\" нельзя сдать. Причина: предмет с ID %d не найден. Неполный сет.",
                setCheckSession.setName,
                currentItemId
            ),
            0xFF8000
        )
        return true
    end

    if not notRentedFound then
        stopWithInventoryCloseDefault(
            string.format(
                "Сет \"%s\" нельзя сдать. Причина: предмет с ID %d в аренде. Неполный сет.",
                setCheckSession.setName,
                currentItemId
            ),
            0xFF8000
        )
        return true
    end

    sampAddChatMessage(
        string.format(
            "[АРЕНДА][ПРОВЕРКА СЕТА] ID %d доступен. Проверено: %d/%d.",
            currentItemId,
            setCheckSession.cursor,
            totalItems
        ),
        0x00FF00
    )

    startNextSetCheckStep()
    return true
end

function startSetCheck()
    if not ensureRentSetSelected() then
        return false
    end

    local set = getSelectedRentSet()
    local ids = buildSetRentItemIds(set)
    if #ids == 0 then
        sampAddChatMessage("[АРЕНДА] В выбранном сете нет валидных ID предметов.", 0xFFFF00)
        return false
    end

    resetSetCheckSession()
    setCheckSession.active = true
    setCheckSession.setIndex = selectedRentSetIndex
    setCheckSession.setName = tostring(set.name or (cp1251("Сет ") .. tostring(selectedRentSetIndex)))
    setCheckSession.itemIds = ids
    setCheckSession.cursor = 0

    sampAddChatMessage(
        string.format("[АРЕНДА][ПРОВЕРКА СЕТА] Запущено: %s | Предметов в сете: %d.", setCheckSession.setName, #ids),
        0x00FF00
    )

    return startNextSetCheckStep()
end

function getSetRentFlowLabel(modeKind)
    if modeKind == "days" then
        return RENT_MODE_LABEL_DAYS
    end
    if modeKind == "hours" then
        return RENT_MODE_LABEL_HOURS
    end
    if modeKind == "restart" then
        return RENT_MODE_LABEL_RESTART
    end
    return RENT_MODE_LABEL_MAX
end

function scheduleNextSetRentStep(delayMs)
    local delay = tonumber(delayMs) or 280
    if delay < 0 then
        delay = 0
    end

    lua_thread.create(
        function()
            wait(delay)
            if isSetRentSessionActive() then
                startNextSetRentStep()
            end
        end
    )
end

function finishSetRentStep(success, reason)
    if not isSetRentSessionActive() then
        return false
    end

    local currentItemId = setRentSession.itemIds[setRentSession.cursor] or itemID
    if success then
        setRentSession.completed = setRentSession.completed + 1
        sampAddChatMessage(
            string.format("[АРЕНДА][СЕТ] Шаг %d/%d выполнен. ID: %d.", setRentSession.cursor, #setRentSession.itemIds, currentItemId),
            0x00FF00
        )
    else
        setRentSession.failed = setRentSession.failed + 1
        local failReason = tostring(reason or "пропуск")
        sampAddChatMessage(
            string.format(
                "[АРЕНДА][СЕТ] Шаг %d/%d пропущен. ID: %d. Причина: %s.",
                setRentSession.cursor,
                #setRentSession.itemIds,
                currentItemId,
                failReason
            ),
            0xFF8000
        )
    end

    awaitingConfirm = false
    awaitingConfirmStart = 0
    awaitingConfirmPid = nil
    awaitingConfirmManual = false
    waitingForDialog = false
    dialogWaitStart = 0
    noDialogTries = 0
    attemptCount = 0
    busy = true
    rentChainActive = false
    rentCfg = nil
    resetManualMinuteRentState()

    local nextDelay = success and 6000 or 280
    scheduleNextSetRentStep(nextDelay)
    return true
end

function startNextSetRentStep()
    if not isSetRentSessionActive() then
        return false
    end

    local totalItems = #setRentSession.itemIds
    if totalItems == 0 then
        stopScript("Сет пуст. Процесс остановлен.", 0xFFFF00, {escPresses = 1})
        return false
    end

    if setRentSession.cursor >= totalItems then
        local successCount = setRentSession.completed
        local failCount = setRentSession.failed
        local allCount = totalItems
        local color = (failCount > 0) and 0xFF8000 or 0x00FF00
        local msg = string.format("Сет \"%s\" завершён. Успешно: %d/%d.", setRentSession.setName, successCount, allCount)
        if failCount > 0 then
            msg = msg .. string.format(" Пропущено: %d.", failCount)
        end
        if failCount == 0 and showSetViewWindow[0] then
            showSetViewWindow[0] = false
        end
        stopScript(msg, color, {escPresses = 0})
        return true
    end

    setRentSession.cursor = setRentSession.cursor + 1

    local itemId = tonumber(setRentSession.itemIds[setRentSession.cursor]) or 0
    if itemId < 1 then
        finishSetRentStep(false, "некорректный ID")
        return false
    end

    local hours = LIMITS.hoursMin
    local remMin = 0

    if setRentSession.modeKind == "days" then
        hours = (tonumber(setRentSession.days) or 1) * 24
    elseif setRentSession.modeKind == "hours" then
        hours = tonumber(setRentSession.hours) or LIMITS.hoursMin
    elseif setRentSession.modeKind == "restart" then
        hours, remMin = calcHoursToRestart()
    else
        hours = LIMITS.hoursMax
    end

    if hours < LIMITS.hoursMin then
        hours = LIMITS.hoursMin
    end
    if hours > LIMITS.hoursMax then
        hours = LIMITS.hoursMax
    end

    local perItemTotal = tonumber(setRentSession.perItemTotal) or 1
    if perItemTotal < 1 then
        perItemTotal = 1
    end

    local hourly = math.ceil(perItemTotal / hours)
    if hourly < 1 then
        hourly = 1
    end

    local actualTotal = hours * hourly

    itemID = itemId
    rentCfg = {
        pid = setRentSession.pid,
        days = math.floor(hours / 24),
        hours = hours,
        total = perItemTotal,
        hourly = hourly,
        actual = actualTotal,
        remMin = remMin,
        kind = "set_" .. tostring(setRentSession.modeKind),
        flowLabel = getSetRentFlowLabel(setRentSession.modeKind),
        msgMainPrinted = true,
        msgMoneyPrinted = true,
        setSession = true
    }

    enable = true
    mode = "auto_rent"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false

    resetManualMinuteRentState()
    resetAwaitingConfirmState()

    local nick = getNickById(setRentSession.pid)
    rentCfg.nick = nick

    sampAddChatMessage(
        string.format(
            "[АРЕНДА][СЕТ] %s | Шаг %d/%d | Ищу предмет ID: %d.",
            setRentSession.setName,
            setRentSession.cursor,
            totalItems,
            itemId
        ),
        0x00FF00
    )

    if lastCurrency then
        sampAddChatMessage(
            string.format(
                "[АРЕНДА][СЕТ] Игрок: %s | %s | Цена: %s/ч | Итого за предмет: %s",
                nick,
                getSetRentFlowLabel(setRentSession.modeKind),
                formatMoney(hourly, lastCurrency),
                formatMoney(actualTotal, lastCurrency)
            ),
            0x00FF00
        )
    end

    return true
end

function startAutoRentForSetItemIds(modeKind, pid, days, hours, totalSum, itemIds, setName, setIndex)
    if type(itemIds) ~= "table" or #itemIds == 0 then
        sampAddChatMessage("[АРЕНДА] Нет предметов для запуска аренды.", 0xFFFF00)
        return false
    end

    local ids = {}
    for i = 1, #itemIds do
        local id = tonumber(itemIds[i])
        if id and id >= 1 and id == math.floor(id) then
            table.insert(ids, id)
        end
    end

    if #ids == 0 then
        sampAddChatMessage("[АРЕНДА] Нет валидных ID предметов для запуска аренды.", 0xFFFF00)
        return false
    end

    totalSum = tonumber(totalSum) or 0
    if totalSum < 1 then
        totalSum = 1
    end

    local perItemTotal = math.ceil(totalSum / #ids)
    if perItemTotal < 1 then
        perItemTotal = 1
    end

    local resolvedSetIndex = tonumber(setIndex)
    if not resolvedSetIndex or resolvedSetIndex < 1 then
        resolvedSetIndex = selectedRentSetIndex
    end

    local resolvedSetName = tostring(setName or (cp1251("Сет ") .. tostring(resolvedSetIndex)))
    if resolvedSetName == "" then
        resolvedSetName = cp1251("Сет ") .. tostring(resolvedSetIndex)
    end

    resetSetRentSession()
    resetSetCheckSession()
    setRentSession.active = true
    setRentSession.setIndex = resolvedSetIndex
    setRentSession.setName = resolvedSetName
    setRentSession.itemIds = ids
    setRentSession.cursor = 0
    setRentSession.modeKind = tostring(modeKind or "days")
    setRentSession.pid = pid
    setRentSession.days = days or 1
    setRentSession.hours = hours or LIMITS.hoursMin
    setRentSession.total = totalSum
    setRentSession.perItemTotal = perItemTotal

    local modeLabel = getSetRentFlowLabel(setRentSession.modeKind)
    sampAddChatMessage(
        string.format(
            "[АРЕНДА][СЕТ] Запущено: %s | %s | Предметов: %d | Сумма за весь срок: %s",
            setRentSession.setName,
            modeLabel,
            #ids,
            formatMoney(totalSum, lastCurrency)
        ),
        0x00FF00
    )

    if #ids > 1 then
        sampAddChatMessage(
            string.format(
                "[АРЕНДА][СЕТ] Распределение: примерно %s за каждый предмет.",
                formatMoney(perItemTotal, lastCurrency)
            ),
            0xFFFF00
        )
    end

    return startNextSetRentStep()
end

function startAutoRentForSelectedSet(modeKind, pid, days, hours, totalSum)
    if not ensureRentSetSelected() then
        return false
    end

    local set = getSelectedRentSet()
    local ids = buildSetRentItemIds(set)
    if #ids == 0 then
        sampAddChatMessage("[АРЕНДА] В выбранном сете нет валидных ID предметов.", 0xFFFF00)
        return false
    end

    local setName = tostring(set.name or (cp1251("Сет ") .. tostring(selectedRentSetIndex)))
    return startAutoRentForSetItemIds(modeKind, pid, days, hours, totalSum, ids, setName, selectedRentSetIndex)
end

function startAutoRent(pid, days, totalSum)
    if not ensureRentItemSelected() then
        return false
    end

    local hours = days * 24
    if hours < 1 then
        hours = 1
    end
    if hours > LIMITS.hoursMax then
        hours = LIMITS.hoursMax
    end

    local hourly = math.ceil(totalSum / hours)

    rentCfg = {
        pid = pid,
        days = days,
        hours = hours,
        total = totalSum,
        hourly = hourly,
        kind = "days_total",
        flowLabel = RENT_MODE_LABEL_DAYS
    }

    enable = true
    mode = "auto_rent"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetSetRentSession()
    resetSetCheckSession()

    local nick = getNickById(pid)
    rentCfg.nick = nick
    rentCfg.msgMoneyPrinted = false

    sampAddChatMessage(string.format(FMT_MODE_STARTED, RENT_MODE_LABEL_DAYS), 0x00FF00)
    sampAddChatMessage(
        string.format("[АРЕНДА] Ищу предмет для игрока! %s -> %d дн. (срок в днях)", nick, days),
        0x00FF00
    )

    if lastCurrency then
        sampAddChatMessage(
            string.format(
                "[АРЕНДА] Цена: %s/ч | Итого: %s",
                formatMoney(hourly, lastCurrency),
                formatMoney(totalSum, lastCurrency)
            ),
            0x00FF00
        )
        rentCfg.msgMoneyPrinted = true
    end
end

function startAutoRentHours(pid, hours, hourly)
    if not ensureRentItemSelected() then
        return false
    end

    if hours < LIMITS.hoursMin then
        hours = LIMITS.hoursMin
    end
    if hours > LIMITS.hoursMax then
        hours = LIMITS.hoursMax
    end
    if hourly < 1 then
        hourly = 1
    end

    local totalSum = hours * hourly

    rentCfg = {
        pid = pid,
        days = math.floor(hours / 24),
        hours = hours,
        total = totalSum,
        hourly = hourly,
        kind = "hours_hourly",
        flowLabel = RENT_MODE_LABEL_HOURS
    }

    enable = true
    mode = "auto_rent"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetSetRentSession()
    resetSetCheckSession()

    local nick = getNickById(pid)
    rentCfg.nick = nick
    rentCfg.msgMainPrinted = false

    if lastCurrency then
        sampAddChatMessage(
            string.format(
                FMT_MODE_STARTED_HOURS,
                RENT_MODE_LABEL_HOURS,
                nick,
                hours,
                formatMoney(hourly, lastCurrency),
                formatMoney(totalSum, lastCurrency)
            ),
            0x00FF00
        )
        rentCfg.msgMainPrinted = true
    end
end

function startAutoRentRestart(pid, totalSum)
    if not ensureRentItemSelected() then
        return false
    end

    local hours, mins = calcHoursToRestart()
    if hours < LIMITS.hoursMin then
        hours = LIMITS.hoursMin
    end
    if hours > LIMITS.hoursMax then
        hours = LIMITS.hoursMax
    end

    if totalSum < 1 then
        totalSum = 1
    end
    local hourly = math.ceil(totalSum / hours)
    if hourly < 1 then
        hourly = 1
    end
    local actualTotal = hours * hourly

    rentCfg = {
        pid = pid,
        days = math.floor(hours / 24),
        hours = hours,
        total = totalSum,
        hourly = hourly,
        actual = actualTotal,
        remMin = mins,
        kind = "restart_total",
        flowLabel = RENT_MODE_LABEL_RESTART
    }

    enable = true
    mode = "auto_rent"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetSetRentSession()
    resetSetCheckSession()

    local nick = getNickById(pid)
    rentCfg.nick = nick
    rentCfg.msgMoneyPrinted = false

    sampAddChatMessage(
        string.format(
            FMT_MODE_STARTED_RESTART,
            RENT_MODE_LABEL_RESTART,
            hours,
            mins
        ),
        0x00FF00
    )
    sampAddChatMessage(string.format("[АРЕНДА] Ищу предмет для игрока! %s | %d ч (до рестарта)", nick, hours), 0x00FF00)

    if lastCurrency then
        sampAddChatMessage(
            string.format(
                "[АРЕНДА] Цена: %s/ч | Итого: %s",
                formatMoney(hourly, lastCurrency),
                formatMoney(actualTotal, lastCurrency)
            ),
            0x00FF00
        )
        rentCfg.msgMoneyPrinted = true
    end
end

function startAutoRentMax(pid, totalSum)
    if not ensureRentItemSelected() then
        return false
    end

    local hours = LIMITS.hoursMax
    if totalSum < 1 then
        totalSum = 1
    end

    local hourly = math.ceil(totalSum / hours)
    if hourly < 1 then
        hourly = 1
    end
    local actualTotal = hours * hourly

    rentCfg = {
        pid = pid,
        days = math.floor(hours / 24),
        hours = hours,
        total = totalSum,
        hourly = hourly,
        actual = actualTotal,
        kind = "max_total",
        flowLabel = RENT_MODE_LABEL_MAX
    }

    enable = true
    mode = "auto_rent"

    resetScanSessionState()
    resetDialogSessionState()

    rentChainActive = false

    resetManualMinuteRentState()
    resetAwaitingConfirmState()
    resetSetRentSession()
    resetSetCheckSession()

    local nick = getNickById(pid)
    rentCfg.nick = nick
    rentCfg.msgMoneyPrinted = false

    sampAddChatMessage(
        string.format(FMT_MODE_STARTED_MAX, RENT_MODE_LABEL_MAX, hours),
        0x00FF00
    )
    sampAddChatMessage(string.format("[АРЕНДА] Ищу предмет для игрока! %s | %d ч (максимальный срок)", nick, hours), 0x00FF00)

    if lastCurrency then
        sampAddChatMessage(
            string.format(
                "[АРЕНДА] Цена: %s/ч | Итого: %s",
                formatMoney(hourly, lastCurrency),
                formatMoney(actualTotal, lastCurrency)
            ),
            0x00FF00
        )
        rentCfg.msgMoneyPrinted = true
    end
end
function ensureUiStyle()
    if uiStyleApplied then
        return
    end

    applyUiThemePreset(uiTheme.preset)
end

function clampInt(ptr, min, max)
    if ptr[0] < min then
        ptr[0] = min
    end
    if ptr[0] > max then
        ptr[0] = max
    end
end

function validatePlayerForUi(pid)
    if not isIntInRange(pid, LIMITS.pidMin, LIMITS.pidMax) then
        sampAddChatMessage(
            string.format("[АРЕНДА] ID игрока нужно указать в пределах %d до %d.", LIMITS.pidMin, LIMITS.pidMax),
            0xFFFF00
        )
        return false
    end

    if not isPlayerOnline(pid) then
        sampAddChatMessage(string.format("[АРЕНДА] Игрок с ID %d не в сети.", pid), 0xFFFF00)
        return false
    end

    return true
end

function runDaysRentFromUi()
    local pid = ui.daysPid[0]
    local days = ui.daysCount[0]
    local total = getMoneyInputValue(ui.daysTotal)

    if not validatePlayerForUi(pid) then
        return
    end

    if not isIntInRange(days, LIMITS.daysMin, LIMITS.daysMax) then
        sampAddChatMessage(
            string.format("[АРЕНДА] Дней должно быть от %d до %d.", LIMITS.daysMin, LIMITS.daysMax),
            0xFFFF00
        )
        return
    end

    if total < 1 then
        sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
        return
    end

    if isSetConfigSelected() then
        startAutoRentForSelectedSet("days", pid, days, nil, total)
    else
        startAutoRent(pid, days, total)
    end
end

function runHoursRentFromUi()
    local pid = ui.hoursPid[0]
    local hours = ui.hoursCount[0]
    local inputValue = getMoneyInputValue(ui.hoursPrice)

    if not validatePlayerForUi(pid) then
        return
    end

    if not isIntInRange(hours, LIMITS.hoursMin, LIMITS.hoursMax) then
        sampAddChatMessage(
            string.format("[АРЕНДА] Часов должно быть от %d до %d.", LIMITS.hoursMin, LIMITS.hoursMax),
            0xFFFF00
        )
        return
    end

    if inputValue < 1 then
        if isSetConfigSelected() then
            sampAddChatMessage("[АРЕНДА] Сумма за весь срок должна быть больше 0.", 0xFFFF00)
        else
            sampAddChatMessage("[АРЕНДА] Цена за час должна быть больше 0.", 0xFFFF00)
        end
        return
    end

    if isSetConfigSelected() then
        startAutoRentForSelectedSet("hours", pid, nil, hours, inputValue)
    else
        startAutoRentHours(pid, hours, inputValue)
    end
end

function runRestartRentFromUi()
    local pid = ui.restartPid[0]
    local total = getMoneyInputValue(ui.restartTotal)

    if not validatePlayerForUi(pid) then
        return
    end

    if total < 1 then
        sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
        return
    end

    if isSetConfigSelected() then
        startAutoRentForSelectedSet("restart", pid, nil, nil, total)
    else
        startAutoRentRestart(pid, total)
    end
end

function runMaxRentFromUi()
    local pid = ui.maxPid[0]
    local total = getMoneyInputValue(ui.maxTotal)

    if not validatePlayerForUi(pid) then
        return
    end

    if total < 1 then
        sampAddChatMessage("[АРЕНДА] Сумма должна быть больше 0.", 0xFFFF00)
        return
    end

    if isSetConfigSelected() then
        startAutoRentForSelectedSet("max", pid, nil, nil, total)
    else
        startAutoRentMax(pid, total)
    end
end

function drawModeCardDays()
    imgui.BeginChild("##daysCard", imgui.ImVec2(0, 0), true, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)
    imgui.Text(uiLabel("CARD_DAYS_TITLE"))
    imgui.TextDisabled(uiLabel("CARD_DAYS_DESC"))

    local changed = false

    local daysPidEdited = imgui.InputInt(uiLabel("INPUT_DAYS_PID"), ui.daysPid, 1, 10)
    if daysPidEdited or imgui.IsItemDeactivatedAfterEdit() then
        clampInt(ui.daysPid, LIMITS.pidMin, LIMITS.pidMax)
        applyPlayerIdToAllModesAndItems(ui.daysPid[0])
        changed = true
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_DAYS_NEAREST"), imgui.ImVec2(120, 0)) then
        if applyNearestPlayerId() then
            changed = true
        end
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("TOOLTIP_NEAREST_ID"))
    end

    if imgui.InputInt(uiLabel("INPUT_DAYS_COUNT"), ui.daysCount, 1, 1) then
        clampInt(ui.daysCount, LIMITS.daysMin, LIMITS.daysMax)
        changed = true
    end

    local prevTotal = getMoneyInputValue(ui.daysTotal)
    imgui.InputText(uiLabel("INPUT_DAYS_TOTAL"), ui.daysTotalBuf, ffi.sizeof(ui.daysTotalBuf))
    syncMoneyInputBuffer(ui.daysTotalBuf, ui.daysTotal, 1)
    if getMoneyInputValue(ui.daysTotal) ~= prevTotal then
        changed = true
    end

    if changed and syncUiToSelectedRentTarget() then
        saveRentItemsToJson()
    end

    if isSetConfigSelected() then
        local desiredTotal = getMoneyInputValue(ui.daysTotal)
        local set = getSelectedRentSet()
        local setItemCount = 0
        if set then
            setItemCount = #buildSetRentItemIds(set)
        end

        if setItemCount > 0 then
            local perItem = math.ceil(desiredTotal / setItemCount)
            if perItem < 1 then
                perItem = 1
            end
            imgui.Text(tostring(ICONS.TEXT_DISTRIBUTION) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_FMT", setItemCount, formatMoney(perItem, lastCurrency)))

            local days = ui.daysCount[0]
            if days < 1 then
                days = 1
            end

            local totalHours = days * 24
            if totalHours < 1 then
                totalHours = 1
            end

            local perItemHourly = math.ceil(perItem / totalHours)
            if perItemHourly < 1 then
                perItemHourly = 1
            end

            imgui.Text(tostring(ICONS.TEXT_PER_ITEM_RATE) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_HOURLY_FMT", formatMoney(perItemHourly, lastCurrency)))
            imgui.Text(tostring(ICONS.TEXT_RATE_CALC) .. " " .. uiLabelFmt("TEXT_RATE_CALC_FMT",
                formatMoney(perItemHourly, lastCurrency),
                totalHours,
                formatMoney(perItem, lastCurrency)
            ))
        end
    end

    if imgui.Button(uiLabel("BTN_RENT_DAYS"), imgui.ImVec2(-1, 32)) then
        runDaysRentFromUi()
    end
    drawRentPriceLimitsTooltip()

    imgui.EndChild()
end
function drawModeCardHours()
    imgui.BeginChild("##hoursCard", imgui.ImVec2(0, 0), true, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)
    imgui.Text(uiLabel("CARD_HOURS_TITLE"))

    local isSetMode = isSetConfigSelected()
    local descKey = isSetMode and "CARD_HOURS_DESC_SET" or "CARD_HOURS_DESC"
    local inputPriceKey = isSetMode and "INPUT_HOURS_SET_TOTAL" or "INPUT_HOURS_PRICE"

    imgui.TextDisabled(uiLabel(descKey))

    local changed = false

    local hoursPidEdited = imgui.InputInt(uiLabel("INPUT_HOURS_PID"), ui.hoursPid, 1, 10)
    if hoursPidEdited or imgui.IsItemDeactivatedAfterEdit() then
        clampInt(ui.hoursPid, LIMITS.pidMin, LIMITS.pidMax)
        applyPlayerIdToAllModesAndItems(ui.hoursPid[0])
        changed = true
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_HOURS_NEAREST"), imgui.ImVec2(120, 0)) then
        if applyNearestPlayerId() then
            changed = true
        end
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("TOOLTIP_NEAREST_ID"))
    end

    if imgui.InputInt(uiLabel("INPUT_HOURS_COUNT"), ui.hoursCount, 1, 5) then
        clampInt(ui.hoursCount, LIMITS.hoursMin, LIMITS.hoursMax)
        changed = true
    end

    local prevHourly = getMoneyInputValue(ui.hoursPrice)
    imgui.InputText(uiLabel(inputPriceKey), ui.hoursPriceBuf, ffi.sizeof(ui.hoursPriceBuf))
    syncMoneyInputBuffer(ui.hoursPriceBuf, ui.hoursPrice, 1)
    if getMoneyInputValue(ui.hoursPrice) ~= prevHourly then
        changed = true
    end

    if changed and syncUiToSelectedRentTarget() then
        saveRentItemsToJson()
    end

    if isSetMode then
        local desiredTotal = getMoneyInputValue(ui.hoursPrice)

        local set = getSelectedRentSet()
        local setItemCount = 0
        if set then
            setItemCount = #buildSetRentItemIds(set)
        end

        if setItemCount > 0 then
            local perItem = math.ceil(desiredTotal / setItemCount)
            if perItem < 1 then
                perItem = 1
            end
            imgui.Text(tostring(ICONS.TEXT_DISTRIBUTION) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_FMT", setItemCount, formatMoney(perItem, lastCurrency)))

            local hours = ui.hoursCount[0]
            if hours < 1 then
                hours = 1
            end

            local totalHours = hours
            if totalHours < 1 then
                totalHours = 1
            end

            local perItemHourly = math.ceil(perItem / totalHours)
            if perItemHourly < 1 then
                perItemHourly = 1
            end

            imgui.Text(tostring(ICONS.TEXT_PER_ITEM_RATE) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_HOURLY_FMT", formatMoney(perItemHourly, lastCurrency)))
            imgui.Text(tostring(ICONS.TEXT_RATE_CALC) .. " " .. uiLabelFmt("TEXT_RATE_CALC_FMT",
                formatMoney(perItemHourly, lastCurrency),
                totalHours,
                formatMoney(perItem, lastCurrency)
            ))
        end
    else
        local total = ui.hoursCount[0] * getMoneyInputValue(ui.hoursPrice)
        imgui.Text(tostring(ICONS.TEXT_TOTAL) .. " " .. uiLabelFmt("TEXT_TOTAL_FMT", formatMoney(total, lastCurrency)))
    end

    if imgui.Button(uiLabel("BTN_RENT_HOURS"), imgui.ImVec2(-1, 32)) then
        runHoursRentFromUi()
    end
    drawRentPriceLimitsTooltip()
    imgui.EndChild()
end
function drawModeCardRestart()
    imgui.BeginChild("##restartCard", imgui.ImVec2(0, 0), true, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)
    imgui.Text(uiLabel("CARD_RESTART_TITLE"))
    imgui.TextDisabled(uiLabel("CARD_RESTART_DESC"))

    local changed = false

    local restartPidEdited = imgui.InputInt(uiLabel("INPUT_RESTART_PID"), ui.restartPid, 1, 10)
    if restartPidEdited or imgui.IsItemDeactivatedAfterEdit() then
        clampInt(ui.restartPid, LIMITS.pidMin, LIMITS.pidMax)
        applyPlayerIdToAllModesAndItems(ui.restartPid[0])
        changed = true
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_RESTART_NEAREST"), imgui.ImVec2(120, 0)) then
        if applyNearestPlayerId() then
            changed = true
        end
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("TOOLTIP_NEAREST_ID"))
    end

    local prevTotal = getMoneyInputValue(ui.restartTotal)
    imgui.InputText(uiLabel("INPUT_RESTART_TOTAL"), ui.restartTotalBuf, ffi.sizeof(ui.restartTotalBuf))
    syncMoneyInputBuffer(ui.restartTotalBuf, ui.restartTotal, 1)
    if getMoneyInputValue(ui.restartTotal) ~= prevTotal then
        changed = true
    end

    if changed and syncUiToSelectedRentTarget() then
        saveRentItemsToJson()
    end

    local h, m = calcHoursToRestart()

    local restartHours = h
    if restartHours < 1 then
        restartHours = 1
    end

    local calcTotal = getMoneyInputValue(ui.restartTotal)
    if isSetConfigSelected() then
        local set = getSelectedRentSet()
        local setItemCount = 0
        if set then
            setItemCount = #buildSetRentItemIds(set)
        end

        if setItemCount > 0 then
            calcTotal = math.ceil(getMoneyInputValue(ui.restartTotal) / setItemCount)
            if calcTotal < 1 then
                calcTotal = 1
            end
            imgui.Text(tostring(ICONS.TEXT_DISTRIBUTION) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_FMT", setItemCount, formatMoney(calcTotal, lastCurrency)))
        end
    end

    local restartHourly = math.ceil(calcTotal / restartHours)
    if restartHourly < 1 then
        restartHourly = 1
    end
    local restartActualTotal = restartHourly * restartHours

    imgui.Text(tostring(ICONS.TEXT_RATE_CALC) .. " " .. uiLabelFmt("TEXT_RATE_CALC_FMT",
        formatMoney(restartHourly, lastCurrency),
        restartHours,
        formatMoney(restartActualTotal, lastCurrency)
    ))

    if imgui.Button(uiLabel("BTN_RENT_RESTART"), imgui.ImVec2(-1, 32)) then
        runRestartRentFromUi()
    end
    drawRentPriceLimitsTooltip()
    imgui.EndChild()
end
function drawModeCardMax()
    imgui.BeginChild("##maxCard", imgui.ImVec2(0, 0), true, imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)
    imgui.Text(uiLabel("CARD_MAX_TITLE"))
    imgui.TextDisabled(uiLabel("CARD_MAX_DESC"))

    local changed = false

    local maxPidEdited = imgui.InputInt(uiLabel("INPUT_MAX_PID"), ui.maxPid, 1, 10)
    if maxPidEdited or imgui.IsItemDeactivatedAfterEdit() then
        clampInt(ui.maxPid, LIMITS.pidMin, LIMITS.pidMax)
        applyPlayerIdToAllModesAndItems(ui.maxPid[0])
        changed = true
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_MAX_NEAREST"), imgui.ImVec2(120, 0)) then
        if applyNearestPlayerId() then
            changed = true
        end
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("TOOLTIP_NEAREST_ID"))
    end

    local prevTotal = getMoneyInputValue(ui.maxTotal)
    imgui.InputText(uiLabel("INPUT_MAX_TOTAL"), ui.maxTotalBuf, ffi.sizeof(ui.maxTotalBuf))
    syncMoneyInputBuffer(ui.maxTotalBuf, ui.maxTotal, 1)
    if getMoneyInputValue(ui.maxTotal) ~= prevTotal then
        changed = true
    end

    if changed and syncUiToSelectedRentTarget() then
        saveRentItemsToJson()
    end

    local maxHours = LIMITS.hoursMax

    local calcTotal = getMoneyInputValue(ui.maxTotal)
    if isSetConfigSelected() then
        local set = getSelectedRentSet()
        local setItemCount = 0
        if set then
            setItemCount = #buildSetRentItemIds(set)
        end

        if setItemCount > 0 then
            calcTotal = math.ceil(getMoneyInputValue(ui.maxTotal) / setItemCount)
            if calcTotal < 1 then
                calcTotal = 1
            end
            imgui.Text(tostring(ICONS.TEXT_DISTRIBUTION) .. " " .. uiLabelFmt("TEXT_SET_PER_ITEM_FMT", setItemCount, formatMoney(calcTotal, lastCurrency)))
        end
    end

    local hourly = math.ceil(calcTotal / maxHours)
    if hourly < 1 then
        hourly = 1
    end
    local actualTotal = hourly * maxHours

    imgui.Text(tostring(ICONS.TEXT_RATE_CALC) .. " " .. uiLabelFmt("TEXT_RATE_CALC_FMT",
        formatMoney(hourly, lastCurrency),
        maxHours,
        formatMoney(actualTotal, lastCurrency)
    ))

    if imgui.Button(uiLabel("BTN_RENT_MAX"), imgui.ImVec2(-1, 32)) then
        runMaxRentFromUi()
    end
    drawRentPriceLimitsTooltip()
    imgui.EndChild()
end
function drawManualMinuteRentWindow()
    if not manualMinuteRent.active then
        return
    end

    if not isManualMinuteRentActive() then
        resetManualMinuteRentState()
        return
    end

    clampManualMinuteValues()

    local resX, resY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(560, 300), imgui.Cond.Always)

    imgui.Begin(
        uiLabelFmt("MANUAL_MINUTE_TITLE_FMT", getSelectedItemName()),
        nil,
        imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
    )

    imgui.TextWrapped(uiLabel("MANUAL_MINUTE_HINT"))
    imgui.Spacing()

    if imgui.InputInt(uiLabel("MANUAL_MINUTE_INPUT"), manualMinuteRent.minutes, 1, 5) then
        clampManualMinuteValues()
    end

    if imgui.InputInt(uiLabel("MANUAL_PRICE_INPUT"), manualMinuteRent.price, 100, 1000) then
        clampManualMinuteValues()
    end

    imgui.Text(uiLabelFmt("MANUAL_LIMIT_MINUTES_FMT", MINUTE_RENT_LIMITS.minutesMin, MINUTE_RENT_LIMITS.minutesMax))
    imgui.Text(
        uiLabelFmt(
            "MANUAL_LIMIT_PRICE_FMT",
            manualMinuteRent.currency,
            formatMoney(manualMinuteRent.priceMin, manualMinuteRent.currency),
            formatMoney(manualMinuteRent.priceMax, manualMinuteRent.currency)
        )
    )
    local minuteTotal = math.max(0, (manualMinuteRent.minutes[0] or 0) * (manualMinuteRent.price[0] or 0))
    imgui.Text(
        uiLabelFmt(
            "MANUAL_TOTAL_CALC_FMT",
            manualMinuteRent.minutes[0],
            formatMoney(manualMinuteRent.price[0], manualMinuteRent.currency),
            formatMoney(minuteTotal, manualMinuteRent.currency)
        )
    )


    if manualMinuteRent.stage == "probe_wait_price" or manualMinuteRent.stage == "probe_wait_hours" then
        imgui.TextColored(imgui.ImVec4(0.95, 0.78, 0.30, 1.0), uiLabel("MANUAL_MINUTE_WAIT_CURRENCY"))
    elseif manualMinuteRent.stage == "price_wait" then
        imgui.TextColored(imgui.ImVec4(0.95, 0.78, 0.30, 1.0), uiLabel("MANUAL_MINUTE_WAIT_PRICE"))
    end

    local continueLabel = tostring(ICONS.MANUAL_CONTINUE) .. " " .. uiLabel("BTN_MANUAL_CONTINUE")
    local stopLabel = tostring(ICONS.MANUAL_STOP) .. " " .. uiLabel("BTN_MANUAL_STOP")

    local style = imgui.GetStyle()
    local buttonHeight = 34

    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.Separator()
    imgui.Spacing()

    local buttonsWidth = imgui.GetContentRegionAvail().x
    local gap = style.ItemSpacing.x
    local buttonWidth = (buttonsWidth - gap) / 2
    if buttonWidth < 120 then
        buttonWidth = 120
    end

    if imgui.Button(continueLabel, imgui.ImVec2(buttonWidth, buttonHeight)) then
        continueManualMinuteRentFlow()
    end
    imgui.SameLine()
    if imgui.Button(stopLabel, imgui.ImVec2(buttonWidth, buttonHeight)) then
        stopManualMinuteRentFlow()
    end

    imgui.End()
end
function drawCreateRentModePopup()
    if
        imgui.BeginPopupModal(
            uiLabel("POPUP_CREATE_RENT_MODE_ID"),
            nil,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize
        )
     then
        imgui.Text(uiLabel("POPUP_CREATE_RENT_MODE_TITLE"))
        imgui.Separator()

        local singleLabel = tostring(ICONS.MODE_SINGLE) .. " " .. uiLabel("BTN_CREATE_SINGLE_RENT")
        local setLabel = tostring(ICONS.MODE_SET) .. " " .. uiLabel("BTN_CREATE_SET_RENT")

        if imgui.Button(singleLabel, imgui.ImVec2(320, 32)) then
            pendingCreateRentPopup = "single"
            imgui.CloseCurrentPopup()
        end

        if imgui.Button(setLabel, imgui.ImVec2(320, 32)) then
            pendingCreateRentPopup = "set"
            imgui.CloseCurrentPopup()
        end

        if imgui.Button(uiLabel("BTN_CANCEL"), imgui.ImVec2(320, 30)) then
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

function drawCreateRentSetPopup()
    imgui.SetNextWindowSize(imgui.ImVec2(760, 520), imgui.Cond.Appearing)

    if
        imgui.BeginPopupModal(
            uiLabel("POPUP_CREATE_RENT_SET_ID"),
            nil,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
        )
     then
        local isEditMode = rentSetEditorIndex > 0 and rentSets[rentSetEditorIndex] ~= nil
        local saveLabel = isEditMode and uiLabel("BTN_SAVE_CHANGES") or uiLabel("BTN_SAVE_SET")

        imgui.Text(isEditMode and uiLabel("POPUP_RENT_SET_EDIT_TITLE") or uiLabel("POPUP_RENT_SET_CREATE_TITLE"))
        imgui.Separator()

        imgui.PushItemWidth(430)
        imgui.InputText(uiLabel("INPUT_SET_NAME"), ui.newSetNameBuf, ffi.sizeof(ui.newSetNameBuf))
        imgui.PopItemWidth()

        imgui.Spacing()
        imgui.Text(uiLabelFmt("TEXT_SET_GRID_FMT", ui.newSetItemLimit))
        imgui.Text(uiLabelFmt("TEXT_SET_IDS_COUNT_FMT", ui.newSetItemCount, ui.newSetItemLimit))
        imgui.SameLine()

        local saveWidth = 170
        local cancelWidth = 170
        local buttonHeight = 30
        local buttonsGap = 12
        local leftShift = 12
        local actionButtonsWidth = saveWidth + buttonsGap + cancelWidth
        local baseX = imgui.GetCursorPosX()
        local actionStartX = baseX + math.max(0, imgui.GetContentRegionAvail().x - actionButtonsWidth) - leftShift
        imgui.SetCursorPosX(math.max(baseX, actionStartX))

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.62, 0.31, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.72, 0.36, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.16, 0.52, 0.27, 1.00))
        if imgui.Button(saveLabel, imgui.ImVec2(saveWidth, buttonHeight)) then
            local setName = normalizeRentSetName(utf8ToCp1251Safe(ffi.string(ui.newSetNameBuf)))
            local itemIds = collectRentSetItemIdsFromDraft()
            local ok, msg

            if isEditMode then
                ok, msg = updateRentSetByIndex(rentSetEditorIndex, setName, itemIds)
            else
                ok, msg = addRentSet(setName, itemIds)
            end

            if ok then
                if isEditMode then
                    sampAddChatMessage(string.format(cp1251("[АРЕНДА] Сет обновлён: %s | Предметов: %d"), setName, #itemIds), 0xFFFF00)
                else
                    sampAddChatMessage(string.format(cp1251("[АРЕНДА] Сет сохранён: %s | Предметов: %d"), setName, #itemIds), 0xFFFF00)
                end
                rentSetEditorIndex = 0
                imgui.CloseCurrentPopup()
            else
                sampAddChatMessage("[АРЕНДА] " .. msg, 0xFFFF00)
            end
        end
        imgui.PopStyleColor(3)

        imgui.SameLine()
        imgui.Dummy(imgui.ImVec2(buttonsGap, 0))
        imgui.SameLine()
        if imgui.Button(uiLabel("BTN_CANCEL"), imgui.ImVec2(cancelWidth, buttonHeight)) then
            rentSetEditorIndex = 0
            imgui.CloseCurrentPopup()
        end

        imgui.Separator()

        local inputWidth = 170
        local cellGap = 12
        local rowCount = math.ceil(ui.newSetItemCount / 3)
        for row = 0, rowCount - 1 do
            local firstIndex = row * 3 + 1
            local secondIndex = firstIndex + 1
            local thirdIndex = firstIndex + 2

            imgui.Text("ID")
            imgui.SameLine()

            imgui.PushItemWidth(inputWidth)
            local firstLabel = uiLabelFmt("INPUT_SET_ITEM_ID_FMT", firstIndex)
            if imgui.InputInt(firstLabel, ui.newSetItemIds[firstIndex], 1, 10) then
                if ui.newSetItemIds[firstIndex][0] < 0 then
                    ui.newSetItemIds[firstIndex][0] = 0
                end
            end
            imgui.PopItemWidth()

            imgui.SameLine()
            imgui.Dummy(imgui.ImVec2(cellGap, 0))
            imgui.SameLine()

            if secondIndex <= ui.newSetItemCount then
                imgui.PushItemWidth(inputWidth)
                local secondLabel = uiLabelFmt("INPUT_SET_ITEM_ID_FMT", secondIndex)
                if imgui.InputInt(secondLabel, ui.newSetItemIds[secondIndex], 1, 10) then
                    if ui.newSetItemIds[secondIndex][0] < 0 then
                        ui.newSetItemIds[secondIndex][0] = 0
                    end
                end
                imgui.PopItemWidth()
            else
                imgui.Dummy(imgui.ImVec2(inputWidth, 0))
            end

            imgui.SameLine()
            imgui.Dummy(imgui.ImVec2(cellGap, 0))
            imgui.SameLine()

            if thirdIndex <= ui.newSetItemCount then
                imgui.PushItemWidth(inputWidth)
                local thirdLabel = uiLabelFmt("INPUT_SET_ITEM_ID_FMT", thirdIndex)
                if imgui.InputInt(thirdLabel, ui.newSetItemIds[thirdIndex], 1, 10) then
                    if ui.newSetItemIds[thirdIndex][0] < 0 then
                        ui.newSetItemIds[thirdIndex][0] = 0
                    end
                end
                imgui.PopItemWidth()
            else
                imgui.Dummy(imgui.ImVec2(inputWidth, 0))
            end
        end

        imgui.Spacing()
        local addLabel = tostring(ICONS.SET_ADD) .. " " .. uiLabel("BTN_ADD_SET_ITEM")
        local removeLabel = tostring(ICONS.SET_REMOVE) .. " " .. uiLabel("BTN_REMOVE_SET_ITEM")

        if ui.newSetItemCount < ui.newSetItemLimit then
            if imgui.Button(addLabel, imgui.ImVec2(180, 30)) then
                ui.newSetItemCount = ui.newSetItemCount + 1
                ui.newSetItemIds[ui.newSetItemCount][0] = 0
            end
        else
            imgui.TextDisabled(addLabel)
        end

        imgui.SameLine()

        if ui.newSetItemCount > 1 then
            if imgui.Button(removeLabel, imgui.ImVec2(180, 30)) then
                ui.newSetItemIds[ui.newSetItemCount][0] = 0
                ui.newSetItemCount = ui.newSetItemCount - 1
            end
        else
            imgui.TextDisabled(removeLabel)
        end


        imgui.EndPopup()
    end
end

function drawCreateRentItemPopup()
    if
        imgui.BeginPopupModal(
            uiLabel("POPUP_CREATE_RENT_ID"),
            nil,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize
        )
     then
        local isEditMode = rentItemEditorIndex > 0 and rentItems[rentItemEditorIndex] ~= nil

        imgui.Text(isEditMode and uiLabel("POPUP_RENT_EDIT_TITLE") or uiLabel("POPUP_RENT_CREATE_TITLE"))
        imgui.Separator()

        if imgui.InputInt(uiLabel("INPUT_ITEM_ID"), ui.newItemId, 1, 10) then
            if ui.newItemId[0] < 1 then
                ui.newItemId[0] = 1
            end
        end

        imgui.InputText(uiLabel("INPUT_ITEM_NAME"), ui.newItemNameBuf, ffi.sizeof(ui.newItemNameBuf))

        local saveLabel = isEditMode and uiLabel("BTN_SAVE_CHANGES") or uiLabel("BTN_SAVE")
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.62, 0.31, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.72, 0.36, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.16, 0.52, 0.27, 1.00))
        if imgui.Button(saveLabel, imgui.ImVec2(160, 30)) then
            local inputName = utf8ToCp1251Safe(ffi.string(ui.newItemNameBuf))
            local ok, msg

            if isEditMode then
                ok, msg = updateRentItemByIndex(rentItemEditorIndex, ui.newItemId[0], inputName)
            else
                ok, msg = addOrUpdateRentItem(ui.newItemId[0], inputName)
            end

            if ok then
                if isEditMode then
                    sampAddChatMessage(
                        string.format("[АРЕНДА] Обновлена аренда: %s [ID: %d]", getSelectedItemName(), itemID),
                        0xFFFF00
                    )
                else
                    sampAddChatMessage(
                        string.format("[АРЕНДА] Создана аренда: %s [ID: %d]", getSelectedItemName(), itemID),
                        0xFFFF00
                    )
                end
                rentItemEditorIndex = 0
                imgui.CloseCurrentPopup()
            else
                sampAddChatMessage("[АРЕНДА] " .. msg, 0xFFFF00)
            end
        end

        imgui.PopStyleColor(3)
        imgui.SameLine()
        if imgui.Button(uiLabel("BTN_CANCEL"), imgui.ImVec2(128, 30)) then
            rentItemEditorIndex = 0
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

local function drawUpdatePopupWindow()
    if not updateState.popupVisible then
        return
    end

    local resX, resY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(UPDATE_POPUP_WIDTH, 420), imgui.Cond.Always)

    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.08, 0.11, 0.16, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.21, 0.54, 0.88, 0.65))
    imgui.PushStyleColor(imgui.Col.TitleBg, imgui.ImVec4(0.10, 0.25, 0.42, 0.96))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.12, 0.34, 0.56, 1.00))
    imgui.PushStyleColor(imgui.Col.TitleBgCollapsed, imgui.ImVec4(0.10, 0.25, 0.42, 0.86))
    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(0.24, 0.45, 0.67, 0.72))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.16, 0.54, 0.87, 0.95))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.21, 0.63, 0.96, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.12, 0.44, 0.76, 1.00))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 18))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(12, 8))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowTitleAlign, imgui.ImVec2(0.5, 0.5))

    local popupAlpha = tonumber(updateState.popupAlpha) or 0.00
    if popupAlpha < 0.00 then
        popupAlpha = 0.00
    elseif popupAlpha > 1.00 then
        popupAlpha = 1.00
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, popupAlpha)

    local popupTitle = tostring(ICONS.TITLE) .. "  ArendaHelper##updatePopup"
    imgui.Begin(popupTitle, nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    if imgui.SetWindowFontScale then
        imgui.SetWindowFontScale(1.22)
    end

    local function drawCenteredText(text, color)
        local contentWidth = imgui.GetContentRegionAvail().x
        local textWidth = imgui.CalcTextSize(text).x
        local cursorX = imgui.GetCursorPosX()

        if textWidth > contentWidth then
            if color then
                imgui.PushStyleColor(imgui.Col.Text, color)
            end
            imgui.TextWrapped(text)
            if color then
                imgui.PopStyleColor()
            end
            return
        end

        imgui.SetCursorPosX(cursorX + (contentWidth - textWidth) * 0.5)

        if color then
            imgui.TextColored(color, text)
        else
            imgui.Text(text)
        end
    end

    drawCenteredText(tostring(ICONS.UPDATE) .. " " .. u8("Обновление доступно"), imgui.ImVec4(0.34, 0.90, 0.48, 1.00))
    drawCenteredText(tostring(ICONS.VERSION) .. " " .. u8(("%s -> %s"):format(SCRIPT_VERSION, updateState.latestVersion or "?")), imgui.ImVec4(0.82, 0.89, 0.98, 1.00))

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    drawCenteredText(tostring(ICONS.CHANGELOG) .. " " .. u8("Что нового:"), imgui.ImVec4(0.76, 0.82, 0.93, 1.00))
    imgui.Spacing()

    if #updateState.changelog == 0 then
        drawCenteredText(u8 "Список изменений недоступен. Откройте тему на форуме.")
    else
        for i = 1, #updateState.changelog do
            drawCenteredText(tostring(ICONS.CHANGELOG_ITEM) .. " " .. u8(updateState.changelog[i]))
        end
    end

    imgui.Spacing()
    local updateHintColor = imgui.ImVec4(0.95, 0.78, 0.38, 1.00)
    drawCenteredText(u8("Новая версия найдена, но файл скрипта нужно заменить вручную."), updateHintColor)
    drawCenteredText(u8(("Нажмите «Обновить», чтобы открыть страницу версии %s."):format(updateState.latestVersion or "?")), updateHintColor)

    local btnHeight = 42
    local btnGap = 12
    local reserveBottom = btnHeight + 10

    local availY = imgui.GetContentRegionAvail().y
    if availY > reserveBottom then
        imgui.Dummy(imgui.ImVec2(0, availY - reserveBottom))
    else
        imgui.Spacing()
    end

    local availW = imgui.GetContentRegionAvail().x
    local btnW = math.floor((availW - btnGap) * 0.5)
    if btnW < 140 then
        btnW = 140
    end

    if imgui.Button(tostring(ICONS.DOWNLOAD) .. " " .. u8("Обновить"), imgui.ImVec2(btnW, btnHeight)) then
        openForumThread()
        hideUpdatePopupImmediately()
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8("Открыть тему ArendaHelper на форуме в браузере."))
    end


    imgui.SameLine(0, btnGap)

    if imgui.Button(tostring(ICONS.CLOSE) .. " " .. u8("Закрыть"), imgui.ImVec2(btnW, btnHeight)) then
        hideUpdatePopupImmediately()
    end

    imgui.End()

    imgui.PopStyleVar(5)
    imgui.PopStyleColor(9)
end

function drawItemsInfoPanel()
    local day, monthName, year, hour, min, sec = getLocalDateTimeNow()
    local restartHours, restartMins = calcExactTimeToRestart()

    local dateText = uiLabelFmt("ITEMS_INFO_DATE_FMT", day, monthName, year)
    local timeText = uiLabelFmt("ITEMS_INFO_TIME_FMT", hour, min, sec)
    local restartText = uiLabelFmt("ITEMS_INFO_RESTART_LEFT_FMT", restartHours, restartMins)

    imgui.BeginChild(
        "##itemsInfoPanel",
        imgui.ImVec2(0, 68),
        true,
        imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar
    )

    imgui.TextWrapped(string.format("%s %s | %s %s", tostring(ICONS.INFO_DATE), dateText, tostring(ICONS.INFO_TIME), timeText))
    imgui.Text(string.format("%s %s", tostring(ICONS.INFO_RESTART), restartText))

    imgui.EndChild()
end

function drawItemsListPanel()
    imgui.BeginChild("##itemsListPanel", imgui.ImVec2(300, 0), true)

    if not logoTexture then
        tryLoadLogoTexture()
    end

    if logoTexture then
        local availWidth = imgui.GetContentRegionAvail().x
        local logoWidth = math.min(availWidth, LOGO_IMAGE_MAX_WIDTH)
        if logoWidth < 1 then
            logoWidth = 1
        end
        local logoHeight = logoWidth / LOGO_IMAGE_ASPECT

        local baseX = imgui.GetCursorPosX()
        if logoWidth < availWidth then
            imgui.SetCursorPosX(baseX + (availWidth - logoWidth) * 0.5)
        end

        imgui.Image(logoTexture, imgui.ImVec2(logoWidth, logoHeight))
        imgui.Spacing()
    end

    imgui.TextWrapped(tostring(ICONS.SETTINGS) .. " " .. uiLabel("ITEMS_PANEL_TITLE"))
    imgui.Separator()

    drawItemsInfoPanel()
    imgui.Spacing()

    imgui.BeginChild("##itemsScrollable", imgui.ImVec2(0, -44), false)

    local pendingEditIndex = 0
    local pendingSetEditIndex = 0

    local availableHeight = imgui.GetContentRegionAvail().y
    if availableHeight < 2 then
        availableHeight = 2
    end

    local topHeight = availableHeight * 0.43

    imgui.BeginChild("##accessoriesSection", imgui.ImVec2(0, topHeight), false)
    imgui.Text(tostring(ICONS.MODE_SINGLE) .. " " .. uiLabel("ITEMS_SECTION_ACCESSORIES"))
    imgui.Separator()
    imgui.BeginChild("##accessoriesList", imgui.ImVec2(0, 0), false)

    if #rentItems == 0 then
        imgui.TextDisabled(uiLabel("ITEMS_EMPTY"))
    end

    for i = 1, #rentItems do
        local it = rentItems[i]
        local style = imgui.GetStyle()
        local rowWidth = imgui.GetContentRegionAvail().x

        local deleteLabel = string.format("%s##deleteRentItem%d", ICONS.DELETE, i)

        local editBtnWidth = imgui.CalcTextSize(tostring(ICONS.EDIT)).x + style.FramePadding.x * 2
        local deleteBtnWidth = imgui.CalcTextSize(tostring(ICONS.DELETE)).x + style.FramePadding.x * 2
        local selectableWidth = rowWidth - editBtnWidth - deleteBtnWidth - style.ItemSpacing.x * 2
        if selectableWidth < 80 then
            selectableWidth = 80
        end

        local editLabel = string.format("%s##editRentItem%d", ICONS.EDIT, i)
        if imgui.SmallButton(editLabel) then
            pendingEditIndex = i
        end

        imgui.SameLine()

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.56, 0.17, 0.19, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.68, 0.22, 0.24, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.13, 0.15, 1.00))
        local clickedDelete = imgui.SmallButton(deleteLabel)
        imgui.PopStyleColor(3)

        if clickedDelete then
            local removedName = tostring(it.name or "")
            local removedId = tonumber(it.id) or 0
            local ok, msg = removeRentItemByIndex(i)
            if ok then
                sampAddChatMessage(
                    string.format("[АРЕНДА] Удалён предмет: %s [ID: %d]", removedName, removedId),
                    0xFF8000
                )
            else
                sampAddChatMessage("[АРЕНДА] " .. msg, 0xFFFF00)
            end
            break
        end

        imgui.SameLine()

        local label = uiLabelFmt("ITEM_ROW_FMT", it.name or "", tonumber(it.id) or 0, i)
        if imgui.Selectable(label, selectedRentTargetType == "item" and i == selectedRentItemIndex, 0, imgui.ImVec2(selectableWidth, 0)) then
            selectRentItem(i)
            saveRentItemsToJson()
        end

        if imgui.BeginDragDropSource(4) then
            local payloadIndex = ffi.new("int[1]", i)
            imgui.SetDragDropPayload("##rentItemPayload", payloadIndex, ffi.sizeof(payloadIndex))
            imgui.Text(uiLabel("DRAGDROP_HINT"))
            imgui.EndDragDropSource()
        end

        if imgui.BeginDragDropTarget() then
            local payload = imgui.AcceptDragDropPayload("##rentItemPayload")
            if payload ~= nil and payload ~= ffi.NULL and payload.Delivery then
                local hasDataPtr = payload.Data ~= nil and payload.Data ~= ffi.NULL
                local hasDataSize = tonumber(payload.DataSize) ~= nil and payload.DataSize >= ffi.sizeof("int")

                if hasDataPtr and hasDataSize then
                    local sourceIndex = ffi.cast("const int*", payload.Data)[0]
                    if sourceIndex ~= i and sourceIndex >= 1 and sourceIndex <= #rentItems and rentItems[i] and rentItems[sourceIndex] then
                        local temp = rentItems[sourceIndex]
                        rentItems[sourceIndex] = rentItems[i]
                        rentItems[i] = temp

                        if selectedRentItemIndex == sourceIndex then
                            selectedRentItemIndex = i
                        elseif selectedRentItemIndex == i then
                            selectedRentItemIndex = sourceIndex
                        end

                        if selectedRentTargetType == "item" then
                            selectRentItem(selectedRentItemIndex)
                        end
                        saveRentItemsToJson()
                    end
                end
            end
            imgui.EndDragDropTarget()
        end
    end
    imgui.EndChild()
    imgui.EndChild()

    imgui.Separator()

    imgui.BeginChild("##setsSection", imgui.ImVec2(0, 0), false)
    imgui.Text(tostring(ICONS.MODE_SET) .. " " .. uiLabel("SETS_LIST_TITLE"))
    imgui.Separator()
    imgui.BeginChild("##setsList", imgui.ImVec2(0, 0), false)

    if #rentSets == 0 then
        imgui.TextDisabled(uiLabel("SETS_EMPTY"))
    else
        for i = 1, #rentSets do
            local set = rentSets[i]
            local setName = tostring(set.name or (cp1251("Сет ") .. tostring(i)))

            local style = imgui.GetStyle()
            local rowWidth = imgui.GetContentRegionAvail().x

            local setViewLabel = string.format("%s##viewRentSet%d", ICONS.VIEW, i)
            local setEditLabel = string.format("%s##editRentSet%d", ICONS.EDIT, i)
            local setDeleteLabel = string.format("%s##deleteRentSet%d", ICONS.DELETE, i)

            local viewBtnWidth = imgui.CalcTextSize(tostring(ICONS.VIEW)).x + style.FramePadding.x * 2
            local editBtnWidth = imgui.CalcTextSize(tostring(ICONS.EDIT)).x + style.FramePadding.x * 2
            local deleteBtnWidth = imgui.CalcTextSize(tostring(ICONS.DELETE)).x + style.FramePadding.x * 2
            local selectableWidth = rowWidth - viewBtnWidth - editBtnWidth - deleteBtnWidth - style.ItemSpacing.x * 3
            if selectableWidth < 90 then
                selectableWidth = 90
            end

            if imgui.SmallButton(setViewLabel) then
                openSetViewWindow(i)
            end

            imgui.SameLine()

            if imgui.SmallButton(setEditLabel) then
                pendingSetEditIndex = i
            end

            imgui.SameLine()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.56, 0.17, 0.19, 0.95))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.68, 0.22, 0.24, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.13, 0.15, 1.00))
            local clickedSetDelete = imgui.SmallButton(setDeleteLabel)
            imgui.PopStyleColor(3)

            if clickedSetDelete then
                local ok, msg = removeRentSetByIndex(i)
                if ok then
                    sampAddChatMessage(string.format(cp1251("[АРЕНДА] Удалён сет: %s"), setName), 0xFF8000)
                else
                    sampAddChatMessage("[АРЕНДА] " .. msg, 0xFFFF00)
                end
                break
            end

            imgui.SameLine()
            local setLabel = uiLabelFmt("SET_SELECT_ROW_FMT", setName, i)
            local isSetSelected = selectedRentTargetType == "set" and i == selectedRentSetIndex
            if imgui.Selectable(setLabel, isSetSelected, 0, imgui.ImVec2(selectableWidth, 0)) then
                selectRentSet(i)
                saveRentItemsToJson()
            end
        end
    end
    imgui.EndChild()
    imgui.EndChild()

    imgui.EndChild()
    if pendingEditIndex > 0 then
        openEditRentItemPopup(pendingEditIndex)
    end

    if pendingSetEditIndex > 0 then
        openEditRentSetPopup(pendingSetEditIndex)
    end

    if imgui.Button(uiLabel("BTN_CREATE_RENT"), imgui.ImVec2(-1, 30)) then
        openCreateRentModePopup()
    end

    drawCreateRentModePopup()

    if pendingCreateRentPopup == "single" then
        pendingCreateRentPopup = nil
        openCreateRentItemPopup()
    elseif pendingCreateRentPopup == "set" then
        pendingCreateRentPopup = nil
        openCreateRentSetPopup()
    end

    drawCreateRentItemPopup()
    drawCreateRentSetPopup()
    imgui.EndChild()
end

function getSetViewStatusUi(status)
    if status == SET_VIEW_STATUS.FREE then
        return uiLabel("SET_VIEW_STATUS_FREE"), imgui.ImVec4(0.33, 0.87, 0.50, 1.0)
    end

    if status == SET_VIEW_STATUS.BUSY then
        return uiLabel("SET_VIEW_STATUS_BUSY"), imgui.ImVec4(0.95, 0.78, 0.30, 1.0)
    end

    if status == SET_VIEW_STATUS.MISSING then
        return uiLabel("SET_VIEW_STATUS_MISSING"), imgui.ImVec4(0.91, 0.40, 0.40, 1.0)
    end

    return uiLabel("SET_VIEW_STATUS_UNKNOWN"), imgui.ImVec4(0.70, 0.76, 0.82, 1.0)
end

function drawSetViewWindow()
    local setViewAlpha = 1.00
    if setViewWindowMenu then
        if showSetViewWindow[0] ~= setViewWindowMenu.state then
            setViewWindowMenu.switch()
        end
        setViewAlpha = setViewWindowMenu.alpha
    end

    if not showSetViewWindow[0] and setViewAlpha <= 0.00 then
        return
    end

    if showSetViewWindow[0] then
        setViewWindowCloseHandled = false
    end

    if showSetViewWindow[0] and not syncSetViewWindowSetData() then
        showSetViewWindow[0] = false
        setViewWindowCloseHandled = true
        resetSetViewScanSession()
        return
    end

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, setViewAlpha)
    imgui.SetNextWindowPos(imgui.ImVec2(setViewWindowPos.x, setViewWindowPos.y), imgui.Cond.Appearing)
    imgui.SetNextWindowSize(SET_VIEW_WINDOW_SIZE, imgui.Cond.Always)

    local title = uiLabelFmt("SET_VIEW_WINDOW_TITLE_FMT", setViewWindowState.setName)
    local setViewWindowOpenRef = showSetViewWindow[0] and showSetViewWindow or nil
    local windowVisible = imgui.Begin(title, setViewWindowOpenRef, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    local currentPos = imgui.GetWindowPos()
    if currentPos ~= nil then
        local posX = tonumber(currentPos.x)
        local posY = tonumber(currentPos.y)

        if posX and posY then
            if math.abs(posX - setViewWindowPos.x) > 0.50 or math.abs(posY - setViewWindowPos.y) > 0.50 then
                setViewWindowPos.x = posX
                setViewWindowPos.y = posY
                setViewWindowPosSavePending = true
                setViewWindowPosChangedAt = os.clock()
            end
        end
    end

    if windowVisible then
        local totalItems = #setViewWindowState.itemIds
        local freeCount = #setViewWindowState.freeItemIds

        local cursorValue = setViewWindowState.cursor
        if cursorValue < 0 then
            cursorValue = 0
        end
        if cursorValue > totalItems then
            cursorValue = totalItems
        end

        if setViewWindowState.scanning then
            imgui.Text(uiLabelFmt("SET_VIEW_TEXT_SCANNING_FMT", cursorValue, totalItems))
        else
            imgui.Text(uiLabelFmt("SET_VIEW_TEXT_FREE_COUNT_FMT", freeCount, totalItems))
        end

        imgui.Text(getSetViewLastScanText())
        if not isSetViewScanFresh() then
            imgui.TextColored(imgui.ImVec4(0.95, 0.78, 0.30, 1.0), uiLabel("SET_VIEW_SCAN_EXPIRED"))
        end

        if setViewWindowState.scanning then
            imgui.TextDisabled(uiLabel("SET_VIEW_BTN_REFRESH"))
        else
            if imgui.Button(uiLabel("SET_VIEW_BTN_REFRESH"), imgui.ImVec2(140, 30)) then
                startSetViewScan()
            end
        end

        imgui.SameLine()

        if setViewWindowState.scanning then
            imgui.TextDisabled(uiLabel("SET_VIEW_BTN_RENT_FREE"))
        else
            local fresh = isSetViewScanFresh()
            if not fresh then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.22, 0.30, 0.65))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.21, 0.26, 0.35, 0.75))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.18, 0.22, 0.30, 0.75))
            end

            if imgui.Button(uiLabel("SET_VIEW_BTN_RENT_FREE"), imgui.ImVec2(180, 30)) then
                runSetViewRentFreeItemsFromUi()
            end

            if not fresh then
                imgui.PopStyleColor(3)
            end
        end

        imgui.Separator()
        imgui.BeginChild("##setViewItemsChild", imgui.ImVec2(0, 0), true)

        if totalItems == 0 then
            imgui.TextDisabled(uiLabel("SET_VIEW_TEXT_EMPTY"))
        else
            for i = 1, totalItems do
                local itemId = tonumber(setViewWindowState.itemIds[i]) or 0
                local itemName = cp1251ToUtf8Safe(tostring(getRentItemNameById(itemId)))
                local status = setViewWindowState.statusByItemId[itemId] or SET_VIEW_STATUS.UNKNOWN
                local statusText, statusColor = getSetViewStatusUi(status)
                local rentUntil = setViewWindowState.rentUntilByItemId[itemId]
                if status == SET_VIEW_STATUS.BUSY and type(rentUntil) == "string" and rentUntil ~= "" then
                    statusText = statusText .. cp1251ToUtf8Safe(" до: ") .. cp1251ToUtf8Safe(rentUntil)
                end

                imgui.Text(tostring(i) .. ". " .. tostring(itemName) .. " [ID: " .. tostring(itemId) .. "]")
                imgui.SameLine()
                imgui.TextColored(statusColor, statusText)
            end
        end

        imgui.EndChild()
    end
    imgui.End()
    imgui.PopStyleVar()


    if setViewWindowPosSavePending and (os.clock() - setViewWindowPosChangedAt) >= 0.25 then
        setViewWindowPosSavePending = false
        saveRentItemsToJson()
    end

    if not showSetViewWindow[0] and not setViewWindowCloseHandled then
        if setViewWindowPosSavePending then
            setViewWindowPosSavePending = false
            saveRentItemsToJson()
        end
        if isSetViewScanActive() and enable and mode == "check" then
            stopScript("Проверка сета остановлена.", 0xFFFF00, {escPresses = 0})
        else
            resetSetViewScanSession()
        end
        setViewWindowCloseHandled = true
    end
end

function drawSettingsStubTab()
    imgui.BeginChild("##settingsStubCard", imgui.ImVec2(0, 0), true)

    local changed = imgui.Checkbox(uiLabel("SETTINGS_ITEM_IDS_TOGGLE"), ui.showInventoryItemIds)
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("SETTINGS_ITEM_IDS_HINT"))
    end

    if changed then
        setInventoryItemIdsEnabled(ui.showInventoryItemIds[0], false)
    end

    imgui.Spacing()
    if inventoryItemIdsEnabled then
        imgui.TextColored(imgui.ImVec4(0.33, 0.87, 0.50, 1.0), uiLabel("SETTINGS_ITEM_IDS_STATE_ON"))
    else
        imgui.TextDisabled(uiLabel("SETTINGS_ITEM_IDS_STATE_OFF"))
    end

    imgui.Separator()
    imgui.Spacing()

    local quietChanged = imgui.Checkbox(uiLabel("SETTINGS_QUIET_MODE_TOGGLE"), ui.quietMode)
    if imgui.IsItemHovered() then
        imgui.SetTooltip(uiLabel("SETTINGS_QUIET_MODE_HINT"))
    end

    if quietChanged then
        setQuietModeEnabled(ui.quietMode[0], false)
    end

    imgui.Spacing()
    if quietModeEnabled then
        imgui.TextColored(imgui.ImVec4(0.33, 0.87, 0.50, 1.0), uiLabel("SETTINGS_QUIET_MODE_STATE_ON"))
    else
        imgui.TextDisabled(uiLabel("SETTINGS_QUIET_MODE_STATE_OFF"))
    end

    imgui.EndChild()
end

function drawThemeSettingsTab()
    imgui.BeginChild("##themeCard", imgui.ImVec2(0, 0), true)
    imgui.Text(uiLabel("THEME_TITLE"))
    imgui.Separator()

    local changedThemePreset = false

    if imgui.Button(uiLabel("BTN_THEME_CUSTOM"), imgui.ImVec2(172, 0)) then
        changedThemePreset = setUiThemePreset(THEME_PRESET.CUSTOM)
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_THEME_DARK"), imgui.ImVec2(90, 0)) then
        changedThemePreset = setUiThemePreset(THEME_PRESET.DARK) or changedThemePreset
    end
    imgui.SameLine()
    if imgui.Button(uiLabel("BTN_THEME_LIGHT"), imgui.ImVec2(90, 0)) then
        changedThemePreset = setUiThemePreset(THEME_PRESET.LIGHT) or changedThemePreset
    end

    if changedThemePreset then
        saveRentItemsToJson()
    end

    imgui.Spacing()
    imgui.Text(uiLabelFmt("THEME_CURRENT_FMT", getUiThemePresetText(uiTheme.preset)))

    if uiTheme.preset ~= THEME_PRESET.CUSTOM then
        imgui.Spacing()
        imgui.TextDisabled(uiLabel("THEME_HINT_CUSTOM_ONLY"))
        imgui.EndChild()
        return
    end

    imgui.Spacing()
    imgui.Text(uiLabel("THEME_BASE_COLORS"))
    imgui.Separator()

    local pendingSave = false

    for i = 1, #THEME_PALETTE_KEYS do
        local key = THEME_PALETTE_KEYS[i]
        local label = uiLabel(THEME_PALETTE_LABELS[key]) .. "##themePalette_" .. key
        if imgui.ColorEdit4(label, uiTheme.palette[key]) then
            applyUiThemePreset(THEME_PRESET.CUSTOM)
        end
        if imgui.IsItemDeactivatedAfterEdit() then
            pendingSave = true
        end
    end

    imgui.Spacing()
    if imgui.Button(uiLabel("BTN_THEME_RESET"), imgui.ImVec2(-1, 0)) then
        resetThemeCustomColors()
        applyUiThemePreset(THEME_PRESET.CUSTOM)
        pendingSave = true
    end

    if pendingSave then
        saveRentItemsToJson()
    end

    imgui.EndChild()
end
local ui_meta = {
    __index = function(self, v)
        if v == "switch" then
            local switch = function()
                if self.process and self.process:status() ~= "dead" then
                    return false
                end
                self.timer = os.clock()
                self.state = not self.state

                self.process =
                    lua_thread.create(
                    function()
                        local bringFloatTo = function(from, to, start_time, duration)
                            local timer = os.clock() - start_time
                            if timer >= 0.00 and timer <= duration then
                                local count = timer / (duration / 100)
                                return count * ((to - from) / 100)
                            end
                            return (timer > duration) and to or from
                        end

                        while true do
                            wait(0)
                            local a = bringFloatTo(0.00, 1.00, self.timer, self.duration)
                            self.alpha = self.state and a or 1.00 - a
                            if a == 1.00 then
                                break
                            end
                        end
                    end
                )
                return true
            end
            return switch
        end

        if v == "alpha" then
            return self.state and 1.00 or 0.00
        end
    end
}

local menu = {state = false, duration = 0.5}
setmetatable(menu, ui_meta)
setViewWindowMenu = {state = false, duration = menu.duration}
setmetatable(setViewWindowMenu, ui_meta)
local showMenu = imgui.new.bool(true)
imgui.OnInitialize(
    function()
        if not fa6FontMerged then
            local cfg = imgui.ImFontConfig()
            cfg.MergeMode = true
            cfg.PixelSnapH = true

            local iconRanges = new.ImWchar[3](fa6.min_range, fa6.max_range, 0)
            imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(
                fa6.get_font_data_base85("solid"),
                14.0,
                cfg,
                iconRanges
            )

            fa6FontMerged = true
        end

        tryLoadLogoTexture()
    end
)

imgui.OnFrame(
    function()
        return menu.alpha > 0.00 or manualMinuteRent.active or showSetViewWindow[0] or (setViewWindowMenu and setViewWindowMenu.alpha > 0.00)
    end,
    function(cls)
        ensureUiStyle()

        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(1060, 590), imgui.Cond.Always)
        cls.HideCursor = not (menu.state or manualMinuteRent.active or showSetViewWindow[0] or (setViewWindowMenu and setViewWindowMenu.alpha > 0.00))

        if manualMinuteRent.active and manualMinuteRent.closeMainRequested then
            if menu.state then
                menu.switch()
            end
            showMenu[0] = true
            manualMinuteRent.closeMainRequested = false
        end
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, menu.alpha)
        imgui.Begin(
            getMainWindowTitle(),
            showMenu,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
        )

        imgui.Columns(2, "##layoutCols", false)
        imgui.SetColumnWidth(0, 308)
        drawItemsListPanel()
        imgui.NextColumn()

        imgui.Text(uiLabel("MAIN_CONTROL_TITLE"))
        imgui.Separator()

        local statusText = uiLabel("STATUS_IDLE")
        local statusColor = imgui.ImVec4(0.70, 0.76, 0.82, 1.0)

        if enable and mode == "check" then
            statusText = uiLabel("STATUS_CHECKING")
            statusColor = imgui.ImVec4(0.33, 0.87, 0.50, 1.0)
        elseif enable and mode == "auto_rent" then
            statusText = uiLabel("STATUS_AUTO_RENT")
            statusColor = imgui.ImVec4(0.31, 0.72, 1.00, 1.0)
        end

        imgui.TextColored(statusColor, statusText)

        if selectedRentTargetType == "set" and hasRentSets() then
            local set = getSelectedRentSet()
            local setName = tostring(set.name or (cp1251("Сет ") .. tostring(selectedRentSetIndex)))
            imgui.TextDisabled(uiLabelFmt("TEXT_SELECTED_TARGET_SET_FMT", setName))
        elseif hasRentItems() then
            local item = getSelectedRentItem()
            local itemName = tostring((item and item.name) or cp1251("Предмет"))
            local selectedItemId = tonumber((item and item.id) or itemID) or 0
            imgui.TextDisabled(uiLabelFmt("TEXT_SELECTED_TARGET_ITEM_FMT", itemName, selectedItemId))
        end

        if enable then
            if imgui.Button(uiLabel("BTN_STOP_ACTIVE_MODE"), imgui.ImVec2(-1, 30)) then
                stopScript("Остановлено.", 0xFFFF00)
            end
        else
            if not isSetConfigSelected() and imgui.Button(uiLabel("BTN_CHECK_ITEMS"), imgui.ImVec2(-1, 30)) then
                startCheck()
            end
        end

        imgui.Spacing()

        if imgui.BeginTabBar("##arendaModes") then
            if imgui.BeginTabItem(TAB_LABELS.HOURS) then
                activeRentModeTab = "hours"
                drawModeCardHours()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem(TAB_LABELS.DAYS) then
                activeRentModeTab = "days"
                drawModeCardDays()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem(TAB_LABELS.RESTART) then
                activeRentModeTab = "restart"
                drawModeCardRestart()
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(TAB_LABELS.MAX) then
                activeRentModeTab = "max"
                drawModeCardMax()
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(TAB_LABELS.SETTINGS) then
                drawSettingsStubTab()
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem(TAB_LABELS.STYLES) then
                drawThemeSettingsTab()
                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end

        imgui.Columns(1)
        imgui.End()

        if not showMenu[0] then
            menu.switch()
            showMenu[0] = true
        end

        imgui.PopStyleVar()

        if showSetViewWindow[0] or (setViewWindowMenu and setViewWindowMenu.alpha > 0.00) then
            drawSetViewWindow()
        end

        if manualMinuteRent.active then
            drawManualMinuteRentWindow()
        end
    end
)

imgui.OnFrame(
    function()
        return updateState.popupVisible
    end,
    function(cls)
        cls.HideCursor = false
        drawUpdatePopupWindow()
    end
)

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x100 or msg == 0x101 or msg == 0x104 or msg == 0x105 or msg == 523 or msg == 513 or msg == 516 then
        if (wparam == keys.VK_ESCAPE and manualMinuteRent.active) and not isPauseMenuActive() then
            consumeWindowMessage(true, false)
            if msg == 0x101 or msg == 0x105 then
                stopManualMinuteRentFlow()
            end
            return
        end

        if (wparam == keys.VK_ESCAPE and showSetViewWindow[0]) and not isPauseMenuActive() then
            consumeWindowMessage(true, false)
            if msg == 0x101 or msg == 0x105 then
                if setViewWindowPosSavePending then
                    setViewWindowPosSavePending = false
                    saveRentItemsToJson()
                end
                showSetViewWindow[0] = false
                setViewWindowCloseHandled = true
                if setViewWindowMenu and setViewWindowMenu.state then
                    setViewWindowMenu.switch()
                end
                if isSetViewScanActive() and enable and mode == "check" then
                    stopScript("Проверка сета остановлена.", 0xFFFF00, {escPresses = 0})
                else
                    resetSetViewScanSession()
                end
            end
            return
        end

        if (wparam == keys.VK_ESCAPE and menu.state) and not isPauseMenuActive() then
            consumeWindowMessage(true, false)
            if msg == 0x101 or msg == 0x105 then
                menu.switch()
            end
        end
    end
end
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(0)
    end
    ensureLogoFileOrFail()
    loadRentItemsFromJson()
    sampRegisterChatCommand(
        "arenda",
        function()
            if updateState.popupVisible then
                hideUpdatePopupImmediately()
            end
            menu.switch()
        end
    )
    while true do
        wait(0)

        if sampIsLocalPlayerSpawned() and not spawned then
            spawned = true
            spawnMessageDueAt = os.clock() + 2
        end

        if spawnMessageDueAt and os.clock() >= spawnMessageDueAt then
            if sampIsLocalPlayerSpawned() then
                sampAddChatMessage(
                    "[АРЕНДА] Успешно загружен | Автор: " .. SCRIPT_AUTHOR .. " | Версия: " .. SCRIPT_VERSION,
                    0xFFFF00
                )
                startUpdateCheck(true)
            end
            spawnMessageDueAt = nil
        end

        if inventoryItemIdsEnabled and os.clock() >= inventoryIdOverlayNextTick then
            inventoryIdOverlayNextTick = os.clock() + INVENTORY_ID_OVERLAY_INTERVAL
            applyInventoryItemIdsOverlay()
        end

        if awaitingConfirm and (os.clock() - awaitingConfirmStart) >= 60 then
            local stopOpts = {escPresses = 0}
            if awaitingConfirmManual then
                stopOpts.escPresses = 1
                stopOpts.escDelay = 60
                stopOpts.escInterval = 120
            end
            stopScript(TXT_RENT_OFFER_NOT_ACCEPTED, 0xFF8000, stopOpts)
        end

        if enable then
            if waitingForDialog and (os.clock() - dialogWaitStart) >= DIALOG_TIMEOUT then
                waitingForDialog = false
                noDialogTries = noDialogTries + 1

                if noDialogTries >= MAX_NO_DIALOG_TRIES then
                    finishScan()
                else
                    sampAddChatMessage("[АРЕНДА] Диалог не получен. Повтор...", 0xFFFF00)
                    attemptCount = 0
                    sampSendChat("/invent")
                    wait(1000)
                end
            end

            if enable and not waitingForDialog and not rentChainActive and not busy then
                attemptCount = attemptCount + 1

                if attemptCount == 1 then
                    sampSendChat("/invent")
                    wait(1000)
                end

                waitingForDialog = true
                dialogWaitStart = os.clock()

                clickInventoryItemByIndex(scanIndex)
                wait(350)
            end
        end
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if enable and mode == "auto_rent" and rentChainActive and rentCfg then
        if dialogId == DIALOG_ID_RENT_TARGET then
            local pid = rentCfg.pid
            lua_thread.create(
                function()
                    wait(250)
                    if not (enable and mode == "auto_rent" and rentChainActive) then
                        return
                    end
                    sampSendDialogResponse(DIALOG_ID_RENT_TARGET, 1, 0, tostring(pid))
                end
            )
            return false
        elseif dialogId == DIALOG_ID_RENT_HOURS then
            if isMinuteRentDialog(text) then
                openManualMinuteRent()
                return false
            end

            if manualMinuteRent.active then
                manualMinuteRent.currentDialogId = DIALOG_ID_RENT_HOURS
                return false
            end

            local hours = rentCfg.hours
            lua_thread.create(
                function()
                    wait(250)
                    if not (enable and mode == "auto_rent" and rentChainActive) then
                        return
                    end
                    sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 1, 0, tostring(hours))
                end
            )
            return false
        elseif dialogId == DIALOG_ID_RENT_PRICE then
            if manualMinuteRent.active then
                onManualMinutePriceDialog(text)
                return false
            end

            local hourly = tonumber(rentCfg.hourly) or 0
            local limits = parseHourlyLimits(text)

            if not limits then
                lua_thread.create(
                    function()
                        wait(160)
                        sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 0, 0, "")
                        wait(300)
                        sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 0, 0, "")
                        wait(300)
                        stopWithInventoryClose(TXT_CANT_PARSE .. " " .. TXT_STOPPED, 0xFFFF00)
                    end
                )
                return false
            end

            local effectiveLimits = getUnifiedHourlyPriceLimits(limits) or limits

            local wrongPrice = (hourly < effectiveLimits.min) or (hourly > effectiveLimits.max)
            if wrongPrice then
                local priceStr = formatMoney(hourly, effectiveLimits.currency)
                local minStr = formatMoney(effectiveLimits.min, effectiveLimits.currency)
                local maxStr = formatMoney(effectiveLimits.max, effectiveLimits.currency)

                lua_thread.create(
                    function()
                        wait(160)
                        sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 0, 0, "")
                        wait(300)
                        sampSendDialogResponse(DIALOG_ID_RENT_HOURS, 0, 0, "")
                        wait(300)

                        sampAddChatMessage("[АРЕНДА] " .. string.format(FMT_BAD_HOURLY, priceStr), 0xFFFF00)
                        sampAddChatMessage("[АРЕНДА] " .. string.format(FMT_ALLOWED_RANGE, minStr, maxStr), 0xFFFF00)
                        sampAddChatMessage("[АРЕНДА] " .. TXT_RENT_CANCELLED, 0xFFFF00)
                        stopWithInventoryClose(nil, nil)
                    end
                )

                return false
            end

            lastCurrency = effectiveLimits.currency

            local nick = rentCfg.nick or getNickById(rentCfg.pid)

            if rentCfg.kind == "hours_hourly" then
                if not rentCfg.msgMainPrinted then
                    local h = rentCfg.hours or 0
                    local hr = rentCfg.hourly or 0
                    local total = rentCfg.total or (h * hr)

                    sampAddChatMessage(
                        string.format(
                            FMT_MODE_STARTED_HOURS,
                            RENT_MODE_LABEL_HOURS,
                            nick,
                            h,
                            formatMoney(hr, lastCurrency),
                            formatMoney(total, lastCurrency)
                        ),
                        0x00FF00
                    )
                    rentCfg.msgMainPrinted = true
                end
            else
                if not rentCfg.msgMoneyPrinted then
                    local hr = rentCfg.hourly or 0
                    local total = rentCfg.total or 0
                    if rentCfg.kind == "restart_total" or rentCfg.kind == "max_total" then
                        total = rentCfg.actual or ((rentCfg.hours or 0) * hr)
                    end

                    sampAddChatMessage(
                        string.format(
                            "[АРЕНДА] Цена: %s/ч | Итого: %s",
                            formatMoney(hr, lastCurrency),
                            formatMoney(total, lastCurrency)
                        ),
                        0x00FF00
                    )
                    rentCfg.msgMoneyPrinted = true
                end
            end

            lua_thread.create(
                function()
                    wait(250)
                    if not (enable and mode == "auto_rent" and rentChainActive) then
                        return
                    end
                    sampSendDialogResponse(DIALOG_ID_RENT_PRICE, 1, 0, tostring(hourly))
                end
            )
            return false
        elseif dialogId == DIALOG_ID_RENT_CONFIRM then
            local pid = rentCfg.pid
            local hourly = rentCfg.hourly
            awaitingConfirmManual = rentCfg and rentCfg.manualFlowUsed or false
            if manualMinuteRent.active then
                resetManualMinuteRentState()
            end
            lua_thread.create(
                function()
                    wait(250)
                    if not (enable and mode == "auto_rent" and rentChainActive) then
                        return
                    end
                    awaitingConfirm = true
                    awaitingConfirmStart = os.clock()
                    awaitingConfirmPid = pid

                    sampSendDialogResponse(DIALOG_ID_RENT_CONFIRM, 1, 0, "")
                    wait(250)
                    if not enable then
                        return
                    end

                    waitingForDialog = false
                    rentChainActive = false
                    busy = true

                    rentCfg = nil
                end
            )
            return false
        else
            local flowLabel = (rentCfg and rentCfg.flowLabel) or RENT_MODE_LABEL_UNKNOWN
            if manualMinuteRent.active then
                resetManualMinuteRentState()
            end
            lua_thread.create(
                function()
                    wait(160)
                    sampSendDialogResponse(dialogId, 0, 0, "")
                    wait(150)
                    stopWithInventoryClose(
                        string.format(FMT_UNEXPECTED_DIALOG_MODE, flowLabel, dialogId),
                        0xFFFF00
                    )
                end
            )
            return false
        end
    end

    if not (enable and waitingForDialog) then
        return
    end
    waitingForDialog = false
    noDialogTries = 0
    busy = true

    if dialogId == DIALOG_ID_RENT_INFO and title and title:find(DIALOG_TITLE_RENT_INFO) then
        local cleanText = stripColorCodes(text or "")
        local rentInfo = cleanText:match("Аренда до:%s*([^\r\n]+)")
        rentInfo = trim(rentInfo)

        if rentInfo ~= "" then
            rentedUntil = rentInfo
        else
            rentedUntil = nil
        end

        processedCount = processedCount + 1

        local slotNumber = getCurrentInventorySlotNumber()
        local statusText = "Предмет в аренде"
        if rentedUntil then
            statusText = statusText .. " до: " .. rentedUntil
        else
            statusText = statusText .. " (срок не определён)"
        end

        sampAddChatMessage(
            "[АРЕНДА] Обработана ячейка " .. slotNumber .. ". " .. statusText .. ". Ищу дальше...",
            0xFFFF00
        )

        lua_thread.create(
            function()
                wait(160)
                sampSendDialogResponse(DIALOG_ID_RENT_INFO, 1, 0, "")
                wait(200)
                scanIndex = scanIndex + 1
                busy = false
            end
        )

        return false
    end

    if mode == "check" then
        notRentedFound = true

        local slotNumber = getCurrentInventorySlotNumber()
        local alreadyTracked = false
        for i = 1, #notRentedSlots do
            if notRentedSlots[i] == slotNumber then
                alreadyTracked = true
                break
            end
        end
        if not alreadyTracked then
            table.insert(notRentedSlots, slotNumber)
        end

        processedCount = processedCount + 1
        sampAddChatMessage(
            "[АРЕНДА] Обработана ячейка " .. slotNumber .. ". Предмет НЕ в аренде (пропуск).",
            0xFF8000
        )

        lua_thread.create(
            function()
                wait(160)
                sampSendDialogResponse(dialogId, 0, 0, "")
                wait(200)
                scanIndex = scanIndex + 1
                busy = false
            end
        )

        return false
    end

    if mode == "auto_rent" and rentCfg then
        if dialogId == DIALOG_ID_RENT_TARGET then
            rentChainActive = true
            sampAddChatMessage("[АРЕНДА] Найден предмет НЕ в аренде. Заполняю поля...", 0xFFFF00)

            local pid = rentCfg.pid
            lua_thread.create(
                function()
                    wait(250)
                    if not enable then
                        return
                    end
                    sampSendDialogResponse(DIALOG_ID_RENT_TARGET, 1, 0, tostring(pid))
                end
            )

            return false
        else
            processedCount = processedCount + 1
            sampAddChatMessage("[АРЕНДА] Неожиданный диалог (ID: " .. dialogId .. "). Пропуск.", 0xFF8000)

            lua_thread.create(
                function()
                    wait(160)
                    sampSendDialogResponse(dialogId, 0, 0, "")
                    wait(200)
                    scanIndex = scanIndex + 1
                    busy = false
                end
            )

            return false
        end
    end
end

function sampev.onServerMessage(color, text)
    if not enable then
        return
    end
    if not text or text == "" then
        return
    end

    local clean = stripColorCodes(text or "")
    clean = clean:gsub("%c", " ")
    clean = clean:gsub("%s+", " ")

    local isTransferActionActiveError =
        clean:find("[Ошибка]", 1, true) and
        clean:find(SERVER_ERROR_TRANSFER_ACTIVE_PART, 1, true)

    if isTransferActionActiveError then
        if mode == "check" then
            stopWithInventoryClose(STOP_REASON_TRANSFER_ACTIVE_CHECK, 0xFFFF00)
            return
        end

        if mode == "auto_rent" then
            stopAutoRentByServerError("Завершите текущую передачу предмета и попробуйте снова")
            return
        end
    end

    if mode ~= "auto_rent" then
        return
    end
    local isOfferWaitMessage =
        clean:match(SERVER_MSG_RENT_OFFER_TIMEOUT_EXACT_PATTERN) ~= nil or
        (clean:find(SERVER_MSG_RENT_OFFER_TIMEOUT_HEAD, 1, true) and
        clean:find(SERVER_MSG_RENT_OFFER_TIMEOUT_BODY, 1, true))

    if isOfferWaitMessage then
        if awaitingConfirm then
            awaitingConfirmStart = os.clock()

            if menu and menu.state then
                menu.switch()
            end
            showMenu[0] = true
            queueEscPresses(1, 60, 120)
        end
        return
    end

    local isOfferAcceptedMessage =
        (clean:find(SERVER_MSG_RENT_ACCEPTED_HEAD, 1, true) or clean:find(SERVER_MSG_RENT_ACCEPTED_HEAD_ALT, 1, true)) and
        clean:find(SERVER_MSG_RENT_OFFER_ACCEPTED_FRAGMENT, 1, true)

    if awaitingConfirm and isOfferAcceptedMessage then
        local nick, id = clean:match("игроком%s+([%w_]+)%[(%d+)%]")
        if not nick or not id then
            nick, id = clean:match("Игроком%s+([%w_]+)%[(%d+)%]")
        end

        local pid = tonumber(id)
        if awaitingConfirmPid and pid and pid ~= awaitingConfirmPid then
            return
        end

        if nick and pid then
            sampAddChatMessage(
                string.format("[АРЕНДА] Успешно! Игрок %s [%d] принял предложение.", nick, pid),
                0x00FF00
            )
        else
            sampAddChatMessage("[АРЕНДА] Успешно! Игрок принял предложение аренды.", 0x00FF00)
        end

        if isSetRentSessionActive() then
            finishSetRentStep(true, "предложение принято")
        else
            stopScript(nil, nil, {escPresses = 0})
        end
        return
    end

    local isRentShopError =
        (clean:find(SERVER_ERROR_RENT_SHOP_ACTIVE_HEAD, 1, true) and
        clean:find(SERVER_ERROR_RENT_SHOP_ACTIVE_TAIL, 1, true)) or
        clean:find(SERVER_ERROR_RENT_SHOP_ACTIVE_ALT, 1, true)

    if isRentShopError then
        stopWithInventoryClose("Сдача отменена. Игрок уже арендует лавку.", 0xFFFF00)
        return
    end

    if clean:find("[Ошибка] Игрок должен быть рядом с вами.", 1, true) then
        stopAutoRentByServerError("Убедитесь, что игрок находится рядом")
        return
    end

    if clean:find("[Ошибка] Игрок не авторизован", 1, true) then
        stopAutoRentByServerError("Игрок ещё не авторизован. Попробуйте позже")
        return
    end

    if clean:find("[Ошибка] Игрок отключил возможность предлагать ему продажу/обмен/аренду!", 1, true) then
        stopAutoRentByServerError("Игрок запретил предложения аренды")
        return
    end

    local offId = clean:match("%[Ошибка%]%s*Игрок%s*'ID:%s*(%d+)'%s*не%s*в%s*сети!")
    if offId then
        stopAutoRentByServerError(string.format("Игрок (ID: %s) не в сети", offId))
        return
    end
end

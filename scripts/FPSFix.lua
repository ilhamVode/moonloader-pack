script_author('JustFedot')
local script__version = '1.1'
script_version(script__version)
script_description(
    'Универсальный помощник для Центрального Рынка с множеством функций и системой логов с уведомлениями в телеграм.')


require("moonloader")
require("sampfuncs")
local sampev = require("samp.events")
local effil = require("effil")
local encoding = require("encoding")
encoding.default = 'CP1251'
u8 = encoding.UTF8
local imgui = require("imgui")
local f = require 'moonloader'.font_flag
local font = renderCreateFont('Arial', 15, f.BOLD + f.SHADOW)
local font_two = renderCreateFont('Arial', 10, f.BOLD + f.SHADOW)


-----------=========================-------------------

-- Получить название Аризоны
function getArizonaName()
    local server_name = sampGetCurrentServerName()
    server_name = server_name:match("^Arizona [^|]+ | ([^|]+) |") or server_name:match("^Arizona [^|]+ | ([^|]+)$")
    return server_name or ""
end

-- Получить свой ID
function sampGetMyNickname()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if result then
        return sampGetPlayerNickname(id)
    else
        return ""
    end
end

---------------=======================---------------------------


function apply_custom_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = ImVec2(15, 15)
    style.WindowRounding = 8.0
    style.FramePadding = ImVec2(5, 5)
    style.ItemSpacing = ImVec2(12, 8)
    style.ItemInnerSpacing = ImVec2(8, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 15.0
    style.ScrollbarRounding = 15.0
    style.GrabMinSize = 15.0
    style.GrabRounding = 7.0
    style.ChildWindowRounding = 8.0
    style.FrameRounding = 6.0


    colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.36, 0.42, 0.47, 1.00)
    colors[clr.WindowBg] = ImVec4(0.11, 0.15, 0.17, 1.00)
    colors[clr.ChildWindowBg] = ImVec4(0.15, 0.18, 0.22, 1.00)
    colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border] = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.12, 0.20, 0.28, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1.00)
    colors[clr.TitleBg] = ImVec4(0.09, 0.12, 0.14, 0.65)
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.TitleBgActive] = ImVec4(0.08, 0.10, 0.12, 1.00)
    colors[clr.MenuBarBg] = ImVec4(0.15, 0.18, 0.22, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
    colors[clr.ScrollbarGrab] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.09, 0.21, 0.31, 1.00)
    colors[clr.ComboBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.CheckMark] = ImVec4(0.28, 0.56, 1.00, 1.00)
    colors[clr.SliderGrab] = ImVec4(0.28, 0.56, 1.00, 1.00)
    colors[clr.SliderGrabActive] = ImVec4(0.37, 0.61, 1.00, 1.00)
    colors[clr.Button] = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.ButtonHovered] = ImVec4(0.28, 0.56, 1.00, 1.00)
    colors[clr.ButtonActive] = ImVec4(0.06, 0.53, 0.98, 1.00)
    colors[clr.Header] = ImVec4(0.20, 0.25, 0.29, 0.55)
    colors[clr.HeaderHovered] = ImVec4(0.26, 0.59, 0.98, 0.80)
    colors[clr.HeaderActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
    colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
    colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
    colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered] = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram] = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(0.25, 1.00, 0.00, 0.43)
    colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end

apply_custom_style()

--[[
	Module ecfg				= require("ecfg")
	nil						= ecfg.mkpath(Str filename)
	
	----------------- TABLE DATA ----------------------
	
	Bool result				= ecfg.update(Table old, Table new / Str new,  [Bool overwrite = true])
	Bool result				= ecfg.save(Str filename, Table new)
	Table loaded / nil		= ecfg.load(Str filename, [Bool save = false])
	Bool result				= ecfg.set(Str filename, Str key / Int key, Value value)
	Bool result				= ecfg.append(Str filename, Value value)
	
	------------------ LIST DATA ----------------------
	
	List loaded / nil		= ecfg.list_load(Str filename, [Bool save = false])
	Bool result				= ecfg.list_save(Str filename, List new)
	Bool result				= ecfg.list_insert(Str filename, Int index / Value value, [Value value])
	Bool result				= ecfg.list_remove(Str filename, [Int index])
	Bool result				= ecfg.list_set(Str filename, Int index, Value value)
]]

local Ecfg = {
    _VERSION = "2.0.4",
    _AUTHOR  = "Double Tap Inside",
    _EMAIL   = "double.tap.inside@gmail.com"
}

function Ecfg.__init()
    local self = {}

    -- \a => '\\a', \0 => '\\0', 31 => '\31'
    local shortControlCharEscapes = {
        ["\a"] = "\\a",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
        ["\v"] = "\\v"
    }

    local longControlCharEscapes = {} -- \a => nil, \0 => \000, 31 => \031

    local function escape(str)
        return (str:gsub("\\", "\\\\")
            :gsub("(%c)%f[0-9]", longControlCharEscapes)
            :gsub("%c", shortControlCharEscapes))
    end

    local function draw_string(str)
        return string.format("%q", escape(str))
    end

    local function draw_key(key)
        if "string" == type(key) and key:match("^[_%a][_%a%d]*$") then
            return key
        elseif "number" == type(key) then
            return "[" .. key .. "]"
        else
            return "[" .. draw_string(key) .. "]"
        end
    end

    local function draw_table(tbl, tab)
        local tab = tab or ""
        local result = {}

        for key, value in pairs(tbl) do
            if type(value) == "string" then
                if type(key) == "number" and key <= #tbl then
                    table.insert(result, draw_string(value))
                else
                    table.insert(result, draw_key(key) .. " = " .. draw_string(value))
                end
            elseif type(value) == "number" or type(value) == "boolean" then
                if type(key) == "number" and key <= #tbl then
                    table.insert(result, tostring(value))
                else
                    table.insert(result, draw_key(key) .. " = " .. tostring(value))
                end
            elseif type(value) == "table" then
                if type(key) == "number" and key <= #tbl then
                    table.insert(result, draw_table(value, tab .. "\t"))
                else
                    table.insert(result, draw_key(key) .. " = " .. draw_table(value, tab .. "\t"))
                end
            else
                if type(key) == "number" and key <= #tbl then
                    table.insert(result, draw_string(tostring(value)))
                else
                    table.insert(result, draw_key(key) .. " = " .. draw_string(tostring(value)))
                end
            end
        end

        if #result == 0 and tab == "" then
            return ""
        elseif #result == 0 then
            return "{}"
        elseif tab == "" then
            return table.concat(result, ",\n") .. ",\n"
        else
            return "{\n" .. tab .. table.concat(result, ",\n" .. tab) .. ",\n" .. tab:sub(2) .. "}"
        end
    end

    local function draw_value(value, tab)
        if type(value) == "string" then
            return draw_string(value)
        elseif type(value) == "number" or type(value) == "boolean" or type(value) == "nil" then
            return tostring(value)
        elseif type(value) == "table" then
            return draw_table(value, tab)
        else
            return draw_string(tostring(value))
        end
    end

    local function draw_list(list)
        local result = {}

        for index, value in ipairs(list) do
            table.insert(result, "table.insert(list, " .. draw_value(value, "\t") .. ")")
        end

        if #result == 0 then
            return ""
        else
            return table.concat(result, "\n") .. "\n"
        end
    end

    function self.list_load(filename, save)
        assert(type(filename) == "string", ("bad argument #1 to 'load' (string expected, got %s)"):format(type(filename)))

        local file = io.open(filename, "r")

        if file then
            local text = file:read("*all")
            file:close()
            local lua_code = loadstring("local list = {}\n" .. text .. "\nreturn list")

            if lua_code then
                local result = lua_code()

                if type(result) == "table" then
                    if save then
                        self.list_save(filename, result)
                    end

                    return result
                end
            end
        end
    end

    function self.list_save(filename, new)
        assert(type(filename) == "string",
            ("bad argument #1 to 'list_save' (string expected, got %s)"):format(type(filename)))
        assert(type(new) == "table", ("bad argument #2 to 'list_save' (table expected, got %s)"):format(type(new)))

        self.mkpath(filename)
        local file = io.open(filename, "w+")

        if file then
            local text = draw_list(new)
            file:write(text)
            file:close()

            return true
        else
            return false
        end
    end

    function self.list_insert(filename, index, value)
        assert(type(filename) == "string",
            ("bad argument #1 to 'list_insert' (string expected, got %s)"):format(type(filename)))

        if value then
            assert(type(index) == "number",
                ("bad argument #2 to 'list_insert' (number expected, got %s)"):format(type(index)))
        end

        local result

        if value then
            result = "table.insert(list, " .. index .. ", " .. draw_value(value, "\t") .. ")"
        else
            result = "table.insert(list, " .. draw_value(index, "\t") .. ")"
        end

        self.mkpath(filename)
        local file = io.open(filename, "a+")

        if file then
            file:write(result .. "\n")
            file:close()
            return true
        else
            return false
        end
    end

    function self.list_remove(filename, index)
        assert(type(filename) == "string",
            ("bad argument #1 to 'list_remove' (string expected, got %s)"):format(type(filename)))
        assert(type(index) == "number" or index == nil,
            ("bad argument #2 to 'list_remove' (number or nil expected, got %s)"):format(type(index)))

        local result

        if index then
            result = "table.remove(list, " .. index .. ")"
        else
            result = "table.remove(list)"
        end

        self.mkpath(filename)
        local file = io.open(filename, "a+")

        if file then
            file:write(result .. "\n")
            file:close()
            return true
        else
            return false
        end
    end

    function self.list_set(filename, index, value)
        assert(type(filename) == "string",
            ("bad argument #1 to 'list_set' (string expected, got %s)"):format(type(filename)))
        assert(type(index) == "number", ("bad argument #2 to 'list_set' (number expected, got %s)"):format(type(index)))

        local result = "list[" .. index .. "] = " .. draw_value(value, "\t")

        self.mkpath(filename)
        local file = io.open(filename, "a+")

        if file then
            file:write(result .. "\n")
            file:close()
            return true
        else
            return false
        end
    end

    function self.mkpath(filename)
        assert(type(filename) == "string",
            ("bad argument #1 to 'mkpath' (string expected, got %s)"):format(type(filename)))

        local sep, pStr = package.config:sub(1, 1), ""
        local path = filename:match("(.+" .. sep .. ").+$") or filename

        for dir in path:gmatch("[^" .. sep .. "]+") do
            pStr = pStr .. dir .. sep
            createDirectory(pStr)
        end
    end

    function self.load(filename, save)
        assert(type(filename) == "string", ("bad argument #1 to 'load' (string expected, got %s)"):format(type(filename)))

        local file = io.open(filename, "r")

        if file then
            local text = file:read("*all")
            file:close()
            local lua_code = loadstring("return {" .. text .. "}")

            if lua_code then
                local result = lua_code()

                if type(result) == "table" then
                    if save then
                        self.save(filename, result)
                    end

                    return result
                end
            end
        end
    end

    function self.save(filename, new)
        assert(type(filename) == "string", ("bad argument #1 to 'save' (string expected, got %s)"):format(type(filename)))
        assert(type(new) == "table", ("bad argument #2 to 'save' (table expected, got %s)"):format(type(new)))

        self.mkpath(filename)
        local file = io.open(filename, "w+")

        if file then
            local text = draw_table(new)
            file:write(text)
            file:close()

            return true
        else
            return false
        end
    end

    function self.append(filename, value)
        assert(type(filename) == "string",
            ("bad argument #1 to 'append' (string expected, got %s)"):format(type(filename)))

        self.mkpath(filename)
        local file = io.open(filename, "a+")

        if file then
            file:write(draw_value(value, "\t") .. ",\n")
            file:close()

            return true
        else
            return false
        end
    end

    function self.set(filename, key, value)
        assert(type(filename) == "string", ("bad argument #1 to 'set' (string expected, got %s)"):format(type(filename)))
        assert(type(key) == "string" or type(key) == "number",
            ("bad argument #2 to 'set' (string or number expected, got %s)"):format(type(key)))

        self.mkpath(filename)
        local file = io.open(filename, "a+")

        if file then
            file:write("\n" .. draw_key(key) .. " = " .. draw_value(value) .. ",")
            file:close()

            return true
        else
            return false
        end
    end

    function self.update(old, new, overwrite)
        assert(type(old) == "table", ("bad argument #1 to 'update' (table expected, got %s)"):format(type(old)))
        assert(type(new) == "string" or type(new) == "table",
            ("bad argument #2 to 'update' (string or table expected, got %s)"):format(type(new)))

        if overwrite == nil then
            overwrite = true
        end

        if type(new) == "table" then
            if overwrite then
                for key, value in pairs(new) do
                    old[key] = value
                end
            else
                for key, value in pairs(new) do
                    if not old[key] then
                        old[key] = value
                    end
                end
            end

            return true
        elseif type(new) == "string" then
            local loaded = self.load(new)

            if loaded then
                if overwrite then
                    for key, value in pairs(loaded) do
                        old[key] = value
                    end
                else
                    for key, value in pairs(loaded) do
                        if not old[key] then
                            old[key] = value
                        end
                    end
                end

                return true
            end
        end

        return false
    end

    return self
end

setmetatable(Ecfg, {
    __call = function(self)
        return self.__init()
    end
})

local ecfg = Ecfg()





local files = {
    settings = getGameDirectory() .. '\\moonloader\\config\\[JF]fps fix\\Настройки.гей',
    stats = getGameDirectory() .. '\\moonloader\\config\\[JF]fps fix\\Статистика.гей',
}
function defaultConfig()
    local cfg = {
        auto_heal = {
            active = false,
            command = '',
            hp = 80,
        },
        lavka = {
            active = false,
            name = '',
        },
        auto_eat = {
            active = false,
            command = '',
        },
        telegram = {
            active = false,
            user_id = '',
            token = '',
            sendsell = false,
        },
        cleaner = false,
        auto_active = false,
    }
    return cfg
end

local cfg = ecfg.load(files.settings)

-- вся база массивом {date, text, server, nick}, ...
local statistic = ecfg.load(files.stats)

if not statistic then
    statistic = {}
    ecfg.save(files.stats, statistic)
end

-- списко выпадающего меню
local im_stats = {
    --[[
	["Server Nickname"] = {
		text,
		text,
	},
	
	["Server Nickname"] = {
		text,
		text,
	},
]]
}

-- вся база разбитая на структуру
local im_choto = {
    --[[
	["Server Nickname"] = {
		["date"] = {
			text,
			text,
		}
	},
	
	["Server Nickname"] = {
		["date"] = {
			text,
			text,
		}
	},
]]
}

-- формирую структуры
for index, item in ipairs(statistic) do
    local server_nickname = item[3] .. " " .. item[4]

    if not im_choto[server_nickname] then
        im_choto[server_nickname] = {}
    end

    if not im_choto[server_nickname][item[1]] then
        if not im_stats[server_nickname] then
            im_stats[server_nickname] = {}
        end

        table.insert(im_stats[server_nickname], 1, item[1])
        im_choto[server_nickname][item[1]] = {}
    end

    table.insert(im_choto[server_nickname][item[1]], 1, item[2])
end


if not cfg then
    cfg = defaultConfig()
    ecfg.save(files.settings, cfg)
end
function writeStatistic(arg)
    local date = os.date("%d.%m.%Y")
    local arizona_name = getArizonaName()
    local my_nickname = sampGetMyNickname()
    local server_nickname = arizona_name .. " " .. my_nickname
    arg = os.date("[%H:%M:%S] ", os.time()) .. arg

    if not im_choto[server_nickname] then
        im_choto[server_nickname] = {}
    end

    if not im_choto[server_nickname][date] then
        im_choto[server_nickname][date] = {}
        table.insert(im_stats[server_nickname], 1, date)
    end

    table.insert(im_choto[server_nickname][date], 1, arg)
    ecfg.append(files.stats, { date, arg, arizona_name, my_nickname })
end

function saveConfig()
    ecfg.save(files.settings, cfg)
end

----------------Переменные дня Imgui
local imgui_cfg = {
    auto_heal = {
        active = imgui.ImBool(false),
        command = imgui.ImBuffer(256),
        hp = imgui.ImInt(0),
    },
    lavka = {
        active = imgui.ImBool(false),
        name = imgui.ImBuffer(256),
    },
    auto_eat = {
        active = imgui.ImBool(false),
        command = imgui.ImBuffer(20),
    },
    telegram = {
        active = imgui.ImBool(false),
        user_id = imgui.ImBuffer(256),
        token = imgui.ImBuffer(256),
        sendsell = imgui.ImBool(false),
    },
    cleaner = imgui.ImBool(false),
    auto_active = imgui.ImBool(false),
}
local imgui_windows = {
    main = imgui.ImBool(false),
}
function refreshImgui()
    imgui_cfg.auto_heal.active.v = cfg.auto_heal.active
    imgui_cfg.auto_heal.command.v = u8(cfg.auto_heal.command)
    imgui_cfg.auto_heal.hp.v = cfg.auto_heal.hp
    imgui_cfg.lavka.name.v = u8(cfg.lavka.name)
    imgui_cfg.lavka.active.v = cfg.lavka.active
    imgui_cfg.auto_eat.active.v = cfg.auto_eat.active
    imgui_cfg.auto_eat.command.v = cfg.auto_eat.command
    imgui_cfg.telegram.active.v = cfg.telegram.active
    imgui_cfg.telegram.user_id.v = cfg.telegram.user_id
    imgui_cfg.telegram.token.v = cfg.telegram.token
    imgui_cfg.telegram.sendsell.v = cfg.telegram.sendsell
    imgui_cfg.cleaner.v = cfg.cleaner
    imgui_cfg.auto_active.v = cfg.auto_active
end

----------------End

local script_status = {
    active = false,
    render = {
        active = false,
        secondFloor = true,
        massive = {},
    },
    palatka = false,
    integrate_plt = {
        active = false,
        buyOrSell = false,
        alt = false,
    }
}



local lavaka_helper = {
    enabled = false,
    debug = false,
    state = 'idle',
    lastOpenAttemptAt = 0,
    lastActionAttemptAt = 0,
    nextOpenAt = 0,
    openAttempts = 0,
    actionAttempts = 0,
    lastCloseAt = 0,
    startedAt = 0,
    lastInstallText = 'Нет данных',
    lastTooFarNoticeAt = 0,
    openRetryMs = 50,
    actionRetryMs = 300,
    baseAfterActionMs = 850,
    afterActionMs = 850,
    minAfterActionMs = 850,
    maxAfterActionMs = 1500,
    retryLimit = 20,
    retryCycles = 0,
    cleanLimit = 20,
    cleanCycles = 0,
    openMenuPacket = { 220, 0, 82, 64 },
    actionCommand = 'radialMenu.useAction|1',
    interactiveMenuText = "window.executeEvent('event.setActiveView', `[\"InteractiveMenu\"]`);",
    closeViewText = "window.executeEvent('event.setActiveView', '[ null ]');",
    alreadyPlacedText = u8:decode('\208\163\32\208\146\208\176\209\129\32\209\131\208\182\208\181\32\209\131\209\129\209\130\208\176\208\189\208\190\208\178\208\187\208\181\208\189\208\176\32\208\187\208\176\208\178\208\186\208\176\33'),
    placedSuccessText = u8:decode('\208\146\209\139\32\209\131\209\129\208\191\208\181\209\136\208\189\208\190\32\208\178\209\139\209\129\209\130\208\176\208\178\208\184\208\187\208\184\32\208\187\208\176\208\178\208\186\209\131\32\208\180\208\187\209\143\32\208\191\209\128\208\190\208\180\208\176\208\182\208\184\47\208\191\208\190\208\186\209\131\208\191\208\186\208\184\32\209\130\208\190\208\178\208\176\209\128\208\176\33'),
    tooFarText = u8:decode('\208\146\209\139\32\208\180\208\176\208\187\208\181\208\186\208\190\32\208\190\209\130\208\190\209\136\208\187\208\184\32\208\190\209\130\32\208\188\208\181\209\129\209\130\208\176\32\209\131\209\129\209\130\208\176\208\189\208\190\208\178\208\186\208\184\33'),
    hintPrefix = u8:decode('\208\159\208\190\208\180\209\129\208\186\208\176\208\183\208\186\208\176'),
    errorPrefix = u8:decode('\208\158\209\136\208\184\208\177\208\186\208\176')
}
function addChat(a)
    sampAddChatMessage('{cca540}[fps fix]: {ffffff}' .. a, -1)
end

function main()
    repeat wait(0) until isSampAvailable()
    while not isSampLoaded() do wait(0) end
    lua_thread.create(main_thread)
    lua_thread.create(heal_thread)
    refreshImgui()
    sampRegisterChatCommand('fps', function() imgui_windows.main.v = not imgui_windows.main.v end)
    addChat('/fps')
    while true do
        wait(0)
        imgui.Process = imgui_windows.main.v
        processLavakaHelper()
    end
end

-----------------Main Thread
local render_status_active = false
local render_status_flood = false
local render_status_lovec = false
function main_thread()
    local posX2, posY2, posZ2
    local bit = require 'lib.samp.events.bitstream_io'
    while true do
        wait(0)


        if render_status_lovec then
            local x, y, z = getCharCoordinates(PLAYER_PED)
            --local posX2, posY2, posZ2
            if not posX2 then
                for id = 0, 2048 do
                    if sampIs3dTextDefined(id) then
                        local text, color, posX, posY, posZ, distance, ignoreWalls, player, vehicle =
                            sampGet3dTextInfoById(id)
                        if text:find('[ Ларцы Concept Car Luxury ]', 1, false) and text:find('{ffffff}В наличии. {C87D6D}%d+ шт') and tonumber(text:match('{ffffff}В наличии. {C87D6D}(%d+) шт')) > 0 and getDistanceBetweenCoords3d(posX, posY, posZ, x, y, z) < 1.7 then
                            render_status_flood = true
                            posX2, posY2, posZ2 = posX, posY, posZ
                        end
                    end
                end
            else
                if getDistanceBetweenCoords3d(posX2, posY2, posZ2, x, y, z) > 1.7 then
                    render_status_flood = false
                    posX2, posY2, posZ2 = nil, nil, nil
                end
            end
        end

        if script_status.render.active then
            local input = sampGetInputInfoPtr()
            local input = getStructElement(input, 0x8, 4)
            local PosX = getStructElement(input, 0x8, 4)
            local PosY = getStructElement(input, 0xC, 4)
            if #script_status.render.massive > 0 then
                renderFontDrawText(font, '{ffa500}[/fch] {ffc0cb}Свободно лавок: {99ff99}' ..
                    #script_status.render.massive, PosX, PosY + 160, 0xFFFFFFFF, 0x90000000)
            else
                renderFontDrawText(font, '{ffa500}[/fch] {ffc0cb}Свободно лавок: {ffffff}' ..
                    #script_status.render.massive, PosX, PosY + 160, 0xFFFFFFFF, 0x90000000)
            end
            for v = 1, #script_status.render.massive do
                if doesObjectExist(script_status.render.massive[v]) then
                    local result, obX, obY, obZ = getObjectCoordinates(script_status.render.massive[v])
                    local x, y, z = getCharCoordinates(PLAYER_PED)

                    if result then
                        local ObjX, ObjY = convert3DCoordsToScreen(obX, obY, obZ)
                        local myX, myY = convert3DCoordsToScreen(x, y, z)

                        if isObjectOnScreen(script_status.render.massive[v]) then
                            renderDrawLine(ObjX, ObjY, myX, myY, 1, 0xFF52FF4D)
                            renderDrawPolygon(myX, myY, 10, 10, 10, 0, 0xFFFFFFFF)
                            renderDrawPolygon(ObjX, ObjY, 10, 10, 10, 0, 0xFFFFFFFF)
                            renderFontDrawText(font_two, 'Свободна', ObjX - 30, ObjY - 20, 0xFF16C910, 0x90000000)
                        end
                        if render_status_active then
                            local char_x, char_y, char_z = getCharCoordinates(PLAYER_PED)
                            if getDistanceBetweenCoords3d(char_x, char_y, char_z, obX, obY, obZ) < 1.5 then
                                render_status_flood = true
                            end
                        end
                    end
                end
            end
        end


        if script_status.active then
            if cfg.cleaner then
                local input = sampGetInputInfoPtr()
                local input = getStructElement(input, 0x8, 4)
                local PosX = getStructElement(input, 0x8, 4)
                local PosY = getStructElement(input, 0xC, 4) - 15
                renderFontDrawText(font_two,
                    '{ffa500}[/fch] {ffffff}Очиститель {99ff99}работает! {808080}(( Имейте ввиду, не двигайтесь ))', PosX,
                    PosY + 80, 0xFFFFFFFF, 0x90000000)
                if sampGetPlayerCount(true) > 1 then
                    for _, handle in ipairs(getAllChars()) do
                        if doesCharExist(handle) then
                            local _, id = sampGetPlayerIdByCharHandle(handle)
                            if id ~= myid then
                                emul_rpc('onPlayerStreamOut', { id })
                            end
                        end
                    end
                end
                if #getAllVehicles() > 0 then
                    local cars = getAllVehicles()
                    for i = 1, #cars do
                        local res, id = sampGetVehicleIdByCarHandle(cars[i])
                        if res and cars[i] ~= 1 then
                            local w = bit.bs_write
                            local bs = raknetNewBitStream()
                            w.int16(bs, id)
                            raknetEmulRpcReceiveBitStream(165, bs)
                        end
                    end
                end
            end
        end
    end
end

function heal_thread()
    while true do
        wait(0)
        if render_status_lovec and render_status_flood then
            repeat
                local data = samp_create_sync_data('player')
                data.keysData = data.keysData + 1024
                data.send()
                wait(100)
            until not render_status_lovec or not render_status_flood
            render_status_flood = false
        end
        if script_status.render.active and render_status_flood and render_status_active then
            repeat
                local data = samp_create_sync_data('player')
                data.keysData = data.keysData + 1024
                data.send()
                wait(100)
            until not script_status.render.active or not render_status_flood
            render_status_flood = false
        end
        if script_status.integrate_plt.alt and script_status.integrate_plt.active then
            repeat
                local data = samp_create_sync_data('player')
                data.keysData = data.keysData + 1024
                data.send()
                wait(100)
            until not script_status.integrate_plt.alt or not script_status.integrate_plt.active
        end
        if script_status.active and cfg.auto_heal.active then
            if getCharHealth(PLAYER_PED) < cfg.auto_heal.hp then
                repeat
                    sampSendChat(cfg.auto_heal.command)
                    wait(1000)
                until getCharHealth(PLAYER_PED) > cfg.auto_heal.hp or not cfg.auto_heal.active or not script_status.active
            end
        end
    end
end

-----------------End

-----------------Events
function sampev.onSetObjectMaterialText(id, data)
    if data.text:find('Номер %d+%. {......}Свободная!') and tonumber(data.text:match('Номер (%d+)%. {......}Свободная!')) < 39 then
        local object = sampGetObjectHandleBySampId(id)
        table.insert(script_status.render.massive, object)
    else
        local ob = sampGetObjectHandleBySampId(id)
        for i = 1, #script_status.render.massive do
            if ob == script_status.render.massive[i] then
                table.remove(script_status.render.massive, i)
            end
        end
    end
end

function sampev.onDestroyObject(id)
    for k = 1, #script_status.render.massive do
        local ob = sampGetObjectHandleBySampId(id)
        if ob == script_status.render.massive[k] then
            table.remove(script_status.render.massive, k)
        end
    end
end

function sampev.onShowTextDraw(id, data)
    if script_status.active then
        if data.text:find('^.+ %- .+ .+ %(.+%)~n~$') and data.modelId == 0 and data.letterColor == -5397778 then
            local nick, gun, damage = data.text:match('^(.+) %- (.+) (.+) %(.+%)~n~$')
            writeStatistic('Зарегестрирован Урон. Источник: ' .. nick .. ' Оружие: ' .. gun .. '. Урон: ' .. damage)
            if cfg.telegram.active then
                sendTelegram('Зарегестрирован Урон. Источник: ' .. nick .. ' Оружие: ' .. gun .. '. Урон: ' .. damage)
            end
        elseif data.text:find('^Collision .+ %(.+%)~n~$') and data.modelId == 0 and data.letterColor == -5397778 then
            writeStatistic('Зарегестрирован Урон. Источник: Collision. Урон: ' ..
                data.text:match('^Collision (.+) %(.+%)~n~$'))
            if cfg.telegram.active then
                sendTelegram('Зарегестрирован Урон. Источник: Collision. Урон: ' ..
                    data.text:match('^Collision (.+) %(.+%)~n~$'))
            end
        end
    end
end

function sampev.onServerMessage(color, text)
    handleLavakaServerMessage(text)
    if text:find('^%[Подсказка%] {FFFFFF}Вы успешно арендовали лавку для продажи') or text:find('^%[Подсказка%] {FFFFFF}Вы успешно выставили лавку для продажи.покупки товара.$') then
        script_status.active = true
        --addChat('Вы встали в лавку. Функции включены.')
        writeStatistic('Вы встали в лавку. Функции включены.')
        if cfg.telegram.active then
            sendTelegram('Вы встали в лавку. Функции включены.')
        end
    elseif script_status.active and (text:find('^%[Информация%] {FFFFFF}Вы отказались от аренды лавки') or text:find('^%[Информация%] {FFFFFF}Вы сняли лавку') or text:find('^%[Информация%] {FFFFFF}У Вас закончилось время для настройки товаров')) then
        script_status.active = false
        --addChat('Вы вышли из лавки. Функции отключены!')
        writeStatistic('Вы вышли из лавки. Функции отключены!')
        if cfg.telegram.active then
            sendTelegram('Вы вышли из лавки. Функции отключены!')
        end
    elseif script_status.active and (text:find('^%[Информация%] {FFFFFF}Ваша лавка была закрыта')) then
        script_status.active = false
        --addChat('Вас выкинули с вашей лавки!')
        writeStatistic('Вас выкинули с вашей лавки!')
        if cfg.telegram.active then
            sendTelegram('Вас выкинули с вашей лавки!')
        end
    end
    if script_status.active then
        -- Продажа с обычным $
        if text:find('^.+ купил у вас .+, вы получили %$%d+ от продажи %(комиссия %d процент%(а%)%)') then
            local name, product, money = text:match(
                '^(.+) купил у вас (.+), вы получили %$(%d+) от продажи %(комиссия %d процент%(а%)%)')
            local reg_text = 'Вы продали: "' .. product .. '" за ' .. money .. '$ Игроку: ' .. name .. '.'
            writeStatistic(reg_text)
            if cfg.telegram.active and cfg.telegram.sendsell then
                sendTelegram(reg_text)
            end

            -- Покупка с обычным $
        elseif text:find('^Вы купили .+ у игрока .+ за %$%d+') then
            local product, name, money = text:match('^Вы купили (.+) у игрока (.+) за %$(%d+)')
            local reg_text = 'Вы купили: "' .. product .. '" за ' .. money .. '$ У игрока: ' .. name .. '.'
            writeStatistic(reg_text)
            if cfg.telegram.active and cfg.telegram.sendsell then
                sendTelegram(reg_text)
            end

            -- Продажа с VC$
        elseif text:find('^.+ купил у вас .+, вы получили VC%$%d+ от продажи %(комиссия %d процент%(а%)%)') then
            local name, product, money = text:match(
                '^(.+) купил у вас (.+), вы получили VC%$(%d+) от продажи %(комиссия %d процент%(а%)%)')
            local reg_text = '[SOSITY] Вы продали: "' .. product .. '" за ' .. money .. 'VC$ Игроку: ' .. name .. '.'
            writeStatistic(reg_text)
            if cfg.telegram.active and cfg.telegram.sendsell then
                sendTelegram(reg_text)
            end

            -- Покупка с VC$ (ИСПРАВЛЕНО)
        elseif text:find('^Вы купили .+ у игрока .+ за VC%$%d+') then
            local product, name, money = text:match('^Вы купили (.+) у игрока (.+) за VC%$(%d+)')
            local reg_text = '[SOSITY] Вы купили: "' .. product .. '" за ' .. money .. 'VC$ У игрока: ' .. name .. '.'
            writeStatistic(reg_text)
            if cfg.telegram.active and cfg.telegram.sendsell then
                sendTelegram(reg_text)
            end
        end
    end
end

function sampev.onDisplayGameText(style, time, text)
    if script_status.active and cfg.auto_eat.active then
        if text:find('You are hungry!') or text:find('You are very hungry!') then
            sampSendChat(cfg.auto_eat.command)
        end
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if render_status_lovec then
        if text:find('Открывая эти ларцы вы сможете получить:', 1, false) and text:find('{ffffff}А так же есть возможность выиграть:', 1, false) and not text:find('AZ Coins') then
            sampSendDialogResponse(id, 1, nil, nil)
            return false
        elseif text:find("{ffffff}Вы действительно хотите купить ларец 'Concept Car Luxury'?", 1, false) and text:find('Его стоимость. {C87D6D}.+') and title:find('{BFBBBA}Concept Car Luxury', 1, false) then
            sampSendDialogResponse(id, 1, nil, nil)
            addChat('Вы купили ларец.')
            return false
        elseif text:find('{C87D6D}На данный момент нет ларцов в наличии', 1, false) or text:find('{C87D6D}Нельзя покупать более 1 ларца за 10 секунд.', 1, false) then
            render_status_lovec = false
            render_status_flood = false
            addChat('Вы не можете купить больше ларцов. Ловля отключена!')
            sampSendDialogResponse(id, 1, nil, nil)
            return false
        end
    end
    if cfg.lavka.active then
        if text:find('Вы действительно хотите выставить свой {85E94E}товар{FFFFFF} на продажу?', 1, false) then
            if render_status_active or render_status_flood then
                render_status_active = false
                render_status_flood = false
            end
            lua_thread.create(function()
                wait(200)
                sampSendDialogResponse(id, 1)
            end)
            return false
        elseif text:find('{FFFFFF}Введите название вашей лавки.', 1, false) then
            lua_thread.create(function()
                wait(3000)
                sampSendDialogResponse(id, 1, nil, cfg.lavka.name)
            end)
            return false
        elseif text:find('{4E9EE9}|||||||||||||||||||', 1, false) and text:find('{9EE94E}|||||||||||||||||||', 1, false) and text:find('{30A641}|||||||||||||||||||', 1, false) and title:find('{BFBBBA}Выберете цвет', 1, false) then
            lua_thread.create(function()
                wait(700)
                sampSendDialogResponse(id, 1, math.random(0, 2), nil)
            end)
            return false
        end
    end
end

function onReceivePacket(id, bitStream)
    handleSatietyReceivePacket(id, bitStream)
    handleLavakaReceivePacket(id, bitStream)
    if script_status.active then
        if (id == PACKET_DISCONNECTION_NOTIFICATION) or
            (id == PACKET_CONNECTION_LOST) then
            script_status.active = false
            --addChat('Зафиксирована потеря соединения с сервером. Скрипт отключен.')
            writeStatistic('Зафиксирована потеря соединения с сервером. Скрипт отключен.')
            if cfg.telegram.active then
                sendTelegram('Зафиксирована потеря соединения с сервером. Скрипт отключен.')
            end
        end
    end
end

local cef_satiety = {
    threshold = 20,
    cooldownMs = 15000,
    lastEatAt = 0,
    lastValue = nil
}

function handleSatietyReceivePacket(id, bs)
    if id ~= 220 then return end

    local text = lavakaReadCefPacket(bs)
    local value = parseSatietyCef(text)
    if not value then return end

    cef_satiety.lastValue = value
    if value <= cef_satiety.threshold then
        triggerAutoEatBySatiety(value)
    end
end

function parseSatietyCef(text)
    if type(text) ~= 'string' then return nil end
    if not text:find("event.arizonahud.playerSatiety", 1, true) then return nil end

    local value = text:match("%[(%d+)%]")
    return value and tonumber(value) or nil
end

function triggerAutoEatBySatiety(value)
    if not cfg.auto_eat.active then return end

    local command = tostring(cfg.auto_eat.command or '')
    command = command:gsub('^%s+', ''):gsub('%s+$', '')
    if command == '' then return end

    local now = math.floor(os.clock() * 1000)
    if now - cef_satiety.lastEatAt < cef_satiety.cooldownMs then return end

    cef_satiety.lastEatAt = now
    sampSendChat(command)
    writeStatistic('AutoEat CEF satiety trigger: ' .. tostring(value))
end
function onReceiveRpc(id, bitStream)
    if script_status.active then
        if (id == RPC_SCRINITGAME) then
            script_status.active = false
            writeStatistic('Обнаружен реконнект. Скрипт отклюен.')
            --addChat('Обнаружен реконнект. Скрипт отклюен.')
        end
    end
end

-----------------End

--------------Telergam
function sendTelegram(message)
    local function threadHandle(runner, url, args, resolve, reject)
        local t = runner(url, args)
        local r = t:get(0)
        while not r do
            r = t:get(0)
            wait(0)
        end
        local status = t:status()
        if status == 'completed' then
            local ok, result = r[1], r[2]
            if ok then resolve(result) else reject(result) end
        elseif err then
            reject(err)
        elseif status == 'canceled' then
            reject(status)
        end
        t:cancel(0)
    end
    local function requestRunner()
        return effil.thread(function(u, a)
            local https = require 'ssl.https'
            local ok, result = pcall(https.request, u, a)
            if ok then
                return { true, result }
            else
                return { false, result }
            end
        end)
    end
    local function async_http_request(url, args, resolve, reject)
        local runner = requestRunner()
        if not reject then reject = function() end end
        lua_thread.create(function()
            threadHandle(runner, url, args, resolve, reject)
        end)
    end
    local function encodeUrl(str)
        str = str:gsub(' ', '%+')
        str = str:gsub('\n', '%%0A')
        return u8:encode(str, 'CP1251')
    end
    local function sendTelegramNotification(msg)
        msg = msg:gsub('{......}', '')
        msg = encodeUrl(msg)
        async_http_request(
            'https://api.telegram.org/bot' ..
            cfg.telegram.token .. '/sendMessage?chat_id=' .. cfg.telegram.user_id .. '&text=' .. msg, '',
            function(result) end)
    end
    if message and message:len() > 0 then
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if _ then
            local srv = getArizonaName()
            if not srv then
                srv = 'Err'
            end
            message = '[' .. srv .. ']' .. sampGetPlayerNickname(id) .. '(' .. id .. '):\n' .. message
            sendTelegramNotification(message)
        else
            message = '[Err]Unknown_Name(nil):\n' .. message
            sendTelegramNotification(message)
        end
    else
        sendTelegramNotification('[JF fps fix]: Попытался отправить сообщение, однако что-то пошло не так!')
    end
end

--------------End

---------------Imgui
local fontsize = nil
function imgui.BeforeDrawFrame()
    if fontsize == nil then
        fontsize = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 30.0, nil,
            imgui.GetIO().Fonts:GetGlyphRangesCyrillic()) -- вместо 30 любой нужный размер
    end
end

local tabs = 1
local statistic_imCombo = imgui.ImInt(0)
local search_buffer = imgui.ImBuffer(256)
function lavakaHelperSetEnabled(value)
    lavaka_helper.enabled = value
    resetLavakaHelperState()
    if lavaka_helper.enabled then
        imgui_windows.main.v = false
        imgui.Process = false
        resetLavakaAdaptiveDelay()
        lavaka_helper.startedAt = lavakaNowMs()
    else
        lavaka_helper.startedAt = 0
    end
    addChat(lavaka_helper.enabled and 'Помощник установки лавки включен.' or 'Помощник установки лавки выключен.')
end

function processLavakaHelper()
    if not lavaka_helper.enabled then return end

    local now = lavakaNowMs()
    if lavaka_helper.state == 'pause' then
        if now >= lavaka_helper.nextOpenAt then
            lavaka_helper.state = 'idle'
        else
            return
        end
    end

    if lavaka_helper.state == 'idle' then
        if now >= lavaka_helper.nextOpenAt and now - lavaka_helper.lastOpenAttemptAt >= lavaka_helper.openRetryMs then
            lavakaSendRawPacket(lavaka_helper.openMenuPacket)
            lavaka_helper.state = 'wait_menu'
            lavaka_helper.lastOpenAttemptAt = now
            lavaka_helper.openAttempts = lavaka_helper.openAttempts + 1
        end
        return
    end

    if lavaka_helper.state == 'wait_menu' then
        if now >= lavaka_helper.nextOpenAt and now - lavaka_helper.lastOpenAttemptAt >= lavaka_helper.openRetryMs then
            lavakaSendRawPacket(lavaka_helper.openMenuPacket)
            lavaka_helper.lastOpenAttemptAt = now
            lavaka_helper.openAttempts = lavaka_helper.openAttempts + 1
        end
        return
    end

    if lavaka_helper.state == 'wait_close' then
        if now - lavaka_helper.lastActionAttemptAt >= lavaka_helper.actionRetryMs then
            lavakaSendCefCommand(lavaka_helper.actionCommand)
            lavaka_helper.lastActionAttemptAt = now
            lavaka_helper.actionAttempts = lavaka_helper.actionAttempts + 1
        end
    end
end

function handleLavakaReceivePacket(id, bs)
    if not lavaka_helper.enabled or id ~= 220 then return end
    if lavaka_helper.state ~= 'wait_menu' and lavaka_helper.state ~= 'wait_close' then return end

    local text, packets = lavakaReadCefPacket(bs)
    if lavaka_helper.state == 'wait_menu' and lavakaIsInteractiveMenuPacket(text, packets) then
        lavakaReportOpenTiming()
        lavakaSendCefCommand(lavaka_helper.actionCommand)
        lavaka_helper.state = 'wait_close'
        lavaka_helper.lastActionAttemptAt = lavakaNowMs()
        lavaka_helper.actionAttempts = 1
        return
    end

    if lavaka_helper.state == 'wait_close' and lavakaIsCloseViewPacket(text, packets) then
        lavakaReportActionTiming()
        lavakaUpdateAdaptiveDelayByRetries()
        resetLavakaHelperState(lavaka_helper.afterActionMs)
        return
    end
end

function handleLavakaServerMessage(text)
    if not lavaka_helper.enabled or not text then return end

    local placed = lavakaIsSystemChat(text, lavaka_helper.hintPrefix, lavaka_helper.placedSuccessText)
    local alreadyPlaced = lavakaIsSystemChat(text, lavaka_helper.errorPrefix, lavaka_helper.alreadyPlacedText)
    if placed or alreadyPlaced then
        lavakaReportInstallTime()
        lavaka_helper.enabled = false
        resetLavakaHelperState()
        lavaka_helper.startedAt = 0
        addChat('Лавка установлена, помощник выключен.')
        return
    end

    if lavakaIsSystemChat(text, lavaka_helper.errorPrefix, lavaka_helper.tooFarText) then
        resetLavakaHelperState(lavaka_helper.afterActionMs)
        lavakaReportTooFar()
    end
end

function lavakaIsSystemChat(text, prefix, needle)
    local cleanText = lavakaCleanChatText(text)
    return cleanText:find('[' .. prefix .. ']', 1, true) == 1 and cleanText:find(needle, 1, true) ~= nil
end

function lavakaCleanChatText(text)
    if not text then return '' end
    return text:gsub('{%x%x%x%x%x%x}', ''):gsub('^%s+', '')
end
function lavakaSendRawPacket(bytes)
    local bs = raknetNewBitStream()
    for _, byte in ipairs(bytes) do
        raknetBitStreamWriteInt8(bs, byte)
    end
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function lavakaSendCefCommand(text)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #text)
    raknetBitStreamWriteString(bs, text)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function lavakaReadCefPacket(bs)
    local text, packets = '', {}
    local bytesUsed = raknetBitStreamGetNumberOfBytesUsed(bs)

    for i = 1, bytesUsed do
        local byte = raknetBitStreamReadInt8(bs)
        if byte >= 32 and byte <= 255 and byte ~= 37 then
            text = text .. string.char(byte)
        end
        table.insert(packets, byte)
    end

    raknetBitStreamResetReadPointer(bs)

    local ok, decoded = pcall(function()
        if raknetBitStreamReadInt8(bs) == 220 and raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamIgnoreBits(bs, 4 * 8)
            local textSize = raknetBitStreamReadInt16(bs)
            if textSize > 0 then
                local textEncoded = raknetBitStreamReadInt8(bs)
                if textEncoded ~= 0 then
                    return raknetBitStreamDecodeString(bs, textSize + textEncoded)
                end
                return raknetBitStreamReadString(bs, textSize)
            end
        end
    end)
    if ok and decoded and #decoded > 0 then
        text = decoded
    end

    raknetBitStreamResetReadPointer(bs)
    return text, packets
end

function lavakaIsInteractiveMenuPacket(text, packets)
    return text == lavaka_helper.interactiveMenuText
end

function lavakaIsCloseViewPacket(text, packets)
    return text == lavaka_helper.closeViewText
end

function lavakaReportOpenTiming()
    if lavaka_helper.debug and lavaka_helper.openAttempts > 1 then
        local extraMs = (lavaka_helper.openAttempts - 1) * lavaka_helper.openRetryMs
        local fromClose = lavaka_helper.lastCloseAt > 0 and (lavakaNowMs() - lavaka_helper.lastCloseAt) or 0
        if fromClose > 0 then
            addChat(('Меню открылось с %d попытки, после закрытия прошло %d мс, расчетный кд %d мс.'):format(lavaka_helper.openAttempts, fromClose, lavaka_helper.afterActionMs + extraMs))
        else
            addChat(('Меню открылось с %d попытки, расчетный кд %d мс.'):format(lavaka_helper.openAttempts, lavaka_helper.afterActionMs + extraMs))
        end
    end
end

function lavakaReportActionTiming()
    if lavaka_helper.debug and lavaka_helper.actionAttempts > 1 then
        local extraMs = (lavaka_helper.actionAttempts - 1) * lavaka_helper.actionRetryMs
        addChat(('Действие прошло с %d попытки, шаг %d мс, ожидание %d мс.'):format(lavaka_helper.actionAttempts, lavaka_helper.actionRetryMs, extraMs))
    end
end

function lavakaUpdateAdaptiveDelayByRetries()
    local hadRetry = lavaka_helper.openAttempts > 1 or lavaka_helper.actionAttempts > 1

    if hadRetry then
        lavaka_helper.retryCycles = lavaka_helper.retryCycles + 1
        lavaka_helper.cleanCycles = 0
        if lavaka_helper.retryCycles > lavaka_helper.retryLimit then
            lavakaRaiseAdaptiveDelay()
            lavaka_helper.retryCycles = 0
        end
    else
        lavaka_helper.cleanCycles = lavaka_helper.cleanCycles + 1
        lavaka_helper.retryCycles = 0
        if lavaka_helper.cleanCycles >= lavaka_helper.cleanLimit then
            lavakaLowerAdaptiveDelay()
            lavaka_helper.cleanCycles = 0
        end
    end
end

function lavakaRaiseAdaptiveDelay()
    if lavaka_helper.afterActionMs >= lavaka_helper.maxAfterActionMs then return end

    lavaka_helper.afterActionMs = math.min(lavaka_helper.afterActionMs + 50, lavaka_helper.maxAfterActionMs)
    addChat('Адаптивный кд увеличен: ' .. lavaka_helper.afterActionMs .. ' мс.')
end

function lavakaLowerAdaptiveDelay()
    if lavaka_helper.afterActionMs <= lavaka_helper.minAfterActionMs then return end

    lavaka_helper.afterActionMs = math.max(lavaka_helper.afterActionMs - 25, lavaka_helper.minAfterActionMs)
    lavaka_helper.retryCycles = 0
    addChat('Адаптивный кд снижен: ' .. lavaka_helper.afterActionMs .. ' мс.')
end

function resetLavakaAdaptiveDelay()
    lavaka_helper.afterActionMs = lavaka_helper.baseAfterActionMs
    lavaka_helper.retryCycles = 0
    lavaka_helper.cleanCycles = 0
end

function lavakaReportInstallTime()
    if lavaka_helper.startedAt <= 0 then return end

    local elapsedMs = math.max(lavakaNowMs() - lavaka_helper.startedAt, 1)
    local minutes = math.max(math.ceil(elapsedMs / 60000), 1)
    lavaka_helper.lastInstallText = 'Последняя установка: меньше чем за ' .. minutes .. ' ' .. lavakaMinuteWord(minutes)
    addChat('Вы установили лавку меньше чем за ' .. minutes .. ' ' .. lavakaMinuteWord(minutes) .. '.')
end

function lavakaReportTooFar()
    local now = lavakaNowMs()
    if now - lavaka_helper.lastTooFarNoticeAt < 5000 then return end

    lavaka_helper.lastTooFarNoticeAt = now
    addChat('Вы далеко от места установки, помощник продолжает попытки.')
end

function resetLavakaHelperState(delayMs)
    if delayMs and delayMs > 0 then
        lavaka_helper.lastCloseAt = lavakaNowMs()
    end
    lavaka_helper.state = 'idle'
    lavaka_helper.lastOpenAttemptAt = 0
    lavaka_helper.lastActionAttemptAt = 0
    lavaka_helper.nextOpenAt = lavakaNowMs() + (delayMs or 0)
    lavaka_helper.openAttempts = 0
    lavaka_helper.actionAttempts = 0
    if delayMs and delayMs > 0 then
        lavaka_helper.state = 'pause'
    end
end

function lavakaNowMs()
    return math.floor(os.clock() * 1000)
end

function lavakaMinuteWord(value)
    local lastTwo = value % 100
    local last = value % 10

    if lastTwo >= 11 and lastTwo <= 14 then
        return 'минут'
    elseif last == 1 then
        return 'минуту'
    elseif last >= 2 and last <= 4 then
        return 'минуты'
    end

    return 'минут'
end

function lavakaStatusText()
    if lavaka_helper.enabled then
        return 'Статус: включен | состояние: ' .. lavaka_helper.state .. ' | кд: ' .. lavaka_helper.afterActionMs .. ' мс'
    end
    return 'Статус: выключен | кд: ' .. lavaka_helper.afterActionMs .. ' мс'
end

function drawLavakaHelperUi()
    imgui.Separator()
    imgui.TextColored(imgui.ImVec4(0.28, 0.56, 1.00, 1.00), u8 'Помощник установки лавки')
    imgui.TextDisabled(u8(lavakaStatusText()))
    imgui.TextDisabled(u8(lavaka_helper.lastInstallText))

    if imgui.ButtonActivatedWithHint(u8 'Включает строгую CEF-цепочку установки лавки: открыть интерактивное меню, дождаться ответа, выбрать действие и дождаться закрытия.', lavaka_helper.enabled, u8(lavaka_helper.enabled and 'Остановить помощник' or 'Запустить помощник'), imgui.ImVec2(170, 0)) then
        lavakaHelperSetEnabled(not lavaka_helper.enabled)
    end
    imgui.SameLine()
    if imgui.ButtonActivatedWithHint(u8 'Показывает технические сообщения о повторных попытках и текущем расчетном кд.', lavaka_helper.debug, u8(lavaka_helper.debug and 'Скрыть диагностику' or 'Показать диагностику'), imgui.ImVec2(170, 0)) then
        lavaka_helper.debug = not lavaka_helper.debug
        addChat('Диагностика помощника установки лавки: ' .. (lavaka_helper.debug and 'включена.' or 'выключена.'))
    end
end
function imgui.OnDrawFrame()
    local w, h = getScreenResolution()
    local arizona_name = getArizonaName()
    local my_nickname = sampGetMyNickname()
    local server_nickname = arizona_name .. " " .. my_nickname

    if not im_stats[server_nickname] then
        im_stats[server_nickname] = {}
    end

    if statistic_imCombo.v + 1 > #im_stats[server_nickname] then
        statistic_imCombo.v = 0
    end

    if imgui_windows.main.v then
        imgui.SetNextWindowSize(imgui.ImVec2(800, 600), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(w / 2 - 800 / 2, h / 2 - 600 / 2), imgui.Cond.FirstUseEver)
        imgui.Begin(u8('[JF] fps fix ' .. script__version) .. " ##main_window", imgui_windows.main,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

        imgui.BeginChild('##main_window_childddddddd', imgui.ImVec2(0, 50), true)

        --imgui.SameLine()

        imgui.SetCursorPosX(imgui.GetCursorPos().x + 10)
        if imgui.ButtonActivated(tabs == 1, u8 "Настройки##tab one", imgui.ImVec2(150, 0)) then
            tabs = 1
        end
        imgui.SameLine()
        if imgui.ButtonActivated(tabs == 3, u8 "Логи##tab three", imgui.ImVec2(150, 0)) then
            tabs = 3
        end
        imgui.SameLine()
        --imgui.SetCursorPosY(8)
        imgui.SetCursorPosX(590)
        imgui.SetCursorPosY(8)
        imgui.VerticalSeparator()
        imgui.SetCursorPosX(600)
        imgui.SetCursorPosY((imgui.GetWindowHeight() - 20) / 2)
        if imgui.ButtonActivatedWithHint(u8 'Ручное "Включение/Отключение" скрипта.\nКрайне не рекомендуется использование вне лавки.\nЗа некоторые функции есть риски бана!', script_status.active, u8 'Активация', imgui.ImVec2(150, 0)) then
            script_status.active = not script_status.active
            if script_status.active then
                --addChat('Функции включены вручную.')
                writeStatistic('Функции включены вручную.')
                if cfg.telegram.active then
                    sendTelegram('Функции включены вручную.')
                end
            else
                --addChat('Функции отключены вручную.')
                writeStatistic('Функции отключены вручную.')
                if cfg.telegram.active then
                    sendTelegram('Функции отключены вручную.')
                end
            end
        end
        imgui.EndChild()

        imgui.BeginChild('##main_window_child', imgui.ImVec2(0, 0), true)


        if tabs == 1 then
            if imgui.ButtonActivatedWithHint(u8 'Включить/Выключить Рендер Лавок\nРендер свободных лавок на ЦР, за исключением второго этажа.', script_status.render.active, u8 'Рендер Лавок', imgui.ImVec2(100, 0)) then
                script_status.render.active = not script_status.render.active
                if render_status_active then
                    render_status_active = false
                    render_status_flood = false
                end
            end
            if script_status.render.active then
                imgui.SameLine()
                if imgui.ButtonActivatedWithHint(u8 'Включить/Выключить Ловлю Лавок\nЕсли включено - Функция профлудит Alt если подойдёте к свободной лавке.\nТак же можете встать у лавки, как только она освободится скрипт её словит.\nДля максимальной эффективности рекомендуется включить Авто-Взятие Лавки.', render_status_active, u8 'Ловец Лавок', imgui.ImVec2(100, 0)) then
                    render_status_active = not render_status_active
                    render_status_flood = false
                end
                imgui.SameLine()
                if imgui.ButtonActivatedWithHint(u8 'Перезагрузка рендера Лавок.\nЕсли у вас проблема с рендером лавок, нажмите сюда что-бы перезагрузить его.', false, u8 'Сброс Лавок', imgui.ImVec2(100, 0)) then
                    render_status_active = false
                    render_status_flood = false
                    script_status.render.active = false
                    script_status.render.massive = {}
                    addChat('Рендер перезагружен! Обновите зону стрима.')
                end
            end
            imgui.SameLine()
            imgui.BeginChild('##sukavertical govno', imgui.ImVec2(8, 25), false)
            imgui.SetCursorPosY(4)
            imgui.VerticalSeparator()
            imgui.EndChild()
            imgui.SameLine()
            if imgui.ButtonActivatedWithHint(u8 'Включить/Выключить ловца Concept Car Luxury.\nАвтоматически ловит ларец Concept Car Luxury.\nФункция срабатывает только если ларцы есть в наличии!', render_status_lovec, u8 'Ловец Ларца', imgui.ImVec2(100, 0)) then
                render_status_lovec = not render_status_lovec
                --[[                    if render_status_lovec and getPlayerMoney(select(1,sampGetPlayerIdByCharHandle(PLAYER_PED))) < 200000 then
                        render_status_lovec = false
                        addChat('Ошибочка, у вас не хватает денег на ларец.')
                    end]]
            end
            imgui.Separator()
            --[[                if imgui.CheckboxWithHint(u8'Автоматическая Активация\nАктивация скрипта автоматически, при входе в лавку.', u8('Автоматическая Активация'), imgui_cfg.auto_active) then
                    cfg.auto_active = imgui_cfg.auto_active.v
                    saveConfig()
                end
                imgui.Separator()]]
            if imgui.CheckboxWithHint(u8 'Авто-Еда\nФункция выполняет указанную команду при обнаружении голода.', u8 'Авто-еда', imgui_cfg.auto_eat.active) then
                cfg.auto_eat.active = imgui_cfg.auto_eat.active.v
                saveConfig()
            end
            if cfg.auto_eat.active then
                if imgui.InputTextWithHintEx(u8 'Введите команду которую скрипт будет выполнять при обнаружении голода.\nПримеры:\n/meatbag - Мешок с мясом\n/jmeat - Жаренное мясо оленины\n/cheeps - Чипсы\n(( Команды обязательно писать с / ))', u8 'Команда Авто-Еды##autoeatcfg', u8 'Поле для команды Авто-Еды', imgui_cfg.auto_eat.command) then
                    cfg.auto_eat.command = imgui_cfg.auto_eat.command.v
                    saveConfig()
                end
            end
            imgui.Separator()
            if imgui.CheckboxWithHint(u8 "Авто-Хил\nФункция выполняет указанную команду в случае если ваше здоровье ниже указанного числа.", u8 'Авто-Хил', imgui_cfg.auto_heal.active) then
                cfg.auto_heal.active = imgui_cfg.auto_heal.active.v
                saveConfig()
            end
            if cfg.auto_heal.active then
                if imgui.InputTextWithHintEx(u8 'Введите команду которую скрипт будет выполнять в случае если ваше здоровье ниже указанного числа.\nПримеры:\n/smoke - Сигареты\n/beer - Пиво\n/usedrugs 3 - Наркотики\n(( Команды обязательно писать с / ))', u8 'Команда Авто-Хила##autoeatcfg', u8 'Поле для команды Авто-Хила', imgui_cfg.auto_heal.command) then
                    cfg.auto_heal.command = imgui_cfg.auto_heal.command.v
                    saveConfig()
                end
                imgui.TextDisabled(u8 'Убедитесь что в вашем инвентаре достаточно Сигарет/Пива/Наркотиков или что вы там используете.')
                imgui.PushItemWidth(150)
                if imgui.InputIntEx(u8 'Минимальное Здоровье', imgui_cfg.auto_heal.hp) then
                    if imgui_cfg.auto_heal.hp.v < 0 then
                        imgui_cfg.auto_heal.hp.v = 0
                    end
                    cfg.auto_heal.hp = imgui_cfg.auto_heal.hp.v
                    saveConfig()
                end
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.PushTextWrapPos(600)
                    imgui.TextUnformatted(u8 'Здесь указывается значение здоровья при котором функция начинает фулдить.\nСтандартное значение - 80 (мин. 0)\nЕсли указано 80, скрипт начнёт флудить командой если здоровье будет ниже чем 80.')
                    imgui.PopTextWrapPos()
                    imgui.EndTooltip()
                end
                imgui.PopItemWidth()
                if imgui_cfg.auto_heal.hp.v < 50 or imgui_cfg.auto_heal.hp.v > 100 then
                    imgui.TextDisabled(u8(
                        'Вы указали странное значение. Ваши настройки подразумевают что флуд начнётся если у вас меньше чем ' ..
                        imgui_cfg.auto_heal.hp.v .. ' HP.'))
                end
            end
            imgui.Separator()
            if imgui.CheckboxWithHint(u8 "Очищать игроков и транспорт. Повышает FPS, минимизирует шанс краша.\nИспользовать на свой страх и риск, после выхода с палатки, рекомендую перезайти в игру.\nДанный очиститель не имеет багов, которые вызывают краш игры.", u8 'Очиститель', imgui_cfg.cleaner) then
                cfg.cleaner = imgui_cfg.cleaner.v
                saveConfig()
            end
            imgui.Separator()
            if imgui.CheckboxWithHint(u8 "Уведомления в Telegram\nПри обнаружении события - отправляет уведомление в Telegram\nПримеры Событий:\nВы взяли лавку\nОтключение от сервера\nНанесение вам урона\nПотеря лавки", u8 'Уведомления в Telegram', imgui_cfg.telegram.active) then
                cfg.telegram.active = imgui_cfg.telegram.active.v
                saveConfig()
            end
            if cfg.telegram.active then
                imgui.SameLine()
                if imgui.Button(u8 'Отправить тестовое сообщение!', imgui.ImVec2(0, 0)) then
                    sendTelegram('Тестовое сообщение!')
                end
                if imgui.CheckboxWithHint(u8 "Включить/Отключить отправку уведомления при КАЖДОЙ покупке/продаже.", u8 'Постоянные уведомления', imgui_cfg.telegram.sendsell) then
                    cfg.telegram.sendsell = imgui_cfg.telegram.sendsell.v
                    saveConfig()
                end
                if imgui.InputTextWithHintEx(u8 'Запустите Telegram, перейдите к поисковой строке над списком чатов и введите в неё запрос getmyid_bot.\nПосле начала работы с ботом он отобразит ваш пользовательский ID.\nВставьте полученный ID в это поле.', 'User_Id', u8 'Поле для User_Id', imgui_cfg.telegram.user_id) then
                    cfg.telegram.user_id = imgui_cfg.telegram.user_id.v
                    saveConfig()
                end
                if imgui.InputTextWithHintEx(u8 'Найдите в телеграме бота с именем «@botfarther», он поможет вам в создании и управлении вашим ботом.\nЧтобы создать нового бота, отправьте «/newbot»\nСледуйте инструкциям, которые он дал, и создайте новое имя для своего бота.\nПоздравляем! Вы только что создали своего бота Telegram. Вы увидите новый токен API, сгенерированный для него.\nВставьте полученный токен в это поле!', 'Token', u8 'Поле для Token', imgui_cfg.telegram.token) then
                    cfg.telegram.token = imgui_cfg.telegram.token.v
                    saveConfig()
                end
            end
            imgui.Separator()
            if imgui.CheckboxWithHint(u8 "Авто-Взятие Лавки\nКогда вы берёте лавку, автоматически платит за аренду, прописывает название Лавки.\nИ рандомно выбирает её цвет.\nТак-же автоматически пропишет: /anim 1", u8 'Авто-Взятие Лавки', imgui_cfg.lavka.active) then
                cfg.lavka.active = imgui_cfg.lavka.active.v
                saveConfig()
            end
            if cfg.lavka.active then
                if imgui_cfg.lavka.name.v then
                    if string.len(u8:decode(imgui_cfg.lavka.name.v)) < 3 then
                        imgui_cfg.lavka.name.v = u8 'Введите название'
                    end
                end
                if imgui.InputTextWithHintEx(nil, u8 'Введите название вашей Лавки.', u8 'Поле для Названия Лавки', imgui_cfg.lavka.name) then
                    if string.len(u8:decode(imgui_cfg.lavka.name.v)) > 20 then
                        imgui_cfg.lavka.name.v = u8 'Длинное название'
                    else
                        cfg.lavka.name = u8:decode(imgui_cfg.lavka.name.v)
                        saveConfig()
                    end
                    cfg.lavka.name = u8:decode(imgui_cfg.lavka.name.v)
                    saveConfig()
                end
                imgui.TextDisabled(u8 'Помните, название лавки не может быть короче 3 и длиннее 20 символов! Текущая длина: ' ..
                    string.len(u8:decode(imgui_cfg.lavka.name.v)) .. u8(' символов.'))
            end
            drawLavakaHelperUi()
            imgui.Separator()
            if imgui.CollapsingHeader(u8 'Очистка Логов') then
                if imgui.ButtonActivatedWithHint(u8 'Внимание! Эта кнопка полностью удалит все логи записанные со всех аккаунтов!\nПеред тем как её нажимать, убедитесь что вы знаете что делаете!', false, u8 'Стереть все Логи', imgui.ImVec2(150, 40)) then
                    im_choto = {}
                    im_stats = {}
                    statistic = {}
                    statistic_imCombo.v = 0
                    ecfg.save(files.stats, statistic)
                end
            end
            imgui.Separator()
        elseif tabs == 2 then
        elseif tabs == 3 then
            imgui.PushItemWidth(150)
            imgui.TextDisabled(arizona_name .. " | " .. my_nickname)
            imgui.Combo(u8 'Выберите дату.', statistic_imCombo, im_stats[server_nickname], 10)
            imgui.SameLine()
            if imgui.Button(u8 'Выгрузить Лог', imgui.ImVec2(150, 0)) then
                local load_text = {}
                if #im_stats[server_nickname] > 0 then
                    for i, v in ipairs(im_choto[server_nickname][im_stats[server_nickname][statistic_imCombo.v + 1]]) do
                        if string.len(u8:decode(search_buffer.v)) > 0 then
                            if ru.lower(v):find(ru.lower(u8:decode(search_buffer.v)), 1, true) then
                                table.insert(load_text, v)
                            end
                        else
                            table.insert(load_text, v)
                        end
                    end
                    if not doesDirectoryExist(getGameDirectory() .. '\\moonloader\\[JF]fps fix - Логи') then
                        createDirectory(getGameDirectory() .. '\\moonloader\\[JF]fps fix - Логи')
                    end
                    if not doesDirectoryExist(getGameDirectory() .. '\\moonloader\\[JF]fps fix - Логи\\[' .. arizona_name .. '] ' .. my_nickname) then
                        createDirectory(getGameDirectory() ..
                            '\\moonloader\\[JF]fps fix - Логи\\[' .. arizona_name .. '] ' .. my_nickname)
                    end
                    local file, err
                    file, err = io.open(
                        getGameDirectory() ..
                        '\\moonloader\\[JF]fps fix - Логи\\[' ..
                        arizona_name .. '] ' .. my_nickname .. '\\' ..
                        im_stats[server_nickname][statistic_imCombo.v + 1] .. '.txt', "w")
                    if file then
                        file:write(table.concat(load_text, "\n"))
                        file:close()
                        addChat('Лог выгружен.')
                    else
                        addChat('Ошибка выгрузки лога.')
                        addChat(err)
                    end
                else
                    addChat('Ошибка. Записей в логе не обнаружено!')
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.PushTextWrapPos(600)
                imgui.TextUnformatted(u8 'Выгружает логи которые у вас на экране файл.\nФайл находится по пути: "moonloader/[JF]fps fix - Логи/"')
                imgui.PopTextWrapPos()
                imgui.EndTooltip()
            end
            imgui.SameLine()
            if imgui.Button(u8 "Пересчитать Далары", imgui.ImVec2(150, 0)) then
                local money = 0
                if #im_stats[server_nickname] > 0 then
                    for i, v in ipairs(im_choto[server_nickname][im_stats[server_nickname][statistic_imCombo.v + 1]]) do
                        if v:find('купили') then
                            money = money - tonumber(v:match('(%d+)%$'))
                        elseif v:find('продали') then
                            money = money + tonumber(v:match('(%d+)%$'))
                        end
                    end
                    addChat('Выгруженный лог за: ' .. im_stats[server_nickname][statistic_imCombo.v + 1])
                    addChat('Общая прибыль составляет: ' .. money .. '$')
                    if cfg.telegram.active then
                        sendTelegram('Выгруженный лог за: ' ..
                            im_stats[server_nickname][statistic_imCombo.v + 1] .. '\nОбщая прибыль составляет: ' ..
                            money .. '$')
                    end
                else
                    addChat('Ошибка. Записей в логе не обнаружено!')
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.PushTextWrapPos(600)
                imgui.TextUnformatted(u8 'Считает вашу прибыль либо убытки за выбранную дату.\n(( Из того что отображается на экране ))\nЕсли включены Уведомления в Telegram, продублирует туда.')
                imgui.PopTextWrapPos()
                imgui.EndTooltip()
            end
            imgui.SameLine()
            imgui.InputTextWithHint('', u8 'Поиск', search_buffer)
            imgui.Separator()

            imgui.BeginChild('##main_stats_child', imgui.ImVec2(0, 0), false)
            if #im_stats[server_nickname] > 0 then
                for i, v in ipairs(im_choto[server_nickname][im_stats[server_nickname][statistic_imCombo.v + 1]]) do
                    if string.len(u8:decode(search_buffer.v)) > 0 then
                        if ru.lower(v):find(ru.lower(u8:decode(search_buffer.v)), 1, true) then
                            imgui.Text(u8(v))
                        end
                    else
                        imgui.Text(u8(v))
                    end
                end
            end
            imgui.EndChild()
        end



        imgui.EndChild()


        imgui.End()
    end
end

function imgui.ButtonActivated(activated, ...)
    if activated then
        imgui.PushStyleColor(imgui.Col.Button, imgui.GetStyle().Colors[imgui.Col.CheckMark])
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.GetStyle().Colors[imgui.Col.CheckMark])
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.GetStyle().Colors[imgui.Col.CheckMark])

        imgui.Button(...)

        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
    else
        return imgui.Button(...)
    end
end

function imgui.ButtonActivatedWithHint(hint, activated, ...)
    if activated then
        imgui.PushStyleColor(imgui.Col.Button, imgui.GetStyle().Colors[imgui.Col.CheckMark])
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.GetStyle().Colors[imgui.Col.CheckMark])
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.GetStyle().Colors[imgui.Col.CheckMark])

        if imgui.Button(...) then
            imgui.PopStyleColor()
            imgui.PopStyleColor()
            imgui.PopStyleColor()
            return true
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(600)
            imgui.TextUnformatted(hint)
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end

        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
    else
        if imgui.Button(...) then return true end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(600)
            imgui.TextUnformatted(hint)
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end
    end
end

imgui.InputTextEx = {
    _edited_item = {}
}
setmetatable(imgui.InputTextEx, {
    __call = function(self, str_id, ...)
        local result = imgui.InputText(str_id, ...)

        if result then
            imgui.InputTextEx._edited_item[str_id] = true
        end

        if not imgui.IsItemActive() and imgui.InputTextEx._edited_item[str_id] then
            imgui.InputTextEx._edited_item[str_id] = nil

            return true
        end
    end
})


function imgui.InputTextWithHintEx(help, label, hint, buf, flags, callback, user_data)
    local l_pos = { imgui.GetCursorPos(), 0 }
    local handle = imgui.InputTextEx(label, buf, flags, callback, user_data)

    if help and imgui.IsItemHovered() and buf.v:len() < 1 then
        imgui.SetTooltip(help)
    end

    l_pos[2] = imgui.GetCursorPos()
    local t = (type(hint) == 'string' and buf.v:len() < 1) and hint or '\0'
    local t_size, l_size = imgui.CalcTextSize(t).x, imgui.CalcTextSize('A').x
    imgui.SetCursorPos(imgui.ImVec2(l_pos[1].x + 8, l_pos[1].y + 2))
    imgui.TextDisabled((imgui.CalcItemWidth() and t_size > imgui.CalcItemWidth()) and
        t:sub(1, math.floor(imgui.CalcItemWidth() / l_size)) or t)
    imgui.SetCursorPos(l_pos[2])
    return handle
end

function imgui.CheckboxWithHint(hint, name, data)
    if imgui.Checkbox(name, data) then return true end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(600)
        imgui.TextUnformatted(hint)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

function imgui.CenterTextColoredRGB(text)
    local width = imgui.GetWindowWidth()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4

    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end

    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImColor(r, g, b, a):GetVec4()
    end

    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local textsize = w:gsub('{.-}', '')
            local text_width = imgui.CalcTextSize(u8(textsize))
            imgui.SetCursorPosX(width / 2 - text_width.x / 2)
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else
                imgui.Text(u8(w))
            end
        end
    end
    render_text(text)
end

function imgui.Link(label, description)
    local size = imgui.CalcTextSize(label)
    local p = imgui.GetCursorScreenPos()
    local p2 = imgui.GetCursorPos()
    local result = imgui.InvisibleButton(label, size)

    imgui.SetCursorPos(p2)

    if imgui.IsItemHovered() then
        if description then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(600)
            imgui.TextUnformatted(description)
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end

        imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.CheckMark], label)
        imgui.GetWindowDrawList():AddLine(imgui.ImVec2(p.x, p.y + size.y), imgui.ImVec2(p.x + size.x, p.y + size.y),
            imgui.GetColorU32(imgui.GetStyle().Colors[imgui.Col.CheckMark]))
    else
        imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.CheckMark], label)
    end

    return result
end

function imgui.InputTextWithHint(label, hint, buf, flags, callback, user_data)
    local l_pos = { imgui.GetCursorPos(), 0 }
    local handle = imgui.InputText(label, buf, flags, callback, user_data)
    l_pos[2] = imgui.GetCursorPos()
    local t = (type(hint) == 'string' and buf.v:len() < 1) and hint or '\0'
    local t_size, l_size = imgui.CalcTextSize(t).x, imgui.CalcTextSize('A').x
    imgui.SetCursorPos(imgui.ImVec2(l_pos[1].x + 8, l_pos[1].y + 2))
    imgui.TextDisabled((imgui.CalcItemWidth() and t_size > imgui.CalcItemWidth()) and
        t:sub(1, math.floor(imgui.CalcItemWidth() / l_size)) or t)
    imgui.SetCursorPos(l_pos[2])
    return handle
end

imgui.InputIntEx = {
    _edited_item = {}
}
setmetatable(imgui.InputIntEx, {
    __call = function(self, str_id, ...)
        local result = imgui.InputInt(str_id, ...)

        if result then
            imgui.InputIntEx._edited_item[str_id] = true
        end

        if not imgui.IsItemActive() and imgui.InputIntEx._edited_item[str_id] then
            imgui.InputIntEx._edited_item[str_id] = nil

            return true
        end
    end
})
function imgui.VerticalSeparator()
    local p = imgui.GetCursorScreenPos()
    imgui.GetWindowDrawList():AddLine(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x, p.y + imgui.GetContentRegionMax().y),
        imgui.GetColorU32(imgui.GetStyle().Colors[imgui.Col.Separator]))
end

---------------End
---------------Какаето хуйня
ru = {
    lu_rus = {},
    ul_rus = {},

    lower = function(s)
        s = string.lower(s)
        local res = {}

        for i = 1, #s do
            local ch = string.sub(s, i, i)
            res[i] = ru.ul_rus[ch] or ch
        end

        return table.concat(res)
    end,

    upper = function(s)
        s = string.upper(s)
        local res = {}
        for i = 1, #s do
            local ch = string.sub(s, i, i)
            res[i] = lu_rus[ch] or ch
        end

        return table.concat(res)
    end
}

do
    local all = {}

    for i = 192, 223 do
        local A, a = string.char(i), string.char(i + 32)
        ru.ul_rus[A] = a
        ru.lu_rus[a] = A
        table.insert(all, A)
        table.insert(all, a)
    end

    local A, a = string.char(168), string.char(184)
    ru.ul_rus[A] = a
    ru.lu_rus[a] = A
    table.insert(all, A)
    table.insert(all, a)

    ru.a = table.concat(all)
end
function emul_rpc(hook, parameters)
    local bs_io = require 'samp.events.bitstream_io'
    local handler = require 'samp.events.handlers'
    local extra_types = require 'samp.events.extra_types'
    local hooks = {

        --[[ Outgoing rpcs
        ['onSendEnterVehicle'] = { 'int16', 'bool8', 26 },
        ['onSendClickPlayer'] = { 'int16', 'int8', 23 },
        ['onSendClientJoin'] = { 'int32', 'int8', 'string8', 'int32', 'string8', 'string8', 'int32', 25 },
        ['onSendEnterEditObject'] = { 'int32', 'int16', 'int32', 'vector3d', 27 },
        ['onSendCommand'] = { 'string32', 50 },
        ['onSendSpawn'] = { 52 },
        ['onSendDeathNotification'] = { 'int8', 'int16', 53 },
        ['onSendDialogResponse'] = { 'int16', 'int8', 'int16', 'string8', 62 },
        ['onSendClickTextDraw'] = { 'int16', 83 },
        ['onSendVehicleTuningNotification'] = { 'int32', 'int32', 'int32', 'int32', 96 },
        ['onSendChat'] = { 'string8', 101 },
        ['onSendClientCheckResponse'] = { 'int8', 'int32', 'int8', 103 },
        ['onSendVehicleDamaged'] = { 'int16', 'int32', 'int32', 'int8', 'int8', 106 },
        ['onSendEditAttachedObject'] = { 'int32', 'int32', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 116 },
        ['onSendEditObject'] = { 'bool', 'int16', 'int32', 'vector3d', 'vector3d', 117 },
        ['onSendInteriorChangeNotification'] = { 'int8', 118 },
        ['onSendMapMarker'] = { 'vector3d', 119 },
        ['onSendRequestClass'] = { 'int32', 128 },
        ['onSendRequestSpawn'] = { 129 },
        ['onSendPickedUpPickup'] = { 'int32', 131 },
        ['onSendMenuSelect'] = { 'int8', 132 },
        ['onSendVehicleDestroyed'] = { 'int16', 136 },
        ['onSendQuitMenu'] = { 140 },
        ['onSendExitVehicle'] = { 'int16', 154 },
        ['onSendUpdateScoresAndPings'] = { 155 },
        ['onSendGiveDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },
        ['onSendTakeDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },]]

        -- Incoming rpcs
        ['onInitGame'] = { 139 },
        ['onPlayerJoin'] = { 'int16', 'int32', 'bool8', 'string8', 137 },
        ['onPlayerQuit'] = { 'int16', 'int8', 138 },
        ['onRequestClassResponse'] = { 'bool8', 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 128 },
        ['onRequestSpawnResponse'] = { 'bool8', 129 },
        ['onSetPlayerName'] = { 'int16', 'string8', 'bool8', 11 },
        ['onSetPlayerPos'] = { 'vector3d', 12 },
        ['onSetPlayerPosFindZ'] = { 'vector3d', 13 },
        ['onSetPlayerHealth'] = { 'float', 14 },
        ['onTogglePlayerControllable'] = { 'bool8', 15 },
        ['onPlaySound'] = { 'int32', 'vector3d', 16 },
        ['onSetWorldBounds'] = { 'float', 'float', 'float', 'float', 17 },
        ['onGivePlayerMoney'] = { 'int32', 18 },
        ['onSetPlayerFacingAngle'] = { 'float', 19 },
        --['onResetPlayerMoney'] = { 20 },
        --['onResetPlayerWeapons'] = { 21 },
        ['onGivePlayerWeapon'] = { 'int32', 'int32', 22 },
        --['onCancelEdit'] = { 28 },
        ['onSetPlayerTime'] = { 'int8', 'int8', 29 },
        ['onSetToggleClock'] = { 'bool8', 30 },
        ['onPlayerStreamIn'] = { 'int16', 'int8', 'int32', 'vector3d', 'float', 'int32', 'int8', 32 },
        ['onSetShopName'] = { 'string256', 33 },
        ['onSetPlayerSkillLevel'] = { 'int16', 'int32', 'int16', 34 },
        ['onSetPlayerDrunk'] = { 'int32', 35 },
        ['onCreate3DText'] = { 'int16', 'int32', 'vector3d', 'float', 'bool8', 'int16', 'int16', 'encodedString4096', 36 },
        --['onDisableCheckpoint'] = { 37 },
        ['onSetRaceCheckpoint'] = { 'int8', 'vector3d', 'vector3d', 'float', 38 },
        --['onDisableRaceCheckpoint'] = { 39 },
        --['onGamemodeRestart'] = { 40 },
        ['onPlayAudioStream'] = { 'string8', 'vector3d', 'float', 'bool8', 41 },
        --['onStopAudioStream'] = { 42 },
        ['onRemoveBuilding'] = { 'int32', 'vector3d', 'float', 43 },
        ['onCreateObject'] = { 44 },
        ['onSetObjectPosition'] = { 'int16', 'vector3d', 45 },
        ['onSetObjectRotation'] = { 'int16', 'vector3d', 46 },
        ['onDestroyObject'] = { 'int16', 47 },
        ['onPlayerDeathNotification'] = { 'int16', 'int16', 'int8', 55 },
        ['onSetMapIcon'] = { 'int8', 'vector3d', 'int8', 'int32', 'int8', 56 },
        ['onRemoveVehicleComponent'] = { 'int16', 'int16', 57 },
        ['onRemove3DTextLabel'] = { 'int16', 58 },
        ['onPlayerChatBubble'] = { 'int16', 'int32', 'float', 'int32', 'string8', 59 },
        ['onUpdateGlobalTimer'] = { 'int32', 60 },
        ['onShowDialog'] = { 'int16', 'int8', 'string8', 'string8', 'string8', 'encodedString4096', 61 },
        ['onDestroyPickup'] = { 'int32', 63 },
        ['onLinkVehicleToInterior'] = { 'int16', 'int8', 65 },
        ['onSetPlayerArmour'] = { 'float', 66 },
        ['onSetPlayerArmedWeapon'] = { 'int32', 67 },
        ['onSetSpawnInfo'] = { 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 68 },
        ['onSetPlayerTeam'] = { 'int16', 'int8', 69 },
        ['onPutPlayerInVehicle'] = { 'int16', 'int8', 70 },
        --['onRemovePlayerFromVehicle'] = { 71 },
        ['onSetPlayerColor'] = { 'int16', 'int32', 72 },
        ['onDisplayGameText'] = { 'int32', 'int32', 'string32', 73 },
        --['onForceClassSelection'] = { 74 },
        ['onAttachObjectToPlayer'] = { 'int16', 'int16', 'vector3d', 'vector3d', 75 },
        ['onInitMenu'] = { 76 },
        ['onShowMenu'] = { 'int8', 77 },
        ['onHideMenu'] = { 'int8', 78 },
        ['onCreateExplosion'] = { 'vector3d', 'int32', 'float', 79 },
        ['onShowPlayerNameTag'] = { 'int16', 'bool8', 80 },
        ['onAttachCameraToObject'] = { 'int16', 81 },
        ['onInterpolateCamera'] = { 'bool', 'vector3d', 'vector3d', 'int32', 'int8', 82 },
        ['onGangZoneStopFlash'] = { 'int16', 85 },
        ['onApplyPlayerAnimation'] = { 'int16', 'string8', 'string8', 'bool', 'bool', 'bool', 'bool', 'int32', 86 },
        ['onClearPlayerAnimation'] = { 'int16', 87 },
        ['onSetPlayerSpecialAction'] = { 'int8', 88 },
        ['onSetPlayerFightingStyle'] = { 'int16', 'int8', 89 },
        ['onSetPlayerVelocity'] = { 'vector3d', 90 },
        ['onSetVehicleVelocity'] = { 'bool8', 'vector3d', 91 },
        ['onServerMessage'] = { 'int32', 'string32', 93 },
        ['onSetWorldTime'] = { 'int8', 94 },
        ['onCreatePickup'] = { 'int32', 'int32', 'int32', 'vector3d', 95 },
        ['onMoveObject'] = { 'int16', 'vector3d', 'vector3d', 'float', 'vector3d', 99 },
        ['onEnableStuntBonus'] = { 'bool', 104 },
        ['onTextDrawSetString'] = { 'int16', 'string16', 105 },
        ['onSetCheckpoint'] = { 'vector3d', 'float', 107 },
        ['onCreateGangZone'] = { 'int16', 'vector2d', 'vector2d', 'int32', 108 },
        ['onPlayCrimeReport'] = { 'int16', 'int32', 'int32', 'int32', 'int32', 'vector3d', 112 },
        ['onGangZoneDestroy'] = { 'int16', 120 },
        ['onGangZoneFlash'] = { 'int16', 'int32', 121 },
        ['onStopObject'] = { 'int16', 122 },
        ['onSetVehicleNumberPlate'] = { 'int16', 'string8', 123 },
        ['onTogglePlayerSpectating'] = { 'bool32', 124 },
        ['onSpectatePlayer'] = { 'int16', 'int8', 126 },
        ['onSpectateVehicle'] = { 'int16', 'int8', 127 },
        ['onShowTextDraw'] = { 134 },
        ['onSetPlayerWantedLevel'] = { 'int8', 133 },
        ['onTextDrawHide'] = { 'int16', 135 },
        ['onRemoveMapIcon'] = { 'int8', 144 },
        ['onSetWeaponAmmo'] = { 'int8', 'int16', 145 },
        ['onSetGravity'] = { 'float', 146 },
        ['onSetVehicleHealth'] = { 'int16', 'float', 147 },
        ['onAttachTrailerToVehicle'] = { 'int16', 'int16', 148 },
        ['onDetachTrailerFromVehicle'] = { 'int16', 149 },
        ['onSetWeather'] = { 'int8', 152 },
        ['onSetPlayerSkin'] = { 'int32', 'int32', 153 },
        ['onSetInterior'] = { 'int8', 156 },
        ['onSetCameraPosition'] = { 'vector3d', 157 },
        ['onSetCameraLookAt'] = { 'vector3d', 'int8', 158 },
        ['onSetVehiclePosition'] = { 'int16', 'vector3d', 159 },
        ['onSetVehicleAngle'] = { 'int16', 'float', 160 },
        ['onSetVehicleParams'] = { 'int16', 'int16', 'bool8', 161 },
        --['onSetCameraBehind'] = { 162 },
        ['onChatMessage'] = { 'int16', 'string8', 101 },
        ['onConnectionRejected'] = { 'int8', 130 },
        ['onPlayerStreamOut'] = { 'int16', 163 },
        ['onVehicleStreamIn'] = { 164 },
        ['onVehicleStreamOut'] = { 'int16', 165 },
        ['onPlayerDeath'] = { 'int16', 166 },
        ['onPlayerEnterVehicle'] = { 'int16', 'int16', 'bool8', 26 },
        ['onUpdateScoresAndPings'] = { 'PlayerScorePingMap', 155 },
        ['onSetObjectMaterial'] = { 84 },
        ['onSetObjectMaterialText'] = { 84 },
        ['onSetVehicleParamsEx'] = { 'int16', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 24 },
        ['onSetPlayerAttachedObject'] = { 'int16', 'int32', 'bool', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 113 }

    }
    local handler_hook = {
        ['onInitGame'] = true,
        ['onCreateObject'] = true,
        ['onInitMenu'] = true,
        ['onShowTextDraw'] = true,
        ['onVehicleStreamIn'] = true,
        ['onSetObjectMaterial'] = true,
        ['onSetObjectMaterialText'] = true
    }
    local extra = {
        ['PlayerScorePingMap'] = true,
        ['Int32Array3'] = true
    }
    local hook_table = hooks[hook]
    if hook_table then
        local bs = raknetNewBitStream()
        if not handler_hook[hook] then
            local max = #hook_table - 1
            if max > 0 then
                for i = 1, max do
                    local p = hook_table[i]
                    if extra[p] then
                        extra_types[p]['write'](bs, parameters[i])
                    else
                        bs_io[p]['write'](bs, parameters[i])
                    end
                end
            end
        else
            if hook == 'onInitGame' then
                handler.on_init_game_writer(bs, parameters)
            elseif hook == 'onCreateObject' then
                handler.on_create_object_writer(bs, parameters)
            elseif hook == 'onInitMenu' then
                handler.on_init_menu_writer(bs, parameters)
            elseif hook == 'onShowTextDraw' then
                handler.on_show_textdraw_writer(bs, parameters)
            elseif hook == 'onVehicleStreamIn' then
                handler.on_vehicle_stream_in_writer(bs, parameters)
            elseif hook == 'onSetObjectMaterial' then
                handler.on_set_object_material_writer(bs, parameters, 1)
            elseif hook == 'onSetObjectMaterialText' then
                handler.on_set_object_material_writer(bs, parameters, 2)
            end
        end
        raknetEmulRpcReceiveBitStream(hook_table[#hook_table], bs)
        raknetDeleteBitStream(bs)
    end
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    -- from SAMP.Lua
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = { 'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData },
        vehicle = { 'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData },
        passenger = { 'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData },
        aim = { 'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData },
        trailer = { 'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData },
        unoccupied = { 'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil },
        bullet = { 'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil },
        spectator = { 'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil }
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    -- copy player's sync data to the allocated memory
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end
    -- function to send packet
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    -- metatable to access sync data and 'send' function
    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({ send = func_send }, mt)
end

-------------End


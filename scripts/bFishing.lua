script_name("bFishing")
script_author("bakhusse")

script_version("1.0")
require "lib.moonloader"
local raknet = require("lib.raknet")
local acef = require("arizona-events")
local encoding = require("encoding")
local sampev = require 'lib.samp.events'
local vkeys = require 'vkeys'
local imgui = require 'mimgui'
local inicfg = require 'inicfg'
local new = imgui.new

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local config_path = "bFishing.json"
local default_config = {
    settings = {
        bot_enabled = false, auto_recast = false, rod_slot = 5,
        mode_recast = 0, mode_cef = 0, mode_keys = 0,
        recast_min = 800, recast_max = 1200,
        cef_min = 500, cef_max = 800,
        keys_min = 600, keys_max = 900
    }
}
local main_ini = inicfg.load(default_config, config_path) or default_config

local bot_enabled = new.bool(main_ini.settings.bot_enabled)
local auto_recast = new.bool(main_ini.settings.auto_recast)
local main_window_state = new.bool(false)
local mode_recast = new.int(main_ini.settings.mode_recast)
local mode_cef = new.int(main_ini.settings.mode_cef)
local mode_keys = new.int(main_ini.settings.mode_keys)
local delay_recast = { min = new.int(main_ini.settings.recast_min), max = new.int(main_ini.settings.recast_max) }
local delay_cef = { min = new.int(main_ini.settings.cef_min), max = new.int(main_ini.settings.cef_max) }
local delay_keys = { min = new.int(main_ini.settings.keys_min), max = new.int(main_ini.settings.keys_max) }
local rod_slot = new.int(main_ini.settings.rod_slot)

local function ApplyCustomStyle()
    local style = imgui.GetStyle()
    local colors = style.Colors

    local orange = imgui.ImVec4(0.99, 0.67, 0.30, 1.00)
    local orange_hover = imgui.ImVec4(0.99, 0.67, 0.30, 0.70)
    local orange_active = imgui.ImVec4(0.99, 0.67, 0.30, 0.50)

    style.WindowRounding = 12.0
    style.ChildRounding = 8.0
    style.FrameRounding = 6.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8.0
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.FramePadding = imgui.ImVec2(10, 8)
    style.ItemSpacing = imgui.ImVec2(10, 10)

    colors[imgui.Col.WindowBg]              = imgui.ImVec4(0.07, 0.07, 0.09, 0.98)
    colors[imgui.Col.Border]                = imgui.ImVec4(0.99, 0.67, 0.30, 0.15)
    colors[imgui.Col.FrameBg]               = imgui.ImVec4(0.11, 0.11, 0.14, 1.00)
    colors[imgui.Col.FrameBgHovered]        = imgui.ImVec4(0.15, 0.15, 0.19, 1.00)
    colors[imgui.Col.TitleBg]               = imgui.ImVec4(0.05, 0.05, 0.06, 1.00)
    colors[imgui.Col.TitleBgActive]         = imgui.ImVec4(0.08, 0.08, 0.10, 1.00)
    
    colors[imgui.Col.CheckMark]             = orange
    colors[imgui.Col.SliderGrab]            = orange
    colors[imgui.Col.SliderGrabActive]      = orange_active
    
    colors[imgui.Col.Button]                = imgui.ImVec4(0.14, 0.14, 0.18, 1.00)
    colors[imgui.Col.ButtonHovered]         = orange_hover
    colors[imgui.Col.ButtonActive]          = orange_active
    
    colors[imgui.Col.Header]                = imgui.ImVec4(0.99, 0.67, 0.30, 0.40)
    colors[imgui.Col.HeaderHovered]         = imgui.ImVec4(0.99, 0.67, 0.30, 0.60)
    colors[imgui.Col.HeaderActive]          = orange
    
    colors[imgui.Col.Separator]             = imgui.ImVec4(0.99, 0.67, 0.30, 0.30)
    colors[imgui.Col.TextSelectedBg]        = imgui.ImVec4(0.99, 0.67, 0.30, 0.20)
end

local function saveConfig()
    main_ini.settings = {
        bot_enabled = bot_enabled[0], auto_recast = auto_recast[0], rod_slot = rod_slot[0],
        mode_recast = mode_recast[0], mode_cef = mode_cef[0], mode_keys = mode_keys[0],
        recast_min = delay_recast.min[0], recast_max = delay_recast.max[0],
        cef_min = delay_cef.min[0], cef_max = delay_cef.max[0],
        keys_min = delay_keys.min[0], keys_max = delay_keys.max[0]
    }
    inicfg.save(main_ini, config_path)
end

local function drawCompatibleCombo(label, current_item)
    local items = {u8"Точная задержка", u8"Примерная задержка"}
    local preview = items[current_item[0] + 1]
    
    if imgui.BeginCombo(label, preview) then
        for i, name in ipairs(items) do
            local is_selected = (current_item[0] == i - 1)
            if imgui.Selectable(name, is_selected) then
                current_item[0] = i - 1
                saveConfig()
            end
        end
        imgui.EndCombo()
    end
end

local function drawCustomInput(label, val, step)
    imgui.BeginGroup()
    imgui.PushItemWidth(100)
    if imgui.InputInt("##" .. label, val, 0, 0) then saveConfig() end
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button("-##" .. label, imgui.ImVec2(32, 32)) then val[0] = val[0] - step saveConfig() end
    imgui.SameLine()
    if imgui.Button("+##" .. label, imgui.ImVec2(32, 32)) then val[0] = val[0] + step saveConfig() end
    imgui.SameLine()
    imgui.TextDisabled(u8(label))
    imgui.EndGroup()
end

imgui.OnFrame(function()
    return main_window_state[0]
end, function(player)
    ApplyCustomStyle()
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(450, 520), imgui.Cond.Always)
    
    if imgui.Begin(u8"bFishing by bakhusse", main_window_state, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
        
        local footer_height = 45
        local scrollable_height = imgui.GetContentRegionAvail().y - footer_height

        imgui.BeginChild("##scroll_area", imgui.ImVec2(0, scrollable_height), false)
        
            imgui.TextColored(imgui.ImVec4(0.99, 0.67, 0.30, 1.00), u8"Главное меню")
            imgui.Spacing()
            
            if imgui.Checkbox(u8("Проходить мини-игру"), bot_enabled) then saveConfig() end
            imgui.SameLine(220)
            if imgui.Checkbox(u8("Авто-заброс"), auto_recast) then saveConfig() end
            
            imgui.Spacing()

            local function drawSettingBlock(title, mode_var, data_struct)
                imgui.Separator()
                imgui.Spacing()
                -- Заголовки блоков теперь тоже оранжевые
                imgui.TextColored(imgui.ImVec4(0.99, 0.67, 0.30, 1.00), u8(title))
                
                imgui.PushItemWidth(260)
                drawCompatibleCombo("##mode_" .. title, mode_var)
                imgui.PopItemWidth()

                imgui.Spacing()
                if mode_var[0] == 0 then
                    drawCustomInput("Задержка (мс)", data_struct.min, 50)
                else
                    drawCustomInput("Мин (мс)", data_struct.min, 50)
                    drawCustomInput("Макс (мс)", data_struct.max, 50)
                end
                imgui.Spacing()
            end

            drawSettingBlock("Задержка заброса", mode_recast, delay_recast)
            drawSettingBlock("Ожидание мини-игры", mode_cef, delay_cef)
            drawSettingBlock("Скорость нажатия", mode_keys, delay_keys)
        
        imgui.EndChild()
        imgui.Separator()
        
        local footer_text = u8"v1.0 © bakhusse"
        local text_size = imgui.CalcTextSize(footer_text)
        
        imgui.SetCursorPosY(imgui.GetWindowHeight() - 32) 
        imgui.SetCursorPosX((imgui.GetWindowWidth() - text_size.x) / 2)
        
        imgui.TextDisabled(footer_text)
        
        imgui.End()
    end
end)

local function getDelay(cfg)
    if cfg.mode[0] == 1 then return math.random(cfg.data.min[0], cfg.data.max[0]) end
    return cfg.data.min[0]
end

function acef.onArizonaDisplay(packet)
    if not bot_enabled[0] then return end 
    if not acef.decode(packet) then return end
    if packet.event == "cef.modals.showModal" and packet.json[1] == "keyReaction" then
        local k_delay = getDelay({mode = mode_keys, data = delay_keys})
        local c_wait = getDelay({mode = mode_cef, data = delay_cef})
        local js = string.format([[
            (function() {
                let keyElements = document.querySelectorAll('.key-reaction__keys-cap');
                let keys = [];
                keyElements.forEach(el => {
                    let char = el.textContent.trim().toUpperCase();
                    if (char) keys.push(char);
                });
                if (keys.length === 0) return;
                let index = 0;
                let interval = setInterval(() => {
                    if (index < keys.length) {
                        let char = keys[index];
                        let keyCode = char.charCodeAt(0);
                        let eventOptions = { key: char, keyCode: keyCode, which: keyCode, code: 'Key' + char, bubbles: true, active: true };
                        document.dispatchEvent(new KeyboardEvent('keydown', eventOptions));
                        document.dispatchEvent(new KeyboardEvent('keypress', eventOptions));
                        document.dispatchEvent(new KeyboardEvent('keyup', eventOptions));
                        keyElements[index].style.color = '#FCAA4D'; 
                        keyElements[index].style.textShadow = '0 0 12px #FCAA4D';
                        index++;
                    } else { clearInterval(interval); }
                }, %d);
            })();
        ]], k_delay)
        lua_thread.create(function() wait(c_wait) evalcef(js) end)
    end
end

function evalcef(code)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function sampev.onServerMessage(color, text)
    if auto_recast[0] and (text:find("Вы поймали") or text:find("Вы поймали рыбу")) then
        lua_thread.create(function()
            local r_delay = getDelay({mode = mode_recast, data = delay_recast})
            wait(r_delay)
            sampSendChat("/fishrod")
        end)
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if id == 25286 and auto_recast[0] then
        sampSendDialogResponse(id, 1, rod_slot[0], "")
        return false 
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("bfish", function() main_window_state[0] = not main_window_state[0] end)
    sampAddChatMessage("{FCAA4D}[bFishing by bakhusse] {FFFFFF}Скрипт запущен. Меню: /bfish")
    wait(-1)
end

imgui.OnCaptionSetCursor = function() return main_window_state[0] end
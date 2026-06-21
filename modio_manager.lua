local MANAGER_VERSION = '1.8.3.4'
local LAYOUT_FIX_BUILD = 'fixed-scroll-layout-2026-06-16-v4'

script_name('ModioManager')
script_author('ModioZodio')
script_version(MANAGER_VERSION)
script_properties('work-in-pause')

require 'lib.moonloader'

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local keys = require 'vkeys'
local ok_fa, fa = pcall(require, 'fAwesome6')

-- Helpers for mimgui labels and button sizing.
-- Without these aliases the script crashes on ui(...) and buttonSize(...).
local function ui(text)
    return tostring(text or '')
end

function buttonSize(label, min_width, height)
    min_width = min_width or 120
    height = height or 36

    local width = min_width
    local ok, size = pcall(imgui.CalcTextSize, label)
    if ok and size and size.x then
        width = math.max(min_width, size.x + 28)
    end

    return imgui.ImVec2(width, height)
end
local dl_status = require('moonloader').download_status
local ok_lfs, lfs = pcall(require, 'lfs')

local new = imgui.new
local window = new.bool(false)
local window_target = false
local window_alpha = 0.0
local window_anim_clock = os.clock()

local MANIFEST_URL = 'https://github.com/ilhamVode/moonloader-pack/raw/refs/heads/main/manifest.json'
local LOCAL_REFRESH_INTERVAL = 2.0
local REMOTE_CHECK_INTERVAL = 3600
local REMOTE_RETRY_AFTER_ERROR = 300
local PREFIX = '[ModioManager]'
local CHAT = 0x52C7EA
local OK = 0x77DD77
local WARN = 0xFFD166
local ERR = 0xFF6666

local workdir = getWorkingDirectory()
local config_dir = workdir .. '\\config\\modio_manager'
local tmp_dir = config_dir .. '\\tmp'
local seen_scripts_path = config_dir .. '\\seen_scripts.json'
local manifest_cache_path = config_dir .. '\\manifest_cache.json'
local imgui_ini_path = config_dir .. '\\imgui.ini'

local selected = 1
local checking = false
local busy = false
local busy_text = ''
local last_check_text = 'Проверка еще не запускалась.'
local last_error = ''
local pending_delete_id = nil
local pending_delete_forbidden = false
local filter_modio_only = false
local show_forbidden = false
local show_manager_changelog = false
local script_changelog_open = {}
local seen_scripts = {}
local runtime = {}
local list_item_anim = {}
local last_local_refresh_clock = 0
local next_remote_check_at = 0
local using_cached_manifest = false
local last_manifest_error = ''
local layout_window_extra_h = 0
local function emptyManifest()
    return {
        schema = 1,
        name = 'ModioZodio MoonLoader Pack',
        owner = 'ModioZodio',
        homepage = 'https://github.com/ilhamVode/moonloader-pack',
        updated_at = '-',
        notes = '',
        manager = {
            file = 'modio_manager.lua',
            version = MANAGER_VERSION,
            updated_at = '-',
            url = 'https://github.com/ilhamVode/moonloader-pack/raw/refs/heads/main/modio_manager.lua'
        },
        scripts = {},
        news = {}
    }
end

local manifest = emptyManifest()

function textWidth(text)
    local ok, size = pcall(imgui.CalcTextSize, tostring(text or ''))
    if ok and size then return size.x end
    return 0
end

function sameLineIfFits(width)
    local spacing = imgui.GetStyle().ItemSpacing.x
    if imgui.GetContentRegionAvail().x > width + spacing then
        imgui.SameLine()
    end
end

function colorU32(color)
    local alpha = window_alpha
    if not alpha or alpha < 0 then alpha = 1.0 end
    if alpha > 1 then alpha = 1.0 end
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color.x, color.y, color.z, color.w * alpha))
end

-- Fixed layout helpers: outer panels must not scroll; only inner body areas scroll.
local FALLBACK_WINDOW_FLAGS = {
    NoScrollbar = 8,
    NoScrollWithMouse = 16
}

function imguiWindowFlag(name)
    local wf = imgui.WindowFlags
    if wf and wf[name] ~= nil then return wf[name] end
    return FALLBACK_WINDOW_FLAGS[name] or 0
end

function noOuterScrollFlags(flags)
    flags = flags or 0
    return flags + imguiWindowFlag('NoScrollbar') + imguiWindowFlag('NoScrollWithMouse')
end

function cacheBustUrl(url)
    url = tostring(url or '')
    if url == '' then return url end
    local sep = url:find('?', 1, true) and '&' or '?'
    local token = tostring(os.time()) .. '_' .. tostring(math.floor(os.clock() * 1000000))
    return url .. sep .. 'modio_ts=' .. token
end

function refreshLocalStateIfNeeded(force)
    local now = os.clock()
    if not force and (now - last_local_refresh_clock) < LOCAL_REFRESH_INTERVAL then
        return
    end
    if busy or checking then return end

    refreshLocalState()
    last_local_refresh_clock = now
end

function main()
    while not isSampAvailable() do wait(0) end

    ensureDir(config_dir)
    ensureDir(tmp_dir)
    loadSeenScripts()
    loadManifestFromFile(manifest_cache_path, false)
    if type(manifest.scripts) == 'table' and #manifest.scripts > 0 then
        using_cached_manifest = true
        last_check_text = 'Используется локальный manifest. Проверяю GitHub...'
    end
    refreshLocalState()

    sampRegisterChatCommand('modio', function()
        toggleManagerWindow()
    end)
    sampRegisterChatCommand('mscripts', function()
        toggleManagerWindow()
    end)

    msg('Менеджер скриптов загружен. Окно: /modio или /mscripts', OK)
    checkRemoteManifest(true)

    while true do
        checkRemoteManifestIfNeeded()
        wait(0)
    end
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x0100 and wparam == keys.VK_ESCAPE and window[0] then
        if window_target then setManagerWindowOpen(false) end
        consumeWindowMessage(true, true)
    end
end

local function uiIcon(name, fallback)
    if ok_fa and type(fa) == 'function' then
        local ok, result = pcall(fa, name)
        if ok and type(result) == 'string' and result ~= '' then return result end
    end
    return fallback or ''
end

function toggleManagerWindow()
    setManagerWindowOpen(not (window[0] and window_target))
end

function setManagerWindowOpen(open)
    open = open == true
    if open then
        window[0] = true
        window_target = true
        refreshLocalStateIfNeeded(true)
    else
        window_target = false
    end
end

function updateManagerWindowAnimation()
    local now = os.clock()
    local delta = now - window_anim_clock
    if delta < 0 then delta = 0 end
    window_anim_clock = now

    local target = window_target and 1.0 or 0.0
    local duration = window_target and 0.16 or 0.20
    local step = duration > 0 and (delta / duration) or 1.0

    if target > window_alpha then
        window_alpha = math.min(target, window_alpha + step)
    elseif target < window_alpha then
        window_alpha = math.max(target, window_alpha - step)
    end

    if not window_target and window_alpha <= 0.01 then
        window_alpha = 0.0
        window[0] = false
    end

    return window_alpha
end

function markScriptSeen(item)
    local id = tostring(type(item) == 'table' and (item.id or item.file or item.name) or '')
    if id == '' or seen_scripts[id] then return end
    seen_scripts[id] = true
    saveSeenScripts()
end

function isScriptNew(item)
    local id = tostring(type(item) == 'table' and (item.id or item.file or item.name) or '')
    return id ~= '' and seen_scripts[id] ~= true
end

imgui.OnInitialize(function()
    ensureDir(config_dir)
    imgui.GetIO().IniFilename = imgui_ini_path
    applyStyle()
end)

imgui.OnFrame(
    function() return window[0] end,
    function()
        local alpha = updateManagerWindowAnimation()
        if alpha <= 0.01 and not window_target then return end

        local sx, sy = getScreenResolution()
        local max_w = math.max(1060, sx - 40)
        local max_h = math.max(680, sy - 40)
        local min_w = 1040
        local start_w = math.min(math.max(sx * 0.80, 1180), sx - 80)
        local start_h = math.min(math.max(sy * 0.78, 700), max_h)
        local layout_min_h = 650
        local layout_max_h = max_h
        if layout_window_extra_h > 0 then
            local spacing_y = imgui.GetStyle().ItemSpacing.y
            layout_min_h = math.min(max_h, math.max(650, layout_window_extra_h + 465 + 200 + spacing_y))
            layout_max_h = math.min(max_h, math.max(layout_min_h, layout_window_extra_h + 515 + 300 + spacing_y))
        end
        imgui.SetNextWindowSize(imgui.ImVec2(start_w, start_h), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSizeConstraints(imgui.ImVec2(min_w, layout_min_h), imgui.ImVec2(max_w, layout_max_h))

        local was_open = window[0]
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)

        local main_flags = noOuterScrollFlags(imgui.WindowFlags.NoCollapse)
        if imgui.Begin(ui 'Modio Manager | менеджер скриптов', window, main_flags) then
            refreshLocalStateIfNeeded(false)
            drawHeader()
            imgui.Separator()

            local avail_y = imgui.GetContentRegionAvail().y
            layout_window_extra_h = math.max(0, imgui.GetWindowSize().y - avail_y)
            local has_news = type(manifest.news) == 'table' and #manifest.news > 0
            local spacing_y = imgui.GetStyle().ItemSpacing.y
            local news_h = 0
            local middle_h = 0
            if has_news then
                local total_h = math.max(0, avail_y - spacing_y)
                local base_news_h = 200
                local max_news_h = 300
                if total_h <= base_news_h then
                    news_h = total_h
                else
                    news_h = base_news_h
                    local middle_space = total_h - news_h
                    middle_h = math.min(515, math.max(0, middle_space))
                    if middle_space >= 465 then
                        middle_h = math.max(465, middle_h)
                    end
                    if middle_h >= 515 then
                        news_h = math.min(max_news_h, math.max(base_news_h, total_h - middle_h))
                    end
                end
            else
                middle_h = math.min(515, math.max(0, avail_y))
                if avail_y >= 465 then
                    middle_h = math.max(465, middle_h)
                end
            end

            imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 10))
            imgui.BeginChild('script_list_frame', imgui.ImVec2(scriptListPanelWidth(), middle_h), true, noOuterScrollFlags(0))
            drawScriptList()
            imgui.EndChild()
            imgui.PopStyleVar()

            imgui.SameLine()

            imgui.BeginChild('script_details_frame', imgui.ImVec2(0, middle_h), true, noOuterScrollFlags(0))
            drawDetails()
            imgui.EndChild()

            if news_h > 0 then
                drawNewsPanel('bottom_fixed', 4, news_h)
            end
        end
        imgui.End()
        imgui.PopStyleVar()

        if was_open and not window[0] and window_target then
            window[0] = true
            setManagerWindowOpen(false)
        end
    end
)

function applyStyle()
    local style = imgui.GetStyle()
    style.Alpha = 0.985
    style.WindowRounding = 12
    style.ChildRounding = 10
    style.FrameRounding = 8
    style.PopupRounding = 10
    style.GrabRounding = 8
    style.ScrollbarRounding = 10
    style.WindowBorderSize = 1
    style.ChildBorderSize = 1
    style.FrameBorderSize = 0
    style.WindowPadding = imgui.ImVec2(17, 16)
    style.FramePadding = imgui.ImVec2(12, 8)
    style.ItemSpacing = imgui.ImVec2(10, 9)
    style.ItemInnerSpacing = imgui.ImVec2(8, 7)
    style.ScrollbarSize = 13

    local c = style.Colors
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.055, 0.066, 0.088, 0.96)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.088, 0.106, 0.142, 0.90)
    c[imgui.Col.PopupBg] = imgui.ImVec4(0.065, 0.078, 0.104, 0.98)
    c[imgui.Col.Border] = imgui.ImVec4(0.250, 0.320, 0.420, 0.58)
    c[imgui.Col.BorderShadow] = imgui.ImVec4(0.000, 0.000, 0.000, 0.00)
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.125, 0.158, 0.214, 0.94)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.165, 0.222, 0.306, 0.98)
    c[imgui.Col.FrameBgActive] = imgui.ImVec4(0.200, 0.278, 0.382, 1.00)
    c[imgui.Col.Button] = imgui.ImVec4(0.150, 0.292, 0.515, 0.94)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.215, 0.405, 0.705, 1.00)
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.115, 0.245, 0.440, 1.00)
    c[imgui.Col.Header] = imgui.ImVec4(0.145, 0.236, 0.368, 0.74)
    c[imgui.Col.HeaderHovered] = imgui.ImVec4(0.195, 0.318, 0.492, 0.88)
    c[imgui.Col.HeaderActive] = imgui.ImVec4(0.155, 0.286, 0.480, 0.96)
    c[imgui.Col.TitleBg] = imgui.ImVec4(0.050, 0.064, 0.092, 0.98)
    c[imgui.Col.TitleBgActive] = imgui.ImVec4(0.085, 0.135, 0.205, 0.99)
    c[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.050, 0.060, 0.080, 0.90)
    c[imgui.Col.Separator] = imgui.ImVec4(0.300, 0.380, 0.500, 0.45)
    c[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.400, 0.560, 0.760, 0.70)
    c[imgui.Col.SeparatorActive] = imgui.ImVec4(0.500, 0.680, 0.900, 0.95)
    c[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.045, 0.055, 0.075, 0.50)
    c[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.250, 0.330, 0.450, 0.75)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.330, 0.440, 0.590, 0.90)
    c[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.400, 0.530, 0.700, 1.00)
    c[imgui.Col.CheckMark] = imgui.ImVec4(0.500, 0.760, 1.000, 1.00)
    c[imgui.Col.ResizeGrip] = imgui.ImVec4(0.300, 0.450, 0.650, 0.28)
    c[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.420, 0.620, 0.880, 0.55)
    c[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.520, 0.720, 1.000, 0.80)
    c[imgui.Col.Text] = imgui.ImVec4(0.930, 0.948, 0.978, 1.00)
    c[imgui.Col.TextDisabled] = imgui.ImVec4(0.600, 0.660, 0.740, 1.00)
end

function drawHeader()
    imgui.TextColored(
        imgui.ImVec4(0.380, 0.680, 1.000, 1.00),
        ui(tostring(manifest.name or 'ModioZodio MoonLoader Pack') .. ' | Последнее обновление на сайте: ' .. tostring(manifest.updated_at or '-'))
    )
    imgui.TextColored(managerVersionColor(), ui(managerStatusText()))

    if manifest.notes and #manifest.notes > 0 then
        imgui.TextWrapped(ui(manifest.notes))
    end
    drawNewScriptsNotice()
    drawInstalledForbiddenWarning()

    if busy or checking then
        imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.35, 1.00), ui(busy_text ~= '' and busy_text or 'Идет операция...'))
    end

    if using_cached_manifest then
        imgui.TextColored(
            imgui.ImVec4(1.00, 0.78, 0.36, 1.00),
            ui 'GitHub временно недоступен: показана локальная копия manifest, повтор каждые 5 минут.'
        )
    end

    if last_error ~= '' then
        imgui.TextColored(imgui.ImVec4(1.00, 0.35, 0.35, 1.00), ui(last_error))
    end

    drawFilters()

    local check_size = buttonSize(ui 'Проверить обновления', 220)
    if managerButton(ui 'Проверить обновления', check_size) then
        checkRemoteManifest(false)
    end
    if managerIsOutdated() then
        drawManagerUpdateButton()
    end
    local manager_history_label = show_manager_changelog and ui 'Скрыть историю менеджера' or ui 'История менеджера'
    local manager_history_size = buttonSize(manager_history_label, 210)
    sameLineIfFits(manager_history_size.x)
    if managerButton(manager_history_label, manager_history_size) then
        show_manager_changelog = not show_manager_changelog
    end

    if hasInstalledForbiddenScripts() then
        local danger_size = buttonSize(ui 'Удалить запрещенные', 230)
        sameLineIfFits(danger_size.x)
        if dangerButton(ui 'Удалить запрещенные', danger_size) then
            pending_delete_forbidden = true
        end
    end

    if show_manager_changelog then
        drawChangelog(type(manifest.manager) == 'table' and manifest.manager.changelog or nil)
    end

    drawForbiddenDeleteConfirmation()
end

function drawNewScriptsNotice()
    local count = countNewScripts()
    if count <= 0 then return end

    imgui.TextColored(
        imgui.ImVec4(0.45, 0.72, 1.00, 1.00),
        ui('В каталоге появились новые скрипты: ' .. tostring(count))
    )
end

function drawInstalledForbiddenWarning()
    if not hasInstalledForbiddenScripts() then return end

    imgui.TextColored(
        imgui.ImVec4(1.00, 0.36, 0.36, 1.00),
        ui 'В вашей сборке есть скрипты из менеджера, за которые можно получить бан.'
    )
end

function countNewScripts()
    local count = 0
    for _, item in ipairs(manifest.scripts or {}) do
        if isScriptNew(item) then
            count = count + 1
        end
    end
    return count
end

function drawFilters()
    imgui.Spacing()
    filter_modio_only = drawSwitch('filter_modio_only', 'Только автор ModioZodio', filter_modio_only, imgui.ImVec4(0.28, 0.54, 0.86, 1.00))
    imgui.SameLine()
    show_forbidden = drawSwitch('show_forbidden', 'Показывать запрещенные', show_forbidden, imgui.ImVec4(0.75, 0.34, 0.32, 1.00))
    imgui.Spacing()
end

function drawSwitch(id, label, value, active_color)
    local size = imgui.ImVec2(48, 24)
    local pos = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(ui('##switch_' .. id), size)
    if clicked then value = not value end

    local hovered = imgui.IsItemHovered()
    local bg = value and active_color or imgui.ImVec4(0.24, 0.28, 0.34, 1.00)
    if hovered and not value then bg = imgui.ImVec4(0.30, 0.35, 0.42, 1.00) end
    if hovered and value then bg = imgui.ImVec4(math.min(active_color.x + 0.06, 1), math.min(active_color.y + 0.06, 1), math.min(active_color.z + 0.06, 1), 1.00) end

    local draw = imgui.GetWindowDrawList()
    local radius_track = size.y / 2
    local border = value and imgui.ImVec4(math.min(active_color.x + 0.18, 1), math.min(active_color.y + 0.18, 1), math.min(active_color.z + 0.18, 1), 0.72) or imgui.ImVec4(0.46, 0.52, 0.60, 0.42)
    local left = imgui.ImVec2(pos.x + radius_track, pos.y + radius_track)
    local right = imgui.ImVec2(pos.x + size.x - radius_track, pos.y + radius_track)
    draw:AddRectFilled(imgui.ImVec2(left.x, pos.y), imgui.ImVec2(right.x, pos.y + size.y), colorU32(bg), 0, 0)
    draw:AddCircleFilled(left, radius_track, colorU32(bg), 48)
    draw:AddCircleFilled(right, radius_track, colorU32(bg), 48)
    draw:AddRect(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(border), radius_track, 15, 1.0)
    draw:AddRectFilled(imgui.ImVec2(left.x, pos.y + 2), imgui.ImVec2(right.x, pos.y + size.y * 0.44), colorU32(imgui.ImVec4(1.00, 1.00, 1.00, value and 0.07 or 0.035)), 0, 0)

    local radius = 9.5
    local knob_x = value and (pos.x + size.x - radius - 3.5) or (pos.x + radius + 3.5)
    local knob = imgui.ImVec2(knob_x, pos.y + size.y / 2)
    draw:AddCircleFilled(imgui.ImVec2(knob.x, knob.y + 1.1), radius, colorU32(imgui.ImVec4(0.00, 0.00, 0.00, 0.22)), 36)
    draw:AddCircleFilled(knob, radius, colorU32(imgui.ImVec4(0.95, 0.97, 0.99, 1.00)), 40)
    draw:AddCircle(knob, radius, colorU32(imgui.ImVec4(1.00, 1.00, 1.00, 0.70)), 40, 1.0)

    imgui.SameLine()
    imgui.Text(ui(label))
    return value
end

function managerButton(label, size, variant, opts)
    opts = opts or {}
    variant = variant or 'primary'
    size = size or buttonSize(label, 120)
    size = imgui.ImVec2(size.x, math.max(size.y, 34))

    local pos = imgui.GetCursorScreenPos()
    local draw = imgui.GetWindowDrawList()
    local clicked = imgui.InvisibleButton(
        ui('##manager_button_' .. tostring(label) .. '_' .. tostring(math.floor(pos.x)) .. '_' .. tostring(math.floor(pos.y))),
        size
    )
    local hovered = imgui.IsItemHovered()
    local active = imgui.IsItemActive()
    local pulse = opts.pulse or 0

    local bg, border, text
    if variant == 'danger' then
        bg = active and imgui.ImVec4(0.42, 0.10, 0.11, 0.96)
            or hovered and imgui.ImVec4(0.66, 0.20, 0.21, 0.92)
            or imgui.ImVec4(0.50, 0.15, 0.16, 0.82)
        border = imgui.ImVec4(0.95, 0.42, 0.38, hovered and 0.62 or 0.38)
        text = imgui.ImVec4(1.00, 0.94, 0.94, 1.00)
    elseif variant == 'update' then
        bg = active and imgui.ImVec4(0.50, 0.12, 0.10, 0.98)
            or hovered and imgui.ImVec4(0.70, 0.23, 0.16, 0.94)
            or imgui.ImVec4(0.48 + pulse * 0.08, 0.15, 0.12, 0.88)
        border = imgui.ImVec4(1.00, 0.47 + pulse * 0.16, 0.24, 0.62)
        text = imgui.ImVec4(1.00, 0.96, 0.92, 1.00)
    else
        bg = active and imgui.ImVec4(0.30, 0.35, 0.90, 0.96)
            or hovered and imgui.ImVec4(0.40, 0.45, 1.00, 0.88)
            or imgui.ImVec4(0.35, 0.40, 0.95, 0.76)
        border = imgui.ImVec4(0.58, 0.66, 1.00, hovered and 0.52 or 0.28)
        text = imgui.ImVec4(0.96, 0.97, 1.00, 1.00)
    end

    if opts.glow then
        draw:AddRectFilled(
            imgui.ImVec2(pos.x - 4, pos.y - 4),
            imgui.ImVec2(pos.x + size.x + 4, pos.y + size.y + 4),
            colorU32(opts.glow),
            10,
            15
        )
    end

    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(bg), 8, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(border), 8, 15, 1.0)

    local text_size = imgui.CalcTextSize(label)
    local text_x = pos.x + (size.x - text_size.x) / 2
    local text_y = pos.y + (size.y - text_size.y) / 2 - 1
    draw:AddText(imgui.ImVec2(text_x, text_y), colorU32(text), label)

    return clicked
end

function dangerButton(label, size)
    return managerButton(label, size, 'danger')
end

function drawManagerUpdateButton()
    local label = ui 'Обновить менеджер'
    local size = buttonSize(label, 210)
    size = imgui.ImVec2(size.x, 34)
    sameLineIfFits(size.x)

    local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.4)
    local pos = imgui.GetCursorScreenPos()
    local draw = imgui.GetWindowDrawList()
    local glow = imgui.ImVec4(1.00, 0.22 + pulse * 0.12, 0.10, 0.20 + pulse * 0.18)
    local border = imgui.ImVec4(1.00, 0.46 + pulse * 0.18, 0.22, 0.65)

    local clicked = managerButton(label, size, 'update', {
        pulse = pulse,
        glow = glow
    })

    draw:AddRect(
        imgui.ImVec2(pos.x - 1, pos.y - 1),
        imgui.ImVec2(pos.x + size.x + 1, pos.y + size.y + 1),
        colorU32(border),
        7,
        15,
        1.5
    )

    if clicked then
        updateManager()
    end
end

function drawScriptList()
    -- Header is outside the scrolling child, so the word 'Скрипты' never leaves the top.
    imgui.TextDisabled(ui 'Скрипты')
    imgui.Separator()

    local list_h = imgui.GetContentRegionAvail().y
    if list_h < 80 then list_h = 80 end

    imgui.BeginChild('script_list_scroll_body', imgui.ImVec2(0, list_h), false)
    ensureSelectedVisible()

    local list = sortedVisibleScripts()
    local shown = 0
    for _, entry in ipairs(list) do
        local item = entry.item
        local st = runtime[item.id] or inspectLocal(item)
        drawScriptListItem(entry.index, item, st)
        shown = shown + 1
    end

    if shown == 0 then
        imgui.TextDisabled(ui 'Нет скриптов по выбранным фильтрам.')
    end

    imgui.EndChild()
end

function scriptListPanelWidth()
    local style = imgui.GetStyle()
    local max_row = textWidth(ui 'Скрипты')
    local badge_max = 0
    local version_max = 0
    for _, entry in ipairs(sortedVisibleScripts()) do
        local item = entry.item
        local st = runtime[item.id] or inspectLocal(item)
        local name_w = textWidth(item.name or item.id or 'script')
        if isForbiddenScript(item) then
            name_w = name_w + 16 + style.ItemSpacing.x
        end

        local badge_w = 0
        if isScriptNew(item) then
            badge_w = newBadgeSize(0.82).x
        else
            badge_w = statusPillSize(item, 0.82, st).x
        end

        badge_max = math.max(badge_max, badge_w)
        version_max = math.max(version_max, textWidth(statusLine(item, st)))
        max_row = math.max(max_row, name_w)
    end

    local compact_name = math.min(max_row, textWidth(ui 'AutoOpenRoulettes'))
    local row_w = math.max(compact_name + badge_max + style.ItemSpacing.x * 2, version_max)
    local avail = imgui.GetContentRegionAvail().x
    local desired = row_w + 16 + listScrollbarReserve()
    local details_share = math.max(0, avail - desired - style.ItemSpacing.x)
    desired = desired + details_share * 0.08
    local min_w = textWidth(ui 'Arenda Helper') + badge_max + style.ItemSpacing.x * 2 + 16 + listScrollbarReserve()
    local max_w = math.max(min_w, avail * 0.38)
    return math.min(math.max(desired, min_w), max_w)
end

function sortedVisibleScripts()
    local result = {}
    for i, item in ipairs(manifest.scripts or {}) do
        if isScriptVisible(item) then
            result[#result + 1] = { index = i, item = item }
        end
    end

    table.sort(result, function(a, b)
        local am = isModioScript(a.item)
        local bm = isModioScript(b.item)
        if am ~= bm then return am end

        local ap = scriptStatusPriority(a.item)
        local bp = scriptStatusPriority(b.item)
        if ap ~= bp then return ap < bp end
        return tostring(a.item.name or a.item.id or ''):lower() < tostring(b.item.name or b.item.id or ''):lower()
    end)

    return result
end

function drawScriptListItem(index, item, st)
    local id = tostring(item.id or index)
    local pos = imgui.GetCursorPos()
    local screen_pos = imgui.GetCursorScreenPos()
    local size = imgui.ImVec2(0, 58)
    local active = selected == index

    imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0, 0, 0, 0))
    if imgui.Selectable(ui('##script_' .. id), active, 0, size) then
        selected = index
        markScriptSeen(item)
        active = true
    end
    imgui.PopStyleColor(3)
    local hovered = imgui.IsItemHovered()
    local progress = updateListItemAnimation(id, active, hovered)
    drawScriptListItemBg(screen_pos, size, active, hovered, isForbiddenScript(item), progress)

    local after = imgui.GetCursorPos()
    local text_offset = progress * 4
    local is_new = isScriptNew(item)
    imgui.SetCursorPos(imgui.ImVec2(pos.x + 10 + text_offset, pos.y + 8))
    if isForbiddenScript(item) then
        drawWarningIcon(16)
        imgui.SameLine()
    end
    imgui.Text(ui(item.name or item.id or 'script'))
    if is_new then
        drawCompactNewBadge(item, text_offset)
    else
        drawCompactStatusBadge(item, text_offset)
    end

    imgui.SetCursorPos(imgui.ImVec2(pos.x + 10 + text_offset, pos.y + 31))
    imgui.TextColored(listVersionColor(st), ui(statusLine(item, st)))

    imgui.SetCursorPos(after)
    imgui.Spacing()
end

function updateListItemAnimation(id, active, hovered)
    local current = list_item_anim[id] or 0.0
    local target = active and 1.0 or hovered and 0.68 or 0.0
    local factor = target > current and 0.24 or 0.32
    current = current + (target - current) * factor
    if current < 0.004 then current = 0 end
    if current > 0.996 then current = 1 end
    list_item_anim[id] = current
    return current
end

function listScrollbarReserve()
    local style = imgui.GetStyle()
    return style.ScrollbarSize - 4
end

function drawCompactStatusBadge(item, offset_x)
    offset_x = offset_x or 0
    local st = runtime[item.id] or inspectLocal(item)
    local label = ui(scriptStatusText(item, st))
    if label == '' then return end

    local width = scriptStatusBadgeWidth(item, 16, st)
    local avail = imgui.GetContentRegionAvail().x
    if avail <= width + 12 then return end

    imgui.SameLine(imgui.GetWindowContentRegionMax().x - width - 8 - listScrollbarReserve() + offset_x)
    drawStatusPill(item, 'list_' .. tostring(item.id or item.file or item.name), 0.82, st)
end

function drawCompactNewBadge(item, offset_x)
    offset_x = offset_x or 0
    local width = newBadgeSize(0.82).x + 16
    local avail = imgui.GetContentRegionAvail().x
    if avail <= width + 12 then return end

    imgui.SameLine(imgui.GetWindowContentRegionMax().x - width - 8 - listScrollbarReserve() + offset_x)
    drawNewBadge('list_' .. tostring(item.id or item.file or item.name), 0.82)
end

function scriptStatusBadgeWidth(item, extra, st)
    return statusPillSize(item, 0.82, st).x + (extra or 0)
end

function statusPillMetrics(item, scale, st)
    scale = scale or 1.0
    local label = ui(scriptStatusText(item, st))
    local text_size = imgui.CalcTextSize(label)
    local text_x = 20 * scale
    local right_pad = 11 * scale
    local size = imgui.ImVec2(text_size.x + text_x + right_pad, math.max(20, 23 * scale))
    return label, text_size, size, 10 * scale, text_x, 3.8 * scale
end

function statusPillSize(item, scale, st)
    local _, _, size = statusPillMetrics(item, scale, st)
    return size
end

function drawStatusPill(item, id, scale, st)
    scale = scale or 1.0
    local label, text_size, size, dot_x, text_x, dot_radius = statusPillMetrics(item, scale, st)
    if label == '' then return end
    local width = size.x
    local height = size.y
    local pos = imgui.GetCursorScreenPos()
    local draw = imgui.GetWindowDrawList()
    local bg, border, dot = scriptStatusPalette(item, st)

    imgui.InvisibleButton(ui('##status_pill_' .. tostring(id or label)), size)
    local after = imgui.GetCursorPos()
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + width, pos.y + height), colorU32(bg), height / 2, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + width, pos.y + height), colorU32(border), height / 2, 15, 1.0)
    draw:AddCircleFilled(imgui.ImVec2(pos.x + dot_x, pos.y + height / 2), dot_radius, colorU32(dot), 18)

    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + text_x, pos.y + (height - text_size.y) / 2 - 1))
    imgui.TextColored(scriptStatusColor(item, st), label)
    imgui.SetCursorPos(imgui.ImVec2(after.x, after.y))
end

function drawStatusPillAt(item, st, pos, scale)
    scale = scale or 1.0
    local label, text_size, size, dot_x, text_x, dot_radius = statusPillMetrics(item, scale, st)
    if label == '' then return end

    local draw = imgui.GetWindowDrawList()
    local bg, border, dot = scriptStatusPalette(item, st)

    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(bg), size.y / 2, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(border), size.y / 2, 15, 1.0)
    draw:AddCircleFilled(imgui.ImVec2(pos.x + dot_x, pos.y + size.y / 2), dot_radius, colorU32(dot), 18)
    draw:AddText(
        imgui.ImVec2(pos.x + text_x, pos.y + (size.y - text_size.y) / 2 - 1),
        colorU32(scriptStatusColor(item, st)),
        label
    )
end

function drawWarningIcon(size)
    size = size or 16
    local pos = imgui.GetCursorScreenPos()
    local draw = imgui.GetWindowDrawList()
    local red = colorU32(imgui.ImVec4(0.92, 0.18, 0.16, 1.00))
    local red_border = colorU32(imgui.ImVec4(1.00, 0.50, 0.42, 0.95))
    local shadow = colorU32(imgui.ImVec4(0.42, 0.02, 0.02, 0.24))
    local white = colorU32(imgui.ImVec4(1.00, 1.00, 1.00, 0.98))

    local p1 = imgui.ImVec2(pos.x + size * 0.50, pos.y + 1.0)
    local p2 = imgui.ImVec2(pos.x + size - 1.0, pos.y + size - 1.5)
    local p3 = imgui.ImVec2(pos.x + 1.0, pos.y + size - 1.5)
    draw:AddTriangleFilled(imgui.ImVec2(p1.x, p1.y + 1.0), imgui.ImVec2(p2.x, p2.y + 1.0), imgui.ImVec2(p3.x, p3.y + 1.0), shadow)
    draw:AddTriangleFilled(p1, p2, p3, red)
    draw:AddTriangle(p1, p2, p3, red_border, 1.1)

    local bar_w = math.max(2.0, size * 0.13)
    local bar_h = size * 0.34
    local bar_x = pos.x + size * 0.5 - bar_w / 2
    local bar_y = pos.y + size * 0.36
    draw:AddRectFilled(imgui.ImVec2(bar_x, bar_y), imgui.ImVec2(bar_x + bar_w, bar_y + bar_h), white, bar_w / 2, 15)
    draw:AddCircleFilled(imgui.ImVec2(pos.x + size * 0.5, pos.y + size * 0.80), size * 0.075, white, 18)

    imgui.Dummy(imgui.ImVec2(size, size))
end

function drawScriptListItemBg(pos, size, active, hovered, forbidden, progress)
    progress = progress or 0
    if progress <= 0.01 then return end

    local draw = imgui.GetWindowDrawList()
    local width = imgui.GetContentRegionAvail().x - listScrollbarReserve()
    if width <= 0 then width = 300 end

    local accent = forbidden and imgui.ImVec4(1.00, 0.36, 0.36, 1.00) or imgui.ImVec4(0.38, 0.68, 1.00, 1.00)
    local glow = imgui.ImVec4(accent.x, accent.y, accent.z, (active and 0.20 or 0.13) * progress)
    local color = active and imgui.ImVec4(0.145, 0.265, 0.440, 0.56 + 0.24 * progress) or imgui.ImVec4(0.145, 0.195, 0.270, 0.26 + 0.28 * progress)
    local border = imgui.ImVec4(accent.x, accent.y, accent.z, (active and 0.34 or 0.22) * progress)
    local shift = progress * 4

    local min = imgui.ImVec2(pos.x + 2 + shift, pos.y + 3)
    local max = imgui.ImVec2(pos.x + width - 2 + shift, pos.y + size.y - 3)
    draw:AddRectFilled(
        imgui.ImVec2(min.x - 3, min.y - 3),
        imgui.ImVec2(max.x + 3, max.y + 3),
        colorU32(glow),
        12,
        15
    )
    draw:AddRectFilled(
        min,
        max,
        colorU32(color),
        10,
        15
    )
    draw:AddRect(min, max, colorU32(border), 10, 15, 1.0)

    if active then
        draw:AddRectFilled(
            imgui.ImVec2(min.x, pos.y + 9),
            imgui.ImVec2(min.x + 3, pos.y + size.y - 9),
            colorU32(imgui.ImVec4(accent.x, accent.y, accent.z, 0.95)),
            3,
            15
        )
        draw:AddRectFilled(
            imgui.ImVec2(min.x + 3, pos.y + 9),
            imgui.ImVec2(min.x + 6, pos.y + size.y - 9),
            colorU32(imgui.ImVec4(accent.x, accent.y, accent.z, 0.18)),
            2,
            15
        )
    end
end

function newBadgeMetrics(scale)
    scale = scale or 1.0
    local icon = uiIcon('SPARKLES', '')
    local label = ui((icon ~= '' and (icon .. '  ') or '') .. 'NEW')
    local text_size = imgui.CalcTextSize(label)
    local pad_x = 10 * scale
    local size = imgui.ImVec2(text_size.x + pad_x * 2, math.max(20, 23 * scale))
    return label, text_size, size, pad_x
end

function newBadgeSize(scale)
    local _, _, size = newBadgeMetrics(scale)
    return size
end

function drawNewBadge(id, scale)
    scale = scale or 1.0
    local label, text_size, size = newBadgeMetrics(scale)
    local pos = imgui.GetCursorScreenPos()
    local draw = imgui.GetWindowDrawList()
    local bg = imgui.ImVec4(0.16, 0.30, 0.54, 0.84)
    local border = imgui.ImVec4(0.46, 0.68, 1.00, 0.48)

    imgui.Dummy(size)
    local after = imgui.GetCursorPos()
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(bg), size.y / 2, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(border), size.y / 2, 15, 1.0)

    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + (size.x - text_size.x) / 2, pos.y + (size.y - text_size.y) / 2 - 1))
    imgui.TextColored(imgui.ImVec4(0.930, 0.980, 1.000, 1.00), label)
    imgui.SetCursorPos(imgui.ImVec2(after.x, after.y))
end

function hasInstalledForbiddenScripts()
    for _, item in ipairs(manifest.scripts or {}) do
        if isForbiddenScript(item) then
            local st = runtime[item.id] or inspectLocal(item)
            if st.installed then
                return true
            end
        end
    end
    return false
end

function isModioScript(item)
    return tostring(item.author or ''):find('ModioZodio', 1, true) ~= nil
end

function scriptId(item)
    return tostring(type(item) == 'table' and (item.id or item.file or item.name) or ''):lower()
end

function isScriptHidden(item)
    return type(item) == 'table' and item.hidden == true
end

function isForbiddenScript(item)
    return type(item) == 'table' and item.forbidden == true
end

function forbiddenWarning(item)
    if type(item) == 'table' and type(item.warning) == 'string' and item.warning ~= '' then
        return item.warning
    end
    return 'Есть возможность получить бан.'
end

function isScriptVisible(item)
    if isScriptHidden(item) then
        return false
    end
    if filter_modio_only and not isModioScript(item) then
        return false
    end
    if isForbiddenScript(item) and not show_forbidden then
        return false
    end
    return true
end

function ensureSelectedVisible()
    local list = manifest.scripts or {}
    if list[selected] and isScriptVisible(list[selected]) then return end

    for i, item in ipairs(list) do
        if isScriptVisible(item) then
            selected = i
            return
        end
    end

    selected = 1
end

function drawDetails()
    local item = (manifest.scripts or {})[selected]
    if not item or not isScriptVisible(item) then
        ensureSelectedVisible()
        item = (manifest.scripts or {})[selected]
    end
    if not item then
        imgui.TextDisabled(ui 'Скриптов в манифесте нет.')
        return
    end

    local st = runtime[item.id] or inspectLocal(item)
    drawDetailsHeader(item, st)
    imgui.Separator()

    local body_h = imgui.GetContentRegionAvail().y
    if body_h < 120 then body_h = 120 end

    imgui.BeginChild('script_details_scroll_body', imgui.ImVec2(0, body_h), false)
    drawDetailsBody(item, st)
    imgui.EndChild()
end

function drawDetailsHeader(item, st)
    -- Title/status row is outside the scrolling child, so it stays pinned at the top.
    local title = ui(item.name or item.id)
    local title_size = imgui.CalcTextSize(title)
    local pill_size = statusPillSize(item, 1.0, st)
    local row_pos = imgui.GetCursorScreenPos()
    local row_width = imgui.GetContentRegionAvail().x
    local row_height = math.max(title_size.y, pill_size.y)

    imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), title)
    drawStatusPillAt(
        item,
        st,
        imgui.ImVec2(row_pos.x + math.max(0, row_width - pill_size.x), row_pos.y + (row_height - pill_size.y) / 2),
        1.0
    )
    imgui.SetCursorScreenPos(imgui.ImVec2(row_pos.x, row_pos.y + row_height + imgui.GetStyle().ItemSpacing.y))
    imgui.Spacing()
end

function drawDetailsBody(item, st)
    if isForbiddenScript(item) then
        imgui.TextColored(imgui.ImVec4(1.00, 0.36, 0.36, 1.00), ui(forbiddenWarning(item)))
        imgui.Spacing()
    end
    infoRow('Автор', item.author or '-')
    infoRow('Локальная версия', st.installed and st.local_version or 'не установлен')
    infoRow('Версия на сайте', versionText(item.version))
    infoRow('Последнее обновление на сайте', item.updated_at or '-')
    drawScriptChangelog(item)

    imgui.Spacing()
    drawStatusBadge(st)
    imgui.Spacing()

    local canDelete = st.installed and not busy
    local script_actions_locked = managerIsOutdated()
    if script_actions_locked then
        imgui.TextColored(
            imgui.ImVec4(1.00, 0.66, 0.30, 1.00),
            ui 'Сначала обновите Modio Manager. Установка и обновление скриптов временно заблокированы.'
        )
        imgui.Spacing()
    end

    if not st.installed then
        local install_size = buttonSize(ui 'Установить', 190)
        if managerButton(ui 'Установить', install_size) then
            if script_actions_locked then
                msg('Сначала обновите Modio Manager, затем устанавливайте скрипты.', WARN)
            elseif busy then
                msg('Сейчас идет другая операция.', WARN)
            else
                installOrUpdate(item, 'install')
            end
        end
    elseif st.outdated then
        local update_size = buttonSize(ui 'Обновить', 190)
        if managerButton(ui 'Обновить', update_size) then
            if script_actions_locked then
                msg('Сначала обновите Modio Manager, затем обновляйте скрипты.', WARN)
            elseif busy then
                msg('Сейчас идет другая операция.', WARN)
            else
                installOrUpdate(item, 'update')
            end
        end
    end

    if canDelete then
        if st.outdated then
            sameLineIfFits(170)
        end
        local delete_size = buttonSize(ui 'Удалить', 170)
        if managerButton(ui 'Удалить', delete_size, 'danger') then
            pending_delete_id = item.id
        end
    elseif st.installed then
        local delete_size = buttonSize(ui 'Удалить', 170)
        if managerButton(ui 'Удалить', delete_size, 'danger') then
            msg('Удаление недоступно, пока идет другая операция.', WARN)
        end
    end

    if not st.installed and busy then
        imgui.TextDisabled(ui 'Установка будет доступна после завершения текущей операции.')
    elseif st.installed and st.outdated and busy then
        imgui.TextDisabled(ui 'Обновление будет доступно после завершения текущей операции.')
    end

    imgui.Spacing()
    drawDeleteConfirmation(item, st)
    imgui.Spacing()

    drawTextSection('Что делает', item.description)
    drawListSection('Команды', item.commands)
    drawTextSection('Как пользоваться', item.usage)
    drawListSection('Особенности', item.features)
    drawTextSection('Важно', item.notes)
end

function drawDeleteConfirmation(item, st)
    if pending_delete_id ~= item.id then return end

    imgui.Separator()
    imgui.TextColored(imgui.ImVec4(1.00, 0.55, 0.35, 1.00), ui('Подтвердите удаление: ' .. tostring(item.name or item.file)))
    imgui.TextWrapped(ui('Файл будет удален из папки moonloader: ' .. getScriptPath(item)))

    local confirm_size = buttonSize(ui 'Да, удалить', 170)
    if managerButton(ui 'Да, удалить', confirm_size, 'danger') then
        pending_delete_id = nil
        deleteScript(item)
    end
    local cancel_size = buttonSize(ui 'Отмена', 130)
    sameLineIfFits(cancel_size.x)
    if managerButton(ui 'Отмена', cancel_size) then
        pending_delete_id = nil
    end
end

function drawForbiddenDeleteConfirmation()
    if not pending_delete_forbidden then return end

    imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(1.00, 0.36, 0.36, 1.00), ui 'Подтвердите удаление всех запрещенных скриптов.')
    imgui.TextWrapped(ui 'Будут удалены только установленные файлы из внутреннего списка рискованных скриптов менеджера.')

    local confirm_size = buttonSize(ui 'Да, удалить запрещенные', 250)
    if dangerButton(ui 'Да, удалить запрещенные', confirm_size) then
        pending_delete_forbidden = false
        deleteForbiddenScripts()
    end
    local cancel_size = buttonSize(ui 'Отмена', 130)
    sameLineIfFits(cancel_size.x)
    if managerButton(ui 'Отмена', cancel_size) then
        pending_delete_forbidden = false
    end
end

function deleteForbiddenScripts()
    if busy then return end

    if not hasInstalledForbiddenScripts() then
        msg('У вас нет запрещенных скриптов.', WARN)
        return
    end

    local deleted = 0
    local failed = 0
    for _, item in ipairs(manifest.scripts or {}) do
        if isForbiddenScript(item) then
            local path = getScriptPath(item)
            if doesFileExist(path) then
                if item.file == thisScript().filename then
                    failed = failed + 1
                else
                    unloadLoadedScript(item, path)
                    local ok = os.remove(path)
                    if ok then
                        deleted = deleted + 1
                    else
                        failed = failed + 1
                    end
                end
            end
        end
    end

    refreshLocalState()
    ensureSelectedVisible()

    if failed > 0 then
        last_error = 'Не удалось удалить запрещенные скрипты: ' .. tostring(failed)
        msg(last_error, ERR)
    else
        msg('Удалено запрещенных скриптов: ' .. tostring(deleted), WARN)
    end
end

function drawSectionTitle(title)
    imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), ui(title))
end

function drawTextSection(title, text)
    if type(text) ~= 'string' or text == '' then return end
    drawSectionTitle(title)
    imgui.TextWrapped(ui(text))
end

function drawListSection(title, list)
    if type(list) ~= 'table' or #list == 0 then return end
    drawSectionTitle(title)
    for _, line in ipairs(list) do
        imgui.TextWrapped(ui('- ' .. tostring(line)))
    end
end

function drawNewsPanel(id, limit, height)
    local news = manifest.news
    if type(news) ~= 'table' or #news == 0 then return end

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.070, 0.088, 0.120, 0.78))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.260, 0.360, 0.520, 0.42))
    imgui.BeginChild(ui('news_panel_' .. tostring(id)), imgui.ImVec2(0, height or 160), true, noOuterScrollFlags(0))

    -- News title is fixed; only news items scroll.
    local icon = uiIcon('NEWSPAPER', '')
    local title = (icon ~= '' and (icon .. '  ') or '') .. 'Новости'
    imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), ui(title))
    imgui.Separator()

    local news_body_h = imgui.GetContentRegionAvail().y
    if news_body_h < 50 then news_body_h = 50 end

    imgui.BeginChild(ui('news_panel_scroll_body_' .. tostring(id)), imgui.ImVec2(0, news_body_h), false)
    local count = 0
    for _, item in ipairs(news) do
        if type(item) == 'table' then
            count = count + 1
            if limit and count > limit then break end
            drawNewsItem(item, count)
        end
    end

    if count == 0 then
        imgui.TextDisabled(ui 'Новостей пока нет.')
    end
    imgui.EndChild()

    imgui.EndChild()
    imgui.PopStyleColor(2)
end

function drawNewsItem(item, index)
    if index > 1 then
        imgui.Spacing()
        imgui.Separator()
    end

    local title = tostring(item.title or 'Новость')
    local date = tostring(item.date or '')
    imgui.TextColored(imgui.ImVec4(0.92, 0.95, 1.00, 1.00), ui(title))
    if date ~= '' then
        imgui.SameLine()
        imgui.TextDisabled(ui(date))
    end

    local lines = newsLines(item)
    for _, line in ipairs(lines) do
        if type(line) == 'table' then
            drawColoredSegments(line)
        else
            local raw = tostring(line or '')
            local segments = parseColorMarkup(raw)
            if raw:find('{#%x%x%x%x%x%x}') then
                drawColoredSegments(segments)
            else
                imgui.TextWrapped(ui(raw))
            end
        end
    end
end

function newsLines(item)
    if type(item.lines) == 'table' then return item.lines end
    if type(item.text) == 'table' then return item.text end
    if type(item.parts) == 'table' then return { item.parts } end
    if type(item.text) == 'string' then return { item.text } end
    return {}
end

function drawColoredSegments(segments)
    local default_color = imgui.ImVec4(0.88, 0.91, 0.96, 1.00)
    local drew = false
    for _, part in ipairs(segments) do
        local text = ''
        local color = default_color
        if type(part) == 'table' then
            text = tostring(part.text or '')
            color = parseHexColor(part.color, default_color)
        else
            text = tostring(part or '')
        end

        if text ~= '' then
            if drew then imgui.SameLine(nil, 0) end
            imgui.TextColored(color, ui(text))
            drew = true
        end
    end
end

function parseColorMarkup(text)
    local result = {}
    local default_color = '#E1E8F5'
    local current_color = default_color
    local pos = 1

    while pos <= #text do
        local start_pos, end_pos, color = text:find('{#(%x%x%x%x%x%x)}', pos)
        local reset_start, reset_end = text:find('{/}', pos, true)

        if reset_start and (not start_pos or reset_start < start_pos) then
            if reset_start > pos then
                result[#result + 1] = { text = text:sub(pos, reset_start - 1), color = current_color }
            end
            current_color = default_color
            pos = reset_end + 1
        elseif start_pos then
            if start_pos > pos then
                result[#result + 1] = { text = text:sub(pos, start_pos - 1), color = current_color }
            end
            current_color = '#' .. color
            pos = end_pos + 1
        else
            result[#result + 1] = { text = text:sub(pos), color = current_color }
            break
        end
    end

    if #result == 0 then
        result[1] = { text = text, color = default_color }
    end
    return result
end

function parseHexColor(value, fallback)
    local hex = tostring(value or ''):match('#?(%x%x%x%x%x%x)')
    if not hex then return fallback end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return imgui.ImVec4(r / 255, g / 255, b / 255, 1.00)
end

function drawScriptChangelog(item)
    if type(item) ~= 'table' then return end
    local id = tostring(item.id or item.file or item.name or 'script')
    imgui.Spacing()
    local opened = script_changelog_open[id] == true
    local label = opened and ui 'Скрыть историю версий' or ui 'Показать историю версий'
    if managerButton(label, buttonSize(label, 220)) then
        script_changelog_open[id] = not opened
    end
    if script_changelog_open[id] then
        drawChangelog(item.changelog)
    end
end

function drawChangelog(changelog)
    if type(changelog) ~= 'table' or #changelog == 0 then
        imgui.TextDisabled(ui 'История версий пока не заполнена.')
        return
    end

    imgui.Spacing()
    for _, entry in ipairs(changelog) do
        local title = tostring(entry.version or 'версия')
        if entry.date and tostring(entry.date) ~= '' then
            title = title .. ' | ' .. tostring(entry.date)
        end
        imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), ui(title))

        if type(entry.changes) == 'table' then
            for _, change in ipairs(entry.changes) do
                imgui.TextWrapped(ui('- ' .. tostring(change)))
            end
        elseif entry.text and tostring(entry.text) ~= '' then
            imgui.TextWrapped(ui(tostring(entry.text)))
        end
        imgui.Spacing()
    end
end

function infoRow(name, value)
    value = tostring(value or '-')
    local label = ui(name .. ':')
    imgui.TextDisabled(label)

    local region = imgui.GetContentRegionAvail().x
    local label_w = math.max(210, textWidth(label) + 24)
    if region > label_w + 260 then
        imgui.SameLine(label_w)
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + math.max(260, region - label_w))
        imgui.TextWrapped(ui(value))
        imgui.PopTextWrapPos()
    else
        imgui.Indent(12)
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + math.max(260, region - 16))
        imgui.TextWrapped(ui(value))
        imgui.PopTextWrapPos()
        imgui.Unindent(12)
    end
end

function drawStatusBadge(st)
    if not st.installed then
        imgui.TextColored(imgui.ImVec4(1.00, 0.65, 0.30, 1.00), ui 'Статус: не установлен')
    elseif st.outdated then
        imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.28, 1.00), ui 'Статус: доступно обновление')
    elseif st.no_version then
        imgui.TextColored(imgui.ImVec4(0.55, 0.72, 0.92, 1.00), ui 'Статус: установлен, версия не указана автором')
    else
        imgui.TextColored(imgui.ImVec4(0.35, 1.00, 0.58, 1.00), ui 'Статус: установлена последняя версия')
    end
end

function scriptStatusValue(item)
    local status = type(item) == 'table' and item.status or nil
    local value = type(status) == 'table' and tostring(status.official or ''):lower() or tostring(status or ''):lower()
    if value == 'actual' or value == 'ok' or value == 'active' or value == '0' then return 'actual' end
    if value == 'outdated' or value == 'broken' or value == 'inactive' then return 'outdated' end
    return 'unknown'
end

function scriptStatusText(item, st)
    if st and st.outdated then return 'update' end
    local value = scriptStatusValue(item)
    if value == 'actual' then return 'актуально' end
    if value == 'outdated' then return 'update' end
    if value == 'unknown' then return 'неизвестно' end
    return ''
end

function scriptStatusColor(item, st)
    if st and st.outdated then return imgui.ImVec4(0.90, 0.90, 0.90, 1.00) end
    local value = scriptStatusValue(item)
    if value == 'actual' then return imgui.ImVec4(0.63, 0.90, 0.68, 1.00) end
    if value == 'outdated' then return imgui.ImVec4(0.90, 0.90, 0.90, 1.00) end
    return imgui.ImVec4(0.94, 0.80, 0.52, 1.00)
end

function scriptStatusPalette(item, st)
    local value = scriptStatusValue(item)
    if st and st.outdated then
        return imgui.ImVec4(0.18, 0.18, 0.18, 0.88), imgui.ImVec4(0.45, 0.45, 0.45, 0.72), imgui.ImVec4(0.80, 0.80, 0.80, 1.00)
    end
    if value == 'actual' then
        return imgui.ImVec4(0.12, 0.24, 0.17, 0.88), imgui.ImVec4(0.35, 0.68, 0.43, 0.72), imgui.ImVec4(0.50, 0.88, 0.58, 1.00)
    end
    if value == 'outdated' then
        return imgui.ImVec4(0.18, 0.18, 0.18, 0.88), imgui.ImVec4(0.45, 0.45, 0.45, 0.72), imgui.ImVec4(0.80, 0.80, 0.80, 1.00)
    end
    return imgui.ImVec4(0.27, 0.22, 0.12, 0.88), imgui.ImVec4(0.74, 0.58, 0.28, 0.70), imgui.ImVec4(0.94, 0.74, 0.36, 1.00)
end

function scriptStatusPriority(item)
    local value = scriptStatusValue(item)
    if value == 'actual' then return 1 end
    if value == 'unknown' then return 2 end
    return 3
end

function statusLine(item, st)
    if not st.installed then
        return 'версия: ' .. versionText(item.version)
    end
    if st.no_version then
        return 'установлен | версия не указана'
    end
    if st.outdated then
        return 'версия: ' .. st.local_version .. ' -> ' .. versionText(item.version)
    end
    return 'версия: ' .. st.local_version
end

function listVersionColor(st)
    if not st.installed then
        return imgui.ImVec4(0.92, 0.72, 0.42, 1.00)
    end
    if st.no_version then
        return imgui.ImVec4(0.62, 0.74, 0.90, 1.00)
    end
    if st.outdated then
        return imgui.ImVec4(0.95, 0.48, 0.48, 1.00)
    end
    return imgui.ImVec4(0.55, 0.82, 0.62, 1.00)
end

function isNoVersion(value)
    local v = tostring(value or '')
    return v == '' or v == '-' or v == 'без версии'
end

function versionText(value)
    if isNoVersion(value) then return 'без версии' end
    return tostring(value)
end

function checkRemoteManifestIfNeeded()
    if next_remote_check_at <= 0 then return end
    if os.time() < next_remote_check_at then return end
    if checking or busy then return end

    checkRemoteManifest(true)
end

function checkRemoteManifest(silent)
    if checking or busy then
        if not silent then msg('Проверка уже выполняется.', WARN) end
        return
    end
    silent = silent == true
    checking = true
    busy_text = 'Проверяю GitHub manifest...'
    if not silent then
        last_error = ''
    end

    local tmp = tmp_dir .. '\\manifest_' .. tostring(os.time()) .. '_' .. tostring(math.floor(os.clock() * 1000000)) .. '.json'
    downloadUrlToFile(cacheBustUrl(MANIFEST_URL), tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            checking = false
            busy_text = ''
            local ok, err = loadManifestFromFile(tmp, true)
            if ok then
                if type(manifest.manager) ~= 'table' or not manifest.manager.url or manifest.manager.url == '' then
                    last_error = 'В manifest.json отсутствует manager.url — обновление менеджера невозможно.'
                    msg(last_error, ERR)
                end
                copyFile(tmp, manifest_cache_path)
                os.remove(tmp)
                using_cached_manifest = false
                last_manifest_error = ''
                last_error = ''
                next_remote_check_at = os.time() + REMOTE_CHECK_INTERVAL
                refreshLocalState()
                last_check_text = 'Последняя проверка: ' .. os.date('%d.%m.%Y %H:%M:%S')
                if not silent then
                    msg('Манифест обновлен.', OK)
                end
            else
                os.remove(tmp)
                handleManifestFailure(err or 'Не удалось прочитать свежий GitHub manifest', silent)
            end
        elseif status == dl_status.STATUS_ERROR then
            os.remove(tmp)
            handleManifestFailure('Не удалось загрузить GitHub manifest.', silent)
        end
    end)
end

function handleManifestFailure(reason, silent)
    checking = false
    busy_text = ''
    last_manifest_error = tostring(reason or 'GitHub manifest временно недоступен.')
    next_remote_check_at = os.time() + REMOTE_RETRY_AFTER_ERROR

    local ok, err = loadManifestFromFile(manifest_cache_path, false)
    if ok then
        using_cached_manifest = true
        last_error = ''
        refreshLocalState()
        last_check_text = 'GitHub недоступен, временно используется локальный manifest. Повтор через 5 минут.'
        if not silent then
            msg('GitHub manifest недоступен. Временно использую локальную копию, повторю через 5 минут.', WARN)
        end
    else
        using_cached_manifest = false
        last_error = last_manifest_error .. ' Локальной копии пока нет.'
        last_check_text = 'GitHub manifest не обновлен. Повтор через 5 минут.'
        if not silent then msg(last_error, ERR) end
    end
end

function managerRemoteVersion()
    if type(manifest.manager) ~= 'table' then return MANAGER_VERSION end
    return tostring(manifest.manager.version or MANAGER_VERSION)
end

function managerIsOutdated()
    return tostring(MANAGER_VERSION) ~= managerRemoteVersion()
end

function managerStatusText()
    local text = 'Modio Manager: ' .. tostring(MANAGER_VERSION) .. ' | на сайте: ' .. managerRemoteVersion()
    if managerIsOutdated() then
        return text .. ' | доступно обновление | ' .. tostring(last_check_text or '-')
    end
    return text .. ' | актуальная версия | ' .. tostring(last_check_text or '-')
end

function managerVersionColor()
    if managerIsOutdated() then
        return imgui.ImVec4(0.95, 0.48, 0.48, 1.00)
    end
    return imgui.ImVec4(0.55, 0.82, 0.62, 1.00)
end

function updateManager()
    if busy or checking then return end

    local manager = manifest.manager
    if type(manager) ~= 'table' or not manager.url or manager.url == '' then
        msg('В манифесте нет ссылки на обновление менеджера.', ERR)
        return
    end

    if not managerIsOutdated() then
        msg('Менеджер уже актуальный.', OK)
        return
    end

    busy = true
    busy_text = 'Обновляю Modio Manager...'
    last_error = ''

    ensureDir(tmp_dir)
    local tmp = tmp_dir .. '\\modio_manager.lua.download'
    local target = getManagerPath()

    downloadUrlToFile(cacheBustUrl(manager.url), tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            if doesFileExist(tmp) then
                local ok, err = replaceFile(tmp, target)
                busy = false
                busy_text = ''
                if ok then
                    msg('Менеджер обновлен.', OK)
                else
                    last_error = 'Не удалось обновить менеджер: ' .. tostring(err)
                    msg(last_error, ERR)
                end
            else
                busy = false
                busy_text = ''
                last_error = 'Загрузка менеджера завершилась, но временный файл не найден.'
                msg(last_error, ERR)
            end
        end
    end)
end

function installOrUpdate(item, mode)
    if busy or not item or not item.url or item.url == '' then return end
    busy = true
    last_error = ''
    busy_text = (mode == 'install' and 'Устанавливаю ' or 'Обновляю ') .. tostring(item.name or item.id) .. '...'

    ensureDir(tmp_dir)
    local tmp = tmp_dir .. '\\' .. item.file .. '.download'
    local target = getScriptPath(item)

    downloadUrlToFile(cacheBustUrl(item.url), tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            if doesFileExist(tmp) then
                local ok, err = replaceFile(tmp, target)
                busy = false
                busy_text = ''
                if ok then
                    refreshLocalState()
                    msg((mode == 'install' and 'Установлен: ' or 'Обновлен: ') .. item.name, OK)
                    reloadInstalledScript(item, target)
                else
                    last_error = 'Не удалось записать файл: ' .. tostring(err)
                    msg(last_error, ERR)
                end
            else
                busy = false
                busy_text = ''
                last_error = 'Загрузка завершилась, но временный файл не найден.'
                msg(last_error, ERR)
            end
        end
    end)
end

function deleteScript(item)
    if busy or not item then return end
    local path = getScriptPath(item)
    if not doesFileExist(path) then
        refreshLocalState()
        return
    end

    if item.file == thisScript().filename then
        msg('Менеджер не удаляет сам себя.', WARN)
        return
    end

    unloadLoadedScript(item, path)

    local ok, err = os.remove(path)
    if ok then
        refreshLocalState()
        msg('Удален: ' .. tostring(item.name or item.file), WARN)
    else
        last_error = 'Не удалось удалить файл: ' .. tostring(err)
        msg(last_error, ERR)
    end
end

function reloadInstalledScript(item, path)
    if not item or not path or path == '' then return end
    if item.file == thisScript().filename then return end

    local ok, err = pcall(function()
        local loaded = findLoadedScriptByPath(path)
        if loaded and loaded.reload then
            loaded:reload()
            msg('Скрипт перезагружен: ' .. tostring(item.name or item.file), OK)
        else
            script.load(path)
            msg('Скрипт загружен: ' .. tostring(item.name or item.file), OK)
        end
    end)

    if not ok then
        last_error = 'Файл установлен, но не удалось запустить скрипт: ' .. tostring(err)
        msg(last_error, WARN)
    end
end


function unloadLoadedScript(item, path)
    if not item or not path or path == '' then return end
    if item.file == thisScript().filename then return end

    local loaded = findLoadedScriptByPath(path)
    if not loaded then return end

    if not loaded.unload then
        msg('Не удалось остановить скрипт перед удалением: метод unload недоступен.', WARN)
        return
    end

    local ok, err = pcall(function()
        loaded:unload()
    end)

    if ok then
        msg('Скрипт остановлен: ' .. tostring(item.name or item.file), WARN)
    else
        msg('Не удалось остановить скрипт перед удалением: ' .. tostring(err), WARN)
    end
end

function findLoadedScriptByPath(path)
    local target = normalizePath(path)
    for _, scr in ipairs(script.list()) do
        if normalizePath(scr.path) == target then
            return scr
        end
    end
    return nil
end

function normalizePath(path)
    return tostring(path or ''):gsub('/', '\\'):lower()
end

function refreshLocalState()
    runtime = {}
    for _, item in ipairs(manifest.scripts or {}) do
        runtime[item.id] = inspectLocal(item)
    end
end

function inspectLocal(item)
    local path = getScriptPath(item)
    local installed = doesFileExist(path)
    local local_version = installed and readScriptVersion(path) or nil
    local remote_version = tostring(item.version or '')
    local no_version = isNoVersion(remote_version)
    local outdated = installed and not no_version and tostring(local_version or '') ~= remote_version

    return {
        installed = installed,
        local_version = local_version or (no_version and 'без версии' or 'неизвестно'),
        outdated = outdated,
        no_version = no_version,
        modified_at = installed and getModifiedText(path) or '-'
    }
end

function readScriptVersion(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local text = f:read(8192) or '' -- первые 8KB (~100-140 строк) — script_version должен быть в заголовке
    f:close()

    local direct = text:match("script_version%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
    if direct then return direct end

    local var_name = text:match("script_version%s*%(%s*([%w_]+)%s*%)")
    if var_name then
        local pattern1 = var_name .. "%s*=%s*['\"]([^'\"]+)['\"]"
        local version = text:match(pattern1)
        if version then return version end
    end

    local named_version = text:match("SCRIPT_VERSION%s*=%s*['\"]([^'\"]+)['\"]")
    if named_version then return named_version end

    local meta_version = text:match("SCRIPT_META%s*=%s*%b{}")
    if meta_version then
        local version = meta_version:match("VERSION%s*=%s*['\"]([^'\"]+)['\"]")
        if version then return version end
    end

    return nil
end

function getModifiedText(path)
    if ok_lfs and lfs then
        local ts = lfs.attributes(path, 'modification')
        if ts then return os.date('%d.%m.%Y %H:%M', ts) end
    end
    return '-'
end

function getScriptPath(item)
    return workdir .. '\\' .. tostring(item.file or '')
end

function getManagerPath()
    return workdir .. '\\' .. tostring(thisScript().filename or 'modio_manager.lua')
end

function replaceFile(tmp, target)
    local backup = target .. '.bak'
    if doesFileExist(backup) then os.remove(backup) end

    if doesFileExist(target) then
        local moved, move_err = os.rename(target, backup)
        if not moved then
            os.remove(tmp)
            return false, move_err or 'не удалось подготовить старый файл к замене'
        end
    end

    local ok, err = os.rename(tmp, target)
    if not ok then
        os.remove(tmp)
        if doesFileExist(backup) then os.rename(backup, target) end
        return false, err
    end

    if doesFileExist(backup) then os.remove(backup) end
    return true
end

function copyFile(source, target)
    local input = io.open(source, 'rb')
    if not input then return false end
    local data = input:read('*a') or ''
    input:close()

    local output = io.open(target, 'wb')
    if not output then return false end
    output:write(data)
    output:close()
    return true
end

function loadSeenScripts()
    seen_scripts = {}
    if not doesFileExist(seen_scripts_path) then return end

    local f = io.open(seen_scripts_path, 'r')
    if not f then return end
    local raw = f:read('*a') or ''
    f:close()
    raw = raw:gsub('^\239\187\191', ''):gsub('^%s+', '')

    local ok, data = pcall(decodeJson, raw)
    if not ok or type(data) ~= 'table' then return end
    for id, value in pairs(data) do
        if value == true then
            seen_scripts[tostring(id)] = true
        end
    end
end

function loadManifestFromFile(path, strict)
    local f = io.open(path, 'r')
    if not f then return false, 'Не удалось открыть manifest.json' end
    local raw = f:read('*a') or ''
    f:close()
    raw = raw:gsub('^\239\187\191', ''):gsub('^%s+', '')

    local ok, data = pcall(decodeJson, raw)
    if not ok or type(data) ~= 'table' then
        if strict then return false, 'manifest.json поврежден или не JSON' end
        return false
    end

    if type(data.scripts) ~= 'table' then
        if strict then return false, 'В manifest.json нет массива scripts' end
        return false
    end

    manifest = data
    selected = math.min(selected, #(manifest.scripts or {}))
    if selected < 1 then selected = 1 end
    return true
end

function saveSeenScripts()
    local f = io.open(seen_scripts_path, 'w')
    if not f then return end
    f:write(encodeJson(seen_scripts))
    f:close()
end

function ensureDir(path)
    if not doesDirectoryExist(path) then
        createDirectory(path)
    end
end

function msg(text, color)
    sampAddChatMessage(PREFIX .. ' {FFFFFF}' .. u8:decode(tostring(text)), color or CHAT)
end

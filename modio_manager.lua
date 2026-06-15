local MANAGER_VERSION = '1.7.9'

script_name('ModioManager')
script_author('ModioZodio')
script_version(MANAGER_VERSION)
script_properties('work-in-pause')

require 'lib.moonloader'

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Helpers for mimgui labels and button sizing.
-- Without these aliases the script crashes on ui(...) and buttonSize(...).
local function ui(text)
    return tostring(text or '')
end

function buttonSize(label, min_width, height)
    min_width = min_width or 120
    height = height or 34

    local width = min_width
    local ok, size = pcall(imgui.CalcTextSize, label)
    if ok and size and size.x then
        width = math.max(min_width, size.x + 24)
    end

    return imgui.ImVec2(width, height)
end
local dl_status = require('moonloader').download_status
local ok_lfs, lfs = pcall(require, 'lfs')

local new = imgui.new
local window = new.bool(false)

local MANIFEST_URL = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/manifest.json'
local LOCAL_REFRESH_INTERVAL = 2.0
local REMOTE_CHECK_INTERVAL = 3600
local PREFIX = '[ModioManager]'
local CHAT = 0x52C7EA
local OK = 0x77DD77
local WARN = 0xFFD166
local ERR = 0xFF6666

local workdir = getWorkingDirectory()
local config_dir = workdir .. '\\config\\modio_manager'
local tmp_dir = config_dir .. '\\tmp'
local cache_manifest_path = config_dir .. '\\manifest_cache.json'
local seen_scripts_path = config_dir .. '\\seen_scripts.json'
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
local last_local_refresh_clock = 0
local next_remote_check_at = 0
local manifest = {
    schema = 1,
    name = 'ModioZodio MoonLoader Pack',
    owner = 'ModioZodio',
    homepage = 'https://github.com/ilhamVode/moonloader-pack',
    updated_at = '-',
    notes = 'Каталог скриптов загружается из GitHub manifest.json. Локальный кеш используется только как fallback, если GitHub временно недоступен.',
    manager = {
        file = 'modio_manager.lua',
        version = MANAGER_VERSION,
        updated_at = '-',
        url = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/modio_manager.lua',
        changelog = {
            {
                version = MANAGER_VERSION,
                date = '2026-06-15',
                changes = {
                    'Убран вводящий в заблуждение текст "актуальная версия" из списка скриптов',
                    'Исправлена разметка бейджа актуальности в карточке скрипта'
                }
            }
        }
    },
    scripts = {}
}

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
    return imgui.ColorConvertFloat4ToU32(color)
end

function cacheBustUrl(url)
    url = tostring(url or '')
    if url == '' then return url end
    local sep = url:find('?', 1, true) and '&' or '?'
    return url .. sep .. 'modio_ts=' .. tostring(os.time())
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
    refreshLocalState()

    sampRegisterChatCommand('modio', function()
        window[0] = not window[0]
        if window[0] then refreshLocalStateIfNeeded(true) end
    end)
    sampRegisterChatCommand('mscripts', function()
        window[0] = not window[0]
        if window[0] then refreshLocalStateIfNeeded(true) end
    end)

    msg('Менеджер скриптов загружен. Окно: /modio или /mscripts', OK)
    checkRemoteManifest(true)

    while true do
        checkRemoteManifestIfNeeded()
        wait(0)
    end
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
        local sx, sy = getScreenResolution()
        local start_w = math.min(math.max(sx * 0.80, 1180), sx - 80)
        local start_h = math.min(math.max(sy * 0.78, 700), sy - 80)
        imgui.SetNextWindowSize(imgui.ImVec2(start_w, start_h), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSizeConstraints(imgui.ImVec2(1040, 650), imgui.ImVec2(math.max(1060, sx - 40), math.max(680, sy - 40)))

        if imgui.Begin(ui 'Modio Manager | менеджер скриптов', window, imgui.WindowFlags.NoCollapse) then
            refreshLocalStateIfNeeded(false)
            drawHeader()
            imgui.Separator()

            imgui.BeginChild('script_list', imgui.ImVec2(330, 0), true)
            drawScriptList()
            imgui.EndChild()

            imgui.SameLine()

            imgui.BeginChild('script_details', imgui.ImVec2(0, 0), true)
            drawDetails()
            imgui.EndChild()
        end
        imgui.End()
    end
)

function applyStyle()
    local style = imgui.GetStyle()
    style.Alpha = 0.97
    style.WindowRounding = 9
    style.ChildRounding = 8
    style.FrameRounding = 7
    style.PopupRounding = 7
    style.GrabRounding = 7
    style.ScrollbarRounding = 8
    style.WindowBorderSize = 1
    style.ChildBorderSize = 1
    style.FrameBorderSize = 0
    style.WindowPadding = imgui.ImVec2(16, 15)
    style.FramePadding = imgui.ImVec2(11, 7)
    style.ItemSpacing = imgui.ImVec2(9, 8)
    style.ItemInnerSpacing = imgui.ImVec2(8, 6)
    style.ScrollbarSize = 13

    local c = style.Colors
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.060, 0.070, 0.090, 0.94)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.095, 0.110, 0.140, 0.88)
    c[imgui.Col.PopupBg] = imgui.ImVec4(0.070, 0.082, 0.105, 0.96)
    c[imgui.Col.Border] = imgui.ImVec4(0.260, 0.330, 0.430, 0.72)
    c[imgui.Col.BorderShadow] = imgui.ImVec4(0.000, 0.000, 0.000, 0.00)
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.130, 0.165, 0.220, 0.95)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.170, 0.230, 0.315, 0.98)
    c[imgui.Col.FrameBgActive] = imgui.ImVec4(0.205, 0.285, 0.390, 1.00)
    c[imgui.Col.Button] = imgui.ImVec4(0.135, 0.260, 0.455, 0.95)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.185, 0.350, 0.610, 1.00)
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.100, 0.215, 0.385, 1.00)
    c[imgui.Col.Header] = imgui.ImVec4(0.155, 0.250, 0.385, 0.88)
    c[imgui.Col.HeaderHovered] = imgui.ImVec4(0.205, 0.330, 0.505, 0.95)
    c[imgui.Col.HeaderActive] = imgui.ImVec4(0.135, 0.245, 0.410, 1.00)
    c[imgui.Col.TitleBg] = imgui.ImVec4(0.055, 0.070, 0.100, 0.96)
    c[imgui.Col.TitleBgActive] = imgui.ImVec4(0.080, 0.125, 0.185, 0.98)
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
    c[imgui.Col.Text] = imgui.ImVec4(0.925, 0.945, 0.975, 1.00)
    c[imgui.Col.TextDisabled] = imgui.ImVec4(0.575, 0.630, 0.705, 1.00)
end

function drawHeader()
    imgui.TextColored(imgui.ImVec4(0.380, 0.680, 1.000, 1.00), ui(manifest.name or 'ModioZodio MoonLoader Pack'))
    imgui.TextDisabled(ui('Последнее обновление на сайте: ' .. tostring(manifest.updated_at or '-')))
    imgui.TextColored(managerVersionColor(), ui(managerStatusText()))

    imgui.TextDisabled(ui('Manifest: ' .. MANIFEST_URL))
    if manifest.notes and #manifest.notes > 0 then
        imgui.TextWrapped(ui(manifest.notes))
    end
    drawNewScriptsNotice()
    drawInstalledForbiddenWarning()

    if busy or checking then
        imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.35, 1.00), ui(busy_text ~= '' and busy_text or 'Идет операция...'))
    else
        imgui.TextDisabled(ui(last_check_text))
    end

    if last_error ~= '' then
        imgui.TextColored(imgui.ImVec4(1.00, 0.35, 0.35, 1.00), ui(last_error))
    end

    drawFilters()

    local check_size = buttonSize(ui 'Проверить обновления', 220)
    if imgui.Button(ui 'Проверить обновления', check_size) then
        checkRemoteManifest(false)
    end
    if managerIsOutdated() then
        drawManagerUpdateButton()
    end
    local manager_history_label = show_manager_changelog and ui 'Скрыть историю менеджера' or ui 'История менеджера'
    local manager_history_size = buttonSize(manager_history_label, 210)
    sameLineIfFits(manager_history_size.x)
    if imgui.Button(manager_history_label, manager_history_size) then
        show_manager_changelog = not show_manager_changelog
    end

    local danger_size = buttonSize(ui 'Удалить запрещенные', 230)
    sameLineIfFits(danger_size.x)
    if dangerButton(ui 'Удалить запрещенные', danger_size) then
        pending_delete_forbidden = true
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
    local size = imgui.ImVec2(46, 24)
    local pos = imgui.GetCursorScreenPos()
    local clicked = imgui.InvisibleButton(ui('##switch_' .. id), size)
    if clicked then value = not value end

    local hovered = imgui.IsItemHovered()
    local bg = value and active_color or imgui.ImVec4(0.24, 0.28, 0.34, 1.00)
    if hovered and not value then bg = imgui.ImVec4(0.30, 0.35, 0.42, 1.00) end
    if hovered and value then bg = imgui.ImVec4(math.min(active_color.x + 0.06, 1), math.min(active_color.y + 0.06, 1), math.min(active_color.z + 0.06, 1), 1.00) end

    local draw = imgui.GetWindowDrawList()
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), colorU32(bg), 12, 15)

    local radius = 9
    local knob_x = value and (pos.x + size.x - radius - 4) or (pos.x + radius + 4)
    draw:AddCircleFilled(imgui.ImVec2(knob_x, pos.y + size.y / 2), radius, colorU32(imgui.ImVec4(0.94, 0.96, 0.98, 1.00)), 24)

    imgui.SameLine()
    imgui.Text(ui(label))
    return value
end

function dangerButton(label, size)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55, 0.15, 0.16, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.72, 0.20, 0.22, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.42, 0.10, 0.11, 1.00))
    local clicked = imgui.Button(label, size)
    imgui.PopStyleColor(3)
    return clicked
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

    draw:AddRectFilled(
        imgui.ImVec2(pos.x - 4, pos.y - 4),
        imgui.ImVec2(pos.x + size.x + 4, pos.y + size.y + 4),
        colorU32(glow),
        9,
        15
    )

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.46 + pulse * 0.10, 0.15, 0.12, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.68, 0.22, 0.16, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.55, 0.12, 0.10, 1.00))
    local clicked = imgui.Button(label, size)
    imgui.PopStyleColor(3)

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
    imgui.TextDisabled(ui 'Скрипты')
    imgui.Separator()

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
end

function sortedVisibleScripts()
    local result = {}
    for i, item in ipairs(manifest.scripts or {}) do
        if isScriptVisible(item) then
            result[#result + 1] = { index = i, item = item }
        end
    end

    table.sort(result, function(a, b)
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

    imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0, 0, 0, 0))
    if imgui.Selectable(ui('##script_' .. id), selected == index, 0, size) then
        selected = index
        markScriptSeen(item)
    end
    imgui.PopStyleColor(3)
    local hovered = imgui.IsItemHovered()
    drawScriptListItemBg(screen_pos, size, selected == index, hovered, isForbiddenScript(item))

    local after = imgui.GetCursorPos()
    imgui.SetCursorPos(imgui.ImVec2(pos.x + 10, pos.y + 8))
    if isForbiddenScript(item) then
        imgui.TextColored(imgui.ImVec4(1.00, 0.28, 0.28, 1.00), ui '!')
        imgui.SameLine()
    end
    imgui.Text(ui(item.name or item.id or 'script'))
    if isScriptNew(item) then
        imgui.SameLine()
        drawNewBadge()
    end
    drawCompactStatusBadge(item)

    imgui.SetCursorPos(imgui.ImVec2(pos.x + 10, pos.y + 31))
    imgui.TextColored(listVersionColor(st), ui(statusLine(item, st)))

    imgui.SetCursorPos(after)
    imgui.Spacing()
end

function drawCompactStatusBadge(item)
    local width = scriptStatusBadgeWidth(item, 16)
    local avail = imgui.GetContentRegionAvail().x
    if avail <= width + 12 then return end

    imgui.SameLine(imgui.GetWindowContentRegionMax().x - width - 8)
    drawStatusPill(item, 'list_' .. tostring(item.id or item.file or item.name), 0.82)
end

function scriptStatusBadgeWidth(item, extra)
    local label = scriptStatusText(item)
    local text_size = imgui.CalcTextSize(ui(label))
    return text_size.x + (extra or 28) + 18
end

function drawStatusPill(item, id, scale)
    scale = scale or 1.0
    local label = ui(scriptStatusText(item))
    local text_size = imgui.CalcTextSize(label)
    local height = math.max(22, 24 * scale)
    local width = text_size.x + 28 * scale + 18
    local pos = imgui.GetCursorScreenPos()
    local size = imgui.ImVec2(width, height)
    local draw = imgui.GetWindowDrawList()
    local bg, border, dot = scriptStatusPalette(item)

    imgui.InvisibleButton(ui('##status_pill_' .. tostring(id or label)), size)
    local after = imgui.GetCursorPos()
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + width, pos.y + height), colorU32(bg), height / 2, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + width, pos.y + height), colorU32(border), height / 2, 15, 1.0)
    draw:AddCircleFilled(imgui.ImVec2(pos.x + 11 * scale, pos.y + height / 2), 4 * scale, colorU32(dot), 18)

    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + 21 * scale, pos.y + (height - text_size.y) / 2 - 1))
    imgui.TextColored(scriptStatusColor(item), label)
    imgui.SetCursorPos(imgui.ImVec2(after.x, after.y))
end

function drawScriptListItemBg(pos, size, active, hovered, forbidden)
    if not active and not hovered then return end

    local draw = imgui.GetWindowDrawList()
    local width = imgui.GetContentRegionAvail().x
    if width <= 0 then width = 300 end

    local color
    if active then
        color = imgui.ImVec4(0.145, 0.260, 0.430, 0.72)
    elseif hovered then
        color = imgui.ImVec4(0.160, 0.205, 0.275, 0.50)
    end

    draw:AddRectFilled(
        imgui.ImVec2(pos.x + 2, pos.y + 2),
        imgui.ImVec2(pos.x + width - 2, pos.y + size.y - 2),
        colorU32(color),
        7,
        15
    )

    if active then
        local stripe = forbidden and imgui.ImVec4(1.00, 0.36, 0.36, 0.95) or imgui.ImVec4(0.38, 0.68, 1.00, 0.95)
        draw:AddRectFilled(
            imgui.ImVec2(pos.x + 2, pos.y + 8),
            imgui.ImVec2(pos.x + 5, pos.y + size.y - 8),
            colorU32(stripe),
            3,
            15
        )
    end
end

function drawNewBadge()
    local label = ui 'NEW'
    local text_size = imgui.CalcTextSize(label)
    local pad_x = 8
    local pad_y = 3
    local pos = imgui.GetCursorScreenPos()
    local size = imgui.ImVec2(text_size.x + pad_x * 2, text_size.y + pad_y * 2)
    local draw = imgui.GetWindowDrawList()

    draw:AddRectFilled(
        pos,
        imgui.ImVec2(pos.x + size.x, pos.y + size.y),
        colorU32(imgui.ImVec4(0.18, 0.46, 0.82, 1.00)),
        7,
        15
    )
    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + pad_x, pos.y + pad_y - 1))
    imgui.TextColored(imgui.ImVec4(0.94, 0.98, 1.00, 1.00), label)
    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + size.x + 4, pos.y))
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
    local title = ui(item.name or item.id)
    local filename = ui(item.file or '-')
    imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), title)
    imgui.TextDisabled(filename)
    drawStatusPill(item, 'details_' .. tostring(item.id or item.file or item.name), 1.0)
    imgui.Spacing()

    imgui.Separator()
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
        if imgui.Button(ui 'Установить', install_size) then
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
        if imgui.Button(ui 'Обновить', update_size) then
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
        if imgui.Button(ui 'Удалить', delete_size) then
            pending_delete_id = item.id
        end
    elseif st.installed then
        local delete_size = buttonSize(ui 'Удалить', 170)
        if imgui.Button(ui 'Удалить', delete_size) then
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
    if imgui.Button(ui 'Да, удалить', confirm_size) then
        pending_delete_id = nil
        deleteScript(item)
    end
    local cancel_size = buttonSize(ui 'Отмена', 130)
    sameLineIfFits(cancel_size.x)
    if imgui.Button(ui 'Отмена', cancel_size) then
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
    if imgui.Button(ui 'Отмена', cancel_size) then
        pending_delete_forbidden = false
    end
end

function deleteForbiddenScripts()
    if busy then return end

    local deleted = 0
    local failed = 0
    for _, item in ipairs(manifest.scripts or {}) do
        if isForbiddenScript(item) then
            local path = getScriptPath(item)
            if doesFileExist(path) then
                local ok = os.remove(path)
                if ok then
                    deleted = deleted + 1
                else
                    failed = failed + 1
                end
            end
        end
    end

    refreshLocalState()
    ensureSelectedVisible()

    if failed > 0 then
        last_error = 'Не удалось удалить запрещенных скриптов: ' .. tostring(failed)
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

function drawScriptChangelog(item)
    if type(item) ~= 'table' then return end
    local id = tostring(item.id or item.file or item.name or 'script')
    imgui.Spacing()
    local opened = script_changelog_open[id] == true
    local label = opened and ui 'Скрыть историю версий' or ui 'Показать историю версий'
    if imgui.Button(label, buttonSize(label, 220)) then
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
    if value == 'actual' or value == 'ok' or value == 'active' then return 'actual' end
    if value == 'outdated' or value == 'broken' or value == 'inactive' then return 'outdated' end
    return 'unknown'
end

function scriptStatusText(item)
    local value = scriptStatusValue(item)
    if value == 'actual' then return 'актуально' end
    if value == 'outdated' then return 'неактуально' end
    return 'неизвестно'
end

function scriptStatusColor(item)
    local value = scriptStatusValue(item)
    if value == 'actual' then return imgui.ImVec4(0.63, 0.90, 0.68, 1.00) end
    if value == 'outdated' then return imgui.ImVec4(0.96, 0.58, 0.58, 1.00) end
    return imgui.ImVec4(0.94, 0.80, 0.52, 1.00)
end

function scriptStatusPalette(item)
    local value = scriptStatusValue(item)
    if value == 'actual' then
        return imgui.ImVec4(0.12, 0.24, 0.17, 0.88), imgui.ImVec4(0.35, 0.68, 0.43, 0.72), imgui.ImVec4(0.50, 0.88, 0.58, 1.00)
    end
    if value == 'outdated' then
        return imgui.ImVec4(0.28, 0.13, 0.13, 0.88), imgui.ImVec4(0.76, 0.34, 0.34, 0.72), imgui.ImVec4(0.96, 0.48, 0.48, 1.00)
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
    if checking or busy then return end
    silent = silent == true
    checking = true
    busy_text = 'Проверяю манифест...'
    if not silent then
        last_error = ''
    end

    local tmp = tmp_dir .. '\\manifest_' .. os.time() .. '.json'
    downloadUrlToFile(cacheBustUrl(MANIFEST_URL), tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            checking = false
            busy_text = ''
            next_remote_check_at = os.time() + REMOTE_CHECK_INTERVAL
            local ok, err = loadManifestFromFile(tmp, true)
            os.remove(tmp)
            if ok then
                saveManifestCache()
                refreshLocalState()
                last_check_text = 'Последняя проверка: ' .. os.date('%d.%m.%Y %H:%M:%S')
                if not silent then
                    msg('Манифест обновлен.', OK)
                end
            else
                local cached = loadCachedManifest()
                if cached then
                    refreshLocalState()
                    last_check_text = 'GitHub manifest недоступен, показан локальный fallback-кеш.'
                    if not silent then
                        msg('GitHub manifest недоступен, открыт локальный кеш.', WARN)
                    end
                elseif not silent then
                    last_error = err or 'Не удалось прочитать manifest.json'
                    msg(last_error, ERR)
                end
            end
        end
    end)
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
        return text .. ' | доступно обновление'
    end
    return text .. ' | актуальная версия'
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
    local text = f:read('*a') or ''
    f:close()

    local direct = text:match("script_version%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
    if direct then return direct end

    local var_name = text:match("script_version%s*%(%s*([%w_]+)%s*%)")
    if var_name then
        local pattern1 = var_name .. "%s*=%s*['\"]([^'\"]+)['\"]"
        local version = text:match(pattern1)
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

function loadCachedManifest()
    if doesFileExist(cache_manifest_path) then
        local loaded = loadManifestFromFile(cache_manifest_path, false) == true
        if loaded then
            last_check_text = 'Показан локальный fallback-кеш.'
        end
        return loaded
    end
    return false
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

function saveManifestCache()
    local f = io.open(cache_manifest_path, 'w')
    if not f then return end
    f:write(encodeJson(manifest))
    f:close()
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

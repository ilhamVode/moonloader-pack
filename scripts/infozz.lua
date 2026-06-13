script_name('InfoZZ')
script_author('Codex')
script_version('1.7.3')
script_description('TXT справочник для SA:MP. Автор: Codex')

require 'lib.moonloader'

local ffi = require 'ffi'
local imgui = require 'mimgui'
local new = imgui.new
local ok_encoding, encoding = pcall(require, 'encoding')
local u8 = nil
if ok_encoding then
    encoding.default = 'CP1251'
    u8 = encoding.UTF8
end

local ok_lfs, lfs = pcall(require, 'lfs')

local PREFIX = '[InfoZZ]'
local AUTHOR = 'Codex'
local CHAT_INFO = 0x66CCFF
local CHAT_OK = 0x77DD77
local CHAT_WARN = 0xFFD166
local CHAT_ERR = 0xFF6666
local MAX_FILE_BYTES = 2 * 1024 * 1024
local READ_CHUNK_BYTES = 16 * 1024
local PYTHON_EXE = 'C:\\Users\\USER\\PycharmProjects\\PythonProject\\.venv\\Scripts\\pythonw.exe'
local PYTHON_PROJECT_DIR = 'C:\\Users\\USER\\PycharmProjects\\PythonProject'
local PYTHON_CONFIG = PYTHON_PROJECT_DIR .. '\\config.json'

local window = new.bool(false)
local notice_open = new.bool(true)
local search_buffer = new.char[256]()
local ai_buffer = new.char[256]()
local view_mode = 'txt'

local config_dir = getWorkingDirectory() .. '\\config\\infozz'
local PYTHON_STATUS_FILE = config_dir .. '\\_infozz_update_status.status'
local IMGUI_INI_FILE = config_dir .. '\\infozz_imgui.ini'
local TITLES_CONFIG_FILE = config_dir .. '\\infozz_titles.cfg'
local files = {}
local skipped_files = {}
local title_overrides = {}
local selected_index = 1
local active_match = 1
local matches = {}
local last_search = ''
local last_load_message = 'Файлы еще не загружены.'
local loaded_at_text = '-'
local is_loading = false
local reload_after_loading = false
local pending_reload = false
local pending_reload_silent = true
local loading_progress = 0
local loading_total = 0
local startup_notice_pending = true
local config_dir_ready = false
local forum_update_running = false
local need_rebuild_matches = true
local need_scroll_to_match = false
local startup_notice_until = 0
local startup_font = nil
local update_status_text = 'Статус форума: требуется обновление.'
local update_status_color = nil
local last_forum_status_raw = ''
local ai_answer = 'Задай вопрос по загруженным TXT.'
local ai_results = {}
local title_editor_open = new.bool(false)
local title_editor_buffer = new.char[256]()
local title_editor_index = nil
local title_editor_popup_pending = false

local colors = {
    bg = imgui.ImVec4(0.065, 0.078, 0.105, 1.00),
    panel = imgui.ImVec4(0.095, 0.118, 0.158, 1.00),
    panel_hover = imgui.ImVec4(0.135, 0.170, 0.230, 1.00),
    panel_soft = imgui.ImVec4(0.115, 0.145, 0.195, 1.00),
    accent = imgui.ImVec4(0.180, 0.430, 0.900, 1.00),
    accent_hover = imgui.ImVec4(0.240, 0.520, 1.000, 1.00),
    cyan = imgui.ImVec4(0.200, 0.780, 0.920, 1.00),
    violet = imgui.ImVec4(0.560, 0.390, 0.980, 1.00),
    text = imgui.ImVec4(0.910, 0.935, 0.970, 1.00),
    muted = imgui.ImVec4(0.550, 0.610, 0.700, 1.00),
    yellow = imgui.ImVec4(1.000, 0.830, 0.220, 1.00),
    danger = imgui.ImVec4(0.980, 0.320, 0.320, 1.00),
    success = imgui.ImVec4(0.340, 0.820, 0.520, 1.00)
}

update_status_color = colors.danger

local ru_lower_map = {
    ['А'] = 'а', ['Б'] = 'б', ['В'] = 'в', ['Г'] = 'г', ['Д'] = 'д',
    ['Е'] = 'е', ['Ё'] = 'ё', ['Ж'] = 'ж', ['З'] = 'з', ['И'] = 'и',
    ['Й'] = 'й', ['К'] = 'к', ['Л'] = 'л', ['М'] = 'м', ['Н'] = 'н',
    ['О'] = 'о', ['П'] = 'п', ['Р'] = 'р', ['С'] = 'с', ['Т'] = 'т',
    ['У'] = 'у', ['Ф'] = 'ф', ['Х'] = 'х', ['Ц'] = 'ц', ['Ч'] = 'ч',
    ['Ш'] = 'ш', ['Щ'] = 'щ', ['Ъ'] = 'ъ', ['Ы'] = 'ы', ['Ь'] = 'ь',
    ['Э'] = 'э', ['Ю'] = 'ю', ['Я'] = 'я'
}

function main()
    while not isSampAvailable() do wait(100) end

    ensure_dir(config_dir)
    refresh_update_status()
    queue_txt_reload(true)
    startup_font = renderCreateFont('Segoe UI', 10, 5)

    sampRegisterChatCommand('infozz', function()
        window[0] = not window[0]
    end)

    chat('Author: ' .. AUTHOR, CHAT_INFO)
    chat('/infozz - open TXT helper. Loading files in background...', CHAT_INFO)
    show_startup_notice()

    while true do
        wait(0)
        if pending_reload then
            local silent = pending_reload_silent
            pending_reload = false
            request_txt_reload(silent)
        end
        draw_render_startup_notice()
    end
end

imgui.OnInitialize(function()
    ensure_dir(config_dir)
    imgui.GetIO().IniFilename = IMGUI_INI_FILE
    apply_style()
end)

imgui.OnFrame(
    function() return window[0] end,
    function()
        if window[0] then
        imgui.SetNextWindowSize(imgui.ImVec2(1040, 670), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSizeConstraints(imgui.ImVec2(860, 520), imgui.ImVec2(1500, 940))

        if imgui.Begin('InfoZZ | TXT справочник', window, imgui.WindowFlags.NoCollapse) then
            draw_header()
            draw_mode_tabs()

            if view_mode == 'ai' then
                draw_ai_page()
            else
                imgui.BeginChild('left_sidebar_shell', imgui.ImVec2(340, 0), false)
                draw_file_panel()
                imgui.EndChild()
                imgui.SameLine()
                imgui.BeginChild('right_reader_shell', imgui.ImVec2(0, 0), false)
                draw_reader_panel()
                imgui.EndChild()
            end
            draw_title_editor_modal()
        end
        imgui.End()
        end
    end
)

function apply_style()
    local style = imgui.GetStyle()
    style.WindowRounding = 12
    style.ChildRounding = 10
    style.FrameRounding = 8
    style.PopupRounding = 10
    style.ScrollbarRounding = 10
    style.GrabRounding = 8
    style.WindowPadding = imgui.ImVec2(16, 16)
    style.FramePadding = imgui.ImVec2(11, 8)
    style.ItemSpacing = imgui.ImVec2(10, 9)
    style.ItemInnerSpacing = imgui.ImVec2(8, 7)

    local c = style.Colors
    c[imgui.Col.WindowBg] = colors.bg
    c[imgui.Col.ChildBg] = colors.panel
    c[imgui.Col.PopupBg] = colors.panel
    c[imgui.Col.Border] = imgui.ImVec4(0.220, 0.270, 0.360, 1.00)
    c[imgui.Col.TitleBg] = imgui.ImVec4(0.060, 0.075, 0.105, 1.00)
    c[imgui.Col.TitleBgActive] = imgui.ImVec4(0.105, 0.140, 0.205, 1.00)
    c[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.060, 0.075, 0.105, 1.00)
    c[imgui.Col.Text] = colors.text
    c[imgui.Col.TextDisabled] = colors.muted
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.130, 0.165, 0.225, 1.00)
    c[imgui.Col.FrameBgHovered] = colors.panel_hover
    c[imgui.Col.FrameBgActive] = imgui.ImVec4(0.160, 0.210, 0.300, 1.00)
    c[imgui.Col.Button] = colors.accent
    c[imgui.Col.ButtonHovered] = colors.accent_hover
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.160, 0.360, 0.760, 1.00)
    c[imgui.Col.Header] = imgui.ImVec4(0.160, 0.220, 0.320, 1.00)
    c[imgui.Col.HeaderHovered] = imgui.ImVec4(0.200, 0.290, 0.430, 1.00)
    c[imgui.Col.HeaderActive] = imgui.ImVec4(0.220, 0.490, 0.950, 0.55)
    c[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.080, 0.100, 0.140, 1.00)
    c[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.240, 0.300, 0.400, 1.00)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.320, 0.400, 0.540, 1.00)
    c[imgui.Col.ResizeGrip] = imgui.ImVec4(0.180, 0.430, 0.900, 0.35)
    c[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.240, 0.520, 1.000, 0.65)
    c[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.560, 0.390, 0.980, 0.85)
end

function push_button_style(base, hover, active)
    imgui.PushStyleColor(imgui.Col.Button, base)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, hover or base)
    imgui.PushStyleColor(imgui.Col.ButtonActive, active or hover or base)
end

function pop_button_style()
    imgui.PopStyleColor(3)
end

function styled_button(label, size, base, hover, active)
    push_button_style(base, hover, active)
    local clicked = imgui.Button(label, size)
    pop_button_style()
    return clicked
end

function draw_subtle_line()
    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(0.180, 0.230, 0.310, 1.00))
    imgui.Separator()
    imgui.PopStyleColor()
end

function show_startup_notice()
    startup_notice_until = os.clock() + 7
end

function is_startup_notice_visible()
    return startup_notice_until > os.clock()
end

function draw_startup_notice()
    local io = imgui.GetIO()
    imgui.SetNextWindowPos(imgui.ImVec2(io.DisplaySize.x - 360, 42), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(330, 92), imgui.Cond.Always)

    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing
    notice_open[0] = true
    if imgui.Begin('InfoZZ startup notice', notice_open, flags) then
        imgui.TextColored(colors.accent, 'InfoZZ loaded')
        imgui.Text('Author: ' .. AUTHOR)
        imgui.TextDisabled('/infozz - TXT helper')
    end
    imgui.End()
end

function draw_render_startup_notice()
    if not is_startup_notice_visible() or not startup_font then return end

    local sx, sy = getScreenResolution()
    local x = sx - 320
    local y = sy - 92
    renderDrawBox(x - 12, y - 10, 300, 72, 0xC8101724)
    renderFontDrawText(startup_font, 'InfoZZ loaded', x, y, 0xFF66CCFF)
    renderFontDrawText(startup_font, 'Author: Codex', x, y + 20, 0xFFE8EEF8)
    renderFontDrawText(startup_font, '/infozz - TXT helper', x, y + 40, 0xFF9AA7B7)
end

function draw_header()
    imgui.TextColored(colors.cyan, 'InfoZZ')
    imgui.SameLine()
    imgui.TextDisabled('by Codex')
    imgui.SameLine()
    imgui.TextColored(colors.success, tostring(#files) .. ' TXT')
    imgui.SameLine()
    imgui.TextDisabled('loaded: ' .. loaded_at_text)

    local button_h = 34
    local region = imgui.GetContentRegionAvail().x
    local right_w = 336
    local text_w = region - right_w
    if text_w < 280 then text_w = region end

    imgui.BeginGroup()
    imgui.TextColored(update_status_color, update_status_text)
    imgui.TextDisabled('folder: ' .. config_dir)
    imgui.EndGroup()

    if region > 620 then
        imgui.SameLine(region - right_w)
    end

    if is_loading then
        styled_button('TXT...', imgui.ImVec2(132, button_h), colors.panel_hover, colors.panel_hover, colors.panel_hover)
    elseif styled_button('Обновить TXT', imgui.ImVec2(132, button_h), colors.accent, colors.accent_hover, imgui.ImVec4(0.130, 0.330, 0.760, 1.00)) then
        queue_txt_reload(false)
    end
    imgui.SameLine()
    if forum_update_running then
        styled_button('Форум...', imgui.ImVec2(178, button_h), colors.panel_hover, colors.panel_hover, colors.panel_hover)
    elseif styled_button('Обновить с форума', imgui.ImVec2(178, button_h), colors.violet, imgui.ImVec4(0.650, 0.500, 1.000, 1.00), imgui.ImVec4(0.450, 0.280, 0.850, 1.00)) then
        start_forum_update()
    end

    draw_subtle_line()
end

function draw_mode_tabs()
    local active_txt = view_mode == 'txt'
    local txt_base = active_txt and colors.accent or colors.panel_soft
    local ai_base = view_mode == 'ai' and colors.violet or colors.panel_soft

    if styled_button('TXT просмотр', imgui.ImVec2(148, 32), txt_base, colors.accent_hover, colors.accent) then
        view_mode = 'txt'
    end
    imgui.SameLine()
    if styled_button('AI поиск', imgui.ImVec2(128, 32), ai_base, imgui.ImVec4(0.650, 0.500, 1.000, 1.00), colors.violet) then
        view_mode = 'ai'
    end
    draw_subtle_line()
end

function draw_file_panel()
    imgui.BeginChild('files_panel', imgui.ImVec2(0, 0), true)
    imgui.TextColored(colors.cyan, 'Файлы')
    imgui.SameLine()
    imgui.TextColored(colors.success, tostring(#files))
    draw_subtle_line()
    imgui.TextWrapped(last_load_message)
    if is_loading then
        local fraction = 0
        if loading_total > 0 then fraction = loading_progress / loading_total end
        imgui.ProgressBar(fraction, imgui.ImVec2(-1, 10), '')
    end
    if #skipped_files > 0 then
        imgui.Spacing()
        imgui.TextColored(colors.yellow, 'Пропущено: ' .. tostring(#skipped_files))
        if imgui.IsItemHovered() then
            imgui.SetTooltip(table.concat(skipped_files, '\n'))
        end
    end
    draw_subtle_line()

    if #files == 0 then
        imgui.TextWrapped('В папке пока нет .txt файлов.')
        imgui.Spacing()
        imgui.TextColored(colors.muted, config_dir)
    else
        for i, file in ipairs(files) do
            local row_width = imgui.GetContentRegionAvail().x
            local edit_w = 58
            local gap = 8
            local select_w = row_width - edit_w - gap
            if select_w < 80 then select_w = 80 end

            local label = file.title .. '##file_' .. i
            if selected_index == i then
                imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(0.180, 0.430, 0.900, 0.70))
                imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0.240, 0.520, 1.000, 0.82))
            else
                imgui.PushStyleColor(imgui.Col.Header, colors.panel_soft)
                imgui.PushStyleColor(imgui.Col.HeaderHovered, colors.panel_hover)
            end
            if imgui.Selectable(label, selected_index == i, 0, imgui.ImVec2(select_w, 28)) then
                selected_index = i
                set_active_match(1)
                need_rebuild_matches = true
            end
            imgui.PopStyleColor(2)
            if imgui.IsItemHovered() then
                imgui.SetTooltip(file.name .. '\n' .. file.path .. '\n' .. pretty_bytes(file.size) .. '\n' .. file.modified)
            end
            imgui.SameLine(0, gap)
            if styled_button('Изм.##edit_title_' .. i, imgui.ImVec2(edit_w, 28), colors.panel_soft, colors.violet, colors.accent) then
                open_title_editor(i)
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip('Изменить отображаемое название')
            end
        end
    end
    imgui.EndChild()
end

function draw_reader_panel()
    local file = files[selected_index]

    imgui.BeginChild('reader_panel', imgui.ImVec2(0, 0), true)
    if is_loading then
        imgui.TextColored(colors.yellow, 'Обновляю TXT в фоне...')
        imgui.TextDisabled('Просмотр временно остановлен, чтобы не грузить игру.')
        imgui.EndChild()
        return
    end

    if not file then
        imgui.TextWrapped('Выбери TXT файл слева. Файлы загружаются при старте скрипта или кнопкой "Обновить".')
        imgui.EndChild()
        return
    end

    imgui.TextColored(colors.cyan, file.title)
    imgui.SameLine()
    imgui.TextDisabled(string.format('%s | %d строк | %s', file.name, #file.lines, pretty_bytes(file.size)))

    imgui.PushItemWidth(-1)
    if imgui.InputTextWithHint('##search', 'Поиск по тексту...', search_buffer, 256) then
        set_active_match(1)
        need_rebuild_matches = true
    end
    imgui.PopItemWidth()

    if need_rebuild_matches or buffer_text(search_buffer) ~= last_search then
        rebuild_matches()
    end

    draw_search_controls()
    draw_subtle_line()
    draw_text_view(file)
    imgui.EndChild()
end

function draw_ai_page()
    imgui.BeginChild('ai_page', imgui.ImVec2(0, 0), true)
    imgui.TextColored(colors.violet, 'Mini AI по TXT')
    imgui.TextDisabled('Лёгкий локальный ассистент: ищет ответ только в загруженных TXT.')
    imgui.PushItemWidth(-146)
    imgui.InputTextWithHint('##ai_question', 'Вопрос по правилам/кодексам...', ai_buffer, 256)
    imgui.PopItemWidth()
    imgui.SameLine()
    if styled_button('Спросить', imgui.ImVec2(132, 0), colors.violet, imgui.ImVec4(0.650, 0.500, 1.000, 1.00), colors.accent) then
        run_ai_search(buffer_text(ai_buffer))
    end
    draw_subtle_line()
    imgui.TextWrapped(ai_answer)
    if #ai_results > 0 then
        imgui.Spacing()
        for i, item in ipairs(ai_results) do
            local title = string.format('%d) %s:%d##ai_result_%d', i, item.file, item.line, i)
            if imgui.Selectable(title, false) then
                jump_to_ai_result(item)
            end
            imgui.TextWrapped(item.text)
            imgui.Separator()
        end
    end
    imgui.EndChild()
end

function draw_search_controls()
    local query = trim(buffer_text(search_buffer))
    if query == '' then
        imgui.TextColored(colors.muted, 'Введите подстроку для поиска.')
        return
    end

    if #matches == 0 then
        imgui.TextColored(colors.danger, 'Совпадений нет')
        return
    end

    imgui.TextColored(colors.yellow, string.format('Найдено: %d / %d', active_match, #matches))
    imgui.SameLine()
    if styled_button('< Назад', imgui.ImVec2(96, 0), colors.panel_soft, colors.panel_hover, colors.accent) then
        set_active_match(active_match - 1)
    end
    imgui.SameLine()
    if styled_button('Вперед >', imgui.ImVec2(104, 0), colors.panel_soft, colors.panel_hover, colors.accent) then
        set_active_match(active_match + 1)
    end
end

function draw_text_view(file)
    imgui.BeginChild('text_scroll', imgui.ImVec2(0, 0), true, imgui.WindowFlags.HorizontalScrollbar)

    local active = matches[active_match]
    local target_line = active and active.line or nil
    local line_height = imgui.GetTextLineHeightWithSpacing()
    local scroll_y = imgui.GetScrollY()
    local view_height = imgui.GetWindowHeight()
    local total_lines = #file.lines
    local first_line = math.floor(scroll_y / line_height) - 8
    local visible_count = math.ceil(view_height / line_height) + 16
    if first_line < 1 then first_line = 1 end
    local last_line = first_line + visible_count
    if last_line > total_lines then last_line = total_lines end

    if need_scroll_to_match and target_line then
        first_line = math.max(1, target_line - math.floor(visible_count / 3))
        last_line = math.min(total_lines, first_line + visible_count)
    end

    if first_line > 1 then
        imgui.Dummy(imgui.ImVec2(1, (first_line - 1) * line_height))
    end

    for i = first_line, last_line do
        local line = file.lines[i]
        draw_highlighted_line(line, i, active)
        if need_scroll_to_match and target_line == i then
            imgui.SetScrollHereY(0.35)
            need_scroll_to_match = false
        end
    end

    if last_line < total_lines then
        imgui.Dummy(imgui.ImVec2(1, (total_lines - last_line) * line_height))
    end

    imgui.EndChild()
end

function draw_highlighted_line(line, line_index, active)
    local query = trim(buffer_text(search_buffer))
    if query == '' then
        imgui.TextUnformatted(line)
        return
    end

    local start_pos, end_pos = nil, nil
    if active and active.line == line_index then
        start_pos, end_pos = active.start_pos, active.end_pos
    else
        local lower_line = normalize_search_text(line)
        local lower_query = escape_lua_pattern(normalize_search_text(query))
        start_pos, end_pos = lower_line:find(lower_query)
    end

    if not start_pos then
        imgui.TextUnformatted(line)
        return
    end

    local before = line:sub(1, start_pos - 1)
    local hit = line:sub(start_pos, end_pos)
    local after = line:sub(end_pos + 1)

    if before ~= '' then
        imgui.TextUnformatted(before)
        imgui.SameLine(0, 0)
    end

    imgui.TextColored(colors.yellow, hit)

    if after ~= '' then
        imgui.SameLine(0, 0)
        imgui.TextUnformatted(after)
    end
end

function rebuild_matches()
    matches = {}
    local query = trim(buffer_text(search_buffer))
    last_search = query
    need_rebuild_matches = false

    local file = files[selected_index]
    if not file or query == '' then return end

    local needle = escape_lua_pattern(normalize_search_text(query))
    for line_index, lower in ipairs(file.search_lines or file.lines) do
        local from = 1
        while true do
            local s, e = lower:find(needle, from)
            if not s then break end
            table.insert(matches, { line = line_index, start_pos = s, end_pos = e })
            from = e + 1
        end
    end

    if active_match > #matches then
        set_active_match(1)
    elseif #matches > 0 then
        need_scroll_to_match = true
    end
end

function run_ai_search(question)
    ai_answer, ai_results = build_ai_answer(question)
    search_buffer[0] = 0
end

function open_title_editor(index)
    local file = files[index]
    if not file then return end

    title_editor_index = index
    ffi.copy(title_editor_buffer, file.title or file.name)
    title_editor_open[0] = true
    title_editor_popup_pending = true
end

function draw_title_editor_modal()
    if not title_editor_open[0] then return end

    if title_editor_popup_pending then
        imgui.OpenPopup('Изменить название TXT')
        title_editor_popup_pending = false
    end

    if imgui.BeginPopupModal('Изменить название TXT', title_editor_open, imgui.WindowFlags.AlwaysAutoResize) then
        local file = files[title_editor_index or 0]
        if file then
            imgui.TextDisabled(file.name)
            imgui.PushItemWidth(360)
            imgui.InputText('Название##title_input', title_editor_buffer, 256)
            imgui.PopItemWidth()

            if imgui.Button('Сохранить', imgui.ImVec2(120, 0)) then
                local title = trim(buffer_text(title_editor_buffer))
                if title == '' then title = default_title_from_filename(file.name) end
                title_overrides[file.name] = title
                file.title = title
                save_title_overrides()
                title_editor_open[0] = false
                imgui.CloseCurrentPopup()
            end
            imgui.SameLine()
            if imgui.Button('Сбросить', imgui.ImVec2(110, 0)) then
                title_overrides[file.name] = nil
                file.title = default_title_from_filename(file.name)
                save_title_overrides()
                title_editor_open[0] = false
                imgui.CloseCurrentPopup()
            end
            imgui.SameLine()
            if imgui.Button('Отмена', imgui.ImVec2(90, 0)) then
                title_editor_open[0] = false
                imgui.CloseCurrentPopup()
            end
        else
            title_editor_open[0] = false
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
end

function build_ai_answer(question)
    ai_results = {}
    question = trim(question or '')
    if question == '' then
        return 'Напиши вопрос, например: "когда можно проводить обыск?"', {}
    end

    local tokens = extract_query_tokens(question)
    if #tokens == 0 then
        return 'Слишком короткий вопрос. Добавь ключевые слова.', {}
    end

    local scored = {}
    for file_index, file in ipairs(files) do
        for line_index, lower in ipairs(file.search_lines or {}) do
            local score = 0
            for _, token in ipairs(tokens) do
                if lower:find(escape_lua_pattern(token), 1) then
                    score = score + #token
                end
            end

            if score > 0 then
                table.insert(scored, {
                    score = score,
                    file_index = file_index,
                    file = file.name,
                    line = line_index,
                    text = file.lines[line_index] or ''
                })
            end
        end
    end

    table.sort(scored, function(a, b)
        if a.score == b.score then return a.file < b.file end
        return a.score > b.score
    end)

    if #scored == 0 then
        return 'По загруженным TXT ничего похожего не нашёл.', {}
    end

    local results = {}
    local used = 0
    local seen = {}
    for _, item in ipairs(scored) do
        local key = item.file .. ':' .. tostring(item.line)
        if not seen[key] and trim(item.text) ~= '' then
            seen[key] = true
            used = used + 1
            local title = item.file
            if files[item.file_index] then
                title = files[item.file_index].title or item.file
            end
            table.insert(results, {
                file_index = item.file_index,
                file = title,
                line = item.line,
                text = trim(item.text)
            })
            if used >= 6 then break end
        end
    end

    return 'Нашёл похожие места. Нажми на результат, чтобы перейти к строке.', results
end

function jump_to_ai_result(item)
    if not item or not files[item.file_index] then return end

    selected_index = item.file_index
    view_mode = 'txt'
    matches = {
        {
            line = item.line,
            start_pos = 1,
            end_pos = math.max(1, #(files[item.file_index].lines[item.line] or ''))
        }
    }
    active_match = 1
    need_rebuild_matches = false
    need_scroll_to_match = true
end

function extract_query_tokens(text)
    text = normalize_search_text(text)
    local tokens = {}
    local stop = {
        ['что'] = true, ['как'] = true, ['когда'] = true, ['где'] = true,
        ['можно'] = true, ['надо'] = true, ['нужно'] = true, ['если'] = true,
        ['это'] = true, ['для'] = true, ['при'] = true, ['или'] = true,
        ['the'] = true, ['and'] = true, ['with'] = true
    }

    for token in text:gmatch('[%w\128-\255]+') do
        if #token >= 3 and not stop[token] then
            table.insert(tokens, token)
        end
    end

    return tokens
end

function set_active_match(value)
    if #matches == 0 then
        active_match = 1
    else
        active_match = value
        if active_match < 1 then active_match = #matches end
        if active_match > #matches then active_match = 1 end
    end
    need_scroll_to_match = true
end

function queue_txt_reload(silent)
    pending_reload = true
    pending_reload_silent = silent
end

function start_forum_update()
    if forum_update_running then return end

    ensure_dir(config_dir)
    forum_update_running = true
    update_status_text = 'Форум: обновление запущено...'
    update_status_color = colors.yellow
    chat('Starting Python forum update...', CHAT_INFO)
    write_status_file('LAUNCHING')

    lua_thread.create(function()
        wait(0)
        local command = string.format(
            'cmd /c start "" /B "%s" "%s\\main.py" --update-once --config "%s"',
            PYTHON_EXE,
            PYTHON_PROJECT_DIR,
            PYTHON_CONFIG
        )
        os.execute(command)
        watch_forum_update_result()
    end)
end

function watch_forum_update_result()
    local started = os.time()
    while forum_update_running do
        wait(1000)
        local status = read_status_file()

        if status and status ~= last_forum_status_raw then
            last_forum_status_raw = status
            refresh_update_status()
            if status:find('RUNNING|', 1, true) then
                chat(update_status_text, CHAT_INFO)
            end
        end

        if status and status:find('DONE', 1, true) then
            forum_update_running = false
            refresh_update_status()
            chat(update_status_text, update_status_color == colors.success and CHAT_OK or update_status_color == colors.yellow and CHAT_WARN or CHAT_ERR)
            chat('Reloading TXT...', CHAT_INFO)
            queue_txt_reload(true)
            return
        end

        if status and status:find('ERROR', 1, true) then
            forum_update_running = false
            refresh_update_status()
            chat('Python update failed. Check parser_background.log.', CHAT_ERR)
            return
        end

        if (status == 'LAUNCHING' or status == 'RUNNING') and os.time() - started > 8 then
            forum_update_running = false
            update_status_text = 'Форум: Python не запустился. Проверь путь к PythonProject.'
            update_status_color = colors.danger
            chat(update_status_text, CHAT_ERR)
            return
        end

        if os.time() - started > 15 * 60 then
            forum_update_running = false
            chat('Python update timeout. Check parser_background.log.', CHAT_WARN)
            return
        end
    end
end

function refresh_update_status()
    local status = read_status_file()
    if not status or status == '' then
        status = read_config_update_status()
    end

    if status == 'LAUNCHING' then
        update_status_text = 'Форум: обновление запускается...'
        update_status_color = colors.yellow
        return
    end

    if not status or status == '' then
        update_status_text = 'Статус форума: требуется обновление.'
        update_status_color = colors.danger
        return
    end

    if status == 'RUNNING' then
        update_status_text = 'Статус форума: предыдущее обновление не завершилось.'
        update_status_color = colors.danger
        return
    end

    local running_index, running_total, running_file = status:match('^RUNNING|(%d+)|(%d+)|(.+)')
    if running_index then
        update_status_text = string.format('Форум: обновляю %s/%s - %s', running_index, running_total, running_file)
        update_status_color = colors.yellow
        return
    end

    if status:find('ERROR', 1, true) then
        update_status_text = 'Статус форума: ошибка обновления.'
        update_status_color = colors.danger
        return
    end

    local tag, stamp, success, total = status:match('^(%w+)|([^|]+)|(%d+)|(%d+)')
    if tag ~= 'DONE' or not stamp then
        update_status_text = 'Статус форума: требуется обновление.'
        update_status_color = colors.danger
        return
    end

    success = tonumber(success) or 0
    total = tonumber(total) or 0
    local age_seconds = seconds_since_stamp(stamp)
    local age_text = format_age(age_seconds)
    update_status_text = string.format('Форум: %s, успешно %d/%d, %s', stamp, success, total, age_text)

    if total > 0 and success < total then
        update_status_text = update_status_text .. ' - были ошибки'
        update_status_color = colors.danger
    elseif age_seconds <= 24 * 60 * 60 then
        update_status_text = update_status_text .. ' - актуально'
        update_status_color = colors.success
    elseif age_seconds <= 7 * 24 * 60 * 60 then
        update_status_text = update_status_text .. ' - возможны изменения'
        update_status_color = colors.yellow
    else
        update_status_text = update_status_text .. ' - требуется обновление'
        update_status_color = colors.danger
    end
end

function request_txt_reload(silent)
    if is_loading then
        reload_after_loading = true
        return
    end

    is_loading = true
    reload_after_loading = false
    loading_progress = 0
    loading_total = 0
    last_load_message = 'Загрузка TXT в фоне...'
    need_rebuild_matches = false
    matches = {}

    lua_thread.create(function()
        wait(0)
        local ok, err = pcall(load_txt_files_worker, silent)
        if not ok then
            is_loading = false
            reload_after_loading = false
            last_load_message = 'Ошибка загрузки TXT.'
            chat('Load error: ' .. tostring(err), CHAT_ERR)
        end
    end)
end

function load_txt_files_worker(silent)
    local new_files = {}
    local new_skipped = {}

    ensure_dir(config_dir)
    title_overrides = load_title_overrides()
    wait(0)

    local names = list_txt_names(config_dir)
    table.sort(names, function(a, b) return a:lower() < b:lower() end)

    loading_total = #names
    if loading_total == 0 then
        last_load_message = 'TXT файлов нет. Папка проверена.'
    end

    for index, name in ipairs(names) do
        loading_progress = index - 1
        last_load_message = string.format('Загрузка: %d / %d', index, loading_total)
        wait(0)

        local path = config_dir .. '\\' .. name
        local content, err, size = read_file(path)
        if content then
            local modified = get_modified_text(path)
            local lines, search_lines = split_lines_for_view(content)
            table.insert(new_files, {
                name = name,
                title = display_title_for_file(name),
                path = path,
                size = size or #content,
                modified = modified,
                lines = lines,
                search_lines = search_lines
            })
        elseif err then
            table.insert(new_skipped, name .. ': ' .. err)
        end

        loading_progress = index
        wait(0)
    end

    files = new_files
    skipped_files = new_skipped
    if selected_index > #files then selected_index = 1 end
    loaded_at_text = os.date('%H:%M:%S')
    last_load_message = string.format('Загружено: %d TXT. Папка проверена.', #files)
    set_active_match(1)
    need_rebuild_matches = true
    is_loading = false

    if startup_notice_pending then
        startup_notice_pending = false
        chat('Loaded files: ' .. tostring(#files), CHAT_OK)
    elseif not silent then
        chat('Reloaded files: ' .. tostring(#files), CHAT_INFO)
    end

    if #skipped_files > 0 then
        chat('Skipped files: ' .. tostring(#skipped_files) .. '. Open /infozz for details.', CHAT_WARN)
    end

    if reload_after_loading then
        reload_after_loading = false
        queue_txt_reload(silent)
    end
end

function list_txt_names(dir)
    local result = {}

    if ok_lfs then
        local ok, iter, state, first = pcall(lfs.dir, dir)
        if ok then
            for name in iter, state, first do
                if name:lower():match('%.txt$') then
                    table.insert(result, name)
                end
            end
            return result
        end
    end

    local command = string.format('dir /b "%s\\*.txt" 2>nul', dir)
    local pipe = io.popen(command)
    if pipe then
        for name in pipe:lines() do
            table.insert(result, name)
        end
        pipe:close()
    end

    return result
end

function load_title_overrides()
    local result = {}
    local file = io.open(TITLES_CONFIG_FILE, 'rb')
    if not file then
        result = default_title_overrides()
        save_title_overrides(result)
        return result
    end

    for line in file:lines() do
        local key, value = line:match('^([^=]+)=(.*)$')
        if key and value then
            result[trim(key)] = trim(value)
        end
    end
    file:close()

    local defaults = default_title_overrides()
    local changed = false
    for key, value in pairs(defaults) do
        if result[key] == nil then
            result[key] = value
            changed = true
        end
    end
    if changed then save_title_overrides(result) end

    return result
end

function save_title_overrides(overrides)
    overrides = overrides or title_overrides
    ensure_dir(config_dir)

    local keys = {}
    for key, _ in pairs(overrides) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return a:lower() < b:lower() end)

    local file = io.open(TITLES_CONFIG_FILE, 'wb')
    if not file then return end
    for _, key in ipairs(keys) do
        file:write(key .. '=' .. tostring(overrides[key]) .. '\n')
    end
    file:close()
end

function default_title_overrides()
    return {
        ['administrativnyy_kodeks.txt'] = 'Административный кодекс',
        ['arrest_rules.txt'] = 'Правила ареста',
        ['dopros_rules.txt'] = 'Правила допроса',
        ['frisk_rules.txt'] = 'Правила обыска',
        ['grazhdanskiy_kodeks.txt'] = 'Гражданский кодекс',
        ['neprikosnovennost.txt'] = 'Неприкосновенность',
        ['traffic_stop_rules.txt'] = 'Правила трафик-стопа',
        ['trudovoy_kodeks.txt'] = 'Трудовой кодекс',
        ['ugolovno_processualnyy_kodeks.txt'] = 'Уголовно-процессуальный кодекс',
        ['ugolovnyy_kodeks.txt'] = 'Уголовный кодекс',
        ['ustav.txt'] = 'Устав'
    }
end

function display_title_for_file(name)
    return title_overrides[name] or default_title_from_filename(name)
end

function default_title_from_filename(name)
    local title = name:gsub('%.txt$', ''):gsub('_', ' ')
    return title
end

function read_file(path)
    local file = io.open(path, 'rb')
    if not file then return nil, 'не удалось открыть' end

    local size = file:seek('end') or 0
    if size > MAX_FILE_BYTES then
        file:close()
        return nil, 'слишком большой файл (' .. pretty_bytes(size) .. ')'
    end
    file:seek('set', 0)

    local chunks = {}
    while true do
        local chunk = file:read(READ_CHUNK_BYTES)
        if not chunk then break end
        table.insert(chunks, chunk)
        wait(0)
    end
    file:close()
    local content = table.concat(chunks)
    if not content then return nil, 'не удалось прочитать' end

    content = content:gsub('^\239\187\191', '')
    content = content:gsub('\r\n', '\n'):gsub('\r', '\n')
    return content, nil, size
end

function read_status_file()
    local file = io.open(PYTHON_STATUS_FILE, 'rb')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return content
end

function read_config_update_status()
    local file = io.open(PYTHON_CONFIG, 'rb')
    if not file then return nil end
    local content = file:read('*a')
    file:close()

    local stamp = content:match('"last_update_at"%s*:%s*"([^"]*)"')
    if not stamp or stamp == '' then return nil end

    local success = content:match('"last_success_count"%s*:%s*(%d+)') or '0'
    local total = content:match('"last_total"%s*:%s*(%d+)') or '0'
    local status = content:match('"last_status"%s*:%s*"([^"]*)"') or ''
    return string.format('DONE|%s|%s|%s|%s', stamp, success, total, status)
end

function write_status_file(text)
    ensure_dir(config_dir)
    local file = io.open(PYTHON_STATUS_FILE, 'wb')
    if not file then return false end
    file:write(text)
    file:close()
    return true
end

function split_lines_for_view(text)
    local lines = {}
    local search_lines = {}
    local count = 0

    text = text:gsub('\n$', '')
    for line in (text .. '\n'):gmatch('(.-)\n') do
        table.insert(lines, line)
        table.insert(search_lines, normalize_search_text(line))
        count = count + 1
        if count % 250 == 0 then wait(0) end
    end

    return lines, search_lines
end

function ensure_dir(path)
    if config_dir_ready then return true end

    if ok_lfs and lfs.attributes(path, 'mode') == 'directory' then
        config_dir_ready = true
        return true
    end

    os.execute(string.format('mkdir "%s" >nul 2>nul', path))

    if ok_lfs then
        if lfs.attributes(path, 'mode') ~= 'directory' then
            chat('Config folder was not created: ' .. path, CHAT_ERR)
            return false
        end
        config_dir_ready = true
        return true
    end

    config_dir_ready = true
    return true
end

function buffer_text(buffer)
    return ffi.string(buffer)
end

function trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

function seconds_since_stamp(stamp)
    local y, m, d, h, min, s = stamp:match('^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then return 999999999 end

    local updated = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(min),
        sec = tonumber(s)
    })
    if not updated then return 999999999 end

    local diff = os.time() - updated
    if diff < 0 then diff = 0 end
    return diff
end

function format_age(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes < 1 then return 'только что' end
    if minutes < 60 then return tostring(minutes) .. ' мин назад' end
    local hours = math.floor(minutes / 60)
    if hours < 24 then return tostring(hours) .. ' ч назад' end
    return tostring(math.floor(hours / 24)) .. ' д назад'
end

function get_modified_text(path)
    if ok_lfs then
        local changed = lfs.attributes(path, 'modification')
        if changed then return os.date('%d.%m.%Y %H:%M', changed) end
    end
    return 'дата неизвестна'
end

function pretty_bytes(size)
    size = tonumber(size) or 0
    if size >= 1024 * 1024 then
        return string.format('%.1f MB', size / 1024 / 1024)
    end
    if size >= 1024 then
        return string.format('%.1f KB', size / 1024)
    end
    return tostring(size) .. ' B'
end

function chat(text, color)
    if sampAddChatMessage then
        local message = PREFIX .. ' ' .. tostring(text)
        if u8 then
            local ok, decoded = pcall(function()
                return u8:decode(message)
            end)
            if ok and decoded then
                message = decoded
            end
        end
        sampAddChatMessage(message, color or CHAT_INFO)
    end
end

function normalize_search_text(text)
    for upper, lower in pairs(ru_lower_map) do
        text = text:gsub(upper, lower)
    end
    return text:lower()
end

function escape_lua_pattern(text)
    return (text:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1'))
end

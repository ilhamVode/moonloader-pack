script_name('ModioManager')
script_author('ModioZodio')
script_version('1.0')
script_properties('work-in-pause')

require 'lib.moonloader'

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local dl_status = require('moonloader').download_status
local ok_lfs, lfs = pcall(require, 'lfs')

local new = imgui.new
local window = new.bool(false)

local MANIFEST_URL = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/manifest.json'
local PREFIX = '[ModioManager]'
local CHAT = 0x52C7EA
local OK = 0x77DD77
local WARN = 0xFFD166
local ERR = 0xFF6666

local workdir = getWorkingDirectory()
local config_dir = workdir .. '\\config\\modio_manager'
local tmp_dir = config_dir .. '\\tmp'
local cache_manifest_path = config_dir .. '\\manifest_cache.json'
local imgui_ini_path = config_dir .. '\\imgui.ini'

local selected = 1
local checking = false
local busy = false
local busy_text = ''
local last_check_text = 'Проверка еще не запускалась.'
local last_error = ''
local pending_delete_id = nil
local manifest = {
    schema = 1,
    name = 'ModioZodio MoonLoader Pack',
    owner = 'ModioZodio',
    homepage = 'https://github.com/ilhamVode/moonloader-pack',
    updated_at = '2026-06-13 14:35 MSK',
    notes = 'Менеджер MoonLoader-скриптов для Arizona RP: установка, обновление и удаление прямо из игры без ручного поиска файлов.',
    scripts = {
        {
            id = 'lavaka',
            name = 'Lavaka',
            file = 'lavaka.lua',
            version = '1.0',
            updated_at = '2026-06-13',
            author = 'ModioZodio',
            description = 'Помощник установки лавки через строгую CEF-цепочку без фонового перехвата окон.',
            commands = {
                '/lavaka - включить или выключить помощник установки лавки',
                '/lavakadebug - включить или выключить диагностические сообщения'
            },
            usage = 'Встаньте на место установки лавки и включите /lavaka. Скрипт сам открывает интерактивное меню, выбирает действие установки и выключается после успешной установки или сообщения, что лавка уже стоит.',
            features = {
                'строгая цепочка действий: запрос меню, ожидание CEF-ответа, действие установки, ожидание закрытия окна',
                'адаптивные задержки под игровые ограничения, чтобы не долбиться вслепую в кд',
                'сообщает примерное время установки и сам останавливается после результата'
            },
            notes = 'Фоновый CEF-перехват убран специально: так скрипт не ломает другие CEF-окна игры, например /time.',
            url = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/scripts/lavaka.lua'
        },
        {
            id = 'ctrllkm',
            name = 'CtrlLKM',
            file = 'ctrllkm.lua',
            version = '1.0',
            updated_at = '2026-06-13',
            author = 'ModioZodio',
            description = 'Удерживает Ctrl, флудит ЛКМ и автоматически выключается при ручном нажатии Ctrl или сообщении о легендарном призе.',
            commands = {
                '/ctrllkm - включить или выключить Ctrl + ЛКМ helper'
            },
            usage = 'Запустите командой /ctrllkm. Скрипт удерживает Ctrl и нажимает ЛКМ по циклу. Если вы сами нажмете Ctrl или в чате появится фраза про легендарный приз, скрипт выключится.',
            features = {
                'автоматически прекращает работу при ручном нажатии Ctrl',
                'останавливается по системному сообщению с текстом "и выиграл легендарный приз"',
                'не выводит повторяющиеся подсказки в чат во время работы'
            },
            notes = 'Название и команды приведены к ЛКМ, потому что ПКМ был ошибкой в старой формулировке.',
            url = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/scripts/ctrllkm.lua'
        },
        {
            id = 'fpsfix',
            name = 'FPSFix',
            file = 'FPSFix.lua',
            version = '0.1 alpha',
            updated_at = '2026-06-13',
            author = 'JustFedot / ModioZodio',
            description = 'FPSFix с дополнительными инструментами и встроенным помощником установки лавки.',
            commands = {
                '/fps - открыть окно FPSFix'
            },
            usage = 'Откройте /fps и управляйте функциями через окно. Внутри добавлен раздел Lavaka: можно включать помощник установки лавки, debug-режим и видеть последний результат установки.',
            features = {
                'основное окно FPSFix с настройками',
                'встроенный помощник установки лавки с той же логикой, что и отдельный lavaka.lua',
                'при запуске установки лавки окно закрывается, чтобы не мешать курсору'
            },
            notes = 'Авторская основа FPSFix сохранена, интеграция Lavaka добавлена отдельно и не требует удаления standalone lavaka.lua.',
            url = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/scripts/FPSFix.lua'
        },
        {
            id = 'infozz',
            name = 'InfoZZ',
            file = 'infozz.lua',
            version = '1.7.3',
            updated_at = '2026-06-13',
            author = 'Codex / ModioZodio',
            description = 'TXT-справочник для SA:MP с просмотром файлов, поиском, локальным AI-поиском по загруженным TXT и обновлением базы.',
            commands = {
                '/infozz - открыть справочник'
            },
            usage = 'Откройте окно /infozz, выберите TXT-файл слева и пользуйтесь поиском по базе. Скрипт подходит для хранения подсказок, заметок и справочной информации прямо в игре.',
            features = {
                'просмотр TXT-файлов в игровом окне',
                'поиск по загруженным материалам',
                'локальный AI-поиск по базе без ручного пролистывания больших текстов',
                'обновление списка файлов из интерфейса'
            },
            notes = 'Полезен как внутриигровая база знаний: команды, цены, заметки, инструкции и любые TXT-материалы.',
            url = 'https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/scripts/infozz.lua'
        }
    }
}

local runtime = {}

function ui(text)
    return tostring(text or '')
end

function buttonSize(label, min_width)
    min_width = min_width or 140
    local ok, size = pcall(imgui.CalcTextSize, label)
    if ok and size then
        return imgui.ImVec2(math.max(min_width, size.x + 30), 0)
    end
    return imgui.ImVec2(min_width, 0)
end

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

function main()
    while not isSampAvailable() do wait(0) end

    ensureDir(config_dir)
    ensureDir(tmp_dir)
    loadCachedManifest()
    refreshLocalState()

    sampRegisterChatCommand('modio', function()
        window[0] = not window[0]
        if window[0] then refreshLocalState() end
    end)
    sampRegisterChatCommand('mscripts', function()
        window[0] = not window[0]
        if window[0] then refreshLocalState() end
    end)

    msg('Менеджер скриптов загружен. Окно: /modio или /mscripts', OK)

    while true do
        wait(0)
    end
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
    style.WindowRounding = 8
    style.ChildRounding = 7
    style.FrameRounding = 6
    style.GrabRounding = 6
    style.ScrollbarRounding = 7
    style.WindowPadding = imgui.ImVec2(14, 14)
    style.FramePadding = imgui.ImVec2(10, 7)
    style.ItemSpacing = imgui.ImVec2(9, 8)

    local c = style.Colors
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.075, 0.085, 0.105, 1.00)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.105, 0.120, 0.150, 1.00)
    c[imgui.Col.Border] = imgui.ImVec4(0.230, 0.280, 0.360, 0.80)
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.145, 0.175, 0.230, 1.00)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.190, 0.250, 0.330, 1.00)
    c[imgui.Col.FrameBgActive] = imgui.ImVec4(0.220, 0.300, 0.410, 1.00)
    c[imgui.Col.Button] = imgui.ImVec4(0.145, 0.260, 0.450, 1.00)
    c[imgui.Col.ButtonHovered] = imgui.ImVec4(0.190, 0.350, 0.610, 1.00)
    c[imgui.Col.ButtonActive] = imgui.ImVec4(0.100, 0.210, 0.380, 1.00)
    c[imgui.Col.Header] = imgui.ImVec4(0.150, 0.240, 0.370, 1.00)
    c[imgui.Col.HeaderHovered] = imgui.ImVec4(0.190, 0.320, 0.500, 1.00)
    c[imgui.Col.HeaderActive] = imgui.ImVec4(0.120, 0.230, 0.400, 1.00)
    c[imgui.Col.Text] = imgui.ImVec4(0.930, 0.950, 0.980, 1.00)
    c[imgui.Col.TextDisabled] = imgui.ImVec4(0.560, 0.610, 0.680, 1.00)
end

function drawHeader()
    imgui.TextColored(imgui.ImVec4(0.380, 0.680, 1.000, 1.00), ui(manifest.name or 'ModioZodio MoonLoader Pack'))
    imgui.TextDisabled(ui('Последнее обновление на сайте: ' .. tostring(manifest.updated_at or '-')))

    imgui.TextDisabled(ui('Manifest: ' .. MANIFEST_URL))
    if manifest.notes and #manifest.notes > 0 then
        imgui.TextWrapped(ui(manifest.notes))
    end

    if busy or checking then
        imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.35, 1.00), ui(busy_text ~= '' and busy_text or 'Идет операция...'))
    else
        imgui.TextDisabled(ui(last_check_text))
    end

    if last_error ~= '' then
        imgui.TextColored(imgui.ImVec4(1.00, 0.35, 0.35, 1.00), ui(last_error))
    end

    local check_size = buttonSize(ui 'Проверить обновления', 220)
    if imgui.Button(ui 'Проверить обновления', check_size) then
        checkRemoteManifest()
    end
    local local_status_size = buttonSize(ui 'Обновить локальный статус', 260)
    sameLineIfFits(local_status_size.x)
    if imgui.Button(ui 'Обновить локальный статус', local_status_size) then
        refreshLocalState()
    end
    local reload_size = buttonSize(ui 'Перезагрузить Lua', 190)
    sameLineIfFits(reload_size.x)
    if imgui.Button(ui 'Перезагрузить Lua', reload_size) then
        reloadScripts()
    end
end

function drawScriptList()
    imgui.TextDisabled(ui 'Скрипты')
    imgui.Separator()

    local list = manifest.scripts or {}
    for i, item in ipairs(list) do
        local st = runtime[item.id] or inspectLocal(item)
        local marker = '[ ]'
        if st.installed then
            marker = st.outdated and '[!]' or '[✓]'
        end

        local label = string.format('%s %s##script_%s', marker, item.name or item.id, item.id)
        if imgui.Selectable(ui(label), selected == i, 0, imgui.ImVec2(0, 34)) then
            selected = i
        end
        imgui.TextDisabled(ui(statusLine(item, st)))
    end
end

function drawDetails()
    local item = (manifest.scripts or {})[selected]
    if not item then
        imgui.TextDisabled(ui 'Скриптов в манифесте нет.')
        return
    end

    local st = runtime[item.id] or inspectLocal(item)
    local title = ui(item.name or item.id)
    local filename = ui(item.file or '-')
    imgui.TextColored(imgui.ImVec4(0.700, 0.850, 1.000, 1.00), title)
    sameLineIfFits(textWidth(filename) + 8)
    imgui.TextDisabled(filename)

    imgui.Separator()
    infoRow('Автор', item.author or '-')
    infoRow('Локальная версия', st.installed and st.local_version or 'не установлен')
    infoRow('Версия на сайте', item.version or '-')
    infoRow('Последнее обновление на сайте', item.updated_at or '-')

    imgui.Spacing()
    drawStatusBadge(st)
    imgui.Spacing()

    local canInstall = not st.installed and not busy
    local canUpdate = st.installed and st.outdated and not busy
    local canDelete = st.installed and not busy

    local install_size = buttonSize(ui 'Установить', 170)
    if imgui.Button(ui 'Установить', install_size) then
        if canInstall then
            installOrUpdate(item, 'install')
        else
            msg('Установка недоступна для выбранного скрипта.', WARN)
        end
    end

    local update_size = buttonSize(ui 'Обновить', 170)
    sameLineIfFits(update_size.x)
    if imgui.Button(ui 'Обновить', update_size) then
        if canUpdate then
            installOrUpdate(item, 'update')
        else
            msg('Обновление не требуется или сейчас идет другая операция.', WARN)
        end
    end

    local delete_size = buttonSize(ui 'Удалить', 170)
    sameLineIfFits(delete_size.x)
    if imgui.Button(ui 'Удалить', delete_size) then
        if canDelete then
            pending_delete_id = item.id
        else
            msg('Удаление недоступно для выбранного скрипта.', WARN)
        end
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
    else
        imgui.TextColored(imgui.ImVec4(0.35, 1.00, 0.58, 1.00), ui 'Статус: установлена последняя версия')
    end
end

function statusLine(item, st)
    if not st.installed then
        return 'не установлен | сайт: ' .. tostring(item.version or '-')
    end
    if st.outdated then
        return 'локально: ' .. st.local_version .. ' | сайт: ' .. tostring(item.version or '-')
    end
    return 'последняя версия: ' .. st.local_version
end

function checkRemoteManifest()
    if checking or busy then return end
    checking = true
    busy_text = 'Проверяю манифест...'
    last_error = ''

    local tmp = tmp_dir .. '\\manifest_' .. os.time() .. '.json'
    downloadUrlToFile(MANIFEST_URL, tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            checking = false
            busy_text = ''
            local ok, err = loadManifestFromFile(tmp, true)
            os.remove(tmp)
            if ok then
                saveManifestCache()
                refreshLocalState()
                last_check_text = 'Последняя проверка: ' .. os.date('%d.%m.%Y %H:%M:%S')
                msg('Манифест обновлен.', OK)
            else
                last_error = err or 'Не удалось прочитать manifest.json'
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

    downloadUrlToFile(item.url, tmp, function(id, status)
        if status == dl_status.STATUSEX_ENDDOWNLOAD then
            if doesFileExist(tmp) then
                if doesFileExist(target) then os.remove(target) end
                local ok, err = os.rename(tmp, target)
                busy = false
                busy_text = ''
                if ok then
                    refreshLocalState()
                    msg((mode == 'install' and 'Установлен: ' or 'Обновлен: ') .. item.name, OK)
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

    local ok, err = os.remove(path)
    if ok then
        refreshLocalState()
        msg('Удален: ' .. tostring(item.name or item.file), WARN)
    else
        last_error = 'Не удалось удалить файл: ' .. tostring(err)
        msg(last_error, ERR)
    end
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
    local outdated = installed and remote_version ~= '' and tostring(local_version or '') ~= remote_version

    return {
        installed = installed,
        local_version = local_version or 'неизвестно',
        outdated = outdated,
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

function loadCachedManifest()
    if doesFileExist(cache_manifest_path) then
        loadManifestFromFile(cache_manifest_path, false)
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

function ensureDir(path)
    if not doesDirectoryExist(path) then
        createDirectory(path)
    end
end

function msg(text, color)
    sampAddChatMessage(PREFIX .. ' {FFFFFF}' .. u8:decode(tostring(text)), color or CHAT)
end

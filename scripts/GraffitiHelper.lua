if script_name then
    script_name('GraffitiHelper')
    script_author('ModioZodio')
    script_version('1.0.0')
end

local Core = {}
Core.gangs = {
    {id = 'grove', name = 'Grove Street', aliases = {'grove', 'groove'}},
    {id = 'ballas', name = 'Ballas', aliases = {'ballas'}},
    {id = 'vagos', name = 'Los Santos Vagos', aliases = {'vagos'}},
    {id = 'aztecas', name = 'Varrios Los Aztecas', aliases = {'aztecas'}},
    {id = 'rifa', name = 'The Rifa', aliases = {'rifa'}},
    {id = 'wolves', name = 'Night Wolves', aliases = {'wolves', 'night wolf'}}
}

Core.phoenixCoordinates = {
    [1]={1850.007812,-1876.897949,14.359398}, [2]={2203.816895,-1966.913086,13.935144},
    [4]={2353.472168,-1508.226929,24.750000}, [5]={2536.280762,-1352.765625,31.085899},
    [6]={2542.881104,-1363.242188,31.765600}, [7]={2767.853271,-1621.187500,11.234398},
    [8]={2839.412354,-1478.387329,12.096929}, [9]={2797.917236,-1097.630859,31.062500},
    [10]={2271.305664,-1099.122070,38.476021}, [11]={2281.543213,-1118.968994,27.021938},
    [12]={2234.015137,-1367.617188,24.531300}, [13]={2346.515625,-1350.853271,24.281300},
    [14]={2322.491699,-1254.459839,22.903177}, [15]={2182.230713,-1467.846191,25.578148},
    [16]={2404.397705,-1499.503784,24.510912}, [17]={2394.101562,-1468.429199,24.781300},
    [18]={2399.438965,-1551.985962,28.790815}, [20]={2522.398926,-1478.742188,24.164101},
    [3]={2422.848303,-1682.297032,13.990000}, [19]={2462.265625,-1541.466064,25.421900},
    [21]={2747.679932,-1187.725830,69.887329}, [22]={2766.147949,-1197.140625,69.070297},
    [23]={2755.914795,-1388.123901,39.460899}, [24]={2767.765137,-1820.013916,12.260919},
    [25]={2794.531250,-1906.750488,14.671898}, [26]={2874.572021,-1909.382812,8.390600},
    [27]={2763.062012,-2012.088379,14.132800}, [28]={2704.298584,-2144.304688,11.820300},
    [29]={2704.257324,-1966.687500,13.757800}, [30]={2640.897949,-2022.409546,13.881960},
    [31]={2553.500488,-1939.648926,4.496775}, [32]={2475.093018,-1747.038940,14.016424},
    [33]={2519.968262,-1715.520142,14.159224}, [34]={2273.015625,-1687.491699,14.968798},
    [35]={2162.751465,-1786.153442,14.247994}, [37]={2034.435181,-1801.742798,14.646441},
    [36]={2110.072510,-1790.985596,14.036344}, [40]={1950.678833,-2034.445435,14.106645},
    [42]={1889.180176,-1982.507812,15.757800}, [45]={2074.117649,-1579.148678,14.030000},
    [38]={1808.395752,-2092.265381,14.218798}, [39]={1927.258301,-2121.448486,13.992959},
    [41]={1928.971436,-1979.076416,14.068993}, [43]={1918.552002,-1786.443970,14.353090},
    [44]={1959.315186,-1577.723755,13.811652}, [46]={2102.133301,-1648.757812,13.585900},
    [47]={2066.501709,-1652.476562,14.281298}, [48]={2046.354248,-1635.843750,13.585900},
    [49]={2241.301270,-1722.385376,14.066567}, [51]={1732.681885,-963.103638,41.437500},
    [50]={1966.945313,-1174.798584,20.039101}, [54]={1969.531980,-1289.695260,24.560000},
    [52]={1746.750000,-1359.711426,16.210899}, [53]={1974.085938,-1351.216064,24.562500},
    [55]={2119.203125,-1196.534180,24.632799}, [56]={2224.746826,-1193.142944,25.835899},
    [57]={2335.082764,-1318.743408,24.821077}, [58]={1904.688477,-1450.939819,14.300081},
    [59]={2621.528076,-1092.283081,69.796898}, [60]={2820.354980,-1190.897583,25.671900},
    [61]={2687.540039,-1101.277832,69.946617}, [62]={2486.641846,-1321.617310,39.070305},
    [63]={2401.008789,-2059.272705,14.136402}, [64]={2652.968018,-1542.518555,23.149090},
    [65]={2527.334229,-1663.462402,15.529331}, [66]={2437.684570,-1219.173462,25.938787},
    [67]={2381.064941,-1186.792236,28.058123}, [68]={2576.782959,-1143.327515,48.224190},
    [69]={1941.447266,-1034.747681,24.662603}, [70]={2580.930420,-1444.142578,24.628147},
    [71]={2195.635010,-1834.974609,13.526550}, [72]={2308.822510,-1634.731201,15.117351},
    [73]={2188.253418,-1884.463379,13.849873}, [74]={2625.418457,-1629.020020,19.948023},
    [75]={2197.609375,-1494.813599,24.482191}, [76]={2323.737305,-1956.464722,14.043968},
    [77]={2497.500000,-1977.938354,13.810752}, [78]={2428.518066,-1884.467407,14.227437},
    [79]={2420.957520,-1391.033081,25.082001}, [80]={1991.613159,-1988.788940,13.753247}
}


Core.coordinateTolerance = 0.75
Core.graffitiTextures = {
    ['hud:radar_gangg'] = true, ['hud:radar_gangb'] = true,
    ['hud:radar_gangy'] = true, ['hud:radar_gangn'] = true,
    ['hud:radar_tattoo'] = true
}
Core.expectedPhoenixMarkers = 80



Core.phoenixTextdrawFirst = 2097
Core.phoenixTextdrawLast = 2176
Core.textdrawMappingVersion = 3

function Core.coordinate(id)
    local point = Core.phoenixCoordinates[tonumber(id)]
    if not point then return nil end
    return {x = point[1], y = point[2], z = point[3], interior = 0,
        provisional = point[4] == true, source = point[4] and 'embedded-provisional' or 'embedded'}
end

function Core.nearestCoordinate(position, radius)
    local found, best = nil, radius or Core.coordinateTolerance
    for id, point in pairs(Core.phoenixCoordinates) do
        local dx, dy = position.x - point[1], position.y - point[2]
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= best then found, best = id, distance end
    end
    return found, best
end

function Core.clean(value)
    return (tostring(value or ''):gsub('{%x%x%x%x%x%x%x%x}', '')
        :gsub('{%x%x%x%x%x%x}', ''):gsub('~n~', '\n'):gsub('~[%a]~', '')
        :gsub('<[bB][rR]%s*/?>', '\n'):gsub('</[pP]>', '\n'):gsub('<[^>]*>', '')
        :gsub('&nbsp;', ' '):gsub('\194\160', ' '):gsub('\r', '')
        :gsub('^[%s%-]+', ''):gsub('%s+$', ''))
end

function Core.lower(s)
    local upper, lower = 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ', 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
    s = s:lower()
    for i = 1, #upper, 2 do s = s:gsub(upper:sub(i, i + 1), lower:sub(i, i + 1)) end
    return s
end

function Core.gang(name)
    local s = Core.lower(Core.clean(name))
    for _, gang in ipairs(Core.gangs) do
        if s == gang.id then return gang.id end
        for _, alias in ipairs(gang.aliases) do
            if s:find(alias, 1, true) then return gang.id end
        end
    end
end

function Core.gangName(id)
    for _, gang in ipairs(Core.gangs) do if gang.id == id then return gang.name end end
end

function Core.organization(text)
    local name = Core.clean(text):match('Организация:%s*%[([^%]\n]+)%]')
        or Core.clean(text):match('Организация:%s*([^\n]+)')
    if name then return Core.gang(name), Core.clean(name) end
end

function Core.status(status)
    local s = Core.lower(Core.clean(status)):gsub('[%.!]+$', '')
    local availability = 'unknown'
    if s:find('недоступ', 1, true) or s:find('не доступ', 1, true)
        or s:find('будет через', 1, true) or s:find('можно через', 1, true)
        or s:find('нельзя', 1, true) then
        availability = 'blocked'
    elseif s == 'доступно' or s == 'доступно для перекраски' or s == 'доступно для закраски'
        or s == 'можно перекрасить' then
        availability = 'available'
    elseif s:find('повторно закрасить можно', 1, true) then
        availability = 'available'
    end
    local seconds = 0
    for _, unit in ipairs({{'дн', 86400}, {'час', 3600}, {'мин', 60}, {'сек', 1}}) do
        local value = s:match('(%d+)%s*' .. unit[1])
        if value then seconds = seconds + tonumber(value) * unit[2] end
    end
    return availability, seconds > 0 and seconds or nil
end

function Core.parse(text, now)
    local clean = Core.clean(text)
    local id = clean:match('Граффити%s*№%s*(%d+)') or clean:match('Граффити%s*#%s*(%d+)')
    local owner = clean:match('Принадлежит:%s*([^\n]+)')
    local status = clean:match('Статус доступности:%s*([^\n]+)')
    if not id or not owner or not status then return nil end
    owner, status = Core.clean(owner), Core.clean(status)
    local availability, seconds = Core.status(status)
    return {id = tonumber(id), owner = owner, ownerGang = Core.gang(owner),
        availability = availability, statusText = status, observedAt = now,
        estimatedAvailableAt = seconds and now + seconds or nil}
end

function Core.parseWorldGraffiti(text, now)
    local clean = Core.clean(text)
    local owner = clean:match('[БB]анда:%s*([^\n]+)') or clean:match('[Gg]ang:%s*([^\n]+)')
    local status = clean:match('([Пп]овторно%s+закрасить%s+можно[^\n]*)')
        or clean:match('([Rr]epaint[^\n]*)') or clean:match('([Cc]an%s+repaint[^\n]*)')
    if not owner or not status then return nil end
    owner, status = Core.clean(owner), Core.clean(status)
    local availability, seconds = Core.status(status)
    return {owner = owner, ownerGang = Core.gang(owner), statusText = status,
        availability = availability, observedAt = now,
        estimatedAvailableAt = seconds and now + seconds or nil, sourceText = clean}
end

function Core.eligibility(record, organization, session, now)
    if record.session ~= session or now - record.observedAt > 300 then return 'stale' end
    if organization and record.ownerGang == organization then return 'own' end
    if record.availability == 'blocked' then return 'blocked' end
    if not organization or not record.ownerGang then return 'unknown' end
    return record.availability
end

function Core.signature(td)
    if not td or (td.selectable ~= 1 and td.selectable ~= true) then return nil end
    if td.style ~= 4 and td.style ~= 5 then return nil end
    local width, height = math.abs(td.lineWidth or 0), math.abs(td.lineHeight or 0)
    if width <= 0 or height <= 0 then return nil end
    return {style = td.style, width = width, height = height}
end

function Core.matches(td, signature, bounds)
    local s = Core.signature(td)
    local p = td and td.position
    return s and signature and p and s.style == signature.style
        and math.abs(s.width - signature.width) < 0.1
        and math.abs(s.height - signature.height) < 0.1
        and p.x >= bounds[1] and p.y >= bounds[2] and p.x <= bounds[3] and p.y <= bounds[4]
end

function Core.isGraffitiMarker(td, bounds)
    local s, p = Core.signature(td), td and td.position
    local texture = s and Core.lower(Core.clean(td.text)) or ''
    return s and p and Core.graffitiTextures[texture]
        and s.style == 4 and math.abs(s.width - 9) < 0.1 and math.abs(s.height - 11) < 0.1
        and p.x >= bounds[1] and p.y >= bounds[2] and p.x <= bounds[3] and p.y <= bounds[4]
end


function Core.scanner(queue, now)
    return {queue = queue, index = 0, phase = 'next', due = now, deadline = 0, done = 0,
        duplicates = 0, seen = {}, deferred = {}, pass = 1}
end


function Core.restartMissing(scan, queue, now)
    scan.queue, scan.index, scan.phase = queue, 0, 'next'
    scan.due, scan.deadline, scan.current = now, 0, nil
    scan.pass = (scan.pass or 1) + 1
    return scan
end

function Core.deferTimedOut(scan, now)
    scan.deferred[scan.current.id] = scan.current
    scan.phase, scan.due, scan.deadline, scan.current = 'next', now, 0, nil
end

function Core.tick(scan, now, valid)
    if not scan then return end
    if scan.phase == 'waiting' then
        if now >= scan.deadline then return 'timeout' end
        return
    end
    if scan.phase ~= 'next' or now < scan.due then return end
    if scan.index == #scan.queue then return 'complete' end
    local item = scan.queue[scan.index + 1]
    if not valid(item) then return 'changed' end
    scan.index = scan.index + 1

    scan.current, scan.phase, scan.due, scan.deadline = item, 'waiting', now, now + 1200
    return 'click', item.id
end

function Core.response(scan, record, now)
    if not scan or scan.phase ~= 'waiting' then return false end
    if scan.seen[record.id] then

        scan.duplicates, scan.due = scan.duplicates + 1, now + 50
        return 'duplicate'
    end
    local reboundFrom
    if scan.current.expectedGraffitiId and record.id ~= scan.current.expectedGraffitiId then

        reboundFrom = scan.current.expectedGraffitiId
        scan.current.expectedGraffitiId = record.id
        scan.current.reboundFrom = reboundFrom
    end
    scan.seen[record.id] = true
    scan.deferred[scan.current.id] = nil

    scan.done, scan.phase, scan.due = scan.done + 1, 'next', now
    return reboundFrom and 'rebound' or 'accepted'
end

if not script_name then return Core end

require 'lib.moonloader'
local events = require 'samp.events'
local encoding = require 'encoding'
local keys = require 'vkeys'
local okFa, fa = pcall(require, 'fAwesome6')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local imgui = require 'mimgui'
local window = imgui.new.bool(false)
local faFontMerged = false
local windowTarget, windowAlpha, windowAnimClock = false, 0.0, os.clock()
local organizationChoice = imgui.new.int(0)
local gangLabels = {'Авто: /stats'}
for _, gang in ipairs(Core.gangs) do gangLabels[#gangLabels + 1] = gang.name end
local labels = imgui.new['const char*'][#gangLabels](gangLabels)
local root = getWorkingDirectory() .. '\\config\\GraffitiHelper'
local db, dbPath, profileKey, session = nil, nil, nil, nil
local textdraws, generation, scan = {}, 0, nil
local dirty = false
local radarBlips = {}
local routeBlip, routeCheckpoint, routeTarget = nil, nil, nil
local autoGang, autoName, readyAt, statsSent = nil, nil, nil, false
local statsDeadline, lastSave, nextRadarRefresh, nextPlayerPositionRefresh = 0, 0, 0, 0

local playerPosition = {x = 0, y = 0}
local lastStatus = 'Откройте карту граффити и запустите сканирование.'
local sessionNonce = tostring(os.time()) .. '-' .. tostring(math.random(100000, 999999))
local bounds = {90, 10, 639, 440}

local save, stop, ingest, command, refreshRadar, clearRadar, organization, clearRoute, setRoute, nearestAvailable, updateRoute
local setWindowOpen, updateWindowAnimation

local function uiIcon(name, fallback)
    if okFa and fa then
        local ok, icon = pcall(function() return fa(name) end)
        if ok and type(icon) == 'string' and icon ~= '' then return icon end
    end
    return fallback or ''
end

local function noOuterScrollFlags(flags)
    local windowFlags = imgui.WindowFlags or {}
    local noScrollbar = windowFlags.NoScrollbar or 8
    local noScrollWithMouse = windowFlags.NoScrollWithMouse or 16
    return (flags or 0) + noScrollbar + noScrollWithMouse
end

local function scanSummary(scan)
    local unique, missing = {}, {}
    for id in pairs(scan.seen) do unique[#unique + 1] = id end
    table.sort(unique)
    for id = 1, Core.expectedPhoenixMarkers do
        if not scan.seen[id] then missing[#missing + 1] = id end
    end
    return unique, missing
end

local function scanAvailableCount(scan)
    local available = 0
    for id in pairs(scan.seen) do
        local record = db and db.graffiti[tostring(id)]
        if record and Core.eligibility(record, organization(), session, os.time()) == 'available' then
            available = available + 1
        end
    end
    return available
end

local function cooldownText(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if hours > 0 then return ('%d ч %d мин'):format(hours, minutes) end
    if minutes > 0 then return ('%d мин'):format(minutes) end
    return 'меньше минуты'
end

local knownGraffitiForTextdraw
local function missingMarkerQueue()
    local mapped, queue = {}, {}
    for _, record in pairs(db.graffiti) do
        if record.session == session and record.textdraw and record.textdraw.id then
            mapped[record.textdraw.id] = true
        end
    end
    for id, td in pairs(textdraws) do
        if not mapped[id] and Core.isGraffitiMarker(td, bounds) then
            queue[#queue + 1] = {id = id, td = td, generation = td.generation,
                expectedGraffitiId = knownGraffitiForTextdraw(id)}
        end
    end
    table.sort(queue, function(a, b) return a.id < b.id end)
    return queue
end

knownGraffitiForTextdraw = function(textdrawId)
    if not db then return nil end
    for id, record in pairs(db.graffiti) do
        if record.textdraw and record.textdraw.id == textdrawId then return tonumber(id) end
    end
    return nil
end

local function mapMarkerQueue()
    local queue, present, lowest, highest = {}, {}, nil, nil
    for id, td in pairs(textdraws) do
        if Core.isGraffitiMarker(td, bounds) then
            present[id] = true
            lowest = not lowest and id or math.min(lowest, id)
            highest = not highest and id or math.max(highest, id)
            queue[#queue + 1] = {id = id, td = td, generation = td.generation,
                expectedGraffitiId = knownGraffitiForTextdraw(id)}
        end
    end

    if #queue >= 60 and highest - lowest < Core.expectedPhoenixMarkers then
        local first = lowest
        for id = first, first + Core.expectedPhoenixMarkers - 1 do
            if not present[id] then
                queue[#queue + 1] = {id = id, inferred = true,
                    expectedGraffitiId = knownGraffitiForTextdraw(id)}
            end
        end
    end
    table.sort(queue, function(a, b) return a.id < b.id end)
    return queue
end

local function finalRetryQueue(scan)
    local queue, queued = missingMarkerQueue(), {}
    for _, item in ipairs(queue) do queued[item.id] = true end
    for id, item in pairs(scan.deferred) do
        if not queued[id] then queue[#queue + 1], queued[id] = item, true end
    end
    table.sort(queue, function(a, b) return a.id < b.id end)
    return queue
end

local function deferredIdText(scan)
    local ids = {}
    for id in pairs(scan.deferred) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids > 12 then
        local shown = {}
        for i = 1, 12 do shown[i] = ids[i] end
        return table.concat(shown, ', ') .. ' … (' .. tostring(#ids) .. ' всего)'
    end
    return table.concat(ids, ', ')
end

local function ms() return getGameTimer() end
local function message(text)
    lastStatus = text
    sampAddChatMessage(u8:decode('[Graffiti] ' .. text), 0x8DE7D4)
end
local function fromSamp(text) return u8(text or '') end
organization = function() return db and db.manualGang or autoGang end

setWindowOpen = function(open)
    windowTarget = open == true
    if windowTarget then window[0] = true end
end

updateWindowAnimation = function()
    local now = os.clock()
    local delta = math.max(0, now - windowAnimClock)
    windowAnimClock = now
    local target = windowTarget and 1.0 or 0.0
    local duration = windowTarget and 0.16 or 0.20
    local step = duration > 0 and delta / duration or 1.0
    if target > windowAlpha then windowAlpha = math.min(target, windowAlpha + step)
    elseif target < windowAlpha then windowAlpha = math.max(target, windowAlpha - step) end
    if not windowTarget and windowAlpha <= 0.01 then windowAlpha, window[0] = 0.0, false end
    return windowAlpha
end

function onWindowMessage(msg, wparam)
    if msg == 0x0100 and wparam == keys.VK_ESCAPE and window[0] then
        if windowTarget then setWindowOpen(false) end
        consumeWindowMessage(true, true)
    end
end
local function coordinateFor(id)
    return Core.coordinate(id)
end


local function applyGraffitiStyle()
    local style = imgui.GetStyle()
    style.Alpha = 0.985
    style.WindowRounding, style.ChildRounding, style.FrameRounding = 14, 12, 10
    style.PopupRounding, style.ScrollbarRounding = 12, 12
    style.WindowBorderSize, style.ChildBorderSize, style.FrameBorderSize = 1, 1, 0
    style.WindowPadding, style.FramePadding = imgui.ImVec2(20, 18), imgui.ImVec2(13, 9)
    style.ItemSpacing, style.ItemInnerSpacing, style.ScrollbarSize = imgui.ImVec2(10, 10), imgui.ImVec2(8, 7), 13
    local c = style.Colors
    c[imgui.Col.WindowBg] = imgui.ImVec4(0.043, 0.055, 0.075, 0.975)
    c[imgui.Col.ChildBg] = imgui.ImVec4(0.071, 0.091, 0.118, 0.94)
    c[imgui.Col.Border] = imgui.ImVec4(0.235, 0.365, 0.405, 0.55)
    c[imgui.Col.FrameBg] = imgui.ImVec4(0.105, 0.137, 0.165, 0.94)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.138, 0.193, 0.216, 0.98)
    c[imgui.Col.FrameBgActive] = imgui.ImVec4(0.152, 0.257, 0.270, 1.00)
    c[imgui.Col.TitleBg] = imgui.ImVec4(0.036, 0.050, 0.069, 0.99)
    c[imgui.Col.TitleBgActive] = imgui.ImVec4(0.064, 0.122, 0.145, 0.99)
    c[imgui.Col.Separator] = imgui.ImVec4(0.225, 0.410, 0.435, 0.45)
    c[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.032, 0.044, 0.060, 0.58)
    c[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.190, 0.355, 0.385, 0.78)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.255, 0.510, 0.525, 0.92)
    c[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.320, 0.660, 0.665, 1.00)
    c[imgui.Col.CheckMark] = imgui.ImVec4(0.400, 0.920, 0.820, 1.00)
    c[imgui.Col.Text] = imgui.ImVec4(0.932, 0.958, 0.965, 1.00)
    c[imgui.Col.TextDisabled] = imgui.ImVec4(0.560, 0.655, 0.690, 1.00)
end

local function animatedColor(color)
    local alpha = math.max(0, math.min(1, windowAlpha or 1))
    return imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color.x, color.y, color.z, color.w * alpha))
end

local function managerLikeButton(label, size, variant, idSuffix)
    local pos, draw = imgui.GetCursorScreenPos(), imgui.GetWindowDrawList()
    local clicked = imgui.InvisibleButton('##graffiti_button_' .. label .. '_' .. tostring(idSuffix or ''), size)
    local hovered, active = imgui.IsItemHovered(), imgui.IsItemActive()
    local bg, border
    if variant == 'danger' then
        bg = active and imgui.ImVec4(0.42, 0.10, 0.11, 0.96)
            or hovered and imgui.ImVec4(0.66, 0.20, 0.21, 0.92)
            or imgui.ImVec4(0.50, 0.15, 0.16, 0.82)
        border = imgui.ImVec4(0.95, 0.42, 0.38, hovered and 0.62 or 0.38)
    elseif variant == 'route' then
        bg = active and imgui.ImVec4(0.55, 0.35, 0.05, 0.98)
            or hovered and imgui.ImVec4(0.86, 0.58, 0.10, 0.96)
            or imgui.ImVec4(0.68, 0.43, 0.07, 0.88)
        border = imgui.ImVec4(1.00, 0.78, 0.28, hovered and 0.75 or 0.48)
    elseif variant == 'routeSecondary' then
        bg = active and imgui.ImVec4(0.07, 0.25, 0.40, 0.98)
            or hovered and imgui.ImVec4(0.10, 0.40, 0.62, 0.96)
            or imgui.ImVec4(0.06, 0.20, 0.32, 0.88)
        border = imgui.ImVec4(0.34, 0.72, 1.00, hovered and 0.75 or 0.46)
    else
        bg = active and imgui.ImVec4(0.070, 0.330, 0.340, 0.98)
            or hovered and imgui.ImVec4(0.145, 0.540, 0.535, 0.94)
            or imgui.ImVec4(0.095, 0.415, 0.425, 0.84)
        border = imgui.ImVec4(0.380, 0.840, 0.790, hovered and 0.65 or 0.38)
    end
    draw:AddRectFilled(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), animatedColor(bg), 8, 15)
    draw:AddRect(pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y), animatedColor(border), 8, 15, 1.0)
    local textSize = imgui.CalcTextSize(label)
    local iconOnlyOffset = size.x <= 40 and 1 or -1
    draw:AddText(imgui.ImVec2(pos.x + (size.x - textSize.x) / 2, pos.y + (size.y - textSize.y) / 2 + iconOnlyOffset),
        animatedColor(imgui.ImVec4(0.950, 1.000, 0.985, 1.00)), label)
    return clicked
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    io.IniFilename = nil
    applyGraffitiStyle()
    local font = getFolderPath(0x14) .. '\\arial.ttf'
    local baseFont = nil
    if doesFileExist(font) then
        baseFont = io.Fonts:AddFontFromFileTTF(font, 16, nil, io.Fonts:GetGlyphRangesCyrillic())
        io.FontDefault = baseFont
    end
    if not faFontMerged and okFa and fa and fa.get_font_data_base85 then
        local cfg = imgui.ImFontConfig()
        cfg.MergeMode, cfg.PixelSnapH = true, true

        cfg.DstFont = baseFont or io.FontDefault
        local new = imgui.new
        local ranges = new.ImWchar[3](fa.min_range, fa.max_range, 0)
        io.Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 14.0, cfg, ranges)
        faFontMerged = true
    end
end)

local function removeNonFiniteNumbers(value, visited)
    if type(value) ~= 'table' then return 0 end
    visited = visited or {}
    if visited[value] then return 0 end
    visited[value] = true
    local removed = 0
    for key, child in pairs(value) do
        if type(child) == 'number' then

            if child ~= child or child == math.huge or child == -math.huge then
                value[key] = nil
                removed = removed + 1
            end
        elseif type(child) == 'table' then
            removed = removed + removeNonFiniteNumbers(child, visited)
        end
    end
    return removed
end

save = function()
    if not db or not dbPath then return end
    lastSave = ms()
    local removed = removeNonFiniteNumbers(db)
    local ok, json = pcall(encodeJson, db)
    if not ok or type(json) ~= 'string' then
        message('Не удалось сериализовать базу: запись отменена, предыдущий файл сохранён.')
        return
    end
    if removed > 0 then message(('Из базы убрано некорректных чисел: %d.'):format(removed)) end

    local f = io.open(dbPath .. '.tmp', 'wb')
    if not f then message('Не удалось открыть файл базы.'); return end
    local written = f:write(json)
    local closed = f:close()
    if not written or not closed then message('Не удалось записать базу.'); return end
    os.remove(dbPath .. '.bak')
    local old = io.open(dbPath, 'rb')
    if old then
        old:close()
        if not os.rename(dbPath, dbPath .. '.bak') then message('Не удалось сохранить резервную копию.'); return end
    end
    if not os.rename(dbPath .. '.tmp', dbPath) then
        os.rename(dbPath .. '.bak', dbPath)
        message('Не удалось заменить базу.'); return
    end
    dirty, lastSave = false, ms()
end

stop = function(reason)
    if scan and db and db.lastScan then
        db.lastScan.collected = scan.done
        db.lastScan.duplicates = scan.duplicates
        db.lastScan.uniqueIds, db.lastScan.missingIds = scanSummary(scan)
        db.lastScan.stopReason = reason
        dirty = true
    end
    scan = nil
    if reason then message(reason) end
    if dirty then save() end
end

local function snapshot(td)
    return {text = fromSamp(td.text), style = td.style, selectable = td.selectable,
        lineWidth = td.lineWidth, lineHeight = td.lineHeight, modelId = td.modelId,
        letterColor = td.letterColor, position = td.position and {x = td.position.x, y = td.position.y},
        generation = td.generation}
end

local function chooseGang(index)
    if not db then return end
    organizationChoice[0] = index
    db.manualGang = index > 0 and Core.gangs[index].id or nil
    dirty = true
    refreshRadar()
    if index == 0 then statsSent, readyAt = false, ms() end
end

ingest = function(text, transport)
    if not db then return end
    local detected, name = Core.organization(text)
    if name then
        if name ~= autoName then
            autoGang, autoName = detected, name
            message('Организация из статистики: ' .. name)
        end
        statsDeadline = 0
    end
    local record = Core.parse(text, os.time())
    if not record then return end

    if scan and scan.phase ~= 'waiting' then return end
    local source = scan and scan.phase == 'waiting' and scan.current or nil
    if scan and scan.phase == 'waiting' then
        local result = Core.response(scan, record, ms())
        if result == 'duplicate' then
            if db.lastScan then
                db.lastScan.collected, db.lastScan.duplicates = scan.done, scan.duplicates
                dirty = true
            end
            return
        elseif result ~= 'accepted' and result ~= 'rebound' then
            stop('Ответ карточки получен вне очереди. Обход остановлен.'); return
        end
    end
    record.transport, record.session = transport, session
    local previous = db.graffiti[tostring(record.id)]
    if previous then record.textdraw = previous.textdraw end
    record.coordinates = coordinateFor(record.id)
    if source then

        for otherId, other in pairs(db.graffiti) do
            if tonumber(otherId) ~= record.id and other.textdraw and other.textdraw.id == source.id then
                other.textdraw = nil
            end
        end
        local sourceTd = source.td or textdraws[source.id]
        record.textdraw = {id = source.id, data = sourceTd and snapshot(sourceTd) or nil}
    end
    db.graffiti[tostring(record.id)], dirty = record, true
    refreshRadar()
end

clearRadar = function()
    for id, blip in pairs(radarBlips) do
        pcall(removeBlip, blip)
        radarBlips[id] = nil
    end
end

local function validBlip(blip)
    return blip ~= nil and blip ~= false and blip ~= -1
end

local function createMapMarker(point, colour)
    local ok, blip = pcall(addBlipForCoord, point.x, point.y, point.z)
    if not ok or not validBlip(blip) then return nil end
    local colourOk = pcall(changeBlipColour, blip, colour)
    local scaleOk = pcall(changeBlipScale, blip, 2)
    local displayOk = pcall(changeBlipDisplay, blip, 3)
    if not (colourOk and scaleOk and displayOk) then
        pcall(removeBlip, blip)
        return nil
    end
    return blip
end

refreshRadar = function()
    if not db or type(addBlipForCoord) ~= 'function' then return end
    local desired = {}
    for id, record in pairs(db.graffiti) do
        local state = Core.eligibility(record, organization(), session, os.time())
        local point = record.coordinates or coordinateFor(id)
        if state == 'available' and point and not (routeTarget and tonumber(id) == routeTarget.id) then desired[id] = point end
    end
    for id, blip in pairs(radarBlips) do
        if not desired[id] then pcall(removeBlip, blip); radarBlips[id] = nil end
    end
    for id, point in pairs(desired) do
        if not radarBlips[id] then

            radarBlips[id] = createMapMarker(point, 1)
        end
    end
end

clearRoute = function()
    if routeBlip then pcall(removeBlip, routeBlip) end
    if routeCheckpoint then pcall(deleteCheckpoint, routeCheckpoint) end
    routeBlip, routeCheckpoint, routeTarget = nil, nil, nil
end

nearestAvailable = function()
    if not db then return nil end
    local x, y = playerPosition.x, playerPosition.y
    local found, bestId, bestDistance = nil, nil, math.huge
    for id, record in pairs(db.graffiti) do
        local point = record.coordinates or coordinateFor(id)
        if point and Core.eligibility(record, organization(), session, os.time()) == 'available' then
            local dx, dy = point.x - x, point.y - y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < bestDistance then found, bestId, bestDistance = point, tonumber(id), distance end
        end
    end
    return bestId, bestDistance, found
end

local function nearestCooldown()
    if not db then return nil end
    local x, y = playerPosition.x, playerPosition.y
    local bestId, bestAt, bestDistance = nil, nil, math.huge
    for id, record in pairs(db.graffiti) do
        local point = record.coordinates or coordinateFor(id)
        local state = Core.eligibility(record, organization(), session, os.time())
        if point and state == 'blocked' and record.estimatedAvailableAt and record.estimatedAvailableAt > os.time() then
            local dx, dy = point.x - x, point.y - y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < bestDistance then bestId, bestAt, bestDistance = tonumber(id), record.estimatedAvailableAt, distance end
        end
    end
    return bestId, bestAt, bestDistance
end

setRoute = function(id)
    local record = db and db.graffiti[tostring(id)]
    local point = record and (record.coordinates or coordinateFor(id))
    if not record or not point then message('Граффити №' .. tostring(id) .. ' ещё не прочитано.'); return false end
    local state = Core.eligibility(record, organization(), session, os.time())
    if state ~= 'available' and state ~= 'blocked' then
        message('Граффити №' .. tostring(id) .. ' сейчас недоступно для закраски.'); return false
    end
    clearRoute()
    local blip = createMapMarker(point, 4)
    if not blip then message('Не удалось создать жёлтую метку маршрута.'); return false end
    routeBlip, routeTarget = blip, {id = tonumber(id), x = point.x, y = point.y, z = point.z}

    local okCheckpoint, checkpoint = pcall(createCheckpoint, 0, point.x, point.y, point.z,
        point.x, point.y, point.z, 4.0)
    if okCheckpoint and checkpoint and checkpoint ~= -1 then routeCheckpoint = checkpoint end
    refreshRadar()
    lastStatus = 'Маршрут проложен к граффити №' .. tostring(id)
    return true
end

updateRoute = function()
    if not routeTarget then return end
    local x, y = playerPosition.x, playerPosition.y
    local dx, dy = routeTarget.x - x, routeTarget.y - y
    if dx * dx + dy * dy <= 100 then
        local id = routeTarget.id
        clearRoute()
        refreshRadar()
        message(('Маршрут к граффити №%d завершён.'):format(id))
    end
end

function events.onShowTextDraw(id, td)
    generation = generation + 1
    td.generation = generation
    textdraws[id] = td
end

function events.onTextDrawSetString(id, text)
    if textdraws[id] then textdraws[id].text = text end
end

function events.onTextDrawHide(id)
    textdraws[id] = nil
    if scan then stop('Карта скрыта или пересоздана. Обход остановлен.'); end
end

function events.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
    if not db or attachedPlayerId ~= 65535 or attachedVehicleId ~= 65535 then return end
    local record = Core.parseWorldGraffiti(fromSamp(text), os.time())
    if not record then return end
    local point = {x = position.x, y = position.y, z = position.z}

    local graffitiId = Core.nearestCoordinate(point)
    if not graffitiId then return end
    local target = db.graffiti[tostring(graffitiId)] or {id = graffitiId}
    target.owner, target.ownerGang = record.owner, record.ownerGang
    target.availability, target.statusText = record.availability, record.statusText
    target.estimatedAvailableAt, target.observedAt = record.estimatedAvailableAt, record.observedAt
    target.session, target.coordinates = session, coordinateFor(graffitiId)
    target.labelId, target.labelDistance = id, distance
    db.graffiti[tostring(graffitiId)], dirty = target, true
    refreshRadar()
    lastStatus = ('Статус граффити №%d обновлён'):format(graffitiId)
end

local sendingClick = false
function events.onSendClickTextDraw(id)
    if sendingClick then return end
    if scan then stop('Ручной клик: обход остановлен.') end
end

function events.onShowDialog(id, style, title, button1, button2, text)
    local utf8 = fromSamp(text)
    local closeStats = statsDeadline > 0 and Core.organization(utf8) ~= nil
    if scan and scan.phase == 'waiting' and not Core.parse(utf8, os.time()) then
        stop('Получен другой диалог: обход остановлен.')
    end
    ingest(utf8, 'native')
    if closeStats then
        lua_thread.create(function()
            wait(0)
            if sampIsDialogActive() and sampGetCurrentDialogId() == id then
                sampCloseCurrentDialogWithButton(0)
            end
        end)
    end
end

local function startScan()
    if not db then message('Дождитесь входа в игру.'); return end
    if scan then message('Скан уже идёт. /gs stop для остановки.'); return end
    if sampIsDialogActive() then message('Сначала закройте карточку граффити.'); return end
    local queue = mapMarkerQueue()
    if #queue == 0 then
        message('Сначала откройте карту граффити, дождитесь значков и затем нажмите Сканировать.')
        return
    end
    scan = Core.scanner(queue, ms() + 500)

    scan.mapDeadline = ms() + 12000
    db.lastScan = {startedAt = os.time(), candidates = #queue, expected = Core.expectedPhoenixMarkers,
        collected = 0, duplicates = 0, complete = false}
    dirty = true
    setWindowOpen(false)
end

command = function(arg)
    local action, rest = (arg or ''):match('^(%S+)%s*(.-)%s*$')
    if not action then setWindowOpen(not (window[0] and windowTarget)); return end
    if action == 'stop' then stop('Обход остановлен.'); return end
    if not db then message('Дождитесь входа в игру.'); return end
    if action == 'scan' then startScan()
    elseif action == 'org' then
        if rest == 'auto' then chooseGang(0); message('Включено определение через /stats.'); return end
        local id = Core.gang(rest)
        for index, gang in ipairs(Core.gangs) do
            if gang.id == id then chooseGang(index); message('Выбрано: ' .. gang.name); return end
        end
        message('org: auto / grove / ballas / vagos / aztecas / rifa / wolves')
    elseif action == 'route' then
        local id, distance
        if rest == '' or Core.lower(rest) == 'nearest' then id, distance = nearestAvailable()
        elseif Core.lower(rest) == 'clear' then clearRoute(); refreshRadar(); return
        else id = tonumber(rest) end
        if not id then message('Нет доступных граффити для маршрута.'); return end
        if setRoute(id) then message(('Маршрут: №%d%s'):format(id, distance and (' · %.0f м'):format(distance) or '')) end
    else message('/gh: окно | /ghs: скан | /ghr [номер]: маршрут | /gho [банда]: организация') end
end

local statusNames = {available = 'Можно перекрасить', blocked = 'Недоступно', own = 'Своя банда',
    unknown = 'Не определено', stale = 'Нужно обновить'}
local gangColors = {
    grove = {0.25, 0.88, 0.45}, ballas = {0.78, 0.34, 0.96}, vagos = {1.00, 0.69, 0.16},
    aztecas = {0.10, 0.82, 0.86}, rifa = {0.26, 0.54, 1.00}, wolves = {0.72, 0.76, 0.82}
}
imgui.OnFrame(function() return window[0] end, function()
    local alpha = updateWindowAnimation()
    if alpha <= 0.01 and not windowTarget then return end
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)

    local screenX, screenY = getScreenResolution()
    local minWidth, minHeight = math.min(700, screenX - 20), math.min(500, screenY - 20)
    local maxWidth, maxHeight = math.max(minWidth, screenX - 20), math.max(minHeight, screenY - 20)
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(minWidth, minHeight), imgui.ImVec2(maxWidth, maxHeight))
    imgui.SetNextWindowSize(imgui.ImVec2(820, 590), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(screenX / 2, screenY / 2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
    imgui.Begin('Graffiti Helper | сканер граффити', window, imgui.WindowFlags.NoCollapse)
    if not db then
        imgui.Text('Дождитесь входа в игру.')
        imgui.End()
        imgui.PopStyleVar()
        return
    end


    local metricAvailable = 0
    for _, record in pairs(db.graffiti) do
        if Core.eligibility(record, organization(), session, os.time()) == 'available' then metricAvailable = metricAvailable + 1 end
    end
    local shellHeight = math.max(100, imgui.GetContentRegionAvail().y)
    imgui.BeginChild('##graffiti_navigation', imgui.ImVec2(138, shellHeight), true, noOuterScrollFlags(0))
    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.SetWindowFontScale(1.45)
    imgui.TextColored(imgui.ImVec4(0.400, 0.920, 0.820, 1.00), uiIcon('SPRAY_CAN', '*'))
    imgui.SetWindowFontScale(1.0)
    imgui.TextColored(imgui.ImVec4(0.400, 0.920, 0.820, 1.00), 'GRAFFITI')
    imgui.TextColored(imgui.ImVec4(0.400, 0.920, 0.820, 1.00), 'HELPER')
    imgui.EndChild()

    imgui.SameLine()
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 10))
    imgui.BeginChild('##graffiti_workspace', imgui.ImVec2(0, shellHeight), false, noOuterScrollFlags(0))

    imgui.Indent(12)
    local last = db.lastScan
    local scanValue = scan and (tostring(scan.done) .. '/' .. tostring(Core.expectedPhoenixMarkers))
        or (last and last.complete and (tostring(last.collected or 0) .. '/' .. tostring(last.expected or Core.expectedPhoenixMarkers)) or '—')
    local scanColor = scan and imgui.ImVec4(1.00, 0.78, 0.28, 1.00) or imgui.ImVec4(0.40, 0.92, 0.82, 1.00)

    imgui.TextDisabled('Организация')
    imgui.SameLine()
    imgui.SetNextItemWidth(190)
    if imgui.Combo('##organization', organizationChoice, labels, #gangLabels) then chooseGang(organizationChoice[0]) end
    imgui.SameLine(0, 22)
    imgui.TextDisabled(uiIcon('CLOCK', '') .. ' Скан')
    imgui.SameLine(); imgui.TextColored(scanColor, scanValue)
    imgui.SameLine(0, 20)
    imgui.TextDisabled(uiIcon('BULLSEYE', '') .. ' Цели')
    imgui.SameLine(); imgui.TextColored(imgui.ImVec4(0.47, 0.88, 0.63, 1.00), tostring(metricAvailable))
    local commandSeparator = uiIcon('CIRCLE', '|')
    imgui.TextDisabled(uiIcon('TERMINAL', '') .. '  /ghs скан  ' .. commandSeparator
        .. '  /ghr [ID] маршрут  ' .. commandSeparator .. '  /gho [банда]')
    imgui.Separator()
    local contentWidth = imgui.GetContentRegionAvail().x
    local records, counts = {}, {available = 0, blocked = 0, own = 0, unknown = 0, stale = 0}
    local playerX, playerY = playerPosition.x, playerPosition.y
    for _, record in pairs(db.graffiti) do
        local state = Core.eligibility(record, organization(), session, os.time())
        counts[state] = counts[state] + 1
        if state == 'available' then
            local point = record.coordinates or coordinateFor(record.id)
            local distance = point and math.sqrt((point.x - playerX) ^ 2 + (point.y - playerY) ^ 2) or math.huge
            records[#records + 1] = {record = record, distance = distance}
        end
    end
    table.sort(records, function(a, b) return a.distance < b.distance end)

    local shownAvailable = #records
    imgui.TextDisabled(uiIcon('BULLSEYE', '') .. ' Доступно')
    imgui.SameLine(); imgui.TextColored(imgui.ImVec4(0.47, 0.88, 0.63, 1.00), tostring(shownAvailable))
    imgui.SameLine(); imgui.TextDisabled(commandSeparator .. ' всего ' .. tostring(Core.expectedPhoenixMarkers))
    imgui.SameLine(contentWidth - 180)
    if managerLikeButton(uiIcon('LOCATION_ARROW', '') .. '  К ближайшему', imgui.ImVec2(172, 32), 'route', 'nearest') then
        command('route nearest')
    end
    imgui.Separator()

    local headerWidth = math.max(150, imgui.GetContentRegionAvail().x - 16)
    imgui.TextDisabled(uiIcon('LIST', '') .. '  Граффити и банда')
    imgui.SameLine(math.max(210, headerWidth - 150))
    imgui.TextDisabled('Расстояние')
    imgui.Separator()

    local listHeight = math.max(80, imgui.GetContentRegionAvail().y - 4)
    imgui.BeginChild('##graffiti_target_rows_v2', imgui.ImVec2(0, listHeight), false)

    local listContentWidth = math.max(150, imgui.GetContentRegionAvail().x - 16)
    if #records == 0 then
        imgui.TextDisabled('Нет доступных для вашей банды граффити.')
    else
        for index, item in ipairs(records) do
            local record = item.record

            local rowPos = imgui.GetCursorPos()
            local rowScreenPos = imgui.GetCursorScreenPos()
            local rowHeight = 38
            imgui.InvisibleButton('##graffiti_row_' .. tostring(record.id), imgui.ImVec2(listContentWidth, rowHeight))
            local rowHovered = imgui.IsItemHovered()
            local afterRow = imgui.GetCursorPos()
            local isNearest = index == 1
            if isNearest then
                imgui.GetWindowDrawList():AddRectFilled(rowScreenPos,
                    imgui.ImVec2(rowScreenPos.x + listContentWidth, rowScreenPos.y + rowHeight),
                    animatedColor(imgui.ImVec4(0.31, 0.22, 0.06, 0.34)), 6, 15)
                imgui.GetWindowDrawList():AddRect(rowScreenPos,
                    imgui.ImVec2(rowScreenPos.x + listContentWidth, rowScreenPos.y + rowHeight),
                    animatedColor(imgui.ImVec4(1.00, 0.72, 0.20, 0.72)), 6, 15, 1.0)
            elseif rowHovered then
                imgui.GetWindowDrawList():AddRectFilled(rowScreenPos,
                    imgui.ImVec2(rowScreenPos.x + listContentWidth, rowScreenPos.y + rowHeight),
                    animatedColor(imgui.ImVec4(0.10, 0.20, 0.23, 0.55)), 6, 15)
            end

            imgui.SetCursorPos(imgui.ImVec2(rowPos.x + 10, rowPos.y + 10))
            local gangRgb = gangColors[record.ownerGang or Core.gang(record.owner)]
            local gangColor = gangRgb and imgui.ImVec4(gangRgb[1], gangRgb[2], gangRgb[3], 1.00)
                or imgui.ImVec4(0.48, 0.64, 0.74, 1.00)
            imgui.TextColored(gangColor, uiIcon('CIRCLE', '*'))
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.400, 0.920, 0.820, 1.00), ('#%d'):format(record.id))
            imgui.SameLine()
            imgui.TextDisabled(record.owner)

            imgui.SetCursorPos(imgui.ImVec2(rowPos.x + math.max(210, listContentWidth - 150), rowPos.y + 10))
            imgui.TextColored(isNearest and imgui.ImVec4(1.00, 0.78, 0.28, 1.00) or imgui.ImVec4(0.58, 0.74, 0.90, 1.00),
                ('%.0f м'):format(item.distance))

            imgui.SetCursorPos(imgui.ImVec2(rowPos.x + math.max(0, listContentWidth - 42), rowPos.y + 5))
            if managerLikeButton(uiIcon('LOCATION_ARROW', '›'), imgui.ImVec2(36, 28),
                    isNearest and 'route' or 'routeSecondary', record.id) then
                command('route ' .. tostring(record.id))
            end
            imgui.SetCursorPos(afterRow)
        end
    end
    imgui.EndChild()
    imgui.Unindent(12)
    imgui.EndChild()
    imgui.PopStyleVar()
    imgui.End()
    imgui.PopStyleVar()
    if not window[0] and windowTarget then
        window[0] = true
        setWindowOpen(false)
    end
end)

local function loadProfile(key)
    if dirty then save() end
    clearRoute()
    profileKey, session = key, sessionNonce .. ':' .. tostring(ms())
    dbPath = root .. '\\' .. key:gsub('[^%w_.%-]', '_') .. '.json'
    db = {schema = 5, graffiti = {}}
    local f = io.open(dbPath, 'rb')
    if f then
        local text = f:read('*a'); f:close()
        local ok, value = pcall(decodeJson, text)
        if ok and type(value) == 'table' and (value.schema == 1 or value.schema == 2 or value.schema == 3 or value.schema == 4 or value.schema == 5) and type(value.graffiti) == 'table' then
            db = value
            db.schema = 5
            for id, record in pairs(db.graffiti) do
                if type(record) ~= 'table' or type(record.id) ~= 'number' or type(record.observedAt) ~= 'number'
                    or type(record.owner) ~= 'string' or type(record.statusText) ~= 'string'
                    or not statusNames[record.availability] then db.graffiti[id] = nil end
            end
        else

            dbPath = dbPath .. '.recovered.json'
            message('База повреждена; новая запись пойдёт в ' .. dbPath)
        end
    end

    local mappingReset = db.textdrawMappingVersion ~= Core.textdrawMappingVersion
    if mappingReset then
        for _, record in pairs(db.graffiti) do record.textdraw = nil end
        db.textdrawMappingVersion = Core.textdrawMappingVersion
    end
    organizationChoice[0] = 0
    for i, gang in ipairs(Core.gangs) do if db.manualGang == gang.id then organizationChoice[0] = i end end
    if organizationChoice[0] == 0 then db.manualGang = nil end
    autoGang, autoName, scan = nil, nil, nil
    statsSent, readyAt = false, ms()
    dirty, statsDeadline, nextRadarRefresh, nextPlayerPositionRefresh = mappingReset, 0, 0, 0
    refreshRadar()
end

function main()
    while not isSampAvailable() do wait(100) end
    if not doesDirectoryExist(root) then createDirectory(root) end
    sampRegisterChatCommand('gh', function(arg) command(arg or '') end)
    sampRegisterChatCommand('ghs', function(arg) command((arg == 'stop') and 'stop' or 'scan') end)
    sampRegisterChatCommand('ghr', function(arg) command('route ' .. tostring(arg or '')) end)
    sampRegisterChatCommand('gho', function(arg) command('org ' .. tostring(arg or '')) end)
    message('/gh окно | /ghs скан | /ghr маршрут')
    while true do
        wait(50)
        if isSampAvailable() and sampIsLocalPlayerSpawned() then
            local ok, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if ok then
                local ip, port = sampGetCurrentServerAddress()
                local key = tostring(ip) .. '_' .. tostring(port) .. '_' .. sampGetPlayerNickname(id)
                if profileKey ~= key then loadProfile(key) end
                if not statsSent and ms() - readyAt >= 5000 and not scan
                    and not sampIsDialogActive() and not sampIsCursorActive() then
                    statsSent, statsDeadline = true, ms() + 10000
                    sampSendChat('/stats')
                end
                if statsDeadline > 0 and ms() > statsDeadline then
                    statsDeadline = 0
                    message('/stats не прочитан. Откройте статистику вручную или выберите организацию.')
                end
                if ms() >= nextPlayerPositionRefresh then
                    local x, y = getCharCoordinates(PLAYER_PED)
                    playerPosition.x, playerPosition.y = x, y
                    nextPlayerPositionRefresh = ms() + 200
                end
                if ms() >= nextRadarRefresh then
                    nextRadarRefresh = ms() + 1000
                    refreshRadar()
                end
                updateRoute()
                if scan then
                    local now = ms()
                    local action, tdId
                    if scan.phase == 'mapwait' then
                        if now >= scan.due then
                            local newlyLoaded = missingMarkerQueue()
                            if #newlyLoaded > 0 then
                                Core.restartMissing(scan, newlyLoaded, now)
                            elseif now >= scan.mapDeadline then
                                stop(('Карта не догрузила все значки: %d/%d. Повторите скан после полной загрузки карты.')
                                    :format(scan.done, Core.expectedPhoenixMarkers))
                            else
                                scan.due = now + 250
                            end
                        end
                    else
                        action, tdId = Core.tick(scan, now, function(item)
                                return item.inferred or (textdraws[item.id]
                                    and textdraws[item.id].generation == item.generation
                                    and Core.isGraffitiMarker(textdraws[item.id], bounds))
                            end)
                    end
                    if action == 'click' then
                            sendingClick = true
                            sampSendClickTextdraw(tdId)
                            sendingClick = false
                        elseif action == 'complete' then
                            if scan.done < Core.expectedPhoenixMarkers then
                                local unresolved = finalRetryQueue(scan)
                                if #unresolved > 0 then
                                    if (scan.pass or 1) < 4 then
                                        Core.restartMissing(scan, unresolved, ms())
                                        db.lastScan.collected = scan.done
                                        db.lastScan.correctivePass = scan.pass
                                        dirty = true
                                    else
                                        stop(('Не ответили TextDraw ID: %s. Скан: %d/%d.')
                                            :format(deferredIdText(scan), scan.done, Core.expectedPhoenixMarkers))
                                    end
                                elseif ms() < scan.mapDeadline then

                                    scan.phase, scan.due = 'mapwait', ms() + 250
                                else
                                    stop(('Скан не подтверждён: %d/%d уникальных. Откройте карту заново и повторите.')
                                        :format(scan.done, Core.expectedPhoenixMarkers))
                                end
                            else
                                db.lastScan.complete, db.lastScan.finishedAt = true, os.time()
                                db.lastScan.collected = scan.done
                                db.lastScan.duplicates = scan.duplicates
                                db.lastScan.uniqueIds, db.lastScan.missingIds = scanSummary(scan)
                                db.lastScan.available = scanAvailableCount(scan)
                                dirty = true
                                local nearestId, nearestDistance = nearestAvailable()
                                local result = ('Скан: %d/%d. Доступно для закраски: %s.')
                                    :format(scan.done, Core.expectedPhoenixMarkers,
                                        db.lastScan.available > 0 and tostring(db.lastScan.available) or 'нет')
                            if nearestId then
                                result = result .. (' Ближайшее: №%d (%.0f м).'):format(nearestId, nearestDistance)
                            else
                                local cooldownId, availableAt, cooldownDistance = nearestCooldown()
                                if cooldownId then
                                    result = result .. (' Ближайшее на КД: №%d, через %s (%.0f м). Маршрут: /ghr %d.')
                                        :format(cooldownId, cooldownText(availableAt - os.time()), cooldownDistance, cooldownId)
                                end
                            end
                                stop(result)
                            end
                    elseif action == 'timeout' then
                        if scan.current then

                            Core.deferTimedOut(scan, ms())
                        end
                    elseif action == 'changed' then stop('Карта изменилась. Обход остановлен.') end
                end
                if dirty and ms() - lastSave > 2000 then save() end
            end
        elseif profileKey then
            stop()
            clearRadar()
            clearRoute()
            profileKey, db, dbPath, session = nil, nil, nil, nil
            textdraws, autoGang, autoName = {}, nil, nil
            statsDeadline = 0
        end
    end
end

function onScriptTerminate(script)
    if script == thisScript() then
        clearRoute()
        clearRadar()
        if dirty then save() end
    end
end

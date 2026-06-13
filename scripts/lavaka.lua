script_name('Lavaka')
script_author('ModioZodio')
script_version('1.0')
script_properties('work-in-pause')

local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local sampev = require 'samp.events'

local enabled = false
local debugMode = false
local state = 'idle'
local lastOpenAttemptAt = 0
local lastActionAttemptAt = 0
local nextOpenAt = 0
local openAttempts = 0
local actionAttempts = 0
local lastCloseAt = 0
local startedAt = 0

local openRetryMs = 50
local actionRetryMs = 300
local baseAfterActionMs = 850
local afterActionMs = baseAfterActionMs
local minAfterActionMs = baseAfterActionMs
local maxAfterActionMs = 1500
local retryLimit = 20
local retryCycles = 0
local cleanLimit = 20
local cleanCycles = 0
local lastMessageText = nil
local lastMessageAt = 0
local lastTooFarNoticeAt = 0

local openMenuPacket = { 220, 0, 82, 64 }
local actionCommand = 'radialMenu.useAction|1'
local interactiveMenuText = "window.executeEvent('event.setActiveView', `[\"InteractiveMenu\"]`);"
local closeViewText = "window.executeEvent('event.setActiveView', '[ null ]');"
local alreadyPlacedText = u8:decode('У Вас уже установлена лавка!')
local placedSuccessText = u8:decode('Вы успешно выставили лавку для продажи/покупки товара!')
local tooFarText = u8:decode('Вы далеко отошли от места установки!')

function main()
    while not isSampAvailable() do wait(0) end

    msgRu('Команда запуска: /lavaka')

    sampRegisterChatCommand('lavaka', function()
        enabled = not enabled
        resetState()
        if enabled then
            resetAdaptiveDelay()
            startedAt = nowMs()
        else
            startedAt = 0
        end
        msgRu(enabled and 'Помощник включен' or 'Помощник выключен')
    end)

    sampRegisterChatCommand('lavakadebug', function()
        debugMode = not debugMode
        msgRu('Диагностика: ' .. (debugMode and 'включена' or 'выключена'))
    end)

    while true do
        wait(0)
        processLavaka()
    end
end

function processLavaka()
    if not enabled then return end

    local now = nowMs()

    if state == 'pause' then
        if now >= nextOpenAt then
            state = 'idle'
        else
            return
        end
    end

    if state == 'idle' then
        if now >= nextOpenAt and now - lastOpenAttemptAt >= openRetryMs then
            sendRawPacket(openMenuPacket)
            state = 'wait_menu'
            lastOpenAttemptAt = now
            openAttempts = openAttempts + 1
        end
        return
    end

    if state == 'wait_menu' then
        if now >= nextOpenAt and now - lastOpenAttemptAt >= openRetryMs then
            sendRawPacket(openMenuPacket)
            lastOpenAttemptAt = now
            openAttempts = openAttempts + 1
        end
        return
    end

    if state == 'wait_close' then
        if now - lastActionAttemptAt >= actionRetryMs then
            sendCefCommand(actionCommand)
            lastActionAttemptAt = now
            actionAttempts = actionAttempts + 1
        end
    end
end

function onReceivePacket(id, bs)
    if not enabled or id ~= 220 then return end

    if state ~= 'wait_menu' and state ~= 'wait_close' then return end

    local text, packets = readCefPacket(bs)
    if state == 'wait_menu' and isInteractiveMenuPacket(text, packets) then
        reportOpenTiming()
        sendCefCommand(actionCommand)
        state = 'wait_close'
        lastActionAttemptAt = nowMs()
        actionAttempts = 1
        return
    end

    if state == 'wait_close' and isCloseViewPacket(text, packets) then
        reportActionTiming()
        updateAdaptiveDelayByRetries()
        resetState(afterActionMs)
        return
    end
end

function sampev.onServerMessage(color, text)
    handleServerMessage(text)
end

function onServerMessage(color, text)
    handleServerMessage(text)
end

function handleServerMessage(text)
    if not enabled then return end
    if isDuplicateMessage(text) then return end

    if isSystemChat(text, '[Подсказка]', 'Вы успешно выставили лавку') or isSystemChat(text, '[Ошибка]', 'У Вас уже установлена лавка') then
        reportInstallTime()
        enabled = false
        resetState()
        startedAt = 0
        msgRu('Лавка установлена, помощник выключен')
    elseif isSystemChat(text, '[Ошибка]', 'Вы далеко отошли от места установки') then
        resetState(afterActionMs)
        reportTooFar()
    end
end

function isSystemChat(text, prefix, needle)
    local cleanText = cleanChatText(text)
    return cleanText:find(u8:decode(prefix), 1, true) == 1 and cleanText:find(u8:decode(needle), 1, true) ~= nil
end

function cleanChatText(text)
    if not text then return '' end
    return text:gsub('{%x%x%x%x%x%x}', ''):gsub('^%s+', '')
end

function isDuplicateMessage(text)
    local now = nowMs()
    if text and text == lastMessageText and now - lastMessageAt <= 100 then
        return true
    end

    lastMessageText = text
    lastMessageAt = now
    return false
end

function sendRawPacket(bytes)
    local bs = raknetNewBitStream()
    for _, byte in ipairs(bytes) do
        raknetBitStreamWriteInt8(bs, byte)
    end
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function sendCefCommand(text)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #text)
    raknetBitStreamWriteString(bs, text)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function readCefPacket(bs)
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

function isInteractiveMenuPacket(text, packets)
    return text == interactiveMenuText
end

function isCloseViewPacket(text, packets)
    return text == closeViewText
end

function reportOpenTiming()
    if debugMode and openAttempts > 1 then
        local extraMs = (openAttempts - 1) * openRetryMs
        local fromClose = lastCloseAt > 0 and (nowMs() - lastCloseAt) or 0
        if fromClose > 0 then
            msgRu(('Меню открылось с %d попытки, после закрытия прошло %d мс, расчетный кд %d мс'):format(openAttempts, fromClose, afterActionMs + extraMs))
        else
            msgRu(('Меню открылось с %d попытки, расчетный кд %d мс'):format(openAttempts, afterActionMs + extraMs))
        end
    end
end

function reportActionTiming()
    if debugMode and actionAttempts > 1 then
        local extraMs = (actionAttempts - 1) * actionRetryMs
        msgRu(('Действие прошло с %d попытки, шаг %d мс, ожидание %d мс'):format(actionAttempts, actionRetryMs, extraMs))
    end
end

function updateAdaptiveDelayByRetries()
    local hadRetry = openAttempts > 1 or actionAttempts > 1

    if hadRetry then
        retryCycles = retryCycles + 1
        cleanCycles = 0
        if retryCycles > retryLimit then
            raiseAdaptiveDelay()
            retryCycles = 0
        end
    else
        cleanCycles = cleanCycles + 1
        retryCycles = 0
        if cleanCycles >= cleanLimit then
            lowerAdaptiveDelay()
            cleanCycles = 0
        end
    end
end

function raiseAdaptiveDelay()
    if afterActionMs >= maxAfterActionMs then return end

    afterActionMs = math.min(afterActionMs + 50, maxAfterActionMs)
    msgRu('Адаптивный кд увеличен: ' .. afterActionMs .. ' мс')
end

function lowerAdaptiveDelay()
    if afterActionMs <= minAfterActionMs then return end

    afterActionMs = math.max(afterActionMs - 25, minAfterActionMs)
    retryCycles = 0
    msgRu('Адаптивный кд снижен: ' .. afterActionMs .. ' мс')
end

function resetAdaptiveDelay()
    afterActionMs = baseAfterActionMs
    retryCycles = 0
    cleanCycles = 0
end

function reportInstallTime()
    if startedAt <= 0 then return end

    local elapsedMs = math.max(nowMs() - startedAt, 1)
    local minutes = math.max(math.ceil(elapsedMs / 60000), 1)
    msgRu('Вы установили лавку меньше чем за ' .. minutes .. ' ' .. minuteWord(minutes))
end

function reportTooFar()
    local now = nowMs()
    if now - lastTooFarNoticeAt < 5000 then return end

    lastTooFarNoticeAt = now
    msgRu('Вы далеко от места установки, помощник продолжает попытки')
end

function resetState(delayMs)
    if delayMs and delayMs > 0 then
        lastCloseAt = nowMs()
    end
    state = 'idle'
    lastOpenAttemptAt = 0
    lastActionAttemptAt = 0
    nextOpenAt = nowMs() + (delayMs or 0)
    openAttempts = 0
    actionAttempts = 0
    if delayMs and delayMs > 0 then
        state = 'pause'
    end
end

function nowMs()
    return math.floor(os.clock() * 1000)
end

function msg(text)
    sampAddChatMessage('[Lavaka] {FFFFFF}' .. text, 0x52C7EA)
end

function msgRu(text)
    sampAddChatMessage('[Lavaka] {FFFFFF}' .. u8:decode(text), 0x52C7EA)
end

function minuteWord(value)
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

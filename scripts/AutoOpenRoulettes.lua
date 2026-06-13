script_name('Auto Open Roulette')
script_version('2.4') -- В исполнении deraquless
script_author('CaJlaT') -- В исполнении deraquless

local init = false
local ready = false
local act = false
local roulette = 0
local roulettes = { 555, 556, 557, 1425 }
local inventory = {}
local lastOpenTime = 0
local openDelay = 2000

local commandName = "autoroulette"

function printChat(text) sampAddChatMessage(string.format('[{007882}%s{FFFFFF}]: %s', thisScript().name, text), -1) end

function logSF(text) sampfuncsLog(string.format('{FFFFFF}[{007882}%s{FFFFFF}]: %s', thisScript().name, text)) end

function logToFile(text)
    if not doesDirectoryExist(getWorkingDirectory() .. '\\Roulette') then createDirectory(getWorkingDirectory() .. '\\Roulette') end
    local file = io.open(getWorkingDirectory() .. '\\Roulette\\' .. os.date('%d-%m-%Y') .. '.txt', 'a+')
    if file then
        file:write('[' .. os.date('%H:%M:%S') .. '] ' .. text .. '\n')
        file:close()
    end
end

local initJS = [[if(!window.cef_sendClientMessage){const e=()=>{},t=[],o=(e,t)=>e!==t&&(e==e||t==t),n=(n,s=e)=>{let r,c=new Set;const i=e=>{if(o(n,e)&&(n=e,r)){const e=!t.length;for(const e of c)e[1](),t.push(e,n);if(e){for(let e=0;e<t.length;e+=2)t[e][0](t[e+1]);t.length=0}}};return{set:i,update:e=>i(e(n)),subscribe:(t,o=e)=>{const l=[t,o];return c.add(l),1===c.size&&(r=s(i,(e=>i(e(n))))||e),t(n),()=>{c.delete(l),!c.size&&r&&(r(),r=null)}}}},s=(t,...o)=>{if(!t)return o.forEach((e=>e())),e;const n=t.subscribe(...o);return n.unsubscribe?()=>n.unsubscribe():n},r=e=>{let t;return s(e,(e=>t=e))(),t},c=n(0),i=(n(!1),n(!1),n(!1),n({}),e=>"function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?typeof e:e&&"function"==typeof Symbol&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e),l=e=>(e||[]).map((e=>"object"===i(e)?JSON.stringify(e):e)).join("|");window.cef_sendClientMessage=(e,...t)=>{const o=e+(t.length?"|":"")+l(t);window.cef?window.cef.SendMessage(o,r(c)):console.log(o)}}]]

local needTakePrize = false
local needExit = false
local prizeTakeTime = 0
local exitTime = 0

function main()
    while not isSampAvailable() do wait(0) end
    
    sampRegisterChatCommand(commandName, function()
        if not ready then
            printChat("Откройте окно рулетки для использования команды")
            return
        end
        
        if not inTable(roulettes, roulette) then
            printChat("Текущая рулетка не поддерживается")
            return
        end
        
        act = not act
        
        if act then
            printChat("Процесс открытия рулеток {007882}запущен")
            lastOpenTime = 0 
        else
            printChat("Процесс открытия рулеток {FF0000}остановлен")
        end
    end)
    
    printChat("Скрипт загружен. Используйте команду {007882}/" .. commandName .. " {FFFFFF}для управления")
    
    while true do
        wait(0)
        local currentTime = os.clock() * 1000
        
        if act and ready and (currentTime - lastOpenTime) > openDelay then
            sendCef('crate.roulette.open')
            lastOpenTime = currentTime
        end
        
        if needTakePrize and (currentTime - prizeTakeTime) > 500 then
            sendCef('crate.roulette.takePrize')
            needTakePrize = false
            needExit = true
            exitTime = currentTime
        end
        
        if needExit and (currentTime - exitTime) > 500 then
            sendCef('crate.roulette.exit')
            needExit = false
        end
    end
end

local samp = require 'samp.events'
function samp.onShowDialog(id, style, title, button1, button2, text)
    if text:find('Поздравляем с получением: {%x+}(.-){%x+}.') then
        local prize = text:match('Поздравляем с получением: {%x+}(.-){%x+}.')
        logToFile(prize)
        if act then
            printChat('Вы получили: {007882}' .. prize)
            logSF('Вы получили: {007882}' .. prize)
            sampSendDialogResponse(id, 1)
            return false
        end
    end
end

function samp.onServerMessage(color, text)
    if act and text:find('%[Подсказка%] {%x+}Вы получили (.+)!') then
        local prize = text:match('%[Подсказка%] {%x+}Вы получили (.+)!')
        if not prize:find('Эдвард') then
            printChat('Вы получили: {007882}' .. prize)
            logSF('Вы получили: {007882}' .. prize)
            logToFile(prize)
        end
    end
end

addEventHandler('onReceivePacket', function(id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if (raknetBitStreamReadInt8(bs) == 17) then
            raknetBitStreamIgnoreBits(bs, 32)
            local len = tonumber(raknetBitStreamReadInt16(bs))
            local encoded = tonumber(raknetBitStreamReadInt8(bs))
            local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, len + encoded) or
                raknetBitStreamReadString(bs, len)
            
            if text:find('window.executeEvent') then
                local event, str = text:match("window.executeEvent%('(.-)', `%[%s*(.-)%s*%]`%);$")
                local event2, str2 = text:match("window.executeEvent%('(.-)', '%[%s*(.-)%s*%]'%);$")
                local event, str = event or event2, str or str2
                if event and str then
                    if act and event == 'event.crate.roulette.onCrateOpen' then
                        needTakePrize = true
                        prizeTakeTime = os.clock() * 1000
                    end
                    if event == 'event.inventory.playerInventory' then
                        local data = decodeJson(str)
                        if data.data.type == 1 and data.data.items then
                            inventory = {}
                            for i, v in ipairs(data.data.items) do
                                table.insert(inventory, v)
                            end
                        end
                    end
                    if event == 'event.crate.roulette.initialize' then
                        local data = decodeJson(str)
                        roulette = tonumber(data.sysName)
                    end
                end
            end
        end
    end
end)

addEventHandler('onSendPacket', function(id, bs, priority, reliability, orderingChannel)
    if id == 220 then
        local id = raknetBitStreamReadInt8(bs)
        local packettype = raknetBitStreamReadInt8(bs)
        local strlen = raknetBitStreamReadInt16(bs)
        local text = raknetBitStreamReadString(bs, strlen)
        if packettype ~= 0 and packettype ~= 1 and #text > 2 then
            if text:find('onActiveViewChanged|(.+)') then
                local view = text:match('onActiveViewChanged|(.+)')
                ready = view == 'CrateRoulette'
                if ready and inTable(roulettes, roulette) then
                    evalanon(initJS)
                    printChat("Окно рулетки открыто. Используйте {007882}/" .. commandName .. " {FFFFFF}для начала открытия")
                end
            end
        end
    end
end)

function sendCef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function emulCef(str, is_encoded)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteInt8(bs, is_encoded and 1 or 0)
    if is_encoded then
        raknetBitStreamEncodeString(bs, str)
    else
        raknetBitStreamWriteString(bs, str)
    end
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

function evalanon(code)
    emulCef(('(() => {%s})();'):format(code))
end

function inTable(t, val, key)
    for k, v in pairs(t) do
        if key and k == key and v == val then return true end
        if type(v) == 'table' then
            if inTable(v, val, key) then return true end
        elseif not key and v == val then
            return true
        end
    end
    return false
end

function findTableByValue(t, val, key, index)
    for k, v in pairs(t) do
        if key and k == key and ((type(val) == 'string' and type(v) == 'string' and v:lower():find(val:lower())) or v == val) then
            return t, index
        end
        if type(v) == 'table' then
            local test, tindex = findTableByValue(v, val, key, index or k)
            if test then return test, tindex end
        elseif not key and ((type(val) == 'string' and type(v) == 'string' and v:lower():find(val:lower())) or v == val) then
            return t, index
        end
    end
    return false, false
end

function getAmount(item)
    local amount = 0
    for i, v in ipairs(inventory) do
        if v.item and v.item == item and v.amount then
            amount = amount + v.amount
        end
    end
    return amount
end
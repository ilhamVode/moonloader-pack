script_name('CtrlLkmFlood')
script_author('ModioZodio')
script_version('1.0')
script_properties('work-in-pause')

local ffi = require 'ffi'
local bit = require 'bit'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local sampev = require 'samp.events'

ffi.cdef[[
typedef unsigned char BYTE;
typedef unsigned long DWORD;
typedef unsigned long ULONG_PTR;
typedef uintptr_t WPARAM;
typedef intptr_t LPARAM;
typedef intptr_t LRESULT;
typedef void* HHOOK;
typedef void* HINSTANCE;

typedef struct {
    DWORD vkCode;
    DWORD scanCode;
    DWORD flags;
    DWORD time;
    ULONG_PTR dwExtraInfo;
} KBDLLHOOKSTRUCT;

typedef LRESULT (__stdcall *HOOKPROC)(int nCode, WPARAM wParam, LPARAM lParam);

HHOOK SetWindowsHookExA(int idHook, HOOKPROC lpfn, HINSTANCE hmod, DWORD dwThreadId);
LRESULT CallNextHookEx(HHOOK hhk, int nCode, WPARAM wParam, LPARAM lParam);
int UnhookWindowsHookEx(HHOOK hhk);
void keybd_event(BYTE bVk, BYTE bScan, DWORD dwFlags, ULONG_PTR dwExtraInfo);
void mouse_event(DWORD dwFlags, DWORD dx, DWORD dy, DWORD dwData, ULONG_PTR dwExtraInfo);
DWORD GetTickCount(void);
]]

local WH_KEYBOARD_LL = 13
local WM_KEYDOWN = 0x0100
local WM_SYSKEYDOWN = 0x0104
local LLKHF_INJECTED = 0x10

local VK_CONTROL = 0x11
local VK_LCONTROL = 0xA2
local VK_RCONTROL = 0xA3

local KEYEVENTF_KEYUP = 0x0002
local MOUSEEVENTF_LEFTDOWN = 0x0002
local MOUSEEVENTF_LEFTUP = 0x0004

local enabled = false
local ctrlHeld = false
local physicalCtrlPressed = false
local clickDelayMs = 80
local clickHoldMs = 12
local minDelayMs = 30
local nextClickAt = 0
local hook = nil
local hookCallback = nil
local legendaryPrizeText = u8:decode('и выиграл легендарный приз')

function main()
    while not isSampAvailable() do wait(0) end

    installKeyboardHook()

    sampRegisterChatCommand('ctrllkm', function(arg)
        handleCommand(arg)
    end)

    while true do
        wait(0)
        processFlood()
    end
end

function handleCommand(arg)
    arg = tostring(arg or ''):match('^%s*(.-)%s*$')

    if arg == 'off' or arg == '0' then
        stopFlood('выключен командой')
        return
    end

    local delay = tonumber(arg)
    if delay then
        clickDelayMs = math.max(math.floor(delay), minDelayMs)
        msg('Задержка ЛКМ установлена: ' .. clickDelayMs .. ' мс')
        return
    end

    if enabled then
        stopFlood('выключен')
    else
        startFlood()
    end
end

function startFlood()
    if enabled then return end
    physicalCtrlPressed = false
    enabled = true
    nextClickAt = nowMs()
    holdCtrl()
    msg('включен: удерживаю Ctrl и флужу ЛКМ. Для остановки нажми Ctrl вручную.')
end

function stopFlood(reason)
    if not enabled and not ctrlHeld then return end
    enabled = false
    physicalCtrlPressed = false
    releaseCtrl()
    msg(reason or 'выключен')
end

function processFlood()
    if not enabled then return end

    if physicalCtrlPressed then
        stopFlood('выключен: обнаружено ручное нажатие Ctrl')
        return
    end

    if isUiBlockingInput() then
        releaseCtrl()
        return
    end

    holdCtrl()

    local now = nowMs()
    if now >= nextClickAt then
        clickLeft()
        nextClickAt = now + clickDelayMs
    end
end

function sampev.onServerMessage(color, text)
    if enabled and text and text:find(legendaryPrizeText, 1, true) then
        stopFlood('выключен: найден легендарный приз в чате')
    end
end

function isUiBlockingInput()
    if isPauseMenuActive and isPauseMenuActive() then return true end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if sampIsScoreboardOpen and sampIsScoreboardOpen() then return true end
    return false
end

function holdCtrl()
    if ctrlHeld then return end
    ffi.C.keybd_event(VK_CONTROL, 0, 0, 0)
    ctrlHeld = true
end

function releaseCtrl()
    if not ctrlHeld then return end
    ffi.C.keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0)
    ctrlHeld = false
end

function clickLeft()
    ffi.C.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    wait(clickHoldMs)
    ffi.C.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
end

function installKeyboardHook()
    if hook ~= nil and hook ~= ffi.NULL then return end

    hookCallback = ffi.cast('HOOKPROC', function(nCode, wParam, lParam)
        if nCode >= 0 and enabled and (wParam == WM_KEYDOWN or wParam == WM_SYSKEYDOWN) then
            local info = ffi.cast('KBDLLHOOKSTRUCT*', lParam)
            local vk = tonumber(info.vkCode)
            local flags = tonumber(info.flags)
            local injected = bit.band(flags, LLKHF_INJECTED) ~= 0

            if not injected and (vk == VK_CONTROL or vk == VK_LCONTROL or vk == VK_RCONTROL) then
                physicalCtrlPressed = true
            end
        end

        return ffi.C.CallNextHookEx(hook, nCode, wParam, lParam)
    end)

    hook = ffi.C.SetWindowsHookExA(WH_KEYBOARD_LL, hookCallback, nil, 0)
    if hook == nil or hook == ffi.NULL then
        msg('не удалось поставить keyboard hook, аварийный стоп по Ctrl может не работать')
    end
end

function nowMs()
    return tonumber(ffi.C.GetTickCount())
end

function msg(text)
    sampAddChatMessage('[CtrlLKM] {FFFFFF}' .. u8:decode(text), 0x52C7EA)
end

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        releaseCtrl()
        if hook ~= nil and hook ~= ffi.NULL then
            ffi.C.UnhookWindowsHookEx(hook)
            hook = nil
        end
        if hookCallback ~= nil then
            hookCallback:free()
            hookCallback = nil
        end
    end
end

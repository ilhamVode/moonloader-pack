script_name("A-Doklad")
script_author("Caps")
script_version("1.0")

local key = require 'vkeys'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local imgui = require 'mimgui'
local new = imgui.new

local default_settings = {
    doklad = {
        post = '',
        name = '',
        condition = '����������',
        reportInterval = 600,
        autoTime = true,
        autoF8 = true
    }
}
local settings = inicfg.load(default_settings, 'doklad_settings.ini')

local lastReportTime = 0
local reportInterval = settings.doklad.reportInterval
local isActive = false
local isSendingReport = false

local WinState = new.bool(false)
local post = new.char[256](u8(settings.doklad.post))
local name = new.char[256](u8(settings.doklad.name))
local condition = new.char[256](u8(settings.doklad.condition))
local checkboxAutoTime = new.bool(settings.doklad.autoTime)
local checkboxAutoF8 = new.bool(settings.doklad.autoF8)
local intervalInput = new.int(reportInterval)

function autoSave()
    settings.doklad.post = u8:decode(ffi.string(post))
    settings.doklad.name = u8:decode(ffi.string(name))
    settings.doklad.condition = u8:decode(ffi.string(condition))
    settings.doklad.reportInterval = intervalInput[0]
    settings.doklad.autoTime = checkboxAutoTime[0]
    settings.doklad.autoF8 = checkboxAutoF8[0]
    
    inicfg.save(settings, 'doklad_settings.ini')
end

function areFieldsFilled()
    local nameStr = ffi.string(name)
    local postStr = ffi.string(post)
    local conditionStr = ffi.string(condition)
    return nameStr ~= "" and postStr ~= "" and conditionStr ~= ""
end

function sendReport()
    if isSendingReport or not isActive then return end
    isSendingReport = true
    
    if not areFieldsFilled() then
        sampAddChatMessage("��������� ��� ���� � ���� ��������!", 0xFF0000)
        isActive = false
        isSendingReport = false
        return
    end
    
    local nameStr = ffi.string(name)
    local postStr = ffi.string(post)
    local conditionStr = ffi.string(condition)
    
    sampSendChat("/r �����������: "..u8:decode(nameStr)..". ����: "..u8:decode(postStr).." | ���������: "..u8:decode(conditionStr))
    
    lua_thread.create(function()
        wait(1000)
        if not isActive then
            isSendingReport = false
            return
        end
        
        if checkboxAutoTime[0] then
            sampSendChat("/time")
            wait(1000)
        end
        
        if checkboxAutoF8[0] then
            setVirtualKeyDown(key.VK_F8, true)
            wait(100)
            setVirtualKeyDown(key.VK_F8, false)
        end
        
        isSendingReport = false
        lastReportTime = os.time()
    end)
end

imgui.OnFrame(function() return WinState[0] end,
    function()
        imgui.SetNextWindowSize(imgui.ImVec2(400, 500), imgui.Cond.FirstUseEver)
        local displaySize = imgui.GetIO().DisplaySize
        local windowSize = imgui.ImVec2(400, 500)
        imgui.SetNextWindowPos(
            imgui.ImVec2(displaySize.x * 0.5, displaySize.y * 0.5),
            imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5)
        )
        
        imgui.Begin(u8'A-Doklad 1.0', WinState)
        
        imgui.Text(u8"�������� ���������:")
        if imgui.InputText(u8"���� ���", name, 256) then autoSave() end
        if imgui.InputText(u8"�������� �����", post, 256) then autoSave() end
        if imgui.InputText(u8"��������� �����", condition, 256) then autoSave() end
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        
        imgui.Text(u8"�������������:")
        if imgui.Checkbox(u8"���� /time ����� �������", checkboxAutoTime) then autoSave() end
        if imgui.Checkbox(u8"���� F8 ����� �������", checkboxAutoF8) then autoSave() end
        
        imgui.Spacing()
        imgui.Separator() 
        imgui.Spacing()
        
        imgui.Text(u8"�������� ����� ��������� (�������):")
        if imgui.InputInt(u8"##interval", intervalInput) then
            if intervalInput[0] < 60 then intervalInput[0] = 60 end
            reportInterval = intervalInput[0]
            autoSave()
        end
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        
        if isActive then
            local currentTime = os.time()
            local timeRemaining = reportInterval - (currentTime - lastReportTime)
            timeRemaining = timeRemaining > 0 and timeRemaining or 0
            
            local minutes = math.floor(timeRemaining / 60)
            local seconds = timeRemaining % 60
            imgui.Text(u8"��������� ������ �����: "..string.format("%d ���. %d ���.", minutes, seconds))
        end
        
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        
        imgui.Text(u8"/doklad - ��������� �������")
        imgui.Text(u8"/dokladoff - ����������� �������")
        
        imgui.Spacing()
        if imgui.Button(u8"�������", imgui.ImVec2(100, 30)) then
            WinState[0] = false
        end
        
        imgui.End()
    end
)

function main()
    while not isSampAvailable() do wait(0) end
    
    sampRegisterChatCommand("doklad", function()
        if not areFieldsFilled() then
            sampAddChatMessage("��������� ��� ���� � ���� ��������!", 0xFF0000)
            isActive = false
            return
        end
        
        if isActive then
            local currentTime = os.time()
            local timeRemaining = reportInterval - (currentTime - lastReportTime)
            timeRemaining = timeRemaining > 0 and timeRemaining or 0
            
            local minutes = math.floor(timeRemaining / 60)
            local seconds = timeRemaining % 60
            sampAddChatMessage(string.format("��������� ������ �����: %d ���. %d ���.", minutes, seconds), 0x00AAFF)
        else
            isActive = true
            sendReport()
        end
    end)
    
    sampRegisterChatCommand("dokladoff", function()
        isActive = false
        sampAddChatMessage("�������������� ������� ���������.", 0x00AAFF)
    end)
    
    sampRegisterChatCommand("dmenu", function()
        WinState[0] = not WinState[0]
    end)

    while true do
        wait(0)
        local currentTime = os.time()
        
        if isActive and not isSendingReport and currentTime - lastReportTime >= reportInterval then
            sendReport()
        end
    end
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    red_theme()
end)

function red_theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    imgui.GetStyle().WindowPadding = imgui.ImVec2(10, 10)
    imgui.GetStyle().FramePadding = imgui.ImVec2(8, 6)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(8, 8)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(4, 4)
    imgui.GetStyle().ScrollbarSize = 12
    imgui.GetStyle().GrabMinSize = 12

    imgui.GetStyle().WindowBorderSize = 1
    imgui.GetStyle().ChildBorderSize = 1
    imgui.GetStyle().PopupBorderSize = 1
    imgui.GetStyle().FrameBorderSize = 1

    imgui.GetStyle().WindowRounding = 8
    imgui.GetStyle().ChildRounding = 8
    imgui.GetStyle().FrameRounding = 8
    imgui.GetStyle().PopupRounding = 8
    imgui.GetStyle().ScrollbarRounding = 8
    imgui.GetStyle().GrabRounding = 8

    colors[clr.FrameBg]                = ImVec4(0.48, 0.16, 0.16, 0.54)
    colors[clr.FrameBgHovered]         = ImVec4(0.98, 0.26, 0.26, 0.40)
    colors[clr.FrameBgActive]          = ImVec4(0.98, 0.26, 0.26, 0.67)
    colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.48, 0.16, 0.16, 1.00)
    colors[clr.CheckMark]              = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.Button]                 = ImVec4(0.98, 0.26, 0.26, 0.40)
    colors[clr.ButtonHovered]          = ImVec4(0.98, 0.26, 0.26, 1.00)
    colors[clr.ButtonActive]           = ImVec4(0.98, 0.06, 0.06, 1.00)
    colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
    colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
end
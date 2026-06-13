require "lib.moonloader"
local sampev = require("samp.events")
local state = false
font = renderCreateFont('Arial', 20, 5)
local tag = "{AD42FE}[GRIBI]{ffffff} - "


function main()
    repeat wait(0) until isSampAvailable() 
	sampAddChatMessage(tag.. " Загружен! Активация: /gribs | Автор: vlaDICK2288", -1)
    sampRegisterChatCommand('gribs',function()
        activ = not activ
		sampAddChatMessage(activ and "ON" or "OFF",0xFF00FF)
    end)
    while true do
        wait(0)
        if activ then
	     for id = 0, 4096 do
		     if sampIs3dTextDefined(id) then
	 	       local text, color, x, y, z, distance, ignoreWalls, player, vehicle = sampGet3dTextInfoById(id)
	 	         if text:find("Срезать гриб") then
	 		        if isPointOnScreen(x, y, z, 3.0) then
	 			        xp, yp, zp = getCharCoordinates(PLAYER_PED)
	 			        x1, y2 = convert3DCoordsToScreen(x, y, z)
	 			        p3, p4 = convert3DCoordsToScreen(xp, yp, zp)
	 			        distance = string.format("%.0f", getDistanceBetweenCoords3d(x, y, z, xp, yp, zp))
	 			        text = ("{ffffff}Грибок\n{ff0000}Дистанция: "..distance)
	 			        renderFontDrawText(font, text, x1, y2, -1)
						end
					end
				end
			end
		end
	end
end
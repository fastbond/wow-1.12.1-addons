--[[
	Addon for managing Consumable items in WoW 1.12.1

	Notes:
	--What item type is demonic rune?
	
--]]


ConsumeBar = {}

ConsumeBar.Bar = {}
ConsumeBar.ItemInfo = {}

ConsumeBar.FramePool = {}
ConsumeBar.FrameIndex = 0

ConsumeBar.MainFrame = nil
ConsumeBar.MenuFrame = nil

ConsumeBar.MenuTimer = nil
MENU_HIDE_DELAY = .15

ATTEMPTS = 0
LOADED = false

--FIX THESE CALCS/SIZES
FRAME_SIZE = 40
BORDER_SIZE = 6
FRAME_GAP = 4

BINDING_HEADER_CONSUMEBAR = "Consume Bar"



function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end


function getTableSize(t)

	if not t then
		return 0
	end

	local len = 0
	
	for k,v in t do
		len = len + 1
	end
	
	return len

end



SLASH_CONSUMEBAR1, SLASH_CONSUMEBAR2 = '/consumebar', '/cb'; 
SlashCmdList["CONSUMEBAR"] = function(msg)

	msg = string.lower(msg)

	--string.find apparently returns [start, end],[match1,match2,...] sometimes
	local _,_, cmd, text = string.find(msg,"([^%s]+) ?(.*)")
	
	--print("Cmd "..cmd)
	--print("Txt "..text)
	
	if cmd == "add" then
		--FIX THE USAGE OF TEXT HERE, BEHAVIOR ON TEXT VS NO TEXT
		ConsumeBar.AddItem(text) --Search through, dont use frameNum
	elseif cmd == "remove" then
		if not text or text=="" then
			ConsumeBar.Remove()
		else
			ConsumeBar.RemoveItem(text)
		end
	elseif cmd == "hide" then
		ConsumeBar.MainFrame:Hide()
	elseif cmd == "show" then 
		ConsumeBar.MainFrame:Show()
	elseif cmd == "lock" then
	elseif cmd == "unlock" then
	elseif cmd == "bind" then 
	elseif cmd == "test" then
		print("SavedConsumes")
		for k,v in SavedConsumes do
			print(k..v["name"])
		end
		print("Bar")
		for k,v in ConsumeBar.Bar do
			local name = v["name"] or ""
			print(k.." "..v["frame"]:GetName().." - "..name)
		end
	elseif cmd == "load" then
		ConsumeBar.LoadSavedConsumes()
	end
	
end




function ConsumeBar.OnLoad() 

	ConsumeBar.CreateMainFrame()
	ConsumeBar.MainFrame:Show()
	
	
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("PLAYER_LOGOUT");
	this:RegisterEvent("BAG_UPDATE");

	ConsumeBar.CreateConsumeMenu()
	--ConsumeBar.CreateInitialFrames() --This function doesn't work
	ConsumeBar.AddFrame() --Add starting empty frame
	
	ConsumeBar.MainFrame:SetScript("OnUpdate", function()
		
		if getTableSize(SavedConsumes) == 0 then
			ConsumeBar.MainFrame:SetScript("OnUpdate", nil)
			LOADED = true
			return
		end
		
		
		--Awful hack to run the load after inventory has actually been loaded
		ATTEMPTS = ATTEMPTS + 1
		if ATTEMPTS >= 100 then
			ConsumeBar.MainFrame:SetScript("OnUpdate", nil)
			ConsumeBar.LoadSavedConsumes()
			print("Consume Bar Loaded")
			LOADED = true
		end	
		
	end)
	
end


function ConsumeBar.CreateMainFrame()

	ConsumeBar.MainFrame = CreateFrame("Button","ConsumeBarFrame",UIParent,nil)
	
	ConsumeBar.MainFrame:SetPoint("TOPLEFT", 0,0)
	
	--Children don't display without a positive Width/Height
	ConsumeBar.MainFrame:SetWidth(1) 
	ConsumeBar.MainFrame:SetHeight(1)

	ConsumeBar.MainFrame:SetMovable() 
	
	return ConsumeBar.MainFrame

end



--Load Consumes from saved character lua file
function ConsumeBar.LoadSavedConsumes()

	print("Loading Saved Consumes")

	for k,v in SavedConsumes do
		local name = v["name"] or ""
		--print(k.." "..name)
		
		--ConsumeBar.AddItem(v["name"])
        
        if k > getTableSize(ConsumeBar.Bar) then
            ConsumeBar.AddFrame()
        end
        
        ConsumeBar.PutItem(v["name"], k)
	end
	

end



function ConsumeBar.OnEvent()

	if event == "BAG_UPDATE" then
		ConsumeBar.UpdateItemInfo()
		ConsumeBar.UpdateFrames()
		
	elseif event == "ADDON_LOADED" and arg1 == "ConsumeBar" then
		SavedConsumes = SavedConsumes or {}
		SavedItemInfo = SavedItemInfo or {}
		Settings = Settings or {}
		
		if Settings["x"] and Settings["y"] then
			ConsumeBar.MainFrame:SetPoint("TOPLEFT", Settings["x"], Settings["y"])
		end
		
		
		for name, item in SavedItemInfo do
			ConsumeBar.ItemInfo[name] = item
		end
		--ConsumeBar.CreateInitialFrames()--ConsumeBar.AddFrame()--CreateInitialFrames() --Not needed due to wait on load
		
	elseif event == "PLAYER_LOGOUT" then 
		if LOADED then
			SavedConsumes = ConsumeBar.Bar
			for i, frame in ConsumeBar.Bar do
				local itemName = frame["name"]
				SavedItemInfo[itemName] = ConsumeBar.ItemInfo[itemName]
				SavedItemInfo[itemName]["bagslots"] = {}
				SavedItemInfo[itemName]["count"] = 0
			end
		end
	end
end 





function ConsumeBar.CreateInitialFrames()

	local emptyFrameCount = getTableSize(SavedConsumes)
	--print(emptyFrameCount)
	print("Creating "..emptyFrameCount.." Empty Frames")
	
	if emptyFrameCount == 0 then
		emptyFrameCount = 1
	end
	
	for i = 1, emptyFrameCount do
		ConsumeBar.AddFrame()
	end

end



function ConsumeBar.AddFrame()

	local frameNum = ConsumeBar.FrameIndex + 1
	local frame = CreateFrame("Button","ConsumeBar_"..frameNum,ConsumeBar.MainFrame,"ActionButtonTemplate")
	ConsumeBar.FrameIndex = ConsumeBar.FrameIndex + 1
	
	--Frame.size = 36 due to actionbuttontemplate
	--Region:SetPoint("point" [, relativeTo [, "relativePoint" [, xOffset [, yOffset]]]])
	--BORDER_SIZE/GAP DONT EVEN DO ANYTHING ANYMORE, FIX THIS WHOLE CALC
	frame:SetPoint("LEFT", BORDER_SIZE + FRAME_GAP + (getTableSize(ConsumeBar.Bar) * FRAME_SIZE),0) --40x40?
	--ConsumeBar.AlignFrames()
	
	--Dragging
	frame:SetScript("OnDragStart", function() if IsControlKeyDown() then ConsumeBar.MainFrame:StartMoving() end end)
	frame:SetScript("OnDragStop", function() ConsumeBar.MainFrame:StopMovingOrSizing(); ConsumeBar.MainFrame:SetUserPlaced(false); 
	
		point, relativeTo, relativePoint, xOfs, yOfs = ConsumeBar.MainFrame:GetPoint()
		--print(point)
		--print(relativeTo:GetName()) --Crashes game
		--print(relativePoint)
		--print(xOfs)
		--print(yOfs)
		
		Settings["x"] = xOfs
		Settings["y"] = yOfs
	
	end)
	frame:RegisterForDrag("LeftButton","RightButton")	
	
	
	--Mouseover

	frame:SetScript("OnEnter", function()	
		ConsumeBar.ResetMenuTimer()
		ConsumeBar.ShowConsumeMenu(frame)
	end)
		
	
	--Leave Mouseover
	frame:SetScript("OnLeave", function()
		ConsumeBar.StartMenuTimer()
	end)
	
	
	local t = {["frame"] = frame, ["name"] = nil, ["texture"]=nil}
	table.insert(ConsumeBar.Bar, t)
	
	return frame, frameNum
end


--Types of Adds
	--All frames full, no frame specified
	--No frame specified, empty frames
	--Frame specified, frame empty
	--Frame specified, frame full
function ConsumeBar.AddItem(itemName, barPos)

	if not itemName or itemName == "" then
		ConsumeBar.AddFrame()
		return
	end

	
	--Find first empty bar frame
	if not barPos then
	
		for k,v in ConsumeBar.Bar do
		
			--This shouldn't happen, but leaving in for now for testing
			if not v["frame"] then
				print("Error: Nil frame in Bar")
				return
			end
			
			--Empty frame(No item assigned)
			if not v["name"] then
				barPos = k
				break
			end
			
		end
	end
	
	if not barPos then
		--_, barPos = ConsumeBar.AddFrame()
		ConsumeBar.AddFrame()
		barPos = getTableSize(ConsumeBar.Bar)
	end
	
	
	if not itemName then
		return
	end
	
	return ConsumeBar.PutItem(itemName, barPos)


end



--Rename framePos
function ConsumeBar.PutItem(itemName, framePos)

	if not itemName or not framePos then
		return
	end
		
	if framePos > getTableSize(ConsumeBar.Bar) then
		return
	end
	
	--if not ConsumeBar.ItemInfo[itemName] then...
	local item = ConsumeBar.GetItemInfo(itemName)

	if not item then
		--print("FAILED ITEM CHECK")
		return
	end
	
	
	ConsumeBar.ItemInfo[item["name"]] = item
	itemName = item["name"]
	ConsumeBar.Bar[framePos]["name"] = itemName

	local frame = ConsumeBar.Bar[framePos]["frame"]
	
	ConsumeBar.SetFrameTexture(frame, item)
	ConsumeBar.SetFrameItemQuantityText(frame, item)
	ConsumeBar.SetFrameCooldown(frame, item)
	
	bind = GetBindingText(GetBindingKey("Consume Bar "..framePos), "KEY_", 1)
	ConsumeBar.SetFrameKeybindText(frame, bind)
	
	
	
	--SCRIPTS
	
	--Use item on click
	frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
	frame:SetScript("OnClick", function()
		--Using closures to hold the variable value
		if getTableSize(ConsumeBar.ItemInfo[itemName]["bagslots"]) > 0 then
			UseContainerItem(ConsumeBar.ItemInfo[itemName]["bagslots"][1]["bag"],ConsumeBar.ItemInfo[itemName]["bagslots"][1]["slot"])
		end
	end)
	
	--Show tooltip
	if ConsumeBar.ItemInfo[itemName] then
	
		frame:SetScript("OnEnter", function()	
		
			ConsumeBar.ResetMenuTimer()
			ConsumeBar.ShowConsumeMenu(frame)
			
			if ConsumeBar.ItemInfo[itemName] and getTableSize(ConsumeBar.ItemInfo[itemName]["bagslots"]) > 0 then
				--GameToolTip:SetPoint("BOTTOMRIGHT")
				GameTooltip:SetOwner(ConsumeBar.MainFrame,"ANCHOR_LEFT")
				GameTooltip:SetBagItem(ConsumeBar.ItemInfo[itemName]["bagslots"][1]["bag"],ConsumeBar.ItemInfo[itemName]["bagslots"][1]["slot"])
				GameTooltip:Show()
			end
		end)
		
	end
	
	--Hide tooltip
	frame:SetScript("OnLeave", function()
		ConsumeBar.StartMenuTimer()
		
		GameTooltip:Hide()
	end)


end






function ConsumeBar.SetFrameTexture(frame, item)

	if not frame or not item then
		return
	end

	--Set texture
	local frameIcon = getglobal(frame:GetName() .. "Icon")
	frameIcon:SetDrawLayer("ARTWORK")
	
	local texture = item["texture"]
	
	if texture then
		frameIcon:SetTexture(texture)
		frameIcon:SetDesaturated(0) --Ensure not greyscale
	end
	
	if item["count"] == 0 then
		frameIcon:SetVertexColor(0.4, 0.4, 0.4);
	end
	
end



function ConsumeBar.SetFrameItemQuantityText(frame, item)

	if not frame then
		return
	end

	--Set quantity text
	if not frame.Text then
		frame.Text = frame:CreateFontString("Text","OVERLAY","NumberFontNormal")
		frame.Text:SetPoint("BOTTOMRIGHT", 0, 0)
	end
	
	if item and item["stack"] > 1 then
		frame.Text:SetText(item["count"])
	else
		frame.Text:SetText("")
	end

end



function ConsumeBar.SetFrameKeybindText(frame, bind)

	if not frame then
		return
	end

	
	--Set bind text
	if not frame.KeybindText then
		frame.KeybindText = frame:CreateFontString("KeybindText","OVERLAY","NumberFontNormal")
		frame.KeybindText:SetPoint("TOPRIGHT", 0, 0)
	end
	
	if bind then
		frame.KeybindText:SetText(bind)
	else
		frame.KeybindText:SetText("")
	end


end



function ConsumeBar.SetFrameCooldown(frame, item)

	if not frame or not item then
		return
	end

	if getTableSize(item["bagslots"]) > 0 then
		local bag = item["bagslots"][1]["bag"]
		local slot = item["bagslots"][1]["slot"]
		--print(bag.." "..slot)
		local cooldownFrame = getglobal(frame:GetName().."Cooldown")
		startTime, duration, isEnabled = GetContainerItemCooldown(bag, slot)
		CooldownFrame_SetTimer(cooldownFrame,startTime, duration, isEnabled)
	end


end



function ConsumeBar.RemoveFrame(index)

	if index < 1 or index > getTableSize(ConsumeBar.Bar) then
		return nil
	end

	local frame = ConsumeBar.Bar[index]["frame"]
	table.remove(ConsumeBar.Bar, index)
	
	frame:Hide()
	frame:UnregisterAllEvents()
	frame:SetParent(nil) --UIParent
	
	table.insert(ConsumeBar.FramePool, frame)

	return frame
end




function ConsumeBar.RemoveItem(itemName)

	local removed = false
	for index,v in ConsumeBar.Bar do
		if itemName and v["name"] and string.lower(v["name"]) == string.lower(itemName) then
			ConsumeBar.RemoveFrame(index)
			removed = true
			break
		end
	end
	
	--Add ConsumeBar.AlignFrames() function
	--This should probably be moved to RemoveFrame function
	if removed then
		local frame
		for i,v in ConsumeBar.Bar do
			frame = v["frame"]
			frame:SetPoint("LEFT", BORDER_SIZE + FRAME_GAP + ((i-1) * FRAME_SIZE),0)
			bind = GetBindingText(GetBindingKey("Consume Bar "..i), "KEY_", 1)
			ConsumeBar.SetFrameKeybindText(frame, bind)
		end
	end
	

end


function ConsumeBar.Remove()

	--Get last frame
	local endIndex = getTableSize(ConsumeBar.Bar)
	ConsumeBar.RemoveFrame(endIndex)
	

end




function ConsumeBar.GetItemInfo(name)

	if name == "" or not name then
			return nil
		end

	local itemLink,itemID,itemName,equipSlot,itemTexture

	local item
	
	
	for i=0,4 do --for each bag
			for j=1,GetContainerNumSlots(i) do --for each slot in bag
				itemLink = GetContainerItemLink(i,j)
				
				if itemLink then
					_,_,itemID,itemName = string.find(GetContainerItemLink(i,j) or "","item:(%d+).+%[(.+)%]")
					itemName,_,_,_,_,itemType,itemStackCount,equipSlot,itemTexture = GetItemInfo(itemID or "")
					local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemID2 = GetContainerItemInfo(i, j)					
								
					if itemName and string.lower(itemName) == string.lower(name) and ((itemType == "Devices" and equipSlot == "") or itemType == "Explosives" or itemType == "Consumable")  then
						
						if not item then--not ConsumeBar.Consumes[itemName] and not item then
							item = {}
							item["count"] = 0
							item["bagslots"] = {}
							item["link"] = itemLink
							item["name"] = itemName
						end
						
						--local bagslot = 
						table.insert(item["bagslots"], {["bag"] = i, ["slot"] = j})
	
						item["count"] = item["count"] + count
						item["texture"] = itemTexture
						item["stack"] = itemStackCount
						
					end
				end
			end
	end

	
	--if not item then
		--print("ERROR "..name)
		--message(name)
	--end
	
	return item
	

end




function ConsumeBar.UseItem(barPos)

	if ConsumeBar.Bar[barPos] and ConsumeBar.Bar[barPos]["name"] then
		local itemName = ConsumeBar.Bar[barPos]["name"]
		
		local item = ConsumeBar.ItemInfo[itemName]
		if item then
			if getTableSize(item["bagslots"]) > 0 then
				local bag = item["bagslots"][1]["bag"]--ConsumeBar.ItemInfo[itemName]["bag"]
				local slot = item["bagslots"][1]["slot"]--ConsumeBar.ItemInfo[itemName]["slot"]
		
				UseContainerItem(bag,slot)
			end
		end
	end

end



--For each item in each bag, add to {name : info} map
--Return map
function ConsumeBar.GetAllItemInfo()

	local items = {}
	local item
		
	local itemLink,itemID,itemName,equipSlot,itemTexture

	
	for i=0,4 do --for each bag
			for j=1,GetContainerNumSlots(i) do --for each slot in bag
				itemLink = GetContainerItemLink(i,j)
				
				if itemLink then
					_,_,itemID,itemName = string.find(GetContainerItemLink(i,j) or "","item:(%d+).+%[(.+)%]")
					itemName,_,_,_,_,itemType,itemStackCount,equipSlot,itemTexture = GetItemInfo(itemID or "")
					local texture, count, locked, quality, readable, lootable, link, isFiltered, hasNoValue, itemID2 = GetContainerItemInfo(i, j)					
								
					if (itemType == "Devices" and equipSlot == "") or itemType == "Explosives" or itemType == "Consumable"  then
						
						if not items[itemName] then--not ConsumeBar.Consumes[itemName] and not item then
							items[itemName] = {}
							items[itemName]["count"] = 0
							items[itemName]["bagslots"] = {}
							items[itemName]["link"] = itemLink
							items[itemName]["name"] = itemName
						end
						
						--local bagslot = 
						table.insert(items[itemName]["bagslots"], {["bag"] = i, ["slot"] = j})
	
						items[itemName]["count"] = items[itemName]["count"] + count
						items[itemName]["texture"] = itemTexture
						items[itemName]["stack"] = itemStackCount
						
					end
				end
			end
	end

	
	return items
	
end



--Optimize this
function ConsumeBar.UpdateItemInfo()

	for name, itemInfo in ConsumeBar.ItemInfo do
		--ConsumeBar.ItemInfo[name] = ConsumeBar.GetItemInfo(name)
		
		local item = ConsumeBar.GetItemInfo(name)
		
		if not item then --Item no longer found in inventory
			ConsumeBar.ItemInfo[name]["count"] = 0
			ConsumeBar.ItemInfo[name]["bagslots"] = {}
			
		else --Item in inventory, info should be up to date
			ConsumeBar.ItemInfo[name] = ConsumeBar.GetItemInfo(name)
		end
		
	end
	

end

--For frames loaded from file, the first text doesnt disappear. New items added in the current session does override correctly
--Optimize this
function ConsumeBar.UpdateFrames()
	
	--slot is a bad name for this, overlap with item info slot
	for index,slot in ConsumeBar.Bar do
		local frame = slot["frame"] 
		local itemName = slot["name"]
		
		--Triggered only if PutItem has been called on a frame
		if itemName then
			
			ConsumeBar.SetFrameCooldown(frame, ConsumeBar.ItemInfo[itemName])
		
			ConsumeBar.SetFrameItemQuantityText(frame, ConsumeBar.ItemInfo[itemName])
			

			local frameIcon = getglobal(frame:GetName() .. "Icon")
			if ConsumeBar.ItemInfo[itemName]["count"] == 0 then
				frameIcon:SetVertexColor(0.4, 0.4, 0.4)
			else
				frameIcon:SetVertexColor(1.0,1.0,1.0)
			end
			
			
		end
	end

end


function ConsumeBar.CreateConsumeMenu()

	ConsumeBar.MenuFrame = CreateFrame("Frame","ConsumeBarMenuFrame",ConsumeBar.MainFrame,nil)
	ConsumeBar.MenuFrame:SetPoint("BOTTOMLEFT", ConsumeBar.MainFrame, "TOPLEFT", 0, 0)
	ConsumeBar.MenuFrame:SetWidth(1) 
	ConsumeBar.MenuFrame:SetHeight(1)
	
	ConsumeBar.MenuFrame.Frames = {}
	
	--ConsumeBar.MenuFrame:SetScript("OnUpdate", function() print("E"..elapsed) end)

	
	ConsumeBar.MenuFrame:Hide()
	
	--print("Created Menu")
	
end


--CENTER THE MENU
function ConsumeBar.UpdateConsumeMenu(targetFrame)


	local items = ConsumeBar.GetAllItemInfo()
	
	for name, item in items do
		ConsumeBar.ItemInfo[name] = item
	end


	i = 1
	for name, item in ConsumeBar.ItemInfo do
		if item["count"] > 0 then
			
			local frame
			if not ConsumeBar.MenuFrame.Frames[i] then
				frame = CreateFrame("Button", "ConsumeBarMenuFrame_"..i, ConsumeBar.MenuFrame, "ActionButtonTemplate")
				
				frame:SetPoint("LEFT", (getTableSize(ConsumeBar.MenuFrame.Frames) * FRAME_SIZE),0) --40x40?
				
				table.insert(ConsumeBar.MenuFrame.Frames, frame)
			
			end
			
			
			frame = ConsumeBar.MenuFrame.Frames[i]
			

			ConsumeBar.SetFrameTexture(frame, item)
			ConsumeBar.SetFrameItemQuantityText(frame, item)
			ConsumeBar.SetFrameCooldown(frame, item)
	
	
			--SCRIPTS
	
			--Use item on click
			frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
			local nameClosure = name
			frame:SetScript("OnClick", function()
				if targetFrame then
					for k, v in ConsumeBar.Bar do
						if targetFrame == v["frame"] then
							--ConsumeBar.PutItem(name, n)
							ConsumeBar.AddItem(nameClosure, k)
							break
						end
					end
				end
			
				--Close GameToolTip
				ConsumeBar.HideConsumeMenu()
			end)
			
			
			--Show tooltip
			local itemClosure = item
			frame:SetScript("OnEnter", function()	
				
				ConsumeBar.ResetMenuTimer()
				
				if itemClosure and getTableSize(itemClosure["bagslots"]) > 0 then
					--GameToolTip:SetPoint("BOTTOMRIGHT")
					GameTooltip:SetOwner(ConsumeBar.MainFrame,"ANCHOR_LEFT")
					GameTooltip:SetBagItem(itemClosure["bagslots"][1]["bag"],itemClosure["bagslots"][1]["slot"])
					GameTooltip:Show()
				end
			end)
			
			
			--Hide tooltip
			frame:SetScript("OnLeave", function()
				ConsumeBar.StartMenuTimer()
				GameTooltip:Hide()
			end)
	
	
			i = i + 1
		
		end
	end


end


--On button mouseover
function ConsumeBar.ShowConsumeMenu(targetFrame)

	ConsumeBar.UpdateConsumeMenu(targetFrame)

	--ConsumeBar.MenuFrame:SetParent(targetFrame)
	if targetFrame then
		ConsumeBar.MenuFrame:SetPoint("BOTTOMLEFT", targetFrame, "TOPLEFT", 0, FRAME_SIZE / 2)
	end
	
	ConsumeBar.MenuFrame:Show()

end




function ConsumeBar.HideConsumeMenu()

	ConsumeBar.MenuFrame:Hide()

end




function ConsumeBar.StartMenuTimer()
	
	ConsumeBar.MenuTimer = GetTime() 
	
	ConsumeBar.MenuFrame:SetScript("OnUpdate", function()	
		if ConsumeBar.MenuTimer then
			if GetTime() >= ConsumeBar.MenuTimer + MENU_HIDE_DELAY then
				ConsumeBar.MenuTimer = nil
				ConsumeBar.HideConsumeMenu()
				ConsumeBar.MenuFrame:SetScript("OnUpdate", nil)
			end
		end
	end)
	
end


function ConsumeBar.ResetMenuTimer()

	ConsumeBar.MenuTimer = nil
	
	ConsumeBar.MenuFrame:SetScript("OnUpdate", nil)
	
	
end











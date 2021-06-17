--TODO:
--Behavior when target is DId	
	--Casts on the DI'd target but it does nothing
	--Multiple whispers to multiple paladins kills all because of this
--DI/Sand override options
--NON TARGETTED SPELLS - mount, consecration, etc shouldn't use range check
--Judge light should add 2 spells
--Judge behaviour is weird due to the mechanic ofnot being on gcd, but requiring the first spell to apply
--Capitalization of members
--LOS/OOR
--Return error messages instead of false
--Class specific behaviors/shortcuts
--More features for item usage
--Cleanup
--Adjust whitelist via command
--Unhardcode rez check
--Follow command
-- > on nothing



EZDI = {}
EZDI.queue = {}
EZDI.itemQueue = {}
EZDI.isCasting = false
EZDI.isHighPriority = false
EZDI.Delay = 1.5
EZDI.LastCast = nil
EZDI.maxCooldown = 2


--Separate by class 
	--dispel = Cleanse or Dispel or Purge
EZDI.spellShortcuts = {
	--Paladin
	["di"] = "Divine Intervention",
	["loh"] = "Lay on Hands",
	["bop"] = "Blessing of Protection",
	["freedom"] = "Blessing of Freedom",
	["fol"] = "Flash of Light",
	["hl"] = "Holy Light",
	["heal"] = "Flash of Light",
	["kings"] = "Greater Blessing of Kings",
	["wisdom"] = "Greater Blessing of Wisdom",
	["might"] = "Greater Blessing of Might",
	["salv"] = "Greater Blessing of Salvation",
	["sanc"] = "Greater Blessing of Sanctuary",
	["light"] = "Greater Blessing of Light",
	["bubble"] = "Divine Shield",
	["sac"] = "Blessing of Sacrifice",
	["res"] = "Redemption",
	["rez"] = "Redemption",
	["hoj"] = "Hammer of Justice",
	["judge"] = "Judgement",
	
	--Druid
	["motw"] = "Mark of the Wild",
	["gotw"] = "Gift of the Wild",
	["rejuv"] = "Rejuvenation",
	["ff"] = "Faerie Fire",
	["brez"] = "Rebirth",
	["inner"] = "Innervate",
	["vate"] = "Innervate",
	
	--Priest
	["pi"] = "Power Infusion",
	["shield"] = "Power Word: Shield",
	["shackle"] = "Shackle Undead",
}


EZDI.OffensiveSpells = {
	["Faerie Fire"] = true,
	["Hammer of Justice"] = true,
	["Judgement"] = true,
	["Earth Shock"] = true,
}




EZDI.PPValues = {
			["Warrior"] = 0,
			["Rogue"] = 1,
			["Priest"] = 2,
			["Druid"] = 3,
			["Paladin"] = 4,
			["Hunter"] = 5,
			["Mage"] = 6,
			["Warlock"] = 7,
			[0] = "Greater Blessing of Wisdom",
			[1] = "Greater Blessing of Might",
			[2] = "Greater Blessing of Salvation",
			[3] = "Greater Blessing of Light",
			[4] = "Greater Blessing of Kings",
			[5] = "Greater Blessing of Sanctuary",
			[-1] = nil,
			
}



function EZDI:OnLoad() 
    -- Register events
	this:RegisterEvent("CHAT_MSG_WHISPER")
	this:RegisterEvent("SPELLCAST_START")
	this:RegisterEvent("SPELLCAST_STOP")
	
	this:RegisterEvent("SPELLCAST_FAILED") --LOS, OOR
	this:RegisterEvent("SPELLCAST_INTERRUPTED")
	--this:RegisterEvent("CHAT_MSG_ADDON")
	
	
	--NEED TO ADD THIS
	if not EZDIWhitelist then
		EZDIWhitelist = {}
	end
	
end



function EZDI:OnEvent()

	local msg = arg1
	local playerName = arg2
	
	if event == "CHAT_MSG_WHISPER" then
		if string.sub(msg,1,1) == "!" then -- '!' is the chosen symbol for specifying a command
			local cmd = nil
			local data = nil
			local cmdIndex = string.find(msg, " ")
			if cmdIndex then
				cmd = string.sub(msg,2,cmdIndex - 1)
				data = string.sub(msg,cmdIndex + 1, -1)
			else
				cmd = string.sub(msg,2,-1)
			end
			
			cmd = string.lower(cmd)
			if cmd == "" or cmd == "help" or cmd == "usage" then
				SendChatMessage("Usage:", "WHISPER" ,nil, playerName)
				SendChatMessage("Whisper a spell name to cast it. Ex. /t paladin Blessing of Protection", "WHISPER" ,nil, playerName)
				SendChatMessage("Offensive spells cast on allies will cast on ally's target.", "WHISPER" ,nil, playerName)
				SendChatMessage("To cast on a target by name, whisper Spell>Target. (no spaces around >)", "WHISPER" ,nil, playerName)
				SendChatMessage("Options:", "WHISPER" ,nil, playerName)
				SendChatMessage("!queue / !q - Get number of spells in queue", "WHISPER" ,nil, playerName)
				SendChatMessage("!cooldown / !cd Spell - Get cooldown of spell", "WHISPER" ,nil, playerName)
				SendChatMessage("!pp / !buff - Get currently assigned paladin buff", "WHISPER" ,nil, playerName)
				SendChatMessage("!item itemName / !use itemName - Use an inventory item by name", "WHISPER", nil, playerName)
				SendChatMessage("!clear - Clear all queued spells", "WHISPER" ,nil, playerName)
				SendChatMessage("!help / !usage - Help message", "WHISPER" ,nil, playerName)
				
			elseif cmd == "queue" or cmd == "q" then --Respond with number of spells in queue
				SendChatMessage(table.getn(EZDI.queue) ,"WHISPER" ,nil, playerName)
				
			elseif (cmd == "cooldown" or cmd == "cd") and data then --Respond with cooldown of spell
				local cd = EZDI:GetCooldown(EZDI.spellShortcuts[data] or data)
				if cd then
					SendChatMessage(string.format("%.1fs",cd) ,"WHISPER" ,nil, playerName)
				else
					SendChatMessage("Spell not found" ,"WHISPER" ,nil, playerName)
				end
				
			elseif cmd == "pp" or cmd == "buff" then --Respond with currently assigned PallyPower buff
				local buff = EZDI:GetPPBuffAssignment(UnitName("player"), playerName) or "No buff assigned"
				SendChatMessage(buff ,"WHISPER" ,nil, playerName)
			
			elseif cmd == "item" or cmd == "use" then --Could add cooldown message if on CD and other things
				if EZDI:FindItem(data) then
					SendChatMessage("Queueing item " .. data, "WHISPER", nil, playerName)
					--Queue item
				else
					SendChatMessage("Could not find " .. data, "WHISPER", nil, playerName)
				end
			
			elseif cmd == "clear" then
				EZDI.queue = {}
				EZDI.isCasting = false
				EZDI.isHighPriority = false
				EZDI.LastCast = nil
			elseif cmd == "debug" then
				print("Queue size: " .. table.getn(EZDI.queue))
				if table.getn(EZDI.queue) > 0 then
					print("Next spell data: ")
					print(" -Spell: "..EZDI[1][1])
					print(" -Source: "..EZDI[1][2])
					print(" -Target: "..EZDI[1][3])
				end
				print("Casting: " .. returnTF(EZDI.isCasting))
				print("IsAddonCast: " .. returnTF(EZDI.isHighPriority))
				print("Last Cast: " .. (EZDI.LastCast or ""))
			end
			
		else --Queue the spell
			local delim = string.find(msg, ">")
			if not delim then
				EZDI:QueueSpell(msg, playerName,playerName) --Add spell request to queue
			else
				local spell = string.sub(msg,1,delim-1)
				local target = string.sub(msg,delim+1,-1)
				EZDI:QueueSpell(spell, playerName,target) --Add spell request to queue with a different target
			end
		end
	
	elseif event == "SPELLCAST_START" then
		EZDI.isCasting = true
	elseif event == "SPELLCAST_STOP" then
		EZDI.isCasting = false
		EZDI.isHighPriority = false
	--[[elseif event == "SPELLCAST_FAILED" then
		print("FAILED")
		--EZDI.isCasting = false]]
	elseif event == "SPELLCAST_INTERRUPTED" then
		--print("INTERRUPTED")
		EZDI.isCasting = false
		EZDI.isHighPriority = false
	end
	
	

end


--Check for offensive assists here instead and set target here?
function EZDI:QueueSpell(spell,source, target)

	spell = EZDI.spellShortcuts[string.lower(spell)] or spell
	
	--Check if spell exists 
	local spellSlot = EZDI:FindSpellSlot(spell)
	if not spellSlot then
		return false
	end
	
	if not EZDI:CheckWhitelist(spell, source) then
		SendChatMessage("You need to request access for that spell", "WHISPER", nil, source)
		return false
	end

	--Check if spell is already queued for that player
	for i=1,table.getn(EZDI.queue) do
		if string.lower(spell) == string.lower(EZDI.queue[i][1]) and source == EZDI.queue[i][2] then
			SendChatMessage("Spell already queued" ,"WHISPER" ,nil,source);
			return false
		end
	end
	
	--Check if spell on cooldown
	local cd = EZDI:GetCooldown(spell)
	if cd > EZDI.maxCooldown then
		SendChatMessage(string.format("Spell on cooldown for %.1f seconds", cd) ,"WHISPER" ,nil,source);
		return false
	end
	
	--Check if assigned to that buff on PP
	local ppbuff = EZDI:GetPPBuffAssignment(UnitName("player"),target)
	if ppbuff and string.find(string.lower(spell),"greater blessing of") and ppbuff ~= spell then
		SendChatMessage("Not assigned to that buff" ,"WHISPER" ,nil,source);
		return false
	end

	table.insert(EZDI.queue, {spell, source, target})
	
	SendChatMessage("Queued " .. spell .. " on " .. target,"WHISPER" ,nil,source);

end




function EZDI:CastNext()

	return EZDI:CastQueuedSpell()

end


--/script TargetByName("Ironforge Guard", true)
--AssistByName("")
--Need to make sure target changes before targetting it
--If no target to start, remove target instead of targetlasttarget
--A little messy with targetting due to too many target swaps ability to cause UI lag
--Add Clear/Clean function for remove from table, targetlasttarget, etc
function EZDI:CastQueuedSpell()
	
	
	if table.getn(EZDI.queue) == 0 then
		return false
	end
	
	if (EZDI.isHighPriority and EZDI.isCasting) then
		return false
	end
	
	if EZDI.LastCast and EZDI.LastCast + EZDI.Delay > GetTime() then
		return false
	end
	
	local spell = EZDI.queue[1][1]
	local source = EZDI.queue[1][2]
	local target = EZDI.queue[1][3]
	--local category = EZDI.queue[1][4]
	
	if not target then
		return false
	end
	
	local targetID = nil
	local targetChanged = false
	
	--Reason for separate check is to accurately stun via assist in case of multiple mobs with same name.
	if EZDI:IsOffensive(spell) then
		targetID = EZDI:GetUnitID(target) 
		if targetID then
			if UnitExists(targetID.."target") and not UnitIsFriend("player", targetID.."target") then
				TargetUnit(targetID.."target")
				targetChanged = true
				targetID = "target"
			else
				table.remove(EZDI.queue,1)
				return false
			end
		end
	end

	if not targetID then
		local currentTarget = UnitName("target")
		if currentTarget ~= target then
			TargetByName(target, true)
			targetChanged = true
		end
		targetID = "target"
		
		--No target by that name found
		if string.lower(target) ~= string.lower(UnitName("target") or "") then
			EZDI:ResetTarget(targetChanged)
			table.remove(EZDI.queue,1)
			return false
		end
	end
	
	
	if not EZDI:IsCastable(targetID, spell) then --Check if spellcast is valid
		table.remove(EZDI.queue,1)
		EZDI:ResetTarget(targetChanged)
		return false
	end
	
	--cancel spell, stop event sets casting to false
	if EZDI.isCasting then --Check if in middle of cast
		SpellStopCasting()
		EZDI.isCasting = false --unneeded due to Event Handling but left in for clarity
		EZDI:ResetTarget(targetChanged)
		return false
	end
	
	--Check cooldown
	local cd = EZDI:GetCooldown(spell)
	if cd > 0 then
		EZDI:ResetTarget(targetChanged)
		return false
	end
	
	
	CastSpellByName(spell) --Attempt to cast spell --Look into CastSpell on Target
	EZDI.LastCast = GetTime()
	EZDI.isHighPriority = true
	
	EZDI:ResetTarget(targetChanged)
	
	table.remove(EZDI.queue,1)
	
	return true

end



function EZDI:ResetTarget(targetChanged)

	if targetChanged then --Change back to original target
		TargetLastTarget() 
	end 

end



function EZDI:IsCastable(targetID, spell)

	--Remove from queue and Exit if target not found in raid or target is ghost
	if not targetID or UnitIsGhost(targetID) then
		return false
	end
	
	--Only allow res spells if target is dead
	if UnitIsDead(targetID) and not EZDI:IsResurrect(spell) then
		return false
	end
	
	--Check to make sure target in same area and online
	if not UnitIsVisible(targetID) then
		return false
	end
	
	--If unit is neutral/enemy and it is a friendly spell return NOT Castable
	if not UnitIsFriend("player", targetID) and not EZDI:IsOffensive(spell) then
		return false
	end
	

	return true
	
end



function EZDI:GetUnitID(name)

	--Check Party
	for i=1,5 do
		if UnitName("party"..i) == name then
			return "party"..i
		end
	end

	--Check Raid
	for i=1,40 do
		if UnitName("raid"..i) == name then
			return "raid"..i
		end
	end

	return nil
end



function EZDI:FindSpellSlot(spellName)

	--for i=1,MAX_SKILLLINE_TABS do
	local spellSlotCount = 0
	for i=1,4 do 
		local name, texture, offset, numSpells = GetSpellTabInfo(i)
		spellSlotCount = spellSlotCount + numSpells
	end
	
	for i=spellSlotCount,1,-1 do --start from end so first result is max rank
		name, rank = GetSpellName(i, "spell");

		if string.lower(name) == string.lower(spellName) then
			return i
		end	
		
	end
	
	return nil
end


function EZDI:CheckWhitelist(spell, target)

	if EZDIWhitelist[spell] then
		for i,name in EZDIWhitelist[spell] do
			if target == name then
				return true --return true if list exists for a spell and target is in it
			end
		end
		return false --return false if the target is not in the list
	end
	
	return true --default case to allow if no list for this spell
end


function EZDI:IsResurrect(spell)

	return spell == "Redemption" or spell == "Rebirth" or spell == "Resurrection"

end




--Divine Intervention=Same Icon as Sand
--Flask of Petrification="Petrification" --Petrification same Icon as pots
--No way to make this reliable?
--Maybe monitor combat log events? 
function EZDI:IsInvulnerable(targetID, iconList)

	for i=1,32 do
		local icon, stacks = UnitBuff(targetID, i)
	end
	
	return nil
end


function EZDI:IsOffensive(spell)

	if EZDI.OffensiveSpells[spell] then
		return true
	end
	
	return false

end


function EZDI:GetCooldown(spell)
	local spellSlot = EZDI:FindSpellSlot(spell)
	if not spellSlot then 
		return nil
	end
	
	local start, duration, enabled = GetSpellCooldown(spellSlot, "spell")
	if duration == 0 then
		return 0
	end
	
	return start + duration - GetTime()
end




--Need some nil/error checks probably
--CHANGE THIS TO TAKE STRING CLASS, SO YOU CAN REQUEST FOR OTHER CLASSES?
function EZDI:GetPPBuffAssignment(paladin, target)

	if PallyPower_Assignments and PallyPower_Assignments[paladin] then
		local targetID = EZDI:GetUnitID(target)
		if targetID then
			local localizedClass, englishClass = UnitClass(targetID)
			local targetClassNum = EZDI.PPValues[localizedClass] 
			local blessing = PallyPower_Assignments[paladin][targetClassNum]
			return EZDI.PPValues[blessing]
		end
	end

	return nil

end


function returnTF(value)
	
	if value then
		return "true"
	else
		return "false"
	end

end



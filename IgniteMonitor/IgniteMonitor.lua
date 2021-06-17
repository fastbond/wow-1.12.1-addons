--Ignite Monitor


--[[

TODO
--Rounded Borders
--UI options
	--Grow up or grow down?
--Other casts
--Ignite total damage below ignite tick(redo ui)
--Difference between prediction and actual ignite
--Assign the stack number when adding an ignite, so you know which is missed. 
--Add owner, expected damage to IgniteStack[target]
--Function for calculating ignite prediction given stacks
-Vertical instead of horizontal?
--Remove/fix old IgniteTimer stuff
--Display previous ignite info for awhile
--You lose scorch timers when swapping targets
--Split into multiple files(parse.lua, etc)

PLAN:
	-UI
		-Redo layout
		-Create DebuffFrame
		-Hide icons when no target

	-Functionality
		-Dragonling stacks
		-Assign stack number when calling AddIgnite(), so you know which is missed if possible
*		-Handle partial resists, add into ignite dmg in ParseDebuff and for Stacks

		-Dragging the Stack window
		-????? stuff
		-Combat range
		
		-Change stackframe height depending on how many stacks there are
		
	-Process
		-Go through flowchart of possible scenarios, make sure logic isn't duplicated/spread
		
--]]



--Fix tables to be subset of IgniteMonitor
IgniteMonitor = {}
IgniteStacks = {} 
ScorchStacks = {}
IgniteMonitorFrame = nil
IgniteMonitor.lastUpdate = 0
IgniteMonitor.updateRate = 1 --In seconds

IgniteMonitor.Icons = {
				["Scorch"] = "Interface\\Icons\\Spell_Fire_SoulBurn",
				["Fireball"] = "Interface\\Icons\\Spell_Fire_FlameBolt",
				["Pyroblast"] = "Interface\\Icons\\Spell_Fire_Fireball02",
				["Fire Blast"] = "Interface\\Icons\\Spell_Fire_Fireball",
				["Flamestrike"] = "Interface\\Icons\\Spell_Fire_SelfDestruct",
				["Blast Wave"] = "Interface\\Icons\\Spell_Holy_Excorcism_02",
				["Ignite"] = "Interface\\Icons\\Spell_Fire_Incinerate",
				["Nightfall"] = "Interface\\Icons\\Spell_Holy_ElunesGrace", --Spell Vulnerability
				["Curse of Elements"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
				["Flame Buffet"] = "Interface\\Icons\\Spell_Fire_Fireball",
			}




function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end




SLASH_IGNITEMONITOR1, SLASH_IGNITEMONITOR2, SLASH_IGNITEMONITOR3 = '/ignitemonitor', '/ignite', '/im'; 
SlashCmdList["IGNITEMONITOR"] = function(msg)

	local msg = string.lower(msg)

	local _,_,cmd, text = string.find(msg,"([^%s]+) ?(.*)")
	
	
	if cmd == "hide" then
		IgniteMonitorFrame:Hide()
	elseif cmd == "show" then
		IgniteMonitorFrame:Show()
	end
	
end



--Not a good way to do this, but good enough for now
function IgniteMonitor:IsMageSpell(spell)

	if spell == "Fireball" or spell == "Fire Blast" or spell == "Scorch" or spell == "Pyroblast" or spell == "Flamestrike" or spell == "Blast Wave" then
		return true
	end
	
	return false

end



function IgniteMonitor:GetTarget()

	if not UnitIsFriend("player", "target") then
		return "target"
	else
		return "targettarget"
	end

end




--Add event for changing zones, areas, etc in order to guarantee old data is cleared?
function IgniteMonitor:OnLoad() 

    -- Register events
	this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE");
	
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"); --"Is afflicted by ignite" + dot ticks
	this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER"); --Auras wearing off others = "Ignite fades from X" SHORT RANGE
	
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	
	IgniteMonitor:SetupFrames()
	IgniteMonitorFrame:Show()
	
	IgniteMonitorFrame:SetScript("OnUpdate", function() 
			IgniteMonitor:OnUpdate()
		end)
	
	
end


function IgniteMonitor:OnUpdate()

	
	local t = GetTime()
	
	if t < IgniteMonitor.lastUpdate + IgniteMonitor.updateRate then --Not ready to update
		return
	end
	
	--Updating
	IgniteMonitor.lastUpdate = t
	
	IgniteMonitor:Sync()
	IgniteMonitor:UpdateFrame()


end




--OnUpdate run every 1? second, call Sync()
function IgniteMonitor:Sync()

	--Compare target debuffs to stored
	--Check ignite damage+source and compare
	
	local target = UnitName(IgniteMonitor:GetTarget())
	local debuffs = IgniteMonitor:GetTargetDebuffs({"Scorch","Nightfall","Curse of Elements","Ignite"})
	
	--Sync stored scorches with target's debuffs
	if debuffs["Scorch"] then 
		if ScorchStacks[target] then
			ScorchStacks[target]["stacks"] = debuffs["Scorch"]
		else
			ScorchStacks[target] = {["stacks"] = debuffs["Scorch"], ["time"] = nil}
		end
	else 
		IgniteMonitor:ClearScorch(target)
	end
	
	
	--Sync ignites with current debuffs
	if debuffs["Ignite"] then
		if not IgniteStacks[target] or debuffs["Ignite"] ~= table.getn(IgniteStacks[target]) then
			IgniteMonitor:ClearIgnite(target)
			for i=1,debuffs["Ignite"] do
				--Add unknown ignite
				IgniteMonitor:AddIgnite(nil, nil, target, nil, nil)
			end
		end
	elseif IgniteStacks[target] then
		IgniteMonitor:ClearIgnite(target)
	end
			
	



end




--Called every time a registered combat event happens
function IgniteMonitor:UpdateFrame()

	local target = UnitName(IgniteMonitor:GetTarget())

	local debuffs = IgniteMonitor:GetTargetDebuffs({"Scorch","Nightfall","Curse of Elements","Ignite"})
	local mods = IgniteMonitor:CalculateDebuffModifier(debuffs)
	local stacks = 0
	
	
	--Update individual stack frames
	for i=1,5 do
		if IgniteStacks[target] and IgniteStacks[target][i] then
			local stack = IgniteStacks[target][i]
			IgniteMonitorFrame.stackFrame.bars[i].icon:SetTexture(IgniteMonitor.Icons[stack["spell"]])
			IgniteMonitorFrame.stackFrame.bars[i].text:SetText((stack["damage"] or "???").." - "..(stack["source"] or "???"))
			stacks = stacks + 1
			
			IgniteMonitorFrame.stackFrame.bars[i]:Show()
		else
			IgniteMonitorFrame.stackFrame.bars[i]:Hide()
		end
	end
	
	--Scale stackframe size with amount of stacks
	--IgniteMonitorFrame.stackFrame:SetHeight(20*stacks + 1)
	
	
	--Update ignite frames
	if IgniteStacks[target] and IgniteStacks[target][1] then
		local igniteDmg = IgniteStacks[target]["baseDmg"] * mods

		IgniteMonitorFrame.igniteFrame.text:SetText(math.floor(igniteDmg).." - "..(IgniteStacks[target]["owner"] or "???"))--[1]
		
		IgniteMonitorFrame.igniteFrame.igniteTotal:SetText("( ".. IgniteStacks[target]["total"] .." )")
		
		IgniteMonitorFrame.igniteFrame.iconText:SetText(stacks)
	
		IgniteMonitorFrame.igniteFrame:SetScript("OnUpdate", function() IgniteMonitor:IgniteTimer() end) --USING OLD IGNITE TIMER, FIX
		
		--IgniteMonitorFrame.igniteTimer.iconText:SetText(stacks)
		--IgniteMonitorFrame.igniteTimer:Show()
		
		
	else --Just hide all this?
		--IgniteMonitorFrame.igniteFrame.icon:SetTexture(nil)
		IgniteMonitorFrame.igniteFrame.text:SetText("")
		IgniteMonitorFrame.igniteFrame.iconText:SetText("")
		IgniteMonitorFrame.igniteFrame.igniteTimer:SetText("")
		IgniteMonitorFrame.igniteFrame.igniteTotal:SetText("")
		
		--IgniteMonitorFrame.igniteTimer.text:SetText("")
		--IgniteMonitorFrame.igniteTimer.iconText:SetText("")
	end
	
	
	--Update scorch frame
	if ScorchStacks[target] then
		IgniteMonitorFrame.scorchTimer.iconText:SetText(ScorchStacks[target]["stacks"])
	else
		IgniteMonitorFrame.scorchTimer.text:SetText("")
		IgniteMonitorFrame.scorchTimer.iconText:SetText("")
	end
	
	
	--Update debuff frame
	if debuffs["Scorch"] then
		IgniteMonitorFrame.scorchTimer.icon:SetVertexColor(1,1,1,1)
	else
		IgniteMonitorFrame.scorchTimer.icon:SetVertexColor(.2,.2,.2,1)
	end
	
	if debuffs["Nightfall"] then
		IgniteMonitorFrame.nightfallTimer.icon:SetVertexColor(1,1,1,1)
	else
		IgniteMonitorFrame.nightfallTimer.icon:SetVertexColor(.2,.2,.2,1)
	end
	
	if debuffs["Curse of Elements"] then
		IgniteMonitorFrame.coeTimer.icon:SetVertexColor(1,1,1,1)
	else
		IgniteMonitorFrame.coeTimer.icon:SetVertexColor(.2,.2,.2,1)
	end
	
	if debuffs["Ignite"] then
		IgniteMonitorFrame.igniteFrame.icon:SetVertexColor(1,1,1,1)
	else
		IgniteMonitorFrame.igniteFrame.icon:SetVertexColor(.2,.2,.2,1)
	end
	
	
	--[[if not target then
		IgniteMonitorFrame.igniteFrame:Hide()
	else
		IgniteMonitorFrame.igniteFrame:Show()
	end]]

	

end




--Split this into multiple event handlers
function IgniteMonitor:OnEvent()

	local msg = arg1
	
	
	local source, spell, hitType, target, damage
	local eventTime = GetTime()

	
	--Any spell hitting a target
	if event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE" or event == "CHAT_MSG_SPELL_PARTY_DAMAGE" then 
		source, spell, hitType, target, damage = IgniteMonitor:ParseSpellDamage(msg)
	
	--Ignite application and tick
	--[TARGET] is afflicted by [SPELL]([STACKS]).
	--[TARGET] suffers [DAMAGE] Fire damage from [SOURCE] [SPELL]
	--Need to check resist damage for actual ignite damage if partial resist
	elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
		target, damage, source = IgniteMonitor:ParseDebuff(msg)
	
	--Ignite/Scorch fades
	--[SPELL] fades from [TARGET].
	elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then 
		spell, target = IgniteMonitor:ParseDebuffFade(msg)
		
	--Unit dies
	elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
		_,_,target = string.find(msg, "(.+) dies.")
		IgniteMonitor:ClearIgnite(target)
		IgniteMonitor:ClearScorch(target)
		
	--Player leaves combat
	elseif event == "PLAYER_REGEN_ENABLED" then 
		IgniteMonitor:ClearIgnite()
		IgniteMonitor:ClearScorch()
		
	elseif event == "PLAYER_TARGET_CHANGED" then	
		IgniteMonitor:Sync()
		--IgniteMonitor:UpdateFrame()
	end
	
	--If event = targte change, then recheck stacks - Sync()
	
	IgniteMonitor:UpdateFrame()
	

end


function IgniteMonitor:ParseSpellDamage(msg)

	local _,_,source, spell, hitType, target, damage,_ = string.find(msg,"([^%s]-)'?s? (.+) (crits) (.+) for (%d+) (Fire damage)(.*)"); 
		
	if not spell then --If above parse failed(not a crit)
		_,_,source, spell, hitType, target, damage,_ = string.find(msg,"([^%s]-)'?s? (.+) (hits) (.+) for (%d+) (Fire damage)(.*)");
	end
	
	if source == "Your" then
		source = UnitName("player")
	end
	
	if hitType == "crits" and IgniteMonitor:IsMageSpell(spell) then 
		IgniteMonitor:AddIgnite(source, spell, target, damage, eventTime)
		IgniteStacks[target]["timer"] = GetTime()
	end

	if spell == "Scorch" then
		IgniteMonitor:AddScorch(source, spell, target, damage, eventTime)
		IgniteMonitorFrame.scorchTimer:SetScript("OnUpdate", function() IgniteMonitor:ScorchTimer() end)
	end
	
	return source, spell, hitType, target, damage

end


--NEED TO HANDLE RESISTS AND ADD INTO DAMAGE
function IgniteMonitor:ParseDebuff(msg)

	_,_,target, damage, source= string.find(msg, "(.+) suffers (%d+) Fire damage from ([^%s]-)'?s? Ignite.")
		
	if not target then
		return
	end
		
	if source == "your" then
		source = UnitName("player")
	end
		
	if IgniteStacks[target] then	
		IgniteStacks[target]["total"] = IgniteStacks[target]["total"] + damage
	end
	
	
	--Consider modifying so it tracks even when not currently targetting
	--Attempt to sync an ignite tick with currently stored ignite data.  Consider moving this to Sync()
	--Only attempts to sync current target
	if target == UnitName(IgniteMonitor:GetTarget()) then
		
		--Get debuffs and modifier
		local debuffs = IgniteMonitor:GetTargetDebuffs({"Scorch","Nightfall","Curse of Elements","Ignite"})
		local modifier = IgniteMonitor:CalculateDebuffModifier(debuffs)
		
		local owner = nil
		local predicted = -10000 --Arbitrary error value.  Ignite would need to be above 200k/tick to be considered correct at .05 threshold
		if IgniteStacks[target] then
			owner = IgniteStacks[target]["owner"]   
			predicted = IgniteStacks[target]["baseDmg"]
		
		
		local threshold = .05
		local actual = damage / modifier
		local dif = math.abs(predicted - actual) / actual
		
		--[[
		--Consider moving this all to Sync() function and instead just setting a needsSync flag here
		if debuffs["Ignite"] and (not IgniteStacks[target] or owner ~= source or dif > threshold) then
		
			--Reset Ignite stacks and add unknown data
			IgniteMonitor:ClearIgnite(target)
			
			for i=1,debuffs["Ignite"] do
				IgniteMonitor:AddIgnite(nil, nil, target, nil, nil)
			end
			
			IgniteStacks[target]["baseDmg"] = actual
			IgniteStacks[target]["owner"] = source
		end
		]]
		
		IgniteStacks[target]["baseDmg"] = actual
		IgniteStacks[target]["owner"] = source
		end
	end
	
	return target, damage, source

end


function IgniteMonitor:ParseDebuffFade(msg)

	_,_,spell, target = string.find(msg, "(.+) fades from (.+)%.") 
	
	if spell == "Ignite" then
		IgniteMonitor:ClearIgnite(target)
	elseif spell == "Fire Vulnerability" then --Scorch debuff
		IgniteMonitor:ClearScorch(target)
	end


	return spell, target

end




function IgniteMonitor:AddIgnite(source, spell, target, damage, critTime)
	
	if not IgniteStacks[target] then
		IgniteStacks[target] = {}
		IgniteStacks[target]["total"] = 0
		IgniteStacks[target]["baseDmg"] = nil
		IgniteStacks[target]["owner"] = nil
	end
	
	--If not already 5 ignite stacks
	if not IgniteStacks[target][5] then
		table.insert(IgniteStacks[target], {["time"] = critTime, ["source"] = source, ["spell"] = spell, ["damage"] = damage})	
		
		if table.getn(IgniteStacks[target]) == 1 then
			IgniteStacks[target]["owner"] = source
		end
		
		IgniteStacks[target]["baseDmg"] = IgniteMonitor:CalculateIgniteDamage(IgniteStacks[target], nil)
	end
	
	

end


function IgniteMonitor:ClearIgnite(target)

	if not target then
		IgniteStacks = nil
		IgniteStacks = {}
	elseif IgniteStacks[target] then
		IgniteStacks[target] = nil
	end

end



function IgniteMonitor:CalculateIgniteDamage(stacks, modifier)

	modifier = modifier or 1

	local damage = 0
	for i=1,5 do
		if stacks[i] then
			damage = damage + (0.2 * (stacks[i]["damage"] or 0))
		end
	end
	
	damage = damage * modifier
	
	return damage

end


function IgniteMonitor:AddScorch(source, spell, target, damage, scorchTime)
	
	if not ScorchStacks[target] then
		ScorchStacks[target] = {["timer"] = nil, ["stacks"] = 0}
	end
	
	ScorchStacks[target]["stacks"] = 1 + ScorchStacks[target]["stacks"]
	if ScorchStacks[target]["stacks"] > 5 then
		ScorchStacks[target]["stacks"] = 5
	end
	
	ScorchStacks[target]["timer"] = GetTime()

end


function IgniteMonitor:ClearScorch(target)

	if not target then
		ScorchStacks = nil
		ScorchStacks = {}
	
	elseif ScorchStacks[target] then
		ScorchStacks[target] = nil
	end
	

end




function IgniteMonitor:GetTargetDebuffs(debuffNames)

	local debuffInfo = {}
	
	for i=1,16 do
		local icon, stacks, school = UnitDebuff(IgniteMonitor:GetTarget(), i)
		
		for j,debuff in debuffNames do
			if IgniteMonitor.Icons[debuff] == icon then
				debuffInfo[debuff] = stacks
				break
			end
		end

	end
	
	return debuffInfo

end



function IgniteMonitor:CalculateDebuffModifier(debuffs)

	if debuffs == nil then
		return
	end

	local modifier = 1.0
	
	if debuffs["Scorch"] then
		local stacks = debuffs["Scorch"]
		modifier = modifier * (1 + (stacks * 0.03))
	end
			
	if debuffs["Nightfall"] then --Spell Vulnerability
		modifier = modifier * 1.15
	end
			
	if debuffs["Curse of Elements"] then
		modifier = modifier * 1.10
	end
		
	return modifier
	
end


function IgniteMonitor:HasDebuff(spell)

	debuffs = IgniteMonitor:GetTargetDebuffs(spell)
	if debuffs[spell] then
		return debuffs[spell]
	end
	
	return nil
end



function IgniteMonitor:ScorchTimer()

	local decimalPlaces = 0
	local scorchDuration = 30.0
	
	local target = UnitName(IgniteMonitor:GetTarget())
	
	if target and ScorchStacks[target] and ScorchStacks[target]["timer"] then
		local tdif = GetTime() - ScorchStacks[target]["timer"]
		
		tdif = scorchDuration - tdif
		
		if tdif < 0 then
			--IgniteMonitorFrame.scorchTimer:Hide()
			IgniteMonitor:ClearScorch(target)
			IgniteMonitorFrame.scorchTimer.text:SetText("")
			IgniteMonitorFrame.scorchTimer.iconText:SetText("")
			IgniteMonitor:UpdateFrame()
			IgniteMonitorFrame.scorchTimer:SetScript("OnUpdate", nil)
			return
		end
		
		local t = math.floor((tdif * (10.0 ^ decimalPlaces)) + 0.5)
		t = t / (10.0 ^ decimalPlaces)
		IgniteMonitorFrame.scorchTimer.text:SetText(t)
	end

end


function IgniteMonitor:IgniteTimer()

	local decimalPlaces = 1
	local igniteDuration = 4.0
	
	local target = UnitName(IgniteMonitor:GetTarget())
	
	if target and IgniteStacks[target] and IgniteStacks[target]["timer"] then
		local tdif = GetTime() - IgniteStacks[target]["timer"]
		
		tdif = igniteDuration - tdif
		
		if tdif < 0 then
			IgniteMonitor:ClearIgnite(target)
			--IgniteMonitorFrame.igniteTimer.text:SetText("")
			--IgniteMonitorFrame.igniteTimer.iconText:SetText("")
			
			IgniteMonitor:UpdateFrame()
			IgniteMonitorFrame.igniteTimer:SetScript("OnUpdate", nil)
			return
		end
		
		local t = math.floor((tdif * (10.0 ^ decimalPlaces)) + 0.5)
		t = t / (10.0 ^ decimalPlaces)
		
		--IgniteMonitorFrame.igniteTimer.text:SetText(t)
		IgniteMonitorFrame.igniteFrame.igniteTimer:SetText(t)
	end

end




function IgniteMonitor:SetupFrames()

	IgniteMonitorFrame = CreateFrame("Frame", "IgniteMonitor_MainFrame", UIParent)
	local frame = IgniteMonitorFrame
	frame:Hide()

	--Set Size
	frame:SetWidth(200)
	frame:SetHeight(60)

	--Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 500)
	
	--Set background
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		--edgeFile = "Interface\\AddOns\\BigWigs\\Textures\\otravi-semi-full-border", edgeSize = 32,
		--edgeFile = "", edgeSize = 32,
		--insets = {left = 1, right = 1, top = 20, bottom = 1},
	})
	frame:SetBackdropBorderColor(1.0,1.0,1.0)
	frame:SetBackdropColor(24/255, 24/255, 24/255, .5)
	
	--Misc
	frame:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
	frame:SetClampedToScreen(true)
	
	--Movement
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(true)
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function()  this:StopMovingOrSizing() end)
	
	
	
	--Ignite Tracking Frame
	--Should add text entries for player, tick damage, and total damage
	local igniteFrame = CreateFrame("Frame", "IgniteMonitor_IgniteFrame", frame)
	igniteFrame:Hide()
	
	igniteFrame:ClearAllPoints()
	igniteFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	igniteFrame:SetWidth(200)
	igniteFrame:SetHeight(60)

	igniteFrame:SetFrameStrata("LOW")
	
	igniteFrame.icon = igniteFrame:CreateTexture("IgniteMonitor_IgniteIconTexture")
	igniteFrame.icon:SetTexture(IgniteMonitor.Icons["Ignite"]) 
	igniteFrame.icon:SetVertexColor(.2,.2,.2,1)
	igniteFrame.icon:SetPoint("TOPRIGHT", igniteFrame, "TOPRIGHT", -2, -2)
	igniteFrame.icon:SetWidth(25)
	igniteFrame.icon:SetHeight(25)
	
	igniteFrame.iconText = igniteFrame:CreateFontString(nil, "OVERLAY")
	igniteFrame.iconText:ClearAllPoints()
	igniteFrame.iconText:SetPoint("BOTTOMRIGHT", igniteFrame.icon, "BOTTOMRIGHT", 0, 0)
	igniteFrame.iconText:SetJustifyH("LEFT")
	igniteFrame.iconText:SetFont("Fonts\\FRIZQT__.TTF", 12, "THINOUTLINE")
	igniteFrame.iconText:SetText("")
	
	igniteFrame.text = igniteFrame:CreateFontString(nil, "OVERLAY")
	igniteFrame.text:ClearAllPoints()
	igniteFrame.text:SetPoint("RIGHT", igniteFrame.icon, "LEFT",-2,2)
	igniteFrame.text:SetTextColor(1, 1, 1, 1)
	igniteFrame.text:SetJustifyH("RIGHT")
	igniteFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 13, "THINOUTLINE")
	igniteFrame.text:SetText("")
	
	igniteFrame.igniteTimer = igniteFrame:CreateFontString(nil, "OVERLAY")
	igniteFrame.igniteTimer:ClearAllPoints()
	igniteFrame.igniteTimer:SetPoint("TOP", igniteFrame.icon, "BOTTOM", 0, -2)
	igniteFrame.igniteTimer:SetTextColor(1,1,1,1)
	igniteFrame.igniteTimer:SetJustifyH("Center")
	igniteFrame.igniteTimer:SetFont("Fonts\\FRIZQT__.TTF", 12, "THINOUTLINE")
	igniteFrame.igniteTimer:SetText("234")
	
	igniteFrame.igniteTotal = igniteFrame:CreateFontString(nil, "OVERLAY")
	igniteFrame.igniteTotal:ClearAllPoints()
	igniteFrame.igniteTotal:SetPoint("TOP", igniteFrame.icon, "BOTTOM",-80,-2)
	igniteFrame.igniteTotal:SetTextColor(1, 1, 1, 1)
	igniteFrame.igniteTotal:SetJustifyH("Center")
	igniteFrame.igniteTotal:SetFont("Fonts\\FRIZQT__.TTF", 11, "THINOUTLINE")
	igniteFrame.igniteTotal:SetText("")
	
	frame.igniteFrame = igniteFrame
	frame.igniteFrame:Show()
	
	
	--local debuffFrame = CreateFrame("Frame", "IgniteMonitor_DebuffFrame", frame)
	--debuffFrame:Hide()
	

	
	local scorchTimer = CreateFrame("Frame", "IgniteMonitor_ScorchTimerFrame", frame)
	scorchTimer:Hide()
	
	scorchTimer:ClearAllPoints()
	scorchTimer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	scorchTimer:SetWidth(198)
	scorchTimer:SetHeight(20)
	
	scorchTimer:SetFrameStrata("LOW")
	
	scorchTimer.icon = scorchTimer:CreateTexture("IgniteMonitor_ScorchTimerIcon")
	scorchTimer.icon:SetTexture(IgniteMonitor.Icons["Scorch"])
	scorchTimer.icon:SetVertexColor(.2,.2,.2,1)
	--scorchTimer.icon:SetDesaturated(1)
	scorchTimer.icon:SetPoint("LEFT", scorchTimer, "LEFT", 0, 0)
	scorchTimer.icon:SetWidth(18)
	scorchTimer.icon:SetHeight(18)
	
	scorchTimer.iconText = scorchTimer:CreateFontString(nil, "OVERLAY")
	scorchTimer.iconText:ClearAllPoints()
	scorchTimer.iconText:SetPoint("BOTTOMRIGHT", scorchTimer.icon, "BOTTOMRIGHT", 0, 0)
	scorchTimer.iconText:SetJustifyH("LEFT")
	scorchTimer.iconText:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	scorchTimer.iconText:SetText("")
	
	scorchTimer.text = scorchTimer:CreateFontString(nil, "OVERLAY")
	scorchTimer.text:ClearAllPoints()
	scorchTimer.text:SetPoint("LEFT", scorchTimer.icon, "RIGHT", 5, 0)
	scorchTimer.text:SetJustifyH("LEFT")
	scorchTimer.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	scorchTimer.text:SetText("")
	
	scorchTimer:SetScript("OnUpdate", nil)
	scorchTimer:Show()
	
	frame.scorchTimer = scorchTimer
	
	
	local nightfallTimer = CreateFrame("Frame", "IgniteMonitor_nightfallTimerFrame", frame)
	nightfallTimer:Hide()
	
	nightfallTimer:ClearAllPoints()
	nightfallTimer:SetPoint("TOPLEFT", frame.scorchTimer, "BOTTOMLEFT", 0, 0)
	nightfallTimer:SetWidth(198)
	nightfallTimer:SetHeight(20)
	
	nightfallTimer:SetFrameStrata("LOW")
	
	nightfallTimer.icon = nightfallTimer:CreateTexture("IgniteMonitor_nightfallTimerIcon")
	nightfallTimer.icon:SetTexture(IgniteMonitor.Icons["Nightfall"])
	nightfallTimer.icon:SetVertexColor(.2,.2,.2,1)
	--nightfallTimer.icon:SetDesaturated(1)
	nightfallTimer.icon:SetPoint("LEFT", nightfallTimer, "LEFT", 0, 0)
	nightfallTimer.icon:SetWidth(18)
	nightfallTimer.icon:SetHeight(18)
	
	nightfallTimer.iconText = nightfallTimer:CreateFontString(nil, "OVERLAY")
	nightfallTimer.iconText:ClearAllPoints()
	nightfallTimer.iconText:SetPoint("BOTTOMRIGHT", nightfallTimer.icon, "BOTTOMRIGHT", 0, 0)
	nightfallTimer.iconText:SetJustifyH("LEFT")
	nightfallTimer.iconText:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	nightfallTimer.iconText:SetText("")
	
	nightfallTimer.text = nightfallTimer:CreateFontString(nil, "OVERLAY")
	nightfallTimer.text:ClearAllPoints()
	nightfallTimer.text:SetPoint("LEFT", nightfallTimer.icon, "RIGHT", 5, 0)
	nightfallTimer.text:SetJustifyH("LEFT")
	nightfallTimer.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	nightfallTimer.text:SetText("")
	
	nightfallTimer:SetScript("OnUpdate", nil)
	nightfallTimer:Show()
	
	frame.nightfallTimer = nightfallTimer
	
	
	
	local coeTimer = CreateFrame("Frame", "IgniteMonitor_coeTimerFrame", frame)
	coeTimer:Hide()
	
	coeTimer:ClearAllPoints()
	coeTimer:SetPoint("TOPLEFT", frame.nightfallTimer, "BOTTOMLEFT", 0, 0)
	coeTimer:SetWidth(198)
	coeTimer:SetHeight(20)
	
	coeTimer:SetFrameStrata("LOW")
	
	coeTimer.icon = coeTimer:CreateTexture("IgniteMonitor_coeTimerIcon")
	coeTimer.icon:SetTexture(IgniteMonitor.Icons["Curse of Elements"])
	coeTimer.icon:SetVertexColor(.2,.2,.2,1)
	--coeTimer.icon:SetDesaturated(1)
	coeTimer.icon:SetPoint("LEFT", coeTimer, "LEFT", 0, 0)
	coeTimer.icon:SetWidth(18)
	coeTimer.icon:SetHeight(18)
	
	coeTimer.iconText = coeTimer:CreateFontString(nil, "OVERLAY")
	coeTimer.iconText:ClearAllPoints()
	coeTimer.iconText:SetPoint("BOTTOMRIGHT", coeTimer.icon, "BOTTOMRIGHT", 0, 0)
	coeTimer.iconText:SetJustifyH("LEFT")
	coeTimer.iconText:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	coeTimer.iconText:SetText("")
	
	coeTimer.text = coeTimer:CreateFontString(nil, "OVERLAY")
	coeTimer.text:ClearAllPoints()
	coeTimer.text:SetPoint("LEFT", coeTimer.icon, "RIGHT", 5, 0)
	coeTimer.text:SetJustifyH("LEFT")
	coeTimer.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	coeTimer.text:SetText("")
	
	coeTimer:SetScript("OnUpdate", nil)
	coeTimer:Show()
	
	frame.coeTimer = coeTimer
	
	
	
	local igniteTimer = CreateFrame("Frame", "IgniteMonitor_igniteTimerFrame", frame)
	igniteTimer:Hide()
	
	igniteTimer:ClearAllPoints()
	igniteTimer:SetPoint("TOPLEFT", frame.nightfallTimer, "BOTTOMLEFT", 0, 0)
	igniteTimer:SetWidth(198)
	igniteTimer:SetHeight(20)
	
	igniteTimer:SetFrameStrata("LOW")
	
	igniteTimer.icon = igniteTimer:CreateTexture("IgniteMonitor_igniteTimerIcon")
	igniteTimer.icon:SetTexture(IgniteMonitor.Icons["Curse of Elements"])
	igniteTimer.icon:SetPoint("LEFT", igniteTimer, "LEFT", 0, 0)
	igniteTimer.icon:SetWidth(18)
	igniteTimer.icon:SetHeight(18)
	
	igniteTimer.iconText = igniteTimer:CreateFontString(nil, "OVERLAY")
	igniteTimer.iconText:ClearAllPoints()
	igniteTimer.iconText:SetPoint("BOTTOMRIGHT", igniteTimer.icon, "BOTTOMRIGHT", 0, 0)
	igniteTimer.iconText:SetJustifyH("LEFT")
	igniteTimer.iconText:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	igniteTimer.iconText:SetText("")
	
	igniteTimer.text = igniteTimer:CreateFontString(nil, "OVERLAY")
	igniteTimer.text:ClearAllPoints()
	igniteTimer.text:SetPoint("LEFT", igniteTimer.icon, "RIGHT", 5, 0)
	igniteTimer.text:SetJustifyH("LEFT")
	igniteTimer.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
	igniteTimer.text:SetText("")
	
	igniteTimer:SetScript("OnUpdate", nil)
	
	frame.igniteTimer = igniteTimer
	
	
	
	
	frame.stackFrame = CreateFrame("Frame", "IgniteMonitor_StackFrame", frame)
	frame.stackFrame:Hide()
	frame.stackFrame:SetWidth(200)
	frame.stackFrame:SetHeight(100)
	frame.stackFrame:ClearAllPoints()
	frame.stackFrame:SetPoint("BOTTOM", frame, "TOP", 0, 0)
	frame.stackFrame:SetFrameStrata("LOW")
	frame.stackFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		--edgeFile = "Interface\\AddOns\\BigWigs\\Textures\\otravi-semi-full-border", edgeSize = 32,
		--edgeFile = "", edgeSize = 32,
		--insets = {left = 1, right = 1, top = 20, bottom = 1},
	})
	frame.stackFrame:SetBackdropBorderColor(1.0,1.0,1.0)
	frame.stackFrame:SetBackdropColor(24/255, 24/255, 24/255, .5)
	frame.stackFrame:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
	

	
	--Tick Bar Setup
	frame.stackFrame.bars = {}
	for i=1, 5 do
		local bar = CreateFrame("Frame", "IgniteMonitor_StackBar"..i, frame.stackFrame)
		bar:Hide()
		bar:ClearAllPoints()
		if i==1 then
			bar:SetPoint( "BOTTOM", frame.stackFrame, "BOTTOM", 0, 0)
		else
			bar:SetPoint("BOTTOM", frame.stackFrame.bars[i-1], "TOP", 0, 0)
		end
		bar:SetFrameStrata("LOW") --Above Background level base
		bar:SetWidth(198)
		bar:SetHeight(20)
		
		bar.icon = bar:CreateTexture("IgniteMonitor_IgniteBarIconTexture"..i)
		bar.icon:SetTexture("")
		bar.icon:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 2, -2)
		bar.icon:SetWidth(16)
		bar.icon:SetHeight(16)
		
		bar.text = bar:CreateFontString(nil, "OVERLAY")
		bar.text:ClearAllPoints()
		bar.text:SetPoint("RIGHT", bar.icon, "LEFT",-4,0)
		bar.text:SetTextColor(1, 1, 1, 1)
		bar.text:SetJustifyH("RIGHT")
		bar.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
		bar.text:SetText("")
	
		frame.stackFrame.bars[i] = bar
		
	end
	
	frame:SetScript("OnMouseUp", function()  if this.stackFrame:IsShown() then this.stackFrame:Hide() else this.stackFrame:Show() end end)
	
	
	
	
end





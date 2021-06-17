--[[
TODO
1) Implement bars for each target being tracked
	X) Add frame for timer bars
	X) Figure out how to display a timer bar
	X) Display a timer bar for each target
	1.4) Spark+Blend
	1.X) PG 265 of http://garde.sylvanas.free.fr/ressources/Guides/Macros-Addons/Beginning%20Lua%20with%20World%20of%20Warcraft%20Add%20ons.pdf
2) Expand event handling to check for:
	X) Target changed
	X) X faded from Y
	X) X is afflicted by Y
	X) Drop combat
	X) Resist
	X) Evade
	2.4) X died
		-Keep dead mobs for X seconds?
	2.8) Immune
	A) Issues:
		1) Mob resets = Empty timer, regardless of other mobs of same name
			-If not in combat on evade, clear bars?
		2) Mob dies, timer stays
		3) Zone change
3) Handle forms properly
	X) Form logic
	X) Drop form if needed
	X) Cast proper spell
4) Saved Variables/Settings
	X) Save a variable table
	X) Positions
	X) Lock
	X) Chain
	X) Show/hide each part
	4.6) Size/scale
	4.7) Colors + Transparency option
5) Targetting
	A) Target selection/naming.  Should only determine target+name once on cast, not on resolution
	X) Max chain
	5.2) Avoid targetting loops
	5.3) FF target by scanning UnitName of target of raid members
	5.4) Other creative targetting methods
	5.5) Fix reverts target if pressing shortly after target change
6) Issues
	6.1) Ignore enemy applying FF to ally
	6.2) Fix unlocked bounding box for timer bars
	6.3) Sanity check
		-FF on evade when not in combat isnt dropped
	6.4) With multiple mobs, timer is reset when they reset
	6.5) If not in combat on evade, clear bars?
	6.6) Don't drop feral form if out of range
	6.7) Show Feral Fire CD somehow?
	6.8) Clear function
	6.9) Zone In/Out
	A) Flash red on failure
	B) Stop unselecting target after swap
		-targettarget is delayed
		-https://wow.gamepedia.com/UNIT_TARGET
7) Addon communication channel
	7.1) Figure out how this works
	7.2) Implement
6) Test
	X) Test feral stuff
	4.2) Test target of target chaining
7) Cleanup
	5.1) Clean comments
	X) Add options
	5.3) Redo logic for bar stuff
	5.4) Move colors etc to variables
	5.5) Fix FFTooltip/handle naming
	5.6) Fix naming of bars/timers
	5.7) Reorder functions
8) FF Marks(Skull,X,Square,etc)
9) Multiple mobs same name(Anub adds etc)
10) Sanity check every X frames
	10.1) Keeping things from old combats
	10.2) Keep dead mobs for X seconds
11) Click bars to recast
	-TargetByName("name", exactmatch)
12) Flash bar red on failure
13) Tooltip option
14) Option for max bars
15) show icon only when target is missing ff
/script print(GetCVar("gxrefresh"))
RestartGx()
https://wowwiki.fandom.com/wiki/CVar_gxRefresh
]]

--Multiple counts for TF, or multiple entries?

FF = {}
FF.frame = nil
FF.iconSize = 35

FF.lastUpdate = nil
FF.updateRate = 0.1

FF.spells = {"Faerie Fire", "Faerie Fire (Feral)"} 
FF.icon = "Interface\\Icons\\Spell_Nature_FaerieFire"
FF.duration = 40 --in seconds

FF.buffTooltip = nil --for buffs

FF.timers = {}
FF.spellIDs = {}
FF.targetName = nil
FF.targetTimerBkp = nil

FF.bars = {}
FF.maxBars = 8
FF.barHeight = 15
FF.barWidth = 185
FF.barSpacingVert = 0
--FF.barSpacingHoriz = 0
FF.barTimerTextIndent = 15
FF.barTextIndent = 50

FF.targetChaining = 3

FF_Settings = {
	["iconScale"] = 1.0,
	["iconX"] = 500,
	["iconY"] = 500,
	["iconEnabled"] = true,
	
	["timersScale"] = 1.0,
	["timersX"] = 500,
	["timersY"] = 500,
	["timersColor"] = nil,
	["timersEnabled"] = true, --hide/show timers/bars alt
	
	["targetChaining"] = 3,
	
	["locked"] = false,
}


function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end


SLASH_FAERIEFIRE1= '/ff'; 
SlashCmdList["FAERIEFIRE"] = function(msg)
	local msg = string.lower(msg)
	local _,_,cmd, text = string.find(msg,"([^%s]+) ?(.*)")
	
	if cmd == "hide" then
		if text == "icon" then
			FF.frame:Hide()
			FF_Settings.iconEnabled = false
		elseif text == "timers" then
			FF.barFrame:Hide()
			FF_Settings.timersEnabled = false
		else
			FF.frame:Hide()
			FF.barFrame:Hide()
			FF_Settings.iconEnabled = false
			FF_Settings.timersEnabled = false
		end
	elseif cmd == "show" then
		if text == "icon" then
			FF.frame:Show()
			FF_Settings.iconEnabled = true
		elseif text == "timers" then
			FF.barFrame:Show()
			FF_Settings.timersEnabled = true
		else
			FF.frame:Show()
			FF.barFrame:Show()
			FF_Settings.iconEnabled = true
			FF_Settings.timersEnabled = true
		end
	elseif cmd == "lock" then
		FF:Lock()
	elseif cmd == "unlock" then
		FF:Unlock()
	elseif cmd == "chain" then
		FF_Settings.maxChain = tonumber(text) or FF_Settings.maxChain
	end
	
end



function FF:FF()
	return FF:CastFF()
end


function FF:CastFF()
	--Determine which FF to cast and if a shift is needed
	--Some duplicate code but wanted to make the logic obvious
	local form = FF:GetForm()
	local spell = "Faerie Fire"
	local shapeshift = false
	if form == "caster" or form == "Moonkin Form" then	--Able to cast normal FF
		spell = "Faerie Fire"
		shapeshift = false
	elseif form == "Travel Form" or form == "Aquatic Form" then
		spell = "Faerie Fire"
		shapeshift = true
	elseif FF:HasFeralFire() then
		spell = "Faerie Fire (Feral)"
		shapeshift = false
	else
		spell = "Faerie Fire"
		shapeshift = true
	end
	
	if not FF.spellIDs[spell] then
		return
	end
	
	local start, duration, enabled = GetSpellCooldown(FF.spellIDs[spell],BOOKTYPE_SPELL)
	--Check if off GCD
	if start == 0 and duration == 0 then 
		local target = FF:FindTarget()
		if target == nil or not UnitExists("target") then
			return
		end
		
		if target ~= "target" then
			TargetUnit(target)
		end
		
		 --I have no idea why this is required, but it is
		if spell == "Faerie Fire (Feral)" then 
			spell = spell .. "()"
		end
		
		CastSpellByName(spell) 
		
		if shapeshift then
			CastSpellByName(form)
		end
		
		if target ~= "target" then
			TargetLastTarget()
		end
		
		--FF:ScheduleUpdate()	
		FF.targetName = UnitName(target)
		
	
	--If on GCD, use shift alt GCD if needed
	elseif shapeshift then	
		CastSpellByName(form)
	end
	
	

	
end



--/script print(FF:BuffScan("Mark of the Wild"))
function FF:BuffScan(buffs)
	FF.buffTooltip:SetOwner(WorldFrame) 
	for i=0,64 do
		FF.buffTooltip:SetPlayerBuff(i) 
		local buffName = FFTooltipTextLeft1:GetText()
		if buffName then
			for _,buff in buffs do
				if buffName == buff then
					FF.buffTooltip:Hide()
					return buff
				end
			end
			
		end 
	end

	FF.buffTooltip:Hide()
	return nil
end



function FF:IsFeralForm()
	for i=1,5 do
		local icon, name, active, castable = GetShapeshiftFormInfo(i);
		if active == 1 and (name == "Dire Bear Form" or name == "Cat Form" or name == "Travel Form") then
			return true
		end
	end

end



function FF:GetForm()
	for i=1,5 do
		local icon, name, active, castable = GetShapeshiftFormInfo(i);
		if active == 1 then
			return name,i
		end
	end
	return "caster",0
end



function FF:HasFeralFire()
	if FF.spellIDs["Faerie Fire (Feral)"] then
		return true
	end
	return false
end




--Avoid loops?
function FF:FindTarget()
	local target = ""
	for i=0,FF_Settings.targetChaining do
		target = target.."target"
		--print(target .. " - " .. (UnitName(target) or ""))
		if not UnitIsFriend(target, "player") then
			return target
		end
	end
	return nil
end




--Should add event for changing zones, areas, etc in order to clear old data
function FF:OnLoad() 
    -- Register events
	--https://wowwiki.fandom.com/wiki/AddOn_loading_process
	this:RegisterEvent("ADDON_LOADED");
	
	--Addon Chat Channel for sync
	this:RegisterEvent("CHAT_MSG_ADDON");
	
	--Spellcast events
	this:RegisterEvent("SPELLS_CHANGED");
	this:RegisterEvent("SPELLCAST_START");
	this:RegisterEvent("SPELLCAST_FAILED"); 
	this:RegisterEvent("SPELLCAST_STOP"); 
	
	--Combat events for tracking
	--https://wowwiki.fandom.com/wiki/Events/Removed
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"); --X is afflicted by Y
	this:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER"); --Auras wearing off others = "Ignite fades from X" SHORT RANGE
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
	this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE"); --Evade self FF
	this:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES");
	this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF");
	this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE")
	this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
	--this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE");
	--this:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA"); --Dispelled?

	
	FF:SetupFrames()
	
	FF.lastUpdate = GetTime()
	
	FF.frame:SetScript("OnUpdate", function() 
			FF:OnUpdate()
		end)
	
	FF.buffTooltip = CreateFrame( "GameTooltip", "FFTooltip", nil, "GameTooltipTemplate" ); -- Tooltip name cannot be nil
	FFTooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );
	-- Allow tooltip SetX() methods to dynamically add new lines based on these
	FFTooltip:AddFontStrings(
		FFTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
		FFTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" )
	);
	
	FF:FindSpellIDs(FF.spells) --Doesn't work on login, but works for console reloadui
	
	FF.frame.squares[1].icon:SetTexture(FF.icon)
	FF.frame.squares[1].icon:SetAlpha(0.2)
	FF.frame.squares[1].cooldown:SetText("")
	FF.frame.squares[1].stacks:SetText("")
	FF.frame.squares[1]:Show()		
		
	
end




function FF:OnUpdate()

	local t = GetTime()
	
	if t < FF.lastUpdate + FF.updateRate then --Not ready to update.  in seconds
		return
	end
	
	FF.lastUpdate = t
	
	--Main icon
	local target = FF:FindTarget()
	if FF:HasDebuffIcon(target, FF.icon) then
		FF.frame.squares[1].icon:SetAlpha(1.0)
		local name = UnitName(target)
		if FF.timers[name] then
			local duration = FF:TimeRemaining(t, FF.timers[name], FF.duration)
			if duration > 10 then
				FF.frame.squares[1].cooldown:SetText(math.ceil(duration))
			elseif duration > 0 then
				FF.frame.squares[1].cooldown:SetText(FF:round(duration, 1))
			else
				FF.frame.squares[1].cooldown:SetText("")
			end
		end
	else
		FF.frame.squares[1].icon:SetAlpha(0.2)
		FF.frame.squares[1].cooldown:SetText("")
	end
	
	
	--Bars
	for i,bar in FF.bars do
		if bar.target ~= nil then
			local duration = FF:TimeRemaining(t, FF.timers[bar.target], FF.duration)
			bar.text:SetText(bar.target)
			if duration > 0 then
				bar:SetValue(duration)
				if duration > 10 then
					bar.time:SetText(math.ceil(duration))
				else
					bar.time:SetText(FF:round(duration, 1))
				end
				--bar:SetStatusBarColor(255/255, 125/255, 255/255, 1.0)
				bar.icon:SetAlpha(1.0)
				bar.text:SetAlpha(1.0)
			else
				bar:SetValue(0)
				bar.time:SetText("")
				--bar:SetStatusBarColor(100/255, 100/255, 100/255, 1.0)
				bar.icon:SetAlpha(0.5)
				bar.text:SetAlpha(0.5)
			end
			bar:Show()
		else 
			bar:Hide()
		end
	end
end




--http://lua-users.org/wiki/SimpleRound
function FF:round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end


function FF:TimeRemaining(current, start, duration)

	return duration - (current - start)

end



--Double triggers if cast->FF
--https://www.lua.org/pil/20.2.html
function FF:OnEvent()

	local msg = arg1
	local eventTime = GetTime()
	
	--print(event)
	--print(msg)
	
	--Settings Loaded
	if event == "ADDON_LOADED" then	
		FF:AddonsLoaded()
	end
	
	
		--Spellcast Events
	if FF.targetName ~= nil then
		if event == "SPELLCAST_FAILED" or  event=="SPELLCAST_START" then
			FF.targetName = nil
		elseif event == "SPELLCAST_STOP" then --Successfully cast, but not necessarily successfull
			FF.targetTimerBkp = FF.timers[FF.targetName] or -FF.duration --schedule failure check?
			FF:AddFF(FF.targetName, eventTime)
			FF.targetName = nil
		end
	end
	
	
	--Combatlog events
	if event == "SPELLS_CHANGED" then --Needed to handle loading spellIDs on login
		FF:FindSpellIDs(FF.spells)
		
	elseif event == "PLAYER_TARGET_CHANGED" then
		FF.lastUpdate = -1
		FF:OnUpdate()
		
	elseif event == "PLAYER_REGEN_ENABLED" then
		FF:Clear()
		
	elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then --X is afflicted by Y.
		local _,_,target,spell = string.find(msg, "(.-) is afflicted by (.-)%.") 
		if spell == "Faerie Fire" then
			--Need to check if target is not a unit in raid to avoid tracking enemy FF on allies
			FF:AddFF(target,eventTime)
		end
		
	elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then  --X fades from Y.
		local _,_,spell,target = string.find(msg, "(.-) fades from (.-)%.")
		if spell == "Faerie Fire" then
			FF:TimeoutFF(target)
		end
		
	elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then --X dies.
		local _,_,target = string.find(msg, "(.-) dies%.")
		--Handle target death here
		
	elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then --Your X was evaded by Y.  Your X was resisted by Y.
		local _,_,spell,failure,target = string.find(msg, "Your (.-) was (.-) by (.-)%.")
		if spell == "Faerie Fire" or spell == "Faerie Fire (Feral)" then
			if failure == "resisted" or failure == "evaded" then
				FF.timers[target] = FF.targetTimerBkp 
			end
		end
	end



	

end




function FF:AddonsLoaded()
	if FF_Settings.locked then
		FF.Lock()
	else
		FF.Unlock()
	end
	
	FF.frame:ClearAllPoints()
	FF.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", FF_Settings.iconX, FF_Settings.iconY)
	FF.barFrame:ClearAllPoints()
	FF.barFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", FF_Settings.timersX, FF_Settings.timersY)
	
	if FF_Settings.iconEnabled then
		FF.frame:Show()
	else
		FF.frame:Hide()
	end
	
	if FF_Settings.timersEnabled then
		FF.barFrame:Show()
	else
		FF.barFrame:Hide()
	end
end





function FF:AddFF(name, eventTime)
	if name == nil then
		return
	end
	
	FF.timers[name] = eventTime
	local firstEmptyBar = nil
	local nameUsed = false
	for i,bar in FF.bars do
		if bar.target == name then
			nameUsed = true
			break
		elseif bar.target == nil then
			firstEmptyBar = firstEmptyBar or i
		end
	end
	if not nameUsed then
		FF.bars[firstEmptyBar].target = name
	end
end


function FF:RemoveFF(name)
	if FF.timers[name] then
		FF[name] = nil
	end
	for i,bar in FF.bars do
		if bar.target == name then
			bar.target = nil
		end
	end
end


function FF:TimeoutFF(name)
	if FF.timers[name] then
		FF.timers[name] = 0.0
	end
end


function FF:Clear()
	FF.timers = {}
	for i,bar in FF.bars do
		bar.target = nil
	end
end


function FF:Lock()
	FF.frame:SetMovable(false)
	FF.frame:EnableMouse(false)
	FF.barFrame:SetMovable(false)
	FF.barFrame:EnableMouse(false)
	FF.barFrame:SetBackdropColor(24/255, 24/255, 24/255, 0)
	FF_Settings.locked = true
end



function FF:Unlock()
	FF.frame:SetMovable(true)
	FF.frame:EnableMouse(true)
	FF.barFrame:SetMovable(true)
	FF.barFrame:EnableMouse(true)
	FF.barFrame:SetBackdropColor(24/255, 24/255, 24/255, .5)
	FF_Settings.locked = false
end



function FF:HasDebuffIcon(unit, debuffIcon)
	if unit == nil or debuffIcon == nil then
		return false
	end

	for i=1,16 do
		icon, stacks = UnitDebuff(unit, i)
		if icon == debuffIcon then
			return true
		end
	end
	return false
end


function FF:FindSpellIDs(spells)
	for i,spell in spells do
		local n = 1
		repeat
			name = GetSpellName (n, BOOKTYPE_SPELL)
			n = n + 1
			if name == spell then
				FF.spellIDs[spell] = n
				break
			end
		until name == nil
	end
	return FF.spellIDs
end


--[[
function FF:ScheduleUpdate()
end
]]


--DONT RECREATE TEXTURE FOR EACH BAR
--DISABLE CLICKING/MOVEMENT UNLESS UNLOCKED
function FF:CreateStatusBars()

	local barFrame = CreateFrame("Frame", "FF_BarFrame", UIParent)
	barFrame:Hide()

	--Set Size
	barFrame:SetWidth(FF.barWidth)
	barFrame:SetHeight((FF.barHeight + FF.barSpacingVert) * FF.maxBars - FF.barSpacingVert)

	--Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
	barFrame:ClearAllPoints()
	barFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", FF_Settings.timersX, FF_Settings.timersY)
	
	--Misc
	barFrame:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
	barFrame:SetFrameLevel(1)
	barFrame:SetClampedToScreen(true)
	
	--Movement
	barFrame:EnableMouse(true)
	barFrame:RegisterForDrag("LeftButton")
	barFrame:SetMovable(true)
	barFrame:SetScript("OnDragStart", function() this:StartMoving() end)
	barFrame:SetScript("OnDragStop", 
		function()  
			this:StopMovingOrSizing();
			FF_Settings.timersX = this:GetLeft();
			FF_Settings.timersY = this:GetBottom(); 
		end)
	
	barFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	barFrame:SetBackdropBorderColor(1.0,1.0,1.0)
	barFrame:SetBackdropColor(24/255, 24/255, 24/255, .5)
	
	barFrame:Show()
	FF.barFrame = barFrame

	for i=1,FF.maxBars do
		local statusbar = CreateFrame("StatusBar", "FFStatusBar"..i, FF.barFrame)
		statusbar:SetPoint("TOPLEFT", FF.barFrame, "TOPLEFT", 0, (-FF.barHeight-FF.barSpacingVert)*(i-1))
		statusbar:SetWidth(FF.barWidth)
		statusbar:SetHeight(FF.barHeight)
		--statusbar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
		statusbar:SetStatusBarTexture("Interface\\Addons\\FFat20\\BantoBar.tga")
		--Interface\\CastingBar\\UI-CastingBar-Spark
		--"Interface\\TARGETINGFRAME\\UI-StatusBar"
		statusbar:SetStatusBarColor(255/255, 125/255, 255/255, 1.0)
		statusbar:SetMinMaxValues(0,FF.duration)
		statusbar:SetValue(FF.duration)
	
		statusbar.bg = statusbar:CreateTexture(nil, "BACKGROUND")
		statusbar.bg:SetTexture("Interface\\Addons\\FFat20\\BantoBar.tga")
		statusbar.bg:SetAllPoints(true)
		statusbar.bg:SetVertexColor(0, 0, 0, .5)

		statusbar.time = statusbar:CreateFontString("FFStatusBar"..i.."time", "OVERLAY")
		statusbar.time:ClearAllPoints()
		statusbar.time:SetPoint("LEFT", statusbar, "LEFT", FF.barTimerTextIndent, 0)
		statusbar.time:SetTextColor(1, 1, 1, 1)
		statusbar.time:SetJustifyH("MIDDLE")
		statusbar.time:SetFont("Fonts\\FRIZQT__.TTF", 10)
		statusbar.time:SetText("")
		--REMOVE OUTLINE
		statusbar.time:SetShadowColor(0,0,0)
		statusbar.time:SetShadowOffset(1, -1)
		
		statusbar.text = statusbar:CreateFontString("FFStatusBar"..i.."text", "OVERLAY")
		statusbar.text:ClearAllPoints()
		statusbar.text:SetPoint("LEFT", statusbar, "LEFT", FF.barTextIndent, 0)
		statusbar.text:SetTextColor(1, 1, 1, 1)
		statusbar.text:SetJustifyH("LEFT")
		statusbar.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
		statusbar.text:SetText("")
		--REMOVE OUTLINE
		statusbar.text:SetShadowColor(0,0,0)
		statusbar.text:SetShadowOffset(1, -1)
		
		statusbar.icon = statusbar:CreateTexture("FF_BarIconTexture"..i) --"ARTWORK"
		statusbar.icon:SetTexture(FF.icon)
		statusbar.icon:SetPoint("TOPRIGHT", statusbar, "TOPLEFT", -1, 0)
		statusbar.icon:SetWidth(FF.barHeight)
		statusbar.icon:SetHeight(FF.barHeight)
		statusbar.icon:SetAlpha(0.5)
		
		
		--[[
		local spark = statusbar:CreateTexture(nil, "OVERLAY") 
		spark:SetParent(statusbar)
		spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		spark:SetWidth(25)
		spark:SetHeight( 15 + 25 )
		spark:SetBlendMode("ADD")
		spark:Show()
		]]

		statusbar:Hide()
		--statusbar:Show()
		table.insert(FF.bars, statusbar)
	end
end




--rename squares
function FF:SetupFrames()

	local frame = CreateFrame("Frame", "FF_MainFrame", UIParent)
	frame:Hide()

	--Set Size
	frame:SetWidth(FF.iconSize)
	frame:SetHeight(FF.iconSize)

	--Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", FF_Settings.iconX, FF_Settings.iconY)
	
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
	frame:SetFrameLevel(1)
	frame:SetClampedToScreen(true)
	
	--Movement
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(true)
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", 
		function()  
			this:StopMovingOrSizing();
			FF_Settings.iconX = this:GetLeft();
			FF_Settings.iconY = this:GetBottom(); 
		end)
	
	frame.squares = {}
	for i=1,1 do
		local square = CreateFrame("Frame", "FF_Buttons"..i, frame)
		--local square = CreateFrame("Button", "BuffWatcher_Buttons"..i, frame, "ActionButtonTemplate")
		square:Hide()
		square:ClearAllPoints()
		if i==1 then
			square:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, 0)
		else
			square:SetPoint("TOPLEFT", frame.squares[i-1], "TOPRIGHT", 0, 0)
		end
		square:SetFrameStrata("BACKGROUND") --Above Background level base
		square:SetFrameLevel(2)
		--square:SetFrameLevel(1)
		square:SetWidth(FF.iconSize)
		square:SetHeight(FF.iconSize)
		square:SetBackdropColor(i/1, i/1, i/1, i/1)
		square:SetBackdropBorderColor(1.0,0.0,0.0)
		--square:SetNormalTexture(nil)
		
		square.icon = square:CreateTexture("FF_SquareTexture"..i)
		square.icon:SetTexture("")
		square.icon:SetPoint("TOPLEFT", square, "TOPLEFT", 0, 0)
		square.icon:SetWidth(FF.iconSize)
		square.icon:SetHeight(FF.iconSize)
		
		square.cooldown = square:CreateFontString(nil, "OVERLAY")
		square.cooldown:ClearAllPoints()
		square.cooldown:SetPoint("CENTER", square.icon, "CENTER",0,0)
		square.cooldown:SetTextColor(1, 1, 1, 1)
		square.cooldown:SetJustifyH("RIGHT")
		square.cooldown:SetFont("Fonts\\FRIZQT__.TTF", 12, "THINOUTLINE")
		square.cooldown:SetText("")
		
		square.stacks = square:CreateFontString(nil, "OVERLAY")
		square.stacks:ClearAllPoints()
		square.stacks:SetPoint("BOTTOMRIGHT", square.icon, "BOTTOMRIGHT",-4,0)
		square.stacks:SetTextColor(1, 1, 1, 1)
		square.stacks:SetJustifyH("RIGHT")
		square.stacks:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
		square.stacks:SetText("")
	
		frame.squares[i] = square
		--square:Show()
	end
	
	FF.frame = frame
	frame:Show()
	
	FF:CreateStatusBars()
	
end




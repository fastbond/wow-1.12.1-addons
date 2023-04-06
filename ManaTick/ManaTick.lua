function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end


ManaTick = {}
local defaultInterval = 2.0
local lockoutDuration = 5
local tickVariance = 0.02
local lastTickTime = 0
local lastTickMana = 0
local expectedTickInterval = defaultInterval
local expectedTickTime = GetTime() + expectedTickInterval
local regenDisabledTime = nil
local isGuess = nil
local latency = nil
local tickInterval = nil


local default_settings = {
	["width"] = 150,
	["height"] = 25,
    ["spark_width"] = 20,
	["show"] = true,
	["lock"] = true,
    ["latency"] = true,
	--["color"] = 1.0,
}
local settings = default_settings


SLASH_MANATICK1, SLASH_MANATICK2 = '/manatick', '/mt'; 
SlashCmdList["MANATICK"] = function(msg)
	local msg = string.lower(msg)
	local _,_,cmd, text = string.find(msg,"([^%s]+) ?(.*)")
	
	if cmd == "show" then
		ManaTick.bar:Show()
	elseif cmd == "hide" then
		ManaTick.bar:Hide()
	end
    
    if cmd == "lock" then
        ManaTick.bar:EnableMouse(false)
    elseif cmd == "unlock" then
        ManaTick.bar:EnableMouse(true)
    end
    
    if cmd == "width" then
        ManaTick:SetWidth(text)
    elseif cmd == "height" then
        ManaTick:SetHeight(text)
    end
    
    if cmd == "latency" then
        ManaTick:ShowLatency(not ManaTick.bar.latency:IsShown())
    end
        
	
end


function ManaTick:OnLoad()
    ManaTick.scripts = CreateFrame("Frame", nil, UIParent)
    ManaTick.scripts:RegisterEvent("PLAYER_ENTERING_WORLD")
    ManaTick.scripts:RegisterEvent("UNIT_MANA")
    ManaTick.scripts:RegisterEvent("ADDON_LOADED")
    
    ManaTick:CreateBar()
    
    --Need to make sure they exist
	if settings.show then
		ManaTick:Show(true)
	else
		ManaTick:Show(false)
	end

    if settings.lock then
        ManaTick:Lock(false)
    else
        ManaTick:Lock(true)
    end
    
    --Need to check for non-numeric
    if settings.width ~= nil then
        ManaTick:SetWidth(settings.width)
    end
    if settings.height ~= nil then
        ManaTick:SetHeight(settings.height)
    end
    
    if settings.latency then
		ManaTick:ShowLatency(true)
	else
		ManaTick:ShowLatency(false)
	end 
    
    
    ManaTick.scripts:SetScript("OnEvent", function()
        ManaTick:OnEvent()
    end)
    
    ManaTick.scripts:SetScript("OnUpdate", function()
        ManaTick:OnUpdate()
    end)
end


--Can't just assume next tick is 5s after spell cast due to set bonus, talents, trinkets
--Any mp5 gear will cause it to tick every 2s regardless
--Blessing of wisdom/buff ticks?
--Mana pots, runes, consumes?
--Latency causing delays
--Tick while casting
--Possible it just pauses current 2s timer, rather than doing on next?
--Need to also do zone, reload, etc events besides enter world
function ManaTick:OnEvent()
    if event == "ADDON_LOADED" then
        --ManaTick:OnLoad()
    end

    if event == "PLAYER_ENTERING_WORLD" then
        --this.lastTickMana = UnitMana("player")
        --this.lastTickTime = GetTime()
        lastTickMana = UnitMana("player")
        lastTickTime = GetTime()
        expectedTickInterval = defaultInterval
        isGuess = true
    end
    
    --Making the assumption that losing mana means casting a spell.  
    --This isn't necessarily true, and can also be caused by:
    --      -Increasing max mana via gear change or buff while at full mana
    --      -Mana burn effects
    --      -Others?
    if event == "UNIT_MANA" and arg1 == "player" then
        local currentMana = UnitMana("player") -- Get the player's current mana
        local t = GetTime()
    
        local manaDiff = currentMana - lastTickMana
        lastTickMana = currentMana
        if manaDiff < 0 then
            regenDisabledTime = t + lockoutDuration
            ManaTick:setTickBarColor(false)
        end
        
        local timeDiff = t - lastTickTime
        --CHANGE THIS TO IF NOT SET, START SCHEDULING TICKS
        if isGuess or (timeDiff > defaultInterval - tickVariance) then
            --print("Time since last change: " .. t - lastTickTime)
            lastTickTime = t    
            expectedTickInterval = defaultInterval
            expectedTickTime = t + expectedTickInterval
            isGuess = false
        end
        
    end
end



function ManaTick:OnUpdate()
    currentTime = GetTime()
    
    if regenDisabledTime ~= nil and regenDisabledTime < currentTime then
        ManaTick:setTickBarColor(true)
        regenDisabledTime = nil
    end
    
    --Only apply this if full mana?
    --if UnitMana("player") / UnitManaMax("player") >= 1 and abs(currentTime - expectedTickTime) < tickVariance then
    if (currentTime - expectedTickTime > 0) and (currentTime - expectedTickTime > tickVariance) then
        lastTickTime = currentTime - tickVariance
        expectedTickTime = expectedTickTime + expectedTickInterval
        isGuess = true
    end
    
    --pct = (currentTime - lastTickTime) / expectedTickInterval
    pct = (currentTime - lastTickTime) / (expectedTickTime - lastTickTime)
    if pct > 1 then
        pct = 1
    end
    if pct < 0 then
        pct = 0
    end
    --duration = expectedTickInterval
    duration = expectedTickTime - lastTickTime
    ManaTick.bar:SetMinMaxValues(0,duration)
    ManaTick.bar:SetValue(pct * duration)
    --ManaTick.bar.text:SetText(duration .. "s")
    xpos = pct * ManaTick.bar:GetWidth()
    ManaTick.bar.spark:SetPoint("CENTER", ManaTick.bar, "LEFT", xpos, 0)
    
    _, _, latencyHome, latencyWorld = GetNetStats()  --latencyWorld doesn't seem to exist?
    drinkPct = (duration - (latencyHome/1000)) / duration
    xpos = drinkPct * ManaTick.bar:GetWidth()
    ManaTick.bar.latency:SetPoint("Center", ManaTick.bar, "LEFT", xpos, 0)
  
end



function ManaTick:SetWidth(width)
    settings.width = width
    ManaTick.bar:SetWidth(settings.width)
end


function ManaTick:SetHeight(height)
    settings.height = height
    ManaTick.bar:SetHeight(settings.height)
end


function ManaTick:Show(show)
    if show then
        settings.show = true
        ManaTick.bar:Show()
    else
        settings.show = false
        ManaTick.bar:Hide()
    end
end


function ManaTick:Lock(lock)
    if lock then
        settings.lock = true
        ManaTick.bar:EnableMouse(false)
    else
        settings.lock = false
        ManaTick.bar:EnableMouse(true)
    end
end


function ManaTick:ShowLatency(showLatencyBar)
    if showLatencyBar then
        settings.latency = true
        ManaTick.bar.latency:Show()
    else
        settings.latency = false
        ManaTick.bar.latency:Hide()
    end
end



function ManaTick:CreateBar()
    ManaTick.bar = CreateFrame("StatusBar", "ManaTickBar", UIParent)

    --Set Size
    ManaTick.bar:SetWidth(settings.width)
    ManaTick.bar:SetHeight(settings.height)

    --Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
    ManaTick.bar:ClearAllPoints()
    ManaTick.bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    --Misc
    ManaTick.bar:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
    ManaTick.bar:SetFrameLevel(1)
    ManaTick.bar:SetClampedToScreen(true)

    --Movement
    ManaTick.bar:EnableMouse(true)
    ManaTick.bar:RegisterForDrag("LeftButton")
    ManaTick.bar:SetMovable(true)
    ManaTick.bar:SetScript("OnDragStart", function() this:StartMoving() end)
    ManaTick.bar:SetScript("OnDragStop", 
        function()  
            this:StopMovingOrSizing();
        end)

    --Background Texture
    --ManaTick.bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
    ManaTick.bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1, },})
    ManaTick.bar:SetBackdropBorderColor(0.0, 0.0, 0.0, .85)
    ManaTick.bar:SetBackdropColor(24/255, 24/255, 24/255, .7)
    --ManaTick.bar.bg:SetVertexColor(0, 0, 0, .5)

    ManaTick.bar.border = nil

    ManaTick.bar.spark = ManaTick.bar:CreateTexture(nil, 'OVERLAY')
    ManaTick.bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    --ManaTick.bar.spark:SetColorTexture(255/255, 125/255, 255/255, 1.0)
    local manabar_height = ManaTick.bar:GetHeight()
    local manabar_width = ManaTick.bar:GetWidth()
    ManaTick.bar.spark:SetHeight(manabar_height * 1.8)
    ManaTick.bar.spark:SetWidth(settings.spark_width)
    ManaTick.bar.spark:SetBlendMode('ADD')

    --Default Values
    ManaTick.bar:SetMinMaxValues(0,defaultInterval)
    ManaTick.bar:SetValue(0)

    --Text
    ManaTick.bar.text = ManaTick.bar:CreateFontString("ManaTick.barText", "OVERLAY")
    ManaTick.bar.text:ClearAllPoints()
    ManaTick.bar.text:SetPoint("LEFT", ManaTick.bar, "RIGHT", 0, 0)
    ManaTick.bar.text:SetTextColor(1, 1, 1, 1)
    ManaTick.bar.text:SetJustifyH("LEFT")
    ManaTick.bar.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    ManaTick.bar.text:SetText("")
    --REMOVE OUTLINE
    ManaTick.bar.text:SetShadowColor(0,0,0)
    ManaTick.bar.text:SetShadowOffset(1, -1)

    ManaTick.bar.latency = ManaTick.bar:CreateTexture(nil, 'OVERLAY')
    ManaTick.bar.latency:SetTexture(1, 1, 1, 0.8)
    ManaTick.bar.latency:SetHeight(manabar_height * 0.8)
    ManaTick.bar.latency:SetWidth(1)

    ManaTick.bar:Show()
end
    


function ManaTick:setTickBarColor(regenEnabled)
    if regenEnabled then
        ManaTick.bar:SetBackdropBorderColor(0.0, 0.0, 0.0, .85)
        ManaTick.bar:SetBackdropColor(24/255, 24/255, 24/255, .7)
    else
        ManaTick.bar:SetBackdropBorderColor(0.2, 0.0, 0.0, .85)
        ManaTick.bar:SetBackdropColor(75/255, 24/255, 24/255, .7)
    end
end












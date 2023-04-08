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
	["lock"] = false,
    ["latency"] = true,
    ["x"] = 0,
    ["y"] = 0,
	--["color"] = 1.0,
}
local settings = {}
for k, v in pairs(default_settings) do
    settings[k] = v
end
ManaTick_Settings = {}


SLASH_MANATICK1, SLASH_MANATICK2 = '/manatick', '/mt'; 
SlashCmdList["MANATICK"] = function(msg)
	local msg = string.lower(msg)
	local _,_,cmd, text = string.find(msg,"([^%s]+) ?(.*)")
    
	if cmd == "show" then
		ManaTick:Show(true)
	elseif cmd == "hide" then
		ManaTick:Show(false)
    
    elseif cmd == "lock" then
        ManaTick:Lock(true)
    elseif cmd == "unlock" then
        ManaTick:Lock(false)
    
    elseif cmd == "width" then
        ManaTick:SetWidth(tonumber(text))
    elseif cmd == "height" then
        ManaTick:SetHeight(tonumber(text))
    
    elseif cmd == "latency" then
        ManaTick:ShowLatency(not ManaTick.bar.latency:IsShown())
        
    elseif cmd == "reset" then
        for k, v in pairs(default_settings) do
            settings[k] = v
        end
        ManaTick:ApplySettings()
    
    --if cmd == "help" or cmd == "" or cmd == nil then
    else
        DEFAULT_CHAT_FRAME:AddMessage("ManaTick commands: ")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt show - Show bar")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt hide - Hide bar")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt lock - Lock in place and disable mouse interaction")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt unlock - Unlock bar for movement")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt width x - Set bar width to x")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt height x - Set bar height x")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt latency - Toggle latency bar")	
        DEFAULT_CHAT_FRAME:AddMessage(" /mt reset - reset settings to defaults")
    end
end


--Runs before variables are loaded
function ManaTick:OnLoad()
    self.scripts = CreateFrame("Frame", nil, UIParent)
    self.scripts:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.scripts:RegisterEvent("UNIT_MANA")
    self.scripts:RegisterEvent("ADDON_LOADED")
    self.scripts:RegisterEvent("PLAYER_LOGOUT")
    
    self:CreateBar()
    
    self.scripts:SetScript("OnEvent", function()
        self:OnEvent()
    end)
    
    self.scripts:SetScript("OnUpdate", function()
        self:OnUpdate()
    end)
    
    self.bar:Show()
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
    --Runs after variables are loaded
    if event == "ADDON_LOADED" and arg1 == "ManaTick" then
        for k, v in ManaTick_Settings do
            settings[k] = v
        end
        _, _, _, x, y = ManaTick.bar:GetPoint()
        if settings.x == nil or settings.y == nil then
            settings.x = x
            settings.y = y
        end
        ManaTick:ApplySettings()
    end
    
    if event == "PLAYER_LOGOUT" then
        ManaTick_Settings = {}
        for k, v in pairs(settings) do
            ManaTick_Settings[k] = v
        end
    end

    if event == "PLAYER_ENTERING_WORLD" then
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
            self:setTickBarColor(false)
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
        self:setTickBarColor(true)
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
    self.bar:SetMinMaxValues(0,duration)
    self.bar:SetValue(pct * duration)
    --self.bar.text:SetText(duration .. "s")
    xpos = pct * self.bar:GetWidth()
    self.bar.spark:SetPoint("CENTER", self.bar, "LEFT", xpos, 0)
    
    _, _, latencyHome, latencyWorld = GetNetStats()  --latencyWorld doesn't seem to exist?
    drinkPct = (duration - (latencyHome/1000)) / duration
    xpos = drinkPct * self.bar:GetWidth()
    self.bar.latency:SetPoint("Center", self.bar, "LEFT", xpos, 0)
  
end



function ManaTick:ApplySettings()
    --Need to make sure they exist
	if settings.show then
		self:Show(true)
	else
		self:Show(false)
	end

    if settings.lock then
        self:Lock(true)
    else
        self:Lock(false)
    end
    
    --Need to check for non-numeric
    if settings.width ~= nil then
        self:SetWidth(settings.width)
    end
    if settings.height ~= nil then
        self:SetHeight(settings.height)
    end
    
    if settings.latency then
		self:ShowLatency(true)
	else
		self:ShowLatency(false)
	end 
    
    if settings.x ~= nil and settings.y ~= nil then
        ManaTick:SetPosition(settings.x, settings.y)
    end
end



function ManaTick:SetWidth(width)
    if type(width) ~= "number" then
        return
    end
    settings.width = width
    ManaTick.bar:SetWidth(settings.width)
end


function ManaTick:SetHeight(height)
    if type(height) ~= "number" then
        return
    end
    settings.height = height
    ManaTick.bar:SetHeight(settings.height)
    ManaTick.bar.spark:SetHeight(ManaTick.bar:GetHeight() * 1.8)
    ManaTick.bar.latency:SetHeight(max(ManaTick.bar:GetHeight() - 4, 5))
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


function ManaTick:SetPosition(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return
    end
    ManaTick.bar:ClearAllPoints()
    ManaTick.bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
end



function ManaTick:CreateBar()
    bar = CreateFrame("StatusBar", "ManaTickBar", UIParent)

    --Set Size
    bar:SetWidth(settings.width)
    bar:SetHeight(settings.height)

    --Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    --Misc
    bar:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
    bar:SetFrameLevel(1)
    bar:SetClampedToScreen(true)

    --Movement
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetMovable(true)
    bar:SetScript("OnDragStart", function() this:StartMoving(); 
            _, _, _, x, y = this:GetPoint()
            settings.x = x
            settings.y = y
        end)
    bar:SetScript("OnDragStop", 
        function()  
            this:StopMovingOrSizing();
        end)

    --Background Texture
    --bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
    bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1, },})
    bar:SetBackdropBorderColor(0.0, 0.0, 0.0, .85)
    bar:SetBackdropColor(24/255, 24/255, 24/255, .7)
    --bar.bg:SetVertexColor(0, 0, 0, .5)

    bar.border = nil

    bar.spark = bar:CreateTexture(nil, 'OVERLAY')
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    --bar.spark:SetColorTexture(255/255, 125/255, 255/255, 1.0)
    bar.spark:SetHeight(bar:GetHeight() * 1.8)
    bar.spark:SetWidth(settings.spark_width)
    bar.spark:SetBlendMode('ADD')

    --Default Values
    bar:SetMinMaxValues(0,defaultInterval)
    bar:SetValue(0)

    --Text
    bar.text = bar:CreateFontString("ManaTick.barText", "OVERLAY")
    bar.text:ClearAllPoints()
    bar.text:SetPoint("LEFT", bar, "RIGHT", 0, 0)
    bar.text:SetTextColor(1, 1, 1, 1)
    bar.text:SetJustifyH("LEFT")
    bar.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    bar.text:SetText("")
    --REMOVE OUTLINE
    bar.text:SetShadowColor(0,0,0)
    bar.text:SetShadowOffset(1, -1)

    bar.latency = bar:CreateTexture(nil, 'OVERLAY')
    bar.latency:SetTexture(1, 1, 1, 0.8)
    bar.latency:SetHeight(max(bar:GetHeight() - 4, 5))
    bar.latency:SetWidth(1)

    ManaTick.bar = bar
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












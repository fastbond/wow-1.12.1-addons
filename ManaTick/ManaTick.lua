

function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end



ManaTick = {}
local defaultInterval = 2.0
local longTickInterval = 5
local tickVariance = 0.02
local lastTickTime = 0
local lastTickMana = 0
local expectedTickInterval = defaultInterval
local expectedTickTime = GetTime() + expectedTickInterval
local regenDisabledTime = nil
local isGuess = nil
local latency = nil
local tickInterval = nil


    
local manatickBar = CreateFrame("StatusBar", "ManaTickBar", UIParent)

--Set Size
manatickBar:SetWidth(150)
manatickBar:SetHeight(25)

--Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
manatickBar:ClearAllPoints()
manatickBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

--Misc
manatickBar:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
manatickBar:SetFrameLevel(1)
manatickBar:SetClampedToScreen(true)

--Movement
manatickBar:EnableMouse(true)
manatickBar:RegisterForDrag("LeftButton")
manatickBar:SetMovable(true)
manatickBar:SetScript("OnDragStart", function() this:StartMoving() end)
manatickBar:SetScript("OnDragStop", 
    function()  
        this:StopMovingOrSizing();
    end)

--Background Texture
--manatickBar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
manatickBar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1, },})
manatickBar:SetBackdropBorderColor(0.0, 0.0, 0.0, .85)
manatickBar:SetBackdropColor(24/255, 24/255, 24/255, .7)

--manatickBar:SetStatusBarTexture("Interface\\Addons\\ManaTick\\BantoBar.tga")
--manatickBar:SetStatusBarColor(255/255, 125/255, 255/255, 1.0)

--[[manatickBar.bg = manatickBar:CreateTexture(nil, "BACKGROUND")
manatickBar.bg:SetTexture("Interface\\Addons\\ManaTick\\BantoBar.tga")
manatickBar.bg:SetAllPoints(true)
manatickBar.bg:SetVertexColor(0, 0, 0, .5)]]

manatickBar.border = nil

manatickBar.spark = manatickBar:CreateTexture(nil, 'OVERLAY')
manatickBar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
--manatickBar.spark:SetColorTexture(255/255, 125/255, 255/255, 1.0)
local manabar_height = manatickBar:GetHeight()--manabarFrame:GetHeight()
local manabar_width = manatickBar:GetWidth()--manabarFrame:GetWidth()
manatickBar.spark:SetHeight(manabar_height * 1.8)
manatickBar.spark:SetWidth(20)
manatickBar.spark:SetBlendMode('ADD')

--Default Values
manatickBar:SetMinMaxValues(0,defaultInterval)
manatickBar:SetValue(0)

--Text
manatickBar.text = manatickBar:CreateFontString("manatickBarText", "OVERLAY")
manatickBar.text:ClearAllPoints()
manatickBar.text:SetPoint("LEFT", manatickBar, "RIGHT", 0, 0)
manatickBar.text:SetTextColor(1, 1, 1, 1)
manatickBar.text:SetJustifyH("LEFT")
manatickBar.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
manatickBar.text:SetText("")
--REMOVE OUTLINE
manatickBar.text:SetShadowColor(0,0,0)
manatickBar.text:SetShadowOffset(1, -1)

manatickBar:Show()

--end




local manatick = CreateFrame("Frame", nil, UIParent)
manatick:RegisterEvent("PLAYER_ENTERING_WORLD")
manatick:RegisterEvent("UNIT_MANA")
--Can't just assume next tick is 5s after spell cast due to set bonus, talents, trinkets
--Any mp5 gear will cause it to tick every 2s regardless
--Blessing of wisdom/buff ticks?
--Mana pots, runes, consumes?
--Latency causing delays
--Tick while casting
--Possible it just pauses current 2s timer, rather than doing on next?
manatick:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        --this.lastTickMana = UnitMana("player")
        --this.lastTickTime = GetTime()
        lastTickMana = UnitMana("player")
        lastTickTime = GetTime()
        expectedTickInterval = defaultInterval
        isGuess = true
    end
    
    if event == "UNIT_MANA" and arg1 == "player" then
        local currentMana = UnitMana("player") -- Get the player's current mana
        local t = GetTime()
    
        local manaDiff = currentMana - lastTickMana
        lastTickMana = currentMana
        --Making the assumption that losing mana means casting a spell.  
        --This isn't necessarily true, and can also be caused by:
        --      -Increasing max mana via gear change or buff while at full mana
        --      -Mana burn effects
        --      -Others?
        if manaDiff < 0 then
            --[[
            expectedTickInterval = longTickInterval
            --Find next interval of defaultInterval after t+longTickInterval
            --THIS IS A BAD WAY TO DO IT BUT IM SO TIRED
            --THIS NEEDS A FLOAT MARGIN CHECK
            while expectedTickTime < t + longTickInterval do
                expectedTickTime = expectedTickTime + defaultInterval
            end
            return
            ]]
            regenDisabledTime = t + longTickInterval
            setTickBarColor(false)
        end
        
        local timeDiff = t - lastTickTime
        --CHANGE THIS TO IF NOT SET, START SCHEDULING TICKS
        if isGuess or (timeDiff > defaultInterval - tickVariance) then
            print("Time since last change: " .. t - lastTickTime)
            lastTickTime = t    
            expectedTickInterval = defaultInterval
            expectedTickTime = t + expectedTickInterval
            isGuess = false
        end
        
    end
end)



function setTickBarColor(regenEnabled)
    if regenEnabled then
        manatickBar:SetBackdropBorderColor(0.0, 0.0, 0.0, .85)
        manatickBar:SetBackdropColor(24/255, 24/255, 24/255, .7)
    else
        manatickBar:SetBackdropBorderColor(0.2, 0.0, 0.0, .85)
        manatickBar:SetBackdropColor(75/255, 24/255, 24/255, .7)
    end
end


manatick:SetScript("OnUpdate", function()
    currentTime = GetTime()
    
    if regenDisabledTime ~= nil and regenDisabledTime < currentTime then
        setTickBarColor(true)
        regenDisabledTime = nil
    end
    
    --Only apply this if full mana?
    --if UnitMana("player") / UnitManaMax("player") >= 1 and abs(currentTime - expectedTickTime) < tickVariance then
    if (currentTime - expectedTickTime > 0) and (currentTime - expectedTickTime < tickVariance) then
        lastTickTime = currentTime
        expectedTickTime = expectedTickTime + expectedTickInterval
        isGuess = true
    end
    
    --pct = (currentTime - lastTickTime) / expectedTickInterval
    pct = (currentTime - lastTickTime) / (expectedTickTime - lastTickTime)
    if pct > 1 then
        pct = 1
    end
    --finish = expectedTickInterval
    finish = expectedTickTime - lastTickTime
    manatickBar:SetMinMaxValues(0,finish)
    manatickBar:SetValue(pct * finish)
    --manatickBar.text:SetText(finish .. "s")
    xpos = pct * manatickBar:GetWidth()
    manatickBar.spark:SetPoint("CENTER", manatickBar, "LEFT", xpos, 0)

end)






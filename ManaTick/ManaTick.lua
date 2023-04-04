ManaTick = {}



function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end


local casting = 0
CastSpellByName_orig = CastSpellByName
CastSpellByName = function(spellname, onself)
    print("casting")
    CastSpellByName_orig(spellname, onself)
    casting = 1
end
    


--function ManaTick:CreateManaTickBar()
local manatickFrame = CreateFrame("Frame", "ManaTick_Frame", UIParent)

--Set Size
manatickFrame:SetWidth(200)
manatickFrame:SetHeight(20)

--Set position relative to base UI(frame anchor corner, target, target anchor corner, xoffset, yoffset)
manatickFrame:ClearAllPoints()
manatickFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

--Misc
manatickFrame:SetFrameStrata("BACKGROUND") --Make sure it's under the bars
manatickFrame:SetFrameLevel(1)
manatickFrame:SetClampedToScreen(true)

--Movement
manatickFrame:EnableMouse(true)
manatickFrame:RegisterForDrag("LeftButton")
manatickFrame:SetMovable(true)
manatickFrame:SetScript("OnDragStart", function() this:StartMoving() end)
manatickFrame:SetScript("OnDragStop", 
    function()  
        this:StopMovingOrSizing();
    end)

manatickFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
manatickFrame:SetBackdropBorderColor(1.0,1.0,1.0)
manatickFrame:SetBackdropColor(24/255, 24/255, 24/255, .5)

manatickFrame:Show()

local manatickBar = CreateFrame("StatusBar", "ManaTickBar", manatickFrame)
manatickBar:SetPoint("CENTER", manatickFrame, "CENTER", 0, 0)
manatickBar:SetWidth(100)
manatickBar:SetHeight(10)
manatickBar:SetStatusBarTexture("Interface\\Addons\\ManaTick\\BantoBar.tga")
--Interface\\CastingBar\\UI-CastingBar-Spark
--"Interface\\TARGETINGFRAME\\UI-StatusBar"
manatickBar:SetStatusBarColor(255/255, 125/255, 255/255, 1.0)
manatickBar:SetMinMaxValues(0,5)
manatickBar:SetValue(5)

--[[manatickBar.bg = manatickBar:CreateTexture(nil, "BACKGROUND")
manatickBar.bg:SetTexture("Interface\\Addons\\ManaTick\\BantoBar.tga")
manatickBar.bg:SetAllPoints(true)
manatickBar.bg:SetVertexColor(0, 0, 0, .5)]]


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



manatickFrame:Show()
manatickBar:Show()

--end




--There might be a hidden set tick on 2s that it waits to line up with
local gcd = 1.5
local longTickDuration = 5 + gcd
local tickDuration = 2
local variance = 0.02
local lastTime = 0
local lastMana = 0
local expectedTick = tickDuration
local nextTick = lastTime
local latency = nil
local tickInterval = nil
local expectedTickInterval = nil

local manabarFrame = manatickBar
local manatick = CreateFrame("Frame", nil, manabarFrame)

manatick.spark = manatick:CreateTexture(nil, 'OVERLAY')
manatick.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
local manabar_height = manatickBar:GetHeight()--manabarFrame:GetHeight()
local manabar_width = manatickBar:GetWidth()--manabarFrame:GetWidth()
manatick.spark:SetHeight(manabar_height + 15)
manatick.spark:SetWidth(manabar_height + 10)
manatick.spark:SetBlendMode('ADD')

manatick:RegisterEvent("PLAYER_ENTERING_WORLD")
manatick:RegisterEvent("UNIT_MANA")
--Can't just assume next tick is 5s after spell cast due to set bonus, talents, trinkets
--Any mp5 gear will cause it to tick every 2s regardless
--Blessing of wisdom/buff ticks?
--Mana pots, runes, consumes?

manatick:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        this.lastMana = UnitMana("player")
        this.lastTime = GetTime()
        expectedTick = tickDuration
    end
    
    if event == "UNIT_MANA" and arg1 == "player" then
        local currentMana = UnitMana("player") -- Get the player's current mana
        local t = GetTime()
    
        local manaDiff = currentMana - lastMana
        lastMana = currentMana
        --Making the assumption that losing mana means casting a spell.  
        --This isn't necessarily true, and can also be caused by:
        --      -Increasing max mana via gear change or buff while at full mana
        --      -Mana burn effects
        --      -Others?
        if manaDiff < 0 then
            lastTime = t
            expectedTick = longTickDuration
            return
        end
        
        local timeDiff = t - lastTime
        if timeDiff > tickDuration - variance then
            --if timeDiff < tickDuration + variance + 1 then
            print("Time since last change: " .. t - lastTime)
            lastTime = t    
            expectedTick = tickDuration
            --expectedTick = longTickDuration
        end
        
    end
end)



manatick:SetScript("OnUpdate", function()
    --Attachment point on this object, parent frame, attachment point on parent frame, xoffset, yoffset
    currentTime = GetTime() - lastTime
    pct = currentTime / expectedTick
    if pct > 1 then
        pct = 1
    end
    manatickBar:SetMinMaxValues(0,expectedTick)
    manatickBar:SetValue(pct * expectedTick)
    manatickBar.text:SetText(expectedTick .. "s")
    xpos = pct * manatickBar:GetWidth()
    manatick.spark:SetPoint("CENTER", manatickBar, "LEFT", xpos, 0)

end)






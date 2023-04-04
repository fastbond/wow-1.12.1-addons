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
    



local longTickDuration = 5
local tickDuration = 2
local variance = 0.02
local lastTime = 0
local lastMana = 0
local expectedTick = tickDuration
local nextTick = lastTime
local latency = nil
local manabarFrame = PlayerFrameManaBar
local manatick = CreateFrame("Frame", nil, manabarFrame)

manatick.spark = manatick:CreateTexture(nil, 'OVERLAY')
manatick.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
local manabar_height = manabarFrame:GetHeight()
local manabar_width = manabarFrame:GetWidth()
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
            expectedTick = longTickDuration
            return
        end
        
        local timeDiff = t - lastTime
        if timeDiff > tickDuration - variance then
            print("Time since last change: " .. t - lastTime)
            lastTime = t    
            expectedTick = tickDuration
        end
        
    end
end)



manatick:SetScript("OnUpdate", function()
    --local pos = (C.unitframes.player.pwidth ~= "-1" and C.unitframes.player.pwidth or C.unitframes.player.width) * (this.current / this.max)
    --Attachment point on this object, parent frame, attachment point on parent frame, xoffset, yoffset
    manatick.spark:SetPoint("CENTER", manabarFrame, "CENTER", 0, 0)
    --[[if this.target then
        this.start, this.max = GetTime(), this.target
        this.target = nil
    end

    if not this.start then return end

    this.current = GetTime() - this.start

    if this.current > this.max then
        this.start, this.max, this.current = GetTime(), 2, 0
    end

    local pos = (C.unitframes.player.pwidth ~= "-1" and C.unitframes.player.pwidth or C.unitframes.player.width) * (this.current / this.max)
    if not C.unitframes.player.pheight then return end
        this.spark:SetPoint("LEFT", pos-((C.unitframes.player.pheight+5)/2), 0)]]
end)





--"UNIT_HEALTH"
--TargetFrameHealthBar

local target = nil
local hideFriendlyPercents = false
local showPartyValues = false

local healthUpdate = function(event)
	unit = target.unit
	
    if hideFriendlyPercents and UnitIsFriend(unit, "player") then
        if showPartyValues and (UnitInParty(unit) or UnitInRaid(unit)) then
            local hp = UnitHealth(unit)
            local maxhp = UnitHealthMax(unit)
            target.text:SetText(format("%d / %d", hp, hp))
		else 
            target.text:SetText("")
        end  
		return
	end
	
	local hp = UnitHealth(unit)
	if hp > 0 then
		hp = hp / UnitHealthMax(unit) * 100
		if hp == 100 then
			target.text:SetText("100%")
		else
			target.text:SetText(format("%d%%", hp))--%.1f%%
		end
	else
		target.text:SetText("")
	end
end

target = CreateFrame("Frame", name, TargetFrameHealthBar)
target:SetPoint("CENTER", TargetFrameHealthBar, "CENTER", 5, 0)
target:SetAlpha(.65)
target:SetFrameStrata("HIGH")
target:SetWidth(TargetFrameHealthBar:GetWidth())
--target:SetWidth(50)
target:SetHeight(20)
target:SetScript("OnEvent", healthUpdate)
target.unit = "target"
target:RegisterEvent("PLAYER_TARGET_CHANGED")
target:RegisterEvent("UNIT_HEALTH")
target.text = target:CreateFontString(nil, nil, "TextStatusBarText")
target.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "THINOUTLINE")
target.text:SetAllPoints(target)
target.text:SetJustifyH("CENTER")

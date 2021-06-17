
--EZDI Item Utility Functions


function EZDI:UseItem(itemName, items)

	return EZDI:UseItemByName(itemName, items)

end


function EZDI:UseItemByName(itemName, items)

	local bag,slot
	
	if items and items[itemName] then
		bag = items[itemName]["bag"]
		slot = items[itemName]["slot"]
	else
		bag, slot = EZDI:FindItem(itemName)
	end
	
	if bag and slot then
		UseContainerItem(bag, slot)
		return true
	end

	return false
	
end


function EZDI:FindItem(item)

	local itemLink,itemID,itemName

	for bag=0,4 do --for each bag
			for slot=1,GetContainerNumSlots(bag) do --for each slot in bag
				itemLink = GetContainerItemLink(bag,slot)
				
				if itemLink then
					_,_,itemID,itemName = string.find(itemLink or "", "item:(%d+).+%[(.+)%]")
					
					if string.lower(item) == string.lower(itemName) then
						return bag,slot
					end
				end
			end
	end
	
	return nil


end

--Only returns the last slot for a particular item
function EZDI:GetAllItems()

	local items = {}
		
	local itemLink,itemID,itemName

	for i=0,4 do --for each bag
			for j=1,GetContainerNumSlots(i) do --for each slot in bag
				itemLink = GetContainerItemLink(i,j)
				
				if itemLink then
					_,_,itemID,itemName = string.find(itemLink or "", "item:(%d+).+%[(.+)%]")
				
					items[itemName] = {}
					items[itemName]["bag"] = i
					items[itemName]["slot"] = j
				end
			end
	end

	
	return items
	
end


function EZDI:UseItemByPriority(itemlist, items)
	
	if not items then
		items = EZDI:GetAllItems()
	end
	
	for _,item in itemlist do
	
		if items[item] then
	
			local bag = items[item]["bag"]
			local slot = items[item]["slot"]
			local startTime, duration = GetContainerItemCooldown(bag, slot)
			
			if duration == 0 then
				UseContainerItem(bag,slot)
				return
			end
		
		end
	
	end

end



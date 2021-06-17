

function UseItem(itemName)

	return UseItemByName(itemName)

end


function UseFirst(itemList)

    return UseItemByPriority(itemList)
    
end


function UseItemByName(itemName, itemInfo)

	--itemName = string.lower(itemName)

	if not itemInfo then
		itemInfo = GetAllItemSlots()
	end
	
	if itemInfo[itemName] then
		local bag = itemInfo[itemName]["bag"]
		local slot = itemInfo[itemName]["slot"]

		UseContainerItem(bag, slot)
	end

end



function UseItemByPriority(itemlist, iteminfo)

	--local iteminfo = GetAllItemSlots()
	
	if not iteminfo then
		iteminfo = GetAllItemSlots()
	end
	
	for _,item in itemlist do
	
		if iteminfo[item] then
	
			local bag = iteminfo[item]["bag"]
			local slot = iteminfo[item]["slot"]
			local startTime, duration = GetContainerItemCooldown(bag, slot)
			
			if duration == 0 then
				UseContainerItem(bag,slot)
				return
			end
		
		end
	
	end

end


--Only returns the last slot for a particular item
function GetAllItemSlots()

	local items = {}
		
	local itemLink,itemID,itemName

	
	for i=0,4 do --for each bag
			for j=1,GetContainerNumSlots(i) do --for each slot in bag
				itemLink = GetContainerItemLink(i,j)
				
				if itemLink then
					_,_,itemID,itemName = string.find(GetContainerItemLink(i,j) or "","item:(%d+).+%[(.+)%]")
				
					items[itemName] = {}
					items[itemName]["bag"] = i
					items[itemName]["slot"] = j
				end
			end
	end

	
	return items
	
end
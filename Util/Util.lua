function print(str)
	DEFAULT_CHAT_FRAME:AddMessage(str)	
end


function getTableSize(t)
	if not t then
		return 0
	end

	local len = 0
	
	for k,v in t do
		len = len + 1
	end
	
	return len
end
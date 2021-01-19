--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 10/01/2021
-- Time: 18:12
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module



-- This script is supposed to alter your unique guid's in item_instance and their references in character_inventory, guild_bank_item and possibly customs
-- to start from 1, counting up without gaps. Do not run this script/command while players are active.

ConsoleOnly = true								-- if true the .sortguid command will not work ingame
MinGMRank = 4									-- staff must have at least this rank to use .sortguid
PrintProgress = 1							-- how often the console or chat should print progression. 1000 means every 1000th item
ChangeCustom = false							-- Is there a custom table e.g. from a transmog module to sort as well?
CustomTableName = "Insert_table_name_here"		-- make this your custom tables name
CustomColumnName = "Insert_column_name_here"	-- make this your custom tables column with the guid to change


------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_COMMAND = 42

local function OnLogin(event, player)
    if player:GetGMRank() >= MinGMRank and not ConsoleOnly then
		player:SendBroadcastMessage("Command .sortguid active.")
	end	
end

local function Sortguid(event, player, command)
	if ConsoleOnly and player then return end					-- this script works only directly from the console if ConsoleOnly is set
	if player then
		if player:GetGMRank() < MinGMRank then return end		-- make sure the staff is properly ranked
	end	
	
    local SortCounter = 1

    if command == "sortguid" then
        QueryItemInstance(player)                      			--get Data from the DB, pass it to itemsGuidArrayLUA[row]
        repeat
		
			if SortCounter == itemsGuidArrayLUA[SortCounter] then	-- if the line is already in the right place dont bother writing again
				print("Skipping: "..SortCounter
				goto skip
			end	
			
            -- Sort item guids
			CharDBExecute("UPDATE item_instance SET guid="..SortCounter.." WHERE guid="..itemsGuidArrayLUA[SortCounter])
			print("UPDATE item_instance SET guid="..SortCounter.." WHERE guid="..itemsGuidArrayLUA[SortCounter])
            
			-- adjust item references in player inventory
			CharDBExecute("UPDATE character_inventory SET item="..SortCounter.." WHERE item="..itemsGuidArrayLUA[SortCounter])
			print("UPDATE character_inventory SET item="..SortCounter.." WHERE item="..itemsGuidArrayLUA[SortCounter])
			
			-- adjust item references in guild banks
			CharDBExecute("UPDATE guild_bank_item SET item_guid="..SortCounter.." WHERE item_guid="..itemsGuidArrayLUA[SortCounter])
			print("UPDATE guild_bank_item SET item_guid="..SortCounter.." WHERE item_guid="..itemsGuidArrayLUA[SortCounter])
			
			-- adjust bag references in player inventory, if the item is a bag
			if has_value(listOfBags, itemsGuidArrayLUA[SortCounter]) then
				CharDBExecute("UPDATE character_inventory SET bag="..SortCounter.." WHERE bag="..itemsGuidArrayLUA[SortCounter])
				print("UPDATE character_inventory SET bag="..SortCounter.." WHERE bag="..itemsGuidArrayLUA[SortCounter])
			end
			
			if ChangeCustom == true then
				CharDBExecute("UPDATE "..CustomTableName.." SET "..CustomColumnName.."="..SortCounter.." WHERE "..CustomColumnName.."="..itemsGuidArrayLUA[SortCounter])
				print("UPDATE "..CustomTableName.." SET "..CustomColumnName.."="..SortCounter.." WHERE "..CustomColumnName.."="..itemsGuidArrayLUA[SortCounter])
			end
			
            if player then
				if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
					player:SendBroadcastMessage("Progressing guid: "..SortCounter.." / "..ItemCounter)
				end	
			else
				if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
					print("Progressing guid: "..SortCounter.." / "..ItemCounter)
				end	
			end
			::skip::
			SortCounter = SortCounter + 1
        until SortCounter == ItemCounter
    end
	itemsGuidArrayLUA = nil			-- free memory
	print("Script .sortguid is done!")
	return false
end

function QueryItemInstance(player)	--get Data from the DB, pass it to Lua arrays
    ItemCounter = 1
	itemsGuidArrayLUA = {}
    --get the item_instance guid column
	print("Reading items from DB...")
	local itemsArraySQL = CharDBQuery("SELECT guid FROM item_instance")
	print("Sorting items in an array...")
	if itemsArraySQL then
        repeat
            itemsGuidArrayLUA[ItemCounter] = itemsArraySQL:GetUInt32(0)
			print("Reading #item "..ItemCounter.." with guid: "..itemsGuidArrayLUA[ItemCounter])
            ItemCounter = ItemCounter + 1
        until not itemsArraySQL:NextRow()
    end
	itemsArraySQL = nil		-- free memory
	
	--get the character_inventory tables bag column
	local n = 1
	characterBagArrayLUA = {}	
	listOfBags = {}
	print("Reading bags from DB...")
	local itemsArraySQL = CharDBQuery("SELECT bag FROM character_inventory")
	print("Making a list of all bags guid's...")
	if itemsArraySQL then
        repeat
            characterBagArrayLUA[n] = itemsArraySQL:GetUInt32(0)
			print("Reading bag"..n..": "..itemsGuidArrayLUA[n])
			if characterBagArrayLUA[n] ~= 0 and not has_value(listOfBags, characterBagArrayLUA[n]) then
				table.insert (listOfBags, characterBagArrayLUA[n])				-- make a list of all bags item guids
				print("Added to list of bags: "..characterBagArrayLUA[n])
			end
            n = n + 1
        until not itemsArraySQL:NextRow()
    end
	itemsArraySQL = nil		-- free memory
end

function ToInteger(number)
    return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
end

function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, Sortguid)
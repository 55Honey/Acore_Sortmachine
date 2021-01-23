--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 10/01/2021
-- Time: 18:12
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module

CustomTableNames = {}
CustomColumnNames = {}

-- This script is supposed to read your unique guid's in item_instance and their references in character_inventory,
-- guild_bank_item and possibly customs to start from 1, counting up without gaps and create a file named
-- "sortguid.sql" in your worldserver.exe directory. Do not run this script/command while players are active.

ConsoleOnly = true																										-- if true the .sortguid command will not work ingame
MinGMRank = 4																											-- staff must have at least this rank to use .sortguid
PrintProgress = 1000																									-- how often the console or chat should print progression. 1000 means every 1000th item
ChangeCustom = false																									-- Is there a custom table e.g. from a transmog module to sort as well? Practically unlimited number possible.
--table.insert(CustomTableNames, 1, "Test_table1")                                                                      -- add a custom table1 to the list
--table.insert(CustomColumnNames, 1, "Test_column1")                                                                    -- add a custom column for table1 to the list
--table.insert(CustomTableNames, 2, "Test_table2")                                                                      -- add a custom table2 to the list
--table.insert(CustomColumnNames, 2, "Test_column2")                                                                    -- add a custom column for table2 to the list

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
	if ConsoleOnly and player then return end																			-- this script works only directly from the console if ConsoleOnly is set
	if player then
    	if player:GetGMRank() < MinGMRank then return end																-- make sure the staff is properly ranked
	end

	local SortCounter = 1
	if command == "sortguid" then
		QueryItemInstance(player)                      																	-- get Data from the DB, pass it to itemsGuidArrayLUA[row]
		WriteSQL()
	end

	print("Script .sortguid is done! Check SortGuid.sql in your worldserver.exe directory.")
	return false
end

function QueryItemInstance(player)																						--get Data from the DB, pass it to Lua arrays
    ItemCounter = 1
	itemsGuidArrayLUA = {}
    print("Reading items from DB...")
	local itemsArraySQL = CharDBQuery("SELECT guid FROM item_instance")													--get the item_instance guid column
	print("Sorting items in an array...")
	if itemsArraySQL then
        repeat
            itemsGuidArrayLUA[ItemCounter] = itemsArraySQL:GetUInt32(0)
			ItemCounter = ItemCounter + 1																				--print("Reading item"..ItemCounter..": "..itemsGuidArrayLUA[ItemCounter])
        until not itemsArraySQL:NextRow()
    end
	table.sort(itemsGuidArrayLUA)																						-- sort the guids in the array ascending from lowest
	itemsArraySQL = nil																									-- free memory
	
	local n = 1
	characterBagArrayLUA = {}
	listOfBags = {}
	print("Reading bags from DB...")
	local itemsArraySQL = CharDBQuery("SELECT bag FROM character_inventory")											--get the character_inventory tables bag column
	print("Making a list of all bags guid's...")
	if itemsArraySQL then
        repeat
            characterBagArrayLUA[n] = itemsArraySQL:GetUInt32(0)
			if characterBagArrayLUA[n] ~= 0 and not has_value(listOfBags, characterBagArrayLUA[n]) then					--print("Reading bag"..n..": "..itemsGuidArrayLUA[n])
				table.insert(listOfBags, characterBagArrayLUA[n])														-- make a list of all bags item guids
			end
            n = n + 1
        until not itemsArraySQL:NextRow()
    end
	itemsArraySQL = nil																									-- free memory
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

function WriteSQL()
	local TermToWrite
	local sqlfile = io.open("SortGuid.sql", "w+")																		-- open and if existant wipe sortguid.sql
	sqlfile:write("SET SQL_SAFE_UPDATES = 0;\n")																		-- add a sql command which allows for unsafe update commands

	repeat

		if SortCounter == itemsGuidArrayLUA[SortCounter] then															-- if the line is already in the right place dont bother writing again
			goto skip
		end

		-- Write to the SQL script:
		sqlfile:write("UPDATE item_instance SET guid="..SortCounter.." WHERE guid="..itemsGuidArrayLUA[SortCounter]..";\n")				-- Sort item guids
		sqlfile:write("UPDATE character_inventory SET item="..SortCounter.." WHERE item="..itemsGuidArrayLUA[SortCounter]..";\n")		-- adjust item references in player inventory
		sqlfile:write("UPDATE guild_bank_item SET item_guid="..SortCounter.." WHERE item_guid="..itemsGuidArrayLUA[SortCounter]..";\n") -- adjust item references in guild banks
		if has_value(listOfBags, itemsGuidArrayLUA[SortCounter]) then
			sqlfile:write("UPDATE character_inventory SET bag="..SortCounter.." WHERE bag="..itemsGuidArrayLUA[SortCounter]..";\n")		-- adjust bag references in player inventory, if the item is a bag
		end

		if ChangeCustom == true then																					-- if changing custom tables is intended..
			for diggit,_ in ipairs(CustomTableNames) do
				if CustomTableNames[diggit] ~= nil and CustomColumnNames[diggit] ~= nil then							-- ..and there is both a table and a column set for the index..
					TermToWrite = "UPDATE "..CustomTableNames[diggit].." SET "..CustomColumnNames[diggit]				-- ..change the guids in that column as well
					TermToWrite = TermToWrite.."="..SortCounter.." WHERE "..CustomColumnNames[diggit].."="
					TermToWrite = TermToWrite..itemsGuidArrayLUA[SortCounter]..";\n"
					sqlfile:write(TermToWrite)
				else																									-- if there is a table specified for a certain index, but no column print an error..
					if player then
						player:SendBroadcastMessage("Error in CostumTableNames or CustomColumnNames: "..diggit)			-- ..in the clients chat if the script was started from there..
					else
						print("Error in CostumTableNames or CustomColumnNames: "..diggit)								-- ..or in the worldserver console if not.
					end
				end
			end
		end

		if player then
			if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
				player:SendBroadcastMessage("Progressing guid: "..SortCounter.." / "..ItemCounter)						-- print progress (ingame if script started from a client) every so often depending on PrintProgress
			end
		else
			if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
				print("Progressing guid: "..SortCounter.." / "..ItemCounter)											-- print progress (in console if script started from there) every so often depending on PrintProgress
			end
		end

		::skip::
		SortCounter = SortCounter + 1

	until SortCounter == ItemCounter

	itemsGuidArrayLUA = nil																								-- free memory
	sqlfile:write("SET SQL_SAFE_UPDATES = 1;\n")																		-- add a sql command which forbids unsafe update commands after our sql is done
	sqlfile:close()
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, Sortguid)
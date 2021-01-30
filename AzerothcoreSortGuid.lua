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

-- Scheme name in your DB
schemename = "acore_characters"

-- If true the .sortguid command will not work ingame
ConsoleOnly = true

-- Staff must have at least this rank to use .sortguid
MinGMRank = 4

-- How often the console or chat should print progression. 1000 means every 1000th item
PrintProgress = 1000

-- For testing. Script will stop after the # of items below.
-- 0 = no limit.
-- 1 = only fixes, no items
-- 2+ = # of items to sort
ItemLimit = 0

-- Is there a custom table e.g. from a transmog module to sort as well? Practically unlimited number possible.
ChangeCustom = false

-- add a custom table and column for it to the list
--table.insert(CustomTableNames, 1, "custom_transmogrification")
--table.insert(CustomColumnNames, 1, "GUID")

-- More custom tables and their columns to change are added the same way, just increment the 2nd argument
--table.insert(CustomTableNames, 2, "Test_table2")
--table.insert(CustomColumnNames, 2, "Test_column2")

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
	-- this script works only directly from the console if ConsoleOnly is set
	if ConsoleOnly and player then return end
	if player then
		-- make sure the staff is properly ranked
		if player:GetGMRank() < MinGMRank then return end
	end

	SortCounter = 1
	if command == "sortguid" then
		-- get Data from the DB, pass it to itemsGuidArrayLUA[row]
		QueryItemInstance(player)
		-- Write commands to a .SQL file
		WriteSQL()
	end

	print("Script .sortguid is done! Check SortGuid.sql in your worldserver.exe directory.")
	return false
end

--get Data from the DB, pass it to Lua arrays
function QueryItemInstance(player)
	ItemCounter = 1
	itemsGuidArrayLUA = {}
	print("Reading items from DB...")
	--get the item_instance guid column from the db
	local itemsArraySQL = CharDBQuery("SELECT guid FROM item_instance")
	print("Adding items in an array...")
	if itemsArraySQL then
		repeat
			itemsGuidArrayLUA[ItemCounter] = itemsArraySQL:GetUInt32(0)
			ItemCounter = ItemCounter + 1
		until not itemsArraySQL:NextRow() or ItemCounter == ItemLimit + 1
	end
	-- sort the guids in the array ascending from lowest
	print("Sorting item array ascending from 1...")
	table.sort(itemsGuidArrayLUA)
	-- free memory
	itemsArraySQL = nil
	
	local n = 1
	characterBagArrayLUA = {}
	listOfBags = {}
	print("Reading bags from DB...")
	--get the character_inventory tables bag column
	local itemsArraySQL = CharDBQuery("SELECT bag FROM character_inventory")
	print("Making a list of all bags guid's...")
	if itemsArraySQL then
        repeat
            characterBagArrayLUA[n] = itemsArraySQL:GetUInt32(0)
			if characterBagArrayLUA[n] ~= 0 and not has_value(listOfBags, characterBagArrayLUA[n]) then
				-- make a list of all bags item guids
				table.insert(listOfBags, characterBagArrayLUA[n])
			end
            n = n + 1
        until not itemsArraySQL:NextRow()
    end
	-- free memory
	itemsArraySQL = nil
end

function ToInteger(number)
    return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
end

-- checks if an array contains a given value
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
	-- open and if existant wipe sortguid.sql
	local sqlfile = io.open("SortGuid.sql", "w+")
	-- choose the right scheme
	sqlfile:write("USE `"..schemename.."`;\n")
	sqlfile:write("\n")
	-- add a sql command which allows for unsafe update commands
	sqlfile:write("SET SQL_SAFE_UPDATES = 0;\n")
	sqlfile:write("\n")
	-- check for broken items. remove them if neccesary.
	sqlfile:write("DELETE FROM `character_inventory`\n")
	sqlfile:write("WHERE NOT EXISTS (\n")
	sqlfile:write("  SELECT *\n")
	sqlfile:write("  FROM `item_instance`\n")
	sqlfile:write("  WHERE `guid` = `character_inventory.item`\n")
	sqlfile:write(");\n")
	sqlfile:write("\n")

	sqlfile:write("DELETE FROM `guild_bank_item`\n")
	sqlfile:write("WHERE NOT EXISTS (\n")
	sqlfile:write("  SELECT *\n")
	sqlfile:write("  FROM `item_instance`\n")
	sqlfile:write("  WHERE `guid` = `guild_bank_item.item_guid`\n")
	sqlfile:write(");\n")
	sqlfile:write("\n")

	sqlfile:write("DELETE FROM `mail_items`\n")
	sqlfile:write("WHERE NOT EXISTS (\n")
	sqlfile:write("  SELECT *\n")
	sqlfile:write("  FROM `item_instance`\n")
	sqlfile:write("  WHERE `guid` = `mail_items.item_guid`\n")
	sqlfile:write(");\n")
	sqlfile:write("\n")

	-- if changing custom tables is intended delete broken references in them
	if ChangeCustom == true then
		for diggit,_ in ipairs(CustomTableNames) do
			if CustomTableNames[diggit] ~= nil and CustomColumnNames[diggit] ~= nil then
				sqlfile:write("DELETE FROM `"..CustomTableNames[diggit].."`\n")
				sqlfile:write("WHERE NOT EXISTS (\n")
				sqlfile:write("  SELECT *\n")
				sqlfile:write("  FROM `item_instance`\n")
				sqlfile:write("  WHERE `guid` = `"..CustomTableNames[diggit].."."..CustomColumnNames[diggit].."`\n")
				sqlfile:write(");\n")
				sqlfile:write("\n")
			end
		end
	end

	if ItemLimit == 1 then goto skip2 end

	repeat
		-- if the line is already in the right place dont bother writing again
		if SortCounter == itemsGuidArrayLUA[SortCounter] then
			goto skip
		end

		-- Write to the SQL script:
		-- Sort item guids
		sqlfile:write("UPDATE `item_instance` SET `guid` = "..SortCounter.." WHERE `guid` = "..itemsGuidArrayLUA[SortCounter].." LIMIT 1;\n")
		-- adjust item references in player inventory
		sqlfile:write("UPDATE `character_inventory` SET `item` = "..SortCounter.." WHERE `item` = "..itemsGuidArrayLUA[SortCounter].." LIMIT 1;\n")
		-- adjust item references in guild banks
		sqlfile:write("UPDATE `guild_bank_item` SET `item_guid` = "..SortCounter.." WHERE `item_guid` = "..itemsGuidArrayLUA[SortCounter].." LIMIT 1;\n")
		-- adjust bag references in player inventory, if the item is a bag
		if has_value(listOfBags, itemsGuidArrayLUA[SortCounter]) then
			sqlfile:write("UPDATE `character_inventory` SET `bag` = "..SortCounter.." WHERE `bag` = "..itemsGuidArrayLUA[SortCounter].." LIMIT 1;\n")
		end
		-- adjust mail_items if the item is in a letter
		sqlfile:write("UPDATE `mail_items` SET `item_guid` = "..SortCounter.." WHERE `item_guid` = "..itemsGuidArrayLUA[SortCounter].." LIMIT 1;\n")

		-- if changing custom tables is intended..
		if ChangeCustom == true then
			for diggit,_ in ipairs(CustomTableNames) do
				-- ..and there is both a table and a column set for the index..
				if CustomTableNames[diggit] ~= nil and CustomColumnNames[diggit] ~= nil then
					-- ..then change the guids in that column as well
					TermToWrite = "UPDATE `"..CustomTableNames[diggit].."` SET `"..CustomColumnNames[diggit]
					TermToWrite = TermToWrite.."` = "..SortCounter.." WHERE `"..CustomColumnNames[diggit].."` = "
					TermToWrite = TermToWrite..itemsGuidArrayLUA[SortCounter]..";\n"
					sqlfile:write(TermToWrite)
				-- if there is a table specified for a certain index, but no column print an error..
				else
					if player then
						-- ..in the clients chat if the script was started from there..
						player:SendBroadcastMessage("Error in CostumTableNames or CustomColumnNames: "..diggit)
					else
						-- ..or in the worldserver console if not.
						print("Error in CostumTableNames or CustomColumnNames: "..diggit)
					end
				end
			end
		end

		::skip::
		if player then
			if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
				-- print progress (ingame if script started from a client) every so often depending on PrintProgress
				player:SendBroadcastMessage("Progressing guid: "..SortCounter.." / "..ItemCounter)
			end
		else
			if ToInteger(SortCounter / PrintProgress) == tonumber(SortCounter / PrintProgress) then
				-- print progress (in console if script started from there) every so often depending on PrintProgress
				print("Progressing guid: "..SortCounter.." / "..ItemCounter)
			end
		end

		SortCounter = SortCounter + 1
		sqlfile:write("\n")
	until SortCounter == ItemCounter

	::skip2::

	-- free memory
	itemsGuidArrayLUA = nil
	-- add a sql command which forbids unsafe update commands after our sql is done
	sqlfile:write("SET SQL_SAFE_UPDATES = 1;\n")
	sqlfile:close()
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, Sortguid)
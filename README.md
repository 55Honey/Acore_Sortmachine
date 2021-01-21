# Acore_Sortmachine

**This is total BETA. Make sure you have decent backups! Do not run it on a live server.**

Please report your findings if you try it. Thank you!

This script is supposed to read your unique guid's in item_instance and their references in character_inventory, guild_bank_item and possibly customs,
to start from 1, counting up without gaps and create a file named "sortguid.sql" in your worldserver.exe directory.

Running it repeatedly will skip creating SQL commands on already sorted items, until a single gap is occured in the servers db.


## Requirements:

Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
Add this script to your `../bin/release/lua_scripts/` directory.

## Usage:

- Run the worldserver standalone. Do **not** have players on the server. Do not have anything active which could potentially create items.
- Type `.sortguid` into the console (recommended) or optionaly on an ingame client with sufficient rights.

## Settings in the .lua file:

`ConsoleOnly = true`

If this is true the .sortguid command will not work ingame but only from the world server console


`MinGMRank = 4`

Staff must have at least this rank to use `.sortguid`


`PrintProgress = 1000`

How often the console or chat should print progression. 1000 means every 1000th item. Skipped or written doesn't matter, both are counted.


`ChangeCustom = false`

If there is a custom table e.g. from a transmog module this must be set to true or all affected items will be lost/bugged


`table.insert(CustomTableNames, 1, "Test_table1")`
`table.insert(CustomColumnNames, 1, "Test_column1")`

Insert your custom tables name and column here. You can add an unlimited (in theory) number of custom spots, as long as there is a column and a table for each custom spot.

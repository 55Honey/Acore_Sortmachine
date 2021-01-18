# Acore_Sortmachine

**This is total BETA. Make sure you have decent backups! Do not run it on a live server.**

Please report your findings if you try it. Thank you!

This script is supposed to alter your unique guid's in item_instance and their references in character_inventory, guild_bank_item and possibly customs.
It's purpose is to close gaps in case the servers #item_guid closes in on 4b.

Running it repeatedly will skip executing SQL commands on already sorted items, until a single gap is occured.


## Requirements:

Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
Add this script to your `../bin/release/lua_scripts/` directory.

## Usage:

- Run the worldserver standalone. Do **not** have players on the server. Do not have anything active which could potentially create items.
- Type `.sortguid` into the console (recommended) or optionaly on an ingame client with sufficient rights.
- Bring time. Local tests on a modern i9 with ssd ran for a split of a second with 1000guids while running this on a remote vps with hdd took 8 hours for ~1mil guids

## Settings in the .lua file:

`ConsoleOnly = true`

If this is true the .sortguid command will not work ingame but only from the world server console


`MinGMRank = 4`

Staff must have at least this rank to use `.sortguid`


`PrintProgress = 1000`

How often the console or chat should print progression. 1000 means every 1000th item. Skipped or written doesn't matter, both are counted.


`ChangeCustom = false`

If there is a custom table e.g. from a transmog module this must be set to true or all affected items will be lost/bugged


`CustomTableName = "Insert_table_name_here"`

Make this your custom tables name.


`CustomColumnName = "Insert_column_name_here"`

Make this your custom tables column with the items guid to change.
-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Wasabi ESX/QBCore Police Job'
author 'wasabirobby'
version '1.10.6'

ui_page 'ui/index.html'
files { 'ui/*', 'ui/**/*' }


data_file 'DLC_ITYP_REQUEST' 'stream/tag.ytyp'

shared_scripts { '@wasabi_bridge/import.lua', 'game/configuration/config.lua', 'game/configuration/locales/*.lua' }

client_scripts { 'game/client/*.lua' }

server_scripts { '@oxmysql/lib/MySQL.lua', 'game/server/*.lua' }

dependencies { 'oxmysql', 'wasabi_bridge' }

provides { 'esx_policejob', 'qb-policejob' }

escrow_ignore {
  'game/**/*.lua',
  'game/configuration/locales/*.lua'
}

dependency '/assetpacks'
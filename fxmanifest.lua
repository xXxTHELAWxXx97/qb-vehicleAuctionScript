fx_version 'adamant'

game 'gta5'

author 'santos#0069'
description 'Simple Vehicle Auction Script'

shared_scripts{
	'config.lua',
	'notifications.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
}

client_scripts {
	'@menuv/menuv.lua',
	'client/utils.lua',
	'client/enumerators.lua',
	'client/client.lua',
}

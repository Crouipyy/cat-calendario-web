fx_version 'cerulean'
game 'gta5'
author 'crouipy'
description 'Calendario escolar'
version '2.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
	'client/*.lua',
}

server_scripts{
    '@oxmysql/lib/MySQL.lua', -- <--- IMPORTANTE
    'server/*.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/script.js',
    'nui/style.css',
    'nui/img/*.png',
    'nui/img/*.svg',
}

-- Añade esta línea para permitir acceso a archivos
server_export 'GuardarCalendarioArchivo'
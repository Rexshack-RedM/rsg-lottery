fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'RexShack'
name 'rsg-lottery'
description 'Lottery script for RSG Framework'
version '3.0.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/webhooks.lua',
    'server/server.lua',
    'server/versionchecker.lua',
}

client_scripts {
    '@rsg-core/client/points.lua',
    'client/client.lua',
}

ui_page 'web/html/lottery.html'

files {
    'locales/*.json',
    'web/html/lottery.html',
    'web/css/lottery.css',
    'web/js/lottery.js',
}

dependencies {
    'rsg-core',
    'oxmysql',
    'rsg-target',
}

lua54 'yes'

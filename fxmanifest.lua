fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'RSG Taxi System'
description 'Advanced taxi system for RedM using RSG2 framework'
author 'RSG Team'
version '1.0.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/npc.lua',
    'client/ui.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/callbacks.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png',
    'html/assets/*.jpg'
}

dependencies {
    'rsg-core',
    'oxmysql'
}

lua54 'yes'
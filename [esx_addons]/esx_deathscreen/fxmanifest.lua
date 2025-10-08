fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

version '1.1.0'
legacyversion '1.13.4'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/deathcam.lua',
    'client/main.lua'
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to rob houses for items to sell'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

client_scripts {
    'client/animations.lua',
    'client/main.lua'
}
server_script 'server/main.lua'

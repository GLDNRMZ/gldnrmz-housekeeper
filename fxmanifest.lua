fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'gldnrmz-housekeeper'
author 'gldnrmz'
description 'House cleaning job (Qbox, QBCore, ESX via community_bridge)'
version '2.0.0'

ox_libs { 'locale' }

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/house.lua',
}

server_script 'server/main.lua'

files {
    'locales/*.json',
}

dependencies {
    'community_bridge',
    '/onesync',
    'ox_lib',
    'qb-interior',
}

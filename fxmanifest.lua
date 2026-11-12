fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'gldnrmz-housekeeper'
author 'gldnrmz'
description 'House cleaning job (Qbox / ox)'
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
    '/onesync',
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'ox_target',
    'qb-interior',
}

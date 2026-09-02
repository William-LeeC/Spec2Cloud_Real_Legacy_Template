fx_version 'cerulean'
game 'gta5'

name 'currency-system'
author 'Project Team'
description 'Dual-balance (cash/bank) currency system (Increment 1 - economic-foundation, specs/frd-currency-system.md)'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'core-framework',
    'oxmysql',
    'ox_lib'
}

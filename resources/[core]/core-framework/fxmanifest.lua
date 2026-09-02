fx_version 'cerulean'
game 'gta5'

name 'core-framework'
author 'Project Team'
description 'Core Player Framework & Persistence (Increment 1 - economic-foundation, specs/frd-core-framework.md)'
version '0.1.0'

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql'
}

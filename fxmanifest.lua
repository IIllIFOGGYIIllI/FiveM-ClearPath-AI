fx_version 'cerulean'
game 'gta5'

author 'IIIIFOGGYIIII'
description 'Standalone predictive AI traffic yielding for emergency vehicles.'
version '0.1.10'

shared_script 'config.lua'

client_scripts {
    'client/utils.lua',
    'client/main.lua'
}

server_script 'server/main.lua'

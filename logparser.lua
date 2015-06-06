local kyny = require 'lib.csparse'
local pretty = require 'pl.pretty'
local tablex = require 'pl.tablex'
local _ = require 'moses'
local os = require 'os'

if (tablex.size(arg) < 4) then
    print("Usage: lua logparser.lua <LOGDIR> <APIADDRESS>")
    print("Example: lua logparser.lua logs http://localhost:9000/api")
    os.exit(1)
end

local Entries = {}

function inc(t, k, v)
    t[k] = t[k] + v
end

local function getUser(user)
    if (Entries[user.steam_id] == nil) then
        Entries[user.steam_id] = {
            kills = 0,
            hits = 0,
            assists = 0,
            headshots = 0,
            deaths = 0,
        }
    end
    return Entries[user.steam_id] 
end


kyny.walk_logs(arg[1], function(timestamp, user, method, data)
    userEntity = getUser(user)
    if (method == 'kill') then
        if (data.is_headshot) then
            userEntity.headshots = userEntity.headshots + 1
        end
        userEntity.kills = userEntity.kills + 1
        Entries[data.target_id].deaths = Entries[data.target_id].deaths + 1
    elseif (method == 'assisted') then
        userEntity.assists = userEntity.assists + 1
    elseif (method == 'hit') then
        userEntity.hits = userEntity.hits + 1
    end
end)

print(tablex.size(arg))

for key, val in pairs(Entries) do
    print('')
    print(key)
    pretty.dump(val)
end

print('')
print('=> ' .. arg[2] .. '/stats')
print('')

local reply = kyny.post_to_web(arg[2] .. '/stats', Entries)
pretty.dump(reply)

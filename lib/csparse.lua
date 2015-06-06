local fs = require 'luarocks.fs'
local stringio = require('pl.stringio')
local stringx = require('pl.stringx')
local List = require('pl.List')
local dkjson = require('dkjson')
local http = require('socket.http')
local ltn12 = require('ltn12')


local function sanitize(str)
  return string.sub(str, 2, string.len(str) - 1) 
end

local function for_loglines(path, entry_parser)
    entry_parser = entry_parser or function() end
    for filepath in fs.dir(path) do
        local file = io.open(path .. '/' .. filepath, 'r')
        for line in file:lines() do entry_parser(line) end
        file:close()
    end
end

local function parse_user_and_timestamp(M, D, Y, h, m, s, name, id, steam_id, team, callback)
    return function(event, data)
        local user = {
            steam_id = steam_id,
            nick = name,
            team = team
        }

        local timestamp = os.time{
            year = Y,
            month = M,
            day = D,
            hour = h,
            minute = m,
            second = s
        }

        callback(timestamp, user, event, data)
    end
end

local function match_actions(str, cb)
    local event, value = string.match(str, '^(%w+) (.+)$')
    if event and value then
        if event == 'purchased' or event == 'say' then
            value = sanitize(value)
        elseif event == 'threw' then
            local gtype, x, y, z = string.match(value, '^(%g+) %[(.+) (.+) (.+)%]$')
            cb('onThrow', {
              type = gtype,
              x = x,
              y = y,
              z = z,
            })
        elseif event == 'assisted' then
            value = string.match(value, '.*<(STEAM%g+%d)>.*')
        end
        cb(event, value)
        return true
    end
end

local function match_attack(str, f)
    fx, fy, fz, target_id, tx, ty, tz, gun, damage, damage_armor, health, armor, hitgroup
        = string.match(str, '^%[(.+) (.+) (.*)%] attacked .*<(STEAM%g+%d)>.* %[(.+) (.+) (.*%d)%] with "(%g+)" %(damage "(%d+)"%) %(damage_armor "(%d+)"%) %(health "(%d+)"%) %(armor "(%d+)"%) %(hitgroup "(.+)"%)')
    if (fx) then
        f({
            fx = fx,
            fy = fy,
            fz = fz,
            target_id = target_id,
            tx = tx,
            ty = ty,
            tz = tz,
            gun = gun,
            damage = damage,
            damage_armor = damage_armor,
            health = health,
            armor = armor,
            hitgroup = hitgroup
        })
        return true
    end
end

local function match_kill(str, f)
    fx, fy, fz, target_id, tx, ty, tz, gun, headshot
        = string.match(str, '^%[(.+) (.+) (.*)%] killed .*<(STEAM%g+%d)>.* %[(.+) (.+) (.*%d)%] with "(%g+)"(.*)')
    if (fx) then
        f({
            fx = fx,
            fy = fy,
            fz = fz,
            target_id = target_id,
            tx = tx,
            ty = ty,
            tz = tz,
            weapon = gun,
            is_headshot = headshot ~= ''
        })
        return true
    end
end

function walk_csgo_logs(path, callback)
    for_loglines(path, function(line)
        local M, D, Y, h, m, s, msg = string.match(string.sub(line, 3), '(%d%d)/(%d%d)/(%d%d%d%d) %- (%d%d):(%d%d):(%d%d): (.+)')
        local first_data, rest = string.match(msg or '', '(%g+) (.+)$')
        local name, id, steam_id, team = string.match(first_data or '', '"(.+)<(.+)><(.*)><(.*)>"')
        local cb = parse_user_and_timestamp(M, D, Y, h, m, s, name, id, steam_id, team, callback)

        if name and tonumber(id) > 0 and steam_id and steam_id ~= 'BOT' then
            if match_actions(rest, cb) then
            elseif match_kill(rest, function(data) cb('kill', data) end) then
            elseif match_attack(rest, function(data) cb('hit', data) end) then
            end
        elseif first_data == 'Team' then
        elseif first_data == 'World' then
        elseif tonumber(id) == 0 then
        elseif steam_id == nil then
        else -- BOT stuff goes here (we are not interested)
        end
    end)
end

function post_data(url, data)
    local body = dkjson.encode(data)
    local headers = {
        ["content-length"] = body:len(),
        ["Content-Type"] = "application/json"
    }
    local response = {}
    local r, c, h = http.request{
        url= url,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response)
    }
    return response
end

return {
  walk_logs = walk_csgo_logs,
  post_to_web = post_data
}

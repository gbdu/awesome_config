--[[
  Licensed under GNU General Public License v2
   * (c) 2014, Yauheni Kirylau
--]]

local dbus = dbus
local awful = require("awful")

local async = require("utils.async")
local h_table = require("utils.table")
local h_string = require("utils.string")
local parse = require("utils.parse")

local lgi = require 'lgi'
local Gio = lgi.require 'Gio'
--local inspect = require("inspect")

-- @TODO: change to native dbus implementation instead of calling qdbus
local dbus_cmd = "qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 "

local spotify = {
  player_status = {},
  player_cmd = 'spotify'
}

function spotify.init(widget)
  dbus.add_match("session", "path='/org/mpris/MediaPlayer2',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'")
  dbus.connect_signal(
    "org.freedesktop.DBus.Properties",
    function(...)
      widget.update()
    end)
end

-------------------------------------------------------------------------------
function spotify.toggle()
  awful.util.spawn_with_shell(dbus_cmd .. "PlayPause")
end


function spotify.toggle2()
  spotify.bus = Gio.bus_get_sync(Gio.BusType.SESSION)
  local result, err = spotify.bus:call_sync(
    'org.mpris.MediaPlayer2.spotify',

    --'/',
    '/org/mpris/MediaPlayer2',

    --'org.freedesktop.MediaPlayer2',
    'org.mpris.MediaPlayer2.Player',

    --'GetMetadata',
    'PlayPause',

    nil,
    nil,
    Gio.DBusConnectionFlags.NONE,
    -1
  )
  spotify.bus:flush()
  result, err = spotify.bus:call_sync(
    'org.mpris.MediaPlayer2.spotify',

    --'/',
    '/org/mpris/MediaPlayer2',

    --'org.freedesktop.MediaPlayer2',
    'org.mpris.MediaPlayer2.Player',

    --'GetMetadata',
    'PlayPause',

    nil,
    nil,
    Gio.DBusConnectionFlags.NONE,
    -1
  )
  --if result then
    --for a, b in pairs(result.value) do
      --print('---')
      --print(a)
      ----print(inspect(b))
    --end
  --else
    --print('error:')
    --print(inspect(err))
  --end
end

function spotify.next_song()
  awful.util.spawn_with_shell(dbus_cmd .. "Next")
end

function spotify.prev_song()
  awful.util.spawn_with_shell(dbus_cmd .. "Previous")
end
-------------------------------------------------------------------------------
function spotify.update(parse_status_callback)
  async.execute(
    dbus_cmd .. "PlaybackStatus",
    function(str) spotify.post_update(str, parse_status_callback) end
  )
end
-------------------------------------------------------------------------------
function spotify.post_update(result_string, parse_status_callback)
  spotify.player_status = {}
  local state = nil
  if result_string:match("Playing") then
    state = 'play'
  elseif result_string:match("Paused") then
    state = 'pause'
  end
  spotify.player_status.state = state
  if state == 'play' or state == 'pause' then
    async.execute(
      dbus_cmd .. "Metadata",
      function(str) spotify.parse_metadata(str, parse_status_callback) end
    )
  else
    parse_status_callback(spotify.player_status)
  end
end
-------------------------------------------------------------------------------
function spotify.parse_metadata(result_string, parse_status_callback)
  local player_status = parse.find_values_in_string(
    result_string,
    "([%w]+): (.*)$",
    { artist='artist',
      title='title',
      album='album',
      date='contentCreated',
      cover_url='artUrl'
    }
  )
  player_status.date = h_string.max_length(player_status.date, 4)
  player_status.file = 'spotify stream'
  h_table.merge(spotify.player_status, player_status)
  parse_status_callback(spotify.player_status)
end

-------------------------------------------------------------------------------
function spotify.resize_cover(
  player_status, _, output_coverart_path, notification_callback
)
  async.execute(
    string.format(
      "wget %s -O %s",
      player_status.cover_url,
      output_coverart_path
    ),
    function() notification_callback() end
  )
end

return spotify

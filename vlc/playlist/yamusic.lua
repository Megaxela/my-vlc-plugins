

-- https://music.yandex.ru/users/Crucian/playlists/1075
USER_PLAYLIST_RE = "/users/.*/playlists/[0-9]+"

-- https://music.yandex.ru/album/24342301/track/109868247
TRACK_RE = "/album/[0-9]+/track/[0-9]+"

-- https://music.yandex.ru/album/24480516
ALBUM_PLAYLIST_RE = "/album/[0-9]+"

function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function trim5(s)
   return s:match'^%s*(.*%S)' or ''
end

function parse_script_line(line)
    key_start, key_end = line:find(':')
    key = line:sub(0, key_end - 1)
    value = trim5(line:sub(key_end + 1))

    vlc.msg.dbg(string.format("[yamusic] Line: '%s', key: '%s', value: '%s'", line, key, value))

    return key, value
end

function update_context(ctx, key, value)
   if key == 'author' then
      ctx.artist = value
   elseif key == 'url' then
      ctx.path = value
   elseif key == 'title' then
      ctx.title = value
   elseif key == 'duration' then
      ctx.duration = tonumber(value)
   elseif key == 'eof' then
      return true
   end
   return false
end

function context_to_track(ctx)
   -- ye, this function is kinda useless, but it may be useful later
   return ctx
end

function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end

-- Probe function.
function probe()
   local probe_result = (
      (
         vlc.access == "http"
         or
         vlc.access == "https"
      )
      and
      (
          (
              -- https://music.yandex.ru/users/Crucian/playlists/1075
              string.match( vlc.path, "^music%.yandex%.ru/" )
              or
              -- https://music.yandex.com/users/Crucian/playlists/1075
              string.match( vlc.path, "^music%.yandex%.com/" )
          )
          and
          (
             string.match( vlc.path, USER_PLAYLIST_RE )
             or
             string.match( vlc.path, TRACK_RE)
             or
             string.match( vlc.path, ALBUM_PLAYLIST_RE)
          )
          and
          (
             -- Require access token
             -- https://music.yandex.ru/album/24480516#access_token=xxxxxxx
             string.match( vlc.path, "?access_token=.+" )
          )
      )
   );

   vlc.msg.dbg(string.format("[yamusic] Probing '%s' with YaMusic: '%s'", vlc.path, tostring(probe_result)))

   return probe_result
end


-- Parse function.
function parse()
   vlc.msg.dbg("[yamusic] Start executing YaMusic parse function ")

   line_iter = os.capture(
      string.format('python3 %s/yamusic.py %s', script_path(), vlc.path),
      true
   ):gmatch("[^\r\n]+")

   if string.match(vlc.path, TRACK_RE) then
      -- Parse only one item
      vlc.msg.dbg(string.format("[yamusic] Detected track: %s", vlc.path))

      ctx = {}
      for line in line_iter do
         key, value = parse_script_line(line)

         if (update_context(ctx, key, value)) then
            return { context_to_track(ctx) }
         end
      end
   end

   -- Parse multiple items
   vlc.msg.dbg(string.format("[yamusic] Detected some sort of playlist: %s", vlc.path))
   result = {}
   iterator = 0

   ctx = {}
   for line in line_iter do
      key, value = parse_script_line(line)

      if (update_context(ctx, key, value)) then
         result[iterator] = context_to_track(ctx)
         ctx = {}
         iterator = iterator + 1
      end
   end

   return result
end

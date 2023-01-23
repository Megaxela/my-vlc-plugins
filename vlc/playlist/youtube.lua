TRACK_RE = "/watch%?"

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

function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end


function parse_script_line(line)
    key_start, key_end = line:find(':')
    key = line:sub(0, key_end - 1)
    value = trim5(line:sub(key_end + 1))

    vlc.msg.dbg(string.format("[youtube] Line: '%s', key: '%s', value: '%s'", line, key, value))

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
            (
               string.match( vlc.path, "^www%.youtube%.com/" )
               or
               string.match( vlc.path, "^music%.youtube%.com/" )
            )
            and
            (
               string.match( vlc.path, TRACK_RE ) -- the html page
               or
               string.match( vlc.path, "/playlist%?" ) -- the html page
               or
               string.match( vlc.path, "/live$" ) -- user live stream html page
               or
               string.match( vlc.path, "/live%?" ) -- user live stream html page
               or
               string.match( vlc.path, "/get_video_info%?" ) -- info API
               or
               string.match( vlc.path, "/v/" ) -- video in swf player
               or
               string.match( vlc.path, "/embed/" ) -- embedded player iframe
            )
         )
         or
         string.match( vlc.path, "^consent%.youtube%.com/" )
      )
   );

   vlc.msg.dbg(string.format("[youtube] Probing '%s' with YouTube: '%s'", vlc.path, tostring(probe_result)))

   return probe_result;
end


-- Parse function.
function parse()
   vlc.msg.info("[youtube] Start executing YouTube parse function (v1.0)")

   line_iter = os.capture(
      string.format('python3 %s/youtube.py %s', script_path(), vlc.path),
      true
   ):gmatch("[^\r\n]+")

   if string.match(vlc.path, TRACK_RE) then
      -- Parse only one item
      vlc.msg.dbg(string.format("[youtube] Detected track: %s", vlc.path))

      ctx = {}
      for line in line_iter do
         key, value = parse_script_line(line)

         if (update_context(ctx, key, value)) then
            return { context_to_track(ctx) }
         end
      end
   end

   vlc.msg.dbg(string.format("[youtube] Detected some sort of playlist: %s", vlc.path))
   result = {}
   iterator = 1

   ctx = {}
   for line in line_iter do
      key_value = parse_script_line(line)

      if (update_context(ctx, key, value))
         result[iterator] = context_to_track(ctx)
         iterator = iterator + 1
      end
   end

   return result
end

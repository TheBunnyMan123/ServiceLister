local socket = require("socket")

--{{Options
PORT=8080
BACKLOG=5
--}}

function generateElement(tbl)
  local attrs = ""
  tbl.type = tbl.type or "span"
  tbl.content = tbl.content or ""

  for k, v in pairs(tbl.attributes or {}) do
    attrs = attrs .. " " .. k .. "=" .. '"' .. tostring(v):gsub('"', '\\"') .. '"'
  end

  return ("<%s%s>%s</%s>"):format(tbl.type, attrs, tbl.content, tbl.type)
end
function generatePage(head, tbl)
  local final = ""
  local finalhead = ""

  for _, v in pairs(head) do
    finalhead = finalhead .. generateElement(v)
  end
  for _, v in ipairs(tbl) do
    final = final .. (type(v) == "string") or generateElement(v)
  end

  return ([[<!DOCTYPE HTML>
  <html>
    <head>
      <link href="/style" rel="stylesheet">
      %s
    </head>
    <body>
      %s
    </body>
  </html>
  ]]):format(finalhead, final)
end

local server = assert(socket.tcp())
assert(server:bind("*", PORT))
server:listen(BACKLOG)

while true do
  print("Awaiting connection")
  local client, error = server:accept()

  if client then
    print(client)
    print("Connected")
    client:settimeout(5)
    local line, err = client:receive()
    local page = "home"
    local final = {
      headers = {}
    }

    local iter = 1

    while line ~= "" do
      if not err then
        if iter == 1 then
          final.method = line:match("^(.-)%s")
          page = line:gsub("^(.-)%s", ""):match("^(.-)%s"):gsub("/", ".")
        else
          local header = line:match("^(.-): ")
          local value = line:gsub("^(.-): ", "")
          final.headers[header] = value
        end
      else
        print("An error occured:", error)
      end

      line, err = client:receive()
      iter = iter + 1
    end

    if page == "." then page = ".home" end
    
    local success, func = pcall(require, "pages" .. page)

    if success then
      print("Sending page " .. page:gsub("^%.", ""))
      client:send("HTTP/1.0 200 OK\n\n" .. func(final))
    else
      client:send("HTTP/1.0 404 NOT FOUND\n\n" .. require("statuspages.404"))
    end
  else
    print("An error occured:", error)
  end

  client:close()
  print("Terminated")
end


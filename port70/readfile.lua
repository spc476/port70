-- ************************************************************************
--
--    Read a file just prior to sending it
--    Copyright 2019 by Sean Conner.  All Rights Reserved.
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--    Comments, questions and criticisms can be sent to: sean@conman.org
--
-- ************************************************************************
-- luacheck: ignore 611

local syslog   = require "org.conman.syslog"
local mimetype = require "org.conman.parsers.mimetype"
local fsys     = require "org.conman.fsys"
local magic    = require "org.conman.fsys.magic"
local url      = require "org.conman.parsers.url.gopher"
               + require "org.conman.parsers.url"
local mklink   = require "port70.mklink"
local cgi      = require "port70.cgi"
local lpeg     = require "lpeg"
local io       = require "io"
local table    = require "table"

local require  = require
local type     = type
local assert   = assert

-- ************************************************************************

local parseline do
  local Cc = lpeg.Cc
  local C  = lpeg.C
  local P  = lpeg.P
  local R  = lpeg.R
  
  local entry = P"\t"
              * C(R" ~"^1) * P"\t"^1 -- type
              * C(R" ~"^1) * P"\t"^1 -- selector
              * C(R" \255"^0)        -- display
              
  local code  = P"\t"
              * C"Lua{"              -- type
              * Cc""                 -- selector
              * Cc""                 -- display
              
  local info  = Cc"info"             -- type
              * Cc""                 -- selector
              * C(R" \255"^0)        -- display
              
  parseline = entry + code + info
end

local cleanpath do
  local char = lpeg.P"/"^1 / "/"
             + lpeg.P(1)
  cleanpath  = lpeg.Cs(char^0)
end

-- ************************************************************************

local function execblock(name,file,ios)
  local acc = {}
  
  repeat
    local line = file:read("*L")
    table.insert(acc,line)
  until line:match "}Lua"
  
  table.remove(acc)
  
  local code  = table.concat(acc," ")
  local env   = { require = require }
  local f,err = load(code,name,"t",env)
  
  if not f then
    syslog('error',"%s: %s",name,err)
    ios:write(mklink {
        type = 'info',
        display = "Nothing in particular right now"
    })
  else
    local data = f()
    if type(data) == 'table' then
      ios:write(table.concat(data,"\r\n"))
    else
      ios:write(data)
    end
  end
end

-- ************************************************************************

return function(filename,ext,info,request,ios)
  assert(ios)
  assert(ios.write)
  assert(ios._drain)
  
  filename = cleanpath:match(filename)
  
  if not filename then
    syslog('warning',"readfile() bad cleanpath")
    ios:write(mklink { type = 'error' , display = "Selector not found" , selector = request.selector })
    return false
  end
  
  if fsys.access(filename,"rx") then
    syslog('debug',"selector=%s rest=%s",request.selector,request.rest)
    return cgi(filename,info,request,ios)
  end
  
  if filename:match(ext) then
    local file = io.open(filename,"r")
    if not file then
      ios:write(mklink { type = 'error' , display = "Selector not found" , selector = request.selector })
      return false
    end
    
    for line in file:lines() do
      local gtype,selector,display = parseline:match(line)
      if gtype == 'url' then
        local uri = url:match(selector)
        if uri.scheme == 'gopher' then
          uri.display = display
          ios:write(mklink(uri))
        else
          ios:write(mklink {
                type     = 'html',
                display  = display,
                selector = "URL:" .. selector
          })
        end
      elseif gtype == 'Lua{' then
        execblock(filename,file,ios)
      else
        ios:write(mklink {
                type     = gtype,
                display  = display,
                selector = selector
        })
      end
    end
    
    file:close()
    return true
  end
  
  local mime = mimetype:match(magic(filename))
  
  if mime.type:match "^text/" then
    local file,err = io.open(filename,"r")
    if not file then
      syslog('error',"io.open(%q) = %s",filename,err)
      ios:write(mklink { type = 'error' , display = "Selector not found" , selector = request.selector })
      return false
    end
    
    for line in file:lines() do
      ios:write(line,"\r\n")
    end
    
    file:close()
    return true
    
  else
    local file,err = io.open(filename,"rb")
    if not file then
      syslog('error',"io.open(%q) = %s",filename,err)
      ios:write(mklink { type = 'error' , display = "Selector not found" , selector = request.selector })
      return false
    end
    
    repeat
      local data = file:read(1024)
      if data then
        ios:write(data)
      end
    until not data
    
    file:close()
    return true,true
  end
end

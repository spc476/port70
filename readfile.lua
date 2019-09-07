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

local mimetype = require "org.conman.parsers.mimetype"
local magic    = require "org.conman.fsys.magic"
local gtypes   = require "org.conman.const.gopher-types"
local url      = require "org.conman.parsers.url.gopher"
               + require "org.conman.parsers.url"
local lpeg     = require "lpeg"
local io       = require "io"
local table    = require "table"

local require  = require

magic:flags('mime')

-- ************************************************************************

local parseline do
  local Cc = lpeg.Cc
  local C  = lpeg.C
  local P  = lpeg.P
  local R  = lpeg.R
  
  local entry = P"\t"
              * C(R" ~"^1) * P"\t"^1 -- type
              * C(R" ~"^1) * P"\t"^1 -- selector
              * C(R" ~"^0)           -- display
              
  local info  = Cc"info"             -- type
              * Cc""                 -- selector
              * C(R" ~"^0)           -- display
              
  parseline = entry + info
end

-- ************************************************************************

return function(filename)
  if filename:match "%.gopher$" then
    local CONF     = require "CONF"
    local file,err = io.open(filename,"r")
    if not file then
      return false,err
    end
    
    local acc = {}
    for line in file:lines() do
      local type,selector,display = parseline:match(line)
      if type == 'url' then
        local uri = url:match(selector)
        if uri.scheme == 'gopher' then
          table.insert(acc,string.format(
                "%s%s\t%s\t%s\t%d",
                gtypes[uri.type],
                display,
                uri.selector,
                uri.host,
                uri.port
          ))
        else
          table.insert(acc,string.format(
                "%s%s\t%s\t%s\t%d",
                gtypes.html,
                display,
                "URL:" .. selector,
                CONF.network.host,
                CONF.network.port
         ))
        end
      elseif type == 'Lua' then
        -- XXX how to handle it
        table.insert(acc,"iLUACODE\t-\t-\t0")
      else
        table.insert(acc,string.format(
                "%s%s\t%s\t%s\t%d",
                gtypes[type],
                display,
                selector,
                CONF.network.host,
                CONF.network.port
        ))
      end
    end
    
    file:close()
    return true,table.concat(acc,"\r\n") .. "\r\n.\r\n"
  end
  
  local mime = mimetype:match(magic(filename))
  
  if mime.type:match "^text/" then
    local file,err = io.open(filename,"r")
    if not file then
      return false,err
    end
    
    local acc = {}
    for line in file:lines() do
      table.insert(acc,line)
    end
    
    file:close()
    return true,table.concat(acc,"\r\n") .. "\r\n.\r\n"
    
  else
    local file,err = io.open(filename,"rb")
    if not file then
      return false,err
    end
    
    local data = file:read("*a")
    file:close()
    return true,data
  end
end

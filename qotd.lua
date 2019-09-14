-- ************************************************************************
--
--    QOTD module
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
-- luacheck: globals init fini handler
-- luacheck: ignore 611

local syslog = require "org.conman.syslog"
local io     = require "io"
local os     = require "os"
local string = require "string"
local table  = require "table"
local CONF   = require "CONF".qotd
local mklink = require "mklink"

_ENV = {}

-- ************************************************************************

local function dudload()
  return mklink {
        type = 'info',
        display = "Some pithy quote goes here ... ",
  }
end

if not CONF then
  return dudload
end

local QUOTES,INDEX,NEXT,MAX do
  local err
  QUOTES,err = io.open(CONF.quotes,"r")
  
  if not QUOTES then
    syslog('error',"qotd: %s: %s",CONF.quotes,err)
    return dudload
  end
  
  local f,err1 = io.open(CONF.index,"rb")
  if not f then
    syslog('error',"qotd: %s: %s",CONF.index,err1)
    CONF.quotes:close()
    return dudload
  end
  
  INDEX    = {}
  NEXT,MAX = string.unpack("<I4I4",f:read(8))
  NEXT     = NEXT + 1 -- adjust for 0 based index
  
  for _ = 1 , MAX do
    local s = f:read(4)
    local i = string.unpack("<I4",s)
    table.insert(INDEX,i)
  end
  
  table.insert(INDEX,f:seek('cur'))
  f:close()
  
  local state = io.open(CONF.state,"r")
  if state then
    NEXT = state:read("*n")
    state:close()
  end
  
  QUOTES:seek('set',INDEX[NEXT])
  
  -- ---------------------------------------------------------------------
  -- Sigh.  Since there's no os.atexit(), we need to kind of monkey patch
  -- something like that in, so we replace os.exit() with our own exit()
  -- function that does the clean up we need to do.
  -- ---------------------------------------------------------------------
  
  local lua_exit = os.exit
  
  os.exit = function(...)
    QUOTES:close()
    local f1 = io.open(CONF.state,"w")
    if f1 then
      f1:write(NEXT,"\n")
      f1:close()
    end
    lua_exit(...)
  end
end

-- ************************************************************************

return function()
  local amount = INDEX[NEXT + 1] - INDEX[NEXT]
  local quote  = QUOTES:read(amount)
  local acc    = {}
  
  for line in quote:gmatch "[^\n]+" do
    table.insert(acc,mklink {
        type = 'info',
        display = line,
    })
  end
  
  NEXT = NEXT + 1
  
  if NEXT > MAX then
    NEXT = 1
    QUOTES:seek('set',0)
  end
  
  return acc
end

-- ************************************************************************

-- ***********************************************************************
--
-- Copyright 2019 by Sean Conner.
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the
-- Free Software Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
-- Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Comments, questions and criticisms can be sent to: sean@conman.org
--
-- ***********************************************************************
-- luacheck: ignore 611

local syslog = require "org.conman.syslog"
local signal = require "org.conman.signal"
local nfl    = require "org.conman.nfl"
local tcp    = require "org.conman.nfl.tcp"
local exit   = require "org.conman.const.exit"
local net    = require "org.conman.net"
local lpeg   = require "lpeg"

local CONF = {}

-- ************************************************************************

if #arg == 0 then
  io.stderr:write(string.format("usage: %s configfile\n",arg[0]))
  os.exit(exit.USAGE,true)
end

do
  local conf,err = loadfile(arg[1],"t",CONF)
  if not conf then
    io.stderr:write(string.format("%s: %s\n",arg[1],err))
    os.exit(exit.CONFIG,true)
  end
  
  conf()
  
  if not CONF.syslog then
    CONF.syslog = { ident = 'gopher' , facility = 'daemon' }
  else
    CONF.syslog.ident    = CONF.syslog.ident    or 'gopher'
    CONF.syslog.facility = CONF.syslog.facility or 'daemon'
  end
  
  syslog.open(CONf.syslog.ident,CONF.syslog.facility)
  
  if not CONF.handlers then
    CONF.handlers = { selector = "/" , module = "filesystem" , directory = "share" }
  end
  
  -- -------------------------------------------------------------------------
  -- The handlers are sorted by length of selector (longest match wins!),
  -- and then the selector is swapped out with an LPEG pattern that matches
  -- said string, plus any additional text beyond the selector.  This is
  -- pretty much what I want, with any sub-parsing done by the individual
  -- handler.  We also initialize each handler as well.
  -- -------------------------------------------------------------------------
  
  local function loadmodule(info)
    local function notfound(_,base,rest,search)
      syslog('debug',"base=%q rest=%q search=%q",base,rest,search or "")
      return false,"Selector not found"
    end
    
    local okay,code = pcall(require,info.module)
    if not okay then
      syslog('error',"%q %s",info.selector,code)
      return { handler = notfound }
    end
    
    if type(code) ~= 'table' then
      syslog('error',"%q module %q not supported",info.selector,info.module)
      return { handler = notfound }
    end
    
    if not code.handler then
      syslog('error',"%q missing %s.handler()",info.selector,info.module)
      code.handler = notfound
      return code
    end
    
    if code.init then
      okay,err = code.init(info)
      if not okay then
        syslog('error',"%q %s=%s",info.selector,info.module,err)
        code.handler = notfound
        return code
      end
    end
    
    return code
  end
  
  table.sort(CONF.handlers,function(a,b) return #a.selector > #b.selector end)
  for _,handler in ipairs(CONF.handlers) do
    handler.code     = loadmodule(handler)
    handler.selector = lpeg.C(handler.selector) * lpeg.C(lpeg.R" ~"^0)
  end
  
  CONF._internal = {}
  CONF._internal.addr = net.address2(CONF.network.addr,'any','tcp',CONF.network.port)[1]
  package.loaded['CONF'] = CONF
end

-- ************************************************************************

local parserequest = lpeg.C(lpeg.R" ~"^0)
                   * (lpeg.P"\t" * lpeg.C(lpeg.R" ~"^1))^-1
                   
local function main(ios)
  syslog('debug',"connection %s",ios.__remote.addr)
  local request = ios:read("*l")
  if not request then
    local msg = "3Bad request\tERROR\texample.com\t70\r\n"
    ios:write(msg)
    syslog(
        'info',
        "remote=%s status=false request=%q bytes=%d",
        ios.__remote.addr,
        "nil",
        #msg
    )
    ios:close()
  end
  
  local selector,search = parserequest:match(request)
  syslog('debug',"selector=%q search=%q",selector,search or "")
  
  for _,handler in ipairs(CONF.handlers) do
    local base,rest = handler.selector:match(selector)
    if base then
      if handler.module == 'http' then
        repeat local line = ios:read("*l") until line == ""
      end
      
      local okay,text = handler.code.handler(handler,base,rest,search)
      
      if not okay then
        text = string.format("3%s\tERROR\texample.com\t70\r\n",text)
      end
      
      ios:write(text)
      syslog(
        'info',
        "remote=%s status=%s request=%q bytes=%d",
        ios.__remote.addr,
        tostring(okay),
        request,
        #text
      )
      ios:close()
      return
    end
  end
  
  assert(false)
end

-- ************************************************************************

local okay,err = tcp.listena(CONF._internal.addr,main)

if not okay then
  io.stderr:write(string.format("%s: %s\n",arg[1],err))
  syslog('error',"%s: %s",arg[1],err)
  os.exit(exit.OSERR,true)
end

signal.catch('int')
signal.catch('term')
syslog('info',"entering service")
nfl.server_eventloop(function() return signal.caught() end)

for _,handler in ipairs(CONF.handlers) do
  if handler.fini then
    local ok,status = pcall(handler.code.fini)
    if not ok then
      syslog('error',"%s: %s",handler.module,status)
    end
  end
end

os.exit(true,true)

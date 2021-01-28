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

local syslog  = require "org.conman.syslog"
local signal  = require "org.conman.signal"
local nfl     = require "org.conman.nfl"
local tcp     = require "org.conman.nfl.tcp"
local exit    = require "org.conman.const.exit"
local magic   = require "org.conman.fsys.magic"
local lpeg    = require "lpeg"
local setugid = require "port70.setugid"

local CONF = {}

magic:flags("mime")

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
  
  syslog.open(CONF.syslog.ident,CONF.syslog.facility)
  
  if not CONF.network
  or not CONF.network.host then
    syslog('critical',"%s: missing or bad network configuration",arg[1])
    os.exit(exit.CONFIG,true)
  end
  
  if not CONF.network.addr then
    CONF.network.addr = "::"
  end
  
  if not CONF.network.port then
    CONF.network.port = 70
  end
  
  package.loaded['port70.CONF'] = CONF
  
  if not CONF.handlers then
    CONF.handlers = { }
  end
  
  local function loadmodule(info)
    local function notfound()
      return false,"Selector not found"
    end
    
    if not info.selector then
      syslog('error',"missing path field in handler")
      info.path = ""
      info.code = { handler = notfound }
      return
    end
    
    if not info.module then
      syslog('error',"%s: missing module field",info.path)
      info.code = { handler = notfound }
      return
    end
    
    local okay,mod = pcall(require,info.module)
    if not okay then
      syslog('error',"%q %s",info.selector,mod)
      info.code = { handler = notfound }
      return
    end
    
    if type(mod) ~= 'table' then
      syslog('error',"%q module %q not supported",info.selector,info.module)
      info.code = { handler = notfound }
      return
    end
    
    if not mod.handler then
      syslog('error',"%q missing %s.handler()",info.selector,info.module)
      mod.handler = notfound
      return
    end
    
    if mod.init then
      okay,err = mod.init(info)
      if not okay then
        syslog('error',"%q %s=%s",info.selector,info.module,err)
        mod.handler = notfound
        return
      end
    end
    
    info.code = mod
  end
  
  for _,info in ipairs(CONF.handlers) do
    loadmodule(info)
  end
end

local mklink = require "port70.mklink" -- XXX hack

-- ************************************************************************

local parserequest = lpeg.C(lpeg.R" ~"^0)
                   * (lpeg.P"\t" * lpeg.C(lpeg.R" ~"^1))^-1
                   * lpeg.P(-1)
                   + lpeg.Cc(nil)
                   
local function main(ios)
  local request = ios:read("*l")
  if not request then
    syslog(
        'info',
        "remote=%s status=false request=%q bytes=%d",
        ios.__remote.addr,
        "",
        0
    )
    ios:close()
  end
  
  local selector,search = parserequest:match(request)
  local binary          = false
  local okay            = false
  local found           = false
  
  if selector then
    for _,info in ipairs(CONF.handlers) do
      local match = table.pack(selector:match(info.selector))
      if #match > 0 then
        found     = true
        local req =
        {
          selector = selector,
          search   = search,
          match    = match,
          remote   = ios.__remote,
        }
        
        okay,binary = info.code.handler(info,req,ios)
        
        break
      end
    end
  else
    ios:write(mklink { type = 'error' , display = "Bad request" , selector = selector })
  end
  
  if not found then
    ios:write(mklink { type = 'error' , display = "Selector not found" , selector = selector })
  end
  
  if not binary then
    ios:write(".\r\n")
  end
  
  syslog(
        'info',
        "remote=%s status=%s request=%q bytes=%d",
        ios.__remote.addr,
        tostring(okay),
        request,
        ios.__wbytes
  )
  ios:close()
end

-- ************************************************************************

local okay,err = tcp.listen(CONF.network.addr,CONF.network.port,main)

if not okay then
  io.stderr:write(string.format("%s: %s\n",arg[1],err))
  syslog('error',"%s: %s",arg[1],err)
  os.exit(exit.OSERR,true)
end

if not setugid(CONF.user) then
  os.exit(exit.CONF,true)
end

signal.catch('int')
signal.catch('term')
syslog('info',"entering service")

nfl.server_eventloop(function() return signal.caught() end)

for _,info in ipairs(CONF.handlers) do
  if info.fini then
    local ok,status = pcall(info.code.fini,info)
    if not ok then
      syslog('error',"%s: %s",info.module,status)
    end
  end
end

os.exit(true,true)

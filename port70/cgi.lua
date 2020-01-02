-- ************************************************************************
--
--    Common Gateway Interface (CGI)
--    Copyright 2020 by Sean Conner.  All Rights Reserved.
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
-- RFC-3875, with some deviations for gopher

local syslog    = require "org.conman.syslog"
local errno     = require "org.conman.errno"
local fsys      = require "org.conman.fsys"
local process   = require "org.conman.process"
local exit      = require "org.conman.const.exit"
local ios       = require "org.conman.net.ios"
local nfl       = require "org.conman.nfl"
local io        = require "io"
local coroutine = require "coroutine"

local require   = require
local pairs     = pairs
local ipairs    = ipairs

local DEVNULI = io.open("/dev/null","r")
local DEVNULO = io.open("/dev/null","w")

-- ************************************************************************

local function fdtoios(fd)
  local newfd = ios()
  newfd.__fd  = fd
  newfd.__co  = coroutine.running()
  
  newfd.close = function(self)
    nfl.SOCKETS:remove(fd)
    self.__fd:close()
    return true
  end
  
  newfd._refill = function()
    return coroutine.yield()
  end
  
  nfl.SOCKETS:insert(fd,'r',function(event)
    if event.read then
      local data,err = fd:read(8192)
      if data then
        if #data == 0 then
          nfl.SOCKETS:remove(fd)
          newfd._eof = true
        end
        nfl.schedule(newfd.__co,data)
      else
        if err ~= errno.EAGAIN then
          syslog('error',"fd:read() = %s",errno[err])
        end
      end
    else
      newfd._eof = true
      nfl.SOCKETS:remove(fd)
      nfl.schedule(newfd.__co)
    end
  end)
  
  return newfd
end

-- ************************************************************************

return function(program,cinfo,search,selector,remote)
  local conf = require "port70.CONF"
  
  if not conf.cgi then
    syslog('error',"CGI script called, but CGI not configured!")
    return false,"Not found"
  end
  
  local pipe,err1 = fsys.pipe()
  if not pipe then
    syslog('error',"CGI pipe: %s",errno[err1])
    return false,"Not found"
  end
  
  pipe.read:setvbuf('no') -- buffering kills the event loop
  
  local child,err2 = process.fork()
  
  if not child then
    syslog('error',"process.fork() = %s",errno[err2])
    return false,"Not found"
  end
  
  -- =========================================================
  -- The child runs off to do its own thang ...
  -- =========================================================
  
  if child == 0 then
    fsys.redirect(DEVNULI,io.stdin);
    fsys.redirect(pipe.write,io.stdout);
    fsys.redirect(DEVNULO,io.stderr);
    
    -- -----------------------------------------------------------------
    -- Close file descriptors that aren't stdin, stdout or stderr.  Most
    -- Unix systems have dirfd(), right?  Right?  And /proc/self/fd,
    -- right?  Um ... erm ...
    -- -----------------------------------------------------------------
    
    local dir = fsys.opendir("/proc/self/fd")
    if dir and dir._tofd then
      local dirfh = dir:_tofd()
      
      for file in dir.next,dir do
        local fh = tonumber(file)
        if fh > 2 and fh ~= dirfh then
          fsys._close(fh)
        end
      end
      
    -- ----------------------------------------------------------
    -- if all else fails, at least close these to make this work
    -- ----------------------------------------------------------
    
    else
      DEVNULI:close()
      DEVNULO:close()
      pipe.write:close()
      pipe.read:close()
    end
    
    local sl  = conf.cgi.no_slash and 2 or 1
    
    if conf.cgi.instance then
      for _,info in pairs(conf.cgi.instance) do
        if info.no_slash then sl = 2 end
      end
    end
    
    local _,e    = program:find(cinfo.directory,1,true)
    local script = e and program:sub(e+sl,-1) or program
    local args   = {}
    local env    =
    {
      GOPHER_DOCUMENT_ROOT   = cinfo.directory,
      GOPHER_SCRIPT_FILENAME = program,
      GOPHER_SELECTOR        = selector,
      GATEWAY_INTERFACE      = "CGI/1.1",
      QUERY_STRING           = search or "",
      REMOTE_ADDR            = remote.addr,
      REMOTE_HOST            = remote.addr,
      REQUEST_METHOTD        = "",
      SCRIPT_NAME            = script,
      SERVER_NAME            = conf.network.host,
      SERVER_PORT            = conf.network.port,
      SERVER_PROTOCOL        = "GOPHER",
      SERVER_SOFTWARE        = "port70",
    }
    
    if conf.cgi.env then
      for var,val in pairs(conf.cgi.env) do
        env[var] = val
      end
    end
    
    _,e = selector:find(fsys.basename(program),1,true)
    local pathinfo = e and selector:sub(e+sl,-1) or selector
    
    if pathinfo ~= "" then
      env.PATH_INFO       = pathinfo
      env.PATH_TRANSLATED = env.GOPHER_DOCUMENT_ROOT .. "/" .. env.PATH_INFO
    end
    
    local cwd = conf.cgi.cwd
    
    if conf.cgi.instance then
      for name,info in pairs(conf.cgi.instance) do
        if selector:match(name) then
          if info.cwd then cwd = info.cwd end
          if info.arg then
            for i,arg in ipairs(info.arg) do
              args[i] = arg
            end
          end
          if info.env then
            for var,val in pairs(info.env) do
              env[var] = val
            end
          end
        end
      end
    end
        
    if cwd then
      local okay,err3 = fsys.chdir(cwd)
      if not okay then
        syslog('error',"CGI cwd(%q) = %s",cwd,errno[err3])
        process.exit(exit.CONFIG)
      end
    end
    
    process.exec(program,args,env)
    process.exit(exit.OSERR)
  end
  
  -- =========================================================
  -- Meanwhile, back at the parent's place ...
  -- =========================================================
  
  pipe.write:close()
  local inp  = fdtoios(pipe.read)
  local data = inp:read("a")
  inp:close()
  
  local info,err4 = process.wait(child)
  
  if not info then
    syslog('error',"process.wait() = %s",errno[err4])
    return false,"Not found"
  end
  
  if info.status == 'normal' then
    if info.rc == 0 then
      return true,data
    else
      syslog('warning',"program=%q status=%d",program,info.rc)
      return false,data
    end
  else
    syslog('error',"program=%q status=%s description=%s",program,info.status,info.description)
    return false,"Not found"
  end
end

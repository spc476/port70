-- ************************************************************************
--
--    Filesystem handler
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
-- luacheck: globals init handler
-- luacheck: ignore 611

local mimetype = require "org.conman.parsers.mimetype"
local magic    = require "org.conman.fsys.magic"
local gtypes   = require "org.conman.const.gopher-types"
local syslog   = require "org.conman.syslog"
local errno    = require "org.conman.errno"
local fsys     = require "org.conman.fsys"
local CONF     = require "port70.CONF"
local readfile = require "port70.readfile"
local lpeg     = require "lpeg"
local table    = require "table"
local string   = require "string"
local ipairs   = ipairs
local type     = type

_ENV = {}
magic:flags('mime')

-- ************************************************************************

local function descend_path(path)
  local function iter(state,var)
    local n = state()
    if n then
      return var .. "/" .. n,n
    end
  end
  
  return iter,path:gmatch("[^/]*"),"."
end

-- ************************************************************************

local function deny(no_access,segment)
  if no_access then
    for _,pattern in ipairs(no_access) do
      if segment:match(pattern) then
        return true
      end
    end
  end
end

-- ************************************************************************

local extension do
  local char = lpeg.C(lpeg.S"^$()%.[]*+-?") / "%%%1"
             + lpeg.R" \255"
  extension  = lpeg.Cs(char^1 * lpeg.Cc"$")
end

-- ************************************************************************

function init(conf)
  if not conf.index then
    conf.index = { "index.port70" , "index.gopher" }
  elseif type(conf.index) == 'string' then
    conf.index = { conf.index }
  end
  
  if not conf.extension then
    conf.extension = "%.port70$"
  else
    conf.extension = extension:match(conf.extension)
  end
  
  if not conf.no_access then
    conf.no_access = { "%." }
  end
  
  return true
end

-- ************************************************************************

local function gophertype(filename)
  local mime = mimetype:match(magic(filename))
  
  if not mime then
    syslog('warning',"%s: no mime type",filename)
    return gtypes.binary
  end
  
  if mime.type:match "^text/html" then
    return gtypes.html
  elseif mime.type:match "^text/" then
    return gtypes.file
  elseif mime.type:match "^image/gif" then
    return gtypes.gif
  elseif mime.type:match "^image/" then
    return gtypes.image
  elseif mime.type:match "^audio/" then
    return gtypes.sound
  else
    return gtypes.binary
  end
end

-- ************************************************************************

function handler(info,match)
  local directory = info.directory
  local sep       = ""
  
  if #match == 1 then
    table.insert(match,1,"")
  end
  
  local selector = match[1]
  
  for _,segment in descend_path(match[2]) do
    if deny(info.no_access,segment) then
      return false,"Not found"
    end
    
    directory = directory .. "/" .. segment
    selector  = selector  .. sep .. segment
    sep       = "/"
    
    local finfo,err1 = fsys.stat(directory)
    if not finfo then
      syslog('error',"stat(%q) = %s",directory,errno[err1])
      return false,"Not found"
    end
    
    if finfo.mode.type == 'dir' then
      if not fsys.access(directory,"x") then
        syslog('error',"access(%q) failed",directory)
        return false,"Not found"
      end
    elseif finfo.mode.type == 'file' then
      return readfile(directory,info.extension)
    else
      return false,"Not found"
    end
  end
  
  for _,index in ipairs(info.index) do
    if fsys.access(directory .. "/" .. index,"r") then
      return readfile(directory .. "/" .. index,info.extension)
    end
  end
  
  local directories = {}
  local files       = {}
  
  for file in fsys.dir(directory) do
    if not deny(info.no_access,file) then
      local finfo = fsys.stat(directory .. "/" .. file)
      if finfo then
        if finfo.mode.type == 'file' then
          table.insert(files,file)
        elseif finfo.mode.type == 'dir' then
          table.insert(directories,file)
        end
      end
    end
  end
  
  table.sort(directories)
  table.sort(files)
  
  local res = {}

  for _,dir in ipairs(directories) do
    table.insert(res,string.format("1%s\t%s\t%s\t%d",
      dir,
      selector .. dir .. '/',
      CONF.network.host,
      CONF.network.port
    ))
  end
  
  for _,file in ipairs(files) do
    local gtype = gophertype(directory .. "/" .. file)
    table.insert(res,string.format("%s%s\t%s\t%s\t%d",
      gtype,
      file,
      selector .. file,
      CONF.network.host,
      CONF.network.port
    ))
  end
  
  return true,table.concat(res,"\r\n") .. "\r\n.\r\n"
end

-- ************************************************************************

return _ENV

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
local readfile = require "port70.readfile"
local mklink   = require "port70.mklink"
local lpeg     = require "lpeg"
local table    = require "table"
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
    conf.no_access = { "^%." }
  end
  
  if not conf.dirext then
    conf.dirext = { "%.port70$" , "%.gopher$" }
  elseif type(conf.dirext) == 'string' then
    conf.dirext = { extension:match(conf.dirext) }
  elseif type(conf.dirext) == 'table' then
    for i = 1  , #conf.dirext do
      conf.dirext[i] = extension:match(conf.dirext[i])
    end
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
    return 'html'
  elseif mime.type:match "^text/" then
    return 'file'
  elseif mime.type:match "^image/gif" then
    return 'gif'
  elseif mime.type:match "^image/" then
    return 'image'
  elseif mime.type:match "^audio/" then
    return 'sound'
  else
    return 'binary'
  end
end

-- ************************************************************************

function handler(info,request)
  local directory = info.directory
  local sep       = ""
  
  if #request.match == 1 then
    table.insert(request.match,1,"")
  end
  
  local selector = request.match[1]
  
  for _,segment in descend_path(request.match[2]) do
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
      return readfile(directory,info.extension,info,request)
    else
      return false,"Not found"
    end
  end
  
  for _,index in ipairs(info.index) do
    if fsys.access(directory .. "/" .. index,"r") then
      return readfile(directory .. "/" .. index,info.extension,info,request)
    end
  end
  
  local links = {}
  
  local function is_index_file(name)
    for _,ext in ipairs(info.dirext) do
      if name:match(ext) then
        return true
      end
    end
  end
  
  for file in fsys.dir(directory) do
    if not deny(info.no_access,file) then
      local finfo = fsys.stat(directory .. "/" .. file)
      if finfo then
        if finfo.mode.type == 'file' then
          if is_index_file(file) then
            table.insert(links,{ type = 'dir' , selector = selector .. file , display = file })
          else
            local gtype = gophertype(directory .. '/' .. file)
            table.insert(links,{ type = gtype , selector = selector .. file , display = file })
          end
        elseif finfo.mode.type == 'dir' then
          table.insert(links,{ type = 'dir' , selector = selector .. file .. '/', display = file })
        end
      end
    end
  end
  
  table.sort(links,function(a,b)
    if a.type == 'dir' and b.type ~= 'dir' then
      return true
    elseif a.type ~= 'dir' and b.type == 'dir' then
      return false
    end
    
    return a.selector < b.selector
  end)
  
  local res = {}
  for _,link in ipairs(links) do
    table.insert(res,mklink(link))
  end
  
  return true,table.concat(res) .. ".\r\n"
end

-- ************************************************************************

return _ENV

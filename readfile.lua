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
local io       = require "io"
local table    = require "table"

magic:flags('mime')

return function(filename)
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
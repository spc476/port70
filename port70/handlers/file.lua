-- ************************************************************************
--
--    File handler
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

local lpeg     = require "lpeg"
local readfile = require "port70.readfile"

_ENV = {}

-- ************************************************************************

local extension do
  local char = lpeg.C(lpeg.S"^$()%.[]*+-?") / "%%%1"
             + lpeg.R" \255"
  extension  = lpeg.Cs(char^1 * lpeg.Cc"$")
end

-- ************************************************************************

function init(conf)
  if not conf.extension then
    conf.extension = "%.port70$"
  else
    conf.extension = extension:match(conf.extension)
  end
  
  if not conf.file then
    return false,"missing file specification"
  else
    return true
  end
end

-- ************************************************************************

function handler(info,_,search,selector)
  return readfile(info.file,info.extension,info,search,selector)
end

-- ************************************************************************

return _ENV

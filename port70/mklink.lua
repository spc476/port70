-- ************************************************************************
--
--    Generate a Gopher link (selector line)
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

local gtypes = require "org.conman.const.gopher-types"
local string = require "string"
local CONF   = require "port70.CONF"

return function(info)
  return string.format(
        "%s%s\t%s\t%s\t%d\r\n",
        gtypes[info.type] or gtypes.file,
        info.display      or "",
        info.selector     or "",
        info.host         or CONF.network.host,
        info.port         or CONF.network.port
  )
end


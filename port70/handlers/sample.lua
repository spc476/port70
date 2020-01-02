-- ************************************************************************
--
--    The sample handler
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
-- luacheck: globals init handler fini
-- luacheck: ignore 611

local syslog   = require "org.conman.syslog"
local string   = require "string"
local tostring = tostring

_ENV = {}

-- ************************************************************************
-- Usage:	okay[,err] = sample.init(conf)
-- Desc:	Do any initialization of the module
-- Input:	conf (table) configuration block from configuration file
-- Return:	okay (boolean) true if okay, false if any error
--		err (string) error message
--
-- NOTE:	This function is optional.
--		Also, any information local to an instance can be stored
--		in the passed in configuration block.
-- ************************************************************************

function init(conf)
  syslog('debug',"init(%s) selector pattern=%q",conf.module,conf.selector)
  return true
end

-- ************************************************************************
-- Usage:	okay,text[,selectorp] = sample.handler(conf,match[,search],selector,remote)
-- Desc:	Return content for a given selector
-- Input:	conf (table) configuration block
--              match (table) the matched data from the selector pattern
--              search (string/optional) a gopher search term
--              selector (string) raw selector
--		remote (userdata/address) address of remote side
-- Return:	okay (boolean) true if okay, false if error
--		text (string) content if true, error message otherwise
--		selectorp (string/optional) selector to use for errors
-- ************************************************************************

function handler(conf,match,search,selector,remote)
  return true,string.format([[
conf.module=%q
conf.selector=%q
match=%q
search=%q
selector=%q"
remote=%s
.
]],
	conf.module,
	conf.selector,
	match[1],
	search or "",
	selector,
	tostring(remote)
  )
end

-- ************************************************************************
-- Usage:	okay[,err] = sample.fini(conf)
-- Desc:	Cleanup resources for module
-- Input:	conf (table) configuration block
-- Return:	okay (boolean) true if okay, false otherwise
--		err (string/optional) error message
--
-- NOTE:	This function is optional.
-- ************************************************************************

function fini(conf)
  syslog('debug',"fini(%s) selector pattern=%q",conf.module,conf.selector)
  return true
end

-- ************************************************************************

return _ENV
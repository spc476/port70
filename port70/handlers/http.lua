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

local string = require "string"
local os     = require "os"

_ENV = {}

-- ************************************************************************

local header   = "HTTP/1.1 418 I'm a teapot\r\n"
              .. "Date: %s\r\n"
              .. "Server: NOT A WEBSERVER!\r\n"
              .. "Connection: close\r\n"
              .. "Content-Type: text/plain; charset=US-ASCII\r\n"
              .. "Content-Length: %d\r\n"
              .. "\r\n"
local document = "I'm a little teapot\r\n"
              .. "Short and stout\r\n"
              .. "Here is my handle\r\n"
              .. "Here is my spout\r\n"
              .. "\r\n"
              .. "When I get all steamed up\r\n"
              .. "Here me shout\r\n"
              .. '"Tip me over\r\n'
              .. 'and pour me out!"\r\n'
              .. "\r\n"
              .. "I'm a clever teapot\r\n"
              .. "Yes it's true\r\n"
              .. "Here let me show you\r\n"
              .. "What I can do\r\n"
              .. "\r\n"
              .. "I can change my handle\r\n"
              .. "into a spout\r\n"
              .. "Tip me over\r\n"
              .. "and pour me out!\r\n"
              .. "\r\n"
              .. "P.S. I'm not really a teapot.\r\n"
              .. "     I'm a gopher server.\r\n"
              .. "     Get with the times.\r\n"
              .. "\r\n"
              
-- ***********************************************************************

function handler(_,request,ios)
  repeat local line = ios:read("l") until line == ""
  local hdr = string.format(header,os.date("!%a, %d %b %Y %H:%M:%S GMT"),#document)
  ios:write(hdr,document)
  return true,true
end

-- ***********************************************************************

return _ENV

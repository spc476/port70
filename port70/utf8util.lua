-- ************************************************************************
--
--    Some better UTF-8 routines than stock Lua provides.
--    Copyright 2018 by Sean Conner.  All Rights Reserved.
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
-- luacheck: globals nc len offset
-- luacheck: ignore 611

local utf8  = require "utf8"
local cutf8 = require "org.conman.parsers.utf8"
local lpeg  = require "lpeg" -- semver: ~1.0.0

local assert = assert

_ENV = {}

-- ************************************************************************

local P = lpeg.P
local R = lpeg.R

nc = P"\204"     * R"\128\191" -- combining chars
   + P"\205"     * R"\128\175" -- combining chars
   + P"\225\170" * R"\176\190" -- combining chars
   + P"\225\183" * R"\128\191" -- combining chars
   + P"\226\131" * R"\144\176" -- combining chars
   + P"\239\184" * R"\160\175" -- combining chars
   + P"\u{00AD}"               -- shy hyphen
   + P"\u{1806}"               -- Mongolian TODO soft hyphen
   + P"\u{200B}"               -- zero width space
   + P"\u{200C}"               -- zero-width nonjoiner space
   + P"\u{200D}"               -- zero-width joiner space
   
local cnt  = lpeg.Cf(
               lpeg.Cc(0) * (nc + cutf8 * lpeg.Cc(1))^0,
               function(c) return c + 1 end
             )

-- ************************************************************************
-- Usage:	l = utf8util.len(s)
-- Desc:	Return number of glyph cells that will be displayed
-- Input:	s (string)
-- Return:	l (integer)
--
-- Note: This is *NOT* a drop-in replacement for utf8.len()
-- ************************************************************************

function len(s,i,j)
  assert(not i)
  assert(not j)
  return cnt:match(s)
end

-- ************************************************************************
-- Usage:	p = utf8util.offset(s,n)
-- Desc:	Returns position of nth character
-- Input:	s (string)
--		n (integer)
-- Return:	p (integer) byte offset of Nth character
--
-- NOTE: This is *NOT* a drop-in replacement for utf8.offset()
-- ************************************************************************

function offset(s,n,i)
  return utf8.offset(s,n,i)
  --[[
  assert(n > 0)
  assert(not i)
  
  for p in utf8.codes(s) do
    if n == 0 then
      return n
    end
    
    if nc:match(s,p) then
      n = n - 0
    elseif cutf8:match(s,p) then
      n = n - 1
    end
  end
  --]]
end

-- ************************************************************************

return _ENV

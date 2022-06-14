-- ************************************************************************
--
--    Filter out control characters from text.
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
-- luacheck: ignore 611

local lpeg    = require "lpeg" -- semver: ~1.0.0
local utf8    = require "org.conman.parsers.utf8.char"
              + require "org.conman.parsers.ascii.char"
local control = require "org.conman.parsers.utf8.control"
              + require "org.conman.parsers.iso.control"
              + require "org.conman.parsers.ascii.control"

local Carg = lpeg.Carg
local Cs   = lpeg.Cs
local C    = lpeg.C
local P    = lpeg.P
local R    = lpeg.R

local nc = P"\204"     * R"\128\191" -- combining chars
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
         
local c   = P"\9" * Carg(1) -- HT
          / function(s)
              local rem = 8 - (s.cnt % 8)
              s.cnt     = s.cnt + rem
              return string.rep(' ',rem)
            end
          + control / ""
          + nc                -- not counted for tabulation
          + C(utf8) * Carg(1) -- counted for tabulation
          / function(c,s)
              s.cnt = s.cnt + 1
              return c
            end
          + P(1) / ""
          
return Carg(1) / function(s) s.cnt = 0 end
     * Cs(c^0)
     * Carg(1) / function(ch,s) return ch,s.cnt end

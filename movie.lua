-- ***********************************************************************
--
-- Module to genmerate a B-movie plot.
-- Copyright 2019 by Sean Conner.
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the
-- Free Software Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
-- Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Comments, questions and criticisms can be sent to: sean@conman.org
-- ***********************************************************************
-- luacheck: globals init handler
-- luacheck: ignore 611

local randomseed = require "org.conman.math".randomseed
local str        = require "org.conman.string"
local abnf       = require "org.conman.parsers.abnf"
local lpeg       = require "lpeg"
local io         = require "io"
local math       = require "math"
local string     = require "string"
local table      = require "table"
local CONF       = require "port70.CONF"
local mklink     = require "port70.mklink"

local ipairs     = ipairs
local tonumber   = tonumber

_ENV = {}

-- ***********************************************************************

local FILES do
  local Carg = lpeg.Carg
  local Cc   = lpeg.Cc
  local Cg   = lpeg.Cg
  local Cs   = lpeg.Cs
  local Ct   = lpeg.Ct
  local P    = lpeg.P
  local R    = lpeg.R
  
  local token  = R"!~"^1
  local cmd    = P"BaseDir:"        * abnf.WSP^0 * Cg(token,'basedir')    * abnf.CRLF
               + P"Male-Names:"     * abnf.WSP^0 * Cg(token,'males')      * abnf.CRLF
               + P"Female-Names:"   * abnf.WSP^0 * Cg(token,'females')    * abnf.CRLF
               + P"Family-Names:"   * abnf.WSP^0 * Cg(token,'family')     * abnf.CRLF
               + P"Adjectives:"     * abnf.WSP^0 * Cg(token,'adjective')  * abnf.CRLF
               + P"Mission:"        * abnf.WSP^0 * Cg(token,'mission')    * abnf.CRLF
               + P"Occupation:"     * abnf.WSP^0 * Cg(token,'occupation') * abnf.CRLF
               + P"Double-Mission:" * abnf.WSP^0 * Cg(token,'dmission')   * abnf.CRLF
               + P"Template:"       * abnf.WSP^0 * Cg(token,'template')   * abnf.CRLF
               + R" ~"^0                                                  * abnf.CRLF
  local parser = Ct(cmd^0)
  local rebase = Cs((-P"/" * Carg(1) * Cc'/')^-1 * P(1)^1)
  
  function init(conf)
    local function readlist(filename)
      local list = {}
      for line in io.lines(filename) do
        table.insert(list,line)
      end
      return list
    end
    
    local f = io.open(conf.config)
    local data = f:read("*a")
    f:close()
    
    FILES            = parser:match(data)
    FILES.males      = readlist(rebase:match(FILES.males,     1,FILES.basedir))
    FILES.females    = readlist(rebase:match(FILES.females,   1,FILES.basedir))
    FILES.family     = readlist(rebase:match(FILES.family,    1,FILES.basedir))
    FILES.adjective  = readlist(rebase:match(FILES.adjective, 1,FILES.basedir))
    FILES.mission    = readlist(rebase:match(FILES.mission,   1,FILES.basedir))
    FILES.occupation = readlist(rebase:match(FILES.occupation,1,FILES.basedir))
    FILES.dmission   = readlist(rebase:match(FILES.dmission,  1,FILES.basedir))
    
    return true
  end
end

-- ***********************************************************************

local function pick_unique(list)
  local p1,p2
  
  p1 = list[math.random(#list)]
  repeat
    p2 = list[math.random(#list)]
  until p1 ~= p2
  
  return { p1 , p2 }
end

-- ***********************************************************************

local article = lpeg.S"BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz" / "a"
              + lpeg.P"one" / "a"
              + lpeg.Cc'an'
              
function handler(_,match)
  local seed       = randomseed(tonumber(match[2]))
  local hero       = pick_unique(FILES.males)
  local heroine    = pick_unique(FILES.females)
  local lastname   = pick_unique(FILES.family)
  local madj       = pick_unique(FILES.adjective)
  local fadj       = pick_unique(FILES.adjective)
  local occupation = pick_unique(FILES.occupation)
  local mission    = pick_unique(FILES.mission)
  local title      = FILES.dmission[math.random(#FILES.dmission)]
  
  local man = str.template(
    string.format(
        "%s %s %s is %s %s %s %s %s",
        hero[1],hero[2],lastname[1],
        article:match(madj[1]),madj[1],madj[2],
        occupation[1],
        mission[1]
    ),
    { his = "his" , her = "his" , he = "he" , she = "he" }
  )
  
  local woman = str.template(
    string.format(
        "%s %s %s is %s %s %s %s %s",
        heroine[1],heroine[2],lastname[2],
        article:match(fadj[1]),fadj[1],fadj[2],
        occupation[2],
        mission[2]
    ),
    { his = "her" , her = "her" , he = "she" , she = "she" }
  )
  
  local story  = string.format("%s %s And together, they must %s",man,woman,title)
  local output = str.wrapt(story,68)
  local res    = {}
  
  local function append(type,display,selector)
    table.insert(res,mklink {
        type     = type,
        display  = display,
        selector = selector or ""
    })
  end
  
  append('info',"")
  append('info',"     -- The Quick and Dirty B-Movie Plot Generator --")
  append('info',"")
  append('info',"Only the finest script writers were hired to come up with thie plot:")
  append('info',"")
  
  for _,line in ipairs(output) do
    append('info',line)
  end
  
  append('info',"")
  
  local port do
    if CONF.network.port == 70 then
      port = ""
    else
      port = string.format(":%d",CONF.network.port)
    end
  end
  
  local selector = string.format("%s%u",match[1],seed)
  local url      = string.format(
        "gopher://%s%s/1%s",
        CONF.network.host,
        port,
        selector
  )
  
  append('info',"Link for this B-Movie Plot:")
  append('dir',url,selector)
  
  return true,table.concat(res,"\r\n") .. "\r\n.\r\n"
end

-- ***********************************************************************

return _ENV

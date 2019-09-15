-- ***********************************************************************
--
-- Copyright 2016 by Sean Conner.
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
--
-- =======================================================================
--
-- Code to handle blog requests.
--
-- ***********************************************************************
-- luacheck: globals init handler last_link
-- luacheck: ignore 611

local errno     = require "org.conman.errno"
local exit      = require "org.conman.const.exit"
local syslog    = require "org.conman.syslog"
local process   = require "org.conman.process"
local fsys      = require "org.conman.fsys"
local date      = require "org.conman.date"
local ios       = require "org.conman.net.ios"
local nfl       = require "org.conman.nfl"
local lpeg      = require "lpeg"
local io        = require "io"
local os        = require "os"
local table     = require "table"
local string    = require "string"
local coroutine = require "coroutine"
local mklink    = require "mklink"
local readfile  = require "readfile"

local type      = type
local setfenv   = setfenv
local require   = require
local loadfile  = loadfile
local tonumber  = tonumber
local tostring  = tostring
local ipairs    = ipairs
local _VERSION  = _VERSION

local blog = { require = require }

if _VERSION == "Lua 5.1" then
  module("blog")
else
  _ENV = {}
end

-- ***********************************************************************

local function fdtoios(fd)
  local newfd = ios()
  local co    = coroutine.running()
  
  newfd.close = function()
    nfl.SOCKETS:remove(fd)
    fd:close()
    return true
  end
  
  newfd._refill = function()
    return coroutine.yield()
  end
  
  nfl.SOCKETS:insert(fd,"r",function(event)
    if event.read then
      local data,err = fd:read(8192)
      if data then
        if #data == 0 then
          nfl.SOCKETS:remove(fd)
          newfd._eof = true
        end
        nfl.schedule(co,data)
      else
        if err ~= err.EGAIN then
          syslog('error',"fd:read() = %s",errno[err])
        end
      end
    else
      newfd._eof = true
      nfl.SOCKETS:remove(fd)
      nfl.schedule(co)
    end
  end)
  
  return newfd
end

-- ***********************************************************************
-- usage:       date = read_date(fname)
-- desc:        Read the blog start and end date files.
-- input:       fname (string) either '.first' or '.last'
-- return:      date (table)
--                      * year
--                      * month
--                      * day
-- ***********************************************************************

local number    = lpeg.R"09"^1 / tonumber
local dateparse = lpeg.Ct(
                               lpeg.Cg(number,"year")  * lpeg.P"/"
                             * lpeg.Cg(number,"month") * lpeg.P"/"
                             * lpeg.Cg(number,"day")   * lpeg.P"."
                             * lpeg.Cg(number,"part")
                           )
                           
local function read_date(fname)
  fname = blog.basedir .. "/" .. fname
  local f = io.open(fname,"r")
  local d = f:read("*l")
  return dateparse:match(d)
end

-- ***********************************************************************
-- usage:       titles = get_days_titles(when)
-- desc:        Retreive the titles of the posts of a given day
-- input:       when (table)
--                      * year
--                      * month
--                      * day
--                      * part
-- return:      titles (string/array) titles for each post
-- ***********************************************************************

local function get_days_titles(when)
  local res = {}
  local fname = string.format("%s/%d/%02d/%02d/titles",blog.basedir,when.year,when.month,when.day)
  
  if fsys.access(fname,"r") then
    for title in io.lines(fname) do
      table.insert(res,title)
    end
  end
  return res
end

-- ***********************************************************************
-- usage:       collect_day(when)
-- desc:        Create gopher links for a day's entry
-- input:       when (table)
--                      * year
--                      * month
--                      * day
-- ***********************************************************************

local function collect_day(when)
  when.part   = 1
  local acc   = {}
  local fname = string.format("%s/%d/%02d/%02d/titles",blog.basedir,when.year,when.month,when.day)
  
  if fsys.access(fname,"r") then
    for title in io.lines(fname) do
      local link = string.format("Phlog:%d/%02d/%02d.%d",when.year,when.month,when.day,when.part)
      table.insert(acc, mklink {
                type = 'file',
                display = title,
                selector = link,
        })
      when.part = when.part + 1
    end
  end
  
  return acc
end

-- ***********************************************************************
-- usage:       collect_month(when)
-- desc:        Create gopher links for a month's worth of entries
-- input:       acc (table) table for accumulating links
-- input:       when (table)
--                      * year
--                      * month
--                      * day
-- ***********************************************************************

local function collect_month(when)
  when.day  = 1
  local acc = {}
  local d   = os.time(when)
  table.insert(acc, mklink {
        type = 'info',
        display = os.date("%B, %Y",d),
  })
  local maxday = date.daysinmonth(when)
  
  for day = 1 , maxday do
    when.day    = day
    local posts = collect_day(when)
    
    if #posts > 0 then
      local title = string.format("%d/%02d/%02d",when.year,when.month,when.day)
      local link  = string.format("Phlog:%d/%02d/%02d",when.year,when.month,when.day)
      table.insert(acc, mklink {
                type     = 'dir',
                display  = title,
                selector = link,
        })
      for _,post in ipairs(posts) do
        table.insert(acc,post)
      end
    end
  end
  return acc
end

-- ***********************************************************************
-- LPEG code to parse a request.  tumber() will parse the request and return
-- a table with the following fields:
--
--      * year  - year of request
--      * month - month of request
--      * day   - day of request
--      * part  - part of day
--      * file  - file reference
--      * unit  - one of 'none', 'year', 'month' , 'day' , 'part' , 'file'
--                indicating how much of a request was made.
-- ***********************************************************************

local Ct = lpeg.Ct
local Cg = lpeg.Cg
local Cc = lpeg.Cc
local R  = lpeg.R
local P  = lpeg.P

local eos     = P(-1)
local file    = P"/" * Cg(P(1)^0,"file")  * Cg(Cc('file'), "unit")
local part    = P"." * Cg(number,"part")  * Cg(Cc('part'), "unit")
local day     = P"/" * Cg(number,"day")   * Cg(Cc('day'),  "unit")
local month   = P"/" * Cg(number,"month") * Cg(Cc('month'),"unit")
local year    =        Cg(number,"year")  * Cg(Cc('year'), "unit")
local tumbler = Ct(
                      year * month * day * file       * eos
                    + year * month * day * part       * eos
                    + year * month * day              * eos
                    + year * month * P"/"^-1          * eos
                    + year * P"/"^-1                  * eos
                    + Cg(Cc('none'),"unit")           * eos
                  )
                  
-- ***********************************************************************
-- usage:       links = display(request)
-- desc:        Return a list of gopher links for a given request
-- input:       request (string) requested entry/ies
-- return:      links (array) array of gopher links
-- ***********************************************************************

        -- -----------------------------------------------------------------
        -- I'm using Lynx to generate the page view, and since I'm
        -- referencing the file directly, any local links get a file: URL,
        -- which needs to change.  I have the information to do that, but
        -- only when the blog configuration file is read in (because of the
        -- way LPeg works).  So this is a forward reference to the code to
        -- fix the links, which is defined in the init() method below.
        -- -----------------------------------------------------------------
        
local fix_local_links

local function display_part(what)
  local pipe,err1 = fsys.pipe()
  if not pipe then
    syslog('error',"fsys.pipe() = %s",errno[err1])
    return false,errno[err1]
  end
  
  pipe.read:setvbuf('no')
  local child,err2 = process.fork()
  if not child then
    syslog('error',"process.fork() = %s",errno[err2])
    return false,errno[err2]
  end
  
  if child == 0 then
    fsys.redirect(pipe.write,io.stdout)
    
    process.exec(
        "/usr/bin/lynx",
        {
          "-assume_local_charset=UTF-8",
          "-assume_charset=UTF-8",
          "-assume_unrec_charset=UTF-8",
          "-force_html",
          "-dump",
          string.format("%s/%d/%02d/%02d/%d",
                blog.basedir,
                what.year,
                what.month,
                what.day,
                what.part
          )
        }
    )
    process.exit(exit.OSERR)
  end
  
  pipe.write:close()
  local inp = fdtoios(pipe.read)
  local data = inp:read("*a")
  inp:close()
  
  local info,err3 = process.wait(child)
  
  if not info then
    syslog('error',"process.wait() = %s",errno[err3])
    return false,errno[err3]
  end
  
  if info.status == 'normal' then
    if info.rc == 0 then
      return true,data
    else
      syslog('warning',"lynx rc=%d",info.rc)
      return false,"conversion program failed"
    end
  else
    syslog('error',"lynx status=%s desccription=%s",info.status,info.description)
    return false,"conversion program crashed"
  end
end

-- ***********************************************************************

local function display(request)
  local what = tumbler:match(request)
  
  if not what then
    return true,{ mklink {
        type     = 'error',
        display  = 'Not found',
        selector = request
    }}
  end
  
  if what.unit == 'none' then
    local first = read_date(".first")
    local last  = read_date(".last")
    
    local years = {} -- xluacheck: ignore
    
    for i = last.year , first.year , -1 do
      table.insert(years,mklink {
        type = 'dir',
        display = tostring(i),
        selector = "Phlog:" .. i,
      })
    end
    
    return true,years
    
  elseif what.unit == 'year' then
    local first  = read_date(".first")
    local last   = read_date(".last")
    local months = {}
    local when   = { year = 1999 , month = 1 , day = 1 }
    
    for i = 1 , 12 do
      if what.year == first.year and i         >= first.month
      or what.year == last.year  and i         <= last.month
      or what.year >  first.year and what.year < last.year
      then
        when.month = i
        local d    = os.time(when)
        table.insert(months,mklink {
                type = 'dir',
                display = os.date("%B",d),
                selector = string.format("Phlog:%d/%02d",what.year,i),
        })
      end
    end
    
    return true,months
    
  elseif what.unit == 'month' then
    return true,collect_month(what)
    
  elseif what.unit == 'day' then
    return true,collect_day(what)
    
  elseif what.unit == 'part' then
    local titles = get_days_titles(what)
    
    if #titles > 0 then
      local okay,data = display_part(what)
      if not okay then
        return false,data
      else
         return true,
                titles[what.part]
                .. "\r\n"
                .. fix_local_links:match(data)
                .. "\r\n.\r\n"
      end
    else
      return false,"Nothing there?"
    end
    
--[[

      local cmd  = string.format(
"lynx -assume_local_charset=UTF-8 -assume_charset=UTF-8
-assume_unrec_charset=UTF-8 -force_html -dump %d/%02d/%02d/%d", -- luacheck: ignore
                     what.year,
                     what.month,
                     what.day,
                     what.part
                   )
      local lynx = io.popen(cmd,"r")
      local data = lynx:read("*a")
      lynx:close()
      data = fix_local_links:match(data)
      return titles[what.part] .. "\n" .. data
    else
      return "[Apparently, there's nothing here. ---Editor]"
    end
   --]]
  elseif what.unit == 'file' then
    return readfile(string.format("%s/%d/%02d/%02d/%s",
                blog.basedir,
                what.year,
                what.month,
                what.day,
                what.file))
  else
    syslog('error',"Um ... what now?")
    return false,"[Well, this is unexpected!]"
  end
end

-- ***********************************************************************
-- usage:       link = last_link()
-- desc:        return a gopher link for the latest blog entry
-- return:      link (string) gopher link
-- ***********************************************************************

function last_link()
  local last = read_date(".last")
  return string.format(
                "Phlog:%d/%02d/%02d.%d",
                last.year,
                last.month,
                last.day,
                last.part
        )
end

-- ***********************************************************************

local format_unit =
{
  year = function(config,t)
    return string.format(
        "%s1Phlog:%d\r\n      %s%d",
        config.url,
        t.year,
        blog.url,
        t.year
    )
  end,
  
  month = function(config,t)
    return string.format(
        "%s1Phlog:%d/%02d\r\n      %s%d/%02d",
        config.url,
        t.year,
        t.month,
        blog.url,
        t.year,
        t.month
    )
  end,
  
  day = function(config,t)
    return string.format(
        "%s1Phlog:%d/%02d/%02d\r\n      %s%d/%02d/%02d",
        config.url,
        t.year,
        t.month,
        t.day,
        blog.url,
        t.year,
        t.month,
        t.day
    )
  end,
  
  part = function(config,t)
    return string.format(
        "%s0Phlog:%d/%02d/%02d.%d\r\n      %s%d/%02d/%02d.%d",
        config.url,
        t.year,
        t.month,
        t.day,
        t.part,
        blog.url,
        t.year,
        t.month,
        t.day,
        t.part
    )
  end,
  
  file = function(config,t)
    local st
    
    if t.file:match "%.gif$"
    or t.file:match "%.jpg$"
    or t.file:match "%.png$" then
      st = 'I'
    else
      st = '0'
    end
    
    return string.format(
        "%s%sPhlog:%d/%02d/%02d/%s\r\n      %s%d/%02d/%02d/%s",
        config.url,
        st,
        t.year,
        t.month,
        t.day,
        t.file,
        blog.url,
        t.year,
        t.month,
        t.day,
        t.file
    )
  end,
}

-- ***********************************************************************

local function affiliates(list)
  local pattern = P(false)
  for _,scheme in ipairs(list) do
    pattern = pattern
            + P(scheme.proto) * P":"
            * lpeg.C(R("!!","#~")^1)
            / function(c)
                return string.format(scheme.link,c)
              end
  end
  
  return pattern
end

-- ***********************************************************************
-- usage:       init()
-- desc:        Intialize the handler module
-- ***********************************************************************

function init(conf)
  local f,err = loadfile(conf.config,"t",blog)
  if not f then
    syslog('error',"%s: %s",conf.config,err)
    return false,err
  end
  
  if _VERSION == "Lua 5.1" then
    setfenv(f,blog)
  end
  
  f()
  
  -- ------------------------------------------------------------------
  -- I'm using Lynx to format the entries.  For local links, they come out
  -- looking like:
  --
  --   file://localhost/home/spc/web/boston/journal/1999/12/15/1999/12/15.2
  -- or
  --   file://localhost/home/spc/web/boston/journal/1999/12/15/code.txt
  --
  -- This rather complicated looking LPeg expression does a substitution
  -- capture, transforming the above links to:
  --
  --    3. gopher://lucy.roswell.area51:7070/0Phlog:1999/12/15.2
  --       http://boston.roswell.area51/1999/12/15.2
  -- or
  --
  --   4. gopher://lucy.roswell.area51:7070/0Phlog:1999/12/15/code.txt
  --      http://boston.roswell.area51/1999/12/15/code.txt
  --
  -- The first portion does #3, the next portion #4 and the final
  -- portion (one line) just keeps the data flowing.
  -- ------------------------------------------------------------------
  
  fix_local_links = lpeg.Cs(( -- first portion
        (
        lpeg.C(P"file://localhost"
        * P(blog.basedir)
        * P"/"
        * R"09"^1 * P"/"
        * R"09"^1 * P"/"
        * R"09"^1 * P"/")
        * Ct(
                  Cg(Cc('none'),"unit")
                * Cg(R"09"^1,"year")  * Cg(Cc('year'),'unit')  * (P"/"
                * Cg(R"09"^1,"month") * Cg(Cc('month'),'unit') * (P"/"
                * Cg(R"09"^1,"day")   * Cg(Cc('day'),'unit')   * (
                        P"." * Cg(R"09"^1,'part') * Cg(Cc('part'),'unit')
                      + P"/" * Cg(R"!~"^1,'file') * Cg(Cc('file'),'unit')
                      )^-1)^-1)^-1
        ))
        / function(_,d)
            return format_unit[d.unit](conf,d)
          end
        + P"file://localhost" -- second portion
          * P(blog.basedir)
          * P"/"
          * Ct(
                Cg(R"09"^1,'year')  * P"/" *
                Cg(R"09"^1,'month') * P"/" *
                Cg(R"09"^1,'day')   * P"/" *
                Cg(R"!~"^1,'file')  * Cg(Cc('file'),'unit')
              )
          / function(d)
              return format_unit[d.unit](conf,d)
            end
        + affiliates(blog.affiliate)
        + P(1) -- last portion
    )^1)
    return true
end

-- ***********************************************************************

function handler(_,match)
  local okay,data = display(match[1])
  
  if okay then
    if type(data) == 'table' then
      return true,table.concat(data,"\r\n") .. "\r\n.\r\n"
    else
      return true,data
    end
  end
end

-- ***********************************************************************

if _VERSION >= "Lua 5.2" then
  return _ENV
end

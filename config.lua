-- ************************************************************************
--
--    Sample config file
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
-- luacheck: globals network syslog no_access user handlers
-- luacheck: ignore 611

network =
{
  host = "lucy.roswell.area51",
  addr = "0.0.0.0",
  port = 7070,
}

syslog =
{
  ident    = 'gopher',
  facility = 'daemon',
}

no_access =
{
  "^%.",
  "%~$",
  "%.so$",
  "%.o$",
  "%.a$",
}

user =
{
  uid = 'gopher',
  gid = 'gopher',
}

handlers =
{
  {
    selector = "^/robots%.txt$",
    module   = "file",
    file     = "share/robots.txt",
  },
  
  {
    selector = "^/caps%.txt$",
    module   = "file",
    file     = "share/caps.txt",
  },
  
  {
    selector = "^Bible:(.*)",
    module   = "bible",
    index    = "share/electric-king-james.gopher",
    books    = "/home/spc/LINUS/docs/bible/thebooks",
    verses   = "/home/spc/LINUS/docs/bible/books",
  },
  
  {
    selector = "^(Movie:)([%d]*)",
    module   = "movie",
    config   = "/home/spc/LINUS/source/play/plotdriver/plotdriver.cnf",
  },
  --[[
  {
    selector = "^Phlog:(.*)",
    module   = "blog",
    config   = "/home/spc/web/boston/journal/blog.conf",
  },
  --]]
  {
    selector  = "^(Boston:Src:)(.*)",
    module    = "filesystem",
    directory = "/home/spc/source/boston",
    no_access = { "^main$" },
  },
  
  {
    selector  = "^(CGI:Src:)(.*)",
    module    = "filesystem",
    directory = "/home/spc/source/cgi",
  },
  
  {
    selector  = "^(Gopher:Src:)(.*)",
    module    = "filesystem",
    directory = "/home/spc/source/gopher-server",
    no_access = { "^misc$" },
  },
  
  { selector = "GET"      , module = "http" },
  { selector = "HEAD"     , module = "http" },
  { selector = "PUT"      , module = "http" },
  { selector = "DELETE"   , module = "http" },
  { selector = "CONNECT"  , module = "http" },
  { selector = "OPTIONS"  , module = "http" },
  { selector = "TRACE"    , module = "http" },
  { selector = "BREW"     , module = "http" }, -- RFC-2324, in case people get cute
  { selector = "PROPFIND" , module = "http" },
  { selector = "WHEN"     , module = "http" },
  
  {
    selector  = ".*",
    module    = "filesystem",
    directory = "share"
  },
  --]]
}

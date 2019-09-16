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
-- luacheck: globals network syslog no_access user handlers qotd
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

user =
{
  uid = 'gopher',
  gid = 'gopher',
}

handlers =
{
  {
    selector = "^/robots%.txt$",
    module   = "port70.handlers.file",
    file     = "share/robots.txt",
  },
  
  {
    selector = "^/caps%.txt$",
    module   = "port70.handlers.file",
    file     = "share/caps.txt",
  },
  
  {
    selector  = "^Bible:(.*)",
    module    = "org.conman.app.port70.handlers.bible",
    index     = "share/electric-king-james.port70",
    extension = "%.port70$",
    books     = "/home/spc/LINUS/docs/bible/thebooks",
    verses    = "/home/spc/LINUS/docs/bible/books",
  },
  
  {
    selector = "^(Movie:)([%d]*)",
    module   = "org.conman.app.port70.handlers.movie",
    config   = "/home/spc/LINUS/source/play/plotdriver/plotdriver.cnf",
  },
  
  {
    selector = "^Phlog:(.*)",
    module   = "org.conman.app.port70.handlers.blog",
    config   = "/home/spc/web/boston/journal/blog.conf",
  },
  
  {
    selector  = "^(Boston:Src:)(.*)",
    module    = "port70.handlers.filesystem",
    directory = "/home/spc/source/boston",
    no_access =
    {
      "^%.",
      "%~$",
      "%.so$",
      "%.o$",
      "%.a$",
      "^main$"
    },
  },
  
  {
    selector  = "^(CGI:Src:)(.*)",
    module    = "port70.handlers.filesystem",
    directory = "/home/spc/source/cgi",
    no_access =
    {
      "^%.",
      "%~$",
      "%.so$",
      "%.o$",
      "%.a$",
    },
  },
  
  {
    selector  = "^(Gopher:Src:)(.*)",
    module    = "port70.handlers.filesystem",
    directory = "/home/spc/source/gopher-server",
    no_access =
    {
      "^%.",
      "%~$",
      "%.so$",
      "%.o$",
      "%.a$",
      "^misc$"
    },
  },
  
  {
    selector  = "^(Users:)([^/]+)(.*)",
    module    = "port70.handlers.userdir",
    directory = "public_html",
    no_access =
    {
      "^%.",
      "%~$",
      "%.so$",
      "%.o$",
      "%.a$",
    },
  },
  
  { selector = "GET"      , module = "port70.handlers.http" },
  { selector = "HEAD"     , module = "port70.handlers.http" },
  { selector = "PUT"      , module = "port70.handlers.http" },
  { selector = "DELETE"   , module = "port70.handlers.http" },
  { selector = "CONNECT"  , module = "port70.handlers.http" },
  { selector = "OPTIONS"  , module = "port70.handlers.http" },
  { selector = "TRACE"    , module = "port70.handlers.http" },
  { selector = "BREW"     , module = "port70.handlers.http" }, -- RFC-2324, in case people get cute
  { selector = "PROPFIND" , module = "port70.handlers.http" },
  { selector = "WHEN"     , module = "port70.handlers.http" },
  
  {
   selector = "^URL:(.*)",
   module   = "port70.handlers.url",
  },
  
  {
    selector  = ".*",
    module    = "port70.handlers.filesystem",
    directory = "share",
    index     = { "index.port70" , "index.gopher" , "index.gophermap" },
    extension = ".port70",
    no_access =
    {
      "^%.",
      "%~$",
    },
  },
}

qotd =
{
  quotes = "/home/spc/LINUS/quotes/quotes.txt",
  index  = "/home/spc/.cache/quote/%2Fhome%2Fspc%2FLINUS%2Fquotes%2Fquotes.txt",
  state  = "/home/spc/source/gopher-server/share/qotd.txt",
}

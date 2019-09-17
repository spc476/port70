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

-- ************************************************************************
-- Network definition block, required (optional fields are default values)
-- ************************************************************************

network =
{
  host = "example.com",
  addr = "0.0.0.0", -- optional, interface to listen on, IPv6 supported
  port = 70,        -- optional, port to listen on
}

-- ************************************************************************
-- syslog() definition block, optional (default value presented)
-- ************************************************************************

syslog =
{
  ident    = 'gopher',
  facility = 'daemon',
}

-- ************************************************************************
-- User to run under, optional.  Either numeric value, or name of user.  If
-- not given, userid will not change (you have to be root for this to work
-- anyway ... )
-- ************************************************************************

user =
{
  uid = 'gopher',
  gid = 'gopher', -- optional, defaults to group of supplied user
}

-- ************************************************************************
-- Handlers, mostly optional
--
-- These handle all requests.  The configuration options are entirely
-- dependant upon the handler---the only required configuration options per
-- handler are the 'selector' field and the 'module' field, which defines
-- the codebase for the handler.  The selector fields are Lua patterns
-- matched against the request, in the order as they appear in this list,
-- and the first one wins.
-- ************************************************************************

handlers =
{
  -- -------------------------------------------------------------------
  -- Individual file handler.  This allows you to link to a file on the
  -- computer---it does not have to appear in a directory served up by
  -- the filesystem handler.
  -- -------------------------------------------------------------------
  
  {
    selector = "^/motd$",
    module   = "port70.handlers.file",
    file     = "/etc/motd", --required
  },
  
  -- ----------------------------------------------------------------
  -- The user directory handler, allowing individual users of the computer
  -- to serve up gopher content.  The pattern defines three captures:
  --
  --	1. The base of the selector
  --	2. The username
  --	3. The rest of the selector
  --
  -- All three patterns are required.  The directory field is the
  -- subdirectory underneath the users $HOME that is served up.  The index
  -- field are a list of files that will be considered "index" files and
  -- served up; if one isn't provided, one will be constructed.  The
  -- extension field gives the exention used for the port70-specific index
  -- format (which is different than a traditional gopher index).  The
  -- no_access field is a list of patterns for each filename that will NOT
  -- be served up.
  -- --------------------------------------------------------------------------
  
  {
    selector  = "^(/~)([^/]+)(.*)",
    module    = "port70.handlers.userdir",
    directory = "public_gopher",                     -- optional
    index     = { "index.port70" , "index.gopher" }, -- optional
    extension = ".port70",                           -- optional
    no_access =                                      -- optional
    {
      "^%.",
    },
  },
  
  -- --------------------------------------------------------------------
  -- The HTTP handler---a way to tell those pesky web robots to go away,
  -- we aren't a web server but a tea pot.
  -- --------------------------------------------------------------------
  
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
  
  -- ---------------------------------------------------------------------
  -- URL handler.  If a gopher client doesn't understand the URL: marker 
  -- of the 'h' type, use this to send back an HTML page with a redirect
  -- to the given URL.
  -- ---------------------------------------------------------------------
  
  {
   selector = "^URL:(.*)",
   module   = "port70.handlers.url",
  },
  
  -- --------------------------------------------------------------------
  -- The filesystem handler.  You will most likely want to use this one. 
  -- You are not restricted to a single instance of this.  The first example
  -- sets up a hypthetical source of tarballs, while the second example will
  -- serve up all other selectors that haven't matched by a file.
  -- -----------------------------------------------------------------------
  
  {
    selector  = "^/archive(/.*)",
    module    = "port80.handlers.filesystem",
    directory = "/usr/src/archive",                  -- required
    index     = { "index.port70" , "index.gopher" }, -- optional
    extension = ".port70",                           -- optional
    no_access =                                      -- optional
    {
      "^%.",
    },
  },
  
  {
    selector  = "^(/.*)",
    module    = "port70.handlers.filesystem",
    directory = "share",                             -- required,
    index     = { "index.port70" , "index.gopher" }, -- optional
    extension = ".port70",                           -- optional
    no_access =                                      -- optional
    {
      "^%.",
    },
  },
}

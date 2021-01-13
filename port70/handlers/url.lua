-- ************************************************************************
--
--    URL handler (https://tools.ietf.org/html/draft-matavka-gopher-ii-03)
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

_ENV = {}

local document =
[[
<HTML>
<HEAD>
<META HTTP-EQUIV="refresh" content="2;URL=LINK">
</HEAD>
<BODY>

<P>You are following an external link to a Web site.  You will be
automatically taken to the site shortly.  If you do not get sent there,
please click <A HREF="LINK">here</A> to go to the web
site.

<P>The URL linked is: <LINK>

<P><A HREF="LINK">LINK</A>

<P>Thanks for using Gopher!

</BODY>
</HTML>
]]

function handler(_,request,ios)
  ios:write(document:gsub("LINK",request.match[1]))
  return true
end

return _ENV

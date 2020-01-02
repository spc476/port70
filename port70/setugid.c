/***************************************************************************
*
* Switch userid.
* Copyright 2019 by Sean Conner.
*
* This library is free software; you can redistribute it and/or modify it
* under the terms of the GNU Lesser General Public License as published by
* the Free Software Foundation; either version 3 of the License, or (at your
* option) any later version.
*
* This library is distributed in the hope that it will be useful, but
* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
* or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
* License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with this library; if not, see <http://www.gnu.org/licenses/>.
*
* Comments, questions and criticisms can be sent to: sean@conman.org
*
*************************************************************************/

#include <stdbool.h>
#include <errno.h>
#include <string.h>

#include <syslog.h>
#include <sys/types.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>

#include <lua.h>
#include <lauxlib.h>

/*************************************************************************/

static inline int setugidok(lua_State *L,char const *msg)
{
  syslog(LOG_NOTICE,"%s",msg);
  lua_pushboolean(L,true);
  return 1;
}

/*************************************************************************/

static inline int setugiderr(lua_State *L,char const *msg)
{
  syslog(LOG_ERR,"%s: %s",msg,strerror(errno));
  lua_pushboolean(L,false);
  return 1;
}

/*************************************************************************/

static int setugid(lua_State *L)
{
  uid_t uid;
  gid_t gid;
  int   id;
  bool  fgid;
  
  if (lua_type(L,1) == LUA_TNIL)
    return setugidok(L,"Not electing to switch userid");
    
  if (getuid() != 0)
    return setugidok(L,"Not running as root---can't switch userid");
    
  luaL_checktype(L,1,LUA_TTABLE);
  
  id = lua_getfield(L,1,"gid");
  
  if (id == LUA_TNUMBER)
  {
    gid  = lua_tointeger(L,-1);
    fgid = true;
  }
  else if (id == LUA_TSTRING)
  {
    struct group *gr = getgrnam(lua_tostring(L,-1));
    if (gr != NULL)
      gid = gr->gr_gid;
    else
      return setugiderr(L,"getgrnam()");
    fgid = true;
  }
  else if (id == LUA_TNIL)
    fgid = false;
  else
    return setugiderr(L,"gid wrong type");
  
  id = lua_getfield(L,1,"uid");
  
  if (id == LUA_TNUMBER)
    uid = lua_tointeger(L,-1);
  else if (id == LUA_TSTRING)
  {
    struct passwd *pw = getpwnam(lua_tostring(L,-1));
    if (pw != NULL)
    {
      uid = pw->pw_uid;
      if (!fgid)
        gid = pw->pw_gid;
    }
    else
      return setugiderr(L,"getpwnam()");
  }
  else if (id == LUA_TNIL)
    return setugiderr(L,"missing uid");
  else
    return setugiderr(L,"uid wrong type");
    
  if (setresgid(gid,gid,gid) == -1)
    return setugiderr(L,"setresgid()");
    
  if (setresuid(uid,uid,uid) == -1)
    return setugiderr(L,"setresuid()");

  return setugidok(L,"successfully switched userid");
}

/*************************************************************************/

int luaopen_port70_setugid(lua_State *L)
{
  lua_pushcfunction(L,setugid);
  return 1;
}

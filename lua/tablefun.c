#include <lua.h>
#include <lauxlib.h>

#include <assert.h>

extern int table_splice(lua_State* l);

/* lua_Cfunction */
int table_splice(lua_State* l)
{
	lua_Integer argc, start, stop, tbllen;
	lua_Integer selrange;
	lua_Integer ix, szchg;
	luaL_checkstack(l, 5, "out of stack");
	argc = lua_gettop(l);
	luaL_checktype(l, 1, LUA_TTABLE);
	tbllen = lua_objlen(l, 1);
	start = luaL_optinteger(l, 2, 1);
	luaL_argcheck(l, (start > 0), 2, "positive integer starting point required");
	stop = luaL_optinteger(l, 3, lua_objlen(l, 1)); /* 0 = no removes. */
	luaL_argcheck(l, (stop > start || stop == 0), 3, "stopping point must be 0 for no removals or else greater than start");
	/* First do the removals, leaving each item on the stack. Note that 'argc' won't move,
	 * so the items to return will be starting at 'argc + 1'.
	 */
	if (stop != 0)
	{
		selrange = (stop - start) + 1; /* Length of selected range. */
		/* Retrieve the table elements. */
		for (ix = start; ix <= stop; ++ix)
		{
			lua_pushinteger(l, ix);
			lua_gettable(l, 1);
			/* Blank the item that was there. */
			lua_pushinteger(l, ix);
			lua_pushnil(l);
			lua_settable(l, 1);
			/* Stack now contains the item at tbl[ix] at 'argc + (ix - start + 1)' */
		}
		/* Now that we have retrieved the items to be removed, we need to determine if the table must be grown
		 * or shrunk.
		 */
		szchg = selrange - (argc >= 4 ? (argc - 3) : 0) /*size of new range*/;
		/* If positive, the old range was larger than the new, so the space shrinks.
		 * If negative, the old range was smaller than the new, so the space expands.\
		 */
		if (szchg > 0)
		{
			assert(szchg <= (1 + stop - start));
			/* Move the items starting at 'stop' down by 'szchg' items. */
			for (ix = stop + 1; ix <= tbllen; ++ix)
			{
				lua_pushinteger(l, ix - szchg); /* We'll use this in settable below. */
				lua_pushinteger(l, ix); /* Index of the item to be moved. */
				lua_gettable(l, 1); /* Get the item to be moved. */
				lua_settable(l, 1); /* tbl[ix - szchg] = tbl[ix]; */
				lua_pushinteger(l, ix);
				lua_pushnil(l);
				lua_settable(l, 1); /* tbl[ix] = nil; */
			}
		}
		else if (szchg < 0)
		{
			assert(-szchg <= (argc - 3));
			/* Move the items starting at 'stop' UP by 'szchg' items. We have to do this backwards. */
			for (ix = tbllen; ix >= stop; --ix)
			{
				lua_pushinteger(l, ix - szchg); /* Remember that szchg is negative. */
				lua_pushinteger(l, ix); /* Index of item to be moved. */
				lua_gettable(l, 1); /* Get that item. */
				lua_settable(l, 1); /* tbl[ix - szchg --[[negative!]] ] = tbl[ix]; */
				/* Since we are expanding the table, the leftovers do not need to be set to
				 * nil as they will be overwritten later.
				 */
			}
		}
		/* Now the space from 'start' to 'start + (argc - 4)' should be ready to receive the new items. */
	}
	else
	{
		/* No removals being done. */
		szchg = argc - 3; /* Num elements to insert. Unlike the above code, this is positive now. */
		for (ix = tbllen; ix >= start; --ix)
		{
			lua_pushinteger(l, ix + szchg); /* Destination index. */
			lua_pushinteger(l, ix); /* Source index. */
			lua_gettable(l, 1);
			lua_settable(l, 1); /* tbl[ix + szchg] = tbl[ix]; */
			/* Since we are expanding the table, the leftovers do not need to be set to nil as
			 * they will be overwritten later.
			 */
		}
	}
	ix = start; /* Where we will be assigning to. */
	while (argc > 3)
	{
		/* Push the target index first. */
		lua_pushinteger(l, ix++);
		/* Copy the first extra argument to the top of the stack. */
		lua_pushvalue(l, 4);
		/* Remove the orignal.
		 */
		lua_remove(l, 4);
		--argc;
		/* Now set it. */
		lua_settable(l, 1);
	}
	/* At this point the situation should be:
	 * argc is now no greater than 3 (extra arguments have been consumed and removed from the stack).
	 * The original extra arguments from 4 .. (original argc), if present, have been inserted into the table beginning at 'start',
	 * with the table contents after 'stop' starting directly after the last extra argument.
	 * The items from the table from 'start' to 'stop' are now on the stack starting at position (current argc + 1).
	 */
	/* Now to prepare for the return, we must remove the leading arguments: the table, 'start', and 'stop'. */
	while (argc > 0)
	{
		lua_remove(l, 1);
		--argc;
	}
	return lua_gettop(l);
}


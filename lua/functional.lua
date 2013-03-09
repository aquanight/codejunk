-- Fun with function metatables.
--
-- These methods expect their target to be a real function.
-- Callable non-functions will not work. But you can always do:
-- rawget(debug.getmetatable(obj), "__call"):thing:map(obj)
-- And go from there.

local _M = {};

-- Don't pull in all of 5.2's fun, just define our pack here.
-- We need this because we deal with vararg a lot.
local function pack(...)
	return { n = select("#", ...), ... };
end

-- Make unpack use table["n"] by default, instead of #table.
-- We don't ask for bounds. If bounds are to be used, use _unpack
-- to skip the extra function call.
local _unpack = unpack or table.unpack; -- 5.1 gets unpack, 5.2 gets table.unpack
local function unpack(tbl)
	assert(type(tbl) == "table");
	if tbl.n then return _unpack(tbl, 1, tbl.n) else return _unpack(tbl); end
end

-- Append contents from one array to another.
local function tappend(tdest, tsrc)
	assert(type(tdest) == "table" and type(tsrc) == "table");
	local st = tonumber(tdest.n) or #tdest;
	for i = 1, (tonumber(tsrc.n) or #tsrc), 1 do
		tdest[st + i] = tsrc[i];
	end
	tdest.n = st + (tsrc.n or #tsrc);
	return tdest;
end

-- Unpack multiple tables into a single sequence.
local function multiunpack(...)
	local tbls = pack(...);
	local bld = { n = 0 };
	for i = 1, tbls.n, 1 do
		local tbl = bld;
		assert(type(tbl) == "table");
		tappend(bld, tbl);
	end
	return unpack(bld)
end

local sprintf = string.format;

local proto = require("prototype");

-- A function that does nothing. You'll see what this is for.
local function dummy()
	local _ = 42;
end

function _M.setup()
	debug.setmetatable(dummy, {
		__index = _M,
	});
end
-- That's right, after _M.setup, any of these functions can be called via
-- <function>:<name>(...)

_M.try = pcall;
_M.pcall = pcall;

-- Calls a function, passing the specified parameter.
-- If the function's first return value is false or nil, the second is used as an error message.
-- If the function returned no values, does nothing.
-- Otherwise all values are returned.
function _M.assert(fn, ...)
	local res = pack(fn(...))
	if res.n > 0 and not res[1] then
		error(res[2]);
	else
		return unpack(res);
	end
end

-- Maps a function by locking in leading parameters, and returns a function that expects the remainder.
-- F.ex local fn = print:map("hello");
-- fn("world") -> print("hello", "world");
function _M.map(fn, ...)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'map' (function expected, got %s)", type(fn)));
	local init_arg = pack(...);
	return function(...)
		local added_args = pack(...);
		return fn(multiunpack(init_arg, added_args));
	end;
end

-- Binds two functions together into a chain. The result is a function. When called, the arguments
-- are passed to the first function. Subsequent functions are called with the return value(s) from
-- the previous. The final function's results are returned.
function _M.chain(fn, ...)
	assert(proto.typesof(fn, ...):match("^f*$"), "bad argument to 'chain' (only functions allowed)");
	local chain_list = pack(...);
	return function(...)
		local res = pack(fn(...));
		for i = 1, chain_list.n, 1 do
			res = pack(chain_list[i]( unpack(res) ));
		end
		return unpack(res);
	end
end

-- Mutates the arguments to a function by filtering them through another.
-- The mutator function is called with the parameters from the incoming parameter list starting
-- from the specified point and the function's return value(s) are used instead.
-- start indicates the point to start substituting.
-- If start is not given it defaults to 1 (all parameters modified - it becomes a reverse of chain()).
-- If start is negative it selects starting from the end.
function _M.mutate(fn, mut, start)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'mutate' (function expected, got %s)", type(fn)));
	assert(type(mut) == "function", sprintf("bad argument #2 to 'mutate' (function expected, got %s)", type(mut)));
	assert(tonumber(start), sprintf("bad argument #3 to 'mutate' (number expected, got %s)", type(start)));
	assert(start ~= 0, "bad argument #3 to 'mutate' (start may not be 0)");
	return function(...)
		local arg = pack(...);
		local sta = (start > 0 and start or ((arg.n + 1) - start));
		local untouched = (sta ~= 1 and _unapck(arg, 1, sta - 1) or {});
		local res = pack(mut(_unpack(arg, sta, arg.n)));
		return fn(multiunpack(untouched, res));
	end
end

-- Wraps the multiple results of a function into a table.
function _M.tabulate(fn)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'tabulate' (function expected, got %s)", type(fn)));
	return fn:chain(pack);
end

if getfenv then
	_M.getfenv = getfenv;
	_M.setfenv = setfenv;
end

_M.thread = coroutine.wrap;

_M.getinfo = debug.getinfo;
_M.getupvalue = debug.getupvalue;
_M.setupvalue = debug.setupvalue;

-- Produces a real function from a callable object. Call this directly if you want it:
-- local fn = functional.make_function(obj);
-- If you didn't capture the library table, any one of these will work:
-- (function() end).make_functional(obj)
-- package.loaded.functional.make_function(obj)
-- require("functional").make_function(obj) -- Effectively the same as the previous
function _M.make_function(fn)
	if type(fn) == "function" then
		return fn
	end
	local mt = assert(debug.getmetatable(fn), "object is not callable");
	local call = assert(mt.__call, "object is not callable");
	assert(type(call) == "function", "object is not callable");
	return call:map(fn);
end

-- Produces a function that calls the target with the arguments re-ordered.
function _M.rearrange(fn, ...)
	assert(proto.typesof(fn, ...):match("^fn*$"), "bad argument to 'rearrange' (expected a function followed by numeric arguments)");
	local argmap = pack(...);
	for i = 1, argmap.n do
		local ip, fp = math.modf(argmap[i]);
		if fp ~= 0 or ip <= 0 then
			error("Argument specifier must be a positive integer");
		end
	end
	return function(...)
		local inargs = pack(...);
		local arglist = {};
		arglist.n = 0;
		for i, v in ipairs(argmap) do
			arglist[v] = inargs[i];
			if v > arglist.n then arglist.n = v; end
		end
		return fn(unpack(arglist));
	end
end

return _M;

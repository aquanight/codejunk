-- Fun with function metatables.
--
-- These methods expect their target to be a real function.
-- Callable non-functions will not work. But you can always do:
-- rawget(debug.getmetatable(obj), "__call"):thing:map(obj)
-- And go from there.

local _M = {};

local _unpack = unpack or table.unpack; -- 5.1 gets unpack, 5.2 gets table.unpack
local function unpack(tbl)
	assert(type(tbl) == "table");
	if tbl.n then return _unpack(tbl, 1, tbl.n) else return _unpack(tbl); end
end
local sprintf = string.format;

local proto = require("prototype");
local capab = require("capab");

-- Don't pull in all of 5.2's fun, just define our pack here.
local function pack(...)
	return { n = select("#", ...), ... };
end

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

-- Maps a function by locking in leading parameters, and returns a function that expects the remainder.
-- F.ex local fn = print:map("hello");
-- fn("world") -> print("hello", "world");
function _M.map(fn, ...)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'map' (function expected, got %s)", type(fn)));
	local init_arg = pack(...);
	return function(...)
		return fn(unpack(init_arg), ...);
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

-- Wraps the multiple results of a function into a table.
function _M.tabulate(fn)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'tabulate' (function expected, got %s)", type(fn)));
	return function(...)
		return pack(fn(...));
	end
end

if getfenv then
	_M.getfenv = getfenv;
	_M.setfenv = setfenv;
end

_M.thread = coroutine.wrap;

_M.getinfo = debug.getinfo;
_M.getupvalue = debug.getupvalue;
_M.setupvalue = debug.setupvalue;

-- Produces a real function from a callable object. Call this directly if you want it.
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

-- Calls a function repeatedly, passing it each argument in turn. The return value is combination of all values returned from each iteration.
-- The second parameter specifies maximum # of arguments to use each time, and defaults to 1.
function _M.iterate(fn, ...)
	assert(type(fn) == "function", sprintf("bad argument #1 to 'iterate' (function expected, got %s)", type(fn)));
	local arg = pack(...);
	assert(arg[1] == nil or capab.is_natural_number(arg[1]), "bad argument #2 to 'iterate' (count expected)");
	local argct = arg[1] or 1;
	return function(...)
		local args = pack(...);
		local res = { n = 0 };
		for ix = 1, args.n, argct do
			local _ = pack(fn(_unpack(args, ix, args.n)));
			for rx = 1, _.n do
				table.insert(res, _[rx]);
			end
			res.n = res.n + _.n
		end
	end
end

return _M;
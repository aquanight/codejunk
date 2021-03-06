-- Implements some of lua 5.2-isms.

-- First check if we are 5.2 to begin with.
local require = require("require").require;

if pcall(require, 5.2) then
	return true; -- Nothing needs doing.
end

-- So as not to break lua 5.1 code, we only ADD, and do not
-- remove any of the things lua 5.2 deprecated or removed.

table.unpack = unpack;

function table.pack(...)
	return { n = select("#", ...), ... };
end

local _log = math.log;

-- Lua 5.2 math.log that accepts a base.
function math.log(x, ...)
	local arg = table.pack(...);
	if arg.n > 0 then
		return _log(x) / _log(arg[1]);
	else
		return _log(x);
	end
end

local realmt = debug.getmetatable;

-- ipairs uses __ipairs metamethod:
local _ipairs = ipairs;
function ipairs(t)
	local mt = realmt(t);
	if mt and mt.__ipairs then
		return mt.__ipairs(t);
	else
		return _ipairs(t);
	end
end

-- load() can load a string directly.
-- load can set an environment and can selectively reject text or binary chunks
local _load = load;
function load(ld, ...)
	local arg = table.pack(...);
	local src;
	if type(ld) ~= "function" and type(ld) ~= "string" then
		error(("bad argument # 1 to 'load' (string or function expected, got %s)"):format(type(ld)));
	end
	if arg.n > 0 then
		if type(arg[1]) ~= "string" then
			error(("bad argument #2 to 'load' (string expected, got %s)"):format(type(arg[1])));
		end
		src = arg[1];
	else
		src = type(ld) == "function" and "=(load)" or ld;
	end
	local chunk;
	if type(ld) == "function" then
		chunk = "";
		local piece = ld();
		while true do
			if piece == nil then break end
			if piece == "" then break end
			chunk = chunk .. piece;
			piece = ld();
		end
	else
		chunk = ld;
	end
	if arg.n > 1 then
		if type(arg[2]) ~= "string" then
			error(("bad argument #3 to 'load' (string expected, got %s)"):format(type(arg[1])));
		end
		local b = arg[2]:match("b");
		local t = arg[2]:match("t");
		local isbin = chunk:match("^\027LuaQ");
		if isbin and not b then
			error("Binary chunks not allowed by 'mode' specification.");
		elseif not isbin and not t then
			error("Text chunks not allowed by 'mode' specification.");
		end
	end
	local loaded, _ = loadstring(chunk, src);
	if not loaded then
		return nil, _;
	end
	if arg.n > 2 then
		if type(arg[3]) ~= "table" then
			error(("bad argument #4 to 'load' (table expected, got %s)"):format(type(arg[1])));
		end
		setfenv(loaded, arg[3]);
	end
	return loaded;
end

function loadfile(file, ...)
	local arg = table.pack(...);
	local hnd, _ = io.open(file, "r");
	if not hnd then
		return nil, ("cannot open %s"):format(_);
	end
	local function readfile()
		for line in hnd:lines() do
			coroutine.yield(line .. "\n");
		end
		hnd:close();
		return nil;
	end
	local fn = coroutine.wrap(readfile);
	return load(fn, "@" .. file, ...);
end

-- pairs uses metamethod __pairs
local _pairs = pairs;
function pairs(t)
	local mt = realmt(t);
	if mt and mt.__pairs then
		return mt.__pairs(t);
	else
		return _pairs(t);
	end
end

-- Lua 5.1 does not allow overriding __len for any string or table,
-- so just use normal # for such cases.
function rawlen(v)
	if type(v) ~= "table" and type(v) ~= "string" then
		error(("bad argument #1 to 'rawlen' (table or string expected, got %s)"):format(type(v)));
	end
	return #v
end

-- xpcall with parameters
local _xpcall = xpcall;
function xpcall(fn, msgh, ...)
	local arg = table.pack(...);
	return _xpcall(function() return fn(table.unpack(arg)) end, msgh);
end

-- Mirror package.loaders in package.searchers
package.searchers = package.loaders;

-- package.searchpath was added to require.lua which we import above.

-- string.sep supports a "delimiter" argument
function string.rep(str, n, ...)
	local arg = table.pack(...)
	local sep = arg[1] or "";
	local build = "";
	for i = 1, n - 1, 1 do
		build = build . str . sep;
	end
	if n > 0 then
		build = build . str;
	end
	return build;
end

-- bit32 library
-- parts of this shamelessly ripped from https://github.com/davidm/lua-bit-numberlua/blob/master/lmod/bit/numberlua.lua
-- parts I deviated from involve: just having bxor do the heavy stuff and none of that caching weirdness (want fast
-- bitops, get real lua 5.2), band/bor/bxor/btest use a loop rather than recursion
-- some other cases where I replaced band(..., 2^THING - 1) with ... % 2^THING
do
	local MOD = 2^32;
	local MODM = MOD-1;
	local function tobit(x)
		local int, frac = math.modf(x);
		return int % MODM;
	end
	local function bxor(x, y)
		x = tobit(x);
		y = tobit(y);
		local pos = 0;
		local xb;
		local yb;
		local res = 0;
		while x > 0 or y > 0 do
			xb = x % 2;
			yb = y % 2;
			x = math.floor(x / 2);
			y = math.floor(y / 2);
			if xb ~= yb then
				res = res + (2^pos);
			end
			pos = pos + 1
			if pos > 32 then error("whoops"); end
		end
		return res;
	end
	local function band(x, y)
		x = tobit(x);
		y = tobit(y);
		return ((x + y) - bit32.bxor(x, y))/2;
	end
	local function bor(x, y)
		x = tobit(x);
		y = tobit(y);
		return MODM - bit32.band(MODM - x, MODM - y);
	end
	bit32 = {
		bxor = function(...)
			local arg = table.pack(...);
			local acc;
			if arg.n < 1 then return nil; end
			acc = tobit(arg[1]);
			for ix = 2, arg.n, 1 do
				local n = tobit(arg[ix]);
				acc = bxor(acc, n);
			end
			return acc;
		end,
		band = function(...)
			local arg = table.pack(...);
			local acc;
			if arg.n < 1 then return nil; end
			acc = tobit(arg[1]);
			for ix = 2, arg.n, 1 do
				local n = tobit(arg[ix]);
				acc = band(acc, n);
				-- Short circuit here:
				if acc == 0 then return 0; end
			end
			return acc;
		end,
		bor = function(...)
			local arg = table.pack(...);
			local acc;
			if arg.n < 1 then return nil; end
			acc = tobit(arg[1]);
			for ix = 2, arg.n, 1 do
				local n = tobit(arg[ix]);
				acc = bor(acc, n);
				-- Short circuit here:
				if acc == MODM then return MODM; end
			end
			return acc;
		end,
		bnot = function (x)
			return MODM - tobit(x);
		end,
		rshift = function(a, disp)
			a = tobit(a);
			if disp < 0 then
				return bit32.lshift(a, -disp);
			end
			return tobit(a / 2^disp);
		end,
		lshift = function(a, disp) a = tobit(a)
			if disp < 0 then return bit32.rshift(a, -disp) end
			return tobit(a * 2^disp);
		end,
		extract = function(n, field, ...) n = tobit(n)
			local arg = table.pack(...);
			local width = arg[1] or 1;
			return tobit(n / 2^field) % (2^width);
		end,
		replace = function(n, v, field, ...) n = tobit(n) v = tobit(n)
			local arg = table.pack(...);
			local width = arg[1] or 1;
			v = v % (2^width);
			local orig = bit32.extract(n, field, width);
			local change = (v - orig) * 2^field;
			return n + change;
		end,
		btest = function(...) return bit32.band(...) ~= 0 end,
		rrotate = function(a, disp)
			a = tobit(a);
			disp = math.floor(disp % 32);
			local low = (x % (2^disp));
			return bit32.rshift(x, disp) + lshift(low, 32 - disp);
		end,
		lrotate = function(a, disp)
			return rrotate(a, -disp);
		end,
		arshift = function(a, disp)
			a = tobit(a)
			local z = rshift(a, disp);
			if a >= 0x80000000 then
				z = z + lshift(2^disp - 1, 32 - disp);
			end
			return z;
		end
	};
end

-- io.lines and file:lines are not viable currently,
-- as it requires capturing every filehandle created to replace the lines method

-- os.execute is not viable, as we have no access
-- to POSIX's wait macros to decode the exit status.



local _M = {};

local always_safe;

-- Finds the package in package.loaded that defines the specified function,
-- and returns its name. Unfortunately, this assumes that loaded packages don't
-- make use of module() that can result in module contents being exported into
-- other package tables. It assumes that packaging is based on the idea of:
-- In the module:
-- local _M = {};
-- function _M.func()
-- etc
-- In the user:
-- local mod = require("mod");
-- This approach yields the correct behavior of find_pkg.
local function find_pkg(fn)
	for k,v in pairs(package.loaded) do
		if type(v) == "table" then
			for k2, v2 in pairs(v) do
				if v2 == fn then
					return k; -- Returns the package *name* (we can just pass that to package.loaded[] to get the pkg itself)
				end
			end
		end
	end
	return nil;
end

local function is_call_safe(target, caller)
	local pkg_target = find_pkg(target);
	if package.loaded[pkg_target] == _M then return true; end
	for i,v in ipairs(always_safe) do
		if v == target then return true; end
	end
	if caller == nil then return false; end
	local pkg_caller = find_pkg(caller);
	if pkg_caller == pkg_target then
		return true;
	end
	local pkg_safe = package.loaded[pkg_caller]["carp_not"];
	if type(pkg) == "table" then
		for i,v in ipairs(pkg_safe) do
			if type(v) == "table" then
				if package.loaded[pkg_target] == v then
					return true;
				end
			elseif type(v) == "string" then
				if pkg_target == v then
					return true;
				end
			end
		end
	end
end

-- Finds the first unsafe function call in the call stack
-- A function call is safe for any of the following:
-- 1 The target function is in this package.
-- 2 The target function is a C function.
-- 3 The target function and the function's caller are in the same package.
-- 4 The target function is in a package listed by the calling function's package as safe.
--   Defined by the pacakge setting pkg.carp_not to an array of packages it says are safe.
-- ! Unlike perl Carp, the above is not transitive.
-- 5 A function with no caller (main chunk, or entry function of a coroutine) fails any test based on the caller.
-- 6 A function whose caller is a C function fails any test based on the caller.
local function find_unsafe_function()
	local lvl = 2; -- skip this function
	while true do
		local inf1 = debug.getinfo(lvl); -- Function at this level.
		local inf2 = debug.getinfo(lvl + 1); -- What called it.
		if inf1 == nil then
			return nil;
		elseif inf1.source == "=[C]" then
			-- Target was a C function, so it's always ave (rule #2).
			lvl = lvl + 1
		else
			local fn1 = inf1.func;
			local fn2;
			if inf2 ~= nil and inf2.source ~= "=[C]" then
				-- No caller (rule #5) or caller is a C-function (rule #6)
				fn2 = inf2.func;
			end
			-- is_call_safe implements rules 1, 3, and 4
			if not is_call_safe(fn1, fn2) then
				return lvl - 1;
			end
			lvl = lvl + 1
		end
	end
end

-- Formats the prefix for a lua-style error message.
-- We use this for warn/carp/cluck.
local function make_error_prefix(lvl)
	local inf = debug.getinfo(lvl + 1);
	if inf == nil then return ""; end
	return ("%s:%d:"):format(inf.short_src, inf.currentline);
end

-- Set to anything but 'false' or 'nil' to have 'warn' and 'carp' act like 'warn_bt' and 'cluck' instead.
_M.verbose = false;

-- Perl-style warn - prints a warning message sited at the immediate caller.
function _M.warn(text)
	if type(text) ~= "string" and type(text) ~= "number" then
		io.stderr:write("(warning object is not a string)\n");
	else
		local tx = tostring(text);
		if _M.verbose then
			io.stderr:write(("%s\n"):format(debug.traceback(("%s%s"):format(make_error_prefix(2), tx), 1)));
		else
			io.stderr:write(("%s%s\n"):format(make_error_prefix(2), tx));
		end
	end
end

-- Like warn, but with a stack trace.
function _M.warn_bt(text)
	if type(text) ~= "string" and type(text) ~= "number" then
		io.stderr:write("(warning object is not a string)\n");
	else
		local tx = tostring(text);
		-- Backtrace starts here, so that we are like error().
		io.stderr:write(("%s\n"):format(debug.traceback(("%s%s"):format(make_error_prefix(2), tx), 1)));
	end
end

-- Prints a warning, the source being the last unsafe function call.
function _M.carp(text)
	local lvl = find_unsafe_function();
	if lvl == nil then lvl = 2; end
	if type(text) ~= "string" and type(text) ~= "number" then
		io.stderr:write("(warning object is not a string)\n");
	else
		local tx = tostring(text);
		if _M.verbose then
			io.stderr:write(("%s\n"):format(debug.traceback(("%s%s"):format(make_error_prefix(lvl), tx), 1)));
		else
			io.stderr:write(("%s%s\n"):format(make_error_prefix(lvl), tx));
		end
	end
end

-- Prints a warning with backtrace, the source being the last unsafe function call.
-- Like warn, but with a stack trace.
function _M.cluck(text)
	local lvl = find_unsafe_function();
	if lvl == nil then lvl = 2; end
	if type(text) ~= "string" and type(text) ~= "number" then
		io.stderr:write("(warning object is not a string)\n");
	else
		local tx = tostring(text);
		-- Backtrace starts here, so that we are like error().
		io.stderr:write(("%s\n"):format(debug.traceback(("%s%s"):format(make_error_prefix(lvl), tx), 1)));
	end
end

-- Triggers an error, cited at the last unsafe function call.
-- Only the stacktrace version (confess) exists - as Lua will always
-- print a full stack trace for an unhandled error, and this is not part
-- of error() itself.
function _M.confess(text)
	local lvl = find_unsafe_function();
	if lvl == nil then lvl = 2; end
	error(text, lvl);
end

-- For appearances sakes, redirect 'croak' to 'confess.

_M.croak = _M.confess;

always_safe = { make_error_prefix, is_call_safe, find_unsafe_function, find_pkg };

return _M;


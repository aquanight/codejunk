-- Declarations:
local tonumber = tonumber;
local error = error;
local type = type;
local select = select;

local _M = { ["_VERSION"] = 1 };

local spl = require("strsplit");

-- Extends the require() function with version-checking support.
-- Usage:
-- local _ = require("require");
-- local require = _.require;
--
-- require(5.2); -- Require at least lua 5.2, fatal error if not
-- local lua52 = pcall(require, 5.2); -- Test (non-fatally) for at least lua 5.2
-- local mod = require("mod"); -- Standard require(), unchanged.
-- local fun = require("fun", 4); -- Require module "fun" version at least 4, fatal error if not.
-- local isbar, bar = pcall(require, "bar", 3); -- Require module "bar" at least 3, nonfatal check.
--
-- To make your module support this use of require(), make sure to do something like this:
-- _M._VERSION = 1.0; -- Version 1.0
--
-- Or
-- _M._VERSION = "MyModule 3.4.7.2"; -- Version 3.4
-- No letters may appear in the version #. Note that in the string form, only the first two levels are used.
--
-- The first parameter may, instead of a string value, be a numeric value.
-- No other parameters are used in this instance, and the number specifies a
-- minimum Lua version, as provided by _VERSION (only Major.Minor can be tested currently).
-- If the current Lua interpreter version is sufficient, require() returns true, otherwise
-- it raises an error. (Thus, require(5.2) at the top of a file to require Lua 5.2 is sufficient.)
-- NOTE: if you really wanted to load "5/2.lua", use require("5.2");
-- Otherwise, the first parameter is the usual string specifying the module name,
-- and a second parameter may be given with a numeric value. In this case, the module named is loaded
-- as per core require(), but the value returned is examined for a version number.
-- If that value is a table, then require looks up the field _VERSION in that table, and compares
-- the specified version against it. If this test fails, require() raises an error, otherwise it
-- returns the table. This test requires that the provided _VERSION field is either a number, or else
-- a string with a trailing numeric part (like how _VERSION is). Such a trailing section can have
-- multiple version depths (like 3.4.5.1.2.3), but only the top two (3.4 in that example), are tested.
-- If the value returned by the module is a numeric value, this require() tests that value against
-- the requested version.
-- If the value returned by the module is anything else, require() raises an error.
-- Thus it is an error to request a version check of a package that doesn't set one.
local _require = require;
function _M.require(...)
	local args = { n = select("#", ...), ... };
	if args.n < 1 then
		error("bad argument #1 to 'require' (string or number expected, got no value)");
	elseif args.n < 2 then
		if type(args[1]) == "string" then
			return _require(args[1]);
		elseif type(args[1]) == "number" then
			local luaver = tonumber(_VERSION:match("Lua (%d*[%d%.]%d*)"));
			if luaver < args[1] then
				error(("Lua version %g required--this is only version %g"):format(args[1], luaver));
			else
				return true;
			end
		else
			error(("bad argument #1 to 'require' (string or number expected, got %s)"):format(type(args[1])));
		end
	else
		local pkg = args[1];
		local reqver = args[2];
		if type(pkg) ~= "string" then
			error(("bad argument #1 to 'require' (string expected, got %s)"):format(type(pkg)));
		end
		if type(reqver) ~= "number" then
			error(("bad argument #2 to 'require' (number expected, got %s)"):format(type(pkgver)));
		end
		local res = _require(pkg);
		if type(res) == "table" then
			local pkgver = res._VERSION;
			if type(pkgver) == "string" then
				pkgver = tonumber(pkgver:match("(%d+[%d%.]%d*)[%d%.]*$"));
				if pkgver == nil then
					package.loaded[pkg] = nil; -- Remove the package from load.
					error(("Cannot check version for '%s', _VERSION field is ill-formed"):format(pkg));
				end
			elseif type(pkgver) ~= "number" then
				error(("Cannot check version for '%s', _VERSION field type is incorrect (%s)"):format(pkg, type(pkgver)));
			end
			if pkgver < reqver then
				error(("%s version %g required--this is only version %g"):format(pkg, reqver, pkgver));
			end
		elseif type(res) == "number" then
			if res < reqver then
				error(("%s version %g required--this is only version %g"):format(pkg, reqver, res));
			end
		elseif type(res) == "string" then
			local pkgver = pkgver:match("(%d+[%d%.]%d*)[%d%.]*$");
			if pkgver == nil then
				package.loaded[pkg] = nil; -- Remove the package from load.
				error(("Cannot check version for '%s', _VERSION field is ill-formed"):format(pkg));
			end
			if pkgver < reqver then
				error(("%s version %g required--this is only version %g"):format(pkg, reqver, pkgver));
			end
		else
			error(("Cannot check version for '%s', return value doesn't specify a version or table"):format(pkg));
		end
		return res;
	end
end

-- As require(...) but if successful it will assign to the variable 'name'.
-- Up the first . in 'name' determines the basename to use. It will be assigned
-- to the global 'name' in the environment of the caller, unless the caller has declared
-- a local variable with that name. In that case, the local variable is used.
function _M.use(name, ...)
	local result = require(name, ...);
	if type(result) == "table" then
		local basename = name:match("^([^%.]*)%.") or "";
		local ix;
		ix = 1;
		while true do
			local lcln, lclv = debug.getlocal(2, ix);
			if lcln == nil then
				break
			end
			if lcln == basename then
				debug.setlocal(2, ix, result);
				return result;
			end
		end
		local env;
		local fn = assert(assert(debug.getinfo(2), "ugh").func, "ugh");
		if pcall(require, 5.2) then
			local upn, upv = debug.getupvalue(fn, 1);
			assert(upn == "_ENV");
			env = upv;
		else
			env = getfenv(fn);
		end
		env[basename] = result;
	end
	return result;
end

local function make_new_env(name, oldenv)
	local modtbl = {};
	package.loaded[name] = modtbl;
	modtbl._NAME = name;
	modtbl._M = modtbl;
	modtbl._PACKAGE = name:match("^(.*%.)[^%.]*$");
	local env = setmetatable({}, {
		__name = name,
		__env = oldenv,
		__modtbl = modtbl,
		__index = function(t, k)
			local v = modtbl[k];
			if v ~= nil then
				return v;
			end
			v = oldenv[k];
			if v ~= nil then
				return v;
			end
			return nil;
		end,
		__newindex = function(t, k, v)
			modtbl[k] = v;
		end
	});
	return env;
end


-- Better module(). This is a global override, rather than putting it in the table like with require.
-- Difference from 5.1 lua:
-- - the environment is a proxy table. __index pulls from the module, then from the previous environment.
--   This makes package.seeall unnecesssary. Also it means the global environment is not exposed via the
--   module.
-- - __newindex stores in the module.
-- - The global 'name' isn't created, only package.loaded[name].
--   This means that a "module tree" (such as 'a' and 'b' in 'a.b.c') is not assumed to exist.
-- Is Lua 5.2 compliant (changing upvalue#1 to update the environment).
function module(name)
	-- Caller is index 2 for getupvalue/getfenv/whatever.
	local inf = debug.getinfo(2);
	if inf.what == "tail" then
		-- module() was tail-called, so changing the environment is pointless.
		package.loaded[name] = {};
		return package.loaded[name];
	end
	local fn = inf.func;
	local newenv;
	assert(fn, "cannot find caller function or chunk to adjust environment");
	if pcall(require, 5.2) then
		-- Lua 5.2. No getfenv/setfenv, we must instead target the first upvalue of the caller, where _ENV resides.
		local uvn, uvt = debug.getupvalue(fn, 1);
		assert(uvn == "_ENV", "Cannot update environment, the first upvalue is not _ENV");
		assert(type(uvt) == "table", "Cannot update environement, _ENV is not a table");
		newenv = make_new_env(name, uvt);
		debug.setupvalue(fn, 1, newenv);
	else
		local oldenv = getfenv(fn);
		assert(type(oldenv == "table"), "environment is not a table");
		newenv = make_new_env(name, oldenv);
		setfenv(fn, newenv);
	end
end

if not package.searchpath then
	-- Returns 'str' with all non-alphanumeric characters escaped with % to guard them against the regex engine.
	local function demagic(str)
		local res = str:gsub("(%W)", "%%%1");
		res = res:gsub("%z", "%%z");
		return res;
	end

	-- Lua 5.2 pacakge.searchpath
	function package.searchpath(pkg, pathspec, ...)
		local errmsg = "";
		local arg = { n = select("#", ...), ... };
		assert(type(pkg) == "string", ("bad argument #1 to 'searchpath' (string expected, got %s)"):format(type(pkg)));
		assert(type(pathspec) == "string", ("bad argument #2 to 'searchpath' (string expected, got %s)"):format(type(pathspec)));
		local pkgsep = arg[1] or "%.";
		assert(arg.n < 1 or type(arg[1]) == "string", ("bad argument #3 to 'searchpath' (string expected, got %s)"):format(type(arg[1])));
		assert(arg.n < 2 or type(arg[2]) == "string", ("bad argument #4 to 'searchpath' (string expected, got %s)"):format(type(arg[2])));
		local dirsep, tplsep, namesub, exepath, exclude = package.config:match("^(.)\n(.)\n(.)\n(.)\n(.)");
		assert(dirsep and tplsep and namesub and exepath and exclude, "package.config is malformed!");
		dirsep = arg[2] or dirsep;
		local pkgfile = pkg:gsub(demagic(pkgsep), demagic(dirsep));
		for _, tok in spl.strtok(tplsep, pathspec) do
			print("tok", tok, "namesub", namesub, "pkgfile", pkgfile);
			print('demagiced:', demagic(namesub), demagic(pkgfile));
			local fname = tok:gsub(demagic(namesub), demagic(pkgfile));
			print('fname', fname);
			local fd = io.open(fname, "rb");
			if fd then
				fd:close();
				return fname;
			else
				errmsg = errmsg .. ("\n\tno file %s"):format(fname);
			end
		end
		return nil, errmsg;
	end
end

local function name_luaopen(dllname)
	local dirsep, tplsep, namesub, exepath, exclude = package.config:match("^(.)\n(.)\n(.)\n(.)\n(.)");
	assert(dirsep and tplsep and namesub and exepath and exclude, "package.config is malformed!");
	local ix = dllname:find(exclude, 1, true);
	if ix ~= nil then
		dllname = dllname:sub(ix + 1);
	end
	return ("luaopen_%s"):format(dllname:gsub("%.", "_"));
end

-- This helper function assists with creating so-called "hybrid" modules - modules that are implemented in a mixture
-- of C and Lua. Generally, the Lua module provides the "primary setup" (since by default .lua files are loaded in
-- preference over a C library) and uses this function to import specific methods from the library.
-- Essentially, it is package.loadlib but with cpath searching ability.
-- If a function name is given, then the return value is that function as a C function.
-- If no function name is given, then the appropriate luaopen_* name is loaded for that library and invoked. That function's
-- return value(s) are returned. If the library returns no values, the function returns 'true'.
-- If an error occurs, the first return value is 'nil'. Note that luaopen_ could return 'nil'.
function _M.hybrid_load(lib, ...)
	assert(type(lib) == "string", ("bad argument #1 to 'hybrid_load' (string expected, got %s)"):format(type(lib)));
	local arg = { n = select("#", ...), ... };
	assert(arg.n < 1 or type(arg[1]) == "string", ("bad argument #2 to 'hybrid_load' (string expected, got %s)"):format(type(arg[1])));
	local so, why = package.searchpath(lib, package.cpath);
	if not so then
		return nil, ("Could not find library '%s'%s"):format(lib, why);
	end
	if arg[1] then
		return package.loadlib(so, arg[1]);
	else
		local lo, why = package.loadlib(so, name_luaopen(lib));
		if not lo then
			return nil, why;
		end
		return lo();
	end
end

return _M;

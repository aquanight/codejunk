-- Declarations:
local tonumber = tonumber;
local error = error;
local type = type;
local select = select;

local _M = { ["_VERSION"] = 1 };

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
-- multiple version depths (like 3,4,5,1,2,3), but only the top two (3.4 in that example), are tested.
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

return _M;

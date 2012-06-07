-- Better string.format, that follows the C99 specification for printf(3).
--
-- Deviations from C99 printf:
-- - For %n, the number of characters stored up to that point is provided as 2nd, 3rd, etc return values from format(),
--   after the formatted string.
-- - The length modifiers - h, hh, l, ll, L, j, z, and t - have no effect and as such are simply ignored.
-- - Support for %q, which functions as %s but quotes the string and escapes any special characters.
-- - <N>$ constructs are permitted to leave gaps, since lua does not have the restriction of trying to advance over unknown types,
--   however, this lua implementation still requires all parameters to have explicit indexes if one is used.
-- Deviations for Lua string.format
-- - Supports the length modifiers, but they do nothing.
-- - Supports %n, which is returned with the formatted string.
-- - Supports %p, which prints the address of a table, function, userdata, or thread object as "0xHEX".
-- - Supports the use of * to retrieve field width and precision from the parameter list. A number must be positioned
--   just prior to the argument to be formatted (ie, the expected order will be width, precision, argument for %*.*s).
-- - Supports the use of <N>$, placed after a % or *. This construct overrides parameter ordering.
--   If one type specifier or * uses <N>$, all type specifiers and *s must use it.

local _fmt = string.format;
local select = select;
local tonumber = tonumber;
local assert = assert;
local error = error;
local unpack = unpack or table.unpack;
local dgmt = debug.getmetatable;
local tostring = tostring;
function string.format(fmt, ...)
	local arg = { n = select("#", ...), ... };
	local argi = 1;
	local ix = 1;
	local iy = 1;
	local work = "";
	local pctns = {};
	while true do
		ix = fmt:find("%", iy, true);
		if ix == nil then
			work = work .. fmt:sub(iy, -1);
			break; -- No more formatters.
		else
			work = work .. fmt:sub(iy, ix - 1); -- Append the intervening text verbatim.
		end
		if fmt:match("^%%%%", ix) then
			work = work .. "%";
			ix = ix + 2;
		else
			ix = ix + 1;
			local argspec = fmt:match("^(%d+)%$", ix);
			if argspec ~= nil then
				assert(argi == 1 or argi == nil, "Cannot mix explicit position specifiers with sequenced specifiers");
				argi = nil;
				ix = ix + #argspec + 1;
				argspec = tonumber(argspec);
			else
				assert(argi ~= nil, "Cannot mix explicit position specifiers with sequences specifiers");
				argspec = argi;
				argi = argi + 1;
			end
			local flag = fmt:match("^([#0- +]?)", ix);
			ix = ix + #flag;
			local width = fmt:match("^%d", ix) or fmt:match("^%*%d+%$", ix) or fmt:match("^%*", ix);
			if width ~= nil then
				ix = ix + #width;
				if width:match("^%*%d+%$") then
					assert(argi == 1 or argi == nil, "Cannot mix explicit position specifiers with sequenced specifiers");
					argi = nil;
					width = tonumber(width:sub(2, -2));
					width = assert(tonumber(arg[width]), _fmt("bad argument #%d to 'format' (number expected, got %s)", width, type(arg[width])));
				elseif width:match("^%*") then
					assert(argi ~= nil, "Cannot mix explicit position specifiers with sequences specifiers");
					width = assert(tonumber(arg[argspec]), _fmt("bad argument #%d to 'format' (number expected, got %s)", argspec, type(arg[argspec])));
					argspec = argspec + 1;
					argi = argi + 1;
				else
					width = tonumber(width);
				end
			end
			local prec = fmt:match("^%.(%d+)", ix) or fmt:match("^%.(%*%d+%$", ix) or fmt:match("^%.%*", ix);
			if prec ~= nil then
				ix = ix + #prec;
				if prec:match("^%*%d+%$") then
					assert(argi == 1 or argi == nil, "Cannot mix explicit position specifiers with sequenced specifiers");
					argi = nil;
					prec = tonumber(prec:sub(2, -2));
					prec = assert(tonumber(arg[prec]), _fmt("bad argument #%d to 'format' (number expected, got %s)", prec, type(arg[prec])));
				elseif prec:match("^%*") then
					assert(argi ~= nil, "Cannot mix explicit position specifiers with sequences specifiers");
					prec = assert(tonumber(arg[argspec]), _fmt("bad argument #%d to 'format' (number expected, got %s)", argspec, type(arg[argspec])));
					argspec = argspec + 1;
					argi = argi + 1;
				else
					prec = tonumber(prec);
				end
			end
			local lenm = fmt:match("^hh", ix) or fmt:match("^ll", ix) or fmt:match("^[hlLqjzt]", ix);
			if lenm ~= nil then
				ix = ix + #lenm;
			end
			-- At last, the type specifier!
			local conv = fmt:sub(ix, ix);
			ix = ix + 1;
			local spec = "%" .. flag;
			if width then spec = spec .. tostring(width); end
			if prec then spec = spec .. "." .. tostring(prec); end
			local fmtarg;
			if conv:match("[diouxXeEfFgGcsq]") then
				-- Defer these to lua's formatter.
				spec = spec .. conv;
				fmtarg = arg[argspec];
			elseif conv == "p" or conv == "P" then
				-- Format a table, userdata, or function to its address.
				if spec:find("#", 1, true) == nil then
					spec = spec:gsub("^%%", "%%#");
				end
				spec = spec .. (conv == "p" and "x" or "X");
				local __ = arg[argspec];
				local tostr = dgmt(__) and dgmt(__).__tostring;
				if tostr ~= nil then
					dgmt(__).__tostring = nil;
					fmtarg = tonumber(tostring(__):match("0x%x+"));
					dgmt(__).__tostring = tostr;
				else
					fmtarg = tonumber(tostring(__):match("0x%x+"));
				end
			elseif conv == "n" then
				-- No output...
				spec = nil;
				fmtarg = nil;
				-- Add the current output length.
				table.insert(pctns, #work);
			else
				error(_fmt("Invalid option '%%%s' to 'format'", conv));
			end
			work = work .. _fmt(spec, fmtarg);
		end
		iy = ix;
	end
	return work, unpack(pctns, 1, pctns.n);
end

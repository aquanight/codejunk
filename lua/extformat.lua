-- Better string.format, that follows the C99 specification for printf(3).
--
-- Deviations from C99 printf:
-- - For %n, the number of characters stored up to that point is provided as 2nd, 3rd, etc return values from format(),
--   after the formatted string.
-- - The length modifiers - h, hh, l, ll, L, j, z, and t - have no effect and as such are simply ignored.
-- - All numeric formats expect a Lua number. There is no distinction between integer and floating point types, however
--   integer-based specifiers may cause rounding or truncation of the value.
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

local pcta;
-- The only way to distinguish positive and negative zero:
local pzero = 0;
local nzero = -pzero; -- Due to constant-folding, -0 doesn't work.
local pinf = 1/pzero;
local ninf = 1/nzero;
if not _G._VERSION:match("Lua 5%.2") then
	pcta = function(val, width, prec, flags, upper)
		local exp, mant, sign;
		local str;
		if val == 0 then
			-- Value is 0,
			exp, mant = 0, 0;
			if 1/val == pinf then
				-- Positive 0
				sign = flags:match("[ +]") or "";
			else
				assert(1/val == ninf);
				-- Negative 0
				sign = '-';
			end
		else
			if val < 0 then
				sign = '-';
				mant = -val;
			else
				sign = flags:match("[ +]") or "";
				mant = val;
			end
			exp = 0;
			repeat
				local ip, _ = math.modf(mant);
				if ip < 8 then
					mant = mant * 2;
					exp = exp - 1;
				elseif ip >= 16 then
					mant = mant / 2;
					exp = exp + 1;
				end
			until (mant >= 8 and mant < 16)
			while mant ~= 0 do
				local ip, fp = math.modf(mant);
				if str then
					str = str .. _fmt(upper and "%1.1X" or "%1.1x", ip);
				else
					str = _fmt(upper and "%1.1X" or "%1.1x.", ip);
				end
				if prec then
					prec = prec - 1
					if prec < 1 then
						break
					end
				end
				mant = fp*16;
			end
		end
		str = str .. (upper and "P" or "p") .. _fmt("%d", exp);
		if width and (#str + 2) < width then
			local fill = width - (#str + 2);
			if flags:match("-") then
				str = "0x" .. str .. (" "):rep(fill);
			elseif flags:match("0") then
				str = "0x" .. ("0"):rep(fill) .. str;
			else
				str = (" "):rep(fill) .. "0x" .. str;
			end
		else
			str = "0x" .. str;
		end
		return str;
	end
end

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
				ix = ix + 1 + #prec;
				if prec:match("^%*%d+%$") then
					assert(argi == 1 or argi == nil, "Cannot mix explicit position specifiers with sequenced specifiers");
					argi = nil;
					prec = tonumber(prec:sub(2, -2));
					prec = assert(tonumber(arg[prec]), _fmt("bad argument #%d to 'format' (number expected, got %s)", prec, type(arg[prec])));
				elseif prec:match("^%*") then
					assert(argi ~= nil, "Cannot mix explicit position specifiers with sequences specifiers");
					prec = assert(tonumber(arg[argspec]), _fmt("bad argument #%d to 'format' (number expected, got %s)", argspec, type(arg[argspec])));
					if prec < 0 then
						prec = -prec;
						flags = flags:match("-") and flags or (flags .. "-");
					end
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
			elseif conv == "a" or conv == "A" then
				if _G._VERSION:match("Lua 5%.2") then
					spec = spec .. conv
					fmtarg = arg[argspec];
				else
					if arg ~= arg or arg == pinf or arg == ninf then
						-- NaN or infintiy
						spec = spec .. "g";
						fmtarg = arg[argspec];
					else
						spec = "%s";
						fmtarg = pcta(arg[argspec], width, prec, flag, conv == "A");
					end
				end
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

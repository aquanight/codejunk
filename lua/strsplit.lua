local _M = {};

-- Accepts two aruguments - a delimiter and a string
function _M.strsep(delim, str)
	if str == "" then
		return nil;
	end
	local ix = str:find(delim, 1, true);
	local rest;
	local tok;
	if ix == nil then
		tok = str;
		rest = "";
	else
		rest = str:sub(ix + #delim);
		tok = str:sub(1, ix - 1);
	end
	return rest, tok;
end

function _M.strtok(delim, str)
	return _M.strsep, delim, str;
end

-- max - maximum number of tokens to yield, the last token contains the string's remainder
-- if negative, it splits 'max' tokens off the back end instead
-- if zero or nil, it does nothing
function _M.split(delim, str, max)
	if max ~= nil and tonumber(max) == nil then error("Bad number to 'max'") end
	if max == 0 then max = nil end
	local backwards = false;
	if max and max < 0 then
		max = -max;
		backwards = true;
		delim = delim:reverse();
		str = str:reverse();
	end
	local res = {};
	for _, tok in _M.strtok(delim, str) do
		if backwards then
			table.insert(res, 1, tok:reverse());
		else
			table.insert(res, tok);
		end
		if max then max = max - 1 end
		if max and max < 2 then
			-- No room left, return remainder.
			if backwards then
				table.insert(res, 1, _:reverse());
			else
				table.insert(res, _);
			end
			break
		end
	end
	return res;
end

-- Backwards version loaded into the string table, making it available as a method applied to a string
-- directly like so
-- tbl = csvline:split(",")
function string.split(str, delim, max)
	return _M.split(delim, str, max);
end

return _M;

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

function _M.split(delim, str)
	local res = {};
	for _, tok in _M.strtok(delim, str) do
		table.insert(res, tok);
	end
	return res;
end

return _M;

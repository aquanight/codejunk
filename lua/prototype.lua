local _M = {};

-- Returns a string containing 1-letter type identification of each argument:
-- n -> number
-- s -> string
-- f -> function
-- t -> table
-- c -> thread (think coroutine)
-- u -> userdata
-- - -> nil
function _M.typesof(...)
	local arg = { n = select("#", ...), ... };
	local types = {}
	for i = 1,arg.n,1 do
		types[i] = type(arg[i]):gsub("^thread$", "c"):gsub("^nil$", "-"):sub(1,1);
	end
	return table.concat(types, "");
end

return _M;

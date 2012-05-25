local _M = {};

-- Returns a table view that contains only the specified keys.
-- If the keys are integers, they are accessed through view[1 .. j] in order.
function _M.slice(tbl, ...)
	local keymap = {}
	local arg = { n = select("#", ...), ... };
	for i = 1, arg.n, 1 do
		if type(arg[i]) == "number" then
			local ip, fp = math.modf(arg[i]);
			if fp == 0 and ip > 0 then
				-- Positive Integer.
				table.insert(keymap, arg[i]);
			else
				-- Non-integer or negative integer (or 0)
				keymap[i] = arg[i];
			end
		elseif arg[i] ~= nil then
			-- Not a number
			keymap[i] = arg[i];
		end
	end
	local mt = {
		__index = function(t, k)
			local realkey = keymap[k];
			if realkey == nil then
				return nil;
			end
			return tbl[realkey];
		end,
		__newindex = function(t, k, v)
			local realkey = keymap[k];
			if realkey == nil then
				error("Attempt to create a table element through a slice view");
			end
			tbl[realkey] = v;
		end
	};
	return setmetatable({}, mt);
end

return _M;

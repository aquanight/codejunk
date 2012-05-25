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

-- As slice(), but sequence indexes are not re-ordered.
function _M.rawslice(tbl, ...)
	local keymap = {}
	local arg = { n = select("#", ...), ... };
	for i = 1, arg.n, 1 do
		keymap[i] = arg[i];
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

-- Creates a "chain" of tables where any index not found in the first
-- is looked up in the next.
-- When retrieving, any index not found in any table results in 'nil'. __index metamethod is respected.
-- When storing, any index not found in any table is created in the first table. __index metamethod is respected
-- to find the first table that has the index, __newindex is respected, if applicable, on the table that is chosen.
function _M.chain(...)
	local arg = { n = select("#", ...), ... };
	assert(arg.n >= 1, "No tables provided to 'chain'");
	for i = 1, arg.n, 1 do
		assert(type(arg[i]) == "table", ("bad argument #%d to 'chain' (table expected, got %s)"):format(i, type(arg[i])));
	end
	local mt = {
		__index = function(t, k)
			for i = 1, arg.n, 1 do
				local val = t[k];
				if val ~= nil then
					return val;
				end
			end
			return nil;
		end,
		__newindex = function(t, k, v)
			for i = 1, arg.n, 1 do
				local val = t[k];
				if val ~= nil then
					t[k] = v;
					return;
				end
			end
			arg[1] = v;
		end
	};
	return setmetatable({}, mt);
end

return _M;

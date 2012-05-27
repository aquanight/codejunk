function dump(value, ...)
	local arg = { n = select("#", ...), ... };
	local name = arg[1] or "_";
	assert(type(name) == "string", ("bad argument #2 to 'dump' (string expected, got %s)"):format(type(name)));
	assert(name:match("^[%a_][%w_]*$"), "name must be a valid Lua identifier");
	local references = {}
	local refname = name .. "_refs"

	local metatables = {}

	-- This function handles the work of converting values to a text representation.
	local function realdump(val, indent)
		local dumpbytype = {
			["string"] = function (val)
				local work = val:gsub(
					"[%z\1-\031\128-\255']",
					function (match)
						if match == "'" then
							return "\\'";
						elseif match == "\t" then
							return "\\t";
						elseif match == "\n" then
							return "\\n";
						elseif match == "\r" then
							return "\\r";
						elseif match == "\a" then
							return "\\a";
						elseif match == "\b" then
							return "\\b";
						elseif match == "\f" then
							return "\\f";
						elseif match == "\v" then
							return "\\v";
						elseif match == "\\" then
							return "\\\\";
						elseif match == "\"" then
							return "\\\"";
						else
							local byte = string.byte(match);
							return ("\\%03d"):format(byte);
						end
					end
				);
				return '"' .. work .. '"';
			end,
			["number"] = function (val)
				return tostring(val);
			end,
			["boolean"] = function (val)
				if val then return "true"; else return "false"; end
			end,
			["table"] = function (val)
				-- Capture the table's metatable.
				local mt = debug.getmetatable(val)
				if mt ~= nil and metatables[val] == nil then
					metatables[val] = mt
					-- Descend into this metatable as a dummy, so as to generate its reference, but
					-- only do so if the metatable is not the same as the top-level reference.
					-- That is special-cased later. This also captures any inner metatables.
					if mt ~= value then
						realdump(mt, 2);
					end
				end
				if indent == 0 then
					local res = "{\n";
					for k,v in pairs(val) do
						local realv = rawget(val, k);
						res = res .. ("\t[%s] = %s\n"):format(realdump(k, 1), realdump(realv, 1));
					end
					res = res .. "}";
					return res;
				else
					references[val] = 1;
					return ("%s[%s]"):format(refname, realdump(tostring(val), indent+1));
				end
			end,
			["function"] = function (val)
				if indent == 0 then
					if debug.getinfo(val).source == "=[C]" then
						return "nil --[[Native Function]]";
					else
						return ("loadstring(%s, %s)"):format(realdump(string.dump(val), 1), realdump(debug.getinfo(val).source, 1));
					end
				else
					references[val] = 1;
					return ("%s[%s]"):format(refname, realdump(tostring(val), indent));
				end
			end,
			["thread"] = function (val)
				if coroutine.status(val) == "dead" then
					return "nil --[[thread (dead)]]";
				end
				local btix = 0
				-- Find the highest 'n' that debug.getinfo(val, btix) is not nil.
				while debug.getinfo(val, btix) ~= nil do
					btix = btix + 1;
				end
				btix = btix - 1
				if btix < 0 then
					return "nil --[[thread (inactive)]]";
				end
				local fn = debug.getinfo(val, btix).func;
				return ("coroutine.create(%s)"):format(realdump(fn, 1));
			end,
			["userdata"] = function (val)
				return "nil --[[userdata]]"
			end,
			["nil"] = function (val)
				return "nil";
			end,
		}
		return dumpbytype[type(val)](val);
	end

	--If it's a table, pre-fill references.
	local function prefill(tbl)
		for k, v in pairs(tbl) do
			if type(k) == "function" or type(k) == "table" then
				if type(k) == "table" and references[k] ~= 1 then
					references[k] = 1;
					prefill(k);
				else
					references[k] = 1;
				end
			end
			if type(v) == "function" or type(v) == "table" then
				if type(v) == "table" and references[v] ~= 1 then
					references[v] = 1;
					prefill(v);
				else
					references[v] = 1;
				end
			end
		end
	end

	if type(value) == "table" then prefill(value) end

	local dumped = realdump(value, 0)

--	setmetatable(references, { ["__newindex"] = function(t,k,v) error "No new references should be created after main dump!" end });

	-- Construct the objects in the reference table.
	local final = "do\nlocal " .. refname .. " = {\n";
	for k, v in pairs(references) do
		if type(k) == "function" then
			final = final .. ('\t[%s] = %s\n'):format(realdump(tostring(k), 1), realdump(k, 0));
		elseif type(k) == "table" then
			final = final .. ('\t[%s] = {}\n'):format(realdump(tostring(k), 1));
		end
	end
	final = final .. "}\n";
	-- Fill in the tables of the reference table.
	for k,v in pairs(references) do
		if type(k) == "table" then
			for k2,v2 in pairs(k) do
				final = final .. ("%s[%s][%s] = %s\n"):format(refname, realdump(tostring(k), 1), realdump(k2, 1), realdump(v2, 1));
			end
		end
	end
	-- Generate the main reference.
	-- Handle a circular reference:
	if references[value] == nil then
		final = final .. ("%s = %s\n"):format(name, dumped);
	else
		final = final .. ("%s = %s\n"):format(name, realdump(value, 1))
	end
	-- Assign metatables
	for k,v in pairs(metatables) do
		final = final .. ("setmetatable(%s, %s)\n"):format(
			(k == value) and name or realdump(k, 1),
			(v == value) and name or realdump(v, 1))
	end

	final = final .. "done\n"

	return final
end

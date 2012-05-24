-- This function is an iterator. It returns the 3 values needed to use a for/in block.
-- 'args' is expected to be a table constructed by { ... } in the main chunk.
-- This table may be modified by getopt(3) so it is highly recommended that the calling code retains a reference.
-- 'optstr' is formatted as defined by getopt(3)
-- Subsequent arguments specify the name of permitted "long options", which are specified on the command line as "--name[=value]".
-- Each argument specifies the full name. Note that no name can contain an = except as a suffix: if a single = suffixes the name, then
-- that long option shall require an argument. If two = suffix the name, then that long option shall allow an optional argument.
-- Note that if '-' appears in optstr, the only way to specify it is with another "short option" character defined in optstr that takes no argument.
-- Long options with an optional argument require that argument specified with the option in a single parameter (--name=value, but not --name value).
-- This is because -- alone means termination of the option list, and --text is taken as a long option. If 'a' took an argument (even if optional), then
-- -a- would specify a with a argument of '-'.
-- Valid short options are not automatically valid long options (eg if -a is valid, --a is not automatically valid) and vice versa (if --a is valid, -a is
-- not automatically valid).
-- This iterator runs in one of 3 modes, as defined by getopt(3):
-- Permute Mode: Non-option arguments are moved to be after all option arguments - this means the table passed in is modified by the iterator.
-- 	This is the default mode. Note that there is no mechanism to explicitly select Permute Mode, even when the POSIXLY_CORRECT environment
-- 	variable is set.
-- POSIX Mode: The first non-option argument terminates processing.
-- 	This mode is selected if the environment variable POSIXLY_CORRECT is set or 'optstr' begins with a + character.
-- In-place Mode: In this mode, each non-option argument is treated as an argument to the option '\001', even is returned as such even if '\001' is not
-- specified in optstr. Note that if no '--' option is found, this means all arguments in args are used.
-- In any mode, an option consisting of "--" terminates option processing at that point. Even in 'in-place mode', no further options are processed.
-- When the iteration finishes, it inserts an option containing "--" just after the last option argument processed,
-- if one is not already present at that location. This way the main program can find where non-options begin by searching for this value.
-- Iteration products:
-- The first value of the iteration is one of three values:
-- - true - a recognized and properly-formed option
-- - false - an ill-formed option (the argument started with '-' but the option character is unrecognized, or a required argument was not found)
-- - nil - no more options remain (in a for/in loop, this result terminates the loop with no execution of the body). Prior to this being returned, the
--         argument table is modified such that a "--" is inserted prior to the argument that caused this result, if one is not already present.
-- When the first value is 'true', the second value returned is the option character itself, and the third value is the option's argument, if one
-- is provided, or nil otherwise.
-- When the first value is 'false', the second value is the option character that caused this result, and the third value is '?' if the error was due
-- to an unrecognized character, or ':' if the error was due to a missing argument.
-- When the first value is 'nil', there are no other result values. In typical usage in a for/in loop, this condition terminates the loop.
local function is_option(arg)
	if #arg < 2 then
		return false;
	end
	if arg:sub(1, 1) ~= "-" then
		return false;
	end
	if arg == "--" then
		return false;
	end
	return true;
end
local function getopts(args, optstr, ...)
	local opttable = {};
	local nonopt_mode = nil; -- Permute Mode
	if os.getenv("POSIXLY_CORRECT") ~= nil or optstr:sub(1,1) == "+" then
		nonopt_mode = '+'; -- POSIX mode 
	elseif optstr:sub(1, 1) == "-" then
		nonopt_mode = '-'; -- In-place mode
	else
	end
	optstr = optstr:gsub("^[+-]?:?", ""); -- Remove leading +/- and leading : (we implement leading : via 4th value in error condition)
	local options = {};
	local longopts = { ... };
	for opt,arg in optstr:gmatch("(.)(:?:?)") do
		options[opt] = #arg;
	end
	for i,v in ipairs(longopts) do
		local name, arg = v:match("^([^=]+)(=?=?)$");
		if name == nil then
			error("Embedded = are not allowed in a longopt name.");
		end
		options["-" .. name] = #arg; -- Prefix a -
	end
	local curopt = nil;
	local optind = 1;
	local function getopt_iterate(...) -- We don't care. Our state is in upvalues.
		if curopt == nil then
			-- No option in progress, so get the next one.
			curopt = args[optind];
			if curopt == nil then
				-- End of argument list. Insert a -- at this point.
				table.insert(args, optind, "--");
				return nil;
			end
			if not is_option(curopt) then
				-- Non-option paramter (empty string, a lone - (which often means STDIN), or an argument not starting with a -.
				if curopt == "--" then
					return nil;
				elseif nonopt_mode == '+' then
					-- POSIX mode: terminate.
					table.insert(args, optind, "--");
					return nil;
				elseif nonopt_mode == "-" then
					-- In-place mode.
					optind = optind + 1;
					local result = curopt;
					curopt = nil;
					return true, "\001", result;
				else
					-- Permute Mode
					local foundix = nil;
					for ix = (optind + 1), #args, 1 do
						local thatarg = args[ix];
						if thatarg == "--" then break; end
						if is_option(thatarg) then foundix = ix; break; end
					end
					if foundix == nil then
						-- No options remain.
						table.insert(args, optind, "--");
						return nil;
					else
						local target = table.remove(args, foundix);
						table.insert(args, optind, target);
						curopt = target;
					end
				end
			end
			optind = optind + 1; -- Move this to the next argument.
			if curopt:sub(1, 2) == "--" then
				-- Here we handle long options.
				local longopt = curopt;
				curopt = nil;
				local eqat = longopt:find("=");
				local name, arg;
				if eqat == nil then
					name = longopt:sub(3);
					arg = nil;
				else
					name = longopt:sub(3, eqat - 1);
					arg = longopt:sub(eqat + 1);
				end
				local argct = options["-" .. name];
				if argct == 0 then -- No argument.
					return true, name, nil;
				elseif argct == 1 then -- Required argument.
					if arg == nil then
						arg = args[optind];
						if arg == nil then
							return false, name, ":";
						end
						optind = optind + 1;
						return true, name, arg;
					else
						return true, name, arg;
					end
				elseif argct == 2 then
					return true, name, arg;
				end
			end
			curopt = curopt:gsub("^-", ""); -- Remove that leading dash.
		end
		-- Here we handle short options.
		local optch = curopt:sub(1,1);
		curopt = curopt:sub(2,-1);
		if #curopt < 1 then curopt = nil; end
		if options[optch] == nil then
			return false, optch, '?';
		elseif options[optch] == 0 then
			return true, optch, nil;
		elseif options[optch] >= 1 then
			-- Consume remaining text of curopt, if present.
			local argument = curopt;
			curopt = nil;
			if argument == nil then
				if options[optch] == 1 then
					-- Try to take the next argument as a parameter. Note that we will use -- as such!
					argument = args[optind]; -- Remember this was incremented last time curopt was pulled.
					if argument == nil then
						-- Argument is missing.
						return false, optch, ':';
					else
						optind = optind + 1;
						return true, optch, argument;
					end
				else
					return true, optch, nil;
				end
			else
				return true, optch, argument;
			end
		end
	end
	return getopt_iterate, args, nil
end

local _M = { ["getopts"] = getopts };

return _M;

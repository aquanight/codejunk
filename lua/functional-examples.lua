-- Some example usages of the functional.lua methods:

require("functional").setup();

-- Wraps method calls:
local function methodize(mthd)
	return function(obj, ...)
		return obj[mthd](obj, ...);
	end
end

local unpack = unpack or table.unpack;

-- The C *printf family:
local sprintf = string.format;

local printf = sprintf:chain(function(str) io.stdout:write(str); end)

local fprintf = methodize("write"):mutate(sprintf, 2); -- fprintf(io.stderr, "blah %s blah", "hello") -> io.stderr:write(string.format("blah %s blah", "hello"))

local vsprintf = sprintf:mutate(unpack, 2);

local vprintf = printf:mutate(unpack, 2);

local vfprintf = fprintf:mutate(unpack, 3);

-- Some extensions:
local errorf = sprintf:chain(error);

local assertf = assert:mutate(sprintf, 2);

-- Make math.random take only an upperbound, but generate 1 random number for every argument given.
local rnd = math.random:iterate(1);

-- An alternate definition of printf based on the above fprintf, using map

local alt_printf = fprintf:map(io.stdout);

-- Pack a formatter with a preset format string.
local indent = sprintf:map("\t%s");



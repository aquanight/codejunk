local args = { ... };
local require = require;
local print = print;
local rm = table.remove;
local ins = table.insert;
local unp = unpack;
local sprintf = string.format;
local ipairs = ipairs;

local function printf(fmt, ...)
	print(sprintf(fmt, ...));
end

local _ = require("getopt");
local getopts = _.getopts;

if #args < 1 then
	print("Specifying the short options to use is required.");
	os.exit(1);
end

local shortopts = rm(args, 1);

local longopts = {};

while true do
	local spec = rm(args, 1);
	if spec == nil then
		print("Specifying '--' followed by some arguments to test against is required.");
		os.exit(1);
	end
	if spec == "--" then
		break
	end
	ins(longopts, spec);
end

for cond, optch, arg in getopts(args, shortopts, unp(longopts)) do
	if cond then
		if arg == nil then
			printf("Option %s (no argument)", optch);
		elseif optch == "\001" then
			printf("Inline non-option %s", arg);
		else
			printf("Option %s = %s", optch, arg);
		end
	else
		if arg == "?" then
			printf("Unknown option %s", optch);
		elseif arg == ":" then
			printf("Option %s missing argument", optch);
		else
			printf("Unknown error %s for option %s", arg, optch);
		end
	end
end

local theend;

for i,v in ipairs(args) do
	if v == "--" then
		theend = i;
		break;
	end
end

if theend == nil then
	print("Something went wrong, no -- was inserted by getopts!");
	os.exit(1);
end

print("Remaining arguments:");
for ix = theend + 1, #args, 1 do
	printf("%s", tostring(args[ix]));
end

print("Done.");

os.exit(0);

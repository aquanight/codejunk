-- Test-bed for functional.lua and strsplit.lua

local require = require("require").require;
require("functional").setup();
local ss = require("strsplit");

debug.getmetatable("").__div = ss.split:rearrange(2, 1);

require("dump");

print(dump("this is the song that never end yes it goes on and on my friends" / " ", "_"));

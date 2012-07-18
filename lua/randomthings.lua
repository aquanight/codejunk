local _M = {};
_M._NAME = 'randomthings';
_M._VERSION = 1;
_M._M = _M;

local function _none()
	return nil
end

local function _pass(l, r)
	return ((l ~= nil) and l) or ((l == nil) and r);
end

debug.setmetatable(nil, {
	__call = _none,
	__index = _none,
	__concat = _pass,
	__add = _pass,
	__sub = function(l, r) return ((l ~= nil) and l) or ((l == nil) and -r); end,
	__mul = function(l, r) return 0 * _pass(l, r) end,
	__div = function(l, r) return ((l == nil) and 0/r) or ((l ~= nil) and l/0) end,
	__pow = function(l, r) return ((l == nil) and 0^r) or ((l ~= nil) and l^0) end,
	__mod = function(l, r) return ((l == nil) and 0%r) or ((l ~= nil) and l%0) end,
	__unm = _none,
	__tostring = function() return "<nil>"; end
});



return _M;

-- Minimal stand-ins for Roblox globals used by the shared modules.
local function color(r, g, b)
	return {
		R = r,
		G = g,
		B = b,
		Lerp = function(self)
			return self
		end,
	}
end
local Color3 = {
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
	new = color,
	fromHSV = color,
}

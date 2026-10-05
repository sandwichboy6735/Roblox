--------------------------------------------------------------------------------
-- PetStyles - how each pet looks (used by the client's PetBuilder).
--
--   Archetype: body plan - Dog, Wolf, Cat, Fox, Bunny, Deer, Unicorn, Bear,
--              Lamb, Owl, Penguin, Phoenix, Dragon, Seal, Crab, Lizard, Capybara
--   Primary / Secondary / Accent: main body, belly & details, ears/horns/etc.
--   Material: optional Enum.Material name for the body (Glass, Foil, Ice, ...)
--   Transparency: optional body transparency (gummy / crystal pets)
--   Extras: optional list of add-ons:
--     Crown, Halo, Helmet, AngelWings, Fire, Glow, Spots, Stripes, Sprinkles,
--     Antenna, Aurora, Lollipop
--
-- Want real art instead? Put a Model named exactly like the pet inside
-- ReplicatedStorage.PetModels and it is used instead of the generated one.
--------------------------------------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local GOLD = rgb(255, 205, 60)
local BLACK = rgb(30, 28, 34)
local WHITE = rgb(245, 245, 250)

local Pets = {
	-- Grassy Meadow
	["Dog"] = { Archetype = "Dog", Primary = rgb(205, 150, 90), Secondary = rgb(248, 228, 195), Accent = rgb(110, 70, 40) },
	["Cat"] = { Archetype = "Cat", Primary = rgb(140, 170, 235), Secondary = rgb(238, 244, 255), Accent = rgb(255, 140, 185) },
	["Bunny"] = { Archetype = "Bunny", Primary = rgb(255, 236, 246), Secondary = rgb(255, 205, 225), Accent = rgb(255, 120, 175) },
	["Fox"] = { Archetype = "Fox", Primary = rgb(235, 115, 40), Secondary = WHITE, Accent = rgb(50, 35, 35) },
	["Deer"] = { Archetype = "Deer", Primary = rgb(160, 105, 60), Secondary = rgb(245, 225, 195), Accent = rgb(120, 85, 55), Extras = { "Spots" } },
	["Unicorn"] = { Archetype = "Unicorn", Primary = rgb(255, 238, 250), Secondary = rgb(255, 140, 215), Accent = GOLD, Extras = { "Glow" } },

	-- Candy Land
	["Gummy Bear"] = { Archetype = "Bear", Primary = rgb(255, 70, 85), Secondary = rgb(255, 140, 150), Accent = rgb(200, 40, 60), Material = "Glass", Transparency = 0.15 },
	["Lollipop Lamb"] = { Archetype = "Lamb", Primary = rgb(255, 200, 230), Secondary = rgb(120, 70, 95), Accent = rgb(255, 90, 160), Extras = { "Lollipop" } },
	["Choco Puppy"] = { Archetype = "Dog", Primary = rgb(115, 70, 40), Secondary = rgb(190, 130, 85), Accent = rgb(80, 45, 25), Extras = { "Sprinkles" } },
	["Candy Cane Cat"] = { Archetype = "Cat", Primary = WHITE, Secondary = rgb(255, 255, 255), Accent = rgb(230, 30, 50), Extras = { "Stripes" } },
	["Cotton Candy Dragon"] = { Archetype = "Dragon", Primary = rgb(165, 200, 255), Secondary = rgb(255, 185, 225), Accent = WHITE, Extras = { "Glow" } },
	["Sugar Phoenix"] = { Archetype = "Phoenix", Primary = rgb(255, 120, 200), Secondary = rgb(255, 225, 130), Accent = rgb(255, 245, 255), Extras = { "Fire", "Glow" } },

	-- Frozen Peaks
	["Penguin"] = { Archetype = "Penguin", Primary = BLACK, Secondary = WHITE, Accent = rgb(255, 150, 40) },
	["Seal"] = { Archetype = "Seal", Primary = rgb(150, 192, 240), Secondary = rgb(228, 240, 255), Accent = BLACK },
	["Snow Owl"] = { Archetype = "Owl", Primary = rgb(232, 244, 255), Secondary = rgb(170, 210, 250), Accent = rgb(255, 195, 50) },
	["Ice Wolf"] = { Archetype = "Wolf", Primary = rgb(150, 215, 255), Secondary = WHITE, Accent = rgb(60, 130, 220), Material = "Ice" },
	["Frost Dragon"] = { Archetype = "Dragon", Primary = rgb(80, 175, 255), Secondary = rgb(220, 245, 255), Accent = rgb(40, 90, 200), Extras = { "Glow" } },
	["Aurora Yeti"] = { Archetype = "Bear", Primary = rgb(225, 250, 255), Secondary = rgb(200, 240, 255), Accent = rgb(120, 255, 220), Extras = { "Aurora", "Glow" } },

	-- Volcano
	["Magma Crab"] = { Archetype = "Crab", Primary = rgb(200, 60, 30), Secondary = rgb(255, 150, 40), Accent = BLACK },
	["Ember Lizard"] = { Archetype = "Lizard", Primary = rgb(255, 120, 40), Secondary = rgb(255, 210, 90), Accent = rgb(95, 35, 20) },
	["Lava Hound"] = { Archetype = "Wolf", Primary = rgb(60, 32, 32), Secondary = rgb(255, 95, 20), Accent = rgb(255, 200, 60), Extras = { "Spots", "Glow" } },
	["Fire Fox"] = { Archetype = "Fox", Primary = rgb(255, 85, 10), Secondary = rgb(255, 215, 90), Accent = rgb(120, 20, 10), Extras = { "Fire" } },
	["Inferno Dragon"] = { Archetype = "Dragon", Primary = rgb(200, 35, 15), Secondary = rgb(255, 170, 40), Accent = BLACK, Extras = { "Fire", "Glow" } },
	["Phoenix King"] = { Archetype = "Phoenix", Primary = rgb(255, 185, 40), Secondary = rgb(255, 80, 20), Accent = rgb(255, 245, 200), Extras = { "Crown", "Fire", "Glow" } },

	-- Space Station
	["Moon Bunny"] = { Archetype = "Bunny", Primary = rgb(220, 205, 255), Secondary = rgb(170, 150, 235), Accent = rgb(255, 235, 140), Extras = { "Helmet" } },
	["Star Pup"] = { Archetype = "Dog", Primary = rgb(255, 235, 120), Secondary = WHITE, Accent = rgb(255, 180, 40), Extras = { "Helmet", "Antenna" } },
	["Nebula Cat"] = { Archetype = "Cat", Primary = rgb(130, 75, 215), Secondary = rgb(255, 120, 225), Accent = rgb(90, 230, 255), Extras = { "Spots", "Glow" } },
	["Galaxy Wolf"] = { Archetype = "Wolf", Primary = rgb(40, 32, 110), Secondary = rgb(120, 200, 255), Accent = rgb(220, 130, 255), Extras = { "Spots", "Glow" } },
	["Void Dragon"] = { Archetype = "Dragon", Primary = rgb(28, 12, 48), Secondary = rgb(170, 60, 255), Accent = rgb(230, 200, 255), Extras = { "Glow" } },
	["Supernova Capybara"] = { Archetype = "Capybara", Primary = rgb(255, 150, 60), Secondary = rgb(255, 238, 180), Accent = rgb(255, 90, 30), Extras = { "Crown", "Fire", "Glow" } },

	-- Gem Egg
	["Golden Dog"] = { Archetype = "Dog", Primary = GOLD, Secondary = rgb(255, 235, 150), Accent = rgb(220, 160, 30), Material = "Foil" },
	["Diamond Cat"] = { Archetype = "Cat", Primary = rgb(185, 240, 255), Secondary = rgb(235, 252, 255), Accent = rgb(120, 200, 255), Material = "Glass", Transparency = 0.2 },
	["Crystal Dragon"] = { Archetype = "Dragon", Primary = rgb(195, 255, 248), Secondary = rgb(150, 220, 255), Accent = rgb(255, 255, 255), Material = "Glass", Transparency = 0.2, Extras = { "Glow" } },
	["Celestial Capybara"] = { Archetype = "Capybara", Primary = rgb(255, 240, 200), Secondary = rgb(255, 230, 160), Accent = GOLD, Extras = { "Halo", "AngelWings", "Glow" } },

	-- Exclusive
	["Golden Capybara"] = { Archetype = "Capybara", Primary = GOLD, Secondary = rgb(255, 235, 160), Accent = rgb(200, 140, 20), Material = "Foil", Extras = { "Crown" } },
}

local PetStyles = {}
PetStyles.Pets = Pets

-- Every archetype the builder knows (used by tests).
PetStyles.Archetypes = {
	Dog = true,
	Wolf = true,
	Cat = true,
	Fox = true,
	Bunny = true,
	Deer = true,
	Unicorn = true,
	Bear = true,
	Lamb = true,
	Owl = true,
	Penguin = true,
	Phoenix = true,
	Dragon = true,
	Seal = true,
	Crab = true,
	Lizard = true,
	Capybara = true,
}

PetStyles.Extras = {
	Crown = true,
	Halo = true,
	Helmet = true,
	AngelWings = true,
	Fire = true,
	Glow = true,
	Spots = true,
	Stripes = true,
	Sprinkles = true,
	Antenna = true,
	Aurora = true,
	Lollipop = true,
}

return PetStyles

--------------------------------------------------------------------------------
-- BrainrotStyles - how each brainrot looks (used by BrainrotBuilder).
--
--   Archetype: body plan. Animals: Dog, Wolf, Cat, Fox, Bunny, Deer, Unicorn,
--              Bear, Lamb, Owl, Penguin, Phoenix, Dragon, Seal, Crab, Lizard,
--              Capybara. Brainrot shapes: Banana, Frog, Squid, Turtle, Shark,
--              Log, Cup, Elephant, Giraffe, Dolphin, Blob
--   Primary / Secondary / Accent: main body, belly & details, feet/extras
--   Material / Transparency: optional body material (Foil, Glass, Neon, ...)
--   Scale: optional size tweak (1 = normal)
--   Extras: Crown, Halo, Helmet, AngelWings, Fire, Glow, Spots, Stripes,
--           Sprinkles, Antenna, Aurora, Lollipop, Sneakers, Bongos, CupHeld,
--           Pizza, Cone, Tube, Jet, Bat, Tutu, Spikes, Propeller, Glasses,
--           Bomb, Scarf
--
-- Want real art? Put a Model named exactly like the brainrot inside
-- ReplicatedStorage.BrainrotModels and it is used instead of the generated one.
--------------------------------------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local GOLD = rgb(255, 205, 60)
local BLACK = rgb(30, 28, 34)
local WHITE = rgb(245, 245, 250)

local Characters = {
	["Pasta Panda"] = { Archetype = "Bear", Primary = WHITE, Secondary = BLACK, Accent = rgb(255, 215, 120), Extras = { "Spots" } },
	["Bongo Banana"] = { Archetype = "Banana", Primary = rgb(255, 225, 60), Secondary = rgb(255, 245, 180), Accent = rgb(120, 85, 40), Extras = { "Bongos" } },
	["Espresso Frog"] = { Archetype = "Frog", Primary = rgb(95, 190, 70), Secondary = rgb(200, 240, 150), Accent = rgb(110, 70, 40), Extras = { "CupHeld" } },
	["Pizza Pigeon"] = { Archetype = "Owl", Primary = rgb(150, 160, 185), Secondary = rgb(215, 220, 235), Accent = rgb(255, 150, 60), Extras = { "Pizza" } },

	["Gelato Goat"] = { Archetype = "Deer", Primary = rgb(240, 235, 225), Secondary = rgb(255, 200, 220), Accent = rgb(140, 110, 90), Extras = { "Cone" } },
	["Mozzarella Moth"] = { Archetype = "Phoenix", Primary = rgb(250, 245, 230), Secondary = rgb(255, 230, 180), Accent = rgb(210, 160, 90), Extras = { "Antenna" } },
	["Spaghetti Squid"] = { Archetype = "Squid", Primary = rgb(255, 200, 110), Secondary = rgb(230, 70, 60), Accent = rgb(255, 240, 200) },
	["Tiramisu Turtle"] = { Archetype = "Turtle", Primary = rgb(120, 80, 55), Secondary = rgb(245, 230, 200), Accent = rgb(90, 160, 90) },

	["Capybara Cannoli"] = { Archetype = "Capybara", Primary = rgb(175, 125, 80), Secondary = rgb(235, 205, 160), Accent = rgb(90, 60, 40), Extras = { "Tube" } },
	["Sneaker Shark"] = { Archetype = "Shark", Primary = rgb(70, 130, 220), Secondary = rgb(225, 240, 255), Accent = rgb(230, 60, 80), Extras = { "Sneakers" } },
	["Croco Jet"] = { Archetype = "Lizard", Primary = rgb(80, 150, 70), Secondary = rgb(200, 230, 150), Accent = rgb(110, 85, 45), Extras = { "Jet" }, Scale = 1.15 },
	["Timber Tapper"] = { Archetype = "Log", Primary = rgb(150, 100, 60), Secondary = rgb(225, 190, 140), Accent = rgb(90, 60, 40), Extras = { "Bat" } },

	["Ballerina Latte"] = { Archetype = "Cup", Primary = rgb(255, 250, 245), Secondary = rgb(235, 200, 160), Accent = rgb(170, 110, 70), Extras = { "Tutu" } },
	["Cactus Elephante"] = { Archetype = "Elephant", Primary = rgb(90, 170, 90), Secondary = rgb(160, 215, 130), Accent = rgb(255, 120, 160), Extras = { "Spikes" } },
	["Fridge Giraffe"] = { Archetype = "Giraffe", Primary = rgb(240, 240, 245), Secondary = rgb(180, 180, 195), Accent = rgb(255, 170, 40) },
	["Drone Dolphino"] = { Archetype = "Dolphin", Primary = rgb(110, 160, 230), Secondary = rgb(225, 240, 255), Accent = rgb(60, 60, 75), Extras = { "Propeller" } },

	["Nuke Nonna"] = { Archetype = "Bear", Primary = rgb(230, 200, 190), Secondary = rgb(245, 235, 230), Accent = rgb(160, 100, 120), Extras = { "Glasses", "Scarf", "Bomb" } },
	["Galaxy Gnocchi"] = { Archetype = "Blob", Primary = rgb(70, 40, 140), Secondary = rgb(190, 120, 255), Accent = rgb(120, 230, 255), Extras = { "Spots", "Glow" } },
	["Tralala Titan"] = { Archetype = "Shark", Primary = rgb(40, 60, 130), Secondary = rgb(190, 220, 255), Accent = rgb(255, 60, 60), Extras = { "Sneakers", "Crown", "Glow" }, Scale = 1.15 },

	["Omega Brainrot"] = { Archetype = "Dragon", Primary = rgb(40, 20, 70), Secondary = rgb(255, 80, 200), Accent = rgb(120, 255, 240), Extras = { "Crown", "Halo", "Glow", "Fire" }, Scale = 1.1 },

	["Sahur Stick"] = { Archetype = "Log", Primary = rgb(110, 75, 45), Secondary = rgb(210, 170, 120), Accent = rgb(255, 160, 40), Extras = { "Bat", "Glow" } },
	["Cloud Croissant"] = { Archetype = "Banana", Primary = rgb(235, 180, 110), Secondary = rgb(255, 235, 200), Accent = rgb(255, 255, 255), Extras = { "AngelWings" } },
	["Prestige Pastaroni"] = { Archetype = "Blob", Primary = rgb(255, 200, 90), Secondary = rgb(230, 60, 60), Accent = rgb(255, 250, 230), Extras = { "Crown", "Sprinkles", "Glow" } },

	["Fragment Phantom"] = { Archetype = "Squid", Primary = rgb(60, 20, 90), Secondary = rgb(170, 90, 255), Accent = rgb(120, 255, 240), Material = "Glass", Transparency = 0.25, Extras = { "Glow", "Halo", "Aurora" } },

	["Golden Goatini"] = { Archetype = "Deer", Primary = GOLD, Secondary = rgb(255, 240, 190), Accent = rgb(200, 140, 20), Material = "Foil", Extras = { "Crown", "Glow" } },
}

local BrainrotStyles = {}
BrainrotStyles.Characters = Characters

BrainrotStyles.Archetypes = {
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
	Banana = true,
	Frog = true,
	Squid = true,
	Turtle = true,
	Shark = true,
	Log = true,
	Cup = true,
	Elephant = true,
	Giraffe = true,
	Dolphin = true,
	Blob = true,
}

BrainrotStyles.Extras = {
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
	Sneakers = true,
	Bongos = true,
	CupHeld = true,
	Pizza = true,
	Cone = true,
	Tube = true,
	Jet = true,
	Bat = true,
	Tutu = true,
	Spikes = true,
	Propeller = true,
	Glasses = true,
	Bomb = true,
	Scarf = true,
}

return BrainrotStyles

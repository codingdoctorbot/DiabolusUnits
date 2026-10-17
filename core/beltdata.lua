-- DiabolusUnits — core/beltdata.lua
--
-- Ranked item IDs for the potion belt, best first, for WoW Forever (Vanilla-based items).
-- The belt takes the first one you carry and can use (core/belt.lua).
--
-- Rankings for potions, healthstones, mana potions, bandages and food follow AutoPotion's
-- Forever lists (ollidiemaus, AutoPotion 3.17.2, Core/*/Forever.lua); item IDs and their
-- order are game data, the code around them is our own. Class utility, mana gems and the
-- battleground items are added here.

local _, ns = ...

local Data = {}
ns.BeltData = Data


-- Health potions
Data.HEALTH = {
	13446, -- Major Healing Potion
	18839, -- Combat Healing Potion
	3928, -- Superior Healing Potion
	1710, -- Greater Healing Potion
	929, -- Healing Potion
	858, -- Lesser Healing Potion
	118, -- Minor Healing Potion
}

-- Battleground-only health draughts, used first inside a battleground
Data.HEALTH_BG = {
	17348, -- Major Healing Draught
	17349, -- Superior Healing Draught
}

-- Healthstones and the items that share their cooldown
Data.HEALTHSTONE = {
	19013, -- Major Healthstone
	9421, -- Major Healthstone
	19012, -- Major Healthstone
	19011, -- Greater Healthstone
	5510, -- Greater Healthstone
	19010, -- Greater Healthstone
	11951, -- Whipper Root Tuber
	19009, -- Healthstone
	14894, -- Lily Root
	5509, -- Healthstone
	23683, -- Crystal Flake Throat Lozenge
	19008, -- Healthstone
	19007, -- Lesser Healthstone
	5511, -- Lesser Healthstone
	19006, -- Lesser Healthstone
	19005, -- Minor Healthstone
	5512, -- Minor Healthstone
	19004, -- Minor Healthstone
}

-- Mana potions
Data.MANA = {
	13444, -- Major Mana Potion
	18253, -- Major Rejuvenation Potion
	18841, -- Combat Mana Potion
	13443, -- Superior Mana Potion
	6149, -- Greater Mana Potion
	3827, -- Mana Potion
	3385, -- Lesser Mana Potion
	2455, -- Minor Mana Potion
	2456, -- Minor Rejuvenation Potion
}

-- Battleground-only mana draughts
Data.MANA_BG = {
	17351, -- Major Mana Draught
	17352, -- Superior Mana Draught
}

-- Mage mana gems (own cooldown), used before potions
Data.MANA_GEM = {
	8008, -- Mana Ruby
	8007, -- Mana Citrine
	5513, -- Mana Jade
	5514, -- Mana Agate
}

-- Warriors: rage potions in the third flask
Data.RAGE = {
	13442, -- Mighty Rage Potion
	5633, -- Great Rage Potion
	5631, -- Rage Potion
}

-- Rogues: energy in the third flask
Data.ENERGY = {
	7676, -- Thistle Tea
}

-- Bandages
Data.BANDAGE = {
	14530, -- Heavy Runecloth Bandage
	14529, -- Runecloth Bandage
	8545, -- Heavy Mageweave Bandage
	8544, -- Mageweave Bandage
	6451, -- Heavy Silk Bandage
	6450, -- Silk Bandage
	3531, -- Heavy Wool Bandage
	3530, -- Wool Bandage
	2581, -- Heavy Linen Bandage
	1251, -- Linen Bandage
}

-- Alterac Valley bandages
Data.BANDAGE_AV = {
	19307, -- Alterac Heavy Runecloth Bandage
}

-- Warsong Gulch bandages
Data.BANDAGE_WSG = {
	19066, -- Warsong Gulch Runecloth Bandage
	19067, -- Warsong Gulch Mageweave Bandage
	19068, -- Warsong Gulch Silk Bandage
}

-- Arathi Basin bandages, Alliance
Data.BANDAGE_AB_ALLIANCE = {
	20243, -- Highlander's Runecloth Bandage
	20066, -- Arathi Basin Runecloth Bandage
	20237, -- Highlander's Mageweave Bandage
	20065, -- Arathi Basin Mageweave Bandage
	20244, -- Highlander's Silk Bandage
	20067, -- Arathi Basin Silk Bandage
}

-- Arathi Basin bandages, Horde
Data.BANDAGE_AB_HORDE = {
	20234, -- Defiler's Runecloth Bandage
	20066, -- Arathi Basin Runecloth Bandage
	20232, -- Defiler's Mageweave Bandage
	20065, -- Arathi Basin Mageweave Bandage
	20235, -- Defiler's Silk Bandage
	20067, -- Arathi Basin Silk Bandage
}

-- Battleground map IDs (uiMapID)
Data.MAP_AV = 1459
Data.MAP_WSG = 1460
Data.MAP_AB = 1461


-- Food that gives a Well Fed buff (order among these does not matter much)
Data.FOOD_BUFF = {
	21023, -- Dirge's Kickin' Chimaerok Chops
	20452, -- Smoked Desert Dumplings
	18254, -- Runn Tum Tuber Surprise
	13810, -- Blessed Sunfruit
	13934, -- Mightfish Steak
	18045, -- Tender Wolf Steak
	12216, -- Spiced Chili Crab
	12218, -- Monster Omelet
	16971, -- Clamlette Surprise
	13928, -- Grilled Squid
	13931, -- Nightfin Soup
	12215, -- Heavy Kodo Stew
	17222, -- Spider Sausage
	13929, -- Hot Smoked Bass
	13927, -- Cooked Glossy Mightfish
	21217, -- Sagefish Delight
	12213, -- Carrion Surprise
	6038, -- Giant Clam Scorcho
	13851, -- Hot Wolf Ribs
	12212, -- Jungle Stew
	12214, -- Mystery Stew
	12210, -- Roast Raptor
	3729, -- Soothing Turtle Bisque
	12211, -- Spiced Wolf Ribs
	4457, -- Barbecued Buzzard Wing
	20074, -- Heavy Crocolisk Stew
	3728, -- Tasty Lion Steak
	3726, -- Big Bear Steak
	3664, -- Crocolisk Gumbo
	3665, -- Curiously Tasty Omelet
	3666, -- Gooey Spider Cake
	5527, -- Goblin Deviled Clams
	3727, -- Hot Lion Chops
	5480, -- Lean Venison
	12209, -- Lean Wolf Steak
	3663, -- Murloc Fin Soup
	1017, -- Seasoned Wolf Kabob
	5479, -- Crispy Lizard Tail
	21072, -- Smoked Sagefish
	1082, -- Redridge Goulash
	5525, -- Boiled Clams
	2684, -- Coyote Steak
	2683, -- Crab Cake
	2687, -- Dry Pork Ribs
	3220, -- Blood Sausage
	3662, -- Crocolisk Steak
	5476, -- Fillet of Frenzy
	724, -- Goretusk Liver Pie
	5477, -- Strider Stew
	2888, -- Beer Basted Boar Ribs
	12224, -- Crispy Bat Wing
	6888, -- Herb Baked Egg
	5472, -- Kaldorei Spider Kabob
	5474, -- Roasted Kodo Meat
	2680, -- Spiced Wolf Meat
	17199, -- Bad Egg Nog
	17198, -- Egg Nog
	17197, -- Gingerbread Cookie
	7807, -- Candy Bar
	7808, -- Chocolate Square
	7806, -- Lollipop
	21254, -- Winter Veil Cookie
	11584, -- Cactus Apple Surprise
}

-- Plain food when no buff food is carried: conjured first, then by restore
Data.FOOD = {
	22895, -- Conjured Cinnamon Roll
	8076, -- Conjured Sweet Roll
	8075, -- Conjured Sourdough
	1487, -- Conjured Pumpernickel
	1114, -- Conjured Rye
	1113, -- Conjured Bread
	5349, -- Conjured Muffin
	19301, -- Alterac Manna Biscuit
	20031, -- Essence Mango
	13724, -- Enriched Manna Biscuit
	21215, -- Graccu's Mince Meat Fruitcake
	23172, -- Refreshing Red Apple
	20516, -- Bobbing Apple
	3448, -- Senggin Root
	2682, -- Cooked Crab Claw
	1401, -- Green Tea Leaf
	8952, -- Roasted Quail
	8932, -- Alterac Swiss
	13935, -- Baked Salmon
	21031, -- Cabbage Kimchi
	19225, -- Deep Fried Candybar
	8953, -- Deep Fried Plantains
	8948, -- Dried King Bolete
	23160, -- Friendship Bread
	11444, -- Grim Guzzler Boar
	8950, -- Homemade Cherry Pie
	13933, -- Lobster Stew
	11415, -- Mixed Berries
	21033, -- Radish Kimchi
	16171, -- Shinsollo
	12763, -- Un'Goro Etherfruit
	22324, -- Winter Kimchi
	13932, -- Poached Sunscale Salmon
	13893, -- Large Raw Mightfish
	18255, -- Runn Tum Tuber
	8957, -- Spinefin Halibut
	4599, -- Cured Ham Steak
	18635, -- Bellara's Nutterbar
	19306, -- Crunchy Frog
	21030, -- Darnassus Kimchi Pie
	13930, -- Filet of Redgill
	3927, -- Fine Aged Cheddar
	9681, -- Grilled King Crawler Legs
	16168, -- Heaven Peach
	4602, -- Moon Harvest Pumpkin
	4608, -- Raw Black Truffle
	4601, -- Soft Banana Bread
	17408, -- Spicy Beefstick
	6887, -- Spotted Yellowtail
	21552, -- Striped Yellowtail
	16766, -- Undermine Clam Chowder
	13546, -- Bloodbelly Fish
	13755, -- Winter Squid
	3771, -- Wild Hog Shank
	4607, -- Delicious Cave Mold
	4539, -- Goldenbark Apple
	17407, -- Graccu's Homemade Meat Pie
	8364, -- Mithril Head Trout
	18632, -- Moonbrook Riot Taffy
	4544, -- Mulgore Spice Bread
	19224, -- Red Hot Wings
	4594, -- Rockscale Cod
	1707, -- Stormwind Brie
	16169, -- Wild Ricecake
	6807, -- Frog Leg Stew
	11951, -- Whipper Root Tuber
	3770, -- Mutton Chop
	4593, -- Bristle Whisker Catfish
	422, -- Dwarven Mild
	4542, -- Moist Cornbread
	19305, -- Pickled Kodo Foot
	4538, -- Snapvine Watermelon
	4606, -- Spongy Morel
	16170, -- Steamed Mandu
	7228, -- Tigule's Strawberry Ice Cream
	5478, -- Dig Rat Stew
	2685, -- Succulent Pork Ribs
	4592, -- Longjaw Mud Snapper
	5473, -- Scorpid Surprise
	5526, -- Clam Chowder
	2287, -- Haunch of Meat
	414, -- Dalaran Sharp
	12238, -- Darkshore Grouper
	17119, -- Deeprun Rat Kabob
	5066, -- Fissure Plant
	4541, -- Freshly Baked Bread
	17406, -- Holiday Cheesewheel
	4605, -- Red-speckled Mushroom
	19304, -- Spiced Beef Jerky
	18633, -- Styleen's Sour Suckerpop
	4537, -- Tel'Abim Banana
	16167, -- Versicolor Treat
	733, -- Westfall Stew
	787, -- Slitherskin Mackerel
	1326, -- Sauteed Sunfish
	6316, -- Loch Frenzy Delight
	5095, -- Rainbow Fin Albacore
	6890, -- Smoked Bear Meat
	117, -- Tough Jerky
	16166, -- Bean Soup
	6290, -- Brilliant Smallfish
	17344, -- Candy Cane
	2679, -- Charred Wolf Meat
	19223, -- Darkmoon Dog
	2070, -- Darnassian Bleu
	4604, -- Forest Mushroom Cap
	7097, -- Leg Meat
	5057, -- Ripe Watermelon
	2681, -- Roasted Boar Meat
	4536, -- Shiny Red Apple
	4656, -- Small Pumpkin
	4540, -- Tough Hunk of Bread
	961, -- Healing Herb
	19995, -- Harvest Boar
	19696, -- Harvest Bread
	19996, -- Harvest Fish
	19994, -- Harvest Fruit
	6299, -- Sickly Looking Fish
	11109, -- Special Chicken Feed
	21235, -- Winter Veil Roast
}

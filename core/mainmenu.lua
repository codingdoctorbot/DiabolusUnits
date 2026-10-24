local addon, ns = ...

local mediapath = "Interface\\AddOns\\DiabolusForever\\media\\"
local cfg = ns.cfg

cfg.backdrop = { bgFile = mediapath.."Tooltip_Background", edgeFile = mediapath.."Tooltip_Border",  tiled = false, edgeSize = 10, insets = {left=8, right=8, top=8, bottom=8} }

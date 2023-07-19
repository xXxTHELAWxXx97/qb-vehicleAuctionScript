config = {}

--[[
	All possible notification systems, choose the one you want:
		qb
		okokNotify
		renzu_notify
		mythic_notify
]]
config.Notifications = "qb"

config.BypassOnwership = { -- Bypasses ownership check, useful for testing or if you want to allow admins to set a vehicle up for auction that is not owned yet.
	permission = 'admin',
	job = 'Auctioner',
	grade = '5'
}

config.ShowDistance = 'mi' -- mi or km

config.AuctionDuration = 10 -- Duration In seconds

config.MapBlips = {
	{
		coords = vector3(-45.9, -1093.82, 25.45),
		name = "Auction Area",
		sprite = 108,
		color = 2,
	}
}

config.AuctionAreas = {
    {
        coords = vector3(-46.97, -1097.2, 25.45),
        radius = 7,
		heading = 66,
	},
}

Config = {}

Config.Lang = 'en'
Config.Currency = 'cash'

Config.CreateTax = 0.15 -- 15%
Config.MaxQuantity = 500
Config.MaxPrice = 100000
Config.MaxWeight = 75000 -- 75kg
Config.MaxOffers = 8

Config.BlacklistedItems = {
    'money',
    'id_card',
    'phone',
    'driver_license',
}

Config.Locations = {
    ['Burton'] = {
        ped = {
            model = 'a_m_m_indian_01',
            scenario = 'WORLD_HUMAN_AA_SMOKE',
            icon = 'fas fa-shopping-cart',
            label = 'Open Burton Market',
        },
        coords = {
            x = -542.94,
            y = -207.84,
            z = 37.65,
            h = 199.72,
        },
        blip = {
            sprite = 480,
            color = 2,
            scale = 0.5,
            label = 'Burton MarketPlace',
        },
    },
}
Config = {}

Config.Offer = {
    createTax = 0.15, -- 15%
    maxQuantity = 500,
    maxPrice = 100000,
    maxOffers = 8,
    maxWeight = 75000, -- 75kg
    blacklistedItems = {
        'money',
        'id_card',
        'phone',
        'driver_license',
    }
}

Config.Messages = {
    Errors = {
        PlayerNotFound = 'Player not found or citizen ID missing.',
        InvalidData = 'Invalid data. Please ensure all fields are filled.',
        NotEnoughItems = 'You do not have enough of that item in your inventory.',
        OfferCreationFailed = 'Failed to create the offer. Your items have been returned.',
        OfferNotFound = 'Offer not found.',
        BuyOwnOffer = 'You cannot buy your own offer.',
        NotEnoughMoney = 'You do not have enough money in your bank account.',
        RemoveOthersOffer = 'You can only remove your own offers.',
        TransactionFailed = 'Something went wrong and the transaction failed. Please try again later.',
        RemoveOfferFailed = 'Failed to remove the offer. Please try again later.',
        MaxQuantityExceeded = 'The quantity exceeds the maximum allowed.',
        MaxPriceExceeded = 'The price exceeds the maximum allowed.',
        MaxOffersReached = 'You already have the maximum number of allowed active offers.',
        maxWeightExceeded = 'The total weight of the items exceeds the maximum allowed.',
        InsufficientTaxMoney = 'You do not have enough money to pay the creation tax.',
        itemNotAllowed = 'The selected item is not allowed in the marketplace.',
        ClaimNotAuthorized = 'You are not authorized to claim this offer.',
        OfferAlreadyClaimed = 'This offer has already been claimed.',
        ClaimUpdateFailed = 'Failed to update the claim status. Please try again later.',
        RemoveMoneyFailed = 'Failed to remove money from your account.',
        RemoveItemFailed = 'Failed to remove the item from your inventory.',
        ItemReturnFailed = 'Failed to return the item to your inventory.',
        MoneyClaimFailed = 'Failed to claim the money.',
        ItemClaimFailed = 'Failed to claim the item.'
    },
    Success = {
        PurchaseSuccess = 'You have successfully purchased the offer.',
        OfferCreated = 'Your offer has been successfully created and listed in the marketplace.',
        OfferRemoved = 'The offer has been successfully removed from the marketplace.',
        OfferPurschased = 'Your offer has been purchased.',
        OfferClaimed = 'The offer has been successfully claimed.'
    }
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
ruleset flower_delivery_shop {
    global {

        drivers_in_network = function() {
            ent:drivers.defaultsTo([])
        }

        num_drivers_in_network = function() {
            drivers_in_network().length()
        }

    }

    // shop:all_bids_received occurs when the shop is ready to pick a driver to fulfill the order
    // This rule fulfills the order
    rule drivers_all_have_bid {
        select when shop all_bids_received
    }

    // External event shop:new_order kicks off an order the shop now needs to complete
    rule prepareOrder {
        select when shop new_order
    }

    // shop:gossip_orders is a periodically raised event that handles checking if a driver is ready to be selected and gossips
    // yet to be disseminated orders into the driver network

    // This rule checks if of the known orders do any of them have enough drivers to select one to handle the order
    rule isOrderReadyForBid {
        select when shop gossip_orders
    }

    // This rule sends out orders that have not received drivers 
    rule gossipOrdersWithoutDrivers {
        select when shop gossip_orders
    }

    // Child order picos send order complete to parent flower shop when they have completed an order
    rule orderComplete {
        select when order complete
    }


}
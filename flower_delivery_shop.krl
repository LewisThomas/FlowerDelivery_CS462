ruleset flower_delivery_shop {
    meta {
        shares __testing

        use module keys

        use module google_directions_api alias directions
            with api_key = keys:google_directions_api{"api_key"}

        use module flower_delivery_order_gossip alias gossip
    }

    global {
        

        __testing = { "queries": [
            ],
            "events": [
                {
                    "domain":"shop",
                    "type":"new_order",
                    "attrs":["customer_wellKnown", "meta"]
                }
            ]}

        drivers_in_network = function() {
            ent:drivers.defaultsTo([])
        }

        num_drivers_in_network = function() {
            drivers_in_network().length()
        }

        // {
        //     "bidAmount":bid, 
        //     "location":location || "None given",
        //     "wellKnown":subscription:wellKnown_Rx(){"id"}
        // }

        find_best_bid = function(bids) {
            key = bids.keys().reduce(function(keyA,keyB){
                choose_better_bid(keyA,keyB,bids)
            })
            key
        }

        choose_better_bid = function(keyA,keyB,bids) {
            a = bids{keyA}
            b = bids{keyB}
            aPrice = a{"bidAmount"}
            bPrice = b{"bidAmount"}
            aDistance = directions:get_distance(a{"location"}, ent:address)
            bDistance = directions:get_distance(b{"location"}, ent:address)
            priceDiff = math:abs(aPrice - bPrice)
            bestKey = (priceDiff > 10) =>
                        ( (aPrice < bPrice) => keyA | keyB ) |
                        ( (aDistance < bDistance) => keyA | keyB )
            bestKey
        }

        orderColor = "#555555"

    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:orders := {}
            ent:address := "None given"
        }
    }

    rule set_shop_address {
        select when shop set_address
        pre {
            address = event:attr("address")
        }
        always {
            ent:address := address
        }
    }

    // shop:order_ready_for_driver_assgmt occurs when the shop is ready to pick a driver to fulfill the order
    // This rule fulfills the order
    // sends event flower_delivery_gossip driverAssigned at end
    rule drivers_all_have_bid {
        select when shop order_ready_for_driver_assgmt
        pre {
            orderID = event:attr("orderID")
            orders = gossip:orders()
            order = orders{orderID}
            bids = order{"driver_bids"}
            
        }
        if bids != {} then
            noop()
        fired {
            raise shop event "select_driver" attributes {
                "orderID": orderID,
                "bids": bids
            }
        }
    }

    rule select_driver {
        select when shop select_driver 
        pre{
            orderID = event:attr("orderID")
            bids = event:attr("bids")
            winning_driver = find_best_bid(bids)
            winning_bid = bids{winning_driver}
            order = ent:orders{orderID}
        }
        event:send(
            {
                "eci": order{"order_eci"},
                "eid": "1337",
                "domain": "order",
                "type": "driver_assigned",
                "attrs": {
                    "driverID": winning_driver,
                    "driver_wellknown": winning_bid{"wellKnown"}
                }
            }
        )
        always {
            raise flower_delivery_gossip event "driverAssigned" attributes {
                "orderID": orderID
            }
        }
    }

    // External event shop:new_order kicks off an order the shop now needs to complete
    // Finishes by sending flower_delivery_gossip addOrder
    rule prepareOrder {
        select when shop new_order
        pre {
            orderID = random:uuid()
            rids = "flower_delivery_order"
            customer = event:attr("customer_wellKnown")
        }
        always {
            ent:orders{orderID} := {"order_eci": null, "customer_wellknown": customer}
            raise wrangler event "child_creation"
                attributes { 
                    "name": orderID, 
                    "color": orderColor,
                    "rids": rids 
                }
            
        }
    }

    rule orderCreated {
        select when wrangler child_initialized
        pre {
            orderID = event:attr("name")
            eci = event:attr("eci")
        }
        event:send(
            {
                "eci": eci,
                "eid": "1337",
                "domain": "order",
                "type": "set_customer",
                "attrs": {
                    "wellknown": orderID
                }
            }
        )
        fired {
            ent:orders{orderID} := ent:orders{orderID}.put("order_eci", eci)

            raise flower_delivery_gossip event "addOrder" attributes 
            {
                "orderID":orderID   
            }
        }
    }

    // shop:gossip_orders is a periodically raised event that handles checking if a driver is ready to be selected and gossips
    // yet to be disseminated orders into the driver network

    // Reason for commenting out: Appears to be handled in gossip ruleset
    // // This rule checks if of the known orders do any of them have enough drivers to select one to handle the order
    // rule isOrderReadyForBid {
    //     select when shop gossip_orders
    // }

    // Reason for commenting out: Appears to be handled in gossip ruleset
    // // This rule sends out orders that have not received drivers 
    // rule gossipOrdersWithoutDrivers {
    //     select when shop gossip_orders
    // }

    // Child order picos send order complete to parent flower shop when they have completed an order
    rule orderComplete {
        select when order complete
        pre {
            orderID = event:attr("orderID")
        }

        always {
            ent:orders := ent:orders.remove(orderID)
            raise wrangler event "child_deletion"
                attributes {"name": orderID};
        }
    }

}
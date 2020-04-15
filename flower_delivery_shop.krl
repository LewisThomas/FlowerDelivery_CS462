ruleset flower_delivery_shop {
    meta {
        shares __testing

        use module google_directions_api alias directions
            with api_key = keys:google_directions_api{"api_key"}
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

        orderColor = "#555555"

    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:orders := {}
            ent:address := ""
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
                    "wellknown": name
                }
            }
        )
        fired {
            ent:orders{orderID} := ent:orders{orderID}.put("order_eci", eci)

            raise flower_delivery_gossip event "addOrder" attributes 
            {
                "orderID":event:attr("orderID")    
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
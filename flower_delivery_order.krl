ruleset flower_delivery_order {

    meta {
        shares isDriver
        provides isDriver
        use module keys
        use module twilio with 
            account_sid = keys:twilio{"account_sid"}
            auth_token =  keys:twilio{"auth_token"}
    }

    global {

        //Customer can query to see if a driver has been assigned
        isDriver = function() {
            ent:hasDriver
        }
    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        pre {
            customerWellknown = event:attr("customerWellknown")
            orderID = event:attr("orderID")
        }
        always {
            ent:driver_wellknown := ""
            ent:driver_assigned := false
            ent:orderID := orderID
            raise wrangler event "subscription" attributes {
                "wellKnown_Tx": customerWellknown,
                "Rx_role":"flower_order",
                "Tx_role":"flower_customer"
            }
        }
    }

    //this is probably a good place for the introduction to the driver
    rule driver_assigned {
        select when order driver_assigned
        pre {
            driverID = event:attr("driverID")
            driver_wellknown = event:attr("driver_wellknown")
        }
        always {
            ent:driver_wellknown := driver_wellknown
            ent:driver_assigned := true

            raise wrangler event "subscription"
                attributes
                { 
                    "Rx_role": "order",
                    "Tx_role": "driver",
                    "channel_type": "subscription",
                    "wellKnown_Tx": driver_wellknown
                } 
        }
    }

    rule driver_subscribed {
        select when wrangler subscription_added Tx_role re#driver#
        event:send(
            {
                "eci": ent:customer_tx,
                "eid": "1337",
                "domain": "customer",
                "type": "send_message",
                "attrs": {
                    "message": "Your driver has been found!"
                }
            }
        )

    }

    rule delivery_arrived {
        select when order delivery_arrived
        event:send(
            {
                "eci": ent:customer_tx,
                "eid": "1337",
                "domain": "customer",
                "type": "send_message",
                "attrs": {
                    "message": "Your order has arrived!"
                }
            }
        )
        always {
            raise order event notify_shop attributes {
                "orderID": ent:orderID
            }
        }

    }

    rule notify_shop {
        select when order notify_shop
        event:send(
            {
                "eci": wrangler:parent_eci(),
                "eid": "1337",
                "domain": "order",
                "type": "complete",
                "attrs": {
                    "orderID":event:attr("orderID")
                }
            }
        )
    }

}
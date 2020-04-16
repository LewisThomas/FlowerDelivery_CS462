ruleset flower_delivery_order {

    meta {
        shares isDriver
        provides isDriver

    }

    global {

        //Customer can query to see if a driver has been assigned
        isDriver = function() {
            ent:hasDriver
        }
    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:customer_wellknown := ""
            ent:driver_wellknown := ""
            ent:driver_assigned := false
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

    }

    rule customer_subscribe {
        select when order set_customer
        pre {
            customer_wellknown = event:attr("wellknown")
        }
        always {
            ent:customer_wellknown := customer_wellknown
        }
    }
}
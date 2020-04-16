ruleset flower_delivery_order {

    meta {
        shares isDriver
        provides isDriver

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
        }
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
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
            ent:hasDriver := false
        }
    }
}
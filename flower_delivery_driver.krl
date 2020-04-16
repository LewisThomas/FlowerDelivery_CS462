ruleset flower_delivery_driver {
    meta {
        shares __testing
        use module io.picolabs.wrangler alias wrangler
    }
    global {
        
        __testing = { "queries": [ 
            { "name": "__testing" },
            // {"name":"orders"},
            // {"name":"generateSeen"},
            // {"name":"others_seen"},
            // {"name":"getLastMessage"},
            // {
            //   "name":"getCount"
            // }
            ],
            "events": [ {
                          "domain":"driver",
                          "type":"debugAddBid",
                          "attrs":["orderID", "bid", "location"]
                        },
                        // {
                        //   "domain":"flower_delivery_gossip",
                        //   "type":"heartbeat"
                        // },
                        // {
                        //   "domain":"flower_delivery_gossip",
                        //   "type":"addDebugOrder"
                        // },
                        //{
                          //"eci":destination_eci.klog("DESTINATION ECI"),
                          //"eid":"gossipin'",
                          //"domain":"gossip",
                          //"type":message_type,
                          //"attrs": {
                          //  "message":actualMessage.klog("ACTUAL MESSAGE IS: "),
                          //  "this_pico_id":meta:picoId
                          //}
                        //}
                        ] }
    }
    rule addBid {
        select when flower_delivery_gossip new_order_seen 
        pre {

        }
    }

    rule debugAddBid {
        select when driver debugAddBid
        pre {
            targetOrderID = event:attr("orderID")
            bid = event:attr("bid")
            location = event:attr("location")
            driverID = wrangler:myself(){"id"}
        }
        always {
            raise flower_delivery_gossip event "addBid" attributes event:attrs
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        }
      }
}
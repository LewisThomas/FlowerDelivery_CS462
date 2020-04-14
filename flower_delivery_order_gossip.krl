ruleset flower_delivery_order_gossip {
    global {
       /**
       
       ent:orders := {
           <order ID> : "meta"
                        "driver_bids" : {
                                            <driver ID> : {<bid info>}
                                        }
       }
       
       */
       
       /**
       
       flower_delivery_gossip:seen_msg
       attrs {
           seen_orders: [{"orderID": <orderID>, "numDrivers":<numDrivers>}, . . .]
       }
       
       */
    }

    rule gossip {
        select when flower_delivery_gossip seen_msg
        pre {
            seen_orders = event:attr("seen_orders")

        }
    }

    rule send_order {
        select when flower_delivery_gossip send_order_info
    }
}
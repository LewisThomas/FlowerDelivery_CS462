ruleset flower_delivery_order_gossip {
    meta {
        use module io.picolabs.subscription alias subscription
    }
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
        symdiff = function (A,B) {
            (A.union(B)).difference(A.intersection(B));
        }

       ordersHaveDifferingDrivers = function(otherOrder, ourOrder) {
           ourOrderDriverIDs = ourOrder{"driver_bids"}.keys();
           otherOrderDriversIDs = otherOrder{"driver_bids"}.keys();
           symdiff(ourOrderDriverIDs, otherOrderDriversIDs).length() > 0
       }

       getOrdersNotSeen = function(othersSeenOrders) {
            ent:orders.filter(function(order, orderID) {
                othersSeenOrder = othersSeenOrders{orderID};
                otherSeenOrder => 
                    ordersHaveDifferingDrivers(othersSeenOrder, order) | false 
                
            })
       }

       getSeenOrders = function() {
        []
       }
    }

    rule gossip {
        select when flower_delivery_gossip seen_msg
        pre {
            seen_orders = event:attr("seen_orders");
            orders = getOrdersNotSeen(seen_orders);
            targetSub = subscription:established().filter(function(sub){
                sub{"Rx"} == meta:eci
              }).head()
        }
        always {
            raise wrangler event "send_event_on_subs" attributes {
                "domain":"flower_delivery_gossip",
                "type":"orders_rumor",
                "subID":targetSub{"Id"},
                "attrs": {
                    "seen_orders": orders
                }
            }
        }
    }

    rule receive_orders {
        select when flower_delivery_gossip orders_rumor
        pre {
            possibleNewOrders = event:attr("seen_orders")
        }
        if possibleNewOrders then
        noop()
        fired {
            ent:orders := ent:orders.map(function(order, orderID) {
                newOrder = possibleNewOrders{"orderID"};
                newOrder => 
                order.set(["driver_bids"], order{"driver_bids"}.put(possibleNewOrders)) | order;
            })
        }
    }

    rule gossip_heartbeat {
        select when flower_delivery_gossip heartbeat
        pre {
            seenOrders = getSeenOrders();
            peers = subscription:established().filter(function(sub) {
                sub{"Rx_role"} == "flower_delivery_gossiper"
            });
            numPeers = peers.length()
            peerToSendOrderToIndex = ent:peerClock.defaultsTo(0) % numPeers;
            peerToSendOrderTo = peers[peerToSendOrderToIndex];
        }
        always {
            raise wrangler event "send_event_on_subs" attributes {
                "domain":"",
                "type":"",
                "attrs":""
            }
        }
    }

    rule send_order {
        select when flower_delivery_gossip send_order_info
    }
}
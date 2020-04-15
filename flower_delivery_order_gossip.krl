/**

API:

    Purpose: Function that other rulesets on this pico can call to find out what orders have been gossiped and their respective
             driver bids
    orders()

    Purpose: Add a peer to the gossip network, assuming that peer has this ruleset installed
    flower_delivery_gossip:addPeer
    attrs {
        "wellKnown" // The ID of the wellknown of the peer you want to add
    }

    Purpose: Raised by the shop ruleset to add an order that needs delivery bids to the gossip network
    flower_delivery_gossip:addOrder
    attrs {
        "metaInfo" (Map), A map containing any extra meta info the flower shop wants to include in the order info
    }

    Purpose: Raised by the driver ruleset to add a bid to a target order. Once a bid is made it cannot be changed
    flower_delivery_gossip:addBid
    attrs {
        "orderID" ID of the order to add the bid to
        "bid" (number) The amount the delivery driver is willing to do it for
        "location" The location the driver is in, can be anything
    }

    Purpose: Raised by this ruleset for the shop ruleset to select on, informing the shop ruleset an order is ready
             for a driver to be selected for it. Note that by default this is checking to see if there are at least
             3 bids on an order, and if there are, that is when it raises the event. See getOrdersReadyToBeAssignedToDriver function
             in the code below for the exact criteria used.
    flower_delivery_gossip:order_ready_for_driver_assgmt
    attrs {
        "orderID" // the ID of the order the shop needs to assign a driver to
    }

    Purpose: raised by the shop ruleset after being notified with order_ready_for_driver_assgmt to mark the order
             as having been assigned a driver, so the shop ruleset is not continually notified of needing driver assignment
    flower_delivery_gossip:driverAssigned
    attrs {
        "orderID" // the ID of the order the shop has now assigned a driver to
    }

    Purpose: Raised by this ruleset to notify the driver ruleset that the orders have just changed and the driver might need
             to make a bid on the new order if it hasn't
    flower_delivery_gossip:possible_bid_needed
    attrs {
        "orders" The same thing that is returned from the orders() function
    }


    ent:orders := {
        <order ID> : "meta": {
                                "driver_assigned": <boolean>
                                "flowerShopID": <ID of order-broadcasting shop>
                            }
                    "driver_bids" : {
                                        <driver ID> : {<bid info>}
                                    }
    }



*/
ruleset flower_delivery_order_gossip {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        shares orders, __testing
        provides orders
    }
    global {
        __testing = { "queries": [ 
            { "name": "__testing" },
            {"name":"orders"},
            // {"name":"generateSeen"},
            // {"name":"others_seen"},
            // {"name":"getLastMessage"},
            // {
            //   "name":"getCount"
            // }
            ],
            "events": [ {
                          "domain":"flower_delivery_gossip",
                          "type":"addPeer",
                          "attrs":["wellKnown"]
                        },
                        // {
                        //   "domain":"flower_delivery_gossip",
                        //   "type":"heartbeat"
                        // },
                        {
                          "domain":"flower_delivery_gossip",
                          "type":"addDebugOrder"
                        },
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

       /**
       
       ent:orders := {
           <order ID> : "meta": {
                                    ""
                                }
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
            ent:orders.klog("starting with this ent:orders").filter(function(order, orderID) {
                othersSeenOrder = othersSeenOrders{orderID};
                otherSeenOrder => 
                    ordersHaveDifferingDrivers(othersSeenOrder, order) | true
                
            })
       }

       getSeenOrders = function() {
           ent:orders.defaultsTo({})
       }

       orders = function() {
           ent:orders.defaultsTo({})
       }

       heartbeat_interval = 2
       driverBidsNeededForOrderSelection = 3
       getOrdersReadyToBeAssignedDriver = function(orders) {
           orders.filter(function(order, orderID) {
               (not order{["meta", "driver_assigned"]}) && 
               order{["meta", "flowerShopID"]} == wrangler:myself(){"id"} &&
               order{["driver_bids"]}.length() >= driverBidsNeededForOrderSelection
           })
       }
    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:orders := {}
            ent:peerClock := 0
            raise flower_delivery_gossip event "heartbeat" attributes event:attrs// kickoff heartbeat
        }
    }

    rule respond_to_seen {
        select when flower_delivery_gossip seen_msg
        pre {
            seen_orders = event:attr("seen_orders").klog("received these seen orders");
            orders = getOrdersNotSeen(seen_orders).klog("calculated these orders differ");
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
            possibleNewOrdersIDs = possibleNewOrders.keys()
            orderIDs = ent:orders.keys()
            unseenOrderIDs = possibleNewOrdersIDs.difference(orderIDs)
            unseenOrders = possibleNewOrders.filter(function(order, orderID) {
                unseenOrderIDs.any(function(newOrderID) {orderID == newOrderID})
            })
            
        }
        if possibleNewOrders then
        noop()
        fired {
            ent:orders := ent:orders.map(function(order, orderID) {
                newOrder = possibleNewOrders{orderID};
                newOrder => 
                order.set(["driver_bids"], order{"driver_bids"}.put(newOrder{"driver_bids"})) | order;
            })
            ent:orders := ent:orders.put(unseenOrders)
            raise flower_delivery_gossip event "possible_bid_needed" attributes {
                "orders":ent:orders
            }
            
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
            peerToSendOrderToIndex = ent:peerClock.defaultsTo(0) % (numPeers <= 0 => 1 | numPeers); // check for divide by 0 if no peers
            peerToSendOrderTo = peers[peerToSendOrderToIndex];
        }
        if numPeers > 0 then
        noop()
        fired {
            raise wrangler event "send_event_on_subs" attributes {
                "domain":"flower_delivery_gossip",
                "type":"seen_msg",
                "subID":peerToSendOrderTo{"Id"},
                "attrs":{
                    "seen_orders":seenOrders
                }
            }
            ent:peerClock := ent:peerClock.defaultsTo(0) + 1
            
        } finally {
            schedule flower_delivery_gossip event "heartbeat" at time:add(time:now(), {"seconds": heartbeat_interval})
        }
    }

    rule addGossipPeer {
        select when flower_delivery_gossip addPeer
        pre {
            wellKnown = event:attr("wellKnown")
        }
        always {
            raise wrangler event "subscription" attributes {
                "wellKnown_Tx":wellKnown,
                "Rx_role":"flower_delivery_gossiper",
                "Tx_role":"flower_delivery_gossiper",
            }
        }
    }

    rule accept_peer_sub {
        select when wrangler inbound_pending_subscription_added 
        always {
            raise wrangler event "pending_subscription_approval" attributes event:attrs
        }
    }


    // 
    rule addOrder {
        select when flower_delivery_gossip addDebugOrder // DEBUG
                or flower_delivery_gossip addOrder
        pre {
            orderID = random:uuid()
            flowerShopID = wrangler:myself(){"id"}
            flowerShopMetaInfo = event:attr("metaInfo") || {}

            order = {"meta":{
                            "flowerShopID":flowerShopID
                            }.put(flowerShopMetaInfo),
                    "driver_bids":{}}
        }
        always {
            ent:orders{orderID} := order
        }
    }

    rule addBid {
        select when flower_delivery_gossip addBid
        pre {
            targetOrderID = event:attr("orderID")
            bid = event:attr("bid")
            location = event:attr("location")
            driverID = wrangler:myself(){"id"}
            bidMap = {
                "bidAmount":bid, 
                "location":location || "None given",
                "wellKnown":subscription:wellKnown_Rx(){"id"}
            }
        }
        if ent:orders{targetOrderID} then
        noop()
        fired {
            ent:orders{[targetOrderID, "driver_bids", driverID]} := bidMap
        } else {
            error info "target order to bid on did not exist!"
        }
    }

    rule readyToSelectDriverCheck {
        select when flower_delivery_gossip heartbeat
        pre {
            ordersReady = getOrdersReadyToBeAssignedDriver(orders())
            ordersReadyIDs = ordersReady.keys()
        }
        if ordersReadyIDs.length() > 0 then
            noop()
        fired {
            raise flower_delivery_gossip event "notify_flowershop" attributes {
                "orders":ordersReadyIDs
            }
        }
    }

    rule notifyFlowerShopOrdersToBeAssigned {
        select when flower_delivery_gossip notify_flowershop
        foreach event:attr("orders") setting (orderID, i)
        always {
            raise shop event "order_ready_for_driver_assgmt" attributes event:attrs.put({
                "orderID":orderID
            })
        }
    }

    rule flowerShopAssignedDriver {
        select when flower_delivery_gossip driverAssigned
        pre {
            orderID = event:attr("orderID")
        }
        always {
            ent:orders{[orderID, "meta", "driver_assigned"]} := true
        }
    }

    // rule send_order {
    //     select when flower_delivery_gossip send_order_info
    // }
}
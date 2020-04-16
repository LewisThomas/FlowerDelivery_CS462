ruleset flower_delivery_customer {
    meta {
        shares __testing

        use module keys
        use module twilio with 
            account_sid = keys:twilio{"account_sid"}
            auth_token =  keys:twilio{"auth_token"}
    }
    
    global {
        

        __testing = { "queries": [
        ],
        "events": [
            {
                "domain":"customer",
                "type":"set_phone_number",
                "attrs":["phone_number"]
            }
        ]}
    }

    rule onInstallation {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:phone_number := "+19714019503"
        }
    }

    rule send_message {
        select when customer send_message
        pre {
            message = event:attr{"message"}
        }
        twilio:send_sms(phone_number,
            "+12029911769",
            message)
    }

    rule acceptOrderPeer {
        select when wrangler inbound_pending_subscription_added 
        always {
            raise wrangler event "pending_subscription_approval" attributes event:attrs
        }
    }
}

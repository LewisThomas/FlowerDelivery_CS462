 
ruleset twilio {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms, messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    messages = function(to, from) {
        base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
        url =   (to == null && from == null) => base_url + "Messages.json?Page=0" |
                (to != null && from == null) => base_url + "Messages.json?To=" + to + "&Page=0"|
                (to == null && from != null) => base_url + "Messages.json?From=" + from + "&Page=0" |
                                            base_url + "Messages.json?To=" + to + "&From=" + from + "&Page=0" 
        response = http:get(url)
    
    
        response{"content"}.decode().klog("message log: ");
        }
  }
}
ruleset google_directions_api {
    meta {
        configure using api_key = ""
        provides get_distance
      }

    global {
        get_distance = function(to, from) {
            (to == "None given") => 86400 | 
            (from == "None given") => 86400 |
                distance(format_address(to), format_address(from))
        }

        distance = function(driver, shop) {
            base_url = <<https://maps.googleapis.com/maps/api/directions/json?origin=#{driver}&destination=#{shop}&key=#{google_key}>>
            response = http:get(base_url)
            json = response{"content"}.decode()
            steps = json{["routes","legs"]}[0]{"steps"}

            steps.reduce(function(a,b) {
                a{["duration","value"]} + b{["duration","value"]}
            })
        }

        format_address = function(address) {
            address.replace(re# #g, "+")
        }
    }
}
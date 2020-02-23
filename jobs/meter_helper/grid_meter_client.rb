
def find_current_grid_kwh(uuid, data)
 current_grid_watts = 0
 data.each do |value|
   if value['uuid'] == uuid
     current_grid_watts = value['tuples'][0].last()
     break
   end
 end
 return current_grid_watts
end


def calculate_sum_of_watts(data_url_to_fetch_from)
  response_with_data = HTTParty.get(data_url_to_fetch_from)
  array = response_with_data.parsed_response['val']
  last_day_sum = 0
  array.each { |a|
    last_day_sum += a.to_i
  }
  return (last_day_sum.to_f/1000).round(1)
end

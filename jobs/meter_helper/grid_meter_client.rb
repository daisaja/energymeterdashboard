
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

def is_new_day()
  now = Time.now
  midnight = Time.new(now.year, now.month, now.day)
  _600s_after_midnight = midnight + 600 # Time window 600s
  if now > midnight and now < _600s_after_midnight
    return true
  else
    return false
  end
end

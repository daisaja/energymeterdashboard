
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

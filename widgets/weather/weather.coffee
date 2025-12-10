class Dashing.Weather extends Dashing.Widget

  onData: (data) ->
    @setBackgroundClassBy parseInt(data.current, 10)

  setBackgroundClassBy: (temperature) ->
    @removeBackgroundClass()
    colorLevel = @findColorLevelBy temperature
    $(@node).addClass "weather-temperature-#{colorLevel}"

  removeBackgroundClass: ->
    classNames = $(@node).attr("class").split " "
    for className in classNames
      match = /weather-temperature-(.*)/.exec className
      $(@node).removeClass match[0] if match

  findColorLevelBy: (temperature) ->
    switch
      when temperature <= 0 then 0
      when temperature in [1..5] then 1
      when temperature in [6..10] then 2
      when temperature in [11..15] then 3
      when temperature in [16..20] then 4
      when temperature in [21..25] then 5
      when temperature > 25 then 6

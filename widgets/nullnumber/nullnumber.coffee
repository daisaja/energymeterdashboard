# Number-Widget, das unbekannte Werte (null/undefined) als "–" anzeigt statt als
# leeren Wert, 0 oder "NaN%". Echte Zahlen werden wie im Number-Widget angezeigt.
class Dashing.Nullnumber extends Dashing.Number
  @accessor 'displayValue', ->
    current = @get('current')
    if current? then Batman.Filters.shortenedNumber(current) else '–'

  @accessor 'difference', ->
    return '' unless @get('current')? and @get('last')?
    last = parseInt(@get('last'))
    current = parseInt(@get('current'))
    if last != 0
      diff = Math.abs(Math.round((current - last) / last * 100))
      "#{diff}%"
    else
      ''

  @accessor 'arrow', ->
    return '' unless @get('current')? and @get('last')?
    if parseInt(@get('current')) > parseInt(@get('last')) then 'fa fa-arrow-up' else 'fa fa-arrow-down'

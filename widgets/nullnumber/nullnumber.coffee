# Number-Widget, das unbekannte Werte (null/undefined) als "–" anzeigt statt als
# leeren Wert, 0 oder "NaN%". Echte Zahlen werden wie im Number-Widget angezeigt.
# Erbt bewusst direkt von Dashing.Widget (nicht von Dashing.Number): Widgets werden
# alphabetisch geladen, "nullnumber" also vor "number" – siehe test/widgets_test.rb.
class Dashing.Nullnumber extends Dashing.Widget
  @accessor 'current', Dashing.AnimatedValue

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

  onData: (data) ->
    if data.status
      # clear existing "status-*" classes
      $(@get('node')).attr 'class', (i,c) ->
        c.replace /\bstatus-\S+/g, ''
      # add new class
      $(@get('node')).addClass "status-#{data.status}"

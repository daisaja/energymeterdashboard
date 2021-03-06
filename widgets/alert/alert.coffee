class Dashing.Alert extends Dashing.Widget

  ready: ->
    # This is fired when the widget is done being rendered

  onData: (data) ->
    # Handle incoming data
    # You can access the html node of this widget with `@node`
    # Example: $(@node).fadeOut().fadeIn() will make the node flash each time data comes in.

# custom function
  @accessor 'isTooHigh', ->
    @get('value') > 300

  @accessor 'isTooLow', ->
    @get('value') < 100

  @accessor 'value', Dashing.AnimatedValue

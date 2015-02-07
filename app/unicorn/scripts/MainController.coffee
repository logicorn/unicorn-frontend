###
(events: Stream touchMoveEvent) -> Stream {
  from: { x, y }
  to: { x, y }
  target: { width, height }
  vector: { x, y }
  magnitude: { x, y }
}
###
touchMoveEventsToContinuousDrag = (events) ->
  events
    .filter((event) -> event.changedTouches?[0]?)
    .map((event) -> event.changedTouches[0])
    .map((touch) ->
      coords: { x: touch.clientX, y: touch.clientY }
      target: { height: touch.target.clientHeight, width: touch.target.clientWidth }
    )
    .scan({ from: null, to: null, target: null }, (acc, {coords, target}) ->
      {
        from: acc.from ? coords
        target: acc.target ? target
        to: coords
      }
    ).changes().map((drag) ->
      drag.vector =
        x: drag.to.x - drag.from.x
        y: drag.to.y - drag.from.y
      drag.magnitude =
        x: drag.vector.x / drag.target.width
        y: drag.vector.y / drag.target.height
      drag
    )

angular.module('unicorn')
  .controller('MainController', ($scope, crane) ->
    $scope.connected = false
    $scope.connect = ->
      supersonic.device.vibrate()
      crane.connect().then ->
        supersonic.device.vibrate()
        $scope.$apply ->
          $scope.connected = true

    $scope.touch = ->
      return ->
        crane.setSpeed(0, 0)

    $scope.engageLeftControl = (events) ->
      stopCraneControl = touchMoveEventsToContinuousDrag(events)
        .map((drag) -> drag.magnitude)
        .onValue (magnitudeVector) ->
          crane.setSpeed 0, (magnitudeVector.x * 255), (magnitudeVector.y * 255)
      
      ->
        stopCraneControl?()
        crane.resetSpeed()

    $scope.engageRightControl = (events) ->
      stopCraneControl = touchMoveEventsToContinuousDrag(events)
        .map((drag) -> drag.magnitude)
        .onValue (magnitudeVector) ->
          crane.setSpeed (magnitudeVector.y * 255), 0, 0
      
      ->
        stopCraneControl?()
        crane.resetSpeed()


    $scope.hertta = ->
      supersonic.logger.log "pressing hertta"
      return ->
        supersonic.logger.log "stopped"

  )
  .service('crane', ->
    backend = "192.168.240.86"
    socket = io("http://#{backend}:80")

    {
      connect: ->
        new Promise (resolve) ->
          supersonic.logger.log "connecting..."
          socket.on 'connected', (data) ->
            supersonic.logger.log "Successful handshake!"
            resolve()
          socket.emit 'hello', { hello: true }

      resetSpeed: ->
        socket.emit 'speed', {
          a: 0
          e: 0
          h: 0
        }

      setSpeed: do ->
        curtail = (v) -> ~~Math.max(-255, Math.min(255, v))
        (hoistSpeed, trolleySpeed, bridgeSpeed) ->
          socket.emit 'speed', {
            a: curtail hoistSpeed
            e: curtail trolleySpeed
            h: curtail bridgeSpeed
          }

      stop: ->
        socket.emit 'stop'
    }
  )
  .directive('onTouch', ->
    restrict: 'A'
    link: (scope, element, attr) ->
      element.on 'touchstart', (event) ->
        onTouchEnd = null
        element.one 'touchend', (event) ->
          onTouchEnd?()
        scope.$apply ->
          onTouchEnd = scope.$eval attr.onTouch
  )
  .directive('onDrag', ->
    restrict: 'A'
    link: (scope, element, attr) ->
      element.on 'touchstart', (event) ->
        events = new Bacon.Bus
        onTouchEnd = scope.$eval attr.onDrag, { events }

        onTouchMove = (event) ->
          events.push event
        element.on 'touchmove', onTouchMove
        element.one 'touchend', ->
          element.off 'touchmove', onTouchMove
          events.push new Bacon.End
          onTouchEnd?()
  )
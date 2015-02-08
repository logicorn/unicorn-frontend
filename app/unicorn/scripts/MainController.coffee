BACKEND_IP = "192.168.1.74"
Bacon = supersonic.internal.Bacon

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
    $scope.lockOrientation = null
    $scope.rotation = 0

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
          rotation = ($scope.rotation / 180) * Math.PI
          x = (magnitudeVector.x * 255)
          y = (magnitudeVector.y * 255)
          correctedX = (x * Math.cos rotation) - (y * Math.sin rotation)
          correctedY = (x * Math.sin rotation) + (y * Math.cos rotation)
          $scope.correctedX = correctedX
          $scope.correctedY = correctedY
          crane.setSpeed 0, correctedX, correctedY
      
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


    lockOrientation = new Bacon.Bus
    $scope.$watch 'lockOrientation', (locked) ->
      lockOrientation.push locked

    lockOrientation
      .flatMapLatest((locked) ->
        if !locked
          Bacon.once 0
        else
          supersonic.device.compass.watchHeading()
            .scan({ startHeading: null, currentHeading: null }, (acc, heading) ->
              {
                startHeading: acc.startHeading ? heading.magneticHeading
                currentHeading: heading.magneticHeading
              }
            )
            .changes()
            .map((correction) ->
              supersonic.logger.log correction
              correction.currentHeading - correction.startHeading
            )
      )
      .delay(0)
      .onValue (rotation) ->
        supersonic.logger.log "applying rotation #{rotation}"
        $scope.$apply ->
          $scope.rotation = rotation

  )
  .service('crane', ->
    socket = io("http://#{BACKEND_IP}:80")

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
          # Flip bridge axis direction
          bridgeSpeed = -bridgeSpeed
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
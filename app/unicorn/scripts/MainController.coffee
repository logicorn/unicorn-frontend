angular.module('unicorn')
  .controller('MainController', ($scope, crane) ->
    $scope.connected = false
    $scope.connect = ->
      supersonic.device.vibrate()
      crane.connect().then ->
        supersonic.device.vibrate()
        $scope.$apply ->
          $scope.connected = true

    $scope.move = (trolleySpeed, bridgeSpeed) ->
      supersonic.logger.log trolleySpeed, bridgeSpeed
      crane.move(trolleySpeed, bridgeSpeed)
      return ->
        crane.move(0, 0)

    $scope.startCraneControl = (events) ->
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
        .onValue (v) ->
          console.log v


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

      move: (trolleySpeed, bridgeSpeed) ->
        socket.emit 'speed', {
          a: 0
          e: trolleySpeed
          h: bridgeSpeed
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
        scope.$eval attr.onDrag, { events }

        onTouchMove = (event) ->
          events.push event
        element.on 'touchmove', onTouchMove
        element.one 'touchend', ->
          element.off 'touchmove', onTouchMove
          events.push new Bacon.End
  )
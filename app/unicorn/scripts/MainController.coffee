angular.module('unicorn')
  .controller('MainController', ($scope, crane) ->
    $scope.connected = false
    $scope.connect = ->
      supersonic.device.vibrate()
      crane.connect().then ->
        supersonic.device.vibrate()
        $scope.$apply ->
          $scope.connected = true

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
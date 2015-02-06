angular.module('unicorn')
  .controller('MainController', ($scope) ->
    $scope.hertta = ->
      supersonic.logger.log "pressing hertta"
      return ->
        supersonic.logger.log "stopped"
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
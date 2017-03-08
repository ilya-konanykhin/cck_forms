class window.CckFormsMap
  @addMap: (map) ->
    @allMapsList ||= []
    @allMapsList.push map
  @allMaps: ->
    @allMapsList || []
  @switchMapTo: (mapType)->
  @map: (type, element, initialPoint, fields, options = {})->
    options['groupId'] = element.data('id')

    switch type
      when "yandex" then new CckFormsMap.YandexMap(element, initialPoint, fields, options)
      when "google" then new CckFormsMap.GoogleMap(element, initialPoint, fields, options)
      else
        throw "Invalid map type: #{type}"

class CckFormsMap.AbstractMap
  type: ->
  constructor: (htmlElement, @initialCoordinate, @fields, options = {})->
    @htmlElement = $(htmlElement)
    @readOnlyMap = options.readOnly
    @groupId     = options.groupId

    CckFormsMap.addMap @
    @._render()
  movePointTo: (somewhere)->
  hide: ->
    @htmlElement.hide()
  show: ->
    @htmlElement.show()
    CckFormsMap.currentMap = @

  setCenter: (latitudeAndLongitude)->
  setZoom: (zoom)->
    @internalMapAPI.setZoom zoom
  setMarkerToPoint: (latitudeAndLongitude) ->

  setCenterByGeocode: (geocode) ->

    options = {
      url:      'https://geocode-maps.yandex.ru/1.x/'
      dataType: 'json'
      data:     {format: 'json', geocode: geocode, results: 1}
    }

    xhr = $.ajax options
    xhr.done (data) =>
      if data.response.GeoObjectCollection.featureMember[0]
        point  = data.response.GeoObjectCollection.featureMember[0].GeoObject.Point.pos.split ' '
        latlon = {latitude: point[1], longitude: point[0]}

        @fields.latitude.val point[1]
        @fields.longitude.val point[0]

        @.setMarkerToPoint latlon
        @.setCenter latlon
        @.setZoom 17 # adjusted by experiment for better view

    xhr.fail ->
      alert "Server error encountered"


  refresh: ->

  _render: ->

  _anotherMaps: ->
    maps = []
    _self = @
    $.each CckFormsMap.allMaps(), ->
      if @ != _self && @.groupId == _self.groupId
        maps.push @
    maps

class CckFormsMap.YandexMap extends CckFormsMap.AbstractMap
  type: -> "yandex"
  _render: ->
    ymaps.ready =>
      coords = [@initialCoordinate.longitude, @initialCoordinate.latitude]
      @internalMapAPI = new ymaps.Map(@htmlElement[0],
        center: coords
        zoom: @initialCoordinate.zoom
        type: "yandex#map"
      , {})
      @internalMapAPI.controls.add "zoomControl"
      @yandexMapPlacemark = new ymaps.Placemark(coords,
        iconContent: ""
      ,
        preset: "twirl#blueStretchyIcon"
      )
      @internalMapAPI.geoObjects.add @yandexMapPlacemark

      @internalMapAPI.events.add "click", (e) =>
        return if @readOnlyMap
        coords = e.get("coordPosition")
        @fields.latitude.val coords[1]
        @fields.longitude.val coords[0]
        @fields.zoom.val @internalMapAPI.getZoom()
        @yandexMapPlacemark.geometry.setCoordinates coords

        $.each @._anotherMaps(), ->
          @.setMarkerToPoint latitude: coords[1], longitude: coords[0]

      @internalMapAPI.events.add "boundschange", (e) =>
        newZoom = e.get("newZoom")
        zoomChanged = e.get("oldZoom") != newZoom

        newCenter = e.get("newCenter")
        centerChanged = e.get("oldCenter") != newCenter

        zoom = @internalMapAPI.getZoom()
        @fields.zoom.val zoom

        $.each @._anotherMaps(), ->
          @.setZoom zoom if zoomChanged
          @.setCenter {latitude: newCenter[1], longitude: newCenter[0]} if centerChanged and not @ignoreCenterChange

  setMarkerToPoint: (latitudeAndLongitude) ->
    @yandexMapPlacemark?.geometry.setCoordinates [latitudeAndLongitude.longitude, latitudeAndLongitude.latitude]
  setCenter: (latitudeAndLongitude)->
    @ignoreCenterChange = true

    if @internalMapAPI
      @internalMapAPI.setCenter [latitudeAndLongitude.longitude, latitudeAndLongitude.latitude]
    else
      ymaps.ready => @internalMapAPI.setCenter [latitudeAndLongitude.longitude, latitudeAndLongitude.latitude]

    @ignoreCenterChange = false

  setZoom: (zoom)->
    if @internalMapAPI
      @internalMapAPI.setZoom zoom
    else
      ymaps.ready => @internalMapAPI.setZoom zoom

  refresh: ->
    if @internalMapAPI
      @internalMapAPI.container.fitToViewport()
    else
      ymaps.ready => @internalMapAPI.container.fitToViewport()


class CckFormsMap.GoogleMap extends CckFormsMap.AbstractMap
  type: -> "google"
  _render: ->
    latlng = new google.maps.LatLng(@initialCoordinate.latitude, @initialCoordinate.longitude)
    googleMapOptions =
      zoom: @initialCoordinate.zoom
      center: latlng
      mapTypeId: google.maps.MapTypeId.ROADMAP
      scrollwheel: false
      streetViewControl: false

    @internalMapAPI = new google.maps.Map(@htmlElement[0], googleMapOptions)

    @googleMapMarker = null
    createOrMoveMarker = (latLng)=>
      @fields.latitude.val latLng.lat()
      @fields.longitude.val latLng.lng()
      if @googleMapMarker
        @googleMapMarker.setPosition latLng
      else
        @._createMarker(latLng)
      googleMapPosition = @googleMapMarker.position
      $.each @._anotherMaps(), ->
        @.setMarkerToPoint latitude: googleMapPosition.lat(), longitude: googleMapPosition.lng()

    createOrMoveMarker latlng  if @fields.latitude.val() or @fields.longitude.val()
    @fields.zoom.val @internalMapAPI.getZoom()  if not @fields.zoom.val() or @fields.zoom.val() is 0
    google.maps.event.addListener @internalMapAPI, "click", (event) =>
      return if @readOnlyMap
      createOrMoveMarker event.latLng

    google.maps.event.addListener @internalMapAPI, "zoom_changed", =>
      zoom = @internalMapAPI.getZoom()
      @fields.zoom.val zoom
      $.each @._anotherMaps(), ->
        @.setZoom zoom
    google.maps.event.addListener @internalMapAPI, "center_changed", =>
      return if @ignoreCenterChange
      center = @internalMapAPI.getCenter()
      $.each @._anotherMaps(), ->
        @.setCenter latitude: center.lat(), longitude: center.lng()

  _createMarker: (latLng)->
    @googleMapMarker = new google.maps.Marker(
      position: latLng
      map: @internalMapAPI
    )

    #title: ''
    google.maps.event.addListener @googleMapMarker, "click", =>
      @googleMapMarker.setMap null
      @googleMapMarker = null
      @fields.latitude.val ""
      @fields.longitude.val ""

  setMarkerToPoint: (latitudeAndLongitude) ->
    @._createMarker(null)  unless @googleMapMarker
    @googleMapMarker.setPosition new google.maps.LatLng(latitudeAndLongitude.latitude, latitudeAndLongitude.longitude)


  setCenter: (latitudeAndLongitude)->
    @ignoreCenterChange = true
    @internalMapAPI.setCenter(new google.maps.LatLng(latitudeAndLongitude.latitude, latitudeAndLongitude.longitude))
    @ignoreCenterChange = false
  show: ->
    super()
    @.refresh()

  refresh: ->
    center = @internalMapAPI.getCenter() # keep the map center rock solid
    google.maps.event.trigger(@internalMapAPI, "resize")
    @internalMapAPI.setCenter(center)


switch_map = ($canvas, mapType) ->
  $.each $canvas.data('maps'), (i, map) ->
    map.show()
    if map.type() == mapType
      map.show()
      $canvas.find('#' + map.groupId + '_type').val mapType
    else
      map.hide()


window.init_map = (canvas) ->

  $canvas = $(canvas)
  $source = $canvas.find('[data-map-data-source]')
  options = $source.data("options")
  mapId   = $source.data("id")

  $lat   = $("#" + mapId + "_latitude")
  $lon   = $("#" + mapId + "_longitude")
  $zoom  = $("#" + mapId + "_zoom")

  fields = zoom: $zoom, latitude: $lat, longitude: $lon

  latLng = new google.maps.LatLng(options.latitude, options.longitude)
  zoom   = options.zoom


  if $lat.val() and $lon.val()
    latLng    = new google.maps.LatLng($lat.val(), $lon.val())
    hasLatLng = true

    if ($zoom.val()) > 0
      zoom    = $zoom.val() * 1
      hasZoom = true


  initialPoint = latitude: latLng.lat(), longitude: latLng.lng(), zoom: zoom
  readOnly     = !!$(@).data("readOnly")

  maps = {}
  $.each $source.data("allowedMaps"), (i, mapType) ->
    $map = $('#' + mapId + '_' + mapType)
    maps[mapType] = new CckFormsMap.map(mapType, $map, initialPoint, fields, readOnly: readOnly)

  $canvas.data('maps', maps)


  cityInputSelectorst = [
        '#' + $source.data("cityid"),
        '[data-behavior="map_city_change"]'
  ].join(', ')
  $cityInput = $(cityInputSelectorst)

  if $cityInput.data('mapCityValue')
    mapCityValue = $cityInput.data('mapCityValue')
    $cityInput   = $cityInput.find(mapCityValue)

  handleCityChange = =>
    cities = $source.data("cities")
    city   = cities[$cityInput.val()]

    if city
      latLng = new google.maps.LatLng(city.lat, city.lon) unless hasLatLng
      zoom   = city.zoom unless hasZoom

    $.each $canvas.data('maps'), (i, map) ->
      map.setCenter latitude: latLng.lat(), longitude: latLng.lng()
      map.setZoom zoom

  $cityInput.change handleCityChange
  handleCityChange() unless $lat.val() or $lon.val()

  activeMapType = $canvas
  .find('.cck-map-switchers a.active')
  .data("mapType")

  switch_map($canvas, activeMapType)


$ ->
  start = ->
    try

      $(document).on "click", ".cck-map-switchers a", (e) ->
        e.preventDefault()

        $(@).addClass("active")
          .siblings()
          .removeClass "active"

        mapType = $(@).data("mapType")
        $canvas = $(@).closest('.map-canvas')

        switch_map $canvas, mapType

      $.each $('.map-canvas'), (index, canvas) ->
        init_map canvas


    catch error
      window.console?.error error

  if window.mapsReady
    window.mapsReady.on start
  else
    start()

# Represents a map point in Google Maps or Yandex.Maps.
#
class CckForms::ParameterTypeClass::Map
  include CckForms::ParameterTypeClass::Base

  MAP_TYPE_GOOGLE = 'google'.freeze
  MAP_TYPE_YANDEX = 'yandex'.freeze
  DEFAULT_MAP_TYPE = Rails.application.config.cck_forms.maps.default_type || MAP_TYPE_GOOGLE

  mattr_accessor :map_providers
  @@map_providers = [MAP_TYPE_YANDEX, MAP_TYPE_GOOGLE]

  mattr_accessor :google_maps_api_key

  # In MongoDB: {latlon: [x, y], zoom: z}
  #
  # In application: {
  #   latitude: x,
  #   longitude: y,
  #   zoom: z
  # }
  def self.demongoize_value(value, _parameter_type_class=nil)
    value = value.to_h
    value.stringify_keys!
    latlon = value['latlon'] || []

    latitude = value['latitude'] || latlon[0]
    longitude = value['longitude'] || latlon[1]
    type_of_map = value['type'] || DEFAULT_MAP_TYPE

    {
        'latitude' => latitude,
        'longitude' => longitude,
        'zoom' => value['zoom'].presence,
        'type' => type_of_map
    }
  end


  # In application: {
  #   latitude: x,
  #   longitude: y,
  #   zoom: z
  # }
  #
  # In MongoDB: {latlon: [x, y], zoom: z}
  def mongoize
    value = self.value.is_a?(Hash) ? self.value : {}
    return {
        'latlon' => [value['latitude'].presence, value['longitude'].presence],
        'zoom' => value['zoom'].presence,
        'type' => value['type'].presence || DEFAULT_MAP_TYPE
    }
  end

  # Call #img_tag if :width & :height
  def to_s(options = {})
    options ||= {}
    if options[:width].to_i > 0 and options[:height].to_i > 0
      return a_tag(to_s(options.except :link), options[:link]) if options[:link]
      return img_tag options[:width], options[:height]
    end

    ''
  end

  # IMG tag of options[:with] X options[:height] size with a point on it in the current value position (unless value
  # is empty, of course).
  #
  # See Google/Yandex Maps Static API.
  def img_tag(width, height, options = {})
    map_type = value['type']

    if value['latitude'].present? and value['longitude'].present?
      if map_type == MAP_TYPE_GOOGLE
        zoom_if_any = value['zoom'].present? ? "&zoom=#{value['zoom']}" : nil
        marker_size_if_any = options[:marker_size] ? "|size:#{options[:marker_size]}" : nil

        url = %Q(
          http://maps.googleapis.com/maps/api/staticmap?
            language=ru&
            size=#{width}x#{height}&
            maptype=roadmap&
            markers=color:red#{marker_size_if_any}|
            #{value['latitude']},#{value['longitude']}&
            sensor=false
            #{zoom_if_any}
        ).gsub(/\s+/, '')

      else # yandex
        zoom_if_any = value['zoom'].present? ? "&z=#{value['zoom']}" : nil
        marker_size = options[:marker_size] == :large ? 'l' : 'm'

        url = %Q(
          http://static-maps.yandex.ru/1.x/?
            l=map&
            size=#{width},#{height}&
            pt=#{value['longitude']},#{value['latitude']},pm2bl#{marker_size}&
            #{zoom_if_any}
        ).gsub(/\s+/, '')
      end
      %Q(<img src="#{url}" width="#{width}" height="#{height}" />).html_safe
    else
      ''
    end
  end

  # <A> tag with a link to the Google/Yandex Maps with marker placed on the current value position
  def a_tag(content, attrs)
    if attrs[:href] = url
      attrs_strings = []
      attrs.each_pair { |name, value| attrs_strings << sprintf('%s="%s"', name, value) }
      sprintf '<a %s>%s</a>', attrs_strings.join, content
    else
      ''
    end
  end

  # Returns a URL to Google/Yandex Maps map with marker placed on the current value position
  def url
    if value['latitude'].present? and value['longitude'].present?
      if value['type'] == MAP_TYPE_GOOGLE
        sprintf(
          'http://maps.google.com/maps?%s&t=m&q=%s+%s',
          value['zoom'].present? ? 'z=' + value['zoom'] : '',
          value['latitude'],
          value['longitude']
        )
      else # yandex
        sprintf(
          'http://maps.yandex.ru/?l=map&text=%s&ll=%s%s',
          [value['latitude'], value['longitude']].join(','),
          [value['longitude'], value['latitude']].join(','),
          value['zoom'].present? ? '&z=' + value['zoom'] : nil
        )
      end
    end
  end

  # 3 hidden field: latitude, longitude, zoom. Next we place a DIV nearby on which Google/Yandex Map is hooked.
  #
  # 1 click on a map places a point (writing to hidden fields). 1 click on a point removes it (emptying fields).
  #
  # options:
  #
  #   value     - current point
  #   width     - map width
  #   height    - map height
  #   latitude  - default map center lat
  #   longitude - default map center lon
  #   zoom      - default map center zoom
  def build_form(form_builder, options)
    set_value_in_hash options

    options = {
        width: 550,
        height: 400,
        latitude: 47.757581,
        longitude: 67.298256,
        zoom: 5,
        value: {},
    }.merge options

    value = (options[:value].is_a? Hash) ? options[:value].stringify_keys : {}

    inputs = []
    id = ''

    form_builder.tap do |value_builder|
      id = form_builder_name_to_id value_builder
      inputs << value_builder.hidden_field(:latitude,  value: value['latitude'])
      inputs << value_builder.hidden_field(:longitude, value: value['longitude'])
      inputs << value_builder.hidden_field(:zoom,      value: value['zoom'])
      inputs << value_builder.hidden_field(:type,      value: value['type'])
    end

    allowed_maps = @@map_providers
    map_names = {'google' => 'Google', 'yandex' => 'Yandex'}
    selected_map_type = value['type'].in?(allowed_maps) ? value['type'] : allowed_maps.first

    switchers = []
    switchers << %Q|<div class="btn-group cck-map-switchers #{'hide' if allowed_maps.count < 2}" style="margin-top: 5px;">|
    allowed_maps.map do |map|
      switchers << %Q|<a class="btn btn-default #{selected_map_type == map ? 'active' : nil}" href="#" data-map-type="#{map}">#{map_names[map]}</a>|
    end
    switchers << '</div>'

    map_html_containers = []
    allowed_maps.each do |map|
      map_html_containers.push %Q|<div id="#{id}_#{map}" data-id=#{id} class="map_widget" style="display: none; width: #{options[:width]}px; height: #{options[:height]}px"></div>|
    end

    api_key = @@google_maps_api_key.present? ? "&key=#{@@google_maps_api_key}" : nil

    %Q|
    <div class="map-canvas">
      #{inputs.join}

      <script>
      var mapsReady = {google: false, yandex: false, callback: null, on: function(callback) {
        this.callback = callback;
        this.fireIfReady();
      }, fireIfReady: function() {
        if(this.google && this.yandex && this.callback) { this.callback() }
      }}

      function googleMapReady() { mapsReady.google = true; mapsReady.fireIfReady() }
      function yandexMapReady() { mapsReady.yandex = true; mapsReady.fireIfReady() }

      function loadMapScripts() {
        var script;
        script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&callback=googleMapReady#{api_key}';
        document.body.appendChild(script);

        script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://api-maps.yandex.ru/2.0/?coordorder=longlat&load=package.full&wizard=constructor&lang=ru-RU&onload=yandexMapReady';
        document.body.appendChild(script);
      }

      window.onload = loadMapScripts;
      </script>

      <div data-map-data-source data-options='#{options.to_json}' data-id="#{id}" data-allowed-maps='#{allowed_maps.to_json}' style="width: #{options[:width]}px; height: #{options[:height]}px">
        #{map_html_containers.join}
      </div>

      #{switchers.join}
    </div>
    |
  end

  # Returns a 64x64 IMG with a marker (see #img_tag)
  def to_diff_value(_options = {})
    demongoize_value!
    img_tag(64, 64, marker_size: :small)
  end
end

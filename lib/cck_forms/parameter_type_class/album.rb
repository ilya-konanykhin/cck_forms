class CckForms::ParameterTypeClass::Album
  include CckForms::ParameterTypeClass::Base
  include CckForms::NeofilesDenormalize

  def self.name
    'Альбом'
  end

  # Преобразует данные для Монго.
  # Приводит переданный массив или хэш объектов Neofiles::Image или их идентификаторов в массив.
  def mongoize
    the_value = value.is_a?(Hash) ? value['value'] : value

    result = []
    if the_value.respond_to? :each
      the_value.each do |image|
        image = image[1] if the_value.respond_to? :each_value
        result.push self.class.neofiles_attrs_or_id(image, ::Neofiles::Image)
      end
    end

    result.compact
  end

  # Преобразуем данные из Монго.
  # Приводим в массив (по идее, массив идентификаторов Neofiles::Image, хотя может быть что угодно).
  def self.demongoize_value(value, parameter_type_class=nil)
    if value.respond_to? :each
      value = value.values if value.respond_to? :values
      value.map { |x| neofiles_mock_or_load(x) }.compact
    else
      []
    end
  end

  # Строит форму для обновления файлов альбома.
  #
  # Ключи options:
  #
  #   value - текущее значение (идентификатор или объект Neofiles::Album)
  def build_form(form_builder, options)
    set_value_in_hash options

    options = {

    }.merge options

    the_value = options[:value].is_a?(Array) ? options[:value] : []
    input_name_prefix = form_builder.object_name + '[value][]'
    widget_id_prefix = form_builder_name_to_id form_builder, '_value_'
    file_forms = []

    the_value.each do |image_id|
      image_id = image_id.is_a?(::Neofiles::File) ? image_id.id : image_id
      file_forms << CckForms::ParameterTypeClass::Image.create_load_form( helper: self,
                                                                          file: image_id,
                                                                          input_name: input_name_prefix,
                                                                          append_create: false,
                                                                          clean_remove: true,
                                                                          widget_id: widget_id_prefix + file_forms.length.to_s,
                                                                          multiple: true,
                                                                          with_desc: options[:with_desc])
    end

    add_file_form = CckForms::ParameterTypeClass::Image.create_load_form( helper: self,
                                                                          file: nil,
                                                                          input_name: input_name_prefix,
                                                                          append_create: true,
                                                                          clean_remove: true,
                                                                          widget_id: widget_id_prefix + file_forms.length.to_s,
                                                                          multiple: true,
                                                                          with_desc: options[:with_desc])

    id = form_builder_name_to_id form_builder, rand(1...1_000_000).to_s

    <<HTML
      <div class="neofiles-album-compact" id="#{id}">
        #{file_forms.join}
        #{add_file_form}
      </div>

      <script type="text/javascript">
        $(function() {
            $("##{id}").album();
        });
      </script>
HTML
  end

  def to_s(options = nil)
    ''
  end

  def to_diff_value(options = {})
    view_context = options[:view_context]
    images_html_list = []
    value.each do |image_id|
      images_html_list << "<img style='width: 64px; height: 64px;' src='#{view_context.neofiles_image_path(id: image_id, format: '64x64', crop: 1)}'>"
    end

    images_html_list.join.html_safe if images_html_list.any?
  end
end

class CckForms::ParameterTypeClass::Album
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Альбом'
  end

  # Преобразует данные для Монго.
  # Приводит переданный массив или хэш объектов Neofiles::Image или их идентификаторов в массив.
  def mongoize
    the_value = value.is_a?(Hash) ? value["value"] : value
    result = []
    if the_value.respond_to? :each
      the_value.each do |image|
        image = image[1] if the_value.respond_to? :each_value
        next if image.blank?
        image = if image.is_a?(::Neofiles::Image)
                  {
                      id: image.id,
                      width: image.width,
                      height: image.height
                  }
                elsif image.is_a?(String)
                  file = ::Neofiles::Image.find(image)
                  {
                      id: file.id,
                      width: file.width,
                      height: file.height
                  }
                else
                  image
                end
        #result.push(image.is_a?(::Neofiles::Image) ? image.id : image.to_s) if image.present?
        result.push(image) if image.present?
      end
    end

    result
  end

  # Преобразуем данные из Монго.
  # Приводим в массив (по идее, массив идентификаторов Neofiles::Image, хотя может быть что угодно).
  def self.demongoize_value(value, parameter_type_class=nil)
    if value.respond_to? :each
      value
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

class CckForms::ParameterTypeClass::File
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Файл'
  end

  def self.file_type
    ::Neofiles::File
  end

  def file_type
    self.class.file_type
  end

  # Если передан Neofiles::File, вернет его идентификатор, если строка - вернет ее, иначе - nil.
  def mongoize
    case value
      when file_type then value.id
      when ::String then value
    end
  end

  # Попытаемся получить объект Neofiles::File по его идентификатору. Если не получилось, вернем nil.
  def self.demongoize_value(value, parameter_type_class=nil)
    file_type.find(value) unless value.blank?
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  # Строит форму выбора и загрузки 1 картинки.
  #
  # Ставит ДИВ и делает аяксовый вызов метода file_compact контроллера Neofiles::AdminController.
  #
  # Ключи options:
  #
  #   value          - текущее значение (идентификатор или объект Neofiles::File)
  #
  def build_form(form_builder, options)
    set_value_in_hash options
    self.class.create_load_form helper: self,
                                file: options[:value].presence,
                                input_name: form_builder.object_name + '[value]',
                                widget_id: form_builder_name_to_id(form_builder, '[value]'),
                                with_desc: options[:with_desc]
  end

  def self.create_load_form(helper:, file:, input_name:, append_create: false, clean_remove: false, widget_id: nil, disabled: false, multiple: false, with_desc: false)
    cont_id   = 'container_' + (widget_id.presence || form_name_to_id(input_name))

    file_id = file.is_a?(Hash) ? file[:id] : file
    # создаем временное поле, чтобы пока аяксовый ответ не вернется, мы могли все же отправить родительскую форму
    # и не потерять при этом данные из поля
    temp_field, remove_temp_field = '', ''
    if file.present? && file.is_a?(String)
      temp_id           = "temp_file_field_#{file}"
      temp_field        = '<input id="' + temp_id + '" type="hidden" name="' + input_name + '" value="' + file + '">'
      remove_temp_field = '$("#' + temp_id + '").remove();'
    end

    '<div id="' + cont_id + '"></div>
    ' + temp_field + '

    <script type="text/javascript">
      $(function() {
          $("#' + cont_id + '").load("' + helper.neofiles_file_compact_path(id: file_id, input_name: input_name, widget_id: widget_id, append_create: append_create ? '1' : nil, clean_remove: clean_remove ? '1' : nil, disabled: disabled ? '1' : nil, multiple: multiple ? '1' : nil, with_desc: with_desc ? '1' : nil) + '", null, function() {
              $(this).children().unwrap();
              ' + remove_temp_field + '
          });
      });
    </script>'
  end

  def to_s
    ''
  end

  def to_diff_value(options = {})
    "Файл: #{self.value.try! :name}"
  end
end

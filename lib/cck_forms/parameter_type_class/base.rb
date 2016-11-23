# Базовая примесь для всех типов полей. Определяет всякие помогайки. Ее нужно включать методом include во все типы,
# например, String, Checkboxes и т. п.
#
#   class CckForms::ParameterTypeClass::NewType
#     include CckForms::ParameterTypeClass::Base
#
#     def self.name
#       'Новый тип'
#     end
#   end
#
#   CckForms::ParameterTypeClass::NewType.name            # 'Новый тип', берется из CckForms::ParameterTypeClass::NewType::name
#
# Использование типов:
#
#   field :cover_photo, type: CckForms::ParameterTypeClass::Image
#   field :gallery, type: CckForms::ParameterTypeClass::Album
#   field :description, type: CckForms::ParameterTypeClass::Text
#
# Что есть в базовом типе:
#
#   1) все помощники УРЛов вида edit_article_path, включаемые через include Rails.application.routes.url_helpers;
#
#   2) методы cck_param и value, которые возвращают текущий параметр (module CckForms::*::Parameter) и его значение;
#
#   3) методы with_cck_param(param) do ... и with_value(value) do ..., которые устанавливают соотв, значения методов
#      cck_param/value на время выполнения блока (еще есть with_cck_param_and_value(param, value) do ...);
#
#   4) динамический метод (через method_missing и respond_to?) ..._with_value(value, args*), который делает то же,
#      что и with_value, но для вызова 1 метода;
#
#   5) set_value_in_hash(hash), который кладет value в hash[:value];
#
#   6) помощники для получения ХТМЛ ID form(_builder)?_name_to_id;
#
#   7) методы для потребителей (типизированных объектов):
#
#        self.code            - код типа из имени модуля (CckForms::ParameterType::RichText -> rich_text)
#        self.name            - имя типа ("Cтрока")
#
module CckForms::ParameterTypeClass::Base
  extend ActiveSupport::Concern

  included do
    # Кое-где понадобятся помогайки-пути, сразу их включим.
    include Rails.application.routes.url_helpers

    attr_accessor :value
    attr_reader :valid_values_class_name, :cck_parameter

    def initialize(options)
      options = options.symbolize_keys

      self.value = options[:value]
      if value.is_a?(Hash) && value.has_key?('value')
        self.value = self.value['value']
      end

      valid_values = options.delete(:valid_values).presence
      valid_values_class_name = options.delete(:valid_values_class_name)
      cck_parameter = options.delete(:cck_parameter)

      @valid_values = valid_values
      @valid_values_class_name = valid_values_class_name
      @cck_parameter = cck_parameter
      @extra_options = options[:extra_options] || options.dup
    end
  end



  module ClassMethods
    def demongoize(something_from_database)
      new value: demongoize_value(something_from_database)
    end

    def demongoize_value(value, parameter_type_class=nil)
      value
    end

    def mongoize(object)
      case object
      when self then object.mongoize
      # TODO: why only these classes? does any scalar fit?
      when Hash, Array, String then new(value: object).mongoize
      else object
      end
    end

    # Возвращает строку с яваскриптовым кодом для выполнения в БД кода emit операции map-reduce на поле данного типа.
    # Поскольку у различных типов данные в БД хранятся по-разному, и вообще понятие "текущего значения этого типа"
    # различается, мы вынуждены отдельно описывать операцию emit, там где это необходимо. Смысл в том, чтобы этот метод
    # вызвал emit для каждого хранимого значения.
    #
    # Пример: есть поле city типа checkboxes, хранящее список городов, то-есть объекты, описываемые этим полем,
    # могут быть в разных городах. Если мы хотим сделать группировочный запрос (частный случай map-reduce) в БД, чтобы,
    # например, подсчитать кол-во объектов в городах, мы не можем просто сделать emit для всего поля city, поскольку
    # оно содержит список городов. Мы должны вызывать emit для каждого элемента массива (т. е., для каждого идентификатора
    # города). Генерацией этого кода и занимается этот метод.
    #
    # В частности, он используется при подсчете популярных значения различных полей (сколько объявлений, поданых
    # в разные города, и т. п.)
    #
    # По-умолчанию, считаем, что значение, хранимое в поле "#{feild_name}" атомарно, и вызываем  emit для него.
    #
    # Подробнее про map-reduce см. http://docs.mongodb.org/manual/applications/map-reduce/
    def emit_map_reduce(feild_name)
      field_name = 'this.' + feild_name
      "if(#{field_name} && #{field_name} != '') emit(#{field_name}, 1)"
    end

    # Конвертирует имя элемента формы в ID, например facility[cck_params][1][value] -> facility_cck_params_1_value.
    def form_name_to_id(name)
      name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, '_').sub(/_\z/, '')
    end

    # Методы, которые нужны наследникам (CckForms::ParameterTypeClass::*) для отображения, сортировки и прочей настройки самих типов.
    # Эти методы не нужны обычным объектам - пользователям типов.

    # CckForms::ParameterTypeClass::Checkboxes -> 'checkboxes'
    # CckForms::ParameterTypeClass::RichText -> 'rich_text'
    def code
      self.to_s.demodulize.underscore
    end

    # Имя типа, например, для select>option[value]
    def name
      nil
    end
  end



  # Загрузит все классы-наследники.
  # TODO: relies on all classes to reside in this class' directory
  def self.load_type_classes
    return if @type_classes_loaded

    path = File.dirname(__FILE__)
    Dir[path + '/*.rb'].each do |filename|
      require_dependency filename unless filename.ends_with? '/base.rb'
    end

    @type_classes_loaded = true
  end



  # "Нормальные" методы, которые будут доступны всем пользователям данного модуля.

  # -> [[key1, value1], [key2, value2], ...]
  # Нужен для построения ХТМЛ СЕЛЕКТов.
  def valid_values_enum
    valid_values = self.valid_values
    return [] if valid_values.blank?
    result = []
    method_for_enumerating = valid_values.is_a?(Array) ? :each_with_index : :each_pair
    valid_values.send(method_for_enumerating) do |key, value|
      result.push [value, key]
    end
    result
  end

  # -> "georgian: грузинская, albanian: албанская"
  # Нужен для построения ХТМЛа и строк.
  def valid_values_as_string
    valid_values_enum.map { |enum| "#{enum[1]}: #{enum[0]}" }.join "\n"
  end

  # Чтобы получать данные из форм и сохранять в БД. Использовать во вьюхах:
  #   = f.text_field :valid_values_as_string
  def valid_values_as_string=(string)
    new_valid_values = {}
    string.split("\n").reject { |line| line.blank? }.each do |line|
      splitted = line.split(':', 2)
      new_valid_values[splitted[0].strip] = splitted[1].strip if splitted.length == 2 and splitted[0].present?
    end
    self.valid_values = new_valid_values
  end

  # Вернет класс, указанный как valid_values_class_name.
  # "City" -> City
  def valid_values_class
    if valid_values_class_name.present?
      if valid_values_class_name.is_a? Class
        valid_values_class_name
      else # если это не строка, то пусть будет выборошено исключение
        valid_values_class_name.constantize
      end
    else
      nil
    end
  end

  # Существует ли valid_values_class?
  def valid_values_class?
    not valid_values_class.nil?
  end

  # Если valid_values пустой, и есть valid_values_class, запишет в valid_values все значения
  # из valid_values_class. Считает, что класс похож на ActiveRecord, и значения берет из all.
  def valid_values
    @valid_values ||= begin
      if vv_class = valid_values_class
        valid_values = {}
        vv_class.all.each { |valid_value_object| valid_values[valid_value_object.id] = valid_value_object.to_s }
        valid_values
      end
    end
  end

  # Строит форму редактирования. Просто input:text со всеми переданными опциями (значение можно определить через
  # options[:value]).
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.text_field :value, options
  end

  # Вернем в виде HTML
  def to_html(options = nil)
    to_s options
  end

  # Чтобы принимать аргумент options
  def to_s(options = nil)
    value.to_s
  end

  # Отображение для страниц "было-стало" в админках и пр. (например, тип "карта" можнет вернуть ХТМЛ картинки-миниатюры).
  def to_diff_value(options = nil)
    to_html options
  end

  # Формируем поисковый запрос для монго на основе запроса (типа мини-DSL язык запроса, свой для каждого типа).
  def search(selectable, field, query)
    selectable.where(field => query.to_s)
  end

  # Нужен для Rails.application.routes.url_helpers
  def default_url_options
    {}
  end

  # Реализация перобразования в/из Монго по умолчанию: берем то, что в value
  def mongoize
    value
  end

  def demongoize_value
    self.class.demongoize_value value, self
  end

  def demongoize_value!
    self.value = demongoize_value
  end



  private

  # options[:value] = value
  def set_value_in_hash(options)
    options[:value] = value unless options.has_key? :value
  end

  # См. ClassMethod.form_name_to_id
  def form_name_to_id(name)
    self.class.form_name_to_id name
  end

  # Конвертирует имя элемента формы из FormBuilder, см. form_name_to_id.
  def form_builder_name_to_id(form_builder, suffix = '')
    form_name_to_id([form_builder.options[:namespace], form_builder.object_name].compact.join('_') + suffix)
  end
end

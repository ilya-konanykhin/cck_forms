class CckForms::ParameterTypeClass::WorkHours
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Часы работы'
  end

  DAYS = %w{ mon tue wed thu fri sat sun }
  DAYS_RU_SHORT = %w{ Пн Вт Ср Чт Пт Сб Вс }

  # mon -> Пн
  def self.day_en_to_ru_short(day)
    DAYS_RU_SHORT[DAYS.index(day.to_s)]
  end

  # Входящий хэш или массив объектов WorkHoursDat
  #
  #   mon: {open_time: ..., open_24_hours: ...}, tue: {...}, ...
  #
  # преобразует в хэш для Монго.
  def mongoize
    return {} unless value.is_a? Hash

    value.reduce({}) do |r, (day_name, day_data)|
      r[day_name] = CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.new(day_data).mongoize if day_name.in? CckForms::ParameterTypeClass::WorkHours::DAYS
      r
    end
  end

  # Конструирует хэш объектов WorkHoursDay (ключ - название дня вида :mon, см. DAYS).
  def self.demongoize_value(value, parameter_type_class=nil)
    return {} unless value.is_a? Hash
    value.reduce({}) do |r, (day_name, day_row)|
      day_row = CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.demongoize(day_row.merge(day: day_name)) if day_row.is_a? Hash
      r[day_name] = day_row
      r
    end
  end

  # Строит форму для редактирования режима работы. 1 строка формы - 1 день со всеми своими параметрами.
  def build_form(form_builder, options)
    set_value_in_hash options

    options = {
        value: {}
    }.merge options

    value = options[:value]
    value = {} unless value.is_a? Hash

    result = []
    met_days = Hash[ CckForms::ParameterTypeClass::WorkHours::DAYS.zip(CckForms::ParameterTypeClass::WorkHours::DAYS.dup.fill(false)) ]

    value.each_value do |day|
      day = CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.new day unless day.is_a? CckForms::ParameterTypeClass::WorkHours::WorkHoursDay
      form_builder.fields_for(:value, index: day.day) { |day_builder| result << day.build_form(day_builder, false, options) }
      met_days[day.day] = true
    end

    met_days.reject! { |_, value| value }

    met_days.keys.each do |day_name|
      form_builder.fields_for(:value, index: day_name) { |day_builder| result << CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.new(day: day_name, open_24_hours: true).build_form(day_builder) }
    end

    form_builder.fields_for(:template) do |day_builder|
      result << CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.new({}).build_form(day_builder, true, options)
    end

    sprintf '<div class="work-hours" id="%1$s">%2$s</div><script type="text/javascript">$(function() {$("#%1$s").workhours()})</script>', form_builder_name_to_id(form_builder), result.join
  end

  # Строит строку вида: "Пн—Ср 10:00—23:00; Чт—Сб круглосуточно"
  def to_html(options = nil)
    value = self.value
    return value.to_s unless value.respond_to? :each

    with_tags = options && !options.try(:[], :with_tags).nil? ? options[:with_tags] : true

    value = value.deep_stringify_keys if value.respond_to? :deep_stringify_keys

    # разобьем на группы дней с одинаковым значением (режимом работы), типа {'круглосуточно' => %w{mon tue wed}, ...}
    groups = {}
    value.send(value.respond_to?(:each_value) ? :each_value : :each) do |day|
      day = CckForms::ParameterTypeClass::WorkHours::WorkHoursDay.new(day) unless day.is_a? CckForms::ParameterTypeClass::WorkHours::WorkHoursDay
      hash = day.to_s_without_day
      groups[hash] = [] unless groups[hash]
      groups[hash] << day.day
    end

    # построим строки для групп
    result = []
    groups.each_pair do |hours_description, days|
      if hours_description.present?
        if days.length == 7
          template = with_tags ? '<span class="workhours-group">%s, <span class="workhours-group-novac">без выходных</span></span>' : '%s, без выходных'
          result << sprintf(template, hours_description)
        else
          if days == %w{ mon tue wed thu fri }
            days_description = 'будние'
          elsif days == %w{ sat sun }
            days_description = 'сб, вс'
          else
            days_description = CckForms::ParameterTypeClass::WorkHours.grouped_days_string(days).mb_chars.downcase
          end
          template = with_tags ? '<span class="workhours-group">%s <span class="workhours-group-days">(%s)</span></span>' : '%s (%s)'
          result << sprintf(template, hours_description, days_description)
        end
      end
    end

    result.join('; ').html_safe
  end

  def to_s(options = nil)
    to_html with_tags: false
  end

  # Входной массив вида %w{mon, tue, wed, sat} преобразует в сгруппированную строку вида: "Пн—Ср, Сб".
  def self.grouped_days_string(days)

    # разобьем на непрерывные группы типа [%w{mon tue wed}, %w{sat}]
    days.sort! { |a, b| DAYS.index(a) <=> DAYS.index(b) }
    prev_index = -2
    groups = []
    days.each do |day|
      index = DAYS.index(day)
      if prev_index + 1 != index
        groups << []
      end

      groups.last << day_en_to_ru_short(day)
      prev_index = index
    end

    # получившиеся группы преобразуем в строки и сольем воедино
    groups.map do |group|
      if group.length == 1
        group[0]
      elsif group.length == 2
        group.join ', '
      else
        sprintf '%s–%s', group.first, group.last
      end
    end.join ', '
  end



  # Модель-представление рабочего графика одного дня недели. При получении данных из Монги преобразовываем в эту модель,
  # для удобства работы (чтобы не с хэшами возиться).
  #
  # day - строка из массива CckForms::ParameterTypeClass::WorkHours::DAYS.
  # open_time и close_time хранятся в виде хэшей {hours: 10, minutes: 5}.
  class WorkHoursDay

    attr_accessor :day, :open_time, :close_time, :open_24_hours, :open_until_last_client

    # Инициализирует свои поля из хэша.
    def initialize(other)
      if other.is_a? Hash
        other = other.symbolize_keys
        @day = other[:day]
        @open_time = other[:open_time]
        @close_time = other[:close_time]
        @open_24_hours = form_to_boolean(other[:open_24_hours])
        @open_until_last_client = form_to_boolean(other[:open_until_last_client])
      elsif other.is_a? WorkHoursDay
        @day = other.day
        @open_time = other.open_time
        @close_time = other.close_time
        @open_24_hours = other.open_24_hours
        @open_until_last_client = other.open_until_last_client
      end
    end

    # Равны ли два объекта. Да, если все их поля равны.
    def ==(other)
      other = self.class.new(other) unless other.is_a? self.class

      self.day == other.day and
          self.open_time == other.open_time and
          self.close_time == other.close_time and
          self.open_24_hours == other.open_24_hours and
          self.open_until_last_client == other.open_until_last_client
    end

    # Строит целочисленный хэш на основе всех полей, кроме day, чтобы группировать одинаковые режимы работы.
    def hash_without_day
      sprintf('%s:%s:%s:%s', open_time, close_time, open_24_hours, open_until_last_client).hash
    end

    # Строит строковое описание режима работы в формате: "с 12:00 до последнего клиента"
    def to_s_without_day
      result = ''
      if open_24_hours
        return 'круглосуточно'
      elsif time_present?(open_time) or time_present?(close_time)
        ots, cts = time_to_s(open_time), time_to_s(close_time)
        if ots and cts
          result = sprintf('%s–%s', ots, cts)
        elsif ots
          result = sprintf('с %s', ots)
        else
          result = sprintf('до %s', cts)
        end
      end

      if open_until_last_client
        result += ' ' if result.present?
        result += 'до последнего клиента'
      end

      result
    end

    # Строит форму редактирования одного дня.
    def build_form(form_builder, template = false, options = {})
      form_builder.object = self

      open_time_form = form_builder.fields_for(:open_time) { |time_form| build_time_form(time_form, open_time) }
      close_time_form = form_builder.fields_for(:close_time) { |time_form| build_time_form(time_form, close_time) }

      input_multi_mark = if options[:multi_days]
                           "data-multi-days='true'"
                         end

      if template
        header = ['<ul class="nav nav-pills">']
        CckForms::ParameterTypeClass::WorkHours::DAYS.each { |day| header << '<li><a href="#"><input name="' + form_builder.object_name + '[days]" type="checkbox" value="' + day + '" /> ' + CckForms::ParameterTypeClass::WorkHours.day_en_to_ru_short(day) + '</a></li>' }
        header = header.push('</ul>').join
      else
        header = sprintf '<strong>%s</strong>:%s', CckForms::ParameterTypeClass::WorkHours::day_en_to_ru_short(day), form_builder.hidden_field(:day)
      end

      open_until_last_client_html = unless options[:hide_open_until_last_client]
                                      <<HTML
                    <div class="checkbox">
                      <label class="form_work_hours_option">#{ form_builder.check_box :open_until_last_client } до&nbsp;последнего&nbsp;клиента</label>
                    </div>
HTML
                                    end

      <<HTML
        <div #{input_multi_mark} class="form_work_hours_day#{template ? ' form_work_hours_day_template" style="display: none' : ''}">
          <div class="form_work_hours_time">
            #{header}
          </div>
          <div class="form_work_hours_time">
            <table width="100%">
              <tr>
                <td width="60%" class="form-inline">
                  с #{ open_time_form }
                  по #{ close_time_form }
                </td>
                <td width="40%">
                    <div class="checkbox">
                      <label class="form_work_hours_option">#{ form_builder.check_box :open_24_hours } круглосуточно</label>
                    </div>
                    #{open_until_last_client_html}
                </td>
              </tr>
            </table>
          </div>
        </div>
HTML
    end



    private

    # Преобразует значение из запроса (чексбокс) в булево, типа 1 -> true.
    def form_to_boolean(value)
      return value == '1' if value.is_a? String
      !!value
    end

    # Преобразует хэше времени {hours: ..., minutes: ...} в строку "10:42"
    def time_to_s(time)
      return nil unless time.is_a?(Hash) and time['hours'].present? and time['minutes'].present?
      sprintf '%s:%s', time['hours'].to_s.rjust(2, '0'), time['minutes'].to_s.rjust(2, '0')
    end

    # Не пустое ли значение времени?
    def time_present?(time)
      return time.is_a?(Hash) && time['hours'].present? && time['minutes'].present?
    end

    # Строим форму с селектами времени вида: [18]:[45]
    def build_time_form(form_builder, value)
      hours = []
      24.times { |hour| hours << [hour.to_s.rjust(2, '0'), hour] }

      minutes = []
      (60/5).times { |minute| minutes << [(minute *= 5).to_s.rjust(2, '0'), minute] }

      sprintf(
          '%s : %s',
          form_builder.select(:hours, hours, {include_blank: true, selected: value.try(:[], 'hours')}, class: 'form-control input-sm', style: 'width: 60px'),
          form_builder.select(:minutes, minutes, {include_blank: true, selected: value.try(:[], 'minutes')}, class: 'form-control input-sm', style: 'width: 60px')
      ).html_safe
    end



    public

    # Преборазование самого себя для сохранения в Монго (хэш).
    def mongoize
      {
          'day' => day.to_s,
          'open_time' => self.class.mongoize_time(open_time),
          'close_time' => self.class.mongoize_time(close_time),
          'open_24_hours' => open_24_hours,
          'open_until_last_client' => open_until_last_client,
      }
    end

    class << self

      # Преборазование самого себя из представления Монго (из хэша).
      def demongoize(object)
        object = object.symbolize_keys
        WorkHoursDay.new(
            day: object[:day].to_s,
            open_time: self.demongoize_time(object[:open_time]),
            close_time: self.demongoize_time(object[:close_time]),
            open_24_hours: object[:open_24_hours],
            open_until_last_client: object[:open_until_last_client],
        )
      end

      # "Статическое" преборазование самого себя для сохранения в Монго (хэш).
      def mongoize(object)
        case object
          when WorkHoursDay then object.mongoize
          when Hash then WorkHoursDay.new(object).mongoize
          else object
        end
      end

      # TODO: сделать нормальный evolve
      def evolve(object)
        object
      end

      # Преобразовываем значение времени для Монго. Берет Time или DateTime или хэш и выдает хэш вида:
      #
      #   {hours: 10, minutes: 5}
      def mongoize_time(time)
        if time.is_a? Time or time.is_a? DateTime
          {'hours' => time.hour, 'minutes' => time.min}
        elsif time.is_a? Hash
          time = time.stringify_keys
          {'hours' => time['hours'].present? ? time['hours'].to_i : nil, 'minutes' => time['minutes'].present? ? time['minutes'].to_i : nil}
        end
      end

      # Преобразовываем значение времени для Монго. Берет Time или DateTime или хэш и выдает хэш вида:
      #
      #   {hours: 10, minutes: 5}
      def demongoize_time(time)
        mongoize_time(time)
      end
    end

  end
end

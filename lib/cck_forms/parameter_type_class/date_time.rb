class CckForms::ParameterTypeClass::DateTime
  include CckForms::ParameterTypeClass::Base
  include CckForms::DateTime

  def self.name
    'Дата и время'
  end

  def build_form(form_builder, options)
    set_value_in_hash options
    value = CckForms::ParameterTypeClass::Time::date_object_from_what_stored_in_database(options[:value])
    form_element_options, form_element_html = CckForms::ParameterTypeClass::Time.default_options_for_date_time_selectors(value)
    form_element_options.merge!({minute_step: 5})
    form_element_html.merge!({required: options[:required]})
    ('<div class="form-inline">%s</div>' % form_builder.fields_for(:value) { |datetime_builder| datetime_builder.datetime_select '', form_element_options, form_element_html})
  end

  # Формирует строковое представление даты и времени. Если options :символ, это эквивалентно options[:символ] = true,
  # например:
  #
  #   date_attr.to_s :only_date
  #   date_attr.to_s :only_date => true # эквивалентно
  #
  # Ключи options:
  #
  #   year_obligatory - вывести год, по-умолчанию, он не показывается, если равен текущему
  #   only_date       - только дату, без времени
  #   rus_date        - дату по-русски, типа "2 июля"
  #
  # По-умолчанию, вернет строку вида "01.02.2012, 12:49". Если что-то сломалось, вернет пустую строку.
  def to_s(options=nil)
    value = if self.value.is_a? Time
              {
                  '(1i)' => self.value.year,
                  '(2i)' => self.value.month,
                  '(3i)' => self.value.day,
                  '(4i)' => self.value.hour,
                  '(5i)' => self.value.min,
              }
            else
              self.value
            end

    return '' unless value and
        value.is_a?(Hash) and
        value.try(:[], '(1i)').to_i > 0 and
        value.try(:[], '(2i)').to_i > 0 and
        value.try(:[], '(3i)').to_i > 0

    options = {options => true} if options.is_a? Symbol
    options = {} unless options.is_a? Hash

    now = Date::today
    date = DateTime.new value.try(:[], '(1i)').to_i, value.try(:[], '(2i)').to_i, value.try(:[], '(3i)').to_i, value.try(:[], '(4i)').to_i, value.try(:[], '(5i)').to_i
    date = date.in_time_zone(Rails.application.config.time_zone)

    need_year = options[:year_obligatory] || now.strftime('%Y') != date.strftime('%Y')

    if options[:rus_date]
      date_string = Russian::strftime(date, '%e %B' + (need_year ? ' %Y' : '')) # 2 июля
    else
      date_string = date.strftime('%d.%m' + (need_year ? '.%Y' : ''))
    end

    time_string = date.strftime '%H:%M'

    if options[:only_date]
      return date_string
    else
      return "#{date_string}, #{time_string}"
    end

  rescue
    ''
  end
end

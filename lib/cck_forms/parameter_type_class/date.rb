# Represents a single date.
#
class CckForms::ParameterTypeClass::Date
  include CckForms::ParameterTypeClass::Base
  include CckForms::DateTime

  # Date SELECT
  def build_form(form_builder, options)
    set_value_in_hash options
    self.class.build_date_form(form_builder, options)
  end

  # Date SELECT as a set of 3 SELECTS: year, month, date
  def self.build_date_form(form_builder, options, type = '')
    val =  options[:value].is_a?(Hash) ? options[:value][type] : options[:value]
    val = CckForms::ParameterTypeClass::Time::date_object_from_what_stored_in_database(val)
    form_element_options, form_element_html = CckForms::ParameterTypeClass::Time::default_options_for_date_time_selectors(val)
    form_element_html.merge!({required: options[:required]})
    ('<div class="form-inline">%s</div>' % form_builder.fields_for(:value) { |datetime_builder| datetime_builder.date_select type, form_element_options, form_element_html}).html_safe
  end

  # "12.12.2012"
  def to_s(options = nil)
    if value.is_a? Time
      the_value = {
          '(1i)' => value.year,
          '(2i)' => value.month,
          '(3i)' => value.day,
      }
    end

    the_value ||= value

    "#{the_value.try(:[], '(3i)')}.#{the_value.try(:[], '(2i)')}.#{the_value.try(:[], '(1i)')}"
  end
end

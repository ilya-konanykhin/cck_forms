# Represents a single time.
#
class CckForms::ParameterTypeClass::Time
  include CckForms::ParameterTypeClass::Base
  include CckForms::DateTime

  # Time SELECT
  def build_form(form_builder, options)
    set_value_in_hash options
    value = CckForms::ParameterTypeClass::Time::date_object_from_what_stored_in_database(options[:value])
    form_element_options, form_element_html = CckForms::ParameterTypeClass::Time::default_options_for_date_time_selectors(value)
    form_element_options.merge!({ignore_date: true, minute_step: 5})
    form_element_html.merge!({required: options[:required]})
    ('<div class="form-inline">%s</div>' % form_builder.fields_for(:value) { |datetime_builder| datetime_builder.time_select '', form_element_options, form_element_html})
  end

  # "19:34"
  def to_s(_options = nil)
    if value.is_a? Time
      the_value = {
          '(4i)' => value.hour,
          '(5i)' => value.min,
      }
    end

    the_value ||= value

    "#{the_value.try(:[], '(4i)')}:#{the_value.try(:[], '(5i)')}"
  end
end

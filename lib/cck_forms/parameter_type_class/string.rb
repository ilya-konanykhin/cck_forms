# Represents a short text string.
#
class CckForms::ParameterTypeClass::String
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Строка'
  end

  # HTML input element
  def build_form(form_builder, options)
    set_value_in_hash options
    attrs = @extra_options.slice(:maxlength, :pattern)
    form_builder.text_field :value, {class: 'form-control'}.merge(attrs).merge(options)
  end
end

# Represents a floating point value.
#
class CckForms::ParameterTypeClass::Float
  include CckForms::ParameterTypeClass::Base

  def mongoize
    value.to_f
  end

  def to_s(_options = nil)
    value.to_f != 0.0 ? value.to_f : ''
  end

  # HTML input
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.number_field :value, {step: 'any', class: 'form-control input-small'}.merge(options)
  end
end

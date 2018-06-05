class CckForms::ParameterTypeClass::FloatRange < CckForms::ParameterTypeClass::NumberRange
  def normalize_number(number)
    number.to_f.round(2)
  end

  def form_field(form_builder_field, field_name, options)
    default_style = {class: 'form-control input-small'}

    form_builder_field.number_field field_name, options.merge(value: value.try(:[], field_name.to_s), step: 'any').reverse_merge(default_style)
  end
end

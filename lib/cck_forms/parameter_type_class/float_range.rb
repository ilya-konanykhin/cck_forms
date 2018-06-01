class CckForms::ParameterTypeClass::FloatRange < CckForms::ParameterTypeClass::NumberRange
  def from_value(value_from_form)
    value_from_form.try(:[], 'from').to_f.round(2)
  end

  def till_value(value_from_form)
    value_from_form.try(:[], 'till').to_f.round(2)
  end

  def form_field(form_builder_field, field_name, options)
    default_style = {class: 'form-control input-small'}

    form_builder_field.number_field field_name, options.merge(value: value.try(:[], field_name.to_s), step: 'any').reverse_merge(default_style)
  end
end

class CckForms::ParameterTypeClass::IntegerRange < CckForms::ParameterTypeClass::NumberRange
  def from_value(value_from_form)
    value_from_form.try(:[], 'from').to_i
  end

  def till_value(value_from_form)
    value_from_form.try(:[], 'till').to_i
  end
end

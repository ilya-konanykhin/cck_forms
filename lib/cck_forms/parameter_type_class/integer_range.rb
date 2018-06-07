class CckForms::ParameterTypeClass::IntegerRange < CckForms::ParameterTypeClass::NumberRange
  def normalize_number(number)
    number.to_i
  end
end

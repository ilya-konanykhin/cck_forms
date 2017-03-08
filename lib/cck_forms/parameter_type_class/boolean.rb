# Represents a single checkbox.
#
class CckForms::ParameterTypeClass::Boolean
  include CckForms::ParameterTypeClass::Base

  # Is it true?
  def value?
    value.present? && value != '0'
  end

  # Anything -> boolean
  def mongoize
    value?
  end

  # 'yes/no' string
  def to_s(_options = nil)
    value? ? I18n.t('cck_forms.boolean.yes') : I18n.t('cck_forms.boolean.no')
  end

  # Checkbox HTML
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.check_box :value, options.merge(value: 1, checked: value?)
  end
end

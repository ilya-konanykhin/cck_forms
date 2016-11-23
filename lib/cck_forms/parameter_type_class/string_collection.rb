class CckForms::ParameterTypeClass::StringCollection
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Массив строк'
  end

  def mongoize
    value.split "\r\n" if value.is_a? String
  end

  def self.demongoize_value(value, parameter_type_class=nil)
    value = [value] if value.is_a? String
    super
  end

  def build_form(form_builder, options)
    set_value_in_hash options
    options[:value] = value.join("\r\n") if value

    form_builder.text_area :value, {cols: 50, rows: 5, class: 'form-control'}.merge(options)
  end
end

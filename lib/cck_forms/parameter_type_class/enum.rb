# Represents a enum (SELECT).
#
class CckForms::ParameterTypeClass::Enum
  include CckForms::ParameterTypeClass::Base

  def mongoize
    value.presence
  end

  # Current string value from valid_values
  def to_s(options = nil)
    return '' if value.blank?
    valid_values[value].to_s
  end

  # Constructs MongoDB query. If query is a Hash, find all objects where field is any of the hash keys, for which value
  # is '1'. Otherwise treat query as where(filed => query).
  def search(selectable, field, query)
    if query.is_a? Hash
      query = query.map { |k, v| v == '1' ? k : nil }.compact
    end
    query = [query] unless query.is_a? Array

    if query.any?
      selectable.where(field.to_sym.in => query)
    else
      selectable
    end
  end

  # options:
  #
  #   as        - if 'checkboxes', display a set of checkboxes, not SELECT
  #   only      - leave only these keys (array/string)
  #   except    - reverse of :only
  #   required  - HTML required attr
  def build_form(form_builder, options)

    if options.is_a? Hash and options[:as] == 'checkboxes'
      options = options.except(:for, :as)
      checkboxes = CckForms::ParameterTypeClass::Checkboxes.new valid_values: self.valid_values, value: self.value
      return checkboxes.build_form(form_builder, options)
    end

    set_value_in_hash options

    values = valid_values_enum
    if options[:only]
      options[:only] = [options[:only]] unless options[:only].is_a? Array
      values.select! { |o| o[1].in? options[:only] }
    end

    if options[:except]
      options[:except] = [options[:except]] unless options[:except].is_a? Array
      values.reject! { |o| o[1].in? options[:except] }
    end

    form_builder.select :value, values, {selected: options[:value], required: options[:required], include_blank: !options[:required]}, class: 'form-control '
  end
end

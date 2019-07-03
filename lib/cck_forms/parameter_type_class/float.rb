# Represents a floating point value.
#
class CckForms::ParameterTypeClass::Float
  include CckForms::ParameterTypeClass::Base

  def mongoize
    value.to_f
  end

  def to_s(_options = nil)
    options ||= {}
    trailing_zeros = options.fetch(:trailing_zeros, true)
    value.to_f != 0.0 ? value.to_f : ''
    trailing_zeros && value.to_i == value ? value.to_i  : value
  end

  # '123'     -> 123
  # '100/'    -> $gte: 100
  # '100/150' -> $gte: 100, $lte: 150
  #    '/150' ->            $lte: 150
  #
  # l: 100          -> $gte: 100
  # l: 100, h: 150  -> $gte: 100, $lte: 150
  #         h: 150  ->            $lte: 150
  def search(selectable, field, query)
    if query.is_a?(Hash) || query.to_s.include?('/')
      low, high = query.is_a?(Hash) ? [query[:l] || query['l'], query[:h] || query['h']] : query.to_s.split('/')

      if low.to_f > 0
        selectable = selectable.gte(field => low.to_f)
      end

      if high.to_f > 0
        selectable = selectable.lte(field => high.to_f)
      end

      selectable
    else
      selectable.where(field => query.to_f)
    end
  end

  # HTML input
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.number_field :value, {step: 'any', class: 'form-control input-small'}.merge(options)
  end
end

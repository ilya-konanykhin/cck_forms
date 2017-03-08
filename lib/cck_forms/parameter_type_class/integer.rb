# Represents a decimal value.
#
class CckForms::ParameterTypeClass::Integer
  include CckForms::ParameterTypeClass::Base

  def mongoize
    value.to_i
  end

  def to_s(options = nil)
    value.to_i != 0 ? value.to_i.to_s : ''
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

      if low.to_i > 0
        selectable = selectable.gte(field => low.to_i)
      end

      if high.to_i > 0
        selectable = selectable.lte(field => high.to_i)
      end

      selectable
    else
      selectable.where(field => query.to_i)
    end
  end

  # Examples of options[:values] (works only if options[:as] == :select or options[:for] == :search):
  #
  #   ranges:   [['not more that 10', '/10'], ['11-20', '11/20'], ['21-30', '21/30'], ['more that 30', '31/']]
  #   counting: [['one', '1'], ['two', '2'], ['three', '3']]
  #   combined: [['one', '1'], ['two', '2'], ['three and more', '3/']]
  #
  # Other options:
  #
  #   only    - leave only these keys (array/string)
  def build_form(form_builder, options = {})
    set_value_in_hash options

    default_style = {class: 'form-control input-small'}

    if options[:for] == :search
      res = []
      as = options[:as]
      only = options[:only]
      options = options.except :only, :for

      if as == :select
        res << form_builder.select(:value, [['', '']] + options[:values], options.merge(selected: options[:value]), class: 'form-control input-small')
      else
        value = options[:value].is_a?(Hash) ? options[:value].symbolize_keys : {}

        if !only || only == :low
          res << form_builder.text_field(:l, options.merge(index: 'value', value: value[:l]).reverse_merge(default_style))
        end

        if !only || only == :high
          res << form_builder.text_field(:h, options.merge(index: 'value', value: value[:h]).reverse_merge(default_style))
        end
      end

      res.join ' – '
    else
      form_builder.number_field :value, options.reverse_merge(default_style)
    end
  end
end

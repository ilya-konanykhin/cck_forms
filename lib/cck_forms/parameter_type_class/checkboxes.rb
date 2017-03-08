# Represents a series of checkboxes. The values are take from valid_values, see base.rb
#
class CckForms::ParameterTypeClass::Checkboxes
  include CckForms::ParameterTypeClass::Base

  # {kazakh: '1', russian: '0', english: '1'} -> ['kazakh', 'english']
  def mongoize
    resulting_set = []

    if value.is_a? Array
      return value
    elsif value.is_a?(String) || value.is_a?(Symbol)
      return [value.to_s]
    elsif !value.is_a?(Hash)
      return []
    end

    value.each do |key, value|
      resulting_set << key if value.to_s == '1'
    end

    resulting_set
  end

  # ['kazakh', 'english'] -> {'kazakh' => 1, 'russain' => 0, 'english' => 1}
  # (for for builders)
  def self.demongoize_value(value, parameter_type_class=nil)
    value.present? or return {}

    valid_values = parameter_type_class.try!(:valid_values) || value.map { |x| [x, nil] }
    valid_values.reduce({}) do |r, (key, _)|
      r[key] = value.include?(key) ? '1' : '0'
      r
    end
  end

  # Comma-separated list of checked entries. Options:
  #
  #   block   - sprintf template for each entry
  #   only    - leave only these keys (array/string)
  #   except  - reverse of :only
  #   glue    - use instead of ', ' for .join
  #   short   - make the string shorter, if possible: if all variants are checked, returns string "all selected"
  #             if few are not checked, returns "all except xxx, yyy, ..."
  def to_s(options = nil)
    checked_keys, checked_elements = [], []
    return '' if value.blank?

    template = '%s'
    if options
      options = {block: options} unless options.is_a? Hash
      template = options[:block] if options[:block]
    else
      options = {}
    end

    if value.respond_to? :each_pair
      value.each_pair do |k, v|
        include = v == '1' && (!options[:only] || options[:only] && options[:only] == k)
        exclude = options[:except] && options[:except] == k
        if include && !exclude
          checked_elements << sprintf(template, valid_values[k])
          checked_keys << k
        end
      end
    elsif value.respond_to? :each
      value.each do |k|
        exclude = options[:except] && options[:except] == k
        unless exclude
          checked_elements << sprintf(template, valid_values[k])
          checked_keys << k
        end
      end
    end

    glue = options[:glue] || ', '
    if options[:short] && checked_keys
      all_keys        = valid_values.keys
      unchecked_keys  = all_keys - checked_keys
      unchecked_num   = unchecked_keys.count

      param_title = cck_parameter ? " «#{cck_parameter.title}»" : ''

      if unchecked_num == 0
        return I18n.t('cck_forms.checkboxes.all_values', param_title: param_title)
      elsif unchecked_num < checked_keys.count./(2).round
        return I18n.t('cck_forms.checkboxes.all_values_except', param_title: param_title) + ' ' + valid_values.values_at(*unchecked_keys).map { |x| sprintf(template, x) }.join(glue)
      end
    end

    checked_elements.join glue
  end

  # Construct Mongoid query from our internal. If query is a Hash, find all objects where field has ALL of the Hash keys.
  # Key 'all' selected all objects.
  #
  # Otherwise, use usual where(field => query).
  def search(selectable, field, query)
    if query.respond_to? :each_pair
      keys = []
      query.each_pair do |key, value|
        if value.present? && value != '0'
          if key == 'any'
            selectable = selectable.where(field.to_sym.ne => [])
          else
            keys << key
          end
        end
      end
      selectable = selectable.where(field.to_sym.all => keys) if keys.any?
    else
      selectable = selectable.where(field.to_s => query)
    end

    selectable
  end

  # Construct emit func for map/reduce to emit on each array value in MongoDB. For example, for object:
  #
  #   cck_params.city: ['almaty', 'astana']
  #
  # we will emit('almaty', 1); emit('astana', 1).
  def self.emit_map_reduce(field_name)
    field_name = 'this.' + field_name
    return "if(#{field_name} && #{field_name} instanceof Array) {
      #{field_name}.forEach(function(key) {
        emit(key, 1)
      })
    }"
  end

  # options:
  #
  #   block   - sprintf template for each entry (input, label)
  #   map     - convert entry labels, e.g. 'long label text' => 'sh.txt'
  #   data    - data-attrs for label, Hash (e.g. capital: {almaty: 'yes', astana: 'no'})
  #   as      - if :select, construct a SELECT, not a checkboxes list
  #   only    - see #to_s
  #   except  - see #to_s
  #   for     - if :search, do not add false-value checkbox
  def build_form(form_builder, options)
    return '' unless valid_values.is_a?(Hash) || valid_values.is_a?(Array)

    if options.is_a? Hash and options[:as] == :select
      return build_select_form(form_builder, options.except(:for, :as))
    end

    options = {block: '<div class="form_check_box_block">%s %s</div>', map: {}}.merge(options)

    set_value_in_hash options
    val = options[:value]

    result = ''
    if valid_values.is_a? Array
      method = :each_with_index
    elsif valid_values.is_a? Hash
      method = :each_pair
    end

    valid_values.send(method) do |k, v|
      if !options[:only] || options[:only] == k || options[:only].try(:include?, k)
        result += form_builder.fields_for :value do |ff|

          begin
            checked = ! val.try(:[], k).to_i.zero?
          rescue
            checked = false
          end

          v = options[:map][v] || v

          # skip `required` since form will not be submitted unless a user checks all the checkboxes
          data = options[:data] ? extract_data_for_key(k, options[:data]) : nil
          sprintf(options[:block], ff.check_box(k.to_sym, {checked: checked}, '1', options[:for] == :search ? nil : '0'), ff.label(k.to_sym, v, data: data)).html_safe
        end
      end
    end

    result
  end



  private

  # options:
  #
  #   only      - see #to_s
  #   except    - see #to_s
  #   required  - HTML required attr
  def build_select_form(form_builder, options)
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

    form_builder.select :value, values, {selected: options[:value], required: options[:required], include_blank: !options[:required]}, class: 'form-control'
  end

  def extract_data_for_key(request_key, data)
    data.reduce({}) do |r, (key, values)|
      r[key] = values[request_key] if values[request_key]
      r
    end
  end
end

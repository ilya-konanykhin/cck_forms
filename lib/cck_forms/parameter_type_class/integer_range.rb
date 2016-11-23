class CckForms::ParameterTypeClass::IntegerRange # Rover :)
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Диапазон между двумя целыми числами'
  end

  # {from: 500, to: 1000, ranges: {"300-600" => true, "601-900" => true, "901-1500" => false}}
  def mongoize
    value_from_form = value
    return nil if value_from_form.blank?

    from = value_from_form.try(:[], 'from').to_i
    till = value_from_form.try(:[], 'till').to_i

    db_representation = {
      from: from,
      till: till,
      ranges: {}
    }

    if @extra_options[:ranges].respond_to? :each
      @extra_options[:ranges].each do |range_string|
        low, high = range_string.split(range_string_delimiter)
        if high.to_i.to_s != high.to_s
          high = Integer::MAX_32BIT
        end
        low, high = low.to_i, high.to_i

        #   -----
        # [ RANGE ]
        completely_in_range = (from >= low && till <= high)

        #       -------
        # [ RANGE ]
        #
        # ------
        #    [ RANGE ]
        intersects_range_partially = (from <= low && till >= low) || (from <= high && till >= high)

        # -----------
        #  [ RANGE ]
        contains_range = from < low && till > high

        db_representation[:ranges][range_string] = completely_in_range || intersects_range_partially || contains_range
      end
    end

    db_representation
  end

  def to_s(options = {})
    options ||= {}
    return '' if value.blank?

    delimiter = options[:delimeter].presence || default_integer_range_delimiter

    from = value.try(:[], 'from').to_i
    till = value.try(:[], 'till').to_i

    return '' if from.zero? && till.zero?

    if from.zero?
      "до #{till}"
    elsif till.zero?
      "от #{from}"
    elsif from == till
      from.to_s
    else
      [from, till].join(delimiter)
    end
  end

  def build_form(form_builder, options)
    set_value_in_hash options
    if options.delete(:for) == :search
      build_search_form(form_builder, options)
    else
      build_for_admin_interface_form(form_builder, options)
    end
  end

  def search(criteria, field, query)
    criteria.where("#{field}.ranges.#{query}" => true)
  end



  private

  def build_for_admin_interface_form(form_builder, options)
    delimiter = options[:delimeter].presence || ' — '

    default_style = {class: 'form-control input-small'}
    result = ['<div class="form-inline">']
    form_builder.fields_for :value do |ff|
      from_field = ff.number_field :from, options.merge(value: value.try(:[], 'from')).reverse_merge(default_style)
      till_field = ff.number_field :till, options.merge(value: value.try(:[], 'till')).reverse_merge(default_style)
      result << [from_field, till_field].join(delimiter).html_safe
    end
    result << '</div>'
    result.join.html_safe
  end

  def build_search_form(form_builder, options)
    delimiter = options[:delimeter].presence || default_integer_range_delimiter
    form_fields = []
    visual_representation = options.delete(:as)
    show_only = options.delete(:only)

    if visual_representation == :select
      klazz = options.delete :class
      form_fields << form_builder.select(:value, [['', '']] + humanized_integer_ranges_for_select, options.merge(selected: options[:value]), {class: klazz} )
    else
      show_all_fields = !show_only

      if show_all_fields or show_only == :low
        form_fields << form_builder.text_field(:from, options.merge(index: 'value', value: value.try(:[], 'from')))
      end

      if show_all_fields or show_only == :high
        form_fields << form_builder.text_field(:till, options.merge(index: 'value', value: value.try(:[], 'till')))
      end
    end

    form_fields.join(delimiter).html_safe
  end

  def default_integer_range_delimiter
    "–"
  end

  def humanized_integer_ranges_for_select
    @extra_options[:ranges].map do |range_string|
      low, high = range_string.split(range_string_delimiter)
      if low.to_i.to_s != low.to_s
        option_text = "до #{high}"
      elsif high.to_i.to_s != high.to_s
        option_text = "свыше #{low}"
      else
        option_text = [low, high].join(default_integer_range_delimiter)
      end
      [option_text, range_string]
    end
  end

  def range_string_delimiter
    /[-:\\]/
  end
end

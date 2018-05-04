class CckForms::ParameterTypeClass::FloatRange
  include CckForms::ParameterTypeClass::Base

  # {from: 500, to: 1000, ranges: {"300-600" => true, "601-900" => true, "901-1500" => false}}
  def mongoize
    value_from_form = value
    return nil if value_from_form.blank?

    from = value_from_form.try(:[], 'from').to_f.round(2)
    till = value_from_form.try(:[], 'till').to_f.round(2)

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

  # "from 10"
  # "till 20"
  # "10-20"
  #
  # options:
  #
  #   delimeter - instead of "-"
  def to_s(options = {})
    options ||= {}
    return '' if value.blank?

    delimiter = options[:delimeter].presence || default_float_range_delimiter

    from = value.try(:[], 'from').to_f.round(2)
    till = value.try(:[], 'till').to_f.round(2)

    return '' if from.zero? && till.zero?

    if from.zero?
      [I18n.t('cck_forms.float_range.till'), till].join(' ')
    elsif till.zero?
      [I18n.t('cck_forms.float_range.from'), from].join(' ')
    elsif from == till
      from.to_s
    else
      [from, till].join(delimiter)
    end
  end

  # If options[:for] == :search and options[:as] == :select, builds a SELECT with options from extra_options[:rages].
  # Otherwise, two inputs are built.
  #
  # options[:only/:except] are available if the former case.
  def build_form(form_builder, options)
    set_value_in_hash options
    if options.delete(:for) == :search
      build_search_form(form_builder, options)
    else
      build_for_admin_interface_form(form_builder, options)
    end
  end

  # Search with the help of extra_options[:ranges]
  def search(criteria, field, query)
    criteria.where("#{field}.ranges.#{query}" => true)
  end



  private

  def build_for_admin_interface_form(form_builder, options)
    delimiter = options[:delimeter].presence || ' — '

    default_style = {class: 'form-control input-small'}
    result = ['<div class="form-inline">']
    form_builder.fields_for :value do |ff|
      from_field = ff.number_field :from, options.merge(value: value.try(:[], 'from'), step: 'any').reverse_merge(default_style)
      till_field = ff.number_field :till, options.merge(value: value.try(:[], 'till'), step: 'any').reverse_merge(default_style)
      result << [from_field, till_field].join(delimiter).html_safe
    end
    result << '</div>'
    result.join.html_safe
  end

  def build_search_form(form_builder, options)
    delimiter = options[:delimeter].presence || default_float_range_delimiter
    form_fields = []
    visual_representation = options.delete(:as)
    show_only = options.delete(:only)

    if visual_representation == :select
      klazz = options.delete :class
      form_fields << form_builder.select(:value, [['', '']] + humanized_float_ranges_for_select, options.merge(selected: options[:value]), {class: klazz} )
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

  def default_float_range_delimiter
    '–'
  end

  def humanized_float_ranges_for_select
    @extra_options[:ranges].map do |range_string|
      low, high = range_string.split(range_string_delimiter)
      if low.to_i.to_s != low.to_s
        option_text = [I18n.t('cck_forms.float_range.less_than'), high].join(' ')
      elsif high.to_i.to_s != high.to_s
        option_text = [I18n.t('cck_forms.float_range.more_than'), low].join(' ')
      else
        option_text = [low, high].join(default_float_range_delimiter)
      end
      [option_text, range_string]
    end
  end

  def range_string_delimiter
    /[-:\\]/
  end
end

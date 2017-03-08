# Represents a pair of date SELECTs (date range).
#
class CckForms::ParameterTypeClass::DateRange
  include CckForms::ParameterTypeClass::Base

  # Converts input hash of type {from: ..., till: ...} to MongoDB format
  def mongoize
    value_from_form = value
    return nil if value_from_form.blank?
    db_representation = {}

    %w(from till).each do |type|
     type_hash = {}
      %w((1i) (2i) (3i)).each do |field|
        type_hash.merge!("#{field}" => value_from_form.try(:[], "#{type + field}"))
      end
     db_representation[type] =  CckForms::ParameterTypeClass::Time::date_object_from_what_stored_in_database(type_hash)
    end

    db_representation
  end

  # 2 date SELECTs
  def build_form(form_builder, options)
    result = []
    set_value_in_hash options

    [:from, :till].each do |type|
      result << CckForms::ParameterTypeClass::Date.build_date_form(form_builder, options, type)
    end

    result.join.html_safe
  end

  # "from 21.12.2012"
  # "till 22.12.2012"
  # "21.12.2012 - 22.12.2012"
  def to_s
    return '' unless value.present? && value.is_a?(Hash)
    types = {}
    [:from, :till].each { |type| types[type] = value[type].strftime('%d.%m.%Y') if value[type].is_a?(Time) }
    from, till = types[:from], types[:till]

    if from.blank?
      "до #{till}"
    elsif till.blank?
      "от #{from}"
    elsif from == till
      from.to_s
    else
      [from, till].join(' - ')
    end

  end
end

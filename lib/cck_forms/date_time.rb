module CckForms::DateTime
  extend ActiveSupport::Concern

  module DateTimeParser
    def date_object_from_what_stored_in_database(value)
      parsed_value = nil
      if value.is_a? Hash

        force_timezone = true
        v = value

        if v.has_key? 'hour' and v.has_key? 'month'
          parsed_value = DateTime.civil(v['year'], v['year'], v['day'], v['hour'], v['minute'])
        elsif v.has_key? 'hour' or v.has_key? 'month'
          if v.has_key? 'hour'
            parsed_value = Time.parse("#{v['hour']}:#{v['minute']}")
          elsif v.has_key? 'month'
            parsed_value = Date.parse("#{v['day']}.#{v['month']}.#{v['year']}")
          end
        else
          if v.has_key? '(5i)' and v.has_key? '(1i)' # date & time
            parsed_value = DateTime.parse("#{v['(3i)']}.#{v['(2i)']}.#{v['(1i)']} #{v['(4i)']}:#{v['(5i)']}")
          elsif v.has_key? '(5i)' # time
            parsed_value = Time.parse("#{v['(4i)']}:#{v['(5i)']}")
          elsif v.has_key? '(1i)' # date
            parsed_value = Date.parse("#{v['(3i)']}.#{v['(2i)']}.#{v['(1i)']}")
          end
        end
      end
      value = parsed_value if parsed_value

      if force_timezone || value.is_a?(Time)
        value = value.change offset: ActiveSupport::TimeZone.new(Rails.application.config.time_zone).formatted_offset
      end

      value
    end
  end

  module ClassMethods
    include DateTimeParser

    def default_options_for_date_time_selectors(value)
      date_in_time_zone = value.in_time_zone(Rails.application.config.time_zone) rescue nil
      [{default: date_in_time_zone, include_blank: false, with_css_classes: true}, {class: 'form-control'}]
    end

    def demongoize_value(value, parameter_type_class=nil)
      date_object_from_what_stored_in_database value
    end
  end

  include DateTimeParser

  def mongoize
    date_object_from_what_stored_in_database value
  end
end

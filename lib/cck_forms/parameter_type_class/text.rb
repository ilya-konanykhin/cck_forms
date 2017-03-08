# Represents a long text string (TEXTAREA).
#
class CckForms::ParameterTypeClass::Text
  include CckForms::ParameterTypeClass::Base

  # Builds a TEXTAREA
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.text_area :value, {cols: 50, rows: 5, class: 'form-control'}.merge(options)
  end

  # Wraps DIFF output to .wall (bootstrap-specific bounded block)
  def to_diff_value(options = {})
    to_html(options).presence.try do |html|
      "<div class='well well-small'>#{html}</div>".html_safe
    end
  end
end

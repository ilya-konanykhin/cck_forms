# Примесь для расширения ActionView::Helpers::FormBuilder, чтобы работать с нашими полями:
#
#   class CckEnabled
#     field :logo, type: CckForms::ParameterTypeClass::Image
#   end
#
#   = form_for @cck_enabled do |f|
#     = f.standalone_cck_field :logo
#
module CckForms::FormBuilderExtensions
  ActionView::Helpers::FormBuilder.class_eval do
    def standalone_cck_field(field_name, options = {})
      fields_for(field_name) do |ff|
        @template.raw object.send(field_name).build_form ff, options
      end
    end
  end
end

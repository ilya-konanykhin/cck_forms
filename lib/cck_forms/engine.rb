module CckForms
  class Engine < ::Rails::Engine
    config.autoload_paths << File.expand_path('../..', __FILE__)

    config.after_initialize do
      CckForms::ParameterTypeClass::Base.load_type_classes if Rails.application.config.cck_forms.load_type_classes
      ActionView::Base.send :include, CckForms::FormBuilderExtensions if Rails.application.config.cck_forms.extend_form_builder
    end

    config.cck_forms = ActiveSupport::OrderedOptions.new

    # general
    config.cck_forms.load_type_classes          = true
    config.cck_forms.extend_form_builder        = true

    # phones
    config.cck_forms.phones = ActiveSupport::OrderedOptions.new
    config.cck_forms.phones.min_phones_in_form  = 3
    config.cck_forms.phones.mobile_codes        = %w{ 777 705 771   701 702 775 778   700   707 }
    config.cck_forms.phones.prefix              = '+7'
    config.cck_forms.phones.number_parts_glue   = '-'
  end
end

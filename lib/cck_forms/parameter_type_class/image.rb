class CckForms::ParameterTypeClass::Image < CckForms::ParameterTypeClass::File
  include CckForms::ParameterTypeClass::Base

  def self.name
    'Картинка'
  end

  def self.file_type
    ::Neofiles::Image
  end

  def file_type
    self.class.file_type
  end

  def to_diff_value(options = {})
    view_context = options[:view_context]
    "<img style='width: 64px; height: 64px;' src='#{view_context.neofiles_image_path(id: value, format: '64x64', crop: 1)}'>".html_safe
  end
end

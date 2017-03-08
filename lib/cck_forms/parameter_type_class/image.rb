# Represents a single image. A subclass of File.
#
class CckForms::ParameterTypeClass::Image < CckForms::ParameterTypeClass::File
  def self.file_type
    ::Neofiles::Image
  end

  def file_type
    self.class.file_type
  end

  # Returns a 64x64 IMG
  def to_diff_value(options = {})
    view_context = options[:view_context]
    "<img style='width: 64px; height: 64px;' src='#{view_context.neofiles_image_path(id: value, format: '64x64', crop: 1)}'>".html_safe
  end
end

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

    if value.present?
      id = value.is_a?(BSON::Document) ? value['_id'] : value
      "<img style='width: 64px; height: 64px;' src='#{view_context.neofiles_image_path(id: id, format: '64x64', crop: 1)}'>".html_safe
    else
      return nil
    end
  end
end

class CckForms::ParameterTypeClass::Image < CckForms::ParameterTypeClass::File
  include CckForms::ParameterTypeClass::Base
  include CckForms::ImageValue

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

  def mongoize
    case value
      when file_type then converted_attributes(value)
      when ::Hash then value
      when ::String
        image = file_type.find(value)
        converted_attributes(image)
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end
  
  def self.demongoize_value(value, parameter_type_class=nil)
    unless value.blank?
      value.is_a?(Hash) ? value : file_type.find(value)
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

end

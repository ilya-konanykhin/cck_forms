# Album without watermark. A subclass of Album.
#
class CckForms::ParameterTypeClass::WatermarklessAlbum < CckForms::ParameterTypeClass::Album
  def self.name
    'Альбом без водяного знака'
  end

  def cck_image_type
    CckForms::ParameterTypeClass::WatermarklessImage
  end
end

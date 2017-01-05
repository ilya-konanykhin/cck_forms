module CckForms::ImageValue
  def converted_attributes(value)
    hash = value.attributes
    hash[:id] = hash.delete :_id
    hash.except(:no_wm, :description)
  end
end
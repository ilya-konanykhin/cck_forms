# Base module for all field types. Is included in type classes like Album, Image etc.
#
#   class CckForms::ParameterTypeClass::NewType
#     include CckForms::ParameterTypeClass::Base
#   end
#
# Standalone usage of real classes:
#
#   field :cover_photo, type: CckForms::ParameterTypeClass::Image
#   field :gallery,     type: CckForms::ParameterTypeClass::Album
#   field :description, type: CckForms::ParameterTypeClass::Text
#
# Base module includes:
#
#   1) URL helpers like edit_article_path accessible via include Rails.application.routes.url_helpers;
#
#   2) methods cck_param & value returning current CCK parameter (module CckForms::*::Parameter) and his current value;
#
#   3) methods with_cck_param(param) do ..., with_value(value) do ... and with_cck_param_and_value(param, value) do ...
#      which set the corresponding values for the block duration;
#
#   4) dynamic method (via method_missing & respond_to?) ..._with_value(value, args*) which is basically the same as
#      with_value do... but for one method invocation only: foo_with_value(v) <=> with_value(v) { foo }
#
#   5) utility set_value_in_hash(hash) placing value in hash[:value];
#
#   6) utilities to get HTML ID: form(_builder)?_name_to_id;
#
#   7) methods to be consumed by the type classes:
#
#        self.code  - type code (e.g. rich_text for CckForms::ParameterType::RichText)
#        self.name  - type name (e.g. "A text string")
#
module CckForms::ParameterTypeClass::Base
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers

    attr_accessor :value
    attr_reader :valid_values_class_name, :cck_parameter

    # Store options into instance variables like @valid_values and so on
    def initialize(options)
      options = options.symbolize_keys

      self.value = options[:value]
      if value.is_a?(Hash) && value.has_key?('value')
        self.value = self.value['value']
      end

      valid_values = options.delete(:valid_values).presence
      valid_values_class_name = options.delete(:valid_values_class_name)
      cck_parameter = options.delete(:cck_parameter)

      @valid_values = valid_values
      @valid_values_class_name = valid_values_class_name
      @cck_parameter = cck_parameter
      @extra_options = options[:extra_options] || options.dup
    end
  end



  module ClassMethods
    # Called on a class to construct its instance from a MongoDB Hash.
    # By default simply create a new object.
    def demongoize(something_from_database)
      new value: demongoize_value(something_from_database)
    end

    # Only converts a value from MongoDB to its in-memory (Ruby) form.
    # By default, return the value itself.
    def demongoize_value(value, parameter_type_class=nil)
      value
    end

    # Called on an class to get a MongoDB Hash form of an instance object.
    # By default simply calls mongoize of the instance.
    def mongoize(object)
      case object
      when self then object.mongoize
      # TODO: why only these classes? does any scalar fit?
      when Hash, Array, String then new(value: object).mongoize
      else object
      end
    end

    # Returns Javascript emit function body to be used as a part of map/reduce "emit" step, see
    # http://docs.mongodb.org/manual/applications/map-reduce/
    #
    # The reason for this is every type class has its own notion of "current value" and stores it specifically. Say,
    # Checkboxes store an array of values and if we want to get distinct values we need a way to extract each "single
    # value" from this array.
    #
    # Example: imagine a field "city" of type Checkboxes. To make an aggregate query (a subtype of map-reduce)
    # to count objects in different cities, for example, we can not run emit for the field as a whole since it is an
    # array. We must call emit for each array value, that is for each city ID. This method does exactly this.
    #
    # In particular, it is used in counting popular values (like "give me a list of cities sorted by the number of
    # host objects (ads? companies?) in them").
    #
    # By default considers a value in "#{feild_name}" atomic and call emit for it.
    def emit_map_reduce(feild_name)
      field_name = 'this.' + feild_name
      "if(#{field_name} && #{field_name} != '') emit(#{field_name}, 1)"
    end

    # Converts input name intp HTML ID, e.g. facility[cck_params][1][value] -> facility_cck_params_1_value.
    def form_name_to_id(name)
      name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, '_').sub(/_\z/, '')
    end

    # CckForms::ParameterTypeClass::Checkboxes -> 'checkboxes'
    # CckForms::ParameterTypeClass::RichText -> 'rich_text'
    def code
      self.to_s.demodulize.underscore
    end

    # A type name, e.g. "A text string"
    def name
      nil
    end
  end



  # Load all type classes
  # TODO: relies on all classes to reside in this class' directory
  def self.load_type_classes
    return if @type_classes_loaded

    path = File.dirname(__FILE__)
    Dir[path + '/*.rb'].each do |filename|
      require_dependency filename unless filename.ends_with? '/base.rb'
    end

    @type_classes_loaded = true
  end



  # Usual methods available to type classes (consumers of this module)

  # Generates valid_values in form consumable to SELECT helper builders: [[key1, value1], [key2, value2], ...]
  def valid_values_enum
    valid_values = self.valid_values
    return [] if valid_values.blank?
    result = []
    method_for_enumerating = valid_values.is_a?(Array) ? :each_with_index : :each_pair
    valid_values.send(method_for_enumerating) do |key, value|
      result.push [value, key]
    end
    result
  end

  # Generates valid values as a comma-separated string: "georgian: грузинская, albanian: албанская" (for HTML puproses)
  def valid_values_as_string
    valid_values_enum.map { |enum| "#{enum[1]}: #{enum[0]}" }.join "\n"
  end

  # Convert HTML form back into Hash again:
  #   = f.text_field :valid_values_as_string
  def valid_values_as_string=(string)
    new_valid_values = {}
    string.split("\n").reject { |line| line.blank? }.each do |line|
      splitted = line.split(':', 2)
      new_valid_values[splitted[0].strip] = splitted[1].strip if splitted.length == 2 and splitted[0].present?
    end
    self.valid_values = new_valid_values
  end

  # "City" -> City
  def valid_values_class
    if valid_values_class_name.present?
      if valid_values_class_name.is_a? Class
        valid_values_class_name
      else # raises exception if this is not a string
        valid_values_class_name.constantize
      end
    else
      nil
    end
  end

  # Is valid_values_class exist at all?
  def valid_values_class?
    not valid_values_class.nil?
  end

  # If valid_values is empty and valid_values_class is not, extracts all values from this class into valid_values.
  # Makes use of ActiveRecord-like method .all for this
  def valid_values
    @valid_values ||= begin
      if vv_class = valid_values_class
        valid_values = {}
        vv_class.all.each { |valid_value_object| valid_values[valid_value_object.id] = valid_value_object.to_s }
        valid_values
      end
    end
  end

  # Builds an edit form in HTML.
  # By default an input:text (value can be set via options[:value]).
  def build_form(form_builder, options)
    set_value_in_hash options
    form_builder.text_field :value, options
  end

  # HTML form of a type class.
  # By default to_s.
  def to_html(options = nil)
    to_s options
  end

  # Redefines to allow passing of options.
  # By default, call to_s on the current value.
  def to_s(options = nil)
    value.to_s
  end

  # Was-became HTML for admin panels etc. (like a type image with map preview for Map).
  def to_diff_value(options = nil)
    to_html options
  end

  # Transforms DSL-like query (specific to each type) into Mongoid query.
  # By default use simple where(field: query.to_s).
  def search(selectable, field, query)
    selectable.where(field => query.to_s)
  end

  # For Rails.application.routes.url_helpers
  def default_url_options
    {}
  end

  # Transforms the value into MongoDB form.
  # By default returns the value itself.
  def mongoize
    value
  end

  def demongoize_value
    self.class.demongoize_value value, self
  end

  def demongoize_value!
    self.value = demongoize_value
  end



  private

  # options[:value] = value
  def set_value_in_hash(options)
    options[:value] = value unless options.has_key? :value
  end

  # See ClassMethod.form_name_to_id
  def form_name_to_id(name)
    self.class.form_name_to_id name
  end

  # Converts FormBuilder name to ID, see form_name_to_id
  def form_builder_name_to_id(form_builder, suffix = '')
    form_name_to_id([form_builder.options[:namespace], form_builder.object_name].compact.join('_') + suffix)
  end
end

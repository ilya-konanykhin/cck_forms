# Utility class to handle denormalization of Neofile::File object fields to be stored in a host object.
#
# This module is included in Album and Image parameter type classes.
#
module CckForms::NeofilesDenormalize
  extend ActiveSupport::Concern

  # Fields that should not be stored in a host object since they are mutable
  NEOFILES_LAZY_ATTRS = %i{ no_wm description is_deleted }

  module ClassMethods
    # Returns all fields of Neofiles::File obj to be denormalized
    def neofiles_attrs(obj)
      obj.attributes.except *NEOFILES_LAZY_ATTRS
    end

    # Returns all fields of Neofiles::File to be denormalized or the object ID if the object itself can not be found
    def neofiles_attrs_or_id(obj_or_id, klass = ::Neofiles::File)
      if obj_or_id.present?
        obj, id = if obj_or_id.is_a? klass
                    [obj_or_id, nil]
                  elsif obj_or_id.is_a?(::String) || obj_or_id.is_a?(::BSON::ObjectId)
                    [::Neofiles::File.where(id: obj_or_id).first, obj_or_id.to_s]
                  end

        obj.try { |x| neofiles_attrs(x) } || id
      end
    end

    # Constructs a Mongoid::Document of class klass with attrs as if it was a usual document loaded from MongoDB
    def neofiles_mock(attrs, klass)
      Mongoid::Factory.from_db(klass, attrs).tap do |obj|
        neofiles_lazy_loadable obj
      end
    end

    # If attrs_or_id is a Hash, constructs a mock from it. Otherwise, load an object by its ID
    def neofiles_mock_or_load(attrs_or_id, klass = ::Neofiles::File)
      if attrs_or_id.present?
        case attrs_or_id
          when ::String then klass.where(id: attrs_or_id).first
          when ::BSON::ObjectId then klass.where(id: attrs_or_id).first
          when ::Hash then neofiles_mock(attrs_or_id.with_indifferent_access, klass)
        end
      end
    end

    # Makes obj lazy load fields NEOFILES_LAZY_ATTRS. That is, when these fields are accessed vie getters or
    # read_attribute, make a request to MongoDB to fetch fresh data (all at once)
    def neofiles_lazy_loadable(obj)
      def obj.__lazy_load
        return if @__lazy_loaded
        @__lazy_loaded = true
        from_db = self.class.find(id)
        attributes.merge! from_db.attributes.slice(*NEOFILES_LAZY_ATTRS)
      end

      def obj.read_attribute(field)
        __lazy_load if field.in? NEOFILES_LAZY_ATTRS
        super(field)
      end

      NEOFILES_LAZY_ATTRS.each do |field|
        obj.define_singleton_method field do
          __lazy_load
          super()
        end
      end
    end
  end
end

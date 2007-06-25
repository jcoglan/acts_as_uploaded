module ActiveRecord
  class Base
  
    def self.acts_as_uploaded(options = {})
      extend ActsAsUploaded::ClassMethods
      include ActsAsUploaded::InstanceMethods
      include ActsAsUploaded::FileSystem
      include ActsAsUploaded::Validation
      
      set_default_upload_settings(options)
      
      before_update   :rename_uploaded_file
      after_save      :save_uploaded_file
      after_destroy   :delete_uploaded_file
      
      alias_method(:write_attribute_without_filename_sanitizing, :write_attribute)
      alias_method(:write_attribute, :write_attribute_with_filename_sanitizing)
      
      alias_method(:validate_without_upload_validation, :validate)
      alias_method(:validate, :validate_with_upload_validation)
    end
  
  end
end

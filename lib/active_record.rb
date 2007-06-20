module ActiveRecord
  class Base
  
    def self.acts_as_uploaded(options = {})
      extend ActsAsUploaded::ClassMethods
      include ActsAsUploaded::InstanceMethods
      
      set_default_upload_settings(options)
      
      before_update :rename_uploaded_file
      after_destroy :delete_uploaded_file
      
      alias_method(:write_attribute_without_filename_sanitizing, :write_attribute)
      alias_method(:write_attribute, :write_attribute_with_filename_sanitizing)
    end
  
  end
end

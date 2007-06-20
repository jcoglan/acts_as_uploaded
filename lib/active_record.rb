module ActiveRecord
  class Base
    def self.acts_as_uploaded
      extend ActsAsUploaded::ClassMethods
      include ActsAsUploaded::InstanceMethods
      set_default_upload_settings
      after_destroy :delete_uploaded_file
    end
  end
end

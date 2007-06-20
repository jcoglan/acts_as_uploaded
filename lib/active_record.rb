module ActiveRecord
  class Base
    def self.acts_as_uploaded(options = {})
      extend ActsAsUploaded::ClassMethods
      include ActsAsUploaded::InstanceMethods
      set_default_upload_settings(options)
      before_update :rename_uploaded_file
      after_destroy :delete_uploaded_file
    end
  end
end

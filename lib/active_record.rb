module ActiveRecord #:nodoc:
  class Base
  
    # Defines a model as representing uploaded files. This macro adds in all the methods that the model
    # will need to process file uploads and handle the saved files once they're on the server. Options are:
    #
    # * <tt>:accepted_content</tt> - string or array of content types used to restrict uploaded filetypes.
    #   e.g. <tt>"image/jpeg"</tt>, or <tt>["image/jpeg", "application/msword"]</tt>. If not specified, all
    #   types will be accepted.
    # * <tt>:valid_filesize</tt> - hash containing minimum and maximum filesizes in bytes accepted by the
    #   model. e.g. <tt>{:minimum => 1, :maximum => 4.megabytes}</tt>. Default is anything up to 4 Mb.
    # * <tt>:directory</tt> - the directory under +RAILS_ROOT+ where files should be stored. Defaults to
    #   <tt>"uploads/#{class.to_s.tableize}"</tt>, so files for your +LargeAttachment+ model would go in
    #   <tt>uploads/large_attachments</tt>.
    # * <tt>:subdirectory</tt> - the name of an instance method in the model which returns a directory name,
    #   used to split the main upload directory into subdirectories. Defaults to +nil+ (everything goes in the
    #   same directory).
    # * <tt>:chmod</tt> - the default +chmod+ permission setting for saved files. Defaults to <tt>0644</tt>.
    # * <tt>:filename</tt> - the database column used to store the file's name. Defaults to <tt>:filename</tt>.
    # * <tt>:content_type</tt> - the database column used to store the file's content type. Defaults to +nil+.
    # * <tt>:filesize</tt> - the database column used to store the file's size in bytes. Defaults to +nil+.
    #
    # Example:
    #
    #   class LargeAttachment < ActiveRecord::Base
    #     belongs_to :folder
    #     acts_as_uploaded :directory => "public/images/attachments",
    #                      :accepted_content => %w(image/jpeg image/png),
    #                      :subdirectory => :folder_id,
    #                      :content_type => :content
    #   end
    #
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

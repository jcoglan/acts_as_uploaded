module ActsAsUploaded #:nodoc:

  module ClassMethods #:nodoc:
  private
    def set_default_upload_settings(options = {})
      class_inheritable_accessor(:upload_options)
      defaults = {
        :accepted_content     => [],
        :valid_filesize       => {:minimum => 0, :maximum => 4.megabytes},
        :directory            => 'uploads/' + self.to_s.tableize,
        :subdirectory         => nil,
        :chmod                => 0644,
        :filename             => :filename,
        :content_type         => nil,
        :filesize             => nil
      }
      self.upload_options = defaults.update(options)
    end
  end
  
  module InstanceMethods #:nodoc:
  
    # Returns the +uploaded_file+ object from the record if it exists. This property only exists during a
    # file upload process - it will not return the file saved on the file system. You should use <tt>File.open</tt>
    # with the record's +full_path+ for operations on the saved file.
    def uploaded_file;          @uploaded_file; end
    
    # Attribute writer for the +uploaded_file+ property. Allows file uploads to be scripted just like any
    # other record attribute. Use <tt>update_attribute :uploaded_file => file</tt> to overwrite saved files.
    def uploaded_file=(file);   write_attribute(:uploaded_file, file); end
    
  private
    
    def extract_file_from_array(array)
      return array unless array.is_a?(Array)
      array.each do |element|
        if element.is_a?(Array)
          result = extract_file_from_array(element)
          return result unless result.nil?
        end
        return element if [StringIO, Tempfile, File].include?(element.class)
      end
      return nil
    end
    
    def sanitize_filename(name)
      name = extract_file_from_array(name)
      name = name.original_filename if name.respond_to?(:original_filename)
      name.to_s.
          gsub(/[\_\:\/]+/, ' ').
          gsub(/[^a-z0-9.\s-]/i, '').
          strip.
          gsub(/\s+/, '_').
          gsub(/^_+$/, '')
    end
    
    def populate_attributes_from_uploaded_file
      return if @uploaded_file.nil?
      send("#{self.class.upload_options[:filename]}=", @uploaded_file.original_filename)
      send("#{self.class.upload_options[:content_type]}=", @uploaded_file.content_type.strip) unless self.class.upload_options[:content_type].nil?
      send("#{self.class.upload_options[:filesize]}=", @uploaded_file.size) unless self.class.upload_options[:filesize].nil?
    end
    
    def write_attribute_with_filename_sanitizing(attr_name, value)
      if attr_name.to_s == "uploaded_file"
        @uploaded_file = extract_file_from_array(value)
        @uploaded_file = nil if @uploaded_file.is_a?(String)
        populate_attributes_from_uploaded_file
      else
        @saved_full_path = full_path if file_exists?
        if attr_name.to_s == self.class.upload_options[:filename].to_s
          value = sanitize_filename(value)
        end
        write_attribute_without_filename_sanitizing(attr_name, value)
      end
    end
    
    def after_save_uploaded_file; end
  end

end

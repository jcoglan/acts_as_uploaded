module ActsAsUploaded

  module ClassMethods
    def upload(uploaded_file, params = {})
      record = self.new(params)
      result = record.upload(uploaded_file)
      [result, record]
    end
    
    def accepts_file_format?(format)
      format = extract_file_from_array(format)
      format = format.content_type if format.respond_to?(:content_type)
      upload_options[:accepted_content].blank? or upload_options[:accepted_content].include?(format.to_s.strip)
    end
    
    def sanitize_filename(filename)
      filename = extract_file_from_array(filename)
      filename = filename.original_filename if filename.respond_to?(:original_filename)
      filename.to_s.gsub(/[\_\:\/]+/, ' ').
          downcase.
          gsub(/[^a-z0-9.\s-]/i, '').
          strip.
          gsub(/\s+/, '_').
          gsub(/^_+$/, '')
    end
    
    def extract_file_from_array(array)
      return array unless array.is_a?(Array)
      array.each do |element|
        return extract_file_from_array(element) if element.is_a?(Array)
        return element if [StringIO, Tempfile, File].include?(element.class)
      end
      return nil
    end
    
  private
    
    def set_default_upload_settings(options = {})
      class_inheritable_accessor(:upload_options)
      defaults = {
        :accepted_content     => [],
        :valid_filesize       => {:minimum => 0, :maximum => 4.megabytes},
        :directory            => 'uploads/' + self.to_s.tableize,
        :subdirectory         => nil,
        :filename             => :filename,
        :content_type         => nil,
        :filesize             => nil
      }
      self.upload_options = defaults.update(options)
    end
  end
  
  module InstanceMethods
    def upload(uploaded_file, overwrite = false)
      @uploaded_file = self.class.extract_file_from_array(uploaded_file)
      populate_attributes_from_uploaded_file
      validate_uploaded_file(overwrite)
      return save_uploaded_file if errors.empty?
      return false
    end
    
  private
    
    def populate_attributes_from_uploaded_file
      return if @uploaded_file.nil?
      send("#{self.class.upload_options[:filename]}=", @uploaded_file.original_filename)
      send("#{self.class.upload_options[:content_type]}=", @uploaded_file.content_type.strip) unless self.class.upload_options[:content_type].nil?
      send("#{self.class.upload_options[:filesize]}=", @uploaded_file.size) unless self.class.upload_options[:filesize].nil?
    end
    
    def write_attribute_with_filename_sanitizing(attr_name, value)
      @saved_full_path ||= full_path if file_exists?
      if attr_name.to_s == self.class.upload_options[:filename].to_s
        value = self.class.sanitize_filename(value)
      end
      write_attribute_without_filename_sanitizing(attr_name, value)
    end
    
    def after_save_uploaded_file; end
  end

end

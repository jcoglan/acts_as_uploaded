module ActsAsUploaded
  module Validation
  
  private
    
    def validate_uploaded_file(overwrite = false)
      valid?
      if @uploaded_file.nil?
        errors.add_to_base('No file was uploaded') and return
      end
      validate_file_does_not_exist unless overwrite
      validate_filesize
      validate_content_type
    end
    
    def validate_file_does_not_exist
      errors.add(self.class.upload_options[:filename], "'#{filename}' already exists") if file_exists?
    end
    
    def validate_filesize
      return if @uploaded_file.nil?
      errors.add_to_base("Uploaded file was too small") if @uploaded_file.size < self.class.upload_options[:valid_filesize][:minimum]
      errors.add_to_base("Uploaded file was too large") if @uploaded_file.size > self.class.upload_options[:valid_filesize][:maximum]
    end
    
    def validate_content_type
      return if @uploaded_file.nil?
      errors.add_to_base("Content type '#{@uploaded_file.content_type.strip}' is not valid") unless
          self.class.accepts_file_format?(@uploaded_file.content_type)
    end
  
  end
end

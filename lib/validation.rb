module ActsAsUploaded #:nodoc:
  module Validation #:nodoc:
  
    def validate_with_upload_validation
      validate_without_upload_validation
      validate_uploaded_file
    end
    
  private
    
    def validate_uploaded_file
      if @uploaded_file.nil?
        if file_exists?
          validate_file_does_not_exist unless full_path == full_path_from_current_attributes
        else
          errors.add_to_base("No file was uploaded")
        end
      else
        validate_file_does_not_exist
        validate_filesize
        validate_content_type
      end
    end
    
    def validate_file_does_not_exist
      errors.add(self.class.upload_options[:filename], "'#{filename}' already exists") if File.file?(full_path_from_current_attributes)
    end
    
    def validate_filesize
      return if @uploaded_file.nil?
      errors.add_to_base("Uploaded file was too small") if @uploaded_file.size < self.class.upload_options[:valid_filesize][:minimum]
      errors.add_to_base("Uploaded file was too large") if @uploaded_file.size > self.class.upload_options[:valid_filesize][:maximum]
    end
    
    def validate_content_type
      return if @uploaded_file.nil?
      errors.add_to_base("Content type '#{@uploaded_file.content_type.strip}' is not valid") unless
          accepts_file_format?(@uploaded_file.content_type)
    end
    
    def accepts_file_format?(format)
      format = extract_file_from_array(format)
      format = format.content_type if format.respond_to?(:content_type)
      upload_options[:accepted_content].blank? or upload_options[:accepted_content].to_a.include?(format.to_s.strip)
    end
  
  end
end

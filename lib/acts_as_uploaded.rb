module ActsAsUploaded

  module ClassMethods
    def upload(upload, params = {})
      record = self.new(params)
      file = extract_file_from_array(upload)
      record.filename = file
      record.validate_uploaded_file(file, false)
      if record.errors.empty?
        record.save_uploaded_file(file)
        result = record.save
        return [result, record]
      end
      [false, record]
    end
    
    def accepts_file_format?(format)
      format = format.content_type if format.respond_to?(:content_type)
      upload_options[:accepted_content].blank? or upload_options[:accepted_content].include?(format.to_s.strip)
    end
    
    def sanitize_filename(filename)
      filename = filename.original_filename if filename.respond_to?(:original_filename)
      filename.to_s.gsub(/[\_\:\/]+/, ' ').
          downcase.
          gsub(/[^a-z0-9.\s-]/i, '').
          strip.
          gsub(/\s+/, '_').
          gsub(/^_+$/, '')
    end
    
  private
    
    def set_default_upload_settings(options = {})
      class_inheritable_accessor(:upload_options)
      defaults = {
        :accepted_content     => [],
        :valid_filesize       => {:minimum => 0, :maximum => 4.megabytes},
        :directory_method     => nil,
        :filename_method      => :filename,
        :upload_directory     => 'uploads/' + self.to_s.tableize
      }
      self.upload_options = defaults.update(options)
    end
    
    def extract_file_from_array(array)
      return array if [StringIO, Tempfile, File].include?(array.class)
      array.each do |element|
        return extract_file_from_array(element) if element.is_a?(Array)
        return element if [StringIO, Tempfile, File].include?(element.class)
      end
      return nil
    end
  end
  
  module InstanceMethods
    def full_path
      path = self.class.upload_options[:upload_directory].
          gsub(Regexp.new("^(#{RAILS_ROOT})?/?"), RAILS_ROOT + '/') + '/' +
          instance_directory + '/' + filename
      path.gsub(/\/+/, '/')
    end
    
    def public_path
      public_regexp = Regexp.new("^#{RAILS_ROOT}/public")
      full_path =~ public_regexp ? full_path.gsub(public_regexp, '') : nil
    end
    
    def file_exists?
      File.exists?(full_path)
    end
    
    def filesize
      file_exists? ? File.size(full_path) : nil
    end
    
    def validate_uploaded_file(file, overwrite = false)
      valid?
      if file.nil?
        errors.add_to_base('No file was uploaded') and return
      end
      validate_file_does_not_exist unless overwrite
      validate_filesize(file.size)
      validate_content_type(file.content_type)
    end
    
    def save_uploaded_file(data)
      ensure_directory_exists
      data = data.read if data.respond_to?(:read)
      File.open(full_path, 'wb') { |f| f.write(data) }
      callback(:after_save_uploaded_file)
    end
    
    def remove_empty_directory
      dir = File.dirname(full_path)
      system_files = ['Thumbs.db', '.DS_Store']
      if (Dir.entries(dir) - ['.', '..'] - system_files).empty?
        system_files.each { |sys| File.delete("#{dir}/#{sys}") if File.exists?("#{dir}/#{sys}") }
        Dir.rmdir(dir)
      end
    end
    
  private
    
    def validate_file_does_not_exist
      errors.add(self.class.upload_options[:filename_method], "'#{filename}' already exists") if file_exists?
    end
    
    def validate_filesize(filesize)
      errors.add_to_base("Uploaded file was too small") if filesize < self.class.upload_options[:valid_filesize][:minimum]
      errors.add_to_base("Uploaded file was too large") if filesize > self.class.upload_options[:valid_filesize][:maximum]
    end
    
    def validate_content_type(content_type)
      errors.add_to_base("Content type '#{content_type.strip}' is not valid") unless self.class.accepts_file_format?(content_type)
    end
    
    def instance_directory
      (dir = self.class.upload_options[:directory_method]).nil? ? '' : send(dir).to_s
    end
    
    def ensure_directory_exists
      upload_directory = File.dirname(full_path)
      leading_slash = (upload_directory =~ /^\//) ? '/' : ''
      directories = upload_directory.split(/\/+/).delete_if(&:blank?)
      directories.each_with_index do |dir, i|
        unless ['.', '..'].include?(dir)
          make_dir = leading_slash + directories[0..i].join('/')
          Dir.mkdir(make_dir) unless File.exists?(make_dir)
        end
      end
    end
    
    def rename_uploaded_file
      saved_record = self.class.find(id)
      if saved_record.file_exists? and full_path != saved_record.full_path
        if file_exists?
          errors.add(self.class.upload_options[:filename_method], "is already taken by another file")
          return false
        end
        ensure_directory_exists
        File.rename(saved_record.full_path, full_path)
        saved_record.remove_empty_directory
      end
    end
    
    def delete_uploaded_file
      File.delete(full_path) if file_exists?
      remove_empty_directory
    end
    
    def write_attribute_with_filename_sanitizing(attr_name, value)
      if attr_name.to_s == self.class.upload_options[:filename_method].to_s
        value = self.class.sanitize_filename(value)
      end
      write_attribute_without_filename_sanitizing(attr_name, value)
    end
    
    def after_save_uploaded_file; end
  end

end

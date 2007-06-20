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
      accepted_content.blank? or accepted_content.include?(format.to_s.strip)
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
      defaults = {
        :accepted_content     => [],
        :valid_filesize       => {:minimum => 0, :maximum => 4.megabytes},
        :directory_method     => nil,
        :filename_method      => :filename
      }
      (defaults.keys.collect(&:to_s) + %w(upload_directory)).each do |method_name|
        cattr_accessor method_name
        if defaults.keys.collect(&:to_s).include?(method_name)
          send("#{method_name}=", defaults[method_name.intern]) if send(method_name).nil?
        end
      end
      options.each { |key, value| send("#{key.to_s}=", value) }
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
      self.class.upload_directory.gsub(/\/$/, '').
          gsub(Regexp.new("^(#{RAILS_ROOT}/?)?"), RAILS_ROOT + '/') +
          instance_directory.gsub(/^\/?(.+?)\/?$/, '/\1') +
          '/' + filename
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
      errors.add(self.class.filename_method, "'#{filename}' already exists") if file_exists?
    end
    
    def validate_filesize(filesize)
      errors.add_to_base("Uploaded file was too small") if filesize < self.class.valid_filesize[:minimum]
      errors.add_to_base("Uploaded file was too large") if filesize > self.class.valid_filesize[:maximum]
    end
    
    def validate_content_type(content_type)
      errors.add_to_base("Content type '#{content_type.strip}' is not valid") unless self.class.accepts_file_format?(content_type)
    end
    
    def instance_directory
      (dir = self.class.directory_method).nil? ? '' : send(dir).to_s
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
          errors.add(self.class.filename_method, "is already taken by another file")
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
      if attr_name.to_s == self.class.filename_method.to_s
        value = self.class.sanitize_filename(value)
        write_attribute_without_filename_sanitizing(attr_name, value)
      end
    end
  end

end

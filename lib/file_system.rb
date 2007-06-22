module ActsAsUploaded
  module FileSystem
  
    def full_path
      @saved_full_path || full_path_from_current_attributes
    end
    
    def public_path
      public_regexp = Regexp.new("^#{RAILS_ROOT}/public")
      full_path =~ public_regexp ? full_path.gsub(public_regexp, '') : nil
    end
    
    def file_exists?
      File.file?(full_path)
    end
    
    def filesize
      file_exists? ? File.size(full_path) : nil
    end
    
    def save_uploaded_file(remove_existing_file = false)
      return false if @uploaded_file.nil?
      return false unless save
      delete_uploaded_file if file_exists? and remove_existing_file
      ensure_directory_exists
      File.open(full_path_from_current_attributes, 'wb') { |f| f.write(@uploaded_file.read) }
      @saved_full_path = full_path_from_current_attributes
      callback(:after_save_uploaded_file)
      return true
    end
    
  private
    
    def full_path_from_current_attributes
      path = self.class.upload_options[:directory].
          gsub(Regexp.new("^(#{RAILS_ROOT})?/?"), RAILS_ROOT + '/') + '/' +
          instance_directory + '/' + send(self.class.upload_options[:filename])
      path.gsub(/\/+/, '/')
    end
    
    def instance_directory
      dir = self.class.upload_options[:subdirectory]
      dir.nil? ? '' : send(dir).to_s.gsub(/[^a-z0-9_\/\\-]/i, '')
    end
    
    def rename_uploaded_file
      if file_exists? and full_path != full_path_from_current_attributes
        if File.file?(full_path_from_current_attributes)
          errors.add(self.class.upload_options[:filename], "is already taken by another file")
          return false
        end
        ensure_directory_exists
        File.rename(full_path, full_path_from_current_attributes)
        remove_empty_directory
        @saved_full_path = full_path_from_current_attributes
      end
    end
    
    def delete_uploaded_file
      if file_exists?
        File.delete(full_path)
        remove_empty_directory
        @saved_full_path = nil
      end
    end
    
    def ensure_directory_exists
      dir = File.dirname(full_path_from_current_attributes)
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
    end
    
    def remove_empty_directory(path = nil)
      dir = path || File.dirname(full_path)
      dir.gsub!(/(\/+\.\.?\/*)*$/, '')
      system_files = %w(Thumbs.db .DS_Store)
      if File.directory?(dir) and !File.symlink?(dir) and (Dir.entries(dir) - %w(. ..) - system_files).empty?
        system_files.each { |sys| File.delete("#{dir}/#{sys}") if File.exists?("#{dir}/#{sys}") }
        Dir.rmdir(dir)
        remove_empty_directory(dir.gsub(/\/+[^\/]*\/*$/, ''))
      end
    end
  
  end
end

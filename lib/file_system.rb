module ActsAsUploaded #:nodoc:
  module FileSystem
  
    # Returns the full system path (including +RAILS_ROOT+) to the uploaded file. If there is a saved
    # file associated with the record, this method will return the path to it, even if you change the
    # record's filename (the saved file will be renamed as appropriate if you then save the record).
    # Currently this location remembering feature only works if the path is a function only of the record's
    # own properties, not properties of any associated records. If no file exists, this method returns
    # the full path as specified by the record's current attributes.
    def full_path
      @saved_full_path || full_path_from_current_attributes
    end
    
    # Returns the path that should be used when inserting the saved file into a web page, if the file
    # is stored in the public directory. If it is saved outside the public directory, +nil+ is returned.
    # Remembers the path to saved files in the same way as +full_path+.
    def public_path
      public_regexp = Regexp.new("^#{RAILS_ROOT}/public")
      full_path =~ public_regexp ? full_path.gsub(public_regexp, '') : nil
    end
    
    # Returns +true+ if there is a saved file upload on the server for the record. Will continue to return
    # +true+ (assuming the file does exist) even if you change the record's filename (see +full_path+ for
    # further details).
    def file_exists?
      File.file?(full_path)
    end
    
    # Returns the size of the uploaded file in bytes. Returns +nil+ if no file exists.
    def filesize
      file_exists? ? File.size(full_path) : nil
    end
    
    # If there is a file saved on the server for the record, this method sets its permissions using the *nix
    # +chmod+ command. +permissions+ should be an octal-format integer. The default setting when saving files is <tt>0644</tt>.
    def chmod(permissions = nil)
      permissions ||= self.class.upload_options[:chmod]
      File.chmod(permissions, full_path) if file_exists?
    end
    
  private
    
    # Returns the full system path (including +RAILS_ROOT+) to the uploaded file, as specified by the
    # record's current attributes. Used by +full_path+ in the event that no file exists.
    def full_path_from_current_attributes
      path = self.class.upload_options[:directory].
          gsub(Regexp.new("^(#{RAILS_ROOT})?/?"), RAILS_ROOT + '/') + '/' +
          instance_directory + '/' + send(self.class.upload_options[:filename])
      path.gsub(/\/+/, '/')
    end
    
    # Returns the subdirectory in which to save the record's file.
    def instance_directory
      dir = self.class.upload_options[:subdirectory]
      dir.nil? ? '' : send(dir).to_s.gsub(/[^a-z0-9_\/\\-]/i, '')
    end
    
    # Saves the <tt>@uploaded_file</tt> attribute to the file system. <tt>@uploaded_file</tt> is set to
    # +nil+ after the save operation to prevent clashes on future saves. Called using the +after_save+
    # callback in <tt>ActiveRecord::Base</tt>.
    def save_uploaded_file
      return if @uploaded_file.nil?
      ensure_directory_exists
      File.open(full_path_from_current_attributes, 'wb') { |f| f.write(@uploaded_file.read) }
      chmod
      @saved_full_path = full_path_from_current_attributes
      @uploaded_file = nil if file_exists?
      callback(:after_save_uploaded_file)
    end
    
    # Renames the uploaded file stored in the filesystem if the record's attribute changes have caused
    # the file's path to change. Only works if the path is a function only of the record's own properties,
    # not of the properties of any associations. Called using the +before_update+ callback in <tt>ActiveRecord::Base</tt>.
    def rename_uploaded_file
      return unless @uploaded_file.nil?
      if file_exists? and full_path != full_path_from_current_attributes
        ensure_directory_exists
        File.rename(full_path, full_path_from_current_attributes)
        remove_empty_directory
        @saved_full_path = full_path_from_current_attributes
      end
    end
    
    # Removes the uploaded file from the filesystem when the record is destroyed.
    def delete_uploaded_file
      return unless file_exists?
      File.delete(full_path)
      remove_empty_directory
      @saved_full_path = nil
    end
    
    # Makes sure that the appropriate directory exists so the file can be saved into it.
    def ensure_directory_exists
      dir = File.dirname(full_path_from_current_attributes)
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
    end
    
    # Removes the file's directory if it is empty. Recusively deletes directories going up the tree until it
    # reaches a non-empty directory. <tt>Thumbs.db</tt> and <tt>.DS_Store</tt> files are removed if they
    # are the only contents of a directory.
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

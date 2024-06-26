module Pod
  class Deintegrator
    alias parent_delete_pods_file_references delete_pods_file_references

    def delete_pods_file_references(project)
      puts "Removing PLAYON Network."

      frameworks_group = project.groups.find { |group| group.name == 'Frameworks' }

      # Remove the framework references in the Xcode project.
      unless frameworks_group.nil?
        _remove_from_project frameworks_group, 'Flutter'
        _remove_from_project frameworks_group, 'App', :needs_env => true
      end

      # Remove the PLAYON Network SDK from the filesystem.
      path = "Frameworks/PLAYON-Network-SDK"
      FileUtils.remove_dir path if Dir.exist? path

      parent_delete_pods_file_references project
    end

    def _remove_from_project(frameworks_group, name, needs_env: false)
      path = "#{frameworks_path "$(CONFIGURATION)", "$(PLAYON_NETWORK_ENV)", :needs_env => needs_env}/#{name}.xcframework"

      file = frameworks_group.children.find do
        |child| child.path == path
      end

      file.remove_from_project unless file.nil?
    end
  end
end
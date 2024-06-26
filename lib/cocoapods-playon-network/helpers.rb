require 'xcodeproj'
require 'zip'

def unzip_file (file, destination)
  Zip::File.open(file) { |zip_file|
    zip_file.each { |f|
      f_path=File.join(destination, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path) unless File.exist?(f_path)
    }
  }
end

def open_xcode_project
  paths = Pathname.glob('*.xcodeproj')
  project_path = paths.first if paths.size == 1

  help! 'A valid Xcode project file is required.' unless project_path
  help! "#{project_path} does not exist." unless project_path.exist?
  unless project_path.directory? && (project_path + 'project.pbxproj').exist?
    help! "#{project_path} is not a valid Xcode project."
  end

  Xcodeproj::Project.open(project_path)
end

def framework_exist?(frameworks_group, path)
  frameworks_group.children.find { |child| child.path == path }
end

def get_frameworks_build_phase(target)
  name = "Embed Frameworks"
  embed_frameworks_build_phase = target.copy_files_build_phases.find { |phase| phase.name == name and phase.symbol_dst_subfolder_spec == :frameworks }

  if embed_frameworks_build_phase.nil?
    embed_frameworks_build_phase = target.new_copy_files_build_phase 'Embed Frameworks'
    embed_frameworks_build_phase.symbol_dst_subfolder_spec = :frameworks
  end

  embed_frameworks_build_phase
end

def _embed_and_sign(framework:, in_target:)
  target = in_target
  target.add_resources([framework])
  target.frameworks_build_phase.add_file_reference framework, true
  target.resources_build_phase.add_file_reference framework, true
  embed_frameworks_build_phase = get_frameworks_build_phase target
  build_file = embed_frameworks_build_phase.add_file_reference framework, true
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy'] }
end

def add_config_value(key, debug_value, release_value = nil, in_project:, in_target: nil)
  if release_value.nil?
    release_value = debug_value
  end

  target = target_for_project in_project, in_target

  _set_config_value _xcconfig_path(:debug, target.name), key, debug_value
  _set_config_value _xcconfig_path(:release, target.name), key, release_value
end

def _set_config_value(path, key, value)
  config = Xcodeproj::Config.new path
  config.merge! key => value
  config.save_as Pathname.new path
end

def _xcconfig_path(config, target_name)
  "Pods/Target Support Files/Pods-#{target_name}/Pods-#{target_name}.#{config}.xcconfig"
end

def target_for_project(project, target)
  if target.nil?
    project.targets.first
  else
    project.targets.find { |t| t.name == target }
  end
end

def add_framework(name, print_name, in_project:, in_target: nil, needs_env: false)
  frameworks_group = in_project.groups.find { |group| group.name == 'Frameworks' }
  path = "#{frameworks_path "$(CONFIGURATION)", "$(PLAYON_NETWORK_ENV)", :needs_env => needs_env}/#{name}.xcframework"

  unless frameworks_group.nil? or framework_exist? frameworks_group, path
    puts "Configuring project to use #{print_name} framework."

    framework = frameworks_group.new_reference path
    target = target_for_project in_project, in_target

    _embed_and_sign :framework => framework, :in_target => target
  end
end

def frameworks_path(config, env = nil, needs_env: nil)
  if env.nil? or needs_env == false
    return "Frameworks/PLAYON-Network-SDK/#{config}"
  end

  "Frameworks/PLAYON-Network-SDK/#{config}/#{env}"
end
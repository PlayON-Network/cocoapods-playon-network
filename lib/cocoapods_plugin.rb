require 'yaml'
require 'xcodeproj'
require 'open-uri'
require 'cocoapods-playon-network/deintegrate'
require 'cocoapods-playon-network/helpers'

# TODO - Waiting this fix https://github.com/CocoaPods/CocoaPods/issues/11277
#Pod::HooksManager.register('cocoapods-playon-network', :post_integrate) do |context|
#  puts "cocoapods-playon-network post_integrate!!!!"
#end

# Install all the pods needed to use the PLAYON Network games.
def use_playon_network
  #plugin "cocoapods-playon-network", :target => target
  puts "Installing PLAYON Network Pods"

  url = _configure_aws_credentials

  # Framework linking is handled by the plugin, not CocoaPods.
  # Add a dummy pod to satisfy `s.dependency 'Flutter'` plugin podspecs.
  pod 'Flutter', :path => File.join(File.dirname(__FILE__), 'Flutter'), :inhibit_warnings => true

  _download_framework 'App.xcframework.zip', url
  _download_flutter_framework url

  _get_all_plugins(url).each do |plugin|
    _pod_plugin plugin, url
  end

  pod 'PlayonNetworkSdk', :git => 'https://github.com/PlayON-Network/ios-sdk.git'
end

def post_install_playon_network(installer, version: "12.0")
  %w[Debug Profile Release].each do |config|
    _unzip_framework 'Flutter', 'Engine', config

    %w[Staging Production].each do |env|
      _unzip_framework 'App', 'Fantasy Game', config, env
    end
  end

  _configure_pods installer, version
end

# https://www.rubydoc.info/gems/xcodeproj
def post_integrate_playon_network(target: nil, debug: :staging, release: :production)
  project = open_xcode_project

  add_config_value 'PLAYON_NETWORK_ENV', debug.capitalize, release.capitalize, :in_project => project, :in_target => target

  add_framework 'Flutter', 'Engine', :in_project => project, :in_target => target
  add_framework 'App', 'Fantasy Game', :in_project => project, :in_target => target, :needs_env => true

  project.save
end

def _get_all_plugins(url)
  response = list_s3_objects :url => "#{url}/plugins"
  response.common_prefixes.map { |item| item[:prefix].split('/').last }
end

def _pod(name, url, configuration)
  pod name, :podspec => "#{url}/#{configuration}", :configuration => configuration
end

def _pod_plugin(plugin, url)
  pod plugin, :podspec => "#{url}/plugins/#{plugin}/#{plugin}.podspec"
end

def _configure_aws_credentials
  playon_network_params = YAML.load_file('playon-network.yaml')
  username = playon_network_params['username']
  access_key = playon_network_params["sdk"]["accessKey"]
  secret_key = playon_network_params["sdk"]["secretKey"]

  set_aws_credentials :region => 'eu-west-1', :access_key => access_key, :secret_key => secret_key

  "s3://playon-network-sdk/ios/#{username}"
end

def _download_flutter_framework(url)
  response = YAML.load get_s3_object :url => "#{url}/Flutter.yaml"

  %w[Debug Profile Release].each do |config|
    path = frameworks_path config
    FileUtils.mkdir_p path unless Dir.exist? path

    url = response[config]
    download = URI.open(url)
    IO.copy_stream(download, "#{path}/Flutter.xcframework.zip")
  end
end

def _download_framework(name, url)
  %w[Debug Profile Release].each do |config|
    %w[Staging Production].each do |env|
      path = frameworks_path config, env
      FileUtils.mkdir_p path unless Dir.exist? path

      get_s3_object :url => "#{url}/#{env.downcase}/#{config}-#{name}", :target => "#{path}/#{name}"
    end
  end
end

def _unzip_framework(name, print_name, config, env = nil)
  framework_name = "#{name}.xcframework"
  path = "#{frameworks_path config, env}"
  framework_zip = "#{path}/#{framework_name}.zip"

  unless env.nil?
    path = "#{path}/#{framework_name}"
  end

  if File.exist? framework_zip
    unless File.exist? path
      Dir.mkdir path
    end

    if env.nil?
      puts "Adding PLAYON Network #{print_name} Framework for #{config}"
    else
      puts "Adding PLAYON Network #{print_name} Framework for #{env}:#{config}"
    end

    unzip_file framework_zip, path
    FileUtils.rm_f framework_zip
  end
end

def _configure_pods(installer, version)
  puts "Configuring PLAYON Network Pods"

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'

      # https://stackoverflow.com/q/76590131
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'

      # https://stackoverflow.com/a/77513296
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < version.to_f
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = version
      end

      config.build_settings['OTHER_LDFLAGS'] = '$(inherited) "-framework Flutter"'

      path = "#{Dir.pwd}/#{frameworks_path config.type}/Flutter.xcframework"

      Dir.new(path).each_child do |xcframework_file|
        next if xcframework_file.start_with?('.') # Hidden file, possibly on external disk.
        if xcframework_file.end_with?('-simulator') # ios-arm64_x86_64-simulator
          config.build_settings['FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]'] = "\"#{path}/#{xcframework_file}\" $(inherited)"
        elsif xcframework_file.start_with?('ios-') # ios-arm64
          config.build_settings['FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]'] = "\"#{path}/#{xcframework_file}\" $(inherited)"
          # else Info.plist or another platform.
        end
      end
    end
  end
end

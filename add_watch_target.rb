#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

project_path = '/Users/markgentry/Projects/VoiceDay/VoiceDay.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if Watch target already exists
if project.targets.any? { |t| t.name == 'VoiceDay Watch App' }
  puts "Watch target already exists, removing it first..."
  watch_target = project.targets.find { |t| t.name == 'VoiceDay Watch App' }
  watch_target.remove_from_project
end

# Create Watch App target
puts "Creating Watch App target..."
watch_target = project.new_target(:watch2_app, 'VoiceDay Watch App', :watchos, '10.0')

# Get or create the Watch App group
watch_group = project.main_group.find_subpath('VoiceDay Watch App', true)
watch_group.set_source_tree('<group>')
watch_group.set_path('VoiceDay Watch App')

# Add source files to target
watch_files = [
  'VoiceDayWatchApp.swift',
  'ContentView.swift',
  'WatchConnectivityManager.swift',
  'WatchSpeechService.swift'
]

watch_files.each do |filename|
  file_path = "VoiceDay Watch App/#{filename}"
  if File.exist?("/Users/markgentry/Projects/VoiceDay/#{file_path}")
    file_ref = watch_group.new_file(filename)
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename}"
  else
    puts "Warning: #{filename} not found"
  end
end

# Add Assets.xcassets
assets_path = 'VoiceDay Watch App/Assets.xcassets'
if File.exist?("/Users/markgentry/Projects/VoiceDay/#{assets_path}")
  assets_ref = watch_group.new_file('Assets.xcassets')
  watch_target.resources_build_phase.add_file_reference(assets_ref)
  puts "Added Assets.xcassets"
end

# Configure build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gadfly.adhd.watchkitapp'
  config.build_settings['INFOPLIST_FILE'] = 'VoiceDay Watch App/Info.plist'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = ''  # Will be set by Xcode
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VoiceDay'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown'
  config.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'com.gadfly.adhd'
  config.build_settings['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

# Add frameworks
frameworks_group = project.main_group.find_subpath('Frameworks', true)

# Add WatchConnectivity framework
wc_ref = project.frameworks_group.new_file('System/Library/Frameworks/WatchConnectivity.framework', :sdk_root)
watch_target.frameworks_build_phase.add_file_reference(wc_ref)

# Add AVFoundation framework
av_ref = project.frameworks_group.new_file('System/Library/Frameworks/AVFoundation.framework', :sdk_root)
watch_target.frameworks_build_phase.add_file_reference(av_ref)

# Link Watch app to iOS app
ios_target = project.targets.find { |t| t.name == 'VoiceDay' }
if ios_target
  # Add Watch app as embedded content
  ios_target.build_configurations.each do |config|
    embed_phase = ios_target.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' }
    unless embed_phase
      embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
      embed_phase.dst_subfolder_spec = '16'  # Watch content
      embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
    end
  end

  # Add dependency
  ios_target.add_dependency(watch_target)
  puts "Added Watch app as dependency of iOS app"
end

# Create scheme for Watch app
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(watch_target)
scheme.set_launch_target(watch_target)
scheme.save_as(project_path, 'VoiceDay Watch App')
puts "Created scheme for Watch app"

project.save
puts "Project saved successfully!"
puts ""
puts "Next steps:"
puts "1. Open Xcode"
puts "2. Select the VoiceDay Watch App scheme"
puts "3. Set your Development Team in Signing & Capabilities"
puts "4. Build and run on your Watch"

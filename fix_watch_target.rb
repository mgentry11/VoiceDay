#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/markgentry/Projects/VoiceDay/VoiceDay.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Clean up any existing Watch target and references
project.targets.each do |target|
  if target.name == 'VoiceDay Watch App'
    puts "Removing existing Watch target..."
    target.remove_from_project
  end
end

# Clean up orphaned dependencies
project.targets.each do |target|
  target.dependencies.each do |dep|
    if dep.target.nil?
      dep.remove_from_project
    end
  end
end

# Remove any existing Watch group file references
project.main_group.children.each do |child|
  if child.respond_to?(:name) && child.name == 'VoiceDay Watch App'
    child.remove_from_project
  end
end

project.save
puts "Cleaned up project"

# Reopen project fresh
project = Xcodeproj::Project.open(project_path)

# Create a new native target for watchOS
puts "Creating new Watch App target..."
watch_target = project.new_target(:application, 'VoiceDay Watch App', :watchos, '10.0')

# Create the Watch App group
watch_group = project.main_group.new_group('VoiceDay Watch App', 'VoiceDay Watch App')

# Add source files
['VoiceDayWatchApp.swift', 'ContentView.swift', 'WatchConnectivityManager.swift', 'WatchSpeechService.swift'].each do |filename|
  full_path = "/Users/markgentry/Projects/VoiceDay/VoiceDay Watch App/#{filename}"
  if File.exist?(full_path)
    file_ref = watch_group.new_reference(filename)
    watch_target.source_build_phase.add_file_reference(file_ref)
    puts "Added source: #{filename}"
  end
end

# Add Assets
assets_ref = watch_group.new_reference('Assets.xcassets')
watch_target.resources_build_phase.add_file_reference(assets_ref)
puts "Added Assets.xcassets"

# Configure build settings properly for watchOS app
watch_target.build_configurations.each do |config|
  settings = config.build_settings

  # Basic settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gadfly.adhd.watchkitapp'
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SWIFT_VERSION'] = '5.0'
  settings['SDKROOT'] = 'watchos'
  settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  settings['TARGETED_DEVICE_FAMILY'] = '4'  # Watch

  # Use generated Info.plist
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VoiceDay'
  settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'com.gadfly.adhd'
  settings['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'

  # Signing
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['SKIP_INSTALL'] = 'YES'

  # Remove any problematic settings
  settings.delete('INFOPLIST_FILE')

  puts "Configured #{config.name} build settings"
end

# Add WatchConnectivity and AVFoundation frameworks
wc_ref = project.frameworks_group.new_file('System/Library/Frameworks/WatchConnectivity.framework', :sdk_root)
watch_target.frameworks_build_phase.add_file_reference(wc_ref)

av_ref = project.frameworks_group.new_file('System/Library/Frameworks/AVFoundation.framework', :sdk_root)
watch_target.frameworks_build_phase.add_file_reference(av_ref)
puts "Added frameworks"

# Save first before adding dependencies
project.save
puts "Saved project"

# Reopen and add dependency
project = Xcodeproj::Project.open(project_path)
ios_target = project.targets.find { |t| t.name == 'VoiceDay' }
watch_target = project.targets.find { |t| t.name == 'VoiceDay Watch App' }

if ios_target && watch_target
  # Add dependency
  ios_target.add_dependency(watch_target)
  puts "Added Watch app as dependency of iOS app"
end

# Create scheme
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(watch_target)
scheme.set_launch_target(watch_target)
scheme.save_as(project_path, 'VoiceDay Watch App')
puts "Created scheme"

project.save
puts ""
puts "Done! Watch App target configured."
puts ""
puts "Next steps in Xcode:"
puts "1. Open the project"
puts "2. Select 'VoiceDay Watch App' scheme"
puts "3. Go to Signing & Capabilities and set your Team"
puts "4. Build and run on Watch"

#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/markgentry/Projects/VoiceDay/VoiceDay.xcodeproj'
project = Xcodeproj::Project.open(project_path)

ios_target = project.targets.find { |t| t.name == 'VoiceDay' }
services_group = project.main_group.find_subpath('VoiceDay/Services', false)
views_group = project.main_group.find_subpath('VoiceDay/Views', false)

# Add TimesheetService
file = 'TimesheetService.swift'
unless services_group.files.any? { |f| f.path == file }
  ref = services_group.new_reference(file)
  ios_target.source_build_phase.add_file_reference(ref)
  puts "Added #{file}"
end

# Add TimesheetView
file = 'TimesheetView.swift'
unless views_group.files.any? { |f| f.path == file }
  ref = views_group.new_reference(file)
  ios_target.source_build_phase.add_file_reference(ref)
  puts "Added #{file}"
end

project.save
puts "Done!"

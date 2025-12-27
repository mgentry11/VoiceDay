#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/markgentry/Projects/VoiceDay/VoiceDay.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the iOS target
ios_target = project.targets.find { |t| t.name == 'VoiceDay' }

# Find or create groups
services_group = project.main_group.find_subpath('VoiceDay/Services', false)
views_group = project.main_group.find_subpath('VoiceDay/Views', false)

# Add MorningChecklistService.swift
service_file = 'MorningChecklistService.swift'
service_path = "Services/#{service_file}"
unless services_group.files.any? { |f| f.path == service_file }
  file_ref = services_group.new_reference(service_file)
  ios_target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{service_file}"
end

# Add MorningChecklistView.swift
view_file1 = 'MorningChecklistView.swift'
unless views_group.files.any? { |f| f.path == view_file1 }
  file_ref = views_group.new_reference(view_file1)
  ios_target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{view_file1}"
end

# Add ManageSelfChecksView.swift
view_file2 = 'ManageSelfChecksView.swift'
unless views_group.files.any? { |f| f.path == view_file2 }
  file_ref = views_group.new_reference(view_file2)
  ios_target.source_build_phase.add_file_reference(file_ref)
  puts "Added #{view_file2}"
end

project.save
puts "Project saved!"

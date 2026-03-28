require 'xcodeproj'

project_path = 'Faro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Add ElevenLabsConvService.swift
services_group = project.main_group.find_subpath('Faro/Services', true)
service_file = services_group.find_file_by_path('ElevenLabsConvService.swift') || 
               services_group.new_file('ElevenLabsConvService.swift')

# Add IntakeChoiceView.swift
views_group = project.main_group.find_subpath('Faro/Views', true)
choice_view = views_group.find_file_by_path('IntakeChoiceView.swift') || 
              views_group.new_file('IntakeChoiceView.swift')

# Add VoiceIntakeView.swift
voice_view = views_group.find_file_by_path('VoiceIntakeView.swift') || 
             views_group.new_file('VoiceIntakeView.swift')

# Find the main target
target = project.targets.first

# Add files to the target build phases if not already there
source_build_phase = target.source_build_phase

unless source_build_phase.files_references.include?(service_file)
  source_build_phase.add_file_reference(service_file)
end

unless source_build_phase.files_references.include?(choice_view)
  source_build_phase.add_file_reference(choice_view)
end

unless source_build_phase.files_references.include?(voice_view)
  source_build_phase.add_file_reference(voice_view)
end

project.save
puts "Added ElevenLabsConvService.swift, IntakeChoiceView.swift, and VoiceIntakeView.swift to project."

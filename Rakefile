APPSPEC = 'Lamp.appspec'

require 'rubygems'
require 'hotcocoa/rake_tasks'
require 'fileutils'

task :default => :run

# Add your own tasks here

desc 'Create a custom the dmg archive from the application bundle'
task :customdmg => :deploy do
  app_name = builder.spec.name
  rm_rf "#{app_name}.dmg"
  sh "hdiutil create #{app_name}.dmg -quiet -volname #{app_name} -srcdir #{app_name}.app -srcdir XTension.app -format UDZO -imagekey zlib-level=9"
end

desc 'Create a custom application bundle'
task :customdeploy => :deploy do
  #FileUtils.cp_r '../xtension', 'Lamp.app/Contents/Resources'
end


namespace :version do
  desc 'Display current versions'
  task show: :environment do
    puts "Chatwoot Version: #{Chatwoot.config[:version]}"
    puts "Custom Version:   #{Chatwoot.config[:custom_version]}"
    puts "Git SHA:          #{GIT_HASH}"
  end

  desc 'Bump custom fork version (type=major|minor|patch)'
  task bump: :environment do
    version_type = ENV['type'] || 'patch'

    # Read current version
    current = Chatwoot.config[:custom_version]
    major, minor, patch = current.split('.').map(&:to_i)

    # Bump version
    case version_type
    when 'major'
      major += 1
      minor = 0
      patch = 0
    when 'minor'
      minor += 1
      patch = 0
    when 'patch'
      patch += 1
    end

    new_version = "#{major}.#{minor}.#{patch}"

    puts "Bumping custom version: #{current} → #{new_version}"

    # Update config/app.yml
    app_config = File.read('config/app.yml')
    app_config.gsub!(/custom_version: ['"]#{Regexp.escape(current)}['"]/,
                     "custom_version: '#{new_version}'")
    File.write('config/app.yml', app_config)

    # Update VERSION_CUSTOM
    File.write('VERSION_CUSTOM', "#{new_version}\n")

    puts "✓ Version bumped successfully to #{new_version}"
    puts "Don't forget to:"
    puts "  1. Commit these changes"
    puts "  2. Create a git tag: git tag -a v#{new_version} -m 'Release v#{new_version}'"
    puts "  3. Push with tags: git push origin develop --tags"
  end

  desc 'Update Chatwoot upstream version'
  task update_chatwoot: :environment do
    version = ENV['version']
    raise "Please specify version: rake version:update_chatwoot version=4.5.3" unless version

    # Update config/app.yml
    app_config = File.read('config/app.yml')
    current = Chatwoot.config[:version]
    app_config.gsub!(/version: ['"]#{Regexp.escape(current)}['"]/,
                     "version: '#{version}'")
    File.write('config/app.yml', app_config)

    # Update VERSION_CW
    File.write('VERSION_CW', "#{version}\n")

    # Update package.json
    package = JSON.parse(File.read('package.json'))
    package['version'] = version
    File.write('package.json', JSON.pretty_generate(package))

    puts "✓ Chatwoot upstream version updated to #{version}"
  end
end

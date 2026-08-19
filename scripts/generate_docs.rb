#!/usr/bin/env ruby
# Automated Documentation Generator for Ansible Roles

require 'yaml'
require 'fileutils'

base_dir = File.expand_path("..", __dir__)
roles_dir = File.join(base_dir, "roles")
docs_dir = File.join(base_dir, "docs")
FileUtils.mkdir_p(docs_dir)

index_md = "# Component Documentation\n\nThis directory contains auto-generated documentation for all Ansible roles in this collection, parsed directly from their `meta/argument_specs.yml` declarations.\n\n## Available Roles\n\n"

roles = Dir.entries(roles_dir).select { |entry| File.directory?(File.join(roles_dir, entry)) && !(entry == '.' || entry == '..') }.sort

roles.each do |role|
  specs_file = File.join(roles_dir, role, "meta", "argument_specs.yml")
  next unless File.exist?(specs_file)

  begin
    data = YAML.load_file(specs_file)
    next unless data && data['argument_specs'] && data['argument_specs']['main']

    main_specs = data['argument_specs']['main']
    short_desc = main_specs['short_description'] || 'No description provided.'
    desc = main_specs['description'] || ''
    desc = desc.join(" ") if desc.is_a?(Array)

    doc = "# Role: `#{role}`\n\n"
    doc += "**#{short_desc}**\n\n"
    doc += "#{desc}\n\n" unless desc.empty?

    options = main_specs['options'] || {}
    if options.any?
      doc += "## Role Variables\n\n"
      doc += "| Variable | Type | Required | Default | Description |\n"
      doc += "|---|---|---|---|---|\n"
      options.each do |var_name, var_details|
        v_type = var_details['type'] || 'str'
        v_req = var_details['required'].to_s == 'true' ? 'true' : 'false'
        v_def = var_details['default'].nil? ? 'None' : var_details['default'].to_s
        v_desc = var_details['description'] || ''
        v_desc = v_desc.join(" ") if v_desc.is_a?(Array)
        
        doc += "| `#{var_name}` | `#{v_type}` | #{v_req} | `#{v_def}` | #{v_desc} |\n"
      end
    else
      doc += "## Role Variables\n\n*This role accepts no customizable variables.*\n"
    end

    File.write(File.join(docs_dir, "#{role}.md"), doc)
    index_md += "- [#{role}](#{role}.md): #{short_desc}\n"

  rescue => e
    puts "Error parsing #{specs_file}: #{e.message}"
  end
end

File.write(File.join(docs_dir, "README.md"), index_md)
puts "Successfully generated documentation for #{roles.length} roles in docs/"

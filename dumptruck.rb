#!/usr/bin/env ruby
require 'yaml'
require 'optparse'
require "readline"

# TODO: The system: setting in yaml is ignored.  Only postgres available right now
# TODO: The -f option needs implemented as the filename passthrough
# TODO: Implement connection string dumps
# TODO: Validate cmdline options.  Cannot choose both backup and restore, etc
# TODO: Users shouldn't use the -t option in the options.  Tables will be handled in the tables section

class DumpTruck

  def initialize(args, stdin)
    @config = YAML.load_file('dumptruck.yml')
    @cmd_line_options = parse_options
    @profile_config = read_profile_config
    @prompt_first = false
  end

  def run
    if @cmd_line_options[:backup]
      execute_db_backup
    elsif @cmd_line_options[:restore]
      execute_db_restore
    else
      raise "You must specify with -r ( for restore ) or -b (for backup)"
    end
  end

  def execute_db_restore
    cmd = "pg_restore"
    cmd += " -d #{@profile_config['schema_name']}"
    cmd += " #{@profile_config['restore']['options']} "
    cmd += " #{@profile_config['output_path']}/#{restore_filename()}"

    if @prompt_first
      command = nil
      puts "About to execute: \n#{cmd}\n Are you sure? ('y/n') "
      command = Readline.readline("> ",true)
      system(cmd) unless command == 'n' || command == 'no'
    else
      puts "Restoring: #{cmd}"
      system(cmd)
    end

  end

  def execute_db_backup
    cmd = "pg_dump"
    cmd += " #{@profile_config['schema_name']} #{@profile_config['backup']['options']}"
    cmd += table_options
    cmd += " -f #{backup_filename()}"

    puts "Dumping: #{cmd}"
    system(cmd)
  end

  def parse_options
    options = {}
    option_parser = OptionParser.new do |opts|
      opts.on("-p PROFILE", "Specify profile to use. *Overrides default specified in the config") do |p|
        options[:profile] = p
      end
      opts.on("-b", "--backup", "Use the backup tool") do
        options[:backup] = true
      end
      opts.on("-r", "--restore", "Use the restore tool") do
        options[:restore] = true
      end
      opts.on("-f FILENAME", "Passthrough to the cmd line tool. *Overrides default specified in the config") do |fn|
        options[:filename] = fn
      end
    end

    option_parser.parse!
    options
  end

  def read_profile_config
    profile_name = decide_profile()
    @config['profiles'].select{ |profile| profile['name'] == profile_name }.first
  end

  def decide_profile
    # if -p given use that profile
    return @cmd_line_options[:profile] unless @cmd_line_options[:profile].nil?
    # no -p given. look for default profile
    default_profile = @config['profiles'].select{ |profile| profile['default'] == "true" }.first
    if default_profile.nil?
      raise "Must with include a -p PROFILE or set a default profile in the config"
    else
      return default_profile['name']
    end
  end

  def restore_filename
    restore_file_name = nil

    if @profile_config['restore']['filename'] == 'auto'
      @prompt_first = true
      regex ="^#{@profile_config['backup']['filename']}-#{@profile_config['name']}-(\\d+-\\d+-\\d+T\\d+-\\d+).dump$"
      restore_file_name = find_recent_file(regex, '%m-%d-%yT%H-%M')
    elsif @profile_config['restore']['filename'] == 'ey'
      @prompt_first = true
      schema_sans_environment = @profile_config['schema_name'].gsub(/(\w+)_\w+/, "\\1")
      regex ="^#{schema_sans_environment}.(\\d+-\\d+-\\d+T\\d+-\\d+-\\d+).dump$"
      restore_file_name = find_recent_file(regex, '%Y-%m-%dT%H-%M-%S')
    else
      restore_file_name = @profile_config['restore']['filename']
    end

    raise "Could not find file to restore.  Try manually defining with the -f cmd line opt" if restore_file_name.nil?

    restore_file_name
  end

  def find_recent_file(regex_filename_matcher, timestamp_format)
    latest_match_timestamp = nil
    latest_matched_filename = nil

    Dir.foreach("#{@profile_config['output_path']}") do |filename|
      matcher = Regexp.new(regex_filename_matcher).match(filename)
      backup_time = matcher[1] rescue nil
      unless backup_time.nil?
        file_timestamp = DateTime.strptime(backup_time, timestamp_format).strftime("%m-%d-%yT%H-%M")
        if latest_match_timestamp.nil? || latest_match_timestamp < file_timestamp
          latest_matched_filename = filename
          latest_match_timestamp = file_timestamp
        end
      end
    end

    latest_matched_filename
  end

  def backup_filename
    filename = " #{@profile_config['output_path']}"

    if @profile_config['backup']['filename'].nil?
      filename += "/pgt"    # default a file name if one isn't in the config
    else
      filename += "/#{@profile_config['backup']['filename']}"
    end

    filename += "-#{@profile_config['name']}"
    filename += "-#{Time.now.strftime("%m-%d-%yT%H-%M")}"
    filename += ".dump"
    filename
  end

  def table_options
    table_names = requested_tables_names
    cmd = ""

    unless table_names.nil?
      case @profile_config['tables']['style']
      when 'whitelist'
        table_names.each{|table_name| cmd += " -t #{table_name}" }
      when 'blacklist'
        table_names.each{|table_name| cmd += " -T #{table_name}" }
      else
        raise "Invalid backup style given. Valid options are: whitelist or blacklist"
      end
    end

    cmd
  end

  def requested_tables_names
    tables = @profile_config['tables']
    tables = tables['names'].split(',') unless tables.nil?
    tables
  end

end

app = DumpTruck.new(ARGV, STDIN)
app.run

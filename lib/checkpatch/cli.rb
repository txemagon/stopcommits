require 'optparse'
require 'yaml'

module Checkpatch
  class CLI
    def self.execute(stdout, arguments=[])

      options = {
        :repository_path     => '.',
        :extensions_file     => '~/.stopcommits/source.ext',
        :svn_look            => `which svnlook`.chomp,
        :deprecated_classes  => '~/.stopcommits/deprecated.yaml',
        :components          => '~/.stopcommits/components.yaml',
        :setup_file          => '~/.stopcommits/config.yaml',
        :hooking             => false
      }

      changed_options = Hash.new

      parser = OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^          /,'')
          Checks in a bunch of files for a list of deprecated classes.

          Usage: #{File.basename($0)} -t <transaction> [options]

          Transaction is only mandatory when in --hooking environment.

          Options are:
        BANNER
        opts.separator ""
        opts.on("-s", "--setup-file SETUP_FILE", String,
                "Default: ~/.stopcommits/config.yaml") { |arg| changed_options[:setup_file] = options[:setup_file] = arg }
        opts.on("-r", "--repository-path PATH", String,
                "Base path for the source code.",
                "Default: current path") { |arg| changed_options[:repository_path] = options[:repository_path] = arg }
        opts.on("-t", "--transaction TRANSACTION", String,
                "Version control transaction number.") { |arg| changed_options[:transaction] = options[:transaction] = arg } 
        opts.on("-e", "--extensions-file EXT_FILE", String,
                "Specify the absolut pathname to the extensions file.",
                "Put one extension per line. You can use regular expressions (not globbing) if you want.",
                "Default: ~/.stopcommits/source.ext") { |arg| changed_options[:extensions_file] = options[:extensions_file] = arg }
        opts.on("-c", "--components COMPONENT_FILE", String,
                "Specify the absolut pathname to the file with the list of components. Use YAML.",
                "Default: ~/.stopcommits/components.yaml") { |arg| changed_options[:components] = options[:components] = arg }
        opts.on("-d", "--deprecated BLACKLIST", String,
                "File with the list of deprecated classes, written in YAML.",
                "Default: ~/.stopcommits/deprecated.yaml") { |arg| changed_options[:deprecated_classes] = options[:deprecated_classes] = arg }
        opts.on("-l", "--svnlook SVN_COMMAND", String,
                "svnlook executable.",
                "Default: `which svnlook`"){ |arg| changed_options[:svn_look] = options[:svn_look] = arg }
        opts.on("-g", "--[no-]hooking",
                "Specify weather the app is run as a svn-hook or not.",
                "Default: false"){ |arg| changed_options[:hooking] = options[:hooking] = arg }

        opts.on("-h", "--help",
                "Show this help message.") { stdout.puts opts; exit }
        opts.parse!(arguments)

        file_options = YAML::load(File.open(File.expand_path(options[:setup_file])))
        file_options.each do |k,v|
          options[k] = v unless changed_options.has_key?(k)
        end

        mandatory_options = %w( transaction ) if options[:hooking] 
        if mandatory_options && mandatory_options.find { |option| options[option.to_sym].nil? }
          stdout.puts opts
          $stderr.puts "Mandatory arguments missing."
          exit(1)
        end
      end

      checker = Checkpatch::Checker.new(options)
      checker.parse
      checker.print_errors
      checker.validate
    end
  end
end

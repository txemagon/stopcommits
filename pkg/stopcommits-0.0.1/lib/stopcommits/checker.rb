require 'yaml'

module Checkpatch
  class Checker

    # When HOOKING this software is used as an svn hook
    HOOKING = false

    def initialize(options)
      @options    = options
      @extensions = extensions_for(options[:extensions_file])
      @deprecated = yaml_load(options[:deprecated_classes])
      @components = yaml_load(options[:components])
      @errors     = Hash.new { |hash, key| hash[key] = Array.new }
    end

    def parse
      @last_commit = get_transaction_files.select do |file|   
        @extensions.inject(false) { |result, ext| result || Regexp.new(ext) =~ file }
      end
      @last_commit.each do |filename|
        @deprecated.each_key do |deprecated_class| 
           if Regexp.new("\\b#{ deprecated_class }\\b") =~ `svnlook cat #{@options[:repository_path]} #{filename}`
             @errors[filename] << deprecated_class
           end
        end
      end
    end

    def validate(errors=@errors)
      critical_error "At least one of the files were tainted." unless errors.empty?
    end


    def print_errors(errors=@errors)
      unless errors.empty?
        $stderr. puts 
        errors.each do |filename, wrong_classes|
          $stderr.puts problems = "#{filename}: Problems encountered."
          $stderr. puts "=" * problems.size
          wrong_classes.each do |deprecated|
            $stderr. puts "#{deprecated} class."
            $stderr. puts "#{@deprecated[deprecated]["error"]}."
            $stderr. puts "Use better:"
            @deprecated[deprecated]["components"].each do |component| 
              $stderr. puts "#{component}#{ (" at: " + @components[component]["location"]) if @components[component] and @components[component]["location"] }"
              $stderr. puts "#{@components[component]["description"]}" if @components[component] and @components[component]["description"]
            end
            $stderr. puts 
          end
          $stderr. puts 
        end
      end
    end

    private

    def extensions_for(file)
      extensions = []
      begin
        File.open(File.expand_path file, "r").each do |line|
          extensions << line.chomp.strip unless line.chomp.strip[0] == ?# or line.chomp.strip.empty?
        end
      rescue
        critical_error "Invalid extensions file at #{file}."
      end
      extensions
    end

    def get_transaction_files
      begin
        files = (`#{@options[:svn_look]} changed #{File.expand_path(@options[:repository_path])} #{ ("-t " + @options[:transaction]) if HOOKING } | tr -s ' ' ' ' | cut -f2 -d ' '`).split("\n")
        raise "svnlook error" if files.empty?
        files
      rescue
        critical_error "svnlook didn't go well."
      end
    end

    def yaml_load(filename)
      begin
        YAML::load(File.open(File.expand_path(filename)))
      rescue
        critical_error "Impossible to load #{filename}"
      end
    end

    def critical_error(msg)
      $stderr.puts msg
      exit(1)
    end

  end
end

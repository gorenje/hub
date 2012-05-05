module Hub
  module Commands
    # $ hub hub standalone
    # Prints the "standalone" version of hub for an easy, memorable
    # installation sequence:
    #
    # $ gem install hub
    # $ hub hub standalone > ~/bin/hub && chmod 755 ~/bin/hub
    # $ gem uninstall hub
    def hub(args)
      return help(args) unless args[1] == 'standalone'
      require 'hub/standalone'
      Hub::Standalone.build $stdout
      exit
    rescue LoadError
      abort "hub is already running in standalone mode."
    rescue Errno::EPIPE
      exit # ignore broken pipe
    end

    def alias(args)
      shells = %w[bash zsh sh ksh csh fish]

      script = !!args.delete('-s')
      shell = args[1] || ENV['SHELL']
      abort "hub alias: unknown shell" if shell.nil? or shell.empty?
      shell = File.basename shell

      unless shells.include? shell
        $stderr.puts "hub alias: unsupported shell"
        warn "supported shells: #{shells.join(' ')}"
        abort
      end

      if script
        puts "alias git=hub"
        if 'zsh' == shell
          puts "if type compdef >/dev/null; then"
          puts "   compdef hub=git"
          puts "fi"
        end
      else
        profile = case shell
          when 'bash' then '~/.bash_profile'
          when 'zsh'  then '~/.zshrc'
          when 'ksh'  then '~/.profile'
          else
            'your profile'
          end

        puts "# Wrap git automatically by adding the following to #{profile}:"
        puts
        puts 'eval "$(hub alias -s)"'
      end

      exit
    end
  end
end

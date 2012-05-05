module Hub
  # The Commands module houses the git commands that hub
  # lovingly wraps. If a method exists here, it is expected to have a
  # corresponding git command which either gets run before or after
  # the method executes.
  #
  # The typical flow is as follows:
  #
  # 1. hub is invoked from the command line:
  #    $ hub clone rtomayko/tilt
  #
  # 2. The Hub class is initialized:
  #    >> hub = Hub.new('clone', 'rtomayko/tilt')
  #
  # 3. The method representing the git subcommand is executed with the
  #    full args:
  #    >> Commands.clone('clone', 'rtomayko/tilt')
  #
  # 4. That method rewrites the args as it sees fit:
  #    >> args[1] = "git://github.com/" + args[1] + ".git"
  #    => "git://github.com/rtomayko/tilt.git"
  #
  # 5. The new args are used to run `git`:
  #    >> exec "git", "clone", "git://github.com/rtomayko/tilt.git"
  #
  # An optional `after` callback can be set. If so, it is run after
  # step 5 (which then performs a `system` call rather than an
  # `exec`). See `Hub::Args` for more information on the `after` callback.
  module Commands
    # We are a blank slate.
    instance_methods.each { |m| undef_method(m) unless m =~ /(^__|send|to\?$)/ }
    extend self

    # provides git interrogation methods
    extend Context

    NAME_RE = /\w[\w.-]*/
    OWNER_RE = /[a-zA-Z0-9-]+/
    NAME_WITH_OWNER_RE = /^(?:#{NAME_RE}|#{OWNER_RE}\/#{NAME_RE})$/

    CUSTOM_COMMANDS = %w[alias create browse compare fork pull-request]

    def run(args)
      slurp_global_flags(args)

      # Hack to emulate git-style
      args.unshift 'help' if args.empty?

      cmd = args[0]
      if expanded_args = expand_alias(cmd)
        cmd = expanded_args[0]
        expanded_args.concat args[1..-1]
      end

      respect_help_flags(expanded_args || args) if custom_command? cmd

      # git commands can have dashes
      cmd = cmd.sub(/(\w)-/, '\1_')
      if method_defined?(cmd) and cmd != 'run'
        args.replace expanded_args if expanded_args
        send(cmd, args)
      end
    rescue Errno::ENOENT
      if $!.message.include? "No such file or directory - git"
        abort "Error: `git` command not found"
      else
        raise
      end
    end

    # $ hub version
    # > git version
    # (print hub version)
    def version(args)
      args.after 'echo', ['hub version', Version]
    end
    alias_method "--version", :version

    # $ hub help
    # (print improved help text)
    def help(args)
      command = args.words[1]

      if command == 'hub'
        puts hub_manpage
        exit
      elsif command.nil? && !args.has_flag?('-a', '--all')
        ENV['GIT_PAGER'] = '' unless args.has_flag?('-p', '--paginate') # Use `cat`.
        puts improved_help_text
        exit
      end
    end
    alias_method "--help", :help

  private
    #
    # Helper methods are private so they cannot be invoked
    # from the command line.
    #

    def custom_command? cmd
      CUSTOM_COMMANDS.include? cmd
    end

    # Show short usage help for `-h` flag, and open man page for `--help`
    def respect_help_flags args
      return if args.size > 2
      case args[1]
      when '-h'
        pattern = /(git|hub) #{Regexp.escape args[0].gsub('-', '\-')}/
        hub_raw_manpage.each_line { |line|
          if line =~ pattern
            $stderr.print "Usage: "
            $stderr.puts line.gsub(/\\f./, '').gsub('\-', '-')
            abort
          end
        }
        abort "Error: couldn't find usage help for #{args[0]}"
      when '--help'
        puts hub_manpage
        exit
      end
    end

    # The text print when `hub help` is run, kept in its own method
    # for the convenience of the author.
    def improved_help_text
      <<-help
usage: git [--version] [--exec-path[=<path>]] [--html-path] [--man-path] [--info-path]
           [-p|--paginate|--no-pager] [--no-replace-objects] [--bare]
           [--git-dir=<path>] [--work-tree=<path>] [--namespace=<name>]
           [-c name=value] [--help]
           <command> [<args>]

Basic Commands:
   init       Create an empty git repository or reinitialize an existing one
   add        Add new or modified files to the staging area
   rm         Remove files from the working directory and staging area
   mv         Move or rename a file, a directory, or a symlink
   status     Show the status of the working directory and staging area
   commit     Record changes to the repository

History Commands:
   log        Show the commit history log
   diff       Show changes between commits, commit and working tree, etc
   show       Show information about commits, tags or files

Branching Commands:
   branch     List, create, or delete branches
   checkout   Switch the active branch to another branch
   merge      Join two or more development histories (branches) together
   tag        Create, list, delete, sign or verify a tag object

Remote Commands:
   clone      Clone a remote repository into a new directory
   fetch      Download data, tags and branches from a remote repository
   pull       Fetch from and merge with another repository or a local branch
   push       Upload data, tags and branches to a remote repository
   remote     View and manage a set of remote repositories

Advanced commands:
   reset      Reset your staging area or working directory to another point
   rebase     Re-apply a series of patches in one branch onto another
   bisect     Find by binary search the change that introduced a bug
   grep       Print files with lines matching a pattern in your codebase

See 'git help <command>' for more information on a specific command.
help
    end

    # Extract global flags from the front of the arguments list.
    # Makes sure important ones are supplied for calls to subcommands.
    #
    # Known flags are:
    #   --version --exec-path=<path> --html-path
    #   -p|--paginate|--no-pager --no-replace-objects
    #   --bare --git-dir=<path> --work-tree=<path>
    #   -c name=value --help
    #
    # Special: `--version`, `--help` are replaced with "version" and "help".
    # Ignored: `--exec-path`, `--html-path` are kept in args list untouched.
    def slurp_global_flags(args)
      flags = %w[ --noop -c -p --paginate --no-pager --no-replace-objects --bare --version --help ]
      flags2 = %w[ --exec-path= --git-dir= --work-tree= ]

      # flags that should be present in subcommands, too
      globals = []
      # flags that apply only to main command
      locals = []

      while args[0] && (flags.include?(args[0]) || flags2.any? {|f| args[0].index(f) == 0 })
        flag = args.shift
        case flag
        when '--noop'
          args.noop!
        when '--version', '--help'
          args.unshift flag.sub('--', '')
        when '-c'
          # slurp one additional argument
          config_pair = args.shift
          # add configuration to our local cache
          key, value = config_pair.split('=', 2)
          git_reader.stub_config_value(key, value)

          globals << flag << config_pair
        when '-p', '--paginate', '--no-pager'
          locals << flag
        else
          globals << flag
        end
      end

      git_reader.add_exec_flags(globals)
      args.add_exec_flags(globals)
      args.add_exec_flags(locals)
    end

    # Handles common functionality of browser commands like `browse`
    # and `compare`. Yields a block that returns params for `github_url`.
    def browse_command(args)
      url_only = args.delete('-u')
      warn "Warning: the `-p` flag has no effect anymore" if args.delete('-p')
      url = yield

      args.executable = url_only ? 'echo' : browser_launcher
      args.push url
    end

    # Returns the terminal-formatted manpage, ready to be printed to
    # the screen.
    def hub_manpage
      abort "** Can't find groff(1)" unless command?('groff')

      require 'open3'
      out = nil
      Open3.popen3(groff_command) do |stdin, stdout, _|
        stdin.puts hub_raw_manpage
        stdin.close
        out = stdout.read.strip
      end
      out
    end

    # The groff command complete with crazy arguments we need to run
    # in order to turn our raw roff (manpage markup) into something
    # readable on the terminal.
    def groff_command
      "groff -Wall -mtty-char -mandoc -Tascii"
    end

    # Returns the raw hub manpage. If we're not running in standalone
    # mode, it's a file sitting at the root under the `man`
    # directory.
    #
    # If we are running in standalone mode the manpage will be
    # included after the __END__ of the file so we can grab it using
    # DATA.
    def hub_raw_manpage
      if File.exists? file = File.dirname(__FILE__) + '/../../man/hub.1'
        File.read(file)
      else
        DATA.read
      end
    end

    # All calls to `puts` in after hooks or commands are paged,
    # git-style.
    def puts(*args)
      page_stdout
      super
    end

    # http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
    def page_stdout
      return if not $stdout.tty? or windows?

      read, write = IO.pipe

      if Kernel.fork
        # Parent process, become pager
        $stdin.reopen(read)
        read.close
        write.close

        # Don't page if the input is short enough
        ENV['LESS'] = 'FSRX'

        # Wait until we have input before we start the pager
        Kernel.select [STDIN]

        pager = ENV['GIT_PAGER'] ||
          `git config --get-all core.pager`.split.first || ENV['PAGER'] ||
          'less -isr'

        pager = 'cat' if pager.empty?

        exec pager rescue exec "/bin/sh", "-c", pager
      else
        # Child process
        $stdout.reopen(write)
        $stderr.reopen(write) if $stderr.tty?
        read.close
        write.close
      end
    end

    # Determines whether a user has a fork of the current repo on GitHub.
    def repo_exists?(project)
      load_net_http
      Net::HTTPSuccess === http_request(project.api_show_url('yaml'))
    end

    # Forks the current repo using the GitHub API.
    #
    # Returns nothing.
    def fork_repo(project)
      load_net_http
      response = http_post project.api_fork_url('yaml')
      response.error! unless Net::HTTPSuccess === response
    end

    # Creates a new repo using the GitHub API.
    #
    # Returns nothing.
    def create_repo(project, options = {})
      is_org = project.owner != github_user(true, project.host)
      params = {'name' => is_org ? project.name_with_owner : project.name}
      params['public'] = '0' if options[:private]
      params['description'] = options[:description] if options[:description]
      params['homepage'] = options[:homepage] if options[:homepage]

      load_net_http
      response = http_post(project.api_create_url('json'), params)
      response.error! unless Net::HTTPSuccess === response
    end

    # Returns parsed data from the new pull request.
    def create_pullrequest(options)
      project = options.fetch(:project)
      params = {
        'pull[base]' => options.fetch(:base),
        'pull[head]' => options.fetch(:head)
      }
      params['pull[issue]'] = options[:issue] if options[:issue]
      params['pull[title]'] = options[:title] if options[:title]
      params['pull[body]'] = options[:body] if options[:body]

      load_net_http
      response = http_post(project.api_create_pullrequest_url('json'), params)
      response.error! unless Net::HTTPSuccess === response
      JSON.parse(response.body)['pull']
    end

    def pullrequest_editmsg(changes)
      message_file = File.join(git_dir, 'PULLREQ_EDITMSG')
      File.open(message_file, 'w') { |msg|
        yield msg
        if changes
          msg.puts "#\n# Changes:\n#"
          msg.puts changes.gsub(/^/, '# ').gsub(/ +$/, '')
        end
      }
      edit_cmd = Array(git_editor).dup
      edit_cmd << '-c' << 'set ft=gitcommit' if edit_cmd[0] =~ /^[mg]?vim$/
      edit_cmd << message_file
      system(*edit_cmd)
      abort "can't open text editor for pull request message" unless $?.success?
      title, body = read_editmsg(message_file)
      abort "Aborting due to empty pull request title" unless title
      [title, body]
    end

    def read_editmsg(file)
      title, body = '', ''
      File.open(file, 'r') { |msg|
        msg.each_line do |line|
          next if line.index('#') == 0
          ((body.empty? and line =~ /\S/) ? title : body) << line
        end
      }
      title.tr!("\n", ' ')
      title.strip!
      body.strip!

      [title =~ /\S/ ? title : nil, body =~ /\S/ ? body : nil]
    end

    def expand_alias(cmd)
      if expanded = git_alias_for(cmd)
        if expanded.index('!') != 0
          require 'shellwords' unless defined?(::Shellwords)
          Shellwords.shellwords(expanded)
        end
      end
    end

    def http_request(url, type = :Get)
      url = URI(url) unless url.respond_to? :host
      user, token = github_user(type != :Get, url.host), github_token(type != :Get, url.host)

      req = Net::HTTP.const_get(type).new(url.request_uri)
      req.basic_auth "#{user}/token", token if user and token

      http = setup_http(url)

      yield req if block_given?
      http.start { http.request(req) }
    end

    def http_post(url, params = nil)
      http_request(url, :Post) do |req|
        req.set_form_data params if params
        req['Content-Length'] = req.body ? req.body.length : 0
      end
    end

    def setup_http(url)
      port = url.port
      if use_ssl = 'https' == url.scheme and not use_ssl?
        # ruby compiled without openssl
        use_ssl = false
        port = 80
      end

      http_args = [url.host, port]
      if proxy = proxy_url(use_ssl)
        http_args.concat proxy.select(:host, :port)
        if proxy.userinfo
          require 'cgi'
          http_args.concat proxy.userinfo.split(':', 2).map {|a| CGI.unescape a }
        end
      end

      http = Net::HTTP.new(*http_args)

      if http.use_ssl = use_ssl
        # TODO: SSL peer verification
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      return http
    end

    def load_net_http
      require 'net/https'
    rescue LoadError
      require 'net/http'
    end

    def use_ssl?
      defined? ::OpenSSL
    end

    def proxy_url(use_ssl)
      env_name = "HTTP#{use_ssl ? 'S' : ''}_PROXY"
      if proxy = ENV[env_name] || ENV[env_name.downcase]
        proxy = "http://#{proxy}" unless proxy.include? '://'
        URI.parse(proxy)
      end
    end

    # Fake exception type for net/http exception handling.
    # Necessary because net/http may or may not be loaded at the time.
    module HTTPExceptions
      def self.===(exception)
        exception.class.ancestors.map {|a| a.to_s }.include? 'Net::HTTPExceptions'
      end
    end

    def display_http_exception(action, response)
      $stderr.puts "Error #{action}: #{response.message} (HTTP #{response.code})"
      case response.code.to_i
      when 401 then warn "Check your token configuration (`git config github.token`)"
      when 422
        if response.content_type =~ /\bjson\b/ and data = JSON.parse(response.body) and data["error"]
          $stderr.puts data["error"]
        end
      end
    end
  end
end

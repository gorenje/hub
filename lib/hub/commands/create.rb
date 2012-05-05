module Hub
  module Commands
    # $ hub create
    # ... create repo on github ...
    # > git remote add -f origin git@github.com:YOUR_USER/CURRENT_REPO.git
    def create(args)
      if !is_repo?
        abort "'create' must be run from inside a git repository"
      elsif owner = github_user and github_token
        args.shift
        options = {}
        options[:private] = true if args.delete('-p')
        new_repo_name = nil

        until args.empty?
          case arg = args.shift
          when '-d'
            options[:description] = args.shift
          when '-h'
            options[:homepage] = args.shift
          else
            if arg =~ /^[^-]/ and new_repo_name.nil?
              new_repo_name = arg
              owner, new_repo_name = new_repo_name.split('/', 2) if new_repo_name.index('/')
            else
              abort "invalid argument: #{arg}"
            end
          end
        end
        new_repo_name ||= repo_name
        new_project = github_project(new_repo_name, owner)

        if repo_exists?(new_project)
          warn "#{new_project.name_with_owner} already exists on #{new_project.host}"
          action = "set remote origin"
        else
          action = "created repository"
          create_repo(new_project, options) unless args.noop?
        end

        url = new_project.git_url(:private => true, :https => https_protocol?)

        if remotes.first != 'origin'
          args.replace %W"remote add -f origin #{url}"
        else
          args.replace %W"remote -v"
        end

        args.after 'echo', ["#{action}:", new_project.name_with_owner]
      end
    rescue HTTPExceptions
      display_http_exception("creating repository", $!.response)
      exit 1
    end
  end
end

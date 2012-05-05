module Hub
  module Commands
    # $ hub fork
    # ... hardcore forking action ...
    # > git remote add -f YOUR_USER git@github.com:YOUR_USER/CURRENT_REPO.git
    def fork(args)
      unless project = local_repo.main_project
        abort "Error: repository under 'origin' remote is not a GitHub project"
      end
      forked_project = project.owned_by(github_user(true, project.host))

      if repo_exists?(forked_project)
        abort "Error creating fork: %s already exists on %s" %
          [ forked_project.name_with_owner, forked_project.host ]
      else
        fork_repo(project) unless args.noop?
      end

      if args.include?('--no-remote')
        exit
      else
        url = forked_project.git_url(:private => true, :https => https_protocol?)
        args.replace %W"remote add -f #{forked_project.owner} #{url}"
        args.after 'echo', ['new remote:', forked_project.owner]
      end
    rescue HTTPExceptions
      display_http_exception("creating fork", $!.response)
      exit 1
    end
  end
end

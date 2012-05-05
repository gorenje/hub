module Hub
  module Commands
    # $ hub init -g
    # > git init
    # > git remote add origin git@github.com:USER/REPO.git
    def init(args)
      if args.delete('-g')
        # can't use default_host because there is no local_repo yet
        # FIXME: this shouldn't be here!
        host = ENV['GITHUB_HOST']
        project = Context::GithubProject.new(nil, github_user(true, host), File.basename(current_dir), host || 'github.com')
        url = project.git_url(:private => true, :https => https_protocol?)
        args.after ['remote', 'add', 'origin', url]
      end
    end
  end
end

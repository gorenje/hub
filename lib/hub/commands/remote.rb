module Hub
  module Commands
    # $ hub remote add pjhyett
    # > git remote add pjhyett git://github.com/pjhyett/THIS_REPO.git
    #
    # $ hub remote add -p mojombo
    # > git remote add mojombo git@github.com:mojombo/THIS_REPO.git
    #
    # $ hub remote add origin
    # > git remote add origin git://github.com/YOUR_LOGIN/THIS_REPO.git
    def remote(args)
      if %w[add set-url].include?(args[1])
        name = args.last
        if name =~ /^(#{OWNER_RE})$/ || name =~ /^(#{OWNER_RE})\/(#{NAME_RE})$/
          user, repo = $1, $2 || repo_name
        end
      end
      return unless user # do not touch arguments

      ssh = args.delete('-p')

      if args.words[2] == 'origin' && args.words[3].nil?
        # Origin special case triggers default user/repo
        user, repo = github_user, repo_name
      elsif args.words[-2] == args.words[1]
        # rtomayko/tilt => rtomayko
        # Make sure you dance around flags.
        idx = args.index( args.words[-1] )
        args[idx] = user
      else
        # They're specifying the remote name manually (e.g.
        # git remote add blah rtomayko/tilt), so just drop the last
        # argument.
        args.pop
      end

      args << git_url(user, repo, :private => ssh)
    end
  end
end

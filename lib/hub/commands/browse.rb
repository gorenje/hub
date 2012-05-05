module Hub
  module Commands
    # $ hub browse
    # > open https://github.com/CURRENT_REPO
    #
    # $ hub browse -- issues
    # > open https://github.com/CURRENT_REPO/issues
    #
    # $ hub browse pjhyett/github-services
    # > open https://github.com/pjhyett/github-services
    #
    # $ hub browse github-services
    # > open https://github.com/YOUR_LOGIN/github-services
    #
    # $ hub browse github-services wiki
    # > open https://github.com/YOUR_LOGIN/github-services/wiki
    def browse(args)
      args.shift
      browse_command(args) do
        dest = args.shift
        dest = nil if dest == '--'

        if dest
          # $ hub browse pjhyett/github-services
          # $ hub browse github-services
          project = github_project dest
          branch = master_branch
        else
          # $ hub browse
          project = current_project
          branch = current_branch && current_branch.upstream || master_branch
        end

        abort "Usage: hub browse [<USER>/]<REPOSITORY>" unless project

        # $ hub browse -- wiki
        path = case subpage = args.shift
        when 'commits'
          "/commits/#{branch.short_name}"
        when 'tree', NilClass
          "/tree/#{branch.short_name}" if branch and !branch.master?
        else
          "/#{subpage}"
        end

        project.web_url(path)
      end
    end
  end
end

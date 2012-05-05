module Hub
  module Commands
    # $ hub fetch mislav
    # > git remote add mislav git://github.com/mislav/REPO.git
    # > git fetch mislav
    #
    # $ hub fetch --multiple mislav xoebus
    # > git remote add mislav ...
    # > git remote add xoebus ...
    # > git fetch --multiple mislav xoebus
    def fetch(args)
      # $ hub fetch --multiple <name1>, <name2>, ...
      if args.include?('--multiple')
        names = args.words[1..-1]
      # $ hub fetch <name>
      elsif remote_name = args.words[1]
        # $ hub fetch <name1>,<name2>,...
        if remote_name =~ /^\w+(,\w+)+$/
          index = args.index(remote_name)
          args.delete(remote_name)
          names = remote_name.split(',')
          args.insert(index, *names)
          args.insert(index, '--multiple')
        else
          names = [remote_name]
        end
      else
        names = []
      end

      projects = names.map { |name|
        unless name =~ /\W/ or remotes.include?(name) or remotes_group(name)
          project = github_project(nil, name)
          project if repo_exists?(project)
        end
      }.compact

      if projects.any?
        projects.each do |project|
          args.before ['remote', 'add', project.owner, project.git_url(:https => https_protocol?)]
        end
      end
    end
  end
end

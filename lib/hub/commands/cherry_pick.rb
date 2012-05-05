module Hub
  module Commands
    # $ git cherry-pick http://github.com/mislav/hub/commit/a319d88#comments
    # > git remote add -f mislav git://github.com/mislav/hub.git
    # > git cherry-pick a319d88
    #
    # $ git cherry-pick mislav@a319d88
    # > git remote add -f mislav git://github.com/mislav/hub.git
    # > git cherry-pick a319d88
    #
    # $ git cherry-pick mislav@SHA
    # > git fetch mislav
    # > git cherry-pick SHA
    def cherry_pick(args)
      unless args.include?('-m') or args.include?('--mainline')
        ref = args.words.last
        if url = resolve_github_url(ref) and url.project_path =~ /^commit\/([a-f0-9]{7,40})/
          sha = $1
          project = url.project
        elsif ref =~ /^(#{OWNER_RE})@([a-f0-9]{7,40})$/
          owner, sha = $1, $2
          project = local_repo.main_project.owned_by(owner)
        end

        if project
          args[args.index(ref)] = sha

          if remote = project.remote and remotes.include? remote
            args.before ['fetch', remote.to_s]
          else
            args.before ['remote', 'add', '-f', project.owner, project.git_url(:https => https_protocol?)]
          end
        end
      end
    end
  end
end

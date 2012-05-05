module Hub
  module Commands
    # $ hub compare 1.0..fix
    # > open https://github.com/CURRENT_REPO/compare/1.0...fix
    # $ hub compare refactor
    # > open https://github.com/CURRENT_REPO/compare/refactor
    # $ hub compare myfork feature
    # > open https://github.com/myfork/REPO/compare/feature
    # $ hub compare -u 1.0...2.0
    # "https://github.com/CURRENT_REPO/compare/1.0...2.0"
    def compare(args)
      args.shift
      browse_command(args) do
        if args.empty?
          branch = current_branch.upstream
          if branch and not branch.master?
            range = branch.short_name
            project = current_project
          else
            abort "Usage: hub compare [USER] [<START>...]<END>"
          end
        else
          sha_or_tag = /(\w{1,2}|\w[\w.-]+\w)/
          # replaces two dots with three: "sha1...sha2"
          range = args.pop.sub(/^#{sha_or_tag}\.\.#{sha_or_tag}$/, '\1...\2')
          project = if owner = args.pop then github_project(nil, owner)
                    else current_project
                    end
        end

        project.web_url "/compare/#{range}"
      end
    end
  end
end

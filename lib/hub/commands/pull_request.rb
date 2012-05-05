module Hub
  module Commands
    # $ hub pull-request
    # $ hub pull-request "My humble contribution"
    # $ hub pull-request -i 92
    # $ hub pull-request https://github.com/rtomayko/tilt/issues/92
    def pull_request(args)
      args.shift
      options = { }
      force = explicit_owner = false
      base_project = local_repo.main_project
      head_project = local_repo.current_project

      unless base_project
        abort "Aborted: the origin remote doesn't point to a GitHub repository."
      end

      from_github_ref = lambda do |ref, context_project|
        if ref.index(':')
          owner, ref = ref.split(':', 2)
          project = github_project(context_project.name, owner)
        end
        [project || context_project, ref]
      end

      while arg = args.shift
        case arg
        when '-f'
          force = true
        when '-b'
          base_project, options[:base] = from_github_ref.call(args.shift, base_project)
        when '-h'
          head = args.shift
          explicit_owner = !!head.index(':')
          head_project, options[:head] = from_github_ref.call(head, head_project)
        when '-i'
          options[:issue] = args.shift
        else
          if url = resolve_github_url(arg) and url.project_path =~ /^issues\/(\d+)/
            options[:issue] = $1
            base_project = url.project
          elsif !options[:title] then options[:title] = arg
          else
            abort "invalid argument: #{arg}"
          end
        end
      end

      options[:project] = base_project
      options[:base] ||= master_branch.short_name

      if tracked_branch = options[:head].nil? && current_branch.upstream
        if !tracked_branch.remote?
          # The current branch is tracking another local branch. Pretend there is
          # no upstream configuration at all.
          tracked_branch = nil
        elsif base_project == head_project and tracked_branch.short_name == options[:base]
          $stderr.puts "Aborted: head branch is the same as base (#{options[:base].inspect})"
          warn "(use `-h <branch>` to specify an explicit pull request head)"
          abort
        end
      end
      options[:head] ||= (tracked_branch || current_branch).short_name

      # when no tracking, assume remote branch is published under active user's fork
      user = github_user(true, head_project.host)
      if head_project.owner != user and !tracked_branch and !explicit_owner
        head_project = head_project.owned_by(user)
      end

      remote_branch = "#{head_project.remote}/#{options[:head]}"
      options[:head] = "#{head_project.owner}:#{options[:head]}"

      if !force and tracked_branch and local_commits = rev_list(remote_branch, nil)
        $stderr.puts "Aborted: #{local_commits.split("\n").size} commits are not yet pushed to #{remote_branch}"
        warn "(use `-f` to force submit a pull request anyway)"
        abort
      end

      if args.noop?
        puts "Would request a pull to #{base_project.owner}:#{options[:base]} from #{options[:head]}"
        exit
      end

      unless options[:title] or options[:issue]
        base_branch = "#{base_project.remote}/#{options[:base]}"
        commits = rev_list(base_branch, remote_branch).to_s.split("\n")

        case commits.size
        when 0
          default_message = commit_summary = nil
        when 1
          format = '%w(78,0,0)%s%n%+b'
          default_message = git_command "show -s --format='#{format}' #{commits.first}"
          commit_summary = nil
        else
          format = '%h (%aN, %ar)%n%w(78,3,3)%s%n%+b'
          default_message = nil
          commit_summary = git_command "log --no-color --format='%s' --cherry %s...%s" %
            [format, base_branch, remote_branch]
        end

        options[:title], options[:body] = pullrequest_editmsg(commit_summary) { |msg|
          msg.puts default_message if default_message
          msg.puts ""
          msg.puts "# Requesting a pull to #{base_project.owner}:#{options[:base]} from #{options[:head]}"
          msg.puts "#"
          msg.puts "# Write a message for this pull request. The first block"
          msg.puts "# of text is the title and the rest is description."
        }
      end

      pull = create_pullrequest(options)

      args.executable = 'echo'
      args.replace [pull['html_url']]
    rescue HTTPExceptions
      display_http_exception("creating pull request", $!.response)
      exit 1
    end
  end
end

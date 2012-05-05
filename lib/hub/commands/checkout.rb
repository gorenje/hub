module Hub
  module Commands
    # $ git checkout https://github.com/defunkt/hub/pull/73
    # > git remote add -f -t feature git://github:com/mislav/hub.git
    # > git checkout --track -B mislav-feature mislav/feature
    def checkout(args)
      _, url_arg, new_branch_name = args.words
      if url = resolve_github_url(url_arg) and url.project_path =~ /^pull\/(\d+)/
        pull_id = $1

        load_net_http
        response = http_request(url.project.api_pullrequest_url(pull_id, 'json'))
        pull_data = JSON.parse(response.body)['pull']

        args.delete new_branch_name
        user, branch = pull_data['head']['label'].split(':', 2)
        abort "Error: #{user}'s fork is not available anymore" unless pull_data['head']['repository']
        new_branch_name ||= "#{user}-#{branch}"

        if remotes.include? user
          args.before ['remote', 'set-branches', '--add', user, branch]
          args.before ['fetch', user, "+refs/heads/#{branch}:refs/remotes/#{user}/#{branch}"]
        else
          url = github_project(url.project_name, user).git_url(:private => pull_data['head']['repository']['private'],
                                                               :https => https_protocol?)
          args.before ['remote', 'add', '-f', '-t', branch, user, url]
        end
        idx = args.index url_arg
        args.delete_at idx
        args.insert idx, '--track', '-B', new_branch_name, "#{user}/#{branch}"
      end
    end
  end
end

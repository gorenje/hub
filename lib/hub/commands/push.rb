module Hub
  module Commands
    # $ hub push origin,staging cool-feature
    # > git push origin cool-feature
    # > git push staging cool-feature
    def push(args)
      return if args[1].nil? || !args[1].index(',')

      branch  = (args[2] ||= current_branch.short_name)
      remotes = args[1].split(',')
      args[1] = remotes.shift

      remotes.each do |name|
        args.after ['push', name, branch]
      end
    end
  end
end

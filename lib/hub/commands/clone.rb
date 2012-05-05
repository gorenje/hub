module Hub
  module Commands
    # $ hub clone rtomayko/tilt
    # > git clone git://github.com/rtomayko/tilt.
    #
    # $ hub clone -p kneath/hemingway
    # > git clone git@github.com:kneath/hemingway.git
    #
    # $ hub clone tilt
    # > git clone git://github.com/YOUR_LOGIN/tilt.
    #
    # $ hub clone -p github
    # > git clone git@github.com:YOUR_LOGIN/hemingway.git
    def clone(args)
      ssh = args.delete('-p')
      has_values = /^(--(upload-pack|template|depth|origin|branch|reference)|-[ubo])$/

      idx = 1
      while idx < args.length
        arg = args[idx]
        if arg.index('-') == 0
          idx += 1 if arg =~ has_values
        else
          # $ hub clone rtomayko/tilt
          # $ hub clone tilt
          if arg =~ NAME_WITH_OWNER_RE and !File.directory?(arg)
            # FIXME: this logic shouldn't be duplicated here!
            name, owner = arg, nil
            owner, name = name.split('/', 2) if name.index('/')
            host = ENV['GITHUB_HOST']
            project = Context::GithubProject.new(nil, owner || github_user(true, host), name, host || 'github.com')
            ssh ||= args[0] != 'submodule' && project.owner == github_user(false, host) || host
            args[idx] = project.git_url(:private => ssh, :https => https_protocol?)
          end
          break
        end
        idx += 1
      end
    end
  end
end

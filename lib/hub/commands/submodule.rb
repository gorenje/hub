module Hub
  module Commands
    # $ hub submodule add wycats/bundler vendor/bundler
    # > git submodule add git://github.com/wycats/bundler.git vendor/bundler
    #
    # $ hub submodule add -p wycats/bundler vendor/bundler
    # > git submodule add git@github.com:wycats/bundler.git vendor/bundler
    #
    # $ hub submodule add -b ryppl ryppl/pip vendor/bundler
    # > git submodule add -b ryppl git://github.com/ryppl/pip.git vendor/pip
    def submodule(args)
      return unless index = args.index('add')
      args.delete_at index

      branch = args.index('-b') || args.index('--branch')
      if branch
        args.delete_at branch
        branch_name = args.delete_at branch
      end

      clone(args)

      if branch_name
        args.insert branch, '-b', branch_name
      end
      args.insert index, 'add'
    end
  end
end

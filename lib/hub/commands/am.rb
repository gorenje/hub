module Hub
  module Commands
    # $ hub am https://github.com/defunkt/hub/pull/55
    # > curl https://github.com/defunkt/hub/pull/55.patch -o /tmp/55.patch
    # > git am /tmp/55.patch
    def am(args)
      if url = args.find { |a| a =~ %r{^https?://(gist\.)?github\.com/} }
        idx = args.index(url)
        gist = $1 == 'gist.'
        # strip the fragment part of the url
        url = url.sub(/#.+/, '')
        # strip extra path from "pull/42/files", "pull/42/commits"
        url = url.sub(%r{(/pull/\d+)/\w*$}, '\1') unless gist
        ext = gist ? '.txt' : '.patch'
        url += ext unless File.extname(url) == ext
        patch_file = File.join(ENV['TMPDIR'] || '/tmp', "#{gist ? 'gist-' : ''}#{File.basename(url)}")
        args.before 'curl', ['-#LA', "hub #{Hub::Version}", url, '-o', patch_file]
        args[idx] = patch_file
      end
    end

    # $ hub apply https://github.com/defunkt/hub/pull/55
    # > curl https://github.com/defunkt/hub/pull/55.patch -o /tmp/55.patch
    # > git apply /tmp/55.patch
    alias_method :apply, :am
  end
end

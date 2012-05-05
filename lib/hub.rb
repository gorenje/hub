require 'hub/version'
require 'hub/args'
require 'hub/context'
require 'hub/ssh_config'
require 'hub/json'
require 'hub/commands'
require 'hub/runner'

# Include each command separately because the standalone
# module scans this file for require strings to construct
# the standalone executable.
require 'hub/commands/am'
require 'hub/commands/browse'
require 'hub/commands/checkout'
require 'hub/commands/cherry_pick'
require 'hub/commands/clone'
require 'hub/commands/compare'
require 'hub/commands/create'
require 'hub/commands/fetch'
require 'hub/commands/fork'
require 'hub/commands/hub'
require 'hub/commands/init'
require 'hub/commands/pull_request'
require 'hub/commands/push'
require 'hub/commands/remote'
require 'hub/commands/submodule'


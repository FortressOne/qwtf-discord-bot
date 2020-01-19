lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'qwtf_discord_bot/version'

Gem::Specification.new do |spec|
  spec.name          = 'qwtf_discord_bot'
  spec.version       = QwtfDiscordBot::VERSION
  spec.authors       = ['Sheldon Johnson']
  spec.email         = ['shayolden@hotmail.com']

  spec.description   = 'A Discord bot for reporting on QuakeWorld Team ' \
                       'Fortress game servers'

  spec.summary       = 'Works by wrapping the excellent CLI server query tool ' \
                       'qstat. Accepts !server, !servers and !active commands ' \
                       'also periodically checks for new players on the ' \
                       'server and reports about them.'

  spec.homepage      = 'https://github.com/drzel/qwtf_discord_bot.git'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'discordrb', '~> 3.3'
  spec.add_runtime_dependency 'redis', '~> 4.1'
  spec.add_runtime_dependency 'thor', '~> 0.20'
end


lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "discord_qstat_bot/version"

Gem::Specification.new do |spec|
  spec.name          = "discord_qstat_bot"
  spec.version       = DiscordQstatBot::VERSION
  spec.authors       = ["Sheldon Johnson"]
  spec.email         = ["shayolden@hotmail.com"]

  spec.summary       = %q{A discord bot wrapping qstat}
  spec.description   = %q{A discord bot wrapping qstat}
  spec.homepage      = "https://github.com/drzel/discord_qstat_bot.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "discordrb"
  spec.add_dependency "thor"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
end

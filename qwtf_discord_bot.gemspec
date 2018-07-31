
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "qwtf_discord_bot/version"

Gem::Specification.new do |spec|
  spec.name          = "qwtf_discord_bot"
  spec.version       = QwtfDiscordBot::VERSION
  spec.authors       = ["Sheldon Johnson"]
  spec.email         = ["shayolden@hotmail.com"]

  spec.description   = %q{A discord bot for checking the status of qwtf servers}
  spec.summary       = %q{A discord bot for checking the status of qwtf servers}
  spec.homepage      = "https://github.com/drzel/qwtf_discord_bot.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "discordrb", '~> 0'

  spec.add_development_dependency "thor", '~> 0'
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", '~> 0'
end

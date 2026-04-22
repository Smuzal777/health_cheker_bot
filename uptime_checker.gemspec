Gem::Specification.new do |spec|
  spec.name    = "uptime_checker"
  spec.version = "0.1.0"
  spec.authors = ['Smuzal']
  spec.email   = ['smuzal@yandex.ru']
  spec.summary = "Проверяет доступность сайтов и парсит ключевые слова"

  spec.add_dependency "nokogiri", "~> 1.15"
  spec.add_dependency "faraday",  "~> 2.7"
  spec.add_dependency "faraday-follow_redirects"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "webmock",  "~> 3.23"
end

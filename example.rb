require_relative "lib/uptime_checker"

# Заглушка для демонстрации без запуска реального YAML
# В реальном применении можно использовать UptimeChecker::ConfigLoader
config = [
  {
    url: "https://link.springer.com/chapter/10.1007/978-3-030-58805-2_22",
    strategy: UptimeChecker::Strategies::SpringerStrategy.new,
    timeout: 5
  },
  {
    url: "https://elibrary.ru/item.asp?id=45781198",
    strategy: UptimeChecker::Strategies::ElibraryStrategy.new,
    timeout: 5
  },
  {
    url: "https://en.wikipedia.org/wiki/Ruby_(programming_language)",
    strategy: UptimeChecker::Strategies::WikipediaStrategy.new,
    timeout: 5
  }
]

puts "--- Запуск проверки доступности и парсинга ключевых слов ---"
results = config.map do |site|
  puts "Проверка: #{site[:url]}..."
  checker = UptimeChecker::Checker.new(site)
  checker.check_health
end

reporter = UptimeChecker::Reporters::ConsoleReporter.new(results)
reporter.render

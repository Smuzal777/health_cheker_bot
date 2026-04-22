require 'bundler/setup'
require 'telegram/bot'
require_relative 'lib/uptime_checker'

# Чтобы логи в Docker отображались сразу
$stdout.sync = true

TOKEN = '8777947041:AAFVnLa_0bXyCPpmlqsqsb7JeQ2S1_WVd6o'

# Функция для создания главного меню с кнопками
def main_menu
  buttons = [
    [Telegram::Bot::Types::InlineKeyboardButton.new(text: '📊 Проверить список из файла', callback_data: 'check_all')],
    [Telegram::Bot::Types::InlineKeyboardButton.new(text: 'ℹ️ Помощь', callback_data: 'help')]
  ]
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
end

puts "🚀 Бот запускается на сервере..."

Telegram::Bot::Client.run(TOKEN) do |bot|
  puts "✅ Соединение с Telegram установлено."

  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      case message.data
      when 'check_all'
        bot.api.answer_callback_query(callback_query_id: message.id, text: "Начинаю опрос сайтов...")

        begin
          # Загружаем конфиг (возвращает Hash)
          config = UptimeChecker::ConfigLoader.load('config/sites.yml')
          bot.api.send_message(chat_id: message.from.id, text: "🔎 Опрашиваю сайты из `sites.yml`...", parse_mode: 'Markdown')

          # Извлекаем массив сайтов из ключа :sites
          sites_array = config[:sites]

          results = sites_array.map do |site_data|
            # Превращаем Hash в структуру, которую ожидает Checker
            site_obj = Struct.new(:url, :timeout, :strategy).new(
              site_data[:url],
              site_data[:timeout],
              site_data[:strategy]
            )
            UptimeChecker::Checker.new(site_obj).check_health
          end

          # Формируем отчет
          report = "🔔 *Отчет мониторинга:*\n\n"
          results.each do |res|
            status = res.available? ? "✅ *UP*" : "❌ *DOWN*"
            report += "#{status} | [#{res.url}](#{res.url})\n"
            report += "⏱ `#{res.response_time}s` | Код: #{res.status_code || 'Error'}\n\n"
          end

          bot.api.send_message(chat_id: message.from.id, text: report, parse_mode: 'Markdown', disable_web_page_preview: true)
        rescue => e
          puts "Ошибка при проверке списка: #{e.message}"
          bot.api.send_message(chat_id: message.from.id, text: "❌ Ошибка: #{e.message}")
        end

      when 'help'
        help_text = "📖 *Как пользоваться ботом:*\n\n" \
          "1. Нажмите кнопку выше для проверки сайтов из вашего файла.\n" \
          "2. Просто пришлите мне ссылку (например, `https://google.com`), чтобы я проверил её мгновенно."
        bot.api.send_message(chat_id: message.from.id, text: help_text, parse_mode: 'Markdown')
      end

    when Telegram::Bot::Types::Message
      case message.text
      when '/start'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Привет! Я бот для мониторинга доступности сайтов.\n\nВыберите действие:",
          reply_markup: main_menu
        )

      when /^http/ # Если пользователь прислал ссылку
        url = message.text.strip
        bot.api.send_message(chat_id: message.chat.id, text: "🔎 Проверяю: #{url}...")

        # Временный объект для разовой проверки
        temp_site = Struct.new(:url, :timeout, :strategy).new(url, 10, UptimeChecker::Strategies::AvailabilityStrategy.new)
        result = UptimeChecker::Checker.new(temp_site).check_health

        status = result.available? ? "✅ Доступен" : "❌ Недоступен"
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "*Результат для* #{url}:\n\n#{status}\nКод ответа: #{result.status_code || 'N/A'}\nВремя: #{result.response_time}с",
          parse_mode: 'Markdown'
        )

      else
        bot.api.send_message(chat_id: message.chat.id, text: "Напишите /start для вызова меню или пришлите ссылку.")
      end
    end
  end
rescue => e
  puts "Критическая ошибка: #{e.message}"
  sleep 5
  retry
end
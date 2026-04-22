require 'bundler/setup'
require 'telegram/bot'
require_relative 'lib/uptime_checker'

$stdout.sync = true
TOKEN = '8777947041:AAFVnLa_0bXyCPpmlqsqsb7JeQ2S1_WVd6o'

# Создаем главное меню с кнопками
def main_menu
  buttons = [
    Telegram::Bot::Types::InlineKeyboardButton.new(text: '📊 Проверить всё', callback_data: 'check_all'),
    Telegram::Bot::Types::InlineKeyboardButton.new(text: '🌐 Инструкция', callback_data: 'help')
  ]
  Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [buttons])
end

Telegram::Bot::Client.run(TOKEN) do |bot|
  puts "🚀 Бот запущен на сервере..."

  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      # Обработка нажатий на кнопки
      if message.data == 'check_all'
        bot.api.answer_callback_query(callback_query_id: message.id, text: "Запускаю проверку...")

        # Вызываем логику проверки (убедитесь, что путь к config верен)
        begin
          config = UptimeChecker::ConfigLoader.load('config/sites.yml')
          bot.api.send_message(chat_id: message.from.id, text: "🔎 Опрашиваю сайты из списка...")

          results = config.sites.map { |s| UptimeChecker::Checker.new(s).check_health }

          report = "🔔 *Результаты мониторинга:*\n\n"
          results.each do |res|
            status = res.available? ? "✅ *UP*" : "❌ *DOWN*"
            report += "#{status} | [#{res.url}](#{res.url})\n"
            report += "⏱ `#{res.response_time}s` | Код: #{res.status_code}\n\n"
          end

          bot.api.send_message(chat_id: message.from.id, text: report, parse_mode: 'Markdown', disable_web_page_preview: true)
        rescue => e
          bot.api.send_message(chat_id: message.from.id, text: "Ошибка: #{e.message}")
        end
      end

    when Telegram::Bot::Types::Message
      case message.text
      when '/start'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Привет! Я бот для мониторинга сайтов.\n\nНажми на кнопку ниже или просто **пришли мне ссылку** на любой сайт для проверки.",
          reply_markup: main_menu,
          parse_mode: 'Markdown'
        )

      when '/check'
        # Дублируем логику для текстовой команды
        bot.api.send_message(chat_id: message.chat.id, text: "Используйте кнопку для проверки всех сайтов или пришлите ссылку.", reply_markup: main_menu)

      when /^http/ # Если пользователь прислал ссылку
        url = message.text.strip
        bot.api.send_message(chat_id: message.chat.id, text: "Проверяю статус #{url}...")

        # Создаем временный конфиг для одного сайта
        site_cfg = Struct.new(:url, :timeout, :strategy).new(url, 10, UptimeChecker::Strategies::Base.new)
        result = UptimeChecker::Checker.new(site_cfg).check_health

        status = result.available? ? "✅ Сайт доступен!" : "❌ Сайт не отвечает."
        bot.api.send_message(chat_id: message.chat.id, text: "#{status}\nОтвет: #{result.status_code}\nВремя: #{result.response_time}с")

      else
        bot.api.send_message(chat_id: message.chat.id, text: "Я не совсем понял. Нажмите кнопку или пришлите ссылку (начинающуюся с http).", reply_markup: main_menu)
      end
    end
  end
end
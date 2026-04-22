require 'bundler/setup'
require 'telegram/bot'
require_relative 'lib/uptime_checker'

$stdout.sync = true

TOKEN = '8777947041:AAFVnLa_0bXyCPpmlqsqsb7JeQ2S1_WVd6o'

# БЕСПЛАТНЫЙ ПРОКСИ (Обновляемый)
# Если этот не сработает, замени адрес и порт на те, что найдешь по ссылке ниже
PROXY_URL = 'http://161.35.70.243:3128'

connection_options = {
  proxy: {
    uri: PROXY_URL
    # Бесплатные прокси обычно не требуют логина и пароля
  },
  request: {
    timeout: 120,
    open_timeout: 30
  }
}

puts "--- ЗАПУСК ЧЕРЕЗ БЕСПЛАТНЫЙ ПРОКСИ ---"
puts "Использую: #{PROXY_URL}"

begin
  Telegram::Bot::Client.run(TOKEN, request: connection_options) do |bot|
    puts "✅ Есть контакт! Бот залогинился."

    bot.listen do |message|
      puts "📥 Получено: #{message.text}"
      case message.text
      when '/start'
        bot.api.send_message(chat_id: message.chat.id, text: "Ура! Прокси работает. Напиши /check")
      when '/check'
        bot.api.send_message(chat_id: message.chat.id, text: "Проверяю сайты...")
        # Твоя логика проверки
      end
    end
  end
rescue => e
  puts "❌ Этот прокси не подошел: #{e.message}"
  puts "Инструкция: зайди на https://free-proxy-list.net/ и возьми первый из списка с поддержкой HTTPS."
end
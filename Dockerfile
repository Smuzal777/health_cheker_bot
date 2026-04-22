# Используем официальный образ Ruby
FROM ruby:3.2-slim

# Устанавливаем системные зависимости для Nokogiri
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libxml2-dev \
    libxslt1-dev

# Создаем рабочую папку
WORKDIR /app

# Копируем зависимости
COPY Gemfile ./
RUN bundle install

# Копируем весь код проекта
COPY . .

# Команда для запуска бота
CMD ["bundle", "exec", "ruby", "bot.rb"]
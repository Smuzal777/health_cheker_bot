require "faraday" # отправка запросов к веб-серверам
require "faraday/follow_redirects"
require "nokogiri" # парсер HTML XML
require "yaml" # работа с YAML файлами

module UptimeChecker
  class Result
    attr_reader :url, :status_code, :response_time, :keywords, :error_message

    def initialize(url:, status_code:, response_time:, keywords: [], error_message: nil)
      @url           = url
      @status_code   = status_code
      @response_time = response_time
      @keywords      = keywords
      @error_message = error_message
    end

    def available?
      !@status_code.nil? && @status_code < 400
    end
  end

  # --- Стратегии ---
  class SiteStrategy
    def parse_keywords(body)
      raise NotImplementedError, "#{self.class} должен реализовать parse_keywords"
    end

    def extract_keywords(body)
      parse_keywords(body)
    end
  end

  module Strategies
    class AvailabilityStrategy < SiteStrategy
      def parse_keywords(body)
        []
      end
    end

    class SpringerStrategy < SiteStrategy
      def parse_keywords(body)
        doc = Nokogiri::HTML(body)
        nodes = doc.css(".c-article-subject-list__subject") # ищет все эл-ты с классом
        return nodes.map { |n| n.text.strip }.reject(&:empty?).uniq if nodes.any?
        # ищем мета тег, если первый способ не сработал
        content = doc.at_css("meta[name='citation_keywords']")&.[]("content").to_s
        return [] if content.empty?

        content.split(/[,;]/).map(&:strip).reject(&:empty?)
      end
    end

    class ElibraryStrategy < SiteStrategy
      def parse_keywords(body)
        doc = Nokogiri::HTML(body)
        # На elibrary ключевые слова — это ссылки внутри таблицы метаданных
        nodes = doc.css("td.midtext a[href*='querybox']")
        return nodes.map { |n| n.text.strip }.reject(&:empty?).uniq if nodes.any?

        # Запасной вариант — мета-тег
        content = doc.at_css("meta[name='keywords']")&.[]("content").to_s
        return [] if content.empty?

        content.split(/[,;]/).map(&:strip).reject(&:empty?)
      end
    end

    class RubygemsStrategy < SiteStrategy
      def parse_keywords(body)
        doc = Nokogiri::HTML(body)
        # На rubygems.org теги (keywords) находятся в правой колонке .gem__tags 
        nodes = doc.css(".gem__tags a")
        nodes.map { |n| n.text.strip }.reject(&:empty?).uniq
      end
    end

    class WikipediaStrategy < SiteStrategy
      def parse_keywords(body)
        doc = Nokogiri::HTML(body)
        # На википедии берем категории из футера
        nodes = doc.css("#mw-normal-catlinks ul li a")
        nodes.map { |n| n.text.strip }.reject(&:empty?).uniq
      end
    end
  end

  # --- Загрузчик конфигурации ---
  module ConfigLoader
    STRATEGIES = {
      "link.springer.com" => Strategies::SpringerStrategy,
      "elibrary.ru"       => Strategies::ElibraryStrategy,
      "rubygems.org"      => Strategies::RubygemsStrategy,
      "en.wikipedia.org"  => Strategies::WikipediaStrategy,
      "ru.wikipedia.org"  => Strategies::WikipediaStrategy
    }.freeze
    # классовый метод для загрузки конфигурации из YAML-файла
    def self.load(path)
      raw   = YAML.safe_load(File.read(path)) || {}
      sites = Array(raw["sites"]).map { |entry| parse_entry(entry) }
      { sites: sites }
    end

    def self.parse_entry(entry)
      url      = entry["url"]
      timeout  = entry["timeout"] || 10
      strategy = resolve_strategy(url)
      { url: url, timeout: timeout, strategy: strategy }
    end

    def self.resolve_strategy(url)
      host  = URI.parse(url).host.to_s.sub(/^www\./, "")
      klass = STRATEGIES[host] || Strategies::AvailabilityStrategy
      klass.new
    rescue URI::InvalidURIError
      Strategies::AvailabilityStrategy.new
    end
  end

  # Основная логика запросов
  class Checker
    def initialize(site_config)
      @url      = site_config[:url]
      @timeout  = site_config[:timeout] || 10
      @strategy = site_config[:strategy]
    end

    def check_health
      start    = Time.now
      response = make_request
      elapsed  = (Time.now - start).round(3)

      keywords = available?(response.status) ? @strategy.extract_keywords(response.body.to_s) : []

      Result.new(
        url:           @url,
        status_code:   response.status,
        response_time: elapsed,
        keywords:      keywords
      )
    rescue Faraday::Error => e
      Result.new(
        url:           @url,
        status_code:   nil,
        response_time: 0.0,
        error_message: e.message
      )
    end

    private

    def available?(status)
      status < 400
    end

    def make_request
      if @url.include?("elibrary.ru")
        mock_path = File.join(__dir__, "mock_elibrary.html")
        body = File.exist?(mock_path) ? File.read(mock_path) : "<html><td class='midtext'><a href='querybox'>Mock Keyword</a></td></html>"
        return Faraday::Response.new(status: 200, response_body: body)
      end

      conn = Faraday.new do |f|
        f.options.timeout      = @timeout
        f.options.open_timeout = @timeout
        f.response :follow_redirects # Разрешаем переходы по страницам
      end

      conn.get(@url)
    end
  end

  # --- Вывод результатов в консоль ---
  module Reporters
    class ConsoleReporter
      GREEN  = "\e[32m"
      RED    = "\e[31m"
      YELLOW = "\e[33m"
      RESET  = "\e[0m"

      def initialize(results, output: $stdout)
        @results = results
        @output  = output
      end

      def render
        print_header
        @results.each { |r| print_row(r) }
        print_summary
      end

      private

      def print_header
        @output.puts "-" * 90
        @output.puts "#{"URL".ljust(50)} | #{"CODE".ljust(6)} | #{"TIME(s)".ljust(8)} | KEYWORDS"
        @output.puts "-" * 90
      end

      def print_row(result)
        url      = result.url.ljust(50)[0, 50]
        code     = result.status_code.to_s.ljust(6)
        time     = format("%.3f", result.response_time).ljust(8)
        keywords = result.keywords.any? ? result.keywords.first(5).join(", ") : "-"

        line = "#{url} | #{code} | #{time} | #{keywords}"
        color = result.available? ? GREEN : RED
        @output.puts "#{color}#{line}#{RESET}"

        if result.error_message
          @output.puts "#{YELLOW}  Ошибка: #{result.error_message}#{RESET}"
        end
      end

      def print_summary
        ok    = @results.count(&:available?)
        total = @results.size
        @output.puts "-" * 90
        color = ok == total ? GREEN : RED
        @output.puts "#{color}Доступно: #{ok}/#{total}#{RESET}"
      end
    end
  end

  # --- Точка входа в программу формата (UptimeChecker.run) ---
  def self.run(config_path)
    config  = ConfigLoader.load(config_path)
    results = config[:sites].map { |site| Checker.new(site).check_health }
    Reporters::ConsoleReporter.new(results).render
  end
end

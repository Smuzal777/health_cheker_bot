require "minitest/autorun"
require "webmock/minitest"
require "tempfile"
require "stringio"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "uptime_checker"

WebMock.disable_net_connect!

class QuickTestCase < Minitest::Test
  def test_result_available
    res = UptimeChecker::Result.new(url: "http://ex.com", status_code: 200, response_time: 0.1)
    assert res.available?
  end

  def test_result_not_available
    res = UptimeChecker::Result.new(url: "http://ex.com", status_code: 500, response_time: 0.1)
    refute res.available?
  end

  # --- Tests for Checker ---
  def test_checker_success
    stub_request(:get, "https://example.com").to_return(status: 200, body: "OK")
    cfg = { url: "https://example.com", strategy: UptimeChecker::Strategies::AvailabilityStrategy.new, timeout: 5 }
    checker = UptimeChecker::Checker.new(cfg)
    result = checker.check_health
    
    assert_equal 200, result.status_code
    assert result.available?
  end

  def test_checker_faraday_error
    stub_request(:get, "https://error.com").to_raise(Faraday::ConnectionFailed.new("Fail"))
    cfg = { url: "https://error.com", strategy: UptimeChecker::Strategies::AvailabilityStrategy.new, timeout: 5 }
    checker = UptimeChecker::Checker.new(cfg)
    result = checker.check_health

    refute result.available?
    assert_equal "Fail", result.error_message
  end

  # --- Tests for Strategies ---
  def test_availability_strategy
    strat = UptimeChecker::Strategies::AvailabilityStrategy.new
    assert_equal [], strat.parse_keywords("<html>content</html>")
  end

  def test_elibrary_strategy
    strat = UptimeChecker::Strategies::ElibraryStrategy.new
    html = %q{<html><body><td class="midtext"><a href="querybox.asp">Science</a></td></body></html>}
    assert_equal ["Science"], strat.parse_keywords(html)
  end

  def test_springer_strategy
    strat = UptimeChecker::Strategies::SpringerStrategy.new
    html = %q{<html><body><ul><li class="c-article-subject-list__subject">Physics</li></ul></body></html>}
    assert_equal ["Physics"], strat.parse_keywords(html)
  end

  # --- Tests for ConfigLoader ---
  def test_config_loader
    content = "sites:\n  - url: https://link.springer.com/test\n    timeout: 5\n"
    f = Tempfile.new(["sites", ".yml"])
    f.write(content)
    f.flush

    config = UptimeChecker::ConfigLoader.load(f.path)
    site = config[:sites].first

    assert_equal "https://link.springer.com/test", site[:url]
    assert_equal 5, site[:timeout]
    assert_instance_of UptimeChecker::Strategies::SpringerStrategy, site[:strategy]
  ensure
    f.close
    f.unlink
  end

  # --- Test for Console Reporter ---
  def test_reporter
    results = [UptimeChecker::Result.new(url: "http://ok.com", status_code: 200, response_time: 0.1)]
    out = StringIO.new
    reporter = UptimeChecker::Reporters::ConsoleReporter.new(results, output: out)
    reporter.render

    assert_match /ok\.com/, out.string
    assert_match /200/, out.string
  end
end

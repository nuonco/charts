require 'minitest/autorun'
require 'open3'
require 'yaml'

class RelayEnvironmentTest < Minitest::Test
  CHART = File.expand_path('../charts/telemetry-relay', __dir__)

  def render(*args)
    out, err, status = Open3.capture3('helm', 'template', 'telemetry-relay', CHART, *args)
    assert status.success?, err
    docs = YAML.load_stream(out).compact
    refute docs.any? { |doc| doc['kind'] == 'NetworkPolicy' }
    docs
  end

  def resource(docs, kind)
    docs.find { |doc| doc['kind'] == kind }.tap { |doc| refute_nil doc, kind }
  end

  def test_disabled_receiver_is_loopback_and_not_in_service
    docs = render('--set', 'env.NUON_TELEMETRY_ENVIRONMENT_ENDPOINT=0.0.0.0:5318')
    assert_equal '127.0.0.1:5318', resource(docs, 'ConfigMap')['data']['NUON_TELEMETRY_ENVIRONMENT_ENDPOINT']
    assert_equal [4318, 13133], resource(docs, 'Service')['spec']['ports'].map { |port| port['port'] }
  end

  def test_enabled_receiver_exposes_cluster_ip_port
    docs = render('--set', 'environmentReceiver.enabled=true')
    assert_equal '0.0.0.0:5318', resource(docs, 'ConfigMap')['data']['NUON_TELEMETRY_ENVIRONMENT_ENDPOINT']
    service = resource(docs, 'Service')['spec']
    assert_equal 'ClusterIP', service['type']
    assert_equal [4318, 13133, 5318], service['ports'].map { |port| port['port'] }
  end

  def test_public_routes_stay_on_authenticated_port
    aws = render('--set', 'environmentReceiver.enabled=true,aws.enabled=true,ingress.domain=telemetry.example.com,ingress.certificateArn=example')
    paths = resource(aws, 'Ingress')['spec']['rules'][0]['http']['paths']
    assert_equal 3, paths.length
    paths.each { |path| assert_equal 'otlp-http', path['backend']['service']['port']['name'] }
    gcp = render('--set', 'environmentReceiver.enabled=true,gcp.enabled=true,gateway.hostname=telemetry.example.com')
    rules = resource(gcp, 'HTTPRoute')['spec']['rules']
    assert_equal 3, rules.length
    rules.each { |rule| assert_equal [4318], rule['backendRefs'].map { |backend| backend['port'] } }
  end
end

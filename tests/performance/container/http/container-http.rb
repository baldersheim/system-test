require 'app_generator/container_app'
require 'http_client'
require 'performance_test'
require 'performance/fbench'
require 'performance/h2load'
require 'pp'


class ContainerHttp < PerformanceTest

  KEY_FILE = 'cert.key'
  CERT_FILE = 'cert.crt'

  PERSISTENT = 'persistent'
  NON_PERSISTENT = 'nonpersistent'

  HTTP1 = 'http1'
  HTTP2 = 'http2'

  def setup
    set_owner('bjorncs')
    # Bundle with HelloWorld and AsyncHelloWorld handler
    @bundledir= selfdir + 'java'
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})

    # Deploy a dummy app to get a reference to the container node, which is needed for uploading the certificate
    deploy_container_app(ContainerApp.new.container(Container.new))
    @container = @vespa.container.values.first

    # Generate TLS certificate with endpoint
    system("openssl req -nodes -x509 -newkey rsa:4096 -keyout #{dirs.tmpdir}#{KEY_FILE} -out #{dirs.tmpdir}#{CERT_FILE} -days 365 -subj '/CN=#{@container.hostname}'")
    system("chmod 644 #{dirs.tmpdir}#{KEY_FILE} #{dirs.tmpdir}#{CERT_FILE}")
    @container.copy("#{dirs.tmpdir}#{KEY_FILE}", dirs.tmpdir)
    @container.copy("#{dirs.tmpdir}#{CERT_FILE}", dirs.tmpdir)
  end


  def test_container_http_performance
    deploy_test_app(access_logging: false)

    set_description('Test basic HTTP performance of container')
    @graphs = [
      {
        :title => 'QPS HTTP/1 persistent',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 persistent (1 client)',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1, 'clients' => 1},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 persistent (8 clients)',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1, 'clients' => 8},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 persistent (32 clients)',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1, 'clients' => 32},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
        :y_min => 90000,
        :y_max => 115000
      },
      {
        :title => 'QPS HTTP/1 persistent (128 clients)',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1, 'clients' => 128},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
        :y_min => 100000,
        :y_max => 130000
      },
      {
        :title => 'Latency HTTP/1 persistent',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1},
        :x => 'benchmark-tag',
        :y => 'latency',
        :historic => true
      },
      {
        :title => 'CPU utilization HTTP/1 persistent',
        :filter => {'connection' => PERSISTENT, 'protocol' => HTTP1},
        :x => 'benchmark-tag',
        :y => 'cpuutil',
        :historic => true
      },
      {
        :title => 'CPU utilization HTTP/1 non-persistent',
        :filter => {'connection' => NON_PERSISTENT, 'protocol' => HTTP1},
        :x => 'benchmark-tag',
        :y => 'cpuutil',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 non-persistent',
        :filter => {'connection' => NON_PERSISTENT, 'protocol' => HTTP1 },
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
        :y_min => 2900,
        :y_max => 3100
      },
      {
        :title => 'QPS HTTP/2 (1 client)',
        :filter => {'protocol' => HTTP2, 'clients' => 1},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
        :y_min => 100000,
        :y_max => 120000
      },
      {
        :title => 'QPS HTTP/2 (4 client)',
        :filter => {'protocol' => HTTP2, 'clients' => 4},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/2 (8 client)',
        :filter => {'protocol' => HTTP2, 'clients' => 8},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
      },
      {
        :title => 'QPS HTTP/2 (32 client)',
        :filter => {'protocol' => HTTP2, 'clients' => 32},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/2 (128 clients)',
        :filter => {'protocol' => HTTP2, 'clients' => 128},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true,
        :y_min => 110000,
        :y_max => 135000
      },
      {
        :title => 'QPS HTTP/2',
        :filter => {'protocol' => HTTP2},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'Latency HTTP/2',
        :filter => {'protocol' => HTTP2},
        :x => 'benchmark-tag',
        :y => 'latency',
        :historic => true
      },
      {
        :title => 'CPU utilization HTTP/2',
        :filter => {'protocol' => HTTP2},
        :x => 'benchmark-tag',
        :y => 'cpuutil',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 vs HTTP/2 (1 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 1},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 vs HTTP/2 (4 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 4},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 vs HTTP/2 (8 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 8},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 vs HTTP/2 (32 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 32},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 vs HTTP/2 (128 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 128},
        :x => 'benchmark-tag',
        :y => 'qps',
        :historic => true
      }
    ]
    run_http1_tests
    run_http2_tests
  end

  def test_container_http_performance_with_logging
    deploy_test_app(access_logging: true)
    set_description('Test basic HTTP performance of container with logging enabled')
    @graphs = [
      {
        :title => 'QPS HTTP/1',
        :filter => {'connection' => PERSISTENT},
        :x => 'clients',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 non-persistent',
        :filter => {'connection' => NON_PERSISTENT },
        :x => 'clients',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 persistent (32 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 32 },
        :x => 'clients',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'QPS HTTP/1 persistent (128 clients)',
        :filter => {'connection' => PERSISTENT, 'clients' => 128 },
        :x => 'clients',
        :y => 'qps',
        :historic => true
      },
      {
        :title => 'Latency HTTP/1',
        :filter => {'connection' => PERSISTENT},
        :x => 'clients',
        :y => 'latency',
        :historic => true
      },
      {
        :title => 'CPU utilization HTTP/1',
        :filter => {'connection' => PERSISTENT},
        :x => 'clients',
        :y => 'cpuutil',
        :historic => true
      },
    ]
    run_http1_tests
  end

  def deploy_test_app(access_logging:)
    app = ContainerApp.new.container(
      Container.new.
        component(AccessLog.new(if access_logging then "vespa" else "disabled" end).
          fileNamePattern("logs/vespa/qrs/QueryAccessLog.default")).
        handler(Handler.new('com.yahoo.performance.handler.HelloWorldHandler').
          binding('http://*/HelloWorld').
          bundle('performance')).
        http(
          Http.new.
            server(
              Server.new('http', @container.http_port)).
            server(
              Server.new('https', '4443').
                config(ConfigOverride.new("jdisc.http.connector").
                  add("http2Enabled", true)).
                ssl(Ssl.new(private_key_file = "#{dirs.tmpdir}#{KEY_FILE}", certificate_file = "#{dirs.tmpdir}#{CERT_FILE}", ca_certificates_file=nil, client_authentication='disabled')))))
    deploy_container_app(app)
  end

  def deploy_container_app(app)
    output = deploy_app(app)
    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def run_http1_tests
    run_h2load_benchmark(128, 1, 30, HTTP1)
    run_h2load_benchmark(32, 1, 10, HTTP1)
    run_h2load_benchmark(8, 1, 10, HTTP1)
    run_h2load_benchmark(4, 1, 10, HTTP1)
    run_h2load_benchmark(1, 1, 10, HTTP1)
    run_fbench_benchmark(32, NON_PERSISTENT)
  end

  def run_http2_tests
    run_h2load_benchmark(128, 1, 30, HTTP2)
    run_h2load_benchmark(8, 64, 10, HTTP2)
    run_h2load_benchmark(8, 128, 10, HTTP2)
    run_h2load_benchmark(4, 64, 10, HTTP2)
    run_h2load_benchmark(4, 128, 10, HTTP2)
    run_h2load_benchmark(4, 256, 10, HTTP2)
    run_h2load_benchmark(2, 64, 10, HTTP2)
    run_h2load_benchmark(2, 128, 10, HTTP2)
    run_h2load_benchmark(2, 256, 10, HTTP2)
    run_h2load_benchmark(1, 256, 10, HTTP2)
    run_h2load_benchmark(1, 512, 10, HTTP2)
  end

  def run_fbench_benchmark(clients, connection)
    @container.copy(selfdir + "hello.txt", dirs.tmpdir)
    @queryfile = dirs.tmpdir + "hello.txt"

    profiler_start
    run_fbench(@container, clients, 40,
               [parameter_filler('connection', connection), parameter_filler('protocol', HTTP1),
                parameter_filler('benchmark-tag', "#{HTTP1}-#{clients}-1")],
               {:disable_http_keep_alive => connection == NON_PERSISTENT})
    profiler_report(connection)
    end

  def run_h2load_benchmark(clients, concurrent_streams, warmup, protocol)
    perf = Perf::System.new(@container)
    perf.start
    h2load = Perf::H2Load.new(@container)
    result = h2load.run_benchmark(clients: clients, threads: [clients, 16].min, concurrent_streams: concurrent_streams,
                                  warmup: warmup, duration: 60, uri_port: 4443, uri_path: '/HelloWorld',
                                  protocols: [if protocol == HTTP2 then 'h2' else 'http/1.1' end])
    perf.end
    write_report([result.filler, perf.fill, parameter_filler('connection', PERSISTENT), parameter_filler('protocol', protocol),
                  parameter_filler('benchmark-tag', "#{protocol}-#{clients}-#{concurrent_streams}")])
  end

end

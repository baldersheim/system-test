# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

class Topleveldispatch < VespaNode

  attr_reader :tld, :part, :row

  def initialize(*args)
    super(*args)
    if @service_entry["part"] && @service_entry["row"]
      @part = @service_entry["part"]
      @row = @service_entry["row"]
      @tld = false
    else
      @tld = true
    end
  end

  def self.get_idx(part, row)
    "part[#{part}].row[#{row}]"
  end

  def wait_until_ready(timeout = 60)
    @testcase.output("Wait until topleveldispatch (#{self.config_id}) ready on #{self.hostname} at port " + get_state_port.to_s + " ...")
    endtime = Time.now.to_i + timeout.to_i
    begin
      get_state_v1_config
    rescue StandardError => e
      sleep 0.1
      retry if Time.now.to_i < endtime
      raise "Timeout while waiting for topleveldispatch to become ready: #{e}"
    end
  end

end

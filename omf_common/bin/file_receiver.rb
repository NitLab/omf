# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
DESCR = %{
Receive a file sent to a topic group
}

require 'omf_common'

OP_MODE = :development
$debug = false

opts = {
  communication: {
    #url: 'amqp://srv.mytestbed.net'
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }  
}

file_path = nil
resource_url = nil

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options]\n#{DESCR}\n"
op.on '-r', '--resource-url URL', "URL of resource" do |url|
  resource_url = url
end
op.on '-f', '--file FILE', "Path to store received file" do |path|
  file_path = path
end
op.on '-d', '--debug', "Set logging to DEBUG level" do
  opts[:logging][:level] = 'debug'
  $debug = true
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []

unless resource_url && file_path
  $stderr.puts 'Missing --resource-url or --file'
  $stderr.puts op
  exit(-1)
end

r = resource_url.split('/')
resource = r.pop
opts[:communication][:url] = r.join('/')

OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    comm.receive_file(resource_url, file_path) do |state|
      debug state
      case state[:action]
      when :progress
        puts "Progress: #{(state[:progress] * 100).to_i}%"
      when :done
        puts "Fully received '#{file_path}' (#{state[:mime_type]})"
        OmfCommon.eventloop.stop
      end
    end
  end
end
#
DESCR = %{
Send a create to a specific resource (topic) and print out any replies.

Any additional command line arguments are interpreted as paramters to 
the create.
}

require 'omf_common'

OP_MODE = :development
$debug = false

opts = {
  communication: {
#    url: 'amqp://srv.mytestbed.net'
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }  
}

resource_url = nil
resource_type = nil
resource_properties = {}

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options] type pname1: val1 pname2: val2 ...\n#{DESCR}\n"
op.on '-r', '--resource-url URL', "URL of resource" do |url|
  resource_url = url
end
op.on '-t', '--type TYPE', "Type of resource to create" do |type|
  resource_type = type
end
op.on '-y', '--yaml YAML_FILE', "Read ype and property from YAML file" do |yfile|
  require 'yaml'
  y = YAML.load_file(yfile)
  unless o = y['create']
    puts "Expected top level 'create', but found '#{y.keys.inspect}'"
    abort
  end
  resource_type = o['type']
  resource_properties = o['properties']
end
op.on '-d', '--debug', "Set logging to DEBUG level" do
  opts[:logging][:level] = 'debug'
  $debug = true
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []

unless resource_url || resource_type
  $stderr.puts 'Missing --resource-url --type or'
  $stderr.puts op
  exit(-1)
end

r = resource_url.split('/')
resource = r.pop
opts[:communication][:url] = r.join('/')

key = nil
def err_exit
  $stderr.puts("Options need to be of the 'key: value' type")
  exit(-1)  
end
rest.each do |s|
  sa = s.split(':')
  if sa.length == 2
    err_exit if key
    resource_properties[sa[0]] = sa[1]
  else
    if s.end_with?(':')
      err_exit if key
      key = s[0]
    else
      err_exit unless key
      resource_properties[key] = s[0]
      key = nil
    end
  end
end
err_exit if key

def print_message(msg, resource)
  puts "#{resource}   <#{msg.type}(#{msg.itype})>    #{$debug ? msg.inspect : ''}"
  if msg.itype == 'WARN'
    puts "    #{msg.inspect}"
  end
  msg.each_property do |name, value|
    puts "    #{name}: #{value}"
  end
  puts "------"
end

OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    comm.subscribe(resource) do |ptopic|
      uid = resource_properties[:uid] ||= SecureRandom.uuid # uuid of newly created object
      # ALready subscribe to the new object's topic to not miss
      # any initial messages
      comm.subscribe(uid) do |ctopic|
        ctopic.on_message do |msg|
          print_message(msg, 'NEW')
        end
      
        ptopic.create(resource_type, resource_properties) do |msg|
          print_message(msg, resource)
        end
      end
    end
  end
end
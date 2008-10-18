require 'optparse'

# default options
OPTIONS = {
  :ami       => "ami-1cd73375",
  :codename     => "hardy",
  :bucket        => "cinch_ec2onrails",
  :prefix => "ec2onrails",
  :user => ENV['AMAZON_USER_ID'],
  :access_key => ENV['AMAZON_ACCESS_KEY_ID'],
  :secret_key => ENV['AMAZON_SECRET_ACCESS_KEY'],
  :private_key => ENV['/mnt/pk-*.pem'],
  :cert => ENV['/mnt/cert-*.pem'],
  :script => '/mnt/ec2onrails/server/build-ec2onrails.sh'
}


ARGV.options do |o|
script_name = File.basename($0)

  o.set_summary_indent('  ')
  o.banner =    "Usage: #{script_name} [OPTIONS]"
  o.define_head "Script to build Amazon EC2 as per http://alestic.com/"
  o.separator   ""
  o.separator   "Mandatory arguments to long options are mandatory for " +
                "short options too."
  
  o.on("-a", "--ami=[val]", String,
       "The AMI from http://alestic.com/",
       "Default: #{OPTIONS[:ami]}")   { |OPTIONS[:ami]| }

 o.on("-c", "--codename=[val]", String,
      "The AMI from http://alestic.com/",
      "Default: #{OPTIONS[:codename]}")   { |OPTIONS[:codename]| }

  o.on("-a", "--another=val", Integer,
       "Requires an int argument")      { |OPTIONS[:another]| }
  o.on("-b", "--boolean",
       "A boolean argument")            { |OPTIONS[:bool]| }
  o.on("--list=[x,y,z]", Array, 
       "Example 'list' of arguments")   { |OPTIONS[:list]| }
  
  o.separator ""

  o.on_tail("-h", "--help", "Show this help message.") { puts o; exit }
  
  o.parse!
end

puts "first:     #{OPTIONS[:first]}"
puts "another:   #{OPTIONS[:another]}"
puts "bool:      #{OPTIONS[:bool]}"
puts "list:      #{OPTIONS[:list].join(',')}"
puts "arguments: #{ARGV}"
if __FILE__ == $0

end
#!/usr/bin/ruby
      
#   Based on a portion of the ec2onrails backup_app_db.rb
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#    Copyright 2009 Robert J. Berger Runa.com

#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
require "rubygems"
require "optiflag"
require "fileutils"
require 'EC2'
require "#{File.dirname(__FILE__)}/../lib/mysql_helper"
require "#{File.dirname(__FILE__)}/../lib/s3_helper"
require "#{File.dirname(__FILE__)}/../lib/aws_helper"
require "#{File.dirname(__FILE__)}/../lib/roles_helper"

require "#{File.dirname(__FILE__)}/../lib/utils"
    
module CommandLineArgs extend OptiFlagSet
  optional_flag "bucket"  
  optional_flag "dir"
  optional_switch_flag "incremental"
  optional_switch_flag "reset"
  and_process!
end

@aws   = Ec2onrails::AwsHelper.new
vols = YAML::load(File.read("/etc/ec2onrails/ebs_hbase_info.yml"))
#vols = {"/mnt/hadoop_datastore"=>{"volume_id"=>"vol-2255b54b", "block_loc"=>"/dev/sdc"}}
ec2 = EC2::Base.new( :access_key_id => @aws.aws_access_key, :secret_access_key => @aws.aws_secret_access_key )

#lets make sure we have space: AMAZON puts a 500 limit on the number of snapshots
snaps = ec2.describe_snapshots['snapshotSet']['item'] rescue nil
if snaps && snaps.size > 450
  # TODO:
  # can we make this a bit smarter?  With a limit of 500, that is difficult.  
  # possible ideas (and some commented out code below)
  #  * only apply cleanups to the volume_ids attached to this instance
  #  * keep the last week worth (at hrly snapshots), then daily for a month, then monthly
  #  * a sweeper task 
  #
  # vol_ids = []
  # vols.each_pair{|k,v| vol_ids << v['volume_id']}
  # #lets only work on those that apply for these volumnes attached 
  # snaps = snaps.collect{|sn| vol_ids.index(sn['volumeId']) ? sn : nil}.compact
  # # get them sorted
  snaps = snaps.sort_by{|snapshot| snapshot['startTime']}.reverse
  curr_batch = {}
  remaining = []
  snaps[200..-1].each do |sn| 
    next if sn.blank? || sn['status'] != 'completed'
    today = Date.parse(sn['startTime']).to_s
    if curr_batch[sn['volumeId']] != today
      curr_batch[sn['volumeId']] = today
      remaining << sn
    else
      ec2.delete_snapshot(:snapshot_id => sn['snapshotId'])
    end
    # next unless vol_ids.index(sn['volumeId'])
  end
  if remaining.size > 400
    puts "  WARNING: still contains #{remaining.size} snapshots; removing the oldest 100 to clean up space"
    remaining[350..-1].each do |sn|
      ec2.delete_snapshot(:snapshot_id => sn['snapshotId'])
    end
  end
else
  puts "Could not retrieve snapshots: auto archiving cleanup will not occur" unless snaps
end

cwd = Dir.pwd
Dir.chdir('/etc/event.d')
furtive_list = Dir.glob('furtive[0-9]')
Dir.chdir(cwd)

begin
  furtive_list.each do |furtive|
    puts "Stopping #{furtive}"
    `sudo initctl stop #{furtive}`
  end
  vols.each_pair do |mount, ebs_info|
    begin
      puts "Freezing #{mount}"
      `sudo xfs_freeze -f #{mount}`
      puts "Snapshotting volume: #{ebs_info['volume_id']}"
      output = ec2.create_snapshot(:volume_id => ebs_info['volume_id'])
      snap_id = output['CreateSnapshotResponse']['snapshotId'] rescue nil
      snap_id ||= output['snapshotId'] rescue nil #this is for the old version of the amazon-ec2
      if snap_id.nil? || snap_id.empty?
        puts "Snapshot for #{ebs_info['volume_id']} FAILED"
        exit
      end
      vol_id  = ebs_info['volume_id']
   ensure
      puts "UnFreezing #{mount}"
      `sudo xfs_freeze -u #{mount}`
    end
  end
ensure
  furtive_list.each do |furtive|
    puts "Staring #{furtive}"
    `sudo initctl start #{furtive}`
  end
end

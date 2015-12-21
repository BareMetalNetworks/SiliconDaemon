#!/usr/bin/env ruby -w
$VERSION = '1.0.0'
$DATE = '12/15/15'
$DEBUG = false
require 'redis'
require 'redis-objects'
require 'connection_pool'

host = ARGV[0] || 'stack0'
failover1 = ARGV[3] || '10.0.1.75'
failover2 = ARGV[4] || 'stack1'
failover3 = ARGV[5] || 'stack2'
failover4 = '10.0.1.150'
failover5 = '10.0.1.151'

db = ARGV[1].to_i || 10

$hostname = `hostname`
$delay = ARGV[2].to_i || 10

def run_stats_loop
  counter = 0 if $DEBUG
  loop do
    p "Loop Iter: #{counter}" if $DEBUG
    dstat = `dstat  --cpu -l -p -dmi -y --tcp -D total,sda,sdb,sdc,sdd,sde --udp -y -g --top-cpu-adv --top-mem --top-io --disk-tps --proc-count 1 0|tail -1`
    $SHM << "#{Time.now.to_i} " + dstat
    if $DEBUG
      p "#{Time.now}: Inserted the following into redis: " + $SHM.values
    end

    counter += 1 if $DEBUG
    sleep $delay
  end
end


begin
  failovers = [failover1, failover2, failover3, failover4, failover5]
  Redis::Objects.redis = ConnectionPool.new(size: 3, timeout: 5) {
    Redis.new({host: host, port: '6379', db: db})}

  $SHM = Redis::List.new("system:stats:#{$hostname}", :marshal => true)
  `dstat 1 0`
  run_stats_loop
rescue Errno::ENOENT =>  err
  raise "You are missing dstat, please install and try again"
rescue SocketError => err
  if failovers
    host = failovers.pop
    sleep 15
    retry
  else
    raise "Exhausted redis server failovers, check infrastructure"
  end
end






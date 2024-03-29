#!/usr/bin/env ruby

shutdown = false
cnf_path = Dir.pwd + '/my_ramdisk.cnf'
ramdisk_path = '/Volumes/RAMDisk'

loop { case ARGV[0]
    when 'shutdown' then  ARGV.shift; shutdown = true
    else break
end; }
 
if shutdown
    puts 'Shutting down mysql on ramdisk'
    if system('mysqladmin -u root -h 127.0.0.1 -P3307 shutdown')
        puts 'Shutdown initated, waiting 5 seconds and removing ramdisk'
        sleep 5
        puts 'Unmounting ramdisk'
        if system('hdiutil detach ' + ramdisk_path)
            puts 'Unmounting done'
        else
            puts 'Unmounting failed, waiting 5 more seconds and retrying'
            if system('hdiutil detach ' + ramdisk_path)
                puts 'Unmounting done'
            else
                puts 'Unmounting failed, please try to unmount manually'
                abort
            end
        end
    else
        puts 'Shutdown failed'
    end
    exit
end
 
if File.directory?(ramdisk_path)
    puts 'Ramdisk already exist, please use "./ramdisk.rb shutdown" to clean up things'
    abort
end
 
puts 'Detecting mysql vendor'
 
if File.directory?('/usr/local/opt/percona-server')
    mysql_basedir = '/usr/local/opt/percona-server'
elsif File.directory?('/usr/local/opt/mysql')
    mysql_basedir = '/usr/local/opt/mysql'
elsif File.directory?('/usr/local/opt/mariadb')
    mysql_basedir = '/usr/local/opt/mariadb'
else
    puts 'Cannot find a valid mysql basedir'
    abort
end
 
puts 'Writing mysql configuration file ' + cnf_path
 
begin
  file = File.open(cnf_path, "w")
  file.write("[mysqld]
port = 3307
socket = /tmp/mysql-ramdisk.sock
datadir = #{ramdisk_path}
") 
rescue IOError
  puts 'Error writing file!'
  abort
ensure
  file.close unless file == nil
end
 
puts 'Creating ramdisk at ' + ramdisk_path
 
if system('diskutil erasevolume HFS+ RAMDisk `hdiutil attach -nomount ram://1048576` > /dev/null')
    puts 'Creation succesfull'
else
    puts 'Creation failed'
end
 
puts 'Initialiting default mysql database into ramdisk'
 
if system('mysql_install_db --basedir=' + mysql_basedir + ' --datadir=' + ramdisk_path + ' > /dev/null')
    puts 'Initialization done'
else
    puts 'Initialization failed'
    abort
end
 
puts 'Starting mysql instance on port 3307 using ramdisk as data folder storage. Also creating test db'
 
# spawn('mysqld_safe --defaults-file=' + cnf_path + ' --general_log=1 --general_log_file=' + ramdisk_path + '/general_log.log > /dev/null && mysqladmin -u root -h 127.0.0.1 -P3307 create test')
spawn('mysqld_safe --defaults-file=' + cnf_path + ' > /dev/null && mysqladmin -u root -h 127.0.0.1 -P3307 create drupal_test')

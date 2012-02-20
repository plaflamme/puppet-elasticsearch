# Class: elasticsearch
#
# This class installs Elasticsearch
#
# Usage:
# include elasticsearch

class elasticsearch($version = "0.18.7", $cluster = "elasticsearch", $dataPath="/var/lib/elasticsearch", $xms = "256m", $xmx = "2048m") {
     $esBasename       = "elasticsearch"
     $esName           = "${esBasename}-${version}"
     $esFile           = "${esName}.tar.gz"
     $esServiceName    = "${esBasename}-servicewrapper"
     $esServiceFile    = "${esServiceName}.tar.gz"
     $esBasePath       = "/usr/local"
     $esPath           = "${esBasePath}/${esName}"
     $esPathLink       = "${esBasePath}/${esBasename}"
     $esDataPath       = "${dataPath}"
     $esLogPath        = "/var/log/${esBasename}"
     $esXms            = "${xms}"
     $esXmx            = "${xmx}"
     $esTCPPortRange   = "9300-9399"
     $esHTTPPortRange  = "9200-9299"
     $esUlimitNofile   = "32000"
     $esUlimitMemlock  = "unlimited"
     $esPidpath        = "/var/run/{$esBasename}"
     $esPidfile        = "${esPidpath}/${esBasename}.pid"
     $esJarfile        = "${esName}.jar"

     include wget

     # TODO: support other OS package names?
     package { 'openjdk-6-jdk' : 
       ensure => installed
     }

     # Ensure the elasticsearch user is present
     user { "$esBasename":
       ensure => "present",
       comment => "Elasticsearch user created by puppet",
       managehome => true,
       shell   => "/bin/false"
     }

     file { "/etc/security/limits.d/${esBasename}.conf":
       content => template("elasticsearch/elasticsearch.limits.conf.erb"),                                                                                                    
       ensure => present,
       owner => root,
       group => root,
     }

#     file { "/etc/init/${esBasename}.conf":
#       content => template("elasticsearch/upstart.elasticsearch.conf.erb"),
#       ensure => present,
#       owner => root,
#       group => root,
#       mode => 644,
#       require => File["/etc/init.d/elasticsearch"]
#     }

     # Make sure we have the application path
     file { "$esPath":
       ensure     => directory,
       owner      => "$esBasename",
       group      => "$esBasename", 
       recurse    => true,
       require    => [ User["$esBasename"], Exec["elasticsearch-package"] ]
     }

     wget::fetch { "tarball-${version}" :
       source      => "https://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-${version}.tar.gz",
       destination => "/tmp/$esFile"
     }

     exec { "elasticsearch-package" :
       command => "tar -zxf /tmp/$esFile",
       cwd     => "$esBasePath",
       path    => ["/bin", "/sbin", "/usr/bin", "/usr/sbin"],
       creates => "$esPath",
       require => Wget::Fetch["tarball-${version}"],
     }

     # Create link to /usr/local/<esBasename> which will be the current version
     file { "$esPathLink" :
       ensure  => link,
       target  => "$esPath",
     }

     # Ensure the data path is created
     file { "$esDataPath":
       ensure  => directory,
       owner   => "$esBasename",
       group   => "$esBasename",
       require => Exec["elasticsearch-package"],
       recurse => true
     }

     # Ensure the link to the data path is set
     file { "$esPath/data":
       ensure => link,
       force => true,
       target => "$esDataPath",
       require => File["$esDataPath"]
     }

     # Symlink config to /etc
     file { "/etc/$esBasename":
       ensure => link,
       target => "$esPathLink/config",
       require => Exec["elasticsearch-package"],
     }

     # Apply config template for search
     file { "$esPath/config/elasticsearch.yml":
       content => template("elasticsearch/elasticsearch.yml.erb"),
       require => File["/etc/$esBasename"]      
     }

     file { "/etc/init.d/elasticsearch":
       content => template("elasticsearch/elasticsearch.init.erb"),                                                                                                    
       ensure  => present,
       mode    => 755,
       owner   => root,
       group   => root,
     }

     # Ensure logging directory
     file { "$esLogPath":
       owner     => "$esBasename",
       group     => "$esBasename",
       ensure    => directory,
       recurse   => true,
       require   => Exec["elasticsearch-package"],
     }

	 file { "${esPidpath}":
	   ensure => directory,
       owner     => "$esBasename",
       group     => "$esBasename",
	 }    

     file { "$esPath/logs":
       ensure => link,
       target => "${esLogPath}",
       force  => true
     }

     # Ensure the service is running
     service { "$esBasename":
       enable => true,
       ensure => running,
       hasrestart => true,
       require => [ File["/etc/init.d/elasticsearch"], File["$esPath/logs"] ],
       subscribe => File["$esPathLink"]
     }
}

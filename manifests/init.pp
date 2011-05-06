# Class: elasticsearch
#
# This class installs Elasticsearch
#
# Usage:
# include elasticsearch

class elasticsearch($version) {
      $esBasename       = "elasticsearch"
      $esName           = "${esBasename}-${version}"
      $esFile           = "${esName}.tar.gz"
      $esServiceName    = "${esBasename}-servicewrapper"
      $esServiceFile    = "${esServiceName}.tgz"
      $esPath           = "${ebs1}/usr/local/${esName}"
      $esPathLink       = "/usr/local/${esBasename}"
      $esDataPath       = "${ebs1}/var/lib/${esBasename}"
      $esLogPath        = "${ebs1}/var/log/${esBasename}"
      $esXms            = "256"
      $esXmx            = "2048"
      $cluster          = "${esBasename}"
      $esTCPPortRange   = "9300-9399"
      $esHTTPPortRange  = "9200-9299"
      
      # Ensure the elasticsearch user is present
      user { "$esBasename":
               ensure => "present",
               comment => "Elasticsearch user created by puppet",
               managehome => true,
               shell   => "/bin/false",          
               require => lvmconfig[$ebs1]
     }
     
     # Set this users file handle limits (ES uses a shit ton of file handles)
     file { "/etc/security/limits.conf":
             source => "puppet:///elasticsearch/limits.conf",
             require => user["$esBasename"]
     }

     exec { "mkdir-ebs-mongohome":
          path => "/bin:/usr/bin",
          command => "mkdir -p $ebs1/usr/local",
          before => File["$esPath"],
          require => user["$esBasename"]
     }    

     # Make sure we have the application path
     file { "$esPath":
             ensure     => directory,
             require    => User["$esBasename"],
             owner      => "$esBasename",
             group      => "$esBasename", 
             recurse    => true
      }
      
      # Temp location
      file { "/tmp/$esFile":
             source  => "puppet:///elasticsearch/$esFile",
             require => File["$esPath"],
             owner => "$esBasename"
      }
      
      # Remove old files and copy in latest
      exec { "elasticsearch-package":
             path => "/bin:/usr/bin",
             command => "mkdir -p $esPath && tar -xzf /tmp/$esFile -C /tmp && sudo -u$esBasename cp -rf /tmp/$esName/. $esPath/. && rm -rf /tmp/$esBasename*", 
             unless  => "test -f $esPath/bin/elasticsearch",
             require => file["/tmp/$esFile"],
             notify => Service["$esBasename"],
      }
      
      # Create link to /usr/local/<esBasename> which will be the current version
      file { "$esPathLink":
           ensure => link,
           target => "$esPath",
           require => File["$esPath"]
      }
      
      # Ensure the data path is created
      file { "$esDataPath":
           ensure => directory,
           owner  => "$esBasename",
           group  => "$esBasename",
           require => Exec["elasticsearch-package"],
           recurse => true           
      }

      # Ensure the link to the data path is set
      file { "$esPath/data":
           ensure => link,
           target => "$esDataPath",
           require => File["$esDataPath"]
      }

      # Symlink config to /etc
      file { "/etc/$esBasename":
             ensure => link,
             target => "$esPathLink",
             require => Exec["elasticsearch-package"],
      }

      # Apply config template for search
      file { "$esPath/config/elasticsearch.yml":
             content => template("elasticsearch/elasticsearch.yml.erb"),
             require => File["/etc/$esBasename"]      
      }
      
      # Stage the Service Package
      file { "/tmp/$esServiceFile":
           source => "puppet:///elasticsearch/$esServiceFile",
            require => Exec["elasticsearch-package"]
      }
      
      # Move the service wrapper into place
      exec { "elasticsearch-service":
             path => "/bin:/usr/bin",
             unless => "test -d $esPath/bin/service/lib",
             command => "tar -xzf /tmp/$esServiceFile -C /tmp && mv /tmp/$esServiceName/service $esPath/bin && rm /tmp/$esServiceFile",
             require => [file["/tmp/$esServiceFile"], user["$esBasename"]]
      }

      # Ensure the service is present
      file { "$esPath/bin/service":
           ensure => directory,
           owner  => elasticsearch,
           group  => elasticsearch,
           recurse => true,
           require => Exec["elasticsearch-service"]
      }

      # Set the service config settings
      file { "$esPath/bin/service/elasticsearch.conf":
             content => template("elasticsearch/elasticsearch.conf.erb"),
             require => file["$esPath/bin/service"]
      }
      
      # Add customized startup script (see: http://www.elasticsearch.org/tutorials/2011/02/22/running-elasticsearch-as-a-non-root-user.html)
      file { "$esPath/bin/service/elasticsearch":
             source => "puppet:///elasticsearch/elasticsearch",
             require => file["$esPath/bin/service"]
      }

      # Create startup script
      file { "/etc/init.d/elasticsearch":
             ensure => link,
             target => "$esPath/bin/service/./elasticsearch",
             require => File["$esPath/bin/service/elasticsearch"]
      }

      # Ensure logging directory
      file { "$esLogPath":
           owner     => "$esBasename",
           group     => "$esBasename",
           ensure    => directory,
           recurse   => true,
           require   => exec["elasticsearch-package"],
      }
      
      # Ensure logging link is in place
      file { "/var/log/$esBasename":
           ensure => link,
           target => "$esLogPath",
           require => [exec["elasticsearch-package"], File["/etc/init.d/$esBasename"]]
      }
      
      notify {"finished":
            message => "Elastic search $esVersion installed",
            require => File["/var/log/$esBasename"]
      }
      
      # Ensure the service is running
      service { "$esBasename":
            ensure => running,
            require => Notify["finished"]
      }

}
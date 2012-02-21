define elasticsearch::plugin($plugin = $name, $source = $name, $cmd="install") {

  import "elasticsearch"

  exec { "install-plugin-${plugin}":
    command => "/usr/local/elasticsearch/bin/plugin -${cmd} $source",
    user    => "elasticsearch",
    group   => "elasticsearch",
    creates => "/usr/local/elasticsearch/plugins/$plugin",
    require => File["/usr/local/elasticsearch"],
    notify  => Service["elasticsearch"],
  }
}

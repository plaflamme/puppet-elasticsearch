define elasticsearch::plugin($plugin = $name, $source = $name, $cmd="install") {

  import "elasticsearch"

  exec { "install-plugin-${plugin}":
    command => "/usr/local/elasticsearch/bin/plugin -${cmd} $source",
    user    => "elasticsearch",
    creates => "/usr/local/elasticsearch/plugins/$plugin",
    notify  => Service["elasticsearch"],
  }
}

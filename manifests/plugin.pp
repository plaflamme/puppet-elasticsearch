define elasticsearch::plugin($source, $plugin = $name, $cmd="install") {

  include elasticsearch

  exec { "install-plugin":
    command => "/usr/local/elasticsearch/bin/plugin -${cmd} $source",
    user    => "elasticsearch",
    creates => "/usr/local/elasticsearch/plugins/$name",
    notify  => Service["elasticsearch"],
  }
}

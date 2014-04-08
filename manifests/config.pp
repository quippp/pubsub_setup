# configure pubsub:

class pubsub_setup::config(
  $deploy_user = $pubsub_setup::params::deploy_user,
  $git_user    = $pubsub_setup::params::git_user,
  $git_pass    = $pubsub_setup::params::git_pass,
  $git_url     = $pubsub_setup::params::git_url,
  $git_branch  = $pubsub_setup::params::git_branch,
  $app_name    = $pubsub_setup::params::app_name,
  $deploy_env  = $pubsub_setup::params::deploy_env,
  ) inherits pubsub_setup::params {

  file { '/etc/monit/monitrc':
    ensure       => file,
    source       => 'puppet:///modules/pubsub_setup/monitrc',
    require      => Package['monit'],
    notify       => Service['monit'],
  }

  # file { '/etc/monit/conf.d/pubsub.conf':
  #   ensure       => 'file',
  #   source       => 'puppet:///modules/pubsub_setup/monit_pubsub.conf',
  #   require      => Package['monit'],
  #   notify       => Service['monit'],
  # }

  if !defined(User[$deploy_user]) {
    # password is foobar, but we aren't going
    # to use it anyway.
    user { $deploy_user:
      ensure      => present,
      managehome  => true,
      shell       => '/bin/bash',
      password    => '$1$Zn4UIQ5U$oh4IqMnvkRuqYZQbdXJl91',
    }
  }

  if $deploy_env == 'vagrant' {

    exec { "git-clone-${app_name}":
      command => "git clone -b ${git_branch} https://${git_user}:${git_pass}@${git_url}/${app_name}",
      timeout => 0,
      user    => $deploy_user,
      group   => $deploy_user,
      cwd     => "/home/${deploy_user}",
      creates => "/home/${deploy_user}/${app_name}",
      require => [ Package['git-core'], User[$deploy_user]],
    }

    exec { "git-pull-${app_name}":
      user    => $deploy_user,
      group   => $deploy_user,
      timeout => 0,
      cwd     => "/home/${deploy_user}/${app_name}",
      command => 'git pull',
      require => Exec["git-clone-${app_name}"],
    }

    $npm_require = [ Exec["git-pull-${app_name}"], Package['nodejs'] ]
  } else {
    $npm_require = [ Package['nodejs'], User[$deploy_user] ]
  }

  if $deploy_env in ['vagrant', 'development'] {
    exec { 'npm-install':
      command     => 'npm install',
      logoutput   => true,
      timeout     => 0,
      cwd         => "/home/${deploy_user}/${app_name}",
      require     => $npm_require,
    }

    exec { 'copy-configjs':
      command     => 'cp config.js.sample config.js',
      user        => $deploy_user,
      group       => $deploy_user,
      cwd         => "/home/${deploy_user}/${app_name}/config",
      creates     => "/home/${deploy_user}/${app_name}/config/config.js",
      require     => Exec['npm-install'],
    }

    exec { "start-server-${app_name}":
      command     => 'node app.js&',
      user        => $deploy_user,
      group       => $deploy_user,
      cwd         => "/home/${deploy_user}/${app_name}",
      unless      => "ps ax | grep '[n]ode app.js'",
      require     => Exec['copy-configjs'],
    }
  }

}

class graphite::base {
  include memcache::base
  include apache2::stock_apache
  include daemontools

  # Packages the host needs:
  package { [python-django, python-cairo, python-memcache, python-pip,
            python-sqlite, python-django-tagging, python-dev]:
    ensure => installed,
  }

  # Packages containing Apache mods
  package { [libapache2-mod-wsgi]:
    ensure  => installed,
    require => Package['apache2'],
  }

  # Enable the Apache mods
  apache2::stock_apache_mods::loadmod { 'mod_wsgi':
    modname => 'wsgi',
    require => Package['libapache2-mod-wsgi'],
  }

  # WSGI unix sockets directory
  file { '/var/run/apache2/wsgi':
    ensure  => directory,
    require => Package['libapache2-mod-wsgi'],
  }

  # This forces apache2::stock_apache to turn on its own default config,
  # which gets rid of the useless "It Works!" default.
  apache2::stock_apache::site_enable { 'default':
  }

  # Install the Graphite python packages using pip
  package { 'carbon':
    ensure   => $::graphite_version,
    provider => pip,
    require  => Package['python-pip'],
  } ->
  package { 'whisper':
    ensure   => $::graphite_version,
    provider => pip,
    require  => Package['python-pip'],
  } ->
  package { 'graphite-web':
    ensure   => $::graphite_version,
    provider => pip,
    require  => Package['python-pip'],
    notify   => Service['apache2'],
  }

  file { '/var/log/carbon-aggregator':
    ensure => directory,
  } ->
  helpers::daemontools::svcadd { 'carbon-aggregator':
    svcstart => template('graphite/carbon-aggregator.run.erb'),
    require  => Package['carbon'],
    logpath  => '/var/log/carbon-aggregator',
  }

  file { '/var/log/carbon-cache':
    ensure => directory,
  } ->
  helpers::daemontools::svcadd { 'carbon-cache':
    svcstart => template('graphite/carbon-cache.run.erb'),
    require  => Package['carbon'],
    logpath  => '/var/log/carbon-cache',
  }

  file { '/opt/graphite/conf/carbon.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/graphite/carbon.conf',
    require => Package['carbon'],
  }

  file { '/opt/graphite/conf/storage-schemas.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/graphite/storage-schemas.conf',
    require => Package['whisper'],
  }

  file { '/opt/graphite/conf/storage-aggregation.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/graphite/storage-aggregation.conf',
    require => Package['whisper'],
  }

  file { '/opt/graphite/conf/graphite.wsgi':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/graphite/graphite.wsgi',
    require => Package['graphite-web'],
  }

  file { '/opt/graphite/webapp/graphite/local_settings.py':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/graphite/local_settings.py',
    require => Package['graphite-web'],
  }

  file { '/etc/apache2/sites-enabled/graphite.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('graphite/graphite.conf.erb'),
    require => Package['apache2'],
  }

  # Graphite storage dirs
  group { 'graphite':
    ensure  => present,
    gid     => '2003',
  } ~>
  user { 'graphite':
    ensure  => present,
    comment => 'Graphite user',
    gid     => 'graphite',
    uid     => '2003',
    shell   => '/usr/bin/false',
  } ~>
  file { '/opt/graphite/storage':
    ensure  => directory,
    owner   => 'graphite',
    group   => 'www-data',
    mode    => '0664',
    recurse => true,
  } ~>
  exec { 'create_graphite_db':
    user    => 'graphite',
    cwd     => '/opt/graphite/webapp/graphite',
    path    => ['/usr/bin/', '/usr/local/bin'],
    command => 'python manage.py syncdb --noinput',
    creates => '/opt/graphite/storage/graphite.db',
  } ->
  file { '/opt/graphite/storage/graphite.db':
    owner   => 'graphite',
    group   => 'www-data',
    mode    => '0664',
  }

}

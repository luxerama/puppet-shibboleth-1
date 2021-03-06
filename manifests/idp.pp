# == Class shibboleth::idp
#
# Installs shibboleth's identity provider. This involves building the war file and deploying
# it in a tomcat instance, and setting up various files and directories in /opt and /etc.
# Shibboleth itself gets installed in /opt/shibboleth-idp.
#
# Class parameters:
# - *shibidp_version*: shibboleth version, defaults to 2.1.5
# - *shibidp_hostname*: the DNS name the service will get accessed through.
#   Defaults to localhost.
# - *shibidp_keypass*: the passphrase of the generated certificate.
# - *shibidp_javahome*: the JAVA_HOME path. Defaults to /usr.
#
# Requires:
# - Tomcat
#
class shibboleth::idp(
  $shibidp_version,
  $shibidp_hostname = 'localhost',
  $shibidp_keypass,
  $shibidp_javahome = '/usr',
  $shibidp_tomcat = false,
) {

  $shibidp_home = "/opt/shibboleth-idp-${shibidp_version}"
  $mirror = 'http://shibboleth.net/downloads/identity-provider'
  $url = "${mirror}/${shibidp_version}/shibboleth-identityprovider-${shibidp_version}-bin.zip"

  $shibidp_installdir = "/usr/src/shibboleth-identityprovider-${shibidp_version}"

  archive::zip { "${shibidp_installdir}/.installed":
    source => $url,
    target => '/usr/src/',
  }

  # see http://ant.apache.org/faq.html#passing-cli-args
  exec { 'install shibboleth idp':
    command     => "cd ${shibidp_installdir} && ./install.sh",
    environment => [
      "JAVA_HOME=${shibidp_javahome}",
      "ANT_OPTS=-Didp.home.input=${shibidp_home} -Didp.hostname.input=${shibidp_hostname} -Didp.keystore.pass=${shibidp_keypass}",
    ],
    creates     => ["${shibidp_home}/war/idp.war"],
    require     => Archive::Zip["${shibidp_installdir}/.installed"],
  }

  file { '/opt/shibboleth-idp':
    ensure  => link,
    target  => $shibidp_home,
    require => Exec['install shibboleth idp'],
  }

  file { '/opt/shibboleth-idp/logs':
    ensure  => directory,
    owner   => 'tomcat',
    mode    => '0755',
    require => [Exec['install shibboleth idp'], File['/opt/shibboleth-idp']],
  }

  file { '/etc/shibboleth':
    ensure  => link,
    target  => '/opt/shibboleth-idp/conf',
    require => [File['/opt/shibboleth-idp'], Exec['install shibboleth idp']],
  }

  file { '/var/log/shibboleth':
    ensure  => link,
    target  => '/opt/shibboleth-idp/logs',
    require => [File['/opt/shibboleth-idp'], Exec['install shibboleth idp']],
  }

  if ( $shibidp_tomcat ) {

    # copy war file from installation dir to tomcat webapp dir.
    # see also
    # https://spaces.internet2.edu/display/SHIB2/IdPApacheTomcatPrepare for an
    # alternate method.
    file { "/srv/tomcat/${shibidp_tomcat}/webapps/idp.war":
      source  => "file:///${shibidp_home}/war/idp.war",
      notify  => Service["tomcat-${shibidp_tomcat}"],
      require => [
        File["/srv/tomcat/${shibidp_tomcat}/webapps/"],
        Exec['install shibboleth idp'],
      ],
    }

    # Copy library shipped with source to tomcat dir.
    # Don't forget to point the common.loader variable to this directory in
    # your catalina.properties file !
    file { "/srv/tomcat/${shibidp_tomcat}/private/endorsed/":
      ensure  => directory,
      source  => "file:///${shibidp_installdir}/endorsed/",
      recurse => true,
      require => [
        Archive::Zip["${shibidp_installdir}/.installed"],
        File['/srv/tomcat/shibb-idp/private/'],
      ],
      notify  => Service["tomcat-${shibidp_tomcat}"],
    }

  }

}

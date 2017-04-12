name 'cerny_chef'
maintainer 'Nathan Cerny'
maintainer_email 'ncerny@gmail.com'
license 'apachev2'
description 'Installs/Configures cerny_chef'
long_description 'Installs/Configures cerny_chef'
version '0.2.2'

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
issues_url 'https://github.com/cerny-cc/cerny_chef/issues' if respond_to?(:issues_url)

# The `source_url` points to the development reposiory for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
source_url 'https://github.com/cerny-cc/cerny_chef' if respond_to?(:source_url)

depends 'chef_stack'
depends 'ntp'
depends 'hostsfile'

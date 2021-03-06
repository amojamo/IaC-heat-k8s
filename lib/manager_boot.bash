#!/bin/bash -v
tempdeb=$(mktemp /tmp/debpackage.XXXXXXXXXXXXXXXXXX) || exit 1
wget -O "$tempdeb" https://apt.puppetlabs.com/puppet6-release-bionic.deb
dpkg -i "$tempdeb"
apt-get update

# Install and make sure Puppet isn't running before getting the environment
apt-get -y install puppetserver
/opt/puppetlabs/bin/puppet resource service puppet ensure=stopped enable=true
/opt/puppetlabs/bin/puppet resource service puppetserver ensure=stopped enable=true

# Configure puppet agent, and puppetserver autosign
/opt/puppetlabs/bin/puppet config set server manager.star.wars --section main
/opt/puppetlabs/bin/puppet config set certname manager.star.wars --section main
/opt/puppetlabs/bin/puppet config set runinterval 300 --section main
/opt/puppetlabs/bin/puppet config set autosign true --section master

# r10 and control-repo deploys:
/opt/puppetlabs/bin/puppet module install puppet-r10k
cat <<EOF > /var/tmp/r10k.pp
class { 'r10k':
  sources => {
    'puppet' => {
      'remote'  => 'https://github.com/amojamo/imt3005tick.git',
      'basedir' => '/etc/puppetlabs/code/environments',
      'prefix'  => false,
    },
  },
}
EOF
/opt/puppetlabs/bin/puppet apply /var/tmp/r10k.pp
r10k deploy environment -pv

# Add hostname to hosts file
echo "$(ip a | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | tr -d 'inet ' | grep -v '^127') $(hostname).star.wars $(hostname)" >> /etc/hosts

# Enable Puppet and run agent to update catalogues 
/opt/puppetlabs/bin/puppet resource service puppetserver ensure=running enable=true
/opt/puppetlabs/bin/puppet agent -t # request certificate
/opt/puppetlabs/bin/puppet agent -t # configure manager
/opt/puppetlabs/bin/puppet agent -t # once more to update exported resources
/opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true
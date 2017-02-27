#! /bin/bash

# Variables
source config.sh

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

noroot() {
  sudo -EH -u "vagrant" "$@";
}

# Install EasyEngine
install_ee() {
    noroot
    echo "Installing EasyEngine"
    echo -e "[user]\n\tname = $git_user\n\temail = $git_email" > ~/.gitconfig

    wget -qO ee rt.cx/ee && sudo bash ee  || exit 1

    echo "Installing EasyEngine Stack"
    ee stack install

    # Add the vagrant user to the www-data group so that it has better access
    # to PHP and Nginx related files.
    usermod -a -G www-data vagrant
}

profile_setup() {
    # Copy custom dotfiles and bin file for the vagrant user from local
    cp "/srv/config/bash_profile" "/home/vagrant/.bash_profile"
    cp "/srv/config/bash_aliases" "/home/vagrant/.bash_aliases"

    if [[ ! -d "/home/vagrant/bin" ]]; then
        mkdir "/home/vagrant/bin"
    fi

    rsync -rvzh --delete "/srv/config/homebin/" "/home/vagrant/bin/"

    echo " * Copied /srv/config/bash_profile                      to /home/vagrant/.bash_profile"
    echo " * Copied /srv/config/bash_aliases                      to /home/vagrant/.bash_aliases"
    echo " * rsync'd /srv/config/homebin                          to /home/vagrant/bin"
}

php_codesniff() {
  # PHP_CodeSniffer (for running WordPress-Coding-Standards)
  if [[ ! -d "/var/www/phpcs" ]]; then
    echo -e "\nDownloading PHP_CodeSniffer (phpcs), see https://github.com/squizlabs/PHP_CodeSniffer"
    git clone -b master "https://github.com/squizlabs/PHP_CodeSniffer.git" "/var/www/phpcs"
  else
    cd /var/www/phpcs
    if [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo -e "\nUpdating PHP_CodeSniffer (phpcs)..."
      git pull --no-edit origin master
    else
      echo -e "\nSkipped updating PHP_CodeSniffer since not on master branch"
    fi
  fi

  # Link `phpcbf` and `phpcs` to the `/usr/local/bin` directory
  ln -sf "/var/www/phpcs/scripts/phpcbf" "/usr/local/bin/phpcbf"
  ln -sf "/var/www/phpcs/scripts/phpcs" "/usr/local/bin/phpcs"

  # Sniffs WordPress Coding Standards
  if [[ ! -d "/var/www/phpcs/CodeSniffer/Standards/WordPress" ]]; then
    echo -e "\nDownloading WordPress-Coding-Standards, sniffs for PHP_CodeSniffer, see https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards"
    git clone -b master "https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards.git" "/var/www/phpcs/CodeSniffer/Standards/WordPress"
  else
    cd /var/www/phpcs/CodeSniffer/Standards/WordPress
    if [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo -e "\nUpdating PHP_CodeSniffer WordPress Coding Standards..."
      git pull --no-edit origin master
    else
      echo -e "\nSkipped updating PHPCS WordPress Coding Standards since not on master branch"
    fi
  fi

  # Install the standards in PHPCS
  phpcs --config-set installed_paths ./CodeSniffer/Standards/WordPress/
  phpcs --config-set default_standard WordPress-Core
  phpcs -i
}

php_search_replace() {
  # Search Replace DB
  if [[ ! -d "/var/www/22222/htdocs/sr" ]]; then
    echo -e "\nDownloading Search Replace DB, see https://github.com/interconnectit/Search-Replace-DB"
    git clone -b master "https://github.com/interconnectit/Search-Replace-DB.git" "/var/www/22222/htdocs/sr"
  else
    cd /var/www/22222/htdocs/sr
    if [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]; then
      echo -e "\nUpdating Search Replace DB..."
      git pull --no-edit origin master
    else
      echo -e "\nSkipped updating Search Replace DB since not on master branch"
    fi
  fi
}

install_ee
profile_setup
php_codesniff
php_search_replace

#set +xv
# And it's done
end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Provisioning complete in "$(( end_seconds - start_seconds ))" seconds"

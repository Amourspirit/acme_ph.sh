# Acme Place Holder

Script update a site's SSL, using [Lets Ecrypt](https://letsencrypt.org/), and [acme.sh](https://github.com/acmesh-official/acme.sh)

This script handles replacing the the sites conf file with a temporary conf before it runs acme.sh to apply the Lets Encrypt update. Once the update is complete the original conf file is restored.

**Use case senario:** [KOHA](https://koha.org/) library being run on a site that is managed by [Webmin/Virtualmin](https://www.virtualmin.com/). Due to the way [KOHA](https://koha.org/) is configured [Virtualmin](https://www.virtualmin.com/) is unable to update the SSL using [Lets Ecrypt](https://letsencrypt.org/).

## Usage

### Parameters

```txt
-d  Required: Specify -d the domain name if -c is ommited then the conf file name will be inferred from this parameter
-r  Required: Specify -r the root directory of the site such as /home/mysite
-p  Optional: Specify -p the public folder for the site. If ommited then then -r + /public_html will be infered such as /home/mysite/public_html
-c  Optional: Specify -c the name of the site configuration file. This is the same value that a2ensite would use such as domain.tld
-f  Optional: Specify -f the place holder conf file that will be enabled to allow letsencrypt to update site.
-t  Optional: Specify -t if set to 1 will uses httpd; Otherwise, By default apache2 will be used
-s  Optional: Specify -s the full path to acme.sh file. Default: ~/.acme.sh/acme.sh
-a  Optional: Specify -a to use a path to configuration file. default is /etc/apache2/sites-available
-e  Optional: Specify -e to use a path to configuration file. default is /etc/apache2/sites-enabled
-i  Optional: Specify -i the configuration file locations to use that contains default options
-v  -v Display version info
-h  -h Display help.
```

### Script Configuration File

*Optionally* a script configuration file can be set up to contain various settings.
The default location for this configuration file is `~/.acme_ph.cfg`

The parameter **-c** can be used to pass in a configuration file in a different location.

This is the default values for the script

```ini
[APACHE]
SITES_AVAILABLE='/etc/apache2/sites-available'
SITES_ENABLED='/etc/apache2/sites-enabled'
HTTPD=0
[ACME]
ACME_SCRIPT="$HOME/.acme.sh/acme.sh"
```

The above settings when the corresponding parameter is set in the command line.

The script `~/.acme_ph.cfg` will have to be created manually if you require default settings different then above,

### Examples

#### Example 1

**Site Domain:** `mysite.domain.tld`  
**Site root:** `/home/mysite`  
**Site public html:** `public_html`  
**Site conf** `mysite.domain.tld.conf`  
**Place holder file** `mysite.domain.tld.dummy.conf`  
**acme.sh** `~/.acme.sh/acme.sh`  
**sites available loc** `/etc/apache2/sites-available`  
**sites enabled loc** `/etc/apache2/sites-enabled`  
**apache/httpd** `apache2`

```txt
/bin/bash /root/scripts/letsencrypt/acme_ph.sh -d 'mysite.domain.tld' -r '/home/mysite'`
```

#### Example 2

**Site Domain:** `mysite.domain.tld`  
**Site root:** `/var/www/mysite`  
**Site public html:** `public`  
**Site conf** `mysite.conf`  
**Place holder file** `mysite.plaeholder.conf`  
**acme.sh** `/opt/acme/acme.sh`  
**sites available loc** `/etc/apache2/sites-available`  
**sites enabled loc** `/etc/apache2/sites-enabled`  
**apache/httpd** `apache2`

```txt
/bin/bash /root/scripts/letsencrypt/acme_ph.sh \
  -d 'mysite.domain.tld' \
  -r '/var/www/mysite' \
  -p 'public' \
  -c 'mysite.conf' \
  -f 'mysite.plaeholder.conf' \
  -s '/opt/acme/acme.sh'
```

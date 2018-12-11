# spock
A command-line tool to sign update manifests of Mozilla extensions

## What is this?
spock signs a Mozilla extension manifest (update.rdf) file and optionally sets a value for <version/>, <updateLink/>, and <updateHash/>.

It was hacked together as a non-interactive replacement to McCoy.

## Prerequisites
- libxml
- libxslt
- ruby, with bindings to libxml and libxslt

You should have created a key with McCoy. The key must not be protected with a password. If there is more than one key, the first one will be used.

spock, normalize_update_rdf.rb, nss_sign_data and rdf2nt.xsl must be in the same directory.
Additionally, on Debian Sid, I used these packages, plus their *-dev counterparts:

- libnss3-1d
- libnspr4-0d

These are needed on Fedora instead (thanks, Godmar!). Include files will be placed in /usr/include/nss3 and /usr/include/nspr4, requiring a Makefile change:

-nss-devel
-nss
-nspr-devel
-nspr

See Godmar's comment below for more instructions about Fedora.

## Usage

Usage: spock [options] FILE
    -i, --extension-id ID            ID of the extension resource, including version if any
                                     Examples:
                                     urn:mozilla:extension:foo@bar.org:0.1
                                     urn:mozilla:extension:{eecba28f-b68b-4b3a-b501-6ce12e6b8696}
    -v, --version VERSION            Set  value in resulting update.rdf
    -u, --update-link URL            Set  value in resulting update.rdf
    -f, --file PACKAGE_FILENAME      Determine  value using PACKAGE_FILENAME
    -d, --nss-directory DIR          Directory containing key key3.db
                                     Example: ~/.mozilla/mccoy/rt7xxbxw.default/

    -h, --help                       This help text

## Simple example:


$ ./spock update.rdf -i urn:mozilla:extension:{eecba28f-b68b-4b3a-b501-6ce12e6b8696} -d ~/.mozilla/mccoy/rt7xxbxw.default/ >update.rdf.signed

## Advanced example:


$ ./spock update.rdf -i urn:mozilla:extension:{eecba28f-b68b-4b3a-b501-6ce12e6b8696} -d ~/.mozilla/mccoy/rt7xxbxw.default/ -v 0.1.0 -u http://my.site.com/extensions/ext.xpi -f ext.xpi  >update.rdf.signed

## Limitations
update.rdf must be valid XML. Note that Mozilla reading the file correctly does not ensure that it will be valid for libxml. Common issues include about= and resource= attributes being unqualified (so if you have an xmlns:RDF= at the top, make sure you write RDF:about= and RDF:resource=). You might want to use include sample.update.rdf as a guide for your own.

Only the first key in McCoy database is used, and it must not be protected by a password.

Only one extension per update.rdf is supported.

The input update.rdf must not contain an <signature/> element already.

update.rdf must already contain <updateLink/> and <updateHash/> tags, even if empty. Spock won't add them.

## Credits
For rtf2nt.xsl, see file.

normalize_update_rdf.rb is a direct translation (minus mistakes, mine) of Dave Townsend’s rdfserializer.js from McCoy. Much of nss_sign_data.c has been adapted from there too.

Content of the nss/ directory comes from libnss3.

A big thank-you to dafi (Davide Ficano) for helping with testing.

## Important notice
This software is NOT endorsed by Mozilla.

This software is also NOT supported by the author. Use at your own risk.

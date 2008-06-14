use warnings;
use strict;

use MediaWiki::API;
use Data::Dumper;

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'http://testwiki.exotica.org.uk/mediawiki/api.php';
print $mw->api( { action => 'login', lgname => 'blah', lgpassword => 'blah' } );

print $mw->api( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade_Conversions' } );

print $mw->get_page('Main Page','content');

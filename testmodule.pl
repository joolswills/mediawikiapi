use warnings;
use strict;

use MediaWiki::API;
use Data::Dumper;

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'http://www.exotica.org.uk/mediawiki/api.php';
$mw->{config}->{limits} = 'max';

if (!$mw->login( {lgname => 'blah', lgpassword => 'blah' } ) ) {
  print $mw->{error_details}.'\n';
}
print Dumper $mw->list ( { action => 'query', list => 'allpages', aplimit=>5 }, 10 );
print Dumper $mw->list ( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade Conversions' }, 20 );

#my $page=$mw->get_page('Main Page','content');
#print $page->{content};
use warnings;
use strict;

use MediaWiki::API;
use Data::Dumper;

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'http://www.exotica.org.uk/mediawiki/api.php';



#api.php ? action=query & list=categorymembers & cmtitle=Category:Physics & cmsort=timestamp & cmdir=desc

print Dumper $mw->list ( { action => 'query', list => 'allpages' }, 50 );
print Dumper $mw->list ( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade Conversions' }, 50 );


#$mw->api( { action => 'login', lgname => 'blah', lgpassword => 'blah' } );
#$mw->api( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade_Conversions' } );

#my $page=$mw->get_page('Main Page','content');
#print $page->{content};
use warnings;
use strict;

use MediaWiki::API;
use Data::Dumper;

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'http://testwiki.exotica.org.uk/mediawiki/api.php';


if (!$mw->login( {lgname => 'Testbot', lgpassword => 'test' } ) ) {
  print $mw->{error_details}."\n";
}
#print Dumper $mw->list ( { action => 'query', list => 'allpages', aplimit=>5 }, 10 );
#print Dumper $mw->list ( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade Conversions' }, 20 );
if ( !$mw->edit( { action => 'edit', title => 'Main Page', text => "hello world\n" } )  ) {
  print $mw->{error_details}."\n";
}
$mw->logout();
if ( !$mw->edit( { action => 'edit', title => 'Main Page', text => "hello world2\n" } )  ) {
  print $mw->{error_details}."\n";
}

#my $page=$mw->get_page('Main Page','content');
#print $page->{content};

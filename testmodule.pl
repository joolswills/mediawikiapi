use warnings;
use strict;

use MediaWiki::API;
use Data::Dumper;

binmode STDOUT, ":utf8";

my $mw = MediaWiki::API->new();
#$mw->{config}->{api_url} = 'http://testwiki.exotica.org.uk/mediawiki/api.php';
$mw->{config}->{api_url} = 'http://testwiki.exotica.org.uk/mediawiki/api.php';
$mw->{config}->{upload_url} = 'http://testwiki.exotica.org.uk/mediawiki/index.php/Special:Upload';
$mw->{config}->{bot}=1;
$mw->{config}->{on_error} = \& on_error;

#open FILE, "logo.png" or die $!;
#binmode FILE;
#my ($buffer, $data);
#while ( read(FILE, $buffer, 65536) )  {
#  $data .= $buffer;
#}
#close(FILE);

#$mw->login( {lgname => 'Testbot', lgpassword => 'test' } );

#$mw->upload( "logo.png",$data,"test upload");

#$mw->login( {lgname => 'Testbot', lgpassword => 'test' } );

# site info
#print Dumper $mw->api( { action => 'query', meta => 'siteinfo' } );

#print Dumper $mw->api( { action => 'query', meta => 'userinfo', uiprop => 'blockinfo|hasmsg|groups|rights|options|editcount|ratelimits' } );

#my $query = $mw->api( { action => 'query', titles => 'Albert Einstein', prop => 'langlinks' } );
#print Dumper $query;
#my @ll = @{ $query->{query}->{pages}->{page}->{langlinks}->{ll} };

#foreach (@ll) {
# print "$_->{content} \n";
# }
#print Dumper $mw->list ( { action => 'query', list => 'allpages', aplimit=>5 }, 10 );
#print Dumper $mw->list ( { action => 'query', list => 'categorymembers', cmtitle => 'Category:Arcade Conversions' }, 20 );

#if ( !$mw->edit( { action => 'delete', title => 'DeleteMe' } )  ) {
#  print $mw->{error_details}."\n";
#}

#if ( !$mw->edit( { action => 'move', from => 'MoveMe', to => 'MoveMe2' } )  ) {
#  print $mw->{error_details}."\n";
#}

#if ( !$mw->edit( { action => 'edit', title => 'Main Page', text => "hello world  ehcwehbcewhcbe\n" } )  ) {
#  print $mw->{error_details}."\n";
#}

#if ( !$mw->edit( { action => 'rollback', title => 'Main Page' } )  ) {
#  print $mw->{error_details}."\n";
#}

#my $page=$mw->get_page('Main Page','content');
#print $page->{content};

sub on_error {
  print "Error code: " . $mw->{error} . "\n";
  print $mw->{error_details}."\n";
  die;
}
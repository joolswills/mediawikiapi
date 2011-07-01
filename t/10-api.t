#!perl -T

use strict;
use warnings;

use Test::More tests => 10;
use Data::Dumper;

BEGIN {
  use_ok( 'MediaWiki::API' );
}

sub read_binary {
  my $file = shift;
  open FILE, $file or return 0;
  binmode FILE;
  my ($buffer, $data);
  while ( read(FILE, $buffer, 16384) )  {
    $data .= $buffer;
  }
  close(FILE);
  return $data;
}

my $mw = MediaWiki::API->new( { api_url => 'http://testwiki.exotica.org.uk/mediawiki/api.php' }  );
$mw->{config}->{upload_url} = 'http://testwiki.exotica.org.uk/wiki/Special:Upload';
my $ref;

isa_ok( $mw, 'MediaWiki::API' );

ok ( $ref = $mw->api( {
  action => 'query',
  meta => 'siteinfo'
  } ),
  '->api siteinfo call'
  );

is ( $ref->{query}->{general}->{server}, 'http://testwiki.exotica.org.uk', '->api siteinfo server' );

ok ( $mw->api( {
  action => 'query',
  list => 'allcategories'
  } ),
  '->list allcategories'
  );

my $time = time;
my $title = 'apitest/' . $time;
my $content = "* Version: $MediaWiki::API::VERSION\n\nthe quick brown fox jumps over the lazy dog";
ok ( $mw->edit( {
  action => 'edit',
  title => $title,
  text => $content,
  summary => 'MediaWiki::API Test suite - edit page',
  bot => 1
  } ),
  '->edit ' . $title
  );

ok ( $ref = $mw->get_page( { title => $title } ), "->get_page $title call" );

is ( $ref->{'*'}, $content, "->get_page $title content" );

$title = "apitest - $time.png";
ok ( my $data = read_binary('t/testimage.png'), 'read image data');
ok ( $mw->upload( {
  title => $title,
  summary => 'MediaWiki::API Test suite - upload image',
  data => $data
  } ),
  "->upload $title"
  );






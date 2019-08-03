#!perl

use strict;
use warnings;

use Test::Most;
use LWP::UserAgent;
use Readonly;
use Data::Dumper;

Readonly my $TIMEOUT  => 10;

sub get_url {
    my $url = shift;
    my $ua  = LWP::UserAgent->new;
    $ua->timeout($TIMEOUT);
    $ua->env_proxy;
    my $response = $ua->get($url);
    return $response;
}

my $api_url = 'http://testwiki.exotica.org.uk/mediawiki/api.php';
my $empty_msg = 'The file you submitted was empty';

if ( $ENV{WIKI_API_URL} ) {
	$api_url = $ENV{WIKI_API_URL};
	$empty_msg = 'The file you submitted was empty.';
}

my ($site_info) = $api_url =~ m{( [^:]+ [:]// [^/]+ ) /}smx;

diag("Using '$api_url' for the tests...");

my $response = get_url($api_url);

if ( $response->is_success ) {
    plan tests => 20;
}
else {
    plan skip_all => "Can't access $api_url to run tests";
}

use_ok('MediaWiki::API');
my $mw = MediaWiki::API->new(
    {
        api_url     => $api_url,
        diagnostics => $ENV{WIKI_DIAGNOSTICS}
    }
);
isa_ok( $mw, 'MediaWiki::API' );

my $ref;
ok(
    $ref = $mw->api(
        {
            action => 'query',
            meta   => 'siteinfo'
        }
    ),
    '->api siteinfo call'
);

is( $ref->{query}->{general}->{server}, $site_info, '->api siteinfo server' );

ok(
    $ref = $mw->api(
        {
            action => 'query',
            list   => 'allcategories'
        }
    ),
    '->list allcategories'
);

my $time  = time;
my $title = 'apitest/' . $time;
my $content =
"* Version: $MediaWiki::API::VERSION\n\nthe quick brown fox jumps over the lazy dog";
ok(
    $ref = $mw->edit( {
            action  => 'edit',
            title   => $title,
            text    => $content,
            summary => 'MediaWiki::API Test suite - edit page',
            bot     => 1
        }
    ),
    '->edit ' . $title
);

ok( $ref = $mw->get_page( { title => $title } ), "->get_page $title call" );

is( $ref->{q{*}}, $content, "->get_page $title content" );

SKIP: {
	if ( !$ENV{WIKI_API_URL} ) {
		skip "Traditional test wiki allows anons", 4
	};
# The move won't succeed if we don't log in
	ok( !$mw->edit(
        {
			action  => 'move',
			from    => $title,
			to      => $title . '-move',
            summary => 'MediaWiki::API Test suite - move page',
            bot     => 1
        }
	  ),
		'->edit action=move ' . $title
	  );
	cmp_ok( $mw->{error}->{code},
			q{==}, 5, 'Anon failed to move page' );

	bail_on_fail();
	ok( $ref = $mw->login( {lgname => $ENV{WIKI_ADMIN}, lgpassword => $ENV{WIKI_PASS}} ), '->login' );
	ok( !exists( $ref->{error}->{code} ), 'No errors during login' );
	restore_fail();
}

# The move will succeed now
ok(
    $ref = $mw->edit(
        {
            action  => 'move',
            from    => $title,
			to      => $title . '-moved',
            bot     => 1,
            summary => 'MediaWiki::API Test suite - move page',
            bot     => 1
        }
    ),
    '->edit logged in action=move ' . $title
);

$title = $title . '-moved';
ok(
    $ref = $mw->edit(
        {
			title   => $title,
			action  => 'delete',
            summary => 'MediaWiki::API Test suite - delete page',
            bot     => 1
        }
    ),
    '->edit action=delete ' . $title
);

delete $mw->{error}->{code};
delete $mw->{error}->{details};

$title = "apitest - $time.png";
ok(
    $ref = $mw->upload(
        {
			title          => $title,
            comment        => 'MediaWiki::API Test suite - upload image',
            file           => undef,
            ignorewarnings => 1,
            bot            => 1
        }
    ),
    "->edit action=upload $title"
  );
cmp_ok( $ref->{error}->{info}, 'eq',
		$empty_msg,
		'Error from empty file.' );
cmp_ok( $ref->{error}->{code}, 'eq', 'empty-file',
		'Error when trying to upload' );

delete $mw->{error}->{code};
delete $mw->{error}->{details};

ok(
    $ref = $mw->upload(
        {
			title          => $title,
            comment        => 'MediaWiki::API Test suite - upload image',
			file           => [ 't/testimage.png'],
            ignorewarnings => 1,
            bot            => 1
        }
    ),
    "->edit action=upload $title"
);

cmp_ok( $ref->{error}->{info}, 'eq',
		$empty_msg,
		'Error from empty file.' );
cmp_ok( $ref->{error}->{code}, 'eq', 'empty-file',
		'Error when trying to upload' );
done_testing();


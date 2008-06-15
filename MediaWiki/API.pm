package MediaWiki::API;

use warnings;
use strict;

#use LWP::Debug qw(+);
use LWP::UserAgent;
use XML::Simple qw(:strict);
use Data::Dumper;

use constant {
  ERR_NO_ERROR => 0,
  ERR_CONFIG   => 1,
  ERR_HTTP     => 2,
  ERR_API      => 3,
  ERR_LOGIN    => 4,
  ERR_EDIT     => 5,
};

sub new {

  my ($class, $config) = @_;
  my $self = { config => $config  };

  my $ua = LWP::UserAgent->new();
  $ua->cookie_jar({});

  $self->{ua} = $ua;

  bless ($self, $class);
  return $self;
}

sub api {
  my ($self,$query) = @_;
  my $apiurl=$self->{config}->{api_url};

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki API php.\n") unless $self->{config}->{api_url};

  $query->{format}='xml';

  my $response = $self->{ua}->post( $apiurl, $query );

  return $self->_error(ERR_HTTP,"An HTTP failure occurred.\n") unless $response->is_success;

  #print Dumper ($response->content);

  my $ref = XML::Simple->new()->XMLin($response->content, ForceArray => 0, KeyAttr => [ ] );

  return $self->_error(ERR_API,$ref->{error}->{code}) if exists ( $ref->{error} );

  return $ref;
}

sub login {
  my ($self,$query) = @_;
  $query->{action} = 'login';
  # attempt to login, and return undef if there was an api failure
  return undef unless ( my $ref = $self->api( $query ) );

  # reassign hash reference to the login section
  $ref=$ref->{login};
  return $self->_error( ERR_LOGIN, 'Login Failure: ' . $ref->{result} ) unless ( $ref->{result} eq 'Success' );

  # everything was ok so return the reference
  return $ref;
}




sub edit {
  my ($self,$query) = @_;
  return undef unless my $ref = $self->api( { action => 'query', prop => 'info|revisions', intoken => 'edit', titles => $query->{title} } );

  # reassign hash reference to the page section
  $ref=$ref->{query}->{pages}->{page};

  return $self->_error( ERR_EDIT, 'Unable to get an edit token.' ) unless ( exists ( $ref->{edittoken} ) );

  $query->{action} = 'edit';
  $query->{token} = $ref->{edittoken};

  return undef unless $ref = $self->api( $query );

  return $ref;
}

# parameters:
# mediawiki api parameters for list functions (http://www.mediawiki.org/wiki/API:Query_-_Lists) as hashref
# number of items to return or 0 for all
sub list {
  my ($self, $query, $max) = @_;
  my ($ref, @results);
  my ($cont_key, $cont_value, $array_key, $count);

  my $list = $query->{list};

  my $do_continue = 0;
  do {
    $ref = $self->api( $query );

    # check if we have yet the key which contains the array of hashrefs for the ref
    # if not, then get it.
    if ( ! defined( $array_key ) ) { 
      ($array_key,)=each( %{ $ref->{query}->{$list} } );
    }
    # count the items in the array, and add to our total
    $count +=  scalar @{$ref->{query}->{$list}->{$array_key}};

    # check if there are more ref to be had
    if ( exists( $ref->{'query-continue'} ) ) {
      # get query-continue hashref and extract key and value (key will be used as from parameter to continue where we left off)
      ($cont_key, $cont_value) = each( %{ $ref->{'query-continue'}->{$list} } );
      $query->{$cont_key} = $cont_value;
      $do_continue = 1;
    }
    push @results, @{$ref->{query}->{$list}->{$array_key}}

  } until ( ! $do_continue || ($count>=$max && $max != 0) );

  return @results;
}

sub get_page {
  my ($self, $page, $rvprop) = @_;
  return undef unless ( my $ref = $self->api( { action => 'query', prop => 'revisions', titles => $page, rvprop => $rvprop } ) );
  return $ref->{query}->{pages}->{page}->{revisions}->{rev};
}

sub _error {
  my ($mw, $code, $desc) = @_;
  $mw->{error} = $code;
  $mw->{error_details} = $desc;

  $mw->{on_error}->() if ($mw->{on_error});

  return undef;
}

1;
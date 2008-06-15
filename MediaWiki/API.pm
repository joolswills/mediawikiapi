package MediaWiki::API;

use warnings;
use strict;

#use LWP::Debug qw(+);
use LWP::UserAgent;
use XML::Simple qw(:strict);
use Data::Dumper;

our($VERSION) = "0.2";

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
  $ua->agent(__PACKAGE__ . "/$VERSION");

  $self->{ua} = $ua;

  bless ($self, $class);
  return $self;
}

sub api {
  my ($self, $query) = @_;
  my $apiurl = $self->{config}->{api_url};

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki API php.\n") unless $self->{config}->{api_url};

  $query->{format}='xml';

  my $response = $self->{ua}->post( $apiurl, $query );

  return $self->_error(ERR_HTTP,"An HTTP failure occurred.\n") unless $response->is_success;

  #print Dumper ($response->content);

  my $ref = XML::Simple->new()->XMLin($response->content, ForceArray => 0, KeyAttr => [ ] );

  return $self->_error(ERR_API,$ref->{error}->{info}) if exists ( $ref->{error} );

  return $ref;
}

sub login {
  my ($self, $query) = @_;
  $query->{action} = 'login';
  # attempt to login, and return undef if there was an api failure
  return undef unless ( my $ref = $self->api( $query ) );

  # reassign hash reference to the login section
  my $login = $ref->{login};
  return $self->_error( ERR_LOGIN, 'Login Failure: ' . $login->{result} ) unless ( $login->{result} eq 'Success' );

  # everything was ok so return the reference
  return $login;
}

sub logout {
  my ($self) = @_;
  # clear login cookies
  $self->{ua}->{cookie_jar} = undef;
  # clear cached tokens
  $self->{config}->{tokens} = undef;
}

sub edit {
  my ($self, $query) = @_;

  # gets and sets a token for the specific action (different tokens for different edit actions such as rollback/delete etc)
  return undef unless ( $self->_get_set_tokens( $query ) );

  # do the edit
  return undef unless ( my $ref = $self->api( $query ) );

  return $ref;
}

# gets a token for a specified parameter and sets it in the query for the call
sub _get_set_tokens {
  my ($self, $query) = @_;
  my ($prop, $title, $token);
  my $action = $query->{action};

  # check if we have a cached token.
  if ( exists( $self->{config}->{tokens}->{$action} ) ) {
    $query->{token} = $self->{config}->{tokens}->{$action};
    return 1;
  }

  # set the properties we want to extract based on the action
  # for edit we want to get the datestamp of the last revision also to avoid collisions
  $prop = 'info|revisions' if ( $action eq 'edit' );
  $prop = 'info' if ( $action eq 'move' or $action eq 'delete' );
  $prop = 'revisions' if ( $query->{action} eq 'rollback' );

  if ( $action eq 'move' ) {
    $title = $query->{from};
  } else {
    $title = $query->{title};
  }

  if ( $action eq 'rollback' ) {
    $token = 'rvtoken';
  } else {
    $token = 'intoken';
  }

  return undef unless ( my $ref = $self->api( { action => 'query', prop => 'info|revisions', $token => $action, titles => $title } ) );

  my $page = $ref->{query}->{pages}->{page};
  if ( $action eq 'rollback' ) {
    $query->{token} = $page->{revisions}->{rev}->{$action.'token'};
    $query->{user}  = $page->{revisions}->{rev}->{user};
  } else {
    $query->{token} = $page->{$action.'token'};
  }

  # need timestamp of last revision for edits to avoid edit conflicts
  if ( $action eq 'edit' ) {
    $query->{basetimestamp} = $page->{revisions}->{rev}->{timestamp};
  }

  return $self->_error( ERR_EDIT, 'Unable to get an edit token.' ) unless ( defined ( $query->{token} ) );

  # cache the token. rollback tokens are specific for the page name and last edited user so can not be cached.
  if ( $action ne 'rollback' ) {
    $self->{config}->{tokens}->{$action} = $query->{token};
  }

  return 1;
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
    return undef unless ( $ref = $self->api( $query ) );

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

  $mw->{config}->{on_error}->() if ($mw->{config}->{on_error});

  return undef;
}

1;

__END__

=head1 AUTHOR

Jools 'BuZz' Smyth <buzz@exotica.org.uk>
http://www.exotica.org.uk

=head1 COPYRIGHT

Copyright (C) 2008 Jools Smyth
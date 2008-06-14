package MediaWiki::API;

use warnings;
use strict;

#use LWP::Debug qw(+);
use LWP::UserAgent;
use XML::Simple qw(:strict);
use Data::Dumper;

sub ERR_NO_ERROR { 0 }
sub ERR_CONFIG { 1 }
sub ERR_HTTP { 2 }

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
  return $ref;
}

sub get_page {
  my ($self, $page, $rvprop) = @_;
  my $query = ($self->api( { action => 'query', prop => 'revisions', titles => $page, rvprop => $rvprop } ));
  return $query->{query}->{pages}->{page}->{revisions}->{rev};
}

sub _error {
  my ($mw, $code, $desc) = @_;
  $mw->{error} = $code;
  $mw->{error_desc} = $desc;
  return $code;
}

1;
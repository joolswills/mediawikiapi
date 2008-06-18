package MediaWiki::API;

use warnings;
use strict;

# our required modules

use LWP::UserAgent;
use XML::Simple qw(:strict);
use HTML::Entities;
#use Data::Dumper;

use constant {
  ERR_NO_ERROR => 0,
  ERR_CONFIG   => 1,
  ERR_HTTP     => 2,
  ERR_API      => 3,
  ERR_LOGIN    => 4,
  ERR_EDIT     => 5,
  ERR_UPLOAD   => 6,
};

=head1 NAME

MediaWiki::API - Provides a Perl interface to the MediaWiki API (http://www.mediawiki.org/wiki/API)

=head1 VERSION

Version 0.03

=cut

our $VERSION  = "0.03";

=head1 SYNOPSIS

  use MediaWiki::API;

  my $mw = MediaWiki::API->new();
  $mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';

  # log in to the wiki
  $mw->login( {lgname => 'test', lgpassword => 'test' } );

  my $articles=$mw->list ( { action => 'query', list => 'categorymembers', cmtitle => 'http://en.wikipedia.org/wiki/Category:Perl', aplimit=>'max' } );

  # user info
  print Dumper $mw->api( { action => 'query', meta => 'userinfo', uiprop => 'blockinfo|hasmsg|groups|rights|options|editcount|ratelimits' } );

    ...


=head1 FUNCTIONS

=head2 MediaWiki::API->new( [ $config_hash ] )

Returns a MediaWiki API object. You can pass a config as a hashref when calling new, or set the configuration later.

=cut

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

=head2 MediaWiki::API->login( $query_hash )

Logs in to a MediaWiki. Parameters are those used by the MediaWiki API (http://www.mediawiki.org/wiki/API:Login). Returns a hash with some login details, or undef on login failure. Errors are stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}

  my $mw = MediaWiki::API->new( { api_url => 'http://en.wikipedia.org/w/api.php' }  );

  #log in to the wiki
  $mw->login( {lgname => 'username', lgpassword => 'password' } );

=cut

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

=head2 MediaWiki::API->api( $query_hash )

Call the MediaWiki API interface. Parameters are passed as a hashref which are described on the
MediaWiki API page (http://www.mediawiki.org/wiki/API). returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

  # get the name of the site
  if ( my $ref = $mw->api( { action => 'query', meta => 'siteinfo' } ) ) {
    print $ref->{query}->{general}->{sitename};
  }

=cut

sub api {
  my ($self, $query) = @_;

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki API php.") unless $self->{config}->{api_url};

  $query->{format}='xml';

  my $response = $self->{ua}->post( $self->{config}->{api_url}, $query );

  return $self->_error(ERR_HTTP,"An HTTP failure occurred.") unless $response->is_success;

  #print Dumper ($response->content);

  my $ref = XML::Simple->new()->XMLin($response->content, ForceArray => 0, KeyAttr => [ ] );

  return $self->_error(ERR_API,$ref->{error}->{code} . ": " . decode_entities($ref->{error}->{info}) ) if exists ( $ref->{error} );

  return $ref;
}


=head2 MediaWiki::API->logout()

Log the current user out and clear associated cookies and edit tokens.

=cut

sub logout {
  my ($self) = @_;
  # clear login cookies
  $self->{ua}->{cookie_jar} = undef;
  # clear cached tokens
  $self->{config}->{tokens} = undef;
}

=head2 MediaWiki::API->edit( $query_hash )

A helper function for doing edits using the MediaWiki API. Parameters are passed as a hashref which are described on the MediaWiki API editing page (http://www.mediawiki.org/wiki/API:Changing_wiki_content). Currently only

=over

=item * Create/Edit pages

=item * Move pages

=item * Rollback

=item * Delete pages

=back

are supported via this call. Use this call to edit pages without having to worry about getting an edit token from the API first. The function will cache edit tokens to speed up future edits (Except for rollback edits, which are not cachable).

Returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

  # edit a page
  if ( ! $mw->edit( { action => 'edit', title => 'Main Page', text => "hello world\n" } )  ) {
    print $mw->{error}->{code} . ': ' . $mw->{error}->{details}."\n";
  }

  # delete a page
  $mw->edit( { action => 'delete', title => 'DeleteMe' };

  # move a page
  $mw->edit( { action => 'move', from => 'MoveMe', to => 'MoveMe2' };

  # rollback a page edit
  $mw->edit( { action => 'rollback', title => 'Sandbox' };

=cut

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
  # for edit we want to get the datestamp of the last revision also to avoid edit conflicts
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

  return $self->_error( ERR_EDIT, 'Unable to get an edit token ($page).' ) unless ( defined ( $query->{token} ) );

  # cache the token. rollback tokens are specific for the page name and last edited user so can not be cached.
  if ( $action ne 'rollback' ) {
    $self->{config}->{tokens}->{$action} = $query->{token};
  }

  return 1;
}

=head2 list

instructions go here

=cut

# parameters:
# mediawiki api parameters for list functions (http://www.mediawiki.org/wiki/API:Query_-_Lists) as hashref
# number of items to return or 0 for all
sub list {
  my ($self, $query, $options) = @_;
  my ($ref, @results);
  my ($cont_key, $cont_value, $array_key);

  my $list = $query->{list};

  $options->{max} = 0 if ( !defined $options->{max} );

  my $continue = 0;
  my $count = 0;
  do {
    return undef unless ( $ref = $self->api( $query ) );

    # return (empty) array if results are empty
    return @results unless ( %{$ref->{query}->{$list}} );

    # check if there are more results to be had
    if ( exists( $ref->{'query-continue'} ) ) {
      # get query-continue hashref and extract key and value (key will be used as from parameter to continue where we left off)
      ($cont_key, $cont_value) = each( %{ $ref->{'query-continue'}->{$list} } );
      $query->{$cont_key} = $cont_value;
      $continue = 1;
    } else {
      $continue = 0;
    }

    # check if we have yet the key which contains the array of hashrefs for the ref
    # if not, then get it.
    if ( ! defined( $array_key ) ) {
      ($array_key,)=each( %{ $ref->{query}->{$list} } );
    }

    if ( defined $options->{hook} ) {
      $options->{hook}(\@{$ref->{query}->{$list}->{$array_key}});
    } else {
      push @results, @{$ref->{query}->{$list}->{$array_key}};
    }

    $count += 1;

  } until ( ! $continue || $count >= $options->{max} && $options->{max} != 0 );

  return 1 if ( defined $options->{max} ); 
  return @results;

}

sub upload {
  my ($self, $title, $data, $summary) = @_;

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki Special:Upload page.") unless $self->{config}->{upload_url};

  my $response = $self->{ua}->post(
    $self->{config}->{upload_url},
    Content_Type => 'multipart/form-data',
    Content => [
      wpUploadFile => [ undef, $title, Content => $data ],
      wpSourceType => 'file',
      wpDestFile => $title,
      wpUploadDescription => $summary,
      wpUpload => 'Upload file',
      wpIgnoreWarning => 'true', ]
  );

  return $self->_error(ERR_UPLOAD,"There was a problem uploading the file - $title") unless ( $response->code == 302 );
  return 1;

}

sub get_page {
  my ($self, $page, $rvprop) = @_;
  return undef unless ( my $ref = $self->api( { action => 'query', prop => 'revisions', titles => $page, rvprop => $rvprop } ) );
  return $ref->{query}->{pages}->{page}->{revisions}->{rev};
}

sub _error {
  my ($mw, $code, $desc) = @_;
  $mw->{error}->{code} = $code;
  $mw->{error}->{details} = $desc;

  $mw->{config}->{on_error}->() if ($mw->{config}->{on_error});

  return undef;
}

1;

__END__

=head1 AUTHOR

Jools Smyth, C<< <buzz at exotica.org.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mediawiki-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MediaWiki-API>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MediaWiki::API


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MediaWiki-API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MediaWiki-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MediaWiki-API>

=item * Search CPAN

L<http://search.cpan.org/dist/MediaWiki-API>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Jools Smyth, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of MediaWiki::API

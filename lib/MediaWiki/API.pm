package MediaWiki::API;

use warnings;
use strict;

# our required modules

use LWP::UserAgent;
use JSON::XS;
use Encode;
use Carp;

use constant {
  ERR_NO_ERROR => 0,
  ERR_CONFIG   => 1,
  ERR_HTTP     => 2,
  ERR_API      => 3,
  ERR_LOGIN    => 4,
  ERR_EDIT     => 5,
  ERR_PARAMS   => 6,
  ERR_UPLOAD   => 7,
  ERR_DOWNLOAD => 8
};

=head1 NAME

MediaWiki::API - Provides a Perl interface to the MediaWiki API (http://www.mediawiki.org/wiki/API)

=head1 VERSION

Version 0.14

=cut

our $VERSION  = "0.14";

=head1 SYNOPSIS

This module provides an interface between Perl and the MediaWiki API (http://www.mediawiki.org/wiki/API) allowing creation of scripts to automate editing and extraction of data from MediaWiki driven sites like Wikipedia.

  use MediaWiki::API;

  my $mw = MediaWiki::API->new();
  $mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';

  # log in to the wiki
  $mw->login( { lgname => 'username', lgpassword => 'password' } );
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # get a list of articles in category
  my $articles = $mw->list ( {
    action => 'query',
    list => 'categorymembers',
    cmtitle => 'Category:Perl',
    cmlimit => 'max' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # and print the article titles
  foreach (@{$articles}) {
      print "$_->{title}\n";
  }

  # get user info
  my $userinfo = $mw->api( {
    action => 'query',
    meta => 'userinfo',
    uiprop => 'blockinfo|hasmsg|groups|rights|options|editcount|ratelimits' } );

    ...

=head1 FUNCTIONS

=head2 MediaWiki::API->new( [ $config_hash ] )

Returns a MediaWiki API object. You can pass a config as a hashref when calling new, or set the configuration later.

  my $mw = MediaWiki::API->new( { api_url => 'http://en.wikipedia.org/w/api.php' }  );

Configuration options are

=over

=item * api_url = 'path to mediawiki api.php';

=item * files_url = 'base url for files'; (needed if the api returns a relative URL for images like /images/a/picture.jpg)

=item * upload_url = 'http://en.wikipedia.org/wiki/Special:Upload'; (path to the upload special page which is required if you want to upload images)

=item * on_error = function reference to call if an error occurs in the module.

=back

An example for the on_error configuration could be something like:

  sub on_error {
    print "Error code: " . $mw->{error}->{code} . "\n";
    print $mw->{error}->{details}."\n";
    die;
  }

Errors are stored in $mw->error->{code} with more information in $mw->error->{details}. The
error codes are as follows

=over

=item * ERR_NO_ERROR = 0 (No error)

=item * ERR_CONFIG   = 1 (An error with the configuration)

=item * ERR_HTTP     = 2 (An http related connection error)

=item * ERR_API      = 3 (An error returned by the MediaWiki API)

=item * ERR_LOGIN    = 4 (An error logging in to the MediaWiki)

=item * ERR_EDIT     = 5 (An error with an editing function)

=item * ERR_PARAMS   = 6 (An error with parameters passed to a helper function)

=item * ERR_UPLOAD   = 7 (An error with the file upload facility)

=item * ERR_DOWNLOAD = 8 (An error with downloading a file)

=back

=cut

sub new {

  my ($class, $config) = @_;
  my $self = { config => $config  };

  my $ua = LWP::UserAgent->new();
  $ua->cookie_jar({});
  $ua->agent(__PACKAGE__ . "/$VERSION");
  $ua->default_header("Accept-Encoding" => "gzip, deflate");

  $self->{ua} = $ua;

  my $json = JSON::XS->new->utf8()->max_depth(10) ;
  $self->{json} = $json;

  $self->{error}->{code} = 0;
  $self->{error}->{details} = 0;

  bless ($self, $class);
  return $self;
}

=head2 MediaWiki::API->login( $query_hash )

Logs in to a MediaWiki. Parameters are those used by the MediaWiki API (http://www.mediawiki.org/wiki/API:Login). Returns a hash with some login details, or undef on login failure. Errors are stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}

  my $mw = MediaWiki::API->new( { api_url => 'http://en.wikipedia.org/w/api.php' }  );

  #log in to the wiki
  $mw->login( {lgname => 'username', lgpassword => 'password' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

=cut

sub login {
  my ($self, $query) = @_;
  $query->{action} = 'login';
  # attempt to login, and return undef if there was an api failure
  return undef unless ( my $ref = $self->api( $query ) );

  # reassign hash reference to the login section
  my $login = $ref->{login};
  return $self->_error( ERR_LOGIN, 'Login Failure - ' . $login->{result} )
    unless ( $login->{result} eq 'Success' );

  # everything was ok so return the reference
  return $login;
}

=head2 MediaWiki::API->api( $query_hash, $options_hash )

Call the MediaWiki API interface. Parameters are passed as a hashref which are described on the MediaWiki API page (http://www.mediawiki.org/wiki/API). returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

  binmode STDOUT, ':utf8';

  # get the name of the site
  if ( my $ref = $mw->api( { action => 'query', meta => 'siteinfo' } ) ) {
    print $ref->{query}->{general}->{sitename};
  }

  # list of titles for "Albert Einstein" in different languages.
  my $titles = $mw->api( {
    action => 'query',
    titles => 'Albert Einstein',
    prop => 'langlinks',
    lllimit => 'max' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  my ($pageid,$langlinks) = each ( %{ $titles->{query}->{pages} } );

  foreach ( @{ $langlinks->{langlinks} } ) {
    print "$_->{'*'}\n";
  }

Parameters are encoded from perl strings to UTF-8 to be passed to Mediawiki automatically, which is normally what you would want. In case for any reason your parameters are already in UTF-8 you can skip the encoding by passing an option skip_encoding => 1 in the $options_hash. For example:

  # $data already contains utf-8 encoded wikitext
  my $ref = $mw->api( { action => 'parse', text => $data }, { skip_encoding => 1 } );

=cut

sub api {
  my ($self, $query, $options) = @_;

  unless ( $options->{skip_encoding} ) {
    $self->_encode_hashref_utf8($query);
  }

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki API php.")
    unless $self->{config}->{api_url};

  $query->{format}='json';

  my $response = $self->{ua}->post( $self->{config}->{api_url}, $query );

  return $self->_error(ERR_HTTP,"An HTTP failure occurred.")
    unless $response->is_success;

  my $ref; 
  eval {
      $ref  = $self->{json}->decode($response->decoded_content);
  };
  if ($@) {
      my $content = $response->decoded_content;
      croak "Failed to decode JSON returned by $self->{config}->{api_url}: $@\n $content";
  };

  return $self->_error(ERR_API,$ref->{error}->{code} . ": " . $ref->{error}->{info} ) if exists ( $ref->{error} );

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

A helper function for doing edits using the MediaWiki API. Parameters are passed as a hashref which are described on the MediaWiki API editing page (http://www.mediawiki.org/wiki/API:Changing_wiki_content). Note that you need $wgEnableWriteAPI = true in your LocalSettings.php to use these features.

Currently only

=over

=item * Create/Edit pages (Mediawiki >= 1.13 )

=item * Move pages  (Mediawiki >= 1.12 )

=item * Rollback  (Mediawiki >= 1.12 )

=item * Delete pages  (Mediawiki >= 1.12 )

=back

are supported via this call. Use this call to edit pages without having to worry about getting an edit token from the API first. The function will cache edit tokens to speed up future edits (Except for rollback edits, which are not cachable).

Returns a hashref with the results of the call or undef on failure with the error code and details stored in MediaWiki::API->{error}->{code} and MediaWiki::API->{error}->{details}.

  # edit a page
  $mw->edit( {
    action => 'edit',
    title => 'Main Page',
    text => "hello world\n" } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # delete a page
  $mw->edit( {
    action => 'delete', title => 'DeleteMe' } ) 
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # move a page
  $mw->edit( {
    action => 'move', from => 'MoveMe', to => 'MoveMe2' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # rollback a page edit
  $mw->edit( {
    action => 'rollback', title => 'Sandbox' } )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

=cut

sub edit {
  my ($self, $query) = @_;

  # gets and sets a token for the specific action (different tokens for different edit actions such as rollback/delete etc). Also sets the timestamp for edits to avoid conflicts.
  return undef unless ( $self->_get_set_tokens( $query ) );

  # do the edit
  return undef unless ( my $ref = $self->api( $query ) );

  return $ref;
}


=head2 MediaWiki::API->get_page( $params_hash )

A helper function for getting the most recent page contents (and other metadata) for a page. It calls the lower level api function with a revisions query to get the most recent revision.

  # get some page contents
  my $page = $mw->get_page( { title => 'Main Page' } );
  # print page contents
  print $page->{'*'};

Returns a hashref with the following keys or undef on an error. If the page is missing then the returned hashref will contain only ns, title and a key called "missing".

=over

=item * '*' - contents of page

=item * 'pageid' - page id of page

=item * 'revid' - revision id of page

=item * 'timestamp' - timestamp of revision

=item * 'user' - user who made revision

=item * 'title' - the title of the page

=item * 'ns' - the namespace the page is in

=item * 'size' - size of page in bytes

=back

Full information about these can be read on (http://www.mediawiki.org/wiki/API:Query_-_Properties#revisions_.2F_rv)

=cut

sub get_page {
  my ($self, $params) = @_;
  return undef unless ( my $ref = $self->api( { action => 'query', prop => 'revisions', titles => $params->{title}, rvprop => 'ids|flags|timestamp|user|comment|size|content' } ) );
  # get the page id and the page hashref with title and revisions
  my ($pageid, $pageref) = each %{ $ref->{query}->{pages} };
  # get the first revision
  my $rev = @{ $pageref->{revisions } }[0];
  # delete the revision from the hashref
  delete($pageref->{revisions});
  # if the page is missing then return the pageref
  return $pageref if ( defined $pageref->{missing} );
  # combine the pageid, the latest revision and the page title into one hash
  return { 'pageid'=>$pageid, %{ $rev }, %{ $pageref } };
}

=head2 MediaWiki::API->list( $query_hash, $options_hash )

A helper function for doing edits using the MediaWiki API. Parameters are passed as a hashref which are described on the MediaWiki API editing page (http://www.mediawiki.org/wiki/API:Query_-_Lists).

This function will return a reference to an array of hashes or undef on failure. It handles getting lists of data from the MediaWiki api, continuing the request with another connection if needed. The options_hash currently has two parameters:

=over

=item * max => value

=item * hook => \&function_hook

=back

The value of max specifies the maximum "queries" which will be used to pull data out. For example the default limit per query is 10 items, but this can be raised to 500 for normal users and higher for sysops and bots. If the limit is raised to 500 and max was set to 2, a maximum of 1000 results would be returned.

If you wish to process large lists, for example the articles in a large category, you can pass a hook function, which will be passed a reference to an array of results for each query connection.

  binmode STDOUT, ':utf8';

  # process the first 400 articles in the main namespace in the category "Surnames".
  # get 100 at a time, with a max of 4 and pass each 100 to our hook.
  $mw->list ( { action => 'query',
                list => 'categorymembers',
                cmtitle => 'Category:Surnames',
                cmnamespace => 0,
                cmlimit=>'100' },
              { max => 4, hook => \&print_articles } )
  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

  # print the name of each article
  sub print_articles {
    my ($ref) = @_;
    foreach (@$ref) {
      print "$_->{title}\n";
    }
  }

=cut

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
    return @results unless ( $ref->{query}->{$list} );

    # check if there are more results to be had
    if ( exists( $ref->{'query-continue'} ) ) {
      # get query-continue hashref and extract key and value (key will be used as from parameter to continue where we left off)
      ($cont_key, $cont_value) = each( %{ $ref->{'query-continue'}->{$list} } );
      $query->{$cont_key} = $cont_value;
      $continue = 1;
    } else {
      $continue = 0;
    }

    if ( defined $options->{hook} ) {
      $options->{hook}( $ref->{query}->{$list} );
    } else {
      push @results, @{ $ref->{query}->{$list} };
    }

    $count += 1;

  } until ( ! $continue || $count >= $options->{max} && $options->{max} != 0 );

  return 1 if ( defined $options->{hook} ); 
  return \@results;

}

=head2 MediaWiki::API->upload( $params_hash )

A function to upload files to a MediaWiki. This function does not use the MediaWiki API currently as support for file uploading is not yet implemented. Instead it uploads using the Special:Upload page, and as such an additional configuration value is needed.

  my $mw = MediaWiki::API->new( {
   api_url => 'http://en.wikipedia.org/w/api.php' }  );
  # configure the special upload location.
  $mw->{config}->{upload_url} = 'http://en.wikipedia.org/wiki/Special:Upload';

The upload function is then called as follows

  # upload a file to MediaWiki
  open FILE, "myfile.jpg" or die $!;
  binmode FILE;
  my ($buffer, $data);
  while ( read(FILE, $buffer, 65536) )  {
    $data .= $buffer;
  }
  close(FILE);

  $mw->upload( { title => 'file.jpg',
                 summary => 'This is the summary to go on the Image:file.jpg page',
                 data => $data } ) || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

Error checking is limited. Also note that the module will force a file upload, ignoring any warning for file size or overwriting an old file.

=cut

sub upload {
  my ($self, $params) = @_;

  return $self->_error(ERR_CONFIG,"You need to give the URL to the mediawiki Special:Upload page.") unless $self->{config}->{upload_url};

  my $response = $self->{ua}->post(
    $self->{config}->{upload_url},
    Content_Type => 'multipart/form-data',
    Content => [
      wpUploadFile => [ undef, $params->{title}, Content => $params->{data} ],
      wpSourceType => 'file',
      wpDestFile => $params->{title},
      wpUploadDescription => $params->{summary},
      wpUpload => 'Upload file',
      wpIgnoreWarning => 'true', ]
  );

  return $self->_error(ERR_UPLOAD,"There was a problem uploading the file - $params->{title}") unless ( $response->code == 302 );
  return 1;

}

=head2 MediaWiki::API->download( $params_hash )

A function to download images/files from a MediaWiki. A file url may need to be configured if the api returns a relative URL.

  my $mw = MediaWiki::API->new( {
    api_url => 'http://www.exotica.org.uk/mediawiki/api.php' }  );
  # configure the file url. Wikipedia doesn't need this but the ExoticA wiki does.
  $mw->{config}->{files_url} = 'http://www.exotica.org.uk';

The download function is then called as follows

  my $file = $mw->download( { title => 'Image:Mythic-Beasts_Logo.png'} )
    || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

If the file does not exist (on the wiki) an empty string is returned. If the file is unable to be downloaded undef is returned.

=cut

sub download {
  my ($self, $params) = @_;

  return $self->_error(ERR_PARAMS,"You need to give a name for the Image page") unless
    ( defined $params->{title} );

  return undef unless my $ref = $self->api(
    { action => 'query',
      titles => $params->{title},
      prop   => 'imageinfo',
      iiprop => 'url' } );

  # get the page id and the page hashref with title and revisions
  my ( $pageid, $pageref ) = each %{ $ref->{query}->{pages} };

  # if the page is missing then return an empty string
  return '' if ( defined $pageref->{missing} );

  my $url = @{ $pageref->{imageinfo} }[0]->{url};

  unless ( $url =~ /^http\:\/\// ) {
    return $self->_error(ERR_PARAMS,'The API returned a relative path. You need to configure the url where files are stored in {config}->{files_url}')
      unless ( defined $self->{config}->{files_url} );
    $url = $self->{config}->{files_url} . $url;
  }

  my $response = $self->{ua}->get($url);
  return $self->_error(ERR_DOWNLOAD,"The file '$url' was not found")
    unless ( $response->code == 200 );

  return $response->decoded_content;
}

# encodes a hash (passed by reference) to utf-8
# used to encode parameters before being passed to the api
sub _encode_hashref_utf8 {
  my ($self, $ref) = @_;
  for my $key ( keys %{$ref} ) {
    $ref->{$key} = encode_utf8( $ref->{$key} );
  }
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

  my ($pageid, $pageref) = each %{ $ref->{query}->{pages} };

  # if the page doesn't exist and we aren't editing/creating a new page then return an error
  return $self->_error( ERR_EDIT, "Unable to $action page '$title'. Page does not exist.") if ( defined $pageref->{missing} && $action ne 'edit' );

  if ( $action eq 'rollback' ) {
    $query->{token} = @{ $pageref->{revisions} }[0]->{$action.'token'};
    $query->{user}  = @{ $pageref->{revisions} }[0]->{user};
  } else {
    $query->{token} = $pageref->{$action.'token'};
  }

  # need timestamp of last revision for edits to avoid edit conflicts (if there are previous revisions)
  if ( $action eq 'edit' && defined $pageref->{revisions} ) {
    $query->{basetimestamp} = @{ $pageref->{revisions} }[0]->{timestamp};
  }

  return $self->_error( ERR_EDIT, 'Unable to get an edit token ($page).' ) unless ( defined $query->{token} );

  # cache the token. rollback tokens are specific for the page name and last edited user so can not be cached.
  if ( $action ne 'rollback' ) {
    $self->{config}->{tokens}->{$action} = $query->{token};
  }

  return 1;
}

sub _error {
  my ($mw, $code, $desc) = @_;
  $mw->{error}->{code} = $code;
  $mw->{error}->{details} = $desc;

  $mw->{config}->{on_error}->() if ($mw->{config}->{on_error});

  return undef;
}

__END__

=head1 AUTHOR

Jools 'BuZz' Smyth, C<< <buzz [at] exotica.org.uk> >>

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

=over

=item * Stuart 'Kyzer' Caie (kyzer [at] 4u.net) for UnExoticA perl code and support

=item * Jason 'XtC' Skelly (xtc [at] amigaguide.org) for moral support

=item * Jonas 'Spectral' Nyren (spectral [at] ludd.luth.se) for hints and tips!

=item * Carl Beckhorn (cbeckhorn [at] fastmail.fm) for ideas and support

=item * Edward Chernenko (edwardspec [at] gmail.com) for his earlier MediaWiki module

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Jools Smyth, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of MediaWiki::API

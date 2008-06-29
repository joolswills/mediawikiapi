use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MediaWiki::API',
    AUTHOR              => 'Jools Smyth <buzz@exotica.org.uk>',
    VERSION_FROM        => 'lib/MediaWiki/API.pm',
    ABSTRACT_FROM       => 'lib/MediaWiki/API.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'JSON::XS'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MediaWiki-API-*' },
);

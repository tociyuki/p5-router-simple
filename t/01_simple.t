use strict;
use warnings;
use Router::Simple;
use Test::More;

my $r = Router::Simple->new();
$r->connect('home', '/' => {controller => 'Root', action => 'show'}, {method => 'GET', host => 'localhost'});
$r->connect('blog_monthly', '/blog/{year}/{month}', {controller => 'Blog', action => 'monthly'}, {method => 'GET'});
$r->connect('/blog/{year:\d{1,4}}/{month:\d{2}}/{day:\d\d}', {controller => 'Blog', action => 'daily'}, {method => 'GET'});
$r->connect('/comment', {controller => 'Comment', 'action' => 'create'}, {method => 'POST'});
$r->connect('/', {controller => 'Root', 'action' => 'show_sub'}, {method => 'GET', host => 'sub.localhost'});
$r->connect(qr{^/belongs/([a-z]+)/([a-z]+)$}, {controller => 'May', action => 'show'});
$r->connect('test7', qr{^/test7/([a-z]+)/([a-z]+)$});
$r->connect(qr{\A/test8/([a-z]+)/([a-z]+)\z}, {controller => 'May', action => 'show'}, {capture => ['animal', 'color']});
$r->connect('/test9/{0}/{00:00000}', {controller => 'Test', action => 'zero'}, {method => 'GET'});
$r->connect('/{spec:test10}/{splat}/{__splat__}/*', {controller => 'Test', action => 'splat'}, {method => 'GET'});

is_deeply(
    $r->match( +{ REQUEST_METHOD => 'GET', PATH_INFO => '/', HTTP_HOST => 'localhost'} ),
    {
        controller => 'Root',
        action     => 'show',
    }
);
is_deeply(
    $r->match( +{ PATH_INFO => '/blog/2010/03', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'Blog',
        action     => 'monthly',
        year => 2010,
        month => '03'
    },
    'blog monthly'
);
is_deeply(
    $r->match( +{ PATH_INFO => '/blog/2010/03/04', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'Blog',
        action     => 'daily',
        year => 2010, month => '03', day => '04',
    },
    'daily'
);
is_deeply(
    $r->match( +{ PATH_INFO => '/blog/2010/03', HTTP_HOST => 'localhost', REQUEST_METHOD => 'POST' } ) || undef,
    undef
);
is_deeply(
    $r->match( +{ PATH_INFO => '/comment', HTTP_HOST => 'localhost', REQUEST_METHOD => 'POST' } ) || undef,
    {
        controller => 'Comment',
        action     => 'create',
    }
);
is_deeply(
    $r->match( +{ PATH_INFO => '/', HTTP_HOST => 'sub.localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'Root',
        action     => 'show_sub',
    }
);
is_deeply(
    $r->match( +{ PATH_INFO => '/belongs/to/us', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'May',
        action     => 'show',
        splat      => ['to', 'us'],
    }
);
is_deeply(
    $r->match( +{ PATH_INFO => '/test7/fox/jumps', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        splat      => ['fox', 'jumps'],
    }
);
is_deeply(
    $r->match( +{ PATH_INFO => '/test8/fox/brown', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'May',
        action     => 'show',
        animal     => 'fox',
        color      => 'brown',
    },
    'named capture from regexp pattern',
);
is_deeply(
    $r->match( +{ PATH_INFO => '/test9/zero/00000', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'Test',
        action     => 'zero',
        '0'        => 'zero',
        '00'       => '00000',
    },
    'capture to zero.',
);
is_deeply(
    $r->match( +{ PATH_INFO => '/test10/split/splice/splat', HTTP_HOST => 'localhost', REQUEST_METHOD => 'GET' } ) || undef,
    {
        controller => 'Test',
        action     => 'splat',
        spec       => 'test10',
        splat      => [qw(split splice splat)],
    },
    'force splat and splat.',
);

done_testing;
